# see http://www.cmcrossroads.com/ask-mr-make/6535-tracing-rule-execution-in-gnu-make
# to trace make execution of make in more detail:
#     make VV=1
ifeq ("$(origin VV)", "command line")
    OLD_SHELL := $(SHELL)
    SHELL = $(warning Building $@$(if $<, (from $<))$(if $?, ($? newer)))$(OLD_SHELL)
endif


###################################################
# Variables that may change

# Arches to build
ARCHES = i386 amd64

# List of codenames to build for
#
# Lucid isn't supported by new kernel packaging, which requires python
# >= 2.7 (2.4 available), kernel-wedge >= 2.82 (2.29 available),
# gcc-4.6 (4.4 available).
#
# Squeeze (Debian 6.0) is reportedly obsolete.
#
#CODENAMES = precise wheezy squeeze lucid jessie
CODENAMES = precise wheezy jessie

# Debian package signature keys
UBUNTU_KEYID = 40976EAF437D05B5
#SQUEEZE_KEYID = AED4B06F473041FA
DEBIAN_KEYID = 8B48AD6246925553
KEYIDS = $(UBUNTU_KEYID) $(DEBIAN_KEYID)
KEYSERVER = hkp://keys.gnupg.net

# Linux vanilla tarball
LINUX_URL = http://www.kernel.org/pub/linux/kernel/v3.0
LINUX_VERSION = 3.5.7

# Uncomment to remove dependencies on Makefile and pbuilderrc while
# hacking this script
DEBUG = yes

# Args to pass into dpkg-buildpackage
ifneq ($(DEBBUILDOPTS),)
DEBBUILDOPTS_ARG = --debbuildopts "$(DEBBUILDOPTS)"
endif

###################################################
# Variables that should not change much
# (or auto-generated)

TOPDIR = $(shell pwd)
SUDO = sudo
LINUX_TARBALL = linux-$(LINUX_VERSION).tar.xz
LINUX_TARBALL_DEBIAN_ORIG = linux_$(LINUX_VERSION).orig.tar.xz
KEYRING = $(TOPDIR)/admin/keyring.gpg
PACKAGES = xenomai linux linux-tools
# ALLSTAMPS = $(foreach c,$(CODENAMES),\
# 	$(foreach a,$(ARCHES),\
# 	$(foreach p,$(PACKAGES),$(c)/$(a)/.stamp-$(p))))
ALLSTAMPS = $(foreach c,$(CODENAMES),\
	$(foreach a,$(ARCHES),$(c)/$(a)/.stamp-final-ppa))
PBUILD = TOPDIR=$(TOPDIR) pbuilder
PBUILD_ARGS = --configfile pbuild/pbuilderrc --allow-untrusted \
	$(DEBBUILDOPTS_ARG)

###################################################
# out-of-band checks

# check that pbuilder exists
ifeq ($(shell /bin/ls /usr/sbin/pbuilder 2>/dev/null),)
  $(error /usr/sbin/pbuilder does not exist)
endif


###################################################
# Misc rules

.PHONY:  all
all:  $(ALLSTAMPS)

%/all: $(foreach p,$(PACKAGES),%/.stamp-$(p))
	: # do nothing

%/.dir-exists:
	mkdir -p $(@D) && touch $@
.PRECIOUS:  %/.dir-exists

test:
	@echo ALLSTAMPS:
	@for i in $(ALLSTAMPS); do echo "    $$i"; done

###################################################
# PPA rules (reusable)

# generate a PPA including all packages build thus far
#
# if one already exists, blow it away and start from scratch
BUILD_PPA = \
	@echo "===== Building PPA: $(1) ====="; \n\
	rm -rf $*/ppa/db $*/ppa/dists $*/ppa/pool; \
	cat pbuild/ppa-distributions.tmpl | sed \
		-e "s/@codename@/$(*D)/g" \
		-e "s/@arch@/$(*F)/g" \
		> $*/ppa/conf/distributions; \
	reprepro -C main -VVb $*/ppa includedeb $(*D) $*/pkgs/*.deb; \
	touch $@

# Update base.tgz with PPA pkgs
UPDATE_CHROOT = \
	@echo "===== Updating pbuilder chroot with PPA packages ====="; \
	$$(SUDO) DIST=$$(*D) ARCH=$$(*F) INTERMEDIATE_REPO=$$*/ppa \
	    $$(PBUILD) --update --override-config \
		$$(PBUILD_ARGS); \
	touch $$@


###################################################
# 0. Basic build dependencies
#
# Generic target for non-<codename>/<arch>-specific targets
stamps/0.1.base-builddeps: \
		admin/.dir-exists \
		git/.dir-exists \
		dist/.dir-exists \
		src/.dir-exists
	touch $@
ifneq ($(DEBUG),yes)
# While hacking, don't rebuild everything whenever a file is changed
stamps/0.1.base-builddeps: \
		Makefile \
		pbuild/pbuilderrc \
		pbuild/ppa-distributions.tmpl \
		pbuild/C10shell \
		.gitmodules \
		admin/keyring.gpg
endif
.PRECIOUS:  stamps/0.1.base-builddeps

# <codename>/<arch> target to ensure the necessary directory structure
# exists and basic dependencies exist and haven't changed; used in
# later targets to avoid complexity and repetition
%/.stamp-builddeps: stamps/0.1.base-builddeps \
		%/aptcache/.dir-exists \
		%/pkgs/.dir-exists \
		%/ppa/conf/.dir-exists
	touch $@
.PRECIOUS:  %/.stamp-builddeps

###################################################
# 1. GPG keyring
#
# Download GPG keys for the various distros, needed by pbuilder
#
# Always touch the keyring so it isn't rebuilt over and over if the
# mtime looks out of date

admin/keyring.gpg: admin/.dir-exists
	@echo "===== Creating GPG keyring ====="
	gpg --no-default-keyring --keyring=$(KEYRING) \
		--keyserver=$(KEYSERVER) --recv-keys \
		--trust-model always \
		$(KEYIDS)
	test -f $@ && touch $@
ifneq ($(DEBUG),yes)
# While hacking, don't rebuild everything whenever a file is changed
admin/keyring.gpg: Makefile
endif


###################################################
# 2. Base chroot tarball

# Base chroot tarballs are named e.g. lucid/i386/base.tgz
# in this case, $(*D) = lucid; $(*F) = i386
#
# This needs a stamp, since base.tgz is later updated with the
# newly-built Xenomai packages
%/.stamp-base.tgz: %/.stamp-builddeps
	@echo "===== Creating pbuilder chroot tarball ====="
	$(SUDO) DIST=$(*D) ARCH=$(*F) \
	    $(PBUILD) --create \
		$(PBUILD_ARGS)
	touch $@
.PRECIOUS:  %/.stamp-base.tgz


###################################################
# Log into chroot

%/chroot: %/.stamp-base.tgz
	@echo "===== Logging into pbuilder chroot $(@D) ====="
	$(SUDO) DIST=$(*D) ARCH=$(*F) INTERMEDIATE_REPO=$*/ppa \
	    $(PBUILD) --login \
		$(PBUILD_ARGS)

###################################################
# 3. Xeno build rules

# 3.1. clone & update the xenomai submodule; FIXME: nice way to detect
# if the branch has new commits?
stamps/3.1.xenomai-source-checkout: stamps/0.1.base-builddeps
	@echo "===== Checking out Xenomai git repo ====="
#	# be sure the submodule has been checked out
	test -f git/xenomai/.git || \
           git submodule update --init -- git/xenomai
	git submodule update git/xenomai
	touch $@
.PRECIOUS: stamps/3.1.xenomai-source-checkout

# 3.2. create the source package
%/.stamp-xenomai-src-deb: %/.stamp-builddeps stamps/3.1.xenomai-source-checkout
	@echo "===== Building Xenomai source package ====="
	rm -f $(@D)/xenomai_*.dsc $(@D)/xenomai_*.tar.gz
	cd $(@D) && dpkg-source -i -I \
		-b $(TOPDIR)/git/xenomai
	touch $@
.PRECIOUS: %/.stamp-xenomai-src-deb

# 3.3. build the binary packages
%/.stamp-xenomai: \
		%/.stamp-xenomai-src-deb \
		%/.stamp-base.tgz \
		stamps/3.1.xenomai-source-checkout
	@echo "===== Building Xenomai binary packages ====="
	$(SUDO) DIST=$(*D) ARCH=$(*F) $(PBUILD) \
		--build $(PBUILD_ARGS) \
	        $(@D)/xenomai_*.dsc
	touch $@
.PRECIOUS: %/.stamp-xenomai


###################################################
# 4. Xenomai PPA update

# 4.1. Build intermediate Xenomai PPA
#
%/.stamp-xenomai-ppa:  %/.stamp-builddeps %/.stamp-xenomai
	$(call BUILD_PPA,Xenomai intermediate)
.PRECIOUS: %/.stamp-xenomai-ppa

# 4.2. Update chroot with Xenomai packages

%/.stamp-base.tgz-xenomai-updated: %/.stamp-xenomai-ppa
	$(call UPDATE_CHROOT)
.PRECIOUS:  %/.stamp-base.tgz-xenomai-updated $(PPA_UPDATE_CHROOT_STAMPS)


###################################################
# 5. Kernel build rules

# 5.1. Check out git submodule
stamps/5.1.linux-kernel-package-checkout: git/.dir-exists
	@echo "===== Checking out kernel Debian git repo ====="
#	# be sure the submodule has been checked out
	git submodule update --recursive --init git/kernel-rt-deb2
	touch $@

# 5.2. Download linux tarball
stamps/5.2.linux-kernel-tarball-downloaded: stamps/0.1.base-builddeps
	@echo "===== Downloading vanilla Linux tarball ====="
	rm -f dist/$(LINUX_TARBALL)
	wget $(LINUX_URL)/$(LINUX_TARBALL) -O dist/$(LINUX_TARBALL)
	touch $@

# 5.3. Prepare Linux source tree
stamps/5.3.linux-kernel-unpacked: \
		stamps/5.2.linux-kernel-tarball-downloaded \
		stamps/5.1.linux-kernel-package-checkout
	@echo "===== Unpacking Linux source package ====="
	mkdir -p src/linux/build
	ln -sf ../../dist/$(LINUX_TARBALL) \
	    src/linux/$(LINUX_TARBALL_DEBIAN_ORIG)
	git --git-dir="git/kernel-rt-deb2/.git" archive --prefix=debian/ HEAD \
	    | tar xCf src/linux/build -
	cd src/linux/build && debian/rules debian/control \
	    || true # always fails
	cd src/linux/build && debian/rules orig
	cd src/linux/build && debian/rules clean
	touch $@

# 5.4. Build Linux kernel source package
stamps/5.4.linux-kernel-source-package: \
		stamps/5.3.linux-kernel-unpacked \
		stamps/5.1.linux-kernel-package-checkout
	@echo "===== Building Linux source package ====="
#	# create source pkg
	cd src/linux/build && dpkg-source -i -I -b .
	touch $@

# 5.5. Build kernel packages
#
# Use the PPA with xenomai devel packages
%/.stamp-linux: \
		stamps/5.4.linux-kernel-source-package \
		%/.stamp-builddeps \
		%/.stamp-base.tgz-xenomai-updated
	@echo "===== Building Linux binary package ====="
	$(SUDO) DIST=$(*D) ARCH=$(*F) INTERMEDIATE_REPO=$*/ppa \
	    $(PBUILD) --build \
		$(PBUILD_ARGS) \
	        src/linux/linux_*.dsc || \
	    (rm -f $@ && exit 1)
	touch $@


###################################################
# 6. linux-tools package build rules
#
# This is built in much the same way as the kernel

# 6.1.  Update linux-tools git submodule
stamps/6.1.linux-tools-package-checkout: stamps/0.1.base-builddeps
	@echo "===== Checking out linux-tools-deb git repo ====="
#	# be sure the submodule has been checked out
	git submodule update --recursive --init git/linux-tools-deb
	touch $@

# 6.2. Prepare linux-tools tarball and prepare source tree
stamps/6.2.linux-tools-unpacked: \
		stamps/0.1.base-builddeps \
		stamps/5.2.linux-kernel-tarball-downloaded \
		stamps/6.1.linux-tools-package-checkout
	@echo "===== Unpacking linux-tools source package ====="
	rm -rf src/linux-tools/*
	mkdir -p src/linux-tools/build
	git --git-dir="git/linux-tools-deb/.git" archive --prefix=debian/ HEAD \
	    | tar xCf src/linux-tools/build -
	cd src/linux-tools/build && debian/bin/genorig.py \
	    ../../../dist/$(LINUX_TARBALL)
	cd src/linux-tools/build && debian/rules debian/control \
	    || true # always fails
	cd src/linux-tools/build && debian/rules orig
	cd src/linux-tools/build && debian/rules clean
	touch $@

# 6.3. Build linux-tools source package
stamps/6.3.linux-tools-source-package: stamps/6.2.linux-tools-unpacked
	@echo "===== Building linux-tools source package ====="
#	# create source pkg
	cd src/linux-tools/build && dpkg-source -i -I -b .
	touch $@

# 6.4. Build linux-tools binary packages
%/.stamp-linux-tools: \
		%/.stamp-builddeps \
		stamps/6.3.linux-tools-source-package
	@echo "===== Building linux-tools binary package ====="
	$(SUDO) DIST=$(*D) ARCH=$(*F) INTERMEDIATE_REPO=$*/ppa \
	    $(PBUILD) --build \
		$(PBUILD_ARGS) \
	        src/linux-tools/linux-tools_*.dsc || \
	    (rm -f $@ && exit 1)
	touch $@

###################################################
# 7. Final PPA
#
# 7.1. Build final PPA with all packages
#
%/.stamp-final-ppa:  %/.stamp-linux %/.stamp-linux-tools
	$(call BUILD_PPA,Final)
.PRECIOUS: %/.stamp-final-ppa

