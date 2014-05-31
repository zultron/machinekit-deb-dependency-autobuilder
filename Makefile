
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
	wheezy-amd64 \
	wheezy-i386 \
	wheezy-armhf \
	jessie-amd64 \
	jessie-i386
# Precise doesn't have gcc 4.7; using gcc 4.6 might be the cause of
# the kernel module problems I've been finding
	# precise-amd64 \
	# precise-i386 \

# Define this to have a deterministic chroot for step 5.4
A_CHROOT = wheezy-amd64

# List of all featuresets
FEATURESETS = \
    xenomai.x86 \
    xenomai.beaglebone \
#    rtai

# Explicitly define featureset list to enable; default all
FEATURESETS_ENABLED = xenomai.beaglebone xenomai.x86

# Debian package signature keys
UBUNTU_KEYID = 40976EAF437D05B5
DEBIAN_KEYID = 8B48AD6246925553
KEYIDS = $(UBUNTU_KEYID) $(DEBIAN_KEYID)
KEYSERVER = hkp://keys.gnupg.net

# Linux vanilla tarball
LINUX_PKG_RELEASE = 1mk
LINUX_VERSION = 3.8.13
LINUX_URL = http://www.kernel.org/pub/linux/kernel/v3.0

# Xenomai package
XENOMAI_PKG_RELEASE = 1mk
XENOMAI_VERSION = 2.6.3
XENOMAI_URL = http://download.gna.org/xenomai/stable

# Your "Firstname Lastname <email@address>"; leave out to use git config
#MAINTAINER = John Doe <jdoe@example.com>

# Uncomment to remove dependencies on Makefile and pbuilderrc while
# hacking this script
DEBUG = yes

###################################################
# Variables that should not change much
# (or auto-generated)

# Misc paths, filenames, executables
TOPDIR := $(shell pwd)
SUDO := sudo
LINUX_TARBALL := linux-$(LINUX_VERSION).tar.xz
LINUX_TARBALL_DEBIAN_ORIG := linux_$(LINUX_VERSION).orig.tar.xz
LINUX_NAME_EXT := $(shell echo $(LINUX_VERSION) | sed 's/\.[0-9]*$$//')
LINUX_PKG_VERSION = $(LINUX_VERSION)-$(LINUX_PKG_RELEASE)~$(CODENAME)1
LINUX_TOOLS_TARBALL_DEBIAN_ORIG := linux-tools_$(LINUX_VERSION).orig.tar.xz
LINUX_TOOLS_NAME_EXT := $(shell echo $(LINUX_VERSION) | sed 's/\.[0-9]*$$//')
LINUX_TOOLS_PKG_NAME := linux-tools-$(LINUX_TOOLS_NAME_EXT)
LINUX_KBUILD_PKG_NAME := linux-kbuild-$(LINUX_TOOLS_NAME_EXT)
XENOMAI_TARBALL := xenomai-$(XENOMAI_VERSION).tar.bz2
XENOMAI_TARBALL_DEBIAN_ORIG := xenomai_$(XENOMAI_VERSION).orig.tar.bz2
XENOMAI_PKG_VERSION = $(XENOMAI_VERSION)-$(XENOMAI_PKG_RELEASE)~$(CODENAME)1

KEYRING := $(TOPDIR)/admin/keyring.gpg

# Pass any 'DEBBUILDOPTS=foo' arg into dpkg-buildpackage
DEBBUILDOPTS_ARG = $(if $(DEBBUILDOPTS),--debbuildopts "$(DEBBUILDOPTS)")

# pbuilder command line
PBUILD = TOPDIR=$(TOPDIR) DIST=$(CODENAME) ARCH=$(ARCH) pbuilder
PBUILD_ARGS = --configfile pbuild/pbuilderrc --allow-untrusted \
	$(DEBBUILDOPTS_ARG)

# A handy way to expand 'pattern-%' with all codename/arch combos
CA_EXPAND = $(patsubst %,$(1),$(ALL_CODENAMES_ARCHES))

# Auto generate Maintainer: field if not set above
MAINTAINER ?= $(shell git config user.name) <$(shell git config user.email)>

# Set this variable to the stamp name of the last target of each
# codename/arch; used by the default target
FINAL_STEP = stamps/7.2.ppa-final
ALLSTAMPS := $(FINAL_STEP)

# All featuresets enabled by default
FEATURESETS_ENABLED ?= $(FEATURESETS)
# Disabled featuresets
FEATURESETS_DISABLED = $(filter-out $(FEATURESETS_ENABLED),$(FEATURESETS))

# Set $(CODENAME) and $(ARCH) for all stamps/x.y.%.foo targets
define setca
ARCH_$(1) = $(shell echo $(1) | sed 's/.*-//')
CODENAME_$(1) = $(shell echo $(1) | sed 's/-.*//')
endef
$(foreach ca,$(ALL_CODENAMES_ARCHES),$(eval $(call setca,$(ca))))
stamps/% clean-%: ARCH = $(ARCH_$*)
stamps/% clean-%: CODENAME = $(if $(CODENAME_$*),$(CODENAME_$*),$(CA))
stamps/% clean-%: CA = $(*)

# Lists of codenames and arches and functions to expand them
uniq = $(if $1,$(firstword $1) $(call uniq,$(filter-out $(firstword $1),$1)))
CODENAMES = $(call uniq,$(foreach ca,$(ALL_CODENAMES_ARCHES),$(CODENAME_$(ca))))
ARCHES = $(call uniq,$(foreach ca,$(ALL_CODENAMES_ARCHES),$(ARCH_$(ca))))
CODENAME_ARCHES = $(call uniq,$(strip \
	$(foreach ca,$(ALL_CODENAMES_ARCHES),\
	  $(if $(findstring $(CODENAME_$(ca)),$(1)),$(ARCH_$(ca))))))
C_EXPAND = $(patsubst %,$(1),$(CODENAMES))
A_EXPAND = $(patsubst %,$(1),$(ARCHES))

# Auto-generate rules like:
# 1.wheezy-amd64.bar: 0.wheezy.foo
# ...using:
# $(call CA_TO_C_DEPS,1.%.bar,0.%.foo)
#
# This is handy when an arch-specific rule pattern depends on a
# non-arch-specific rule pattern, and codename decoupling is desired
define CA_TO_C_DEP
$(patsubst %,$(1),$(3)): $(foreach d,$(2),$(patsubst %,$(d),$(CODENAME_$(3))))
endef
define CA_TO_C_DEPS
$(foreach ca,$(ALL_CODENAMES_ARCHES),\
	$(eval $(call CA_TO_C_DEP,$(1),$(2),$(ca))))
endef

# Auto-generate rules like:
# 1.wheezy.bar: 0.wheezy-i386.foo 0.wheezy-amd64.foo
# ...using:
# $(call C_TO_CA_DEPS,1.%.bar,0.%.foo)
#
# This is handy when an indep rule pattern depends on a
# arch rule pattern, and codename decoupling is desired
define C_TO_CA_DEP
$(patsubst %,$(1),$(3)): $(strip \
	$(foreach a,$(ARCHES),\
	  $(if $(findstring $(3)-$(a),$(ALL_CODENAMES_ARCHES)),\
	    $(patsubst %,$(2),$(3)-$(a)))))
endef
define C_TO_CA_DEPS
$(foreach dep,$(2),\
  $(foreach c,$(CODENAMES),$(eval $(call C_TO_CA_DEP,$(1),$(dep),$(c)))))
endef

# A random chroot to build the linux source package in
A_CHROOT ?= $(wordlist 1,1,$(ALL_CODENAMES_ARCHES))
AN_ARCH = $(ARCH_$(A_CHROOT))
A_CODENAME = $(CODENAME_$(A_CHROOT))

# The reprepro command and args
REPREPRO = reprepro -VV \
	-b ppa --confdir +b/conf-$(CODENAME) --dbdir +b/db-$(CODENAME)

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

test:
	@echo ALLSTAMPS:
	@for i in $(ALLSTAMPS); do echo "    $$i"; done

###################################################
# PPA rules (reusable)

# generate a PPA including all packages build thus far
# (call BUILD_PPA,<index>,<src-pkg>,<pkg.dsc>,<pkg.deb> ...)
define BUILD_PPA
	@echo "===== $(1). $(CODENAME):  Adding $(2) packages to PPA ====="
	$(REASON)
#	# Remove packages if they exist
	$(REPREPRO) \
	    removesrc $(CODENAME) $(2)
#	# Add source package
	$(REPREPRO) -C main \
	    includedsc $(CODENAME) $(3)
#	# Add binary packages
	$(REPREPRO) -C main \
	    includedeb $(CODENAME) $(4)
	touch $@
endef

# list a PPA's packages for a distro
define LIST_PPA
	@echo "===== $(1). $(CODENAME):  Listing $(2) PPA ====="
	$(REASON)
	$(REPREPRO) \
	    list $(CODENAME)
endef

# Clean a PPA's packages for a distro
define CLEAN_PPA
	@echo "===== $(1). $(CODENAME):  Listing $(2) PPA ====="
	$(REASON)
	$(REPREPRO) \
	    list $(CODENAME)
endef

# Update base.tgz with PPA pkgs
define UPDATE_CHROOT
	@echo "===== $(1). $(CA): " \
	    "Updating pbuilder chroot with PPA packages ====="
	$(REASON)
	$(SUDO) INTERMEDIATE_REPO=ppa \
	    $(PBUILD) --update --override-config \
		$(PBUILD_ARGS)
	touch $@
endef

###################################################
# 0. Basic build dependencies
#
# 0.1 Generic target for non-<codename>/<arch>-specific targets
stamps/0.1.base-builddeps:
	mkdir -p admin git dist src stamps pkgs aptcache chroots logs
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
SQUEAKY_CLEAN_TARGETS += clean-base-builddeps

# 0.2 Init distro ppa directories and configuration
$(call C_EXPAND,stamps/0.2.%.ppa-init): \
stamps/0.2.%.ppa-init:
	@echo "===== 0.2.  $(CODENAME):  Init ppa directories ====="
	mkdir -p ppa/conf-$(CODENAME) ppa/db-$(CODENAME)
	cat pbuild/ppa-distributions.tmpl | sed \
		-e "s/@codename@/$(CODENAME)/g" \
		-e "s/@arch@/$(call CODENAME_ARCHES,$(CODENAME))/g" \
		> ppa/conf-$(CODENAME)/distributions

	touch $@

# 0.3 Init distro ppa
stamps/0.3.all.ppa-init: \
		$(call C_EXPAND,stamps/0.2.%.ppa-init)
	@echo "===== 0.2.  All:  Init ppa directories ====="
	mkdir -p ppa/dists ppa/pool
	touch $@

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

# 2.1.  Build chroot tarball
$(call CA_EXPAND,stamps/2.1.%.chroot-build): \
stamps/2.1.%.chroot-build: \
		stamps/1.1.keyring-downloaded
	@echo "===== 2.1. $(CA):  Creating pbuilder chroot tarball ====="
	$(REASON)
#	# make all the codename/i386 directories needed right here
	mkdir -p pkgs aptcache
#	# create the base.tgz chroot tarball
	$(SUDO) $(PBUILD) --create \
		$(PBUILD_ARGS)
	touch $@
.PRECIOUS:  $(call CA_EXPAND,stamps/2.1.%.chroot-build)

clean.%.chroot:
	@echo "cleaning $(CA) chroot tarball"
	rm -f chroots/base-$(CA).tgz
	rm -f stamps/2.1-$(CA)-chroot-build
ARCH_SQUEAKY_CLEAN_TARGETS += clean-chroot

###################################################
# Log into chroot

$(call CA_EXPAND,%.chroot): \
%.chroot: \
		stamps/2.1.%.chroot-build
	@echo "===== Logging into $(*) pbuilder chroot ====="
	$(REASON)
	$(SUDO) INTERMEDIATE_REPO=ppa \
	    $(PBUILD) --login \
		--bindmounts $(TOPDIR) \
		$(PBUILD_ARGS)
.PHONY:  $(call CA_EXPAND,%.chroot)

###################################################
# 3.0. Xeno build rules

# 3.0.1. Download Xenomai tarball distribution
stamps/3.0.1.xenomai-tarball-download: \
		stamps/0.1.base-builddeps
	@echo "===== 3.0.1. All variants:  Downloading Xenomai tarball ====="
	$(REASON)
	mkdir -p dist
	wget $(XENOMAI_URL)/$(XENOMAI_TARBALL) -O dist/$(XENOMAI_TARBALL)
	mkdir -p src/xenomai
	ln -f dist/$(XENOMAI_TARBALL) \
	    src/xenomai/$(XENOMAI_TARBALL_DEBIAN_ORIG)
	touch $@
.PRECIOUS: stamps/3.0.1.xenomai-tarball-download

clean-xenomai-tarball-download: \
		clean-xenomai-source-package
	@echo "cleaning up xenomai tarball"
	rm -f dist/$(XENOMAI_TARBALL)
	rm -f stamps/3.0.1.xenomai-tarball-download
SQUEAKY_CLEAN_TARGETS += clean-xenomai-tarball-download

# 3.0.2. Build Xenomai source package for each distro
XENO_SOURCE_STAMPS := $(call C_EXPAND,stamps/3.0.2.%.xenomai-build-source)
$(XENO_SOURCE_STAMPS): stamps/3.0.2.%.xenomai-build-source: \
		stamps/3.0.1.xenomai-tarball-download
	@echo "===== 3.0.2. $(CODENAME)-all: " \
	    "Building Xenomai source package ====="
	rm -rf src/xenomai/$(CODENAME); mkdir -p src/xenomai/$(CODENAME)
	tar xC src/xenomai/$(CODENAME) \
	    -f src/xenomai/$(XENOMAI_TARBALL_DEBIAN_ORIG) \
	    --strip-components=1
	cd src/xenomai/$(CODENAME) && \
	    $(TOPDIR)/pbuild/tweak-pkg.sh \
	    $(CODENAME) $(XENOMAI_PKG_VERSION) "$(MAINTAINER)"
	cd pkgs && dpkg-source -i -I \
	    -b $(TOPDIR)/src/xenomai/$(CODENAME)
	touch $@
.PRECIOUS: $(XENO_SOURCE_STAMPS)
XENOMAI_ARTIFACTS_INDEP += stamps/3.0.2.%.xenomai-build-source

clean.%.xenomai-build-source: \
		$(call CA_EXPAND,%/clean-xenomai-build)
	@echo "cleaning up xenomai source package for $(CODENAME)"
	rm -f src/xenomai/xenomai_*.dsc
	rm -f src/xenomai/xenomai_*.tar.gz
	rm -f stamps/3.0.2-$(CODENAME)-xenomai-source-package
ARCH_CLEAN_TARGETS += xenomai-build-source

# 3.0.3. Build Xenomai binary packages for each distro/arch
#   But only build binary-indep packages once:
stamps/3.0.3.%.xenomai-build-binary: \
	BUILDTYPE = $(if $(findstring $(ARCH),$(AN_ARCH)),-b,-A)
#   Depend on the Xenomai source package build for the matching codename
$(call CA_TO_C_DEPS,stamps/3.0.3.%.xenomai-build-binary,\
	stamps/3.0.2.%.xenomai-build-source)
#   List of Xenomai all codename-arch binary package targets
XENO_BINARY_STAMPS := $(call CA_EXPAND,stamps/3.0.3.%.xenomai-build-binary)
$(XENO_BINARY_STAMPS): \
stamps/3.0.3.%.xenomai-build-binary: stamps/2.1.%.chroot-build
	@echo "===== 3.0.3. $(CA): " \
	    "Building Xenomai binary packages ====="
	$(REASON)
	$(SUDO) $(PBUILD) \
	    --build \
	    $(PBUILD_ARGS) \
	    --debbuildopts $(BUILDTYPE) \
	    pkgs/xenomai_$(XENOMAI_PKG_VERSION).dsc
	touch $@
.PRECIOUS: $(XENO_BINARY_STAMPS)

clean.%.xenomai-build:
	@echo "cleaning up $(CA) xenomai binary-build"
	rm -f $*/pkgs/xenomai_*_$(ARCH).build
	rm -f $*/pkgs/xenomai_*_$(ARCH).changes
	rm -f $*/pkgs/xenomai_*.dsc
	rm -f $*/pkgs/xenomai_*.tar.gz
	rm -f $*/pkgs/xenomai-doc_*.deb
	rm -f $*/pkgs/xenomai-runtime_*.deb
	rm -f $*/pkgs/linux-patch-xenomai_*.deb
	rm -f $*/pkgs/libxenomai1_*.deb
	rm -f $*/pkgs/libxenomai-dev_*.deb
	rm -f stamps/3.0.3-$*-xenomai-build
ARCH_CLEAN_TARGETS += xenomai-build

# 3.0.4. Add Xenomai packages to the PPA for each distro
$(call C_TO_CA_DEPS,stamps/3.0.4.%.xenomai-ppa,\
	stamps/3.0.3.%.xenomai-build-binary)
$(call C_EXPAND,stamps/3.0.4.%.xenomai-ppa): \
stamps/3.0.4.%.xenomai-ppa: \
		stamps/3.0.2.%.xenomai-build-source \
		stamps/0.3.all.ppa-init
	$(call BUILD_PPA,3.0.4,xenomai,\
	    pkgs/xenomai_$(XENOMAI_PKG_VERSION).dsc,\
	    pkgs/xenomai-doc_$(XENOMAI_PKG_VERSION)_all.deb \
	    pkgs/xenomai-kernel-source_$(XENOMAI_PKG_VERSION)_all.deb \
	    $(foreach a,$(call CODENAME_ARCHES,$(CODENAME)),$(wildcard\
		pkgs/libxenomai-dev_$(XENOMAI_PKG_VERSION)_$(a).deb \
		pkgs/libxenomai1_$(XENOMAI_PKG_VERSION)_$(a).deb \
		pkgs/xenomai-runtime_$(XENOMAI_PKG_VERSION)_$(a).deb)))
XENOMAI_ARTIFACTS += stamps/3.0.4.%.xenomai-ppa

###################################################
# 3.1. RTAI build rules

# 3.1.1. clone & update the rtai submodule
stamps/3.1.1.rtai-source-checkout: \
		stamps/0.1.base-builddeps
	@echo "===== 3.1.1. All variants:  Checking out RTAI git repo ====="
	$(REASON)
	mkdir -p git/rtai
#	# be sure the submodule has been checked out
	test -f git/rtai/.git || \
           git submodule update --init -- git/rtai
	git submodule update git/rtai
	touch $@
.PRECIOUS: stamps/3.1.1.rtai-source-checkout

clean-rtai-source-checkout: \
		clean-rtai-source-package
	@echo "cleaning up RTAI git submodule directory"
	rm -rf git/rtai; mkdir -p git/rtai
	rm -f stamps/3.1.1.rtai-source-checkout
SQUEAKY_CLEAN_TARGETS += clean-rtai-source-checkout

# 3.1.2. clone & update the rtai-deb submodule
stamps/3.1.2.rtai-deb-source-checkout: \
		stamps/0.1.base-builddeps
	@echo "===== 3.1.2. All variants: " \
	    "Checking out RTAI Debian git repo ====="
	$(REASON)
	mkdir -p git/rtai-deb
#	# be sure the submodule has been checked out
	test -f git/rtai-deb/.git || \
           git submodule update --init -- git/rtai-deb
	git submodule update git/rtai-deb
	touch $@
.PRECIOUS: stamps/3.1.2.rtai-deb-source-checkout

clean-rtai-deb-source-checkout: \
		clean-rtai-source-package
	@echo "cleaning up RTAI Debian git submodule directory"
	rm -rf git/rtai-deb; mkdir -p git/rtai-deb
	rm -f stamps/3.1.2.rtai-deb-source-checkout
SQUEAKY_CLEAN_TARGETS += clean-rtai-deb-source-checkout

# 3.1.3. Build RTAI orig source tarball
stamps/3.1.3.rtai-source-tarball: \
		stamps/3.1.1.rtai-source-checkout
	@echo "===== 3.1.3. All variants:  Building RTAI source tarball ====="
	$(REASON)
	mkdir -p src/rtai
	rm -f src/rtai/rtai_*.orig.tar.gz
	RTAI_VER=`sed -n '1 s/rtai *(\([0-9.][0-9.]*\).*/\1/p' \
		git/rtai-deb/changelog` && \
	git --git-dir="git/rtai/.git" archive HEAD | \
	    gzip > src/rtai/rtai_$${RTAI_VER}.orig.tar.gz
	touch $@
.PRECIOUS: stamps/3.1.3.rtai-source-tarball

clean-rtai-source-tarball: \
		clean-rtai-source-package
	@echo "cleaning up unpacked rtai source"
	rm -f src/rtai/rtai_*.dsc
	rm -f src/rtai/rtai_*.tar.gz
	rm -f stamps/3.1.3.rtai-source-tarball
CLEAN_TARGETS += clean-rtai-source-tarball

# 3.1.4. Build RTAI source package
stamps/3.1.4.rtai-source-package: \
		stamps/3.1.2.rtai-deb-source-checkout \
		stamps/3.1.3.rtai-source-tarball
	@echo "===== 3.1.4. All variants:  Build RTAI source package ====="
	$(REASON)
	rm -rf src/rtai/build; mkdir -p src/rtai/build
	rm -f src/rtai/rtai_*.dsc
	rm -f src/rtai/rtai_*.debian.tar.gz
	tar xzCf src/rtai/build src/rtai/rtai_*.orig.tar.gz
	git --git-dir="git/rtai-deb/.git" archive --prefix=debian/ HEAD | \
	    tar xCf src/rtai/build -
	cd src/rtai && dpkg-source -i -I -b build
	touch $@
.PRECIOUS: stamps/3.1.4.rtai-source-package

clean-rtai-source-package: \
		$(call CA_EXPAND,%/clean-rtai-build)
	rm -rf src/rtai/build
	rm -f stamps/3.1.4.rtai-source-package
CLEAN_TARGETS += clean-rtai-source-tarball

# 3.1.5. Build the RTAI binary packages
%/.stamp.3.1.5.rtai-build: \
		%/.stamp.2.1.chroot-build \
		stamps/3.1.4.rtai-source-package
	@echo "===== 3.1.5. $(CA):  Building RTAI binary packages ====="
	$(REASON)
#	# ARM arch is broken
#	# jessie is broken (no libcomedi)
	test $(ARCH) = armhf -o $(CODENAME) = jessie || \
	    $(SUDO) $(PBUILD) \
		--build $(PBUILD_ARGS) \
	        src/rtai/rtai_*.dsc
	touch $@
.PRECIOUS: %/.stamp.3.1.5.rtai-build

%/clean-rtai-build:
	@echo "cleaning up $* rtai binary-build"
# FIXME
	# rm -f $*/pkgs/xenomai_*.build
	# rm -f $*/pkgs/xenomai_*.changes
	# rm -f $*/pkgs/xenomai_*.dsc
	# rm -f $*/pkgs/xenomai_*.tar.gz
	# rm -f $*/pkgs/xenomai-doc_*.deb
	# rm -f $*/pkgs/xenomai-runtime_*.deb
	# rm -f $*/pkgs/linux-patch-xenomai_*.deb
	# rm -f $*/pkgs/libxenomai1_*.deb
	# rm -f $*/pkgs/libxenomai-dev_*.deb
	# rm -f $*/.stamp.3.3.xenomai-build
	exit 1
ARCH_CLEAN_TARGETS += xenomai-build

# Hook into rest of build
ifneq ($(filter rtai,$(FEATURESETS_ENABLED)),)
PPA_INTERMEDIATE_DEPS += %/.stamp.3.1.5.rtai-build
endif

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

# 5.3. Update chroot with Xenomai packages
$(call CA_EXPAND,stamps/5.3.%.linux-kernel-xenomai-update-chroot,\
	$(XENOMAI_ARTIFACTS)): \
stamps/5.3.%.linux-kernel-xenomai-update-chroot: \
		stamps/5.1.linux-kernel-package-checkout \
		stamps/5.2.linux-kernel-tarball-downloaded
	$(call UPDATE_CHROOT,5.3)
.PRECIOUS: $(call CA_EXPAND,stamps/5.3.%.linux-kernel-xenomai-update-chroot)

# 5.4. Unpack and configure Linux package source tree
#
# This has to be done in a chroot with the featureset packages
stamps/5.4.linux-kernel-package-configured: CODENAME = $(A_CODENAME)
stamps/5.4.linux-kernel-package-configured: ARCH = $(AN_ARCH)
stamps/5.4.linux-kernel-package-configured: \
		stamps/5.3.$(A_CHROOT).linux-kernel-xenomai-update-chroot
	@echo "===== 5.4. All:  Unpacking and configuring" \
	    " Linux source package ====="
	$(REASON)
#	# Starting clean, copy debian packaging and hardlink source tarball
	rm -rf src/linux/build; mkdir -p src/linux/build
	git --git-dir="git/kernel-rt-deb2/.git" archive --prefix=debian/ HEAD \
	    | tar xCf src/linux/build -
#	# Configure the package in a chroot
	chmod +x pbuild/linux-unpacked-chroot-script.sh
	$(SUDO) INTERMEDIATE_REPO=ppa \
	    $(PBUILD) \
		--execute --bindmounts ${TOPDIR}/src/linux \
		$(PBUILD_ARGS) \
		pbuild/linux-unpacked-chroot-script.sh \
		$(FEATURESETS_DISABLED)
#	# Hardlink linux tarball with Debian-format path name
	ln -f dist/$(LINUX_TARBALL) \
	    pkgs/$(LINUX_TARBALL_DEBIAN_ORIG)
	ln -f dist/$(LINUX_TARBALL) \
	    src/linux/$(LINUX_TARBALL_DEBIAN_ORIG)
#	# Make copy of changelog for later munging
	cp --preserve=all src/linux/build/debian/changelog src/linux
#	# Build the source tree and clean up
	cd src/linux/build && debian/rules orig
	cd src/linux/build && debian/rules clean
	touch $@
.PRECIOUS: stamps/5.4.linux-kernel-package-configured

clean-linux-kernel-package-configured: \
		clean-linux-kernel-source-package
	@echo "cleaning up linux kernel source directory"
	rm -rf src/linux/build
	rm -rf src/linux/orig
	rm -f src/linux/linux_*.orig.tar.xz
	rm -f stamps/5.4.linux-kernel-package-configured
CLEAN_TARGETS += clean-linux-kernel-package-configured

# 5.5. Build Linux kernel source package for each distro
$(call C_EXPAND,stamps/5.5.%.linux-kernel-source-package): \
stamps/5.5.%.linux-kernel-source-package: \
		stamps/5.1.linux-kernel-package-checkout \
		stamps/5.4.linux-kernel-package-configured
	@echo "===== 5.5. $(CODENAME)-all: " \
	    "Building Linux source package ====="
	$(REASON)
#	# Restore original changelog
	cp --preserve=all src/linux/changelog src/linux/build/debian
#	# Add changelog entry
	cd src/linux/build && \
	    $(TOPDIR)/pbuild/tweak-pkg.sh \
	    $(CODENAME) $(LINUX_PKG_VERSION) "$(MAINTAINER)"
#	# Create source pkg
	cd src/linux/build && dpkg-source -i -I -b .
	mv src/linux/linux_$(LINUX_PKG_VERSION).debian.tar.xz \
	    src/linux/linux_$(LINUX_PKG_VERSION).dsc pkgs
	touch $@
.PRECIOUS: $(call C_EXPAND,stamps/5.5.%.linux-kernel-source-package)

clean-linux-kernel-source-package: \
		$(call CA_EXPAND,%/clean-linux-kernel-build)
	@echo "cleaning up linux kernel source package"
	rm -f src/linux/linux_*.debian.tar.xz
	rm -f src/linux/linux_*.orig.tar.xz
	rm -f src/linux/linux_*.dsc
	rm -f stamps/5.5.linux-kernel-source-package
CLEAN_TARGETS += clean-linux-kernel-source-package

# 5.6. Build kernel packages for each distro/arch
#
# Use the PPA with featureset devel packages
$(call CA_TO_C_DEPS,stamps/5.6.%.linux-kernel-build,\
	stamps/5.5.%.linux-kernel-source-package)

$(call CA_EXPAND,stamps/5.6.%.linux-kernel-build): \
stamps/5.6.%.linux-kernel-build: stamps/4.2.%.chroot-update
	@echo "===== 5.6. $(CA):  Building Linux binary package ====="
	$(REASON)
	$(SUDO) INTERMEDIATE_REPO=ppa \
	    $(PBUILD) --build \
		$(PBUILD_ARGS) \
	        pkgs/linux_$(LINUX_PKG_VERSION).dsc || \
	    (rm -f $@ && exit 1)
	touch $@
.PRECIOUS: $(call CA_EXPAND,stamps/5.6.%.linux-kernel-build)
LINUX_ARTIFACTS_ARCH += stamps/5.6.%.linux-kernel-build

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
	rm -f $*/.stamp.5.6.linux-kernel-build
ARCH_CLEAN_TARGETS += linux-kernel-build

# 5.7. Add kernel packages to the PPA for each distro
# linux-headers-3.8-1mk-common-xenomai.x86_3.8.13-1mk~wheezy1_i386.deb
# linux-headers-3.8-1mk-xenomai.x86-686-pae_3.8.13-1mk~wheezy1_i386.deb
# linux-image-3.8-1mk-xenomai.x86-686-pae_3.8.13-1mk~wheezy1_i386.deb
$(call C_TO_CA_DEPS,stamps/5.7.%.linux-kernel-ppa,\
	stamps/5.6.%.linux-kernel-build)
$(call C_EXPAND,stamps/5.7.%.linux-kernel-ppa): \
stamps/5.7.%.linux-kernel-ppa: \
		stamps/5.5.%.linux-kernel-source-package \
		stamps/0.3.all.ppa-init
	$(call BUILD_PPA,5.7,linux,\
	    pkgs/linux_$(LINUX_PKG_VERSION).dsc,\
	    $(foreach a,$(call CODENAME_ARCHES,$(CODENAME)),$(wildcard\
		pkgs/linux-headers-*_$(LINUX_PKG_VERSION)_$(a).deb \
		pkgs/linux-image-*_$(LINUX_PKG_VERSION)_$(a).deb)))
LINUX_KERNEL_ARTIFACTS += stamps/5.7.%.linux-kernel-ppa

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
#	# Make copy of changelog for later munging
	cp --preserve=all src/linux-tools/build/debian/changelog \
	    src/linux-tools
#	# Build the source tree and clean up
	cd src/linux-tools/build && debian/rules orig
	cd src/linux-tools/build && debian/rules clean
#	# Hardlink linux-tools tarball with Debian-format path name
	ln -f src/linux-tools/orig/$(LINUX_TOOLS_TARBALL_DEBIAN_ORIG) \
	    pkgs/$(LINUX_TOOLS_TARBALL_DEBIAN_ORIG)
	touch $@

stamps/6.2.linux-tools-unpacked-clean: \
		$(call C_EXPAND,stamps/6.3.%.linux-tools-source-package-clean)
	@echo "6.2.  All:  Cleaning up linux-tools unpacked sources"
	rm -rf src/linux-tools
	rm -f pkgs/linux-tools_$(LINUX_VERSION).orig.tar.xz
	rm -f stamps/6.2.linux-tools-unpacked

# 6.3. Build linux-tools source package for each distro
$(call C_EXPAND,stamps/6.3.%.linux-tools-source-package): \
stamps/6.3.%.linux-tools-source-package: \
		stamps/6.2.linux-tools-unpacked
	@echo "===== 6.3. $(CODENAME)-all: " \
	    "Building linux-tools source package ====="
	$(REASON)
#	# Restore original changelog
	cp --preserve=all src/linux-tools/changelog \
	    src/linux-tools/build/debian
#	# Add changelog entry
	cd src/linux-tools/build && \
	    $(TOPDIR)/pbuild/tweak-pkg.sh \
	    $(CODENAME) $(LINUX_PKG_VERSION) "$(MAINTAINER)"
#	# create source pkg
	cd src/linux-tools/build && dpkg-source -i -I -b .
	mv src/linux-tools/linux-tools_$(LINUX_PKG_VERSION).debian.tar.xz \
	    src/linux-tools/linux-tools_$(LINUX_PKG_VERSION).dsc pkgs
	touch $@
.PRECIOUS: $(call C_EXPAND,stamps/6.3.%.linux-tools-source-package)

$(call C_EXPAND,stamps/6.3.%.linux-tools-source-package-clean): \
stamps/6.3.%.linux-tools-source-package-clean:
	@echo "6.3. $(CODENAME):  Cleaning up linux-tools source package"
	rm -f pkgs/linux-tools_$(LINUX_PKG_VERSION).debian.tar.xz
	rm -f pkgs/linux-tools_$(LINUX_PKG_VERSION).dsc
	rm -f stamps/6.3.$(CODENAME).linux-tools-source-package
$(call C_TO_CA_DEPS,stamps/6.3.%.linux-tools-source-package-clean,\
	stamps/6.4.%.linux-tools-build-clean)


# 6.4. Build linux-tools binary packages for each distro/arch against
# distro src pkg
$(call CA_TO_C_DEPS,stamps/6.4.%.linux-tools-build,\
	stamps/6.3.%.linux-tools-source-package)

$(call CA_EXPAND,stamps/6.4.%.linux-tools-build): \
stamps/6.4.%.linux-tools-build:
	@echo "===== 6.4. $(CA):  Building linux-tools binary package ====="
	$(REASON)
	$(SUDO) INTERMEDIATE_REPO=ppa \
	    $(PBUILD) --build \
		$(PBUILD_ARGS) \
	        pkgs/linux-tools_$(LINUX_PKG_VERSION).dsc
	touch $@
.PRECIOUS: $(call CA_EXPAND,stamps/6.4.%.linux-tools-build)

stamps/6.4.%.linux-tools-build-clean:
	@echo "6.4. $(CA):  Cleaning up linux-tools binary build"
	rm -f pkgs/linux-tools-*_$(LINUX_PKG_VERSION)_$(ARCH).deb
	rm -f pkgs/linux-kbuild-*_$(LINUX_PKG_VERSION)_$(ARCH).deb
	rm -f pkgs/linux-tools_$(LINUX_PKG_VERSION)-$(ARCH).build
	rm -f pkgs/linux-tools_$(LINUX_PKG_VERSION)_$(ARCH).changes
	rm -f stamps/6.4.$(CA).linux-tools-build
# Clean up the distro PPA
$(call CA_TO_C_DEPS,stamps/6.4.%.linux-tools-build-clean,\
	stamps/7.1.%.ppa-final-clean)

# 6.5. Add linux-tools binary packages to the PPA for each distro
$(call C_TO_CA_DEPS,stamps/6.5.%.linux-tools-ppa,\
	stamps/6.4.%.linux-tools-build)
$(call C_EXPAND,stamps/6.5.%.linux-tools-ppa): \
stamps/6.5.%.linux-tools-ppa: \
		stamps/6.3.%.linux-tools-source-package \
		stamps/0.3.all.ppa-init
	$(call BUILD_PPA,6.5,Final,linux-tools,\
	    pkgs/linux-tools_$(LINUX_PKG_VERSION).dsc,\
	    $(foreach a,$(call CODENAME_ARCHES,$(CODENAME)),\
		pkgs/$(LINUX_TOOLS_PKG_NAME)_$(LINUX_PKG_VERSION)_$(a).deb \
		pkgs/$(LINUX_KBUILD_PKG_NAME)_$(LINUX_PKG_VERSION)_$(a).deb))
LINUX_TOOLS_ARTIFACTS += stamps/6.5.%.linux-tools-ppa


###################################################
# 100. Final PPA
#
# 100.1. Build final PPA for each distro with distro/arch packages
#
$(call C_EXPAND,stamps/100.1.%.ppa-final): \
stamps/100.1.%.ppa-final: \
		$(XENOMAI_ARTIFACTS) \
		$(LINUX_KERNEL_ARTIFACTS) \
		$(LINUX_TOOLS_ARTIFACTS) \
		pbuild/ppa-distributions.tmpl
	$(call BUILD_PPA,100.1,Final)

$(call C_EXPAND,stamps/100.1.%.ppa-final-list): \
stamps/100.1.%.ppa-final-list:
	$(call LIST_PPA,100.1,Final)

stamps/100.1.%.ppa-final-clean: \
		stamps/100.2.ppa-final-clean
	@echo "100.1. $(CODENAME):  Removing packages from PPA"
	rm -f stamps/100.1.$*.ppa-final


# 100.2.  Tie in all final PPAs for each distro
stamps/100.2.ppa-final: \
		$(call C_EXPAND,stamps/100.1.%.ppa-final)
	@echo "===== 100.2. All:  All packages in PPA ====="
	touch $@

stamps/100.2.ppa-final-clean:
	@echo "100.2. All:  Cleaning up final PPA stamp"
	rm -f stamps/100.2.ppa-final

###################################################
# Clean targets

%/clean: $(foreach t,$(ARCH_CLEAN_TARGETS),%/$(t))
	@echo "Cleaned up $(CA) build artifacts"

# Expand the list of ARCH_CLEAN_TARGETS
CLEAN_TARGETS += $(foreach t,$(ARCH_CLEAN_TARGETS),\
	$(call CA_EXPAND,clean.%.$(t)))
clean: $(CLEAN_TARGETS)

%/squeaky-clean-caches:
	@echo "Removing $(CA) aptcache"
	rm -rf aptcache; mkdir -p aptcache
squeaky-clean-caches: \
		$(call CA_EXPAND,%/squeaky-clean-caches)
	@echo "Removing ccache"
	rm -rf ccache; mkdir -p ccache
	@echo "Removing unpacked chroots"
	rm -rf build; mkdir -p build

# Expand the list of ARCH_SQUEAKY_CLEAN_TARGETS
SQUEAKY_CLEAN_TARGETS += $(foreach t,$(ARCH_SQUEAKY_CLEAN_TARGETS),\
	$(call CA_EXPAND,%/$(t)))
squeaky-clean: \
		$(CLEAN_TARGETS) \
		$(SQUEAKY_CLEAN_TARGETS) \
		squeaky-clean-caches
