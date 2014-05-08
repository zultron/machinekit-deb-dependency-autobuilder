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

###################################################
# Variables that should not change much
# (or auto-generated)

# Misc paths, filenames, executables
TOPDIR = $(shell pwd)
SUDO = sudo
LINUX_TARBALL = linux-$(LINUX_VERSION).tar.xz
LINUX_TARBALL_DEBIAN_ORIG = linux_$(LINUX_VERSION).orig.tar.xz
KEYRING = $(TOPDIR)/admin/keyring.gpg

# Pass any 'DEBBUILDOPTS=foo' arg into dpkg-buildpackage
ifneq ($(DEBBUILDOPTS),)
DEBBUILDOPTS_ARG = --debbuildopts "$(DEBBUILDOPTS)"
endif

# pbuilder command line
PBUILD = TOPDIR=$(TOPDIR) pbuilder
PBUILD_ARGS = --configfile pbuild/pbuilderrc --allow-untrusted \
	$(DEBBUILDOPTS_ARG)

# List of all codename/arch combos
ALL_CODENAMES_ARCHES = $(foreach c,$(CODENAMES),\
	$(foreach a,$(ARCHES),$(c)/$(a)))
# ...and a handy way to expand 'pattern-%'
CA_EXPAND = $(patsubst %,$(1),$(ALL_CODENAMES_ARCHES))

# Set this variable to the stamp name of the last target of each
# codename/arch; used by the default target
FINAL_STEP = .stamp.7.1.ppa-final
ALLSTAMPS := $(call CA_EXPAND,%/$(FINAL_STEP))

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

%/all: %/$(FINAL_STEP)
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
define BUILD_PPA
	@echo "===== $(1). $(@D):  Building $(2) PPA ====="
#	# Always start from scratch
	rm -rf $*/ppa; mkdir -p $*/ppa/db $*/ppa/dists $*/ppa/pool $*/ppa/conf
#	# Configure
	cat pbuild/ppa-distributions.tmpl | sed \
		-e "s/@codename@/$(*D)/g" \
		-e "s/@arch@/$(*F)/g" \
		> $*/ppa/conf/distributions
#	# Build
	reprepro -C main -VVb $*/ppa includedeb $(*D) $*/pkgs/*.deb
	touch $@
endef

# Update base.tgz with PPA pkgs
define UPDATE_CHROOT
	@echo "===== $(1). $(@D): " \
	    "Updating pbuilder chroot with PPA packages ====="
	$(SUDO) DIST=$(*D) ARCH=$(*F) INTERMEDIATE_REPO=$*/ppa \
	    $(PBUILD) --update --override-config \
		$(PBUILD_ARGS)
	touch $@
endef

%/clean-ppa:
	rm -rf $*/ppa

###################################################
# 0. Basic build dependencies
#
# 0.1 Generic target for non-<codename>/<arch>-specific targets
stamps/0.1.base-builddeps: \
		admin/.dir-exists \
		git/.dir-exists \
		dist/.dir-exists \
		src/.dir-exists \
		stamps/.dir-exists
	touch $@
ifneq ($(DEBUG),yes)
# While hacking, don't rebuild everything whenever a file is changed
stamps/0.1.base-builddeps: \
		Makefile \
		pbuild/pbuilderrc \
		.gitmodules
endif
.PRECIOUS:  stamps/0.1.base-builddeps


###################################################
# 1. GPG keyring

# 1.1 Download GPG keys for the various distros, needed by pbuilder
#
# Always touch the keyring so it isn't rebuilt over and over if the
# mtime looks out of date

stamps/1.1.keyring-downloaded:
	@echo "===== 1.1. All variants:  Creating GPG keyring ====="
	mkdir -p admin
	gpg --no-default-keyring --keyring=$(KEYRING) \
		--keyserver=$(KEYSERVER) --recv-keys \
		--trust-model always \
		$(KEYIDS)
	test -f $(KEYRING) && touch $@  # otherwise, fail
.PRECIOUS:  stamps/1.1.keyring-downloaded

clean-keyring:
	@echo "cleaning package GPG keyring"
	rm -f $(KEYRING)
	rm -f stamps/1.1.keyring-downloaded
SQUEAKY_CLEAN_TARGETS += clean-keyring

###################################################
# 2. Base chroot tarball

# Base chroot tarballs are named e.g. lucid/i386/base.tgz
# in this case, $(*D) = lucid; $(*F) = i386
#
# 2.1.  Build chroot tarball
%/.stamp.2.1.chroot-build: \
		stamps/1.1.keyring-downloaded
	@echo "===== 2.1. $(@D):  Creating pbuilder chroot tarball ====="
#	# make all the codename/i386 directories needed right here
	mkdir -p $(@D)/{pkgs,aptcache}
#	# create the base.tgz chroot tarball
	$(SUDO) DIST=$(*D) ARCH=$(*F) \
	    $(PBUILD) --create \
		$(PBUILD_ARGS)
	touch $@
.PRECIOUS:  %/.stamp.2.1.chroot-build

%/clean-chroot:
	@echo "cleaning $* chroot tarball"
	rm -f $*/base.tgz
	rm -f $*/.stamp.2.1.chroot-build
ARCH_SQUEAKY_CLEAN_TARGETS += clean-chroot

###################################################
# Log into chroot

%/chroot: \
		%/.stamp.2.1.chroot-build
	@echo "===== Logging into $(@D) pbuilder chroot ====="
	$(SUDO) DIST=$(*D) ARCH=$(*F) INTERMEDIATE_REPO=$*/ppa \
	    $(PBUILD) --login \
		$(PBUILD_ARGS)

###################################################
# 3. Xeno build rules

# 3.1. clone & update the xenomai submodule; FIXME: nice way to detect
# if the branch has new commits?
stamps/3.1.xenomai-source-checkout: \
		stamps/0.1.base-builddeps
	@echo "===== 3.1. All variants:  Checking out Xenomai git repo ====="
	mkdir -p git/xenomai
#	# be sure the submodule has been checked out
	test -f git/xenomai/.git || \
           git submodule update --init -- git/xenomai
	git submodule update git/xenomai
	touch $@
.PRECIOUS: stamps/3.1.xenomai-source-checkout

clean-xenomai-source-checkout: \
		clean-xenomai-source-package
	@echo "cleaning up xenomai git submodule directory"
	rm -rf git/xenomai
	rm -f stamps/3.1.xenomai-source-checkout
SQUEAKY_CLEAN_TARGETS += clean-xenomai-source-checkout

# 3.2. create the source package
stamps/3.2.xenomai-source-package: \
		stamps/3.1.xenomai-source-checkout
	@echo "===== 3.2. All variants:  Building Xenomai source package ====="
	mkdir -p src/xenomai
	cd src/xenomai && dpkg-source -i -I -b $(TOPDIR)/git/xenomai
	touch $@
.PRECIOUS: stamps/3.2.xenomai-source-package

clean-xenomai-source-package: \
		$(call CA_EXPAND,%/clean-xenomai-build)
	@echo "cleaning up xenomai source package"
	rm -f src/xenomai_*.{dsc,tar.gz}
	rm -f stamps/3.2.xenomai-source-package
CLEAN_TARGETS += clean-xenomai-source-package

# 3.3. build the binary packages
%/.stamp.3.3.xenomai-build: \
		%/.stamp.2.1.chroot-build \
		stamps/3.1.xenomai-source-checkout \
		stamps/3.2.xenomai-source-package
	@echo "===== 3.3. $(@D):  Building Xenomai binary packages ====="
	$(SUDO) DIST=$(*D) ARCH=$(*F) $(PBUILD) \
		--build $(PBUILD_ARGS) \
	        src/xenomai/xenomai_*.dsc
	touch $@
.PRECIOUS: %/.stamp.3.3.xenomai-build

%/clean-xenomai-build:
	@echo "cleaning up $* xenomai binary-build"
	rm -f $*/pkgs/xenomai_*.build
	rm -f $*/pkgs/xenomai_*.changes
	rm -f $*/pkgs/xenomai_*.dsc
	rm -f $*/pkgs/xenomai_*.tar.gz
	rm -f $*/pkgs/xenomai-doc_*.deb
	rm -f $*/pkgs/xenomai-runtime_*.deb
	rm -f $*/pkgs/linux-patch-xenomai_*.deb
	rm -f $*/pkgs/libxenomai1_*.deb
	rm -f $*/pkgs/libxenomai-dev_*.deb
	rm -f $*/.stamp.3.3.xenomai-build
ARCH_CLEAN_TARGETS += clean-xenomai-build


###################################################
# 4. Xenomai PPA update

# 4.1. Build intermediate Xenomai PPA
#
%/.stamp.4.1.ppa-xenomai: \
		pbuild/ppa-distributions.tmpl \
		%/.stamp.0.2.builddeps \
		%/.stamp.3.3.xenomai-build
	$(call BUILD_PPA,4.1,Xenomai intermediate)
.PRECIOUS: %/.stamp.4.1.ppa-xenomai

%/clean-ppa-xenomai: \
		%/clean-ppa \
		%/clean-chroot-update
	@echo "cleaning up $* PPA directory"
	rm -f $*/.stamp.4.1.ppa-xenomai
ARCH_CLEAN_TARGETS += clean-ppa-xenomai

# 4.2. Update chroot with Xenomai packages

%/.stamp.4.2.chroot-update: %/.stamp.4.1.ppa-xenomai
	$(call UPDATE_CHROOT,4.2)
.PRECIOUS:  %/.stamp.4.2.chroot-update $(PPA_UPDATE_CHROOT_STAMPS)

%/clean-chroot-update:
	@echo "cleaning up $* chroot update stamps"
	rm -f $*/.stamp.4.2.chroot-update
ARCH_CLEAN_TARGETS += clean-chroot-update

###################################################
# 5. Kernel build rules

# 5.1. Check out git submodule
stamps/5.1.linux-kernel-package-checkout: \
		stamps/0.1.base-builddeps
	@echo "===== 5.1. All variants: "\
	    "Checking out kernel Debian git repo ====="
#	# be sure the submodule has been checked out
	git submodule update --recursive --init git/kernel-rt-deb2
	touch $@

clean-linux-kernel-package-checkout: \
		clean-linux-kernel-tarball-downloaded
	@echo "cleaning up linux kernel packaging git submodule directory"
	rm -rf git/kernel-rt-deb2
	rm -f stamps/5.1.linux-kernel-package-checkout
SQUEAKY_CLEAN_TARGETS += clean-linux-kernel-package-checkout

# 5.2. Download linux tarball
stamps/5.2.linux-kernel-tarball-downloaded: \
		stamps/0.1.base-builddeps
	@echo "===== 5.2. All variants: " \
	    "Downloading vanilla Linux tarball ====="
	rm -f dist/$(LINUX_TARBALL)
	wget $(LINUX_URL)/$(LINUX_TARBALL) -O dist/$(LINUX_TARBALL)
	touch $@

clean-linux-kernel-tarball-downloaded: \
		clean-linux-kernel-unpacked
	@echo "cleaning up linux kernel tarball"
	rm -f dist/$(LINUX_TARBALL)
	rm -f stamps/5.2.linux-kernel-tarball-downloaded
SQUEAKY_CLEAN_TARGETS += clean-linux-kernel-tarball-downloaded

# 5.3. Prepare Linux source tree
stamps/5.3.linux-kernel-unpacked: \
		stamps/5.1.linux-kernel-package-checkout \
		stamps/5.2.linux-kernel-tarball-downloaded
	@echo "===== 5.3. All variants:  Unpacking Linux source package ====="
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

clean-linux-kernel-unpacked: \
		clean-linux-kernel-source-package
	@echo "cleaning up linux kernel source directory"
	rm -rf src/linux/{build,orig}
	rm -f src/linux/linux_*.orig.tar.xz
	rm -f stamps/5.3.linux-kernel-unpacked
CLEAN_TARGETS += clean-linux-kernel-unpacked

# 5.4. Build Linux kernel source package
stamps/5.4.linux-kernel-source-package: \
		stamps/5.1.linux-kernel-package-checkout \
		stamps/5.3.linux-kernel-unpacked
	@echo "===== 5.4. All variants:  Building Linux source package ====="
#	# create source pkg
	cd src/linux/build && dpkg-source -i -I -b .
	touch $@

clean-linux-kernel-source-package: \
		$(call CA_EXPAND,%/clean-linux-kernel-build)
	@echo "cleaning up linux kernel source package"
	rm -f src/linux/linux_*.debian.tar.xz
	rm -f src/linux/linux_*.orig.tar.xz
	rm -f src/linux/linux_*.dsc
	rm -f stamps/5.4.linux-kernel-source-package
CLEAN_TARGETS += clean-linux-kernel-source-package

# 5.5. Build kernel packages
#
# Use the PPA with xenomai devel packages
%/.stamp.5.5.linux-kernel-build: \
		%/.stamp.0.2.builddeps \
		%/.stamp.4.2.chroot-update \
		stamps/5.4.linux-kernel-source-package
	@echo "===== 5.5. $(@D):  Building Linux binary package ====="
	$(SUDO) DIST=$(*D) ARCH=$(*F) INTERMEDIATE_REPO=$*/ppa \
	    $(PBUILD) --build \
		$(PBUILD_ARGS) \
	        src/linux/linux_*.dsc || \
	    (rm -f $@ && exit 1)
	touch $@

%/clean-linux-kernel-build:
	@echo "cleaning up $* linux kernel binary build"
	rm -f $*/pkgs/linux-headers-*.deb
	rm -f $*/pkgs/linux-image-*.deb
	rm -f $*/pkgs/linux-libc-dev_*.deb
	rm -f $*/pkgs/linux_*.build
	rm -f $*/pkgs/linux_*.changes
	rm -f $*/pkgs/linux_*.dsc
	rm -f $*/pkgs/linux_*.debian.tar.xz
	rm -f $*/pkgs/linux_*.orig.tar.xz
	rm -f $*/.stamp.5.5.linux-kernel-build
ARCH_CLEAN_TARGETS += clean-linux-kernel-build

###################################################
# 6. linux-tools package build rules
#
# This is built in much the same way as the kernel

# 6.1.  Update linux-tools git submodule
stamps/6.1.linux-tools-package-checkout: \
		stamps/0.1.base-builddeps
	@echo "===== 6.1. All variants: " \
	    "Checking out linux-tools-deb git repo ====="
#	# be sure the submodule has been checked out
	git submodule update --recursive --init git/linux-tools-deb
	touch $@

clean-linux-tools-package-checkout: \
		clean-linux-tools-unpacked
	@echo "cleaning up linux-tools git submodule directory"	
	rm -rf git/linux-tools-deb
	rm -f stamps/6.1.linux-tools-package-checkout
SQUEAKY_CLEAN_TARGETS += clean-linux-tools-package-checkout

# 6.2. Prepare linux-tools tarball and prepare source tree
stamps/6.2.linux-tools-unpacked: \
		stamps/0.1.base-builddeps \
		stamps/5.2.linux-kernel-tarball-downloaded \
		stamps/6.1.linux-tools-package-checkout
	@echo "===== 6.2. All variants: " \
	    "Unpacking linux-tools source directory ====="
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

clean-linux-tools-unpacked: \
		clean-linux-tools-source-package
	@echo "cleaning up linux-tools source directory"
	rm -rf src/linux-tools/{build,orig}
	rm -f src/linux/linux-tools_*.orig.tar.xz
	rm -f stamps/6.2.linux-tools-unpacked
CLEAN_TARGETS += clean-linux-tools-unpacked

# 6.3. Build linux-tools source package
stamps/6.3.linux-tools-source-package: \
		stamps/6.2.linux-tools-unpacked
	@echo "===== 6.3. All variants: " \
	    "Building linux-tools source package ====="
#	# create source pkg
	cd src/linux-tools/build && dpkg-source -i -I -b .
	touch $@

clean-linux-tools-source-package: \
		$(call CA_EXPAND,%/clean-linux-tools-build)
	@echo "cleaning up linux-tools source package"
	rm -f src/linux-tools/linux-tools_*.debian.tar.xz
	rm -f src/linux-tools/linux-tools_*.orig.tar.xz
	rm -f src/linux-tools/linux-tools_*.dsc
	rm -f stamps/6.3.linux-tools-source-package
CLEAN_TARGETS += clean-linux-tools-source-package

# 6.4. Build linux-tools binary packages
%/.stamp.6.4.linux-tools-build: \
		%/.stamp.0.2.builddeps \
		stamps/6.3.linux-tools-source-package
	@echo "===== 6.4. $(@D):  Building linux-tools binary package ====="
	$(SUDO) DIST=$(*D) ARCH=$(*F) INTERMEDIATE_REPO=$*/ppa \
	    $(PBUILD) --build \
		$(PBUILD_ARGS) \
	        src/linux-tools/linux-tools_*.dsc
	touch $@

%/clean-linux-tools-build:
	@echo "cleaning up $* linux-tools binary build"
	rm -f $*/pkgs/linux-tools-*.deb
	rm -f $*/pkgs/linux-kbuild-*.deb
	rm -f $*/pkgs/linux-tools_*.orig.tar.xz
	rm -f $*/pkgs/linux-tools_*.debian.tar.xz
	rm -f $*/pkgs/linux-tools_*.dsc
	rm -f $*/pkgs/linux-tools_*.build
	rm -f $*/pkgs/linux-tools_*.changes
	rm -f $*/.stamp.6.4.linux-tools-build
ARCH_CLEAN_TARGETS += clean-linux-tools-build


###################################################
# 7. Final PPA
#
# 7.1. Build final PPA with all packages
#
%/.stamp.7.1.ppa-final: \
		pbuild/ppa-distributions.tmpl \
		%/.stamp.5.5.linux-kernel-build \
		%/.stamp.6.4.linux-tools-build
	$(call BUILD_PPA,7.1,Final)

%/clean-ppa-final: \
		%/clean-ppa
	@echo "cleaning up $* final PPA directory"
	rm -f $*/.stamp.7.1.ppa-final
ARCH_CLEAN_TARGETS += clean-ppa-final


###################################################
# Clean targets

%/clean: $(foreach t,$(ARCH_CLEAN_TARGETS),%/$(t))
	@echo "Cleaned up $* build artifacts"

# Expand the list of ARCH_CLEAN_TARGETS
CLEAN_TARGETS += $(foreach t,$(ARCH_CLEAN_TARGETS),$(call CA_EXPAND,%/$(t)))
clean: $(CLEAN_TARGETS)

%/squeaky-clean-caches:
	@echo "Removing $* aptcache"
	rm -r $*/aptcache
squeaky-clean-caches: \
		$(call CA_EXPAND,%/squeaky-clean-caches)
	@echo "Removing ccache"
	rm -r ccache

# Expand the list of ARCH_SQUEAKY_CLEAN_TARGETS
SQUEAKY_CLEAN_TARGETS += $(foreach t,$(ARCH_SQUEAKY_CLEAN_TARGETS),\
	$(call CA_EXPAND,%/$(t)))
squeaky-clean: \
		$(CLEAN_TARGETS) \
		$(SQUEAKY_CLEAN_TARGETS) \
		squeaky-clean-caches
