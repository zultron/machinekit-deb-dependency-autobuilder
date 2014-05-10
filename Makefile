# see http://www.cmcrossroads.com/ask-mr-make/6535-tracing-rule-execution-in-gnu-make
# to trace make execution of make in more detail:
#     make VV=1
ifeq ("$(origin VV)", "command line")
    OLD_SHELL := $(SHELL)
    SHELL = $(warning Building $@$(if $<, (from $<))$(if $?, ($? newer)))$(OLD_SHELL)
endif


###################################################
# Variables that may change

# List of codename/arch combos to build
#
# Lucid isn't supported by new kernel packaging, which requires python
# >= 2.7 (2.4 available), kernel-wedge >= 2.82 (2.29 available),
# gcc-4.6 (4.4 available).
#
# Squeeze (Debian 6.0) is reportedly obsolete.
ALL_CODENAMES_ARCHES = \
	wheezy/amd64 \
	wheezy/i386 \
	wheezy/armhf \
	precise/amd64 \
	precise/i386 \
	jessie/amd64 \
	jessie/i386

# Define this to have a deterministic chroot for step 5.3
#A_CHROOT = wheezy/amd64

# List of all featuresets
FEATURESETS = \
    xenomai.x86 \
    xenomai.beaglebone \
#    rtai

# Explicitly define featureset list to enable; default all
#FEATURESETS_ENABLED = xenomai.beaglebone

# Debian package signature keys
UBUNTU_KEYID = 40976EAF437D05B5
#SQUEEZE_KEYID = AED4B06F473041FA
DEBIAN_KEYID = 8B48AD6246925553
KEYIDS = $(UBUNTU_KEYID) $(DEBIAN_KEYID)
KEYSERVER = hkp://keys.gnupg.net

# Linux vanilla tarball
LINUX_URL = http://www.kernel.org/pub/linux/kernel/v3.0
LINUX_VERSION = 3.8.13

# Uncomment to remove dependencies on Makefile and pbuilderrc while
# hacking this script
#DEBUG = yes

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

# A handy way to expand 'pattern-%' with all codename/arch combos
CA_EXPAND = $(patsubst %,$(1),$(ALL_CODENAMES_ARCHES))

# A handy way to separate codename or arch from a codename/arch combo
codename = $(patsubst %/,%,$(dir $(1)))
arch = $(notdir $(1))

# Set this variable to the stamp name of the last target of each
# codename/arch; used by the default target
FINAL_STEP = .stamp.7.1.ppa-final
ALLSTAMPS := $(call CA_EXPAND,%/$(FINAL_STEP))

# A random chroot to build the linux source package in
A_CHROOT ?= $(wordlist 1,1,$(ALL_CODENAMES_ARCHES))

# All featuresets enabled by default
FEATURESETS_ENABLED ?= $(FEATURESETS)
# Disabled featuresets
FEATURESETS_DISABLED = $(filter-out $(FEATURESETS_ENABLED),$(FEATURESETS))

###################################################
# out-of-band checks

# check that pbuilder exists
ifeq ($(shell /bin/ls /usr/sbin/pbuilder 2>/dev/null),)
  $(error /usr/sbin/pbuilder does not exist)
endif


###################################################
# Debugging

REASON = @if test -f $@; then \
 echo "   == re-making '$@' for dependency '$?' ==";\
 else \
   echo "   == making non-existent '$@' for dependency '$?' =="; \
 fi

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

clean-base-builddeps:
	rm -f stamps/0.1.base-builddeps
	find . -name .dir-exists -exec rm -f '{}' \;
SQUEAKY_CLEAN_TARGETS += clean-base-builddeps


###################################################
# 1. GPG keyring

# 1.1 Download GPG keys for the various distros, needed by pbuilder
#
# Always touch the keyring so it isn't rebuilt over and over if the
# mtime looks out of date

stamps/1.1.keyring-downloaded: \
		stamps/0.1.base-builddeps
	@echo "===== 1.1. All variants:  Creating GPG keyring ====="
	$(REASON)
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
	$(REASON)
#	# make all the codename/i386 directories needed right here
	mkdir -p $(@D)/pkgs $(@D)/aptcache
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
	$(REASON)
	$(SUDO) DIST=$(*D) ARCH=$(*F) INTERMEDIATE_REPO=$*/ppa \
	    $(PBUILD) --login \
		--bindmounts $(TOPDIR) \
		$(PBUILD_ARGS)

###################################################
# 3. Xeno build rules

# 3.1. clone & update the xenomai submodule; FIXME: nice way to detect
# if the branch has new commits?
stamps/3.1.xenomai-source-checkout: \
		stamps/0.1.base-builddeps
	@echo "===== 3.1. All variants:  Checking out Xenomai git repo ====="
	$(REASON)
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
	rm -rf git/xenomai; mkdir -p git/xenomai
	rm -f stamps/3.1.xenomai-source-checkout
SQUEAKY_CLEAN_TARGETS += clean-xenomai-source-checkout

# 3.2. create the source package
stamps/3.2.xenomai-source-package: \
		stamps/3.1.xenomai-source-checkout
	@echo "===== 3.2. All variants:  Building Xenomai source package ====="
	$(REASON)
	mkdir -p src/xenomai
	rm -f src/xenomai/xenomai_*.dsc src/xenomai/xenomai_*.tar.gz
	cd src/xenomai && dpkg-source -i -I -b $(TOPDIR)/git/xenomai
	touch $@
.PRECIOUS: stamps/3.2.xenomai-source-package

clean-xenomai-source-package: \
		$(call CA_EXPAND,%/clean-xenomai-build)
	@echo "cleaning up xenomai source package"
	rm -f src/xenomai/xenomai_*.dsc
	rm -f src/xenomai/xenomai_*.tar.gz
	rm -f stamps/3.2.xenomai-source-package
CLEAN_TARGETS += clean-xenomai-source-package

# 3.3. build the binary packages
%/.stamp.3.3.xenomai-build: \
		%/.stamp.2.1.chroot-build \
		stamps/3.1.xenomai-source-checkout \
		stamps/3.2.xenomai-source-package
	@echo "===== 3.3. $(@D):  Building Xenomai binary packages ====="
	$(REASON)
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

# Hook into rest of build
ifneq ($(filter xenomai.%,$(FEATURESETS_ENABLED)),)
PPA_INTERMEDIATE_DEPS += %/.stamp.3.3.xenomai-build
endif

###################################################
# 8. RTAI build rules

# 8.1. clone & update the rtai submodule
stamps/8.1.rtai-source-checkout: \
		stamps/0.1.base-builddeps
	@echo "===== 8.1. All variants:  Checking out RTAI git repo ====="
	$(REASON)
	mkdir -p git/rtai
#	# be sure the submodule has been checked out
	test -f git/rtai/.git || \
           git submodule update --init -- git/rtai
	git submodule update git/rtai
	touch $@
.PRECIOUS: stamps/8.1.rtai-source-checkout

clean-rtai-source-checkout: \
		clean-rtai-source-package
	@echo "cleaning up RTAI git submodule directory"
	rm -rf git/rtai; mkdir -p git/rtai
	rm -f stamps/8.1.rtai-source-checkout
SQUEAKY_CLEAN_TARGETS += clean-rtai-source-checkout

# 8.2. clone & update the rtai-deb submodule
stamps/8.2.rtai-deb-source-checkout: \
		stamps/0.1.base-builddeps
	@echo "===== 8.2. All variants: " \
	    "Checking out RTAI Debian git repo ====="
	$(REASON)
	mkdir -p git/rtai-deb
#	# be sure the submodule has been checked out
	test -f git/rtai-deb/.git || \
           git submodule update --init -- git/rtai-deb
	git submodule update git/rtai-deb
	touch $@
.PRECIOUS: stamps/8.2.rtai-deb-source-checkout

clean-rtai-deb-source-checkout: \
		clean-rtai-source-package
	@echo "cleaning up RTAI Debian git submodule directory"
	rm -rf git/rtai-deb; mkdir -p git/rtai-deb
	rm -f stamps/8.2.rtai-deb-source-checkout
SQUEAKY_CLEAN_TARGETS += clean-rtai-deb-source-checkout

# 8.3. Build RTAI orig source tarball
stamps/8.3.rtai-source-tarball: \
		stamps/8.1.rtai-source-checkout
	@echo "===== 8.3. All variants:  Building RTAI source tarball ====="
	$(REASON)
	mkdir -p src/rtai
	rm -f src/rtai/rtai_*.orig.tar.gz
	RTAI_VER=`sed -n '1 s/rtai *(\([0-9.][0-9.]*\).*/\1/p' \
		git/rtai-deb/changelog` && \
	git --git-dir="git/rtai/.git" archive HEAD | \
	    gzip > src/rtai/rtai_$${RTAI_VER}.orig.tar.gz
	touch $@
.PRECIOUS: stamps/8.3.rtai-source-tarball

clean-rtai-source-tarball: \
		clean-rtai-source-package
	@echo "cleaning up unpacked rtai source"
	rm -f src/rtai/rtai_*.dsc
	rm -f src/rtai/rtai_*.tar.gz
	rm -f stamps/8.3.rtai-source-tarball
CLEAN_TARGETS += clean-rtai-source-tarball

# 8.4. Build RTAI source package
stamps/8.4.rtai-source-package: \
		stamps/8.2.rtai-deb-source-checkout \
		stamps/8.3.rtai-source-tarball
	@echo "===== 8.4. All variants:  Build RTAI source package ====="
	$(REASON)
	rm -rf src/rtai/build; mkdir -p src/rtai/build
	rm -f src/rtai/rtai_*.dsc
	rm -f src/rtai/rtai_*.debian.tar.gz
	tar xzCf src/rtai/build src/rtai/rtai_*.orig.tar.gz
	git --git-dir="git/rtai-deb/.git" archive --prefix=debian/ HEAD | \
	    tar xCf src/rtai/build -
	cd src/rtai && dpkg-source -i -I -b build
	touch $@
.PRECIOUS: stamps/8.4.rtai-source-package

clean-rtai-source-package: \
		$(call CA_EXPAND,%/clean-rtai-build)
	rm -rf src/rtai/build
	rm -f stamps/8.4.rtai-source-package
CLEAN_TARGETS += clean-rtai-source-tarball

# 8.5. Build the RTAI binary packages
%/.stamp.8.5.rtai-build: \
		%/.stamp.2.1.chroot-build \
		stamps/8.4.rtai-source-package
	@echo "===== 8.5. $(@D):  Building RTAI binary packages ====="
	$(REASON)
	$(SUDO) DIST=$(*D) ARCH=$(*F) $(PBUILD) \
		--build $(PBUILD_ARGS) \
	        src/rtai/rtai_*.dsc
	touch $@
.PRECIOUS: %/.stamp.8.5.rtai-build

%/clean-rtai-build:
	@echo "cleaning up $* rtai binary-build"
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

# Hook into rest of build
ifneq ($(filter rtai,$(FEATURESETS_ENABLED)),)
PPA_INTERMEDIATE_DEPS += %/.stamp.8.5.rtai-build
endif

###################################################
# 4. Intermediate PPA update

# 4.1. Build intermediate PPA with featureset packages
#
%/.stamp.4.1.ppa-intermediate: \
		pbuild/ppa-distributions.tmpl \
		$(PPA_INTERMEDIATE_DEPS)
	$(call BUILD_PPA,4.1,intermediate)
.PRECIOUS: %/.stamp.4.1.ppa-intermediate

%/clean-ppa-intermediate: \
		%/clean-ppa \
		%/clean-chroot-update
	@echo "cleaning up $* PPA directory"
	rm -f $*/.stamp.4.1.ppa-intermediate
ARCH_CLEAN_TARGETS += clean-ppa-intermediate

# 4.2. Update chroot with featureset packages

%/.stamp.4.2.chroot-update: %/.stamp.4.1.ppa-intermediate
	$(call UPDATE_CHROOT,4.2)
.PRECIOUS:  %/.stamp.4.2.chroot-update

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
	$(REASON)
#	# be sure the submodule has been checked out
	git submodule update --recursive --init git/kernel-rt-deb2
	touch $@

clean-linux-kernel-package-checkout: \
		clean-linux-kernel-tarball-downloaded
	@echo "cleaning up linux kernel packaging git submodule directory"
	rm -rf git/kernel-rt-deb2; mkdir -p git/kernel-rt-deb2
	rm -f stamps/5.1.linux-kernel-package-checkout
SQUEAKY_CLEAN_TARGETS += clean-linux-kernel-package-checkout

# 5.2. Download linux tarball
stamps/5.2.linux-kernel-tarball-downloaded: \
		stamps/0.1.base-builddeps
	@echo "===== 5.2. All variants: " \
	    "Downloading vanilla Linux tarball ====="
	$(REASON)
	rm -f dist/$(LINUX_TARBALL)
	wget $(LINUX_URL)/$(LINUX_TARBALL) -O dist/$(LINUX_TARBALL)
	touch $@

clean-linux-kernel-tarball-downloaded: \
		clean-linux-kernel-package-configured
	@echo "cleaning up linux kernel tarball"
	rm -f dist/$(LINUX_TARBALL)
	rm -f stamps/5.2.linux-kernel-tarball-downloaded
SQUEAKY_CLEAN_TARGETS += clean-linux-kernel-tarball-downloaded

# 5.3. Unpack and configure Linux package source tree
#
# This has to be done in a chroot with the featureset packages
stamps/5.3.linux-kernel-package-configured: \
		stamps/5.1.linux-kernel-package-checkout \
		stamps/5.2.linux-kernel-tarball-downloaded \
		$(A_CHROOT)/.stamp.4.2.chroot-update
	@echo "===== 5.3. All variants:  Unpacking and configuring" \
	    " Linux source package ====="
	$(REASON)
#	# Starting clean, copy debian packaging and hardlink source tarball
	rm -rf src/linux/build; mkdir -p src/linux/build
	ln -f dist/$(LINUX_TARBALL) \
	    src/linux/$(LINUX_TARBALL_DEBIAN_ORIG)
	git --git-dir="git/kernel-rt-deb2/.git" archive --prefix=debian/ HEAD \
	    | tar xCf src/linux/build -
#	# Configure the package in a chroot
	chmod +x pbuild/linux-unpacked-chroot-script.sh
	$(SUDO) \
	    DIST=$(call codename,$(A_CHROOT)) \
	    ARCH=$(call arch,$(A_CHROOT)) \
	    INTERMEDIATE_REPO=$(A_CHROOT)/ppa \
	    $(PBUILD) \
		--execute --bindmounts ${TOPDIR}/src/linux \
		$(PBUILD_ARGS) \
		pbuild/linux-unpacked-chroot-script.sh \
		$(FEATURESETS_DISABLED)
#	# Build the source tree and clean up
	cd src/linux/build && debian/rules orig
	cd src/linux/build && debian/rules clean
	touch $@

clean-linux-kernel-package-configured: \
		clean-linux-kernel-source-package
	@echo "cleaning up linux kernel source directory"
	rm -rf src/linux/build
	rm -rf src/linux/orig
	rm -f src/linux/linux_*.orig.tar.xz
	rm -f stamps/5.3.linux-kernel-package-configured
CLEAN_TARGETS += clean-linux-kernel-package-configured

# 5.4. Build Linux kernel source package
stamps/5.4.linux-kernel-source-package: \
		stamps/5.1.linux-kernel-package-checkout \
		stamps/5.3.linux-kernel-package-configured
	@echo "===== 5.4. All variants:  Building Linux source package ====="
	$(REASON)
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
# Use the PPA with featureset devel packages
%/.stamp.5.5.linux-kernel-build: \
		%/.stamp.4.2.chroot-update \
		stamps/5.4.linux-kernel-source-package
	@echo "===== 5.5. $(@D):  Building Linux binary package ====="
	$(REASON)
	$(SUDO) DIST=$(*D) ARCH=$(*F) INTERMEDIATE_REPO=$*/ppa \
	    $(PBUILD) --build \
		$(PBUILD_ARGS) \
	        src/linux/linux_*.dsc || \
	    (rm -f $@ && exit 1)
	touch $@
.PRECIOUS: %/.stamp.5.5.linux-kernel-build

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
	$(REASON)
#	# be sure the submodule has been checked out
	git submodule update --recursive --init git/linux-tools-deb
	touch $@

clean-linux-tools-package-checkout: \
		clean-linux-tools-unpacked
	@echo "cleaning up linux-tools git submodule directory"	
	rm -rf git/linux-tools-deb; mkdir -p git/linux-tools-deb
	rm -f stamps/6.1.linux-tools-package-checkout
SQUEAKY_CLEAN_TARGETS += clean-linux-tools-package-checkout

# 6.2. Prepare linux-tools tarball and prepare source tree
stamps/6.2.linux-tools-unpacked: \
		stamps/0.1.base-builddeps \
		stamps/5.2.linux-kernel-tarball-downloaded \
		stamps/6.1.linux-tools-package-checkout
	@echo "===== 6.2. All variants: " \
	    "Unpacking linux-tools source directory ====="
	$(REASON)
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
	rm -rf src/linux-tools/build
	rm -rf src/linux-tools/orig
	rm -f src/linux/linux-tools_*.orig.tar.xz
	rm -f stamps/6.2.linux-tools-unpacked
CLEAN_TARGETS += clean-linux-tools-unpacked

# 6.3. Build linux-tools source package
stamps/6.3.linux-tools-source-package: \
		stamps/6.2.linux-tools-unpacked
	@echo "===== 6.3. All variants: " \
	    "Building linux-tools source package ====="
	$(REASON)
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
		stamps/6.3.linux-tools-source-package
	@echo "===== 6.4. $(@D):  Building linux-tools binary package ====="
	$(REASON)
	$(SUDO) DIST=$(*D) ARCH=$(*F) INTERMEDIATE_REPO=$*/ppa \
	    $(PBUILD) --build \
		$(PBUILD_ARGS) \
	        src/linux-tools/linux-tools_*.dsc
	touch $@
.PRECIOUS: %/.stamp.6.4.linux-tools-build

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
	rm -rf $*/aptcache
squeaky-clean-caches: \
		$(call CA_EXPAND,%/squeaky-clean-caches)
	@echo "Removing ccache"
	rm -rf ccache
	@echo "Removing unpacked chroots"
	rm -rf tmp/*

# Expand the list of ARCH_SQUEAKY_CLEAN_TARGETS
SQUEAKY_CLEAN_TARGETS += $(foreach t,$(ARCH_SQUEAKY_CLEAN_TARGETS),\
	$(call CA_EXPAND,%/$(t)))
squeaky-clean: \
		$(CLEAN_TARGETS) \
		$(SQUEAKY_CLEAN_TARGETS) \
		squeaky-clean-caches
