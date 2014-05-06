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
CODENAMES = precise wheezy squeeze lucid

# Debian package signature keys
UBUNTU_KEYID = 40976EAF437D05B5
SQUEEZE_KEYID = AED4B06F473041FA
WHEEZY_KEYID = 8B48AD6246925553
KEYIDS = $(UBUNTU_KEYID) $(SQUEEZE_KEYID) $(WHEEZY_KEYID)
KEYSERVER = hkp://keys.gnupg.net

# Linux vanilla tarball
LINUX_URL = http://www.kernel.org/pub/linux/kernel/v3.0
LINUX_VERSION = 3.5.7

# Uncomment to remove dependencies on Makefile and pbuilderrc while
# hacking this script
#DEBUG = yes

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
ALLSTAMPS = $(foreach c,$(CODENAMES),\
	$(foreach a,$(ARCHES),\
	$(foreach p,$(PACKAGES),$(c)/$(a)/.stamp-$(p))))
PBUILD = TOPDIR=$(TOPDIR) pbuilder
PBUILD_ARGS = --configfile pbuild/pbuilderrc --allow-untrusted \
	$(DEBBUILDOPTS_ARG)
# Build source pkgs for hardy with format 1.0
SOURCE_PACKAGE_FORMAT_hardy = --format=1.0

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
# Basic build dependencies
#
# Generic target for non-<codename>/<arch>-specific targets
admin/.stamp-builddeps: \
		admin/.dir-exists \
		git/.dir-exists \
		dist/.dir-exists \
		src/.dir-exists
	touch $@
ifneq ($(DEBUG),yes)
# While hacking, don't rebuild everything whenever a file is changed
admin/.stamp-builddeps: \
		Makefile \
		pbuild/pbuilderrc \
		pbuild/ppa-distributions.tmpl \
		pbuild/C10shell \
		.gitmodules \
		admin/keyring.gpg
endif
.PRECIOUS:  admin/.stamp-builddeps

# <codename>/<arch> target to ensure the necessary directory structure
# exists and basic dependencies exist and haven't changed; used in
# later targets to avoid complexity and repetition
%/.stamp-builddeps: admin/.stamp-builddeps \
		%/aptcache/.dir-exists \
		%/pkgs/.dir-exists \
		%/ppa/conf/.dir-exists
	touch $@
.PRECIOUS:  %/.stamp-builddeps

###################################################
# GPG keyring
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
# Base chroot tarball

# Base chroot tarballs are named e.g. lucid/i386/base.tgz
# in this case, $(*D) = lucid; $(*F) = i386
#
# This needs a stamp, since base.tgz is later updated with the
# newly-built Xenomai packages
.PRECIOUS:  %/.stamp-base.tgz
%/.stamp-base.tgz: %/.stamp-builddeps
	@echo "===== Creating pbuilder chroot tarball ====="
	$(SUDO) DIST=$(*D) ARCH=$(*F) \
	    $(PBUILD) --create \
		$(PBUILD_ARGS)
	touch $@


###################################################
# Xeno build rules

# clone & update the xenomai submodule; FIXME: nice way to detect if
# the branch has new commits?
git/.stamp-xenomai:
	@echo "===== Checking out Xenomai git repo ====="
#	# be sure the submodule has been checked out
	test -f git/xenomai/.git || \
           git submodule update --init -- git/xenomai
	git submodule update git/xenomai
	touch $@
.PRECIOUS: git/.stamp-xenomai

# create the source package
%/.stamp-xenomai-src-deb: %/.stamp-builddeps git/.stamp-xenomai
	@echo "===== Building Xenomai source package ====="
	cd $(@D) && dpkg-source -i -I $(SOURCE_PACKAGE_FORMAT_$(*D)) \
		-b $(TOPDIR)/git/xenomai
	touch $@
.PRECIOUS: %/.stamp-xenomai-src-deb

# build the binary packages
%/.stamp-xenomai: %/.stamp-xenomai-src-deb %/.stamp-base.tgz
	@echo "===== Building Xenomai binary packages ====="
	$(SUDO) DIST=$(*D) ARCH=$(*F) $(PBUILD) \
		--build $(PBUILD_ARGS) \
	        $(@D)/xenomai_*.dsc
	touch $@
.PRECIOUS: %/.stamp-xenomai


###################################################
# PPA update, Xenomai

# generate an intermediate PPA including the xenomai runtime or kernel pkgs,
# needed to build later packages
#
# if one already exists, blow it away and start from scratch
%/.stamp-xenomai-ppa %/.stamp-linux-ppa:  %/.stamp-builddeps %/.stamp-xenomai
	@echo "===== Building PPA ====="
	rm -rf $*/ppa/db $*/ppa/dists $*/ppa/pool
	cat pbuild/ppa-distributions.tmpl | sed \
		-e "s/@codename@/$(*D)/g" \
		-e "s/@arch@/$(*F)/g" \
		> $*/ppa/conf/distributions
	reprepro -C main -VVb $*/ppa includedeb $(*D) $*/pkgs/*.deb
	touch $@
%/.stamp-linux-ppa:  %/.stamp-linux
.PRECIOUS: %/.stamp-xenomai-ppa %/.stamp-linux-ppa


###################################################
# Update base.tgz with PPA pkgs

# Update the base chroot to pick up the Xenomai runtime or kernel
# packages, prerequisite to later package builds
%/.stamp-base.tgz-xenomai-updated %/.stamp-base.tgz-linux-updated: \
		%/.stamp-xenomai-ppa
	@echo "===== Updating pbuilder chroot with PPA packages ====="
	$(SUDO) DIST=$(*D) ARCH=$(*F) INTERMEDIATE_REPO=$*/ppa \
	    $(PBUILD) --update --override-config \
		$(PBUILD_ARGS)
	touch $@
%/.stamp-base.tgz-linux-updated: %/.stamp-linux-ppa
.PRECIOUS:  %/.stamp-base.tgz-xenomai-updated %/.stamp-base.tgz-linux-updated


###################################################
# Kernel build rules

git/kernel-rt-deb2/changelog: git/.dir-exists
	@echo "===== Checking out kernel Debian git repo ====="
#	# be sure the submodule has been checked out
	git submodule update --recursive --init git/kernel-rt-deb2
	touch $@

dist/$(LINUX_TARBALL):
	@echo "===== Downloading vanilla Linux tarball ====="
	test -d src || mkdir -p src
	cd src && wget $(LINUX_URL)/$(LINUX_TARBALL)

src/.stamp-linux: src/.dir-exists dist/$(LINUX_TARBALL)
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


src/.stamp-linux-src: src/.stamp-linux git/kernel-rt-deb2/changelog
	@echo "===== Building Linux source package ====="
#	# create source pkg
	cd src/linux/build && dpkg-source -i -I -b .
	touch $@

# build kernel packages, including the PPA with xenomai devel packages
%/.stamp-linux: %/.stamp-builddeps src/.stamp-linux-src \
		%/.stamp-base.tgz-xenomai-updated
	@echo "===== Building Linux binary package ====="
	$(SUDO) DIST=$(*D) ARCH=$(*F) INTERMEDIATE_REPO=$*/ppa \
	    $(PBUILD) --build \
		$(PBUILD_ARGS) \
	        src/linux/linux_*.dsc || \
	    (rm -f $@ && exit 1)
	touch $@


###################################################
# linux-tools package build rules
#
# This is built in much the same way as the kernel

git/linux-tools-deb/changelog: git/.dir-exists
	@echo "===== Checking out linux-tools-deb git repo ====="
#	# be sure the submodule has been checked out
	git submodule update --recursive --init git/linux-tools-deb
	touch $@

src/.stamp-linux-tools: src/.dir-exists dist/$(LINUX_TARBALL) \
		 git/linux-tools-deb/changelog
	@echo "===== Unpacking linux-tools source package ====="
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


src/.stamp-linux-tools-src: src/.stamp-linux-tools
	@echo "===== Building linux-tools source package ====="
#	# create source pkg
	cd src/linux-tools/build && dpkg-source -i -I -b .
	touch $@

%/.stamp-linux-tools: %/.stamp-builddeps src/.stamp-linux-tools-src
	@echo "===== Building linux-tools binary package ====="
	$(SUDO) DIST=$(*D) ARCH=$(*F) INTERMEDIATE_REPO=$*/ppa \
	    $(PBUILD) --build \
		$(PBUILD_ARGS) \
	        src/linux-tools/linux-tools_*.dsc || \
	    (rm -f $@ && exit 1)
	touch $@

