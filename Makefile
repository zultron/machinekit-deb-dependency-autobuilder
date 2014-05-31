
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
# Default rule

all:
.PHONY:  all

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

stamps/0.1.clean-base-builddeps:
	rm -f stamps/0.1.base-builddeps
SQUEAKY_ALL += stamps/0.1.clean-base-builddeps


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

$(call C_EXPAND,stamps/0.2.%.ppa-init-squeaky): \
stamps/0.2.%.ppa-init-squeaky:
	@echo "0.2. $(CODENAME):  Removing ppa directories"
	rm -rf ppa/conf-$(CODENAME) ppa/db-$(CODENAME)


# 0.3 Init distro ppa
stamps/0.3.all.ppa-init: \
		$(call C_EXPAND,stamps/0.2.%.ppa-init)
	@echo "===== 0.3.  All:  Init ppa directories ====="
	mkdir -p ppa/dists ppa/pool
	touch $@

stamps/0.3.all.ppa-init-squeaky: \
	$(call C_EXPAND,stamps/0.2.%.ppa-init-squeaky)
	@echo "0.3.  All:  Remove ppa directories"
	rm -rf ppa
SQUEAKY_ALL += stamps/0.3.all.ppa-init-squeaky


###################################################
# 1. GPG keyring

# 1.1 Download GPG keys for the various distros, needed by pbuilder

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

stamps/1.1.keyring-downloaded-clean:
	@echo "1.1. All:  Cleaning package GPG keyring"
	rm -f $(KEYRING)
	rm -f stamps/1.1.keyring-downloaded
SQUEAKY_ALL += stamps/1.1.keyring-downloaded-clean


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

2.1.clean.%.chroot:
	@echo "2.1. $(CA):  Cleaning chroot tarball"
	rm -f chroots/base-$(CA).tgz
	rm -f stamps/2.1-$(CA)-chroot-build
SQUEAKY_ARCH += 2.1.clean.%.chroot


#
# Log into chroot
#
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
	touch $@
.PRECIOUS: stamps/3.0.1.xenomai-tarball-download

stamps/3.0.1.xenomai-tarball-download-squeaky: \
		$(call C_EXPAND,stamps/3.0.2.%.xenomai-build-source-clean)
	@echo "3.0.1. All:  Clean xenomai tarball"
	rm -f dist/$(XENOMAI_TARBALL)
	rm -f stamps/3.0.1.xenomai-tarball-download
XENOMAI_SQUEAKY_ALL += stamps/3.0.1.xenomai-tarball-download-squeaky


# 3.0.1.1. Set up Xenomai sources
stamps/3.0.1.1.xenomai-source-setup: \
		stamps/3.0.1.xenomai-tarball-download
	@echo "===== 3.0.1. All: " \
	    "Setting up Xenomai source ====="
	mkdir -p src/xenomai
	ln -f dist/$(XENOMAI_TARBALL) \
	    src/xenomai/$(XENOMAI_TARBALL_DEBIAN_ORIG)
	touch $@

$(call C_EXPAND,stamps/3.0.1.1.%.xenomai-source-setup-clean): \
stamps/3.0.1.1.%.xenomai-source-setup-clean: \
		$(call C_EXPAND,stamps/3.0.2.%.xenomai-build-source-clean)
	@echo "3.0.1.1. All:  Clean xenomai sources"
	rm -rf src/xenomai
XENOMAI_CLEAN_INDEP += stamps/3.0.1.1.%.xenomai-source-setup-clean


# 3.0.2. Build Xenomai source package for each distro
$(call C_EXPAND,stamps/3.0.2.%.xenomai-build-source): \
stamps/3.0.2.%.xenomai-build-source: \
		stamps/3.0.1.xenomai-source-setup
	@echo "===== 3.0.2. $(CODENAME)-all: " \
	    "Building Xenomai source package ====="
	$(REASON)
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
.PRECIOUS:  $(call C_EXPAND,stamps/3.0.2.%.xenomai-build-source)

$(call C_EXPAND,stamps/3.0.2.%.xenomai-build-source-clean): \
stamps/3.0.2.%.xenomai-build-source-clean:
	@echo "3.0.2. $(CODENAME):  Clean xenomai source package"
	rm -rf src/xenomai/$(CODENAME)
	rm -f pkgs/xenomai_$(XENOMAI_PKG_VERSION).dsc
	rm -f pkgs/$(XENOMAI_TARBALL_DEBIAN_ORIG)
	rm -f pkgs/xenomai_$(XENOMAI_PKG_VERSION).debian.tar.gz
	rm -f pkgs/xenomai_$(XENOMAI_PKG_VERSION)_all.changes
	rm -f stamps/3.0.2-$(CODENAME)-xenomai-build-source
$(call C_TO_CA_DEPS,stamps/3.0.2.%.xenomai-build-source-clean,\
	stamps/3.0.3.%.xenomai-build-binary-clean)
XENOMAI_CLEAN_INDEP += stamps/3.0.2.%.xenomai-build-source-clean


# 3.0.3. Build Xenomai binary packages for each distro/arch
#
#   Only build binary-indep packages once:
stamps/3.0.3.%.xenomai-build-binary: \
	BUILDTYPE = $(if $(findstring $(ARCH),$(AN_ARCH)),-b,-A)

$(call CA_TO_C_DEPS,stamps/3.0.3.%.xenomai-build-binary,\
	stamps/3.0.2.%.xenomai-build-source)
$(call CA_EXPAND,stamps/3.0.3.%.xenomai-build-binary): \
stamps/3.0.3.%.xenomai-build-binary: \
		stamps/2.1.%.chroot-build
	@echo "===== 3.0.3. $(CA): " \
	    "Building Xenomai binary packages ====="
	$(REASON)
	$(SUDO) $(PBUILD) \
	    --build \
	    $(PBUILD_ARGS) \
	    --debbuildopts $(BUILDTYPE) \
	    pkgs/xenomai_$(XENOMAI_PKG_VERSION).dsc
	touch $@
.PRECIOUS: $(call CA_EXPAND,stamps/3.0.3.%.xenomai-build-binary)

$(call CA_EXPAND,stamps/3.0.3.%.xenomai-build-binary-clean): \
stamps/3.0.3.%.xenomai-build-binary-clean:
	@echo "3.0.3. $(CA):  Clean Xenomai binary build"
	rm -f pkgs/libxenomai-dev_$(XENOMAI_PKG_VERSION)_$(ARCH).deb
	rm -f pkgs/libxenomai1_$(XENOMAI_PKG_VERSION)_$(ARCH).deb
	rm -f pkgs/xenomai-runtime_$(XENOMAI_PKG_VERSION)_$(ARCH).deb
	rm -f pkgs/xenomai-doc_$(XENOMAI_PKG_VERSION)_all.deb
	rm -f pkgs/xenomai-kernel-source_$(XENOMAI_PKG_VERSION)_all.deb
	rm -f pkgs/xenomai_$(XENOMAI_PKG_VERSION)-$(ARCH).build
	rm -f pkgs/xenomai_$(XENOMAI_PKG_VERSION)_$(ARCH).changes
	rm -f stamps/3.0.3-$(CA)-xenomai-build
$(call CA_TO_C_DEPS,stamps/3.0.3.%.xenomai-build-binary-clean,\
	stamps/3.0.4.%.xenomai-ppa-clean)


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
XENOMAI_INDEP := stamps/3.0.4.%.xenomai-ppa

$(call C_EXPAND,stamps/3.0.4.%.xenomai-ppa-clean): \
stamps/3.0.4.%.xenomai-ppa-clean:
	@echo "3.0.4. $(CODENAME):  Clean Xenomai PPA stamp"
	rm -f stamps/3.0.4.$(CODENAME).xenomai-ppa


# Hook Xenomai builds into kernel and final builds, if configured
ifneq ($(filter xenomai.%,$(FEATURESETS)),)
LINUX_KERNEL_DEPS_INDEP += $(XENOMAI_INDEP)
FINAL_DEPS_INDEP += $(XENOMAI_INDEP)
SQUEAKY_ALL += $(XENOMAI_SQUEAKY_ALL)
CLEAN_INDEP += $(XENOMAI_CLEAN_INDEP)
endif


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
SQUEAKY_CLEAN += clean-rtai-source-checkout

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
SQUEAKY_CLEAN += clean-rtai-deb-source-checkout

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

stamps/5.1.linux-kernel-package-checkout-clean: \
		$(call CA_EXPAND,\
			stamps/5.3.%.linux-kernel-deps-update-chroot-clean)
	@echo "5.1. All:  Clean linux kernel packaging git submodule stamp"
	rm -f stamps/5.1.linux-kernel-package-checkout

stamps/5.1.linux-kernel-package-checkout-squeaky: \
		stamps/5.1.linux-kernel-package-checkout-clean
	@echo "5.1. All:  Clean linux kernel packaging git submodule"
	rm -rf git/kernel-rt-deb2; mkdir -p git/kernel-rt-deb2
LINUX_SQUEAKY_ALL += stamps/5.1.linux-kernel-package-checkout-squeaky

# 5.2. Download linux tarball
stamps/5.2.linux-kernel-tarball-downloaded: \
		stamps/0.1.base-builddeps
	@echo "===== 5.2. All variants: " \
	    "Downloading vanilla Linux tarball ====="
	$(REASON)
	rm -f dist/$(LINUX_TARBALL)
	wget $(LINUX_URL)/$(LINUX_TARBALL) -O dist/$(LINUX_TARBALL)
	touch $@

stamps/5.2.linux-kernel-tarball-downloaded-clean: \
		$(call CA_EXPAND,\
			stamps/5.3.%.linux-kernel-deps-update-chroot-clean)
	@echo "5.2. All:  Clean up linux kernel tarball"
	rm -f dist/$(LINUX_TARBALL)
	rm -f stamps/5.2.linux-kernel-tarball-downloaded
LINUX_SQUEAKY_ALL += stamps/5.2.linux-kernel-tarball-downloaded


# 5.3. Update chroot with dependent packages
#
# Any indep targets should be added to $(LINUX_KERNEL_DEPS_INDEP), and
# arch or all targets should be added to $(LINUX_KERNEL_DEPS)
$(call CA_TO_C_DEPS,stamps/5.3.%.linux-kernel-deps-update-chroot,\
	$(LINUX_KERNEL_DEPS_INDEP))
$(call CA_EXPAND,stamps/5.3.%.linux-kernel-deps-update-chroot): \
stamps/5.3.%.linux-kernel-deps-update-chroot: \
		stamps/5.1.linux-kernel-package-checkout \
		stamps/5.2.linux-kernel-tarball-downloaded \
		$(LINUX_KERNEL_DEPS)
	$(call UPDATE_CHROOT,5.3)
.PRECIOUS: $(call CA_EXPAND,stamps/5.3.%.linux-kernel-deps-update-chroot)

$(call CA_EXPAND,stamps/5.3.%.linux-kernel-deps-update-chroot-clean): \
stamps/5.3.%.linux-kernel-deps-update-chroot-clean:
	@echo "5.3. $(CA):  Clean linux kernel chroot xenomai update stamp"
	rm -f stamps/5.3.$(CA).linux-kernel-deps-update-chroot
$(call CA_TO_C_DEPS,stamps/5.3.%.linux-kernel-deps-update-chroot-clean,\
	stamps/5.5.%.linux-kernel-source-package-clean)

# Cleaning this cleans up all (non-squeaky) linux arch and indep artifacts
LINUX_CLEAN_ARCH := stamps/5.3.%.linux-kernel-deps-update-chroot-clean


# 5.4. Unpack and configure Linux package source tree
#
# This has to be done in a chroot with the featureset packages
stamps/5.4.linux-kernel-package-configured: CODENAME = $(A_CODENAME)
stamps/5.4.linux-kernel-package-configured: ARCH = $(AN_ARCH)
stamps/5.4.linux-kernel-package-configured: \
		stamps/5.3.$(A_CHROOT).linux-kernel-deps-update-chroot
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

stamps/5.4.linux-kernel-package-configured-clean: \
		$(call C_EXPAND,stamps/5.5.%.linux-kernel-source-package-clean)
	@echo "5.4.  All: Clean configured linux kernel source directory"
	rm -rf src/linux
	rm -f pkgs/$(LINUX_TARBALL_DEBIAN_ORIG)
	rm -f stamps/5.4.linux-kernel-package-configured
LINUX_CLEAN_ALL += stamps/5.4.linux-kernel-package-configured-clean


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

$(call C_EXPAND,stamps/5.5.%.linux-kernel-source-package-clean): \
stamps/5.5.%.linux-kernel-source-package-clean:
	@echo "5.5.  $(CODENAME):  Clean linux kernel source build"
	rm -f pkgs/linux_$(LINUX_PKG_VERSION).debian.tar.xz
	rm -f pkgs/linux_$(LINUX_PKG_VERSION).dsc
	rm -f stamps/5.5.linux-kernel-source-package
$(call C_TO_CA_DEPS,stamps/5.5.%.linux-kernel-source-package-clean,\
	stamps/5.6.%.linux-kernel-build-clean)

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

$(call CA_EXPAND,stamps/5.6.%.linux-kernel-build-clean): \
stamps/5.6.%.linux-kernel-build-clean:
	@echo "5.6.  $(CA):  Clean linux kernel binary builds"
	rm -f $(wildcard pkgs/linux-headers-*_$(LINUX_PKG_VERSION)_$(ARCH).deb)
	rm -f $(wildcard pkgs/linux-image-*_$(LINUX_PKG_VERSION)_$(ARCH).deb)
	rm -f pkgs/linux_$(LINUX_PKG_VERSION)-$(ARCH).build
	rm -f pkgs/linux_$(LINUX_PKG_VERSION)_$(ARCH).changes
	rm -f stamps/5.6.$*.linux-kernel-build
$(call CA_TO_C_DEPS,stamps/5.6.%.linux-kernel-build-clean,\
	stamps/5.7.%.linux-kernel-ppa-clean)

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

# This is the final result of the linux kernel build
LINUX_INDEP := stamps/5.7.%.linux-kernel-ppa

$(call C_EXPAND,stamps/5.7.%.linux-kernel-ppa-clean): \
stamps/5.7.%.linux-kernel-ppa-clean:
	@echo "5.7.  $(CODENAME):  Clean linux kernel PPA stamp"
	rm -f stamps/5.7.%.linux-kernel-ppa-clean


# Hook kernel build into final build
FINAL_DEPS_INDEP += $(LINUX_INDEP)
SQUEAKY_ALL += $(LINUX_SQUEAKY_ALL)
CLEAN_ARCH += $(LINUX_CLEAN_ARCH)
CLEAN_ALL += $(LINUX_CLEAN_ALL)


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

stamps/6.1.linux-tools-package-checkout-clean: \
		stamps/6.2.linux-tools-unpacked-clean
	@echo "6.2.  All:  Remove linux-tools git submodule stamp"
	rm -f stamps/6.1.linux-tools-package-checkout

stamps/6.1.linux-tools-package-checkout-squeaky: \
		stamps/6.1.linux-tools-package-checkout-clean
	@echo "6.2.  All:  Cleaning up linux-tools git submodule"
	rm -rf git/linux-tools-deb; mkdir -p git/linux-tools-deb
LINUX_TOOLS_SQUEAKY_ALL += stamps/6.1.linux-tools-package-checkout-squeaky


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
LINUX_TOOLS_CLEAN_ALL += stamps/6.2.linux-tools-unpacked-clean

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
LINUX_TOOLS_CLEAN_INDEP += stamps/6.3.%.linux-tools-source-package-clean


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
	stamps/6.5.%.linux-tools-ppa-clean)

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
# This target is the main result of the linux-tools build
LINUX_TOOLS_INDEP := stamps/6.5.%.linux-tools-ppa

$(call C_EXPAND,stamps/6.5.%.linux-tools-ppa-clean): \
stamps/6.5.%.linux-tools-ppa-clean:
	@echo "6.5. $(CODENAME):  Clean linux-tools PPA stamp"
	rm -f stamps/6.5.$(CODENAME).linux-tools-ppa


# Hook linux-tools builds into final build
FINAL_DEPS_INDEP += $(LINUX_TOOLS_INDEP)
SQUEAKY_ALL += $(LINUX_TOOLS_SQUEAKY_ALL)
CLEAN_ALL += $(LINUX_TOOLS_CLEAN_ALL)
CLEAN_INDEP += $(LINUX_TOOLS_CLEAN_INDEP)


###################################################
# 100. Final Targets
#
# 100.0. Final target for each distro
#
# wheezy.all
$(call C_EXPAND,stamps/%.all): \
stamps/%.all: \
	$(FINAL_DEPS_INDEP)
.PHONY: $(call C_EXPAND,stamps/%.all)

# Final target
all: \
	$(call C_EXPAND,stamps/%.all)
.PHONY: all


# 
# 100.1. Clean targets
#
# distro/arch targets
$(call CA_EXPAND,stamps/%.clean): \
stamps/%.clean: \
	$(CLEAN_ARCH)
.PHONY:  $(call CA_EXPAND,stamps/%.clean)

# distro targets
$(call C_TO_CA_DEPS,stamps/%.clean,stamps/%.clean)
$(call C_EXPAND,stamps/%.clean): \
stamps/%.clean: \
	$(CLEAN_INDEP)
.PHONY:  $(call C_EXPAND,stamps/%.clean)

# all targets
clean: \
	$(CLEAN_ALL) \
	$(call C_EXPAND,stamps/%.clean)
.PHONY:  clean


#
# 100.2. Squeaky clean targets
#
# These remove things that don't often need removing and are expensive
# to replace

# 100.2.1 Remove aptcache
100.2.1.squeaky-aptcache:
	@echo "100.2.1. All:  Remove aptcache"
	rm -rf aptcache; mkdir -p aptcache
.PHONY: 100.2.1.squeaky-aptcache
SQUEAKY_ALL += 100.2.1.squeaky-aptcache

# 100.2.2 Remove ccache
100.2.2.squeaky-ccache:
	@echo "100.2.2. All:  Remove ccache"
	rm -rf ccache; mkdir -p ccache
.PHONY: 100.2.2.squeaky-ccache
SQUEAKY_ALL += 100.2.2.squeaky-ccache

# 100.2.3 Squeaky clean distro/arch artifacts
$(call CA_EXPAND,100.2.3.%.squeaky-clean): \
100.2.3.%.squeaky-clean: \
	$(SQUEAKY_ARCH)
.PHONY: $(call CA_EXPAND,100.2.3.%.squeaky-clean)

# 100.2.4 Squeaky clean distro artifacts
$(call C_EXPAND,100.2.4.%.squeaky-clean): \
100.2.4.%.squeaky-clean: \
	$(SQUEAKY_INDEP)
.PHONY: $(call C_EXPAND,100.2.4.%.squeaky-clean)

# 100.2.5 Make everything squeaky clean
squeaky-clean: \
	clean \
	$(SQUEAKY_ALL) \
	$(call C_EXPAND,100.2.4.%.squeaky-clean)
.PHONY: squeaky-clean
