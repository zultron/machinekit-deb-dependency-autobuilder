###################################################
# Configuration override

# Override settings locally in this file
-include Config.mk


###################################################
# Variables that may change or be overridden in Config.mk

# List of codename/arch combos to build
#
# Lucid isn't supported by new kernel packaging, which requires python
# >= 2.7 (2.4 available), kernel-wedge >= 2.82 (2.29 available),
# gcc-4.6 (4.4 available).
#
# Squeeze (Debian 6.0) is reportedly obsolete.
ALL_CODENAMES_ARCHES ?= \
	wheezy-amd64 \
	wheezy-i386 \
	jessie-amd64 \
	wheezy-armhf \
	jessie-i386
# Precise doesn't have gcc 4.7; using gcc 4.6 might be the cause of
# the kernel module problems I've been finding
	# precise-amd64 \
	# precise-i386 \
	#

# Define this to have a deterministic chroot for step 5.4
#BUILD_ARCH_CHROOT ?= wheezy-amd64

# Your "Firstname Lastname <email@address>"; leave out to use git config
#MAINTAINER = John Doe <jdoe@example.com>

# User to run as in pbuilder
PBUILDER_USER ?= ${USER}

# Uncomment to remove dependencies on Makefile and pbuilderrc while
# hacking this script
DEBUG ?= yes
# Uncomment to print reasons a target is being built/rebuilt
DEBUG_DEPS ?= yes

###################################################
# Directories
#
# The top 'make' directory
#
# This directory is shared by all builds; by default, shared pieces
# are kept under this directory
TOPDIR := $(shell pwd)
# Where to build the Apt package repository
REPODIR ?= $(TOPDIR)/ppa
# Where to download source tarballs
DISTDIR ?= $(TOPDIR)/dist
# Where apt keyring and rendered pbuilderrc templates live
MISCDIR ?= $(TOPDIR)/misc


# The top non-shared directory
#
# Build artifacts not shared between codenames and arches can be built
# in a separate directory by overriding in Config.mk.  This can be
# useful e.g. to run builds on fast storage.
#
# NOTE: This is not suited to running on tmpfs.  If these disappear,
# later updates to the builds will break.
PRIVATE_DIR ?= $(TOPDIR)
# If PRIVATE_DIR is set separately from TOPDIR, make it available in
# the chroot by adding it to BINDMOUNTS
ifneq ($(TOPDIR),$(PRIVATE_DIR))
BINDMOUNTS := $(PRIVATE_DIR)
endif
# Where to place packages
BUILDRESULT ?= $(PRIVATE_DIR)/pkgs
# Apt package cach
APTCACHE ?= $(PRIVATE_DIR)/aptcache
# ccache
CCACHEDIR ?= $(PRIVATE_DIR)/ccache
# chroot tarball directory
CHROOTDIR ?= $(PRIVATE_DIR)/chroots
# Where to unpack the chroot and build
BUILDPLACE ?= $(PRIVATE_DIR)/build
# Where to unpack sources
SOURCEDIR ?= $(PRIVATE_DIR)/src

###################################################
# Variables that should not change much
# (or auto-generated)

# Debian package signature keys
UBUNTU_KEYID = 40976EAF437D05B5
DEBIAN_KEYID = 8B48AD6246925553
WHEEZY_KEYID = 6FB2A1C265FFB764
KEYIDS = $(UBUNTU_KEYID) $(DEBIAN_KEYID) $(WHEEZY_KEYID)
KEYSERVER = hkp://keys.gnupg.net

# Misc paths, filenames, executables
SUDO := sudo -n

KEYRING := $(MISCDIR)/keyring.gpg

# Pass any 'DEBBUILDOPTS=foo' arg into dpkg-buildpackage
DEBBUILDOPTS_ARG = $(if $(DEBBUILDOPTS),--debbuildopts "$(DEBBUILDOPTS)")

# pbuilder command line
ifneq ($(BINDMOUNTS),)
BINDMOUNTS_ARG = --bindmounts "$(BINDMOUNTS)"
endif
PBUILD = pbuilder
PBUILD_ARGS = --configfile \
	$(MISCDIR)/pbuilderrc.$(if $(CODENAME),$(CODENAME)-$(ARCH),$(BUILD_ARCH_CHROOT)) \
	--allow-untrusted \
	$(DEBBUILDOPTS_ARG) $(BINDMOUNTS_ARG)

# Auto generate Maintainer: field if not set above
MAINTAINER ?= $(shell git config user.name) <$(shell git config user.email)>

##############################################
# Random utilities

# Return unique list of words
uniq = $(if $1,$(firstword $1) $(call uniq,$(filter-out $(firstword $1),$1)))


##############################################
# CODENAME and ARCH handling

# Generate variables like ARCH_wheezy-armhf = armhf
define setca
ARCH_$(1) := $(shell echo $(1) | sed 's/.*-//')
CODENAME_$(1) := $(shell echo $(1) | sed 's/-.*//')
endef
$(foreach ca,$(ALL_CODENAMES_ARCHES),$(eval $(call setca,$(ca))))

# Lists of codenames and arches
CODENAMES = $(call uniq,$(foreach ca,$(ALL_CODENAMES_ARCHES),$(CODENAME_$(ca))))
ARCHES = $(call uniq,$(foreach ca,$(ALL_CODENAMES_ARCHES),$(ARCH_$(ca))))
CODENAME_ARCHES = $(call uniq,$(strip \
	$(foreach ca,$(ALL_CODENAMES_ARCHES),\
	  $(if $(findstring $(CODENAME_$(ca)),$(1)),$(ARCH_$(ca))))))

# Functions to expand codenames and arches from a given pattern
C_EXPAND = $(foreach i,$(1),$(patsubst %,$(i),$(CODENAMES)))
A_EXPAND = $(foreach i,$(1),$(patsubst %,$(i),$(ARCHES)))
CA_EXPAND = $(foreach i,$(1),$(patsubst %,$(i),$(ALL_CODENAMES_ARCHES)))

# A random chroot to configure a source package in
# (The kernel configuration depends on packages being installed)
BUILD_ARCH_CHROOT ?= $(wordlist 1,1,$(ALL_CODENAMES_ARCHES))
BUILD_INDEP_CODENAME = $(shell echo $(BUILD_ARCH_CHROOT) | sed 's/-.*//')
# Arch to build indep packages with
BUILD_INDEP_ARCH = $(shell echo $(BUILD_ARCH_CHROOT) | sed 's/.*-//')
# Arches NOT to build indep packages with
BUILD_ARCH_ARCHES = $(filter-out $(ARCH_$(BUILD_ARCH_CHROOT)),$(ARCHES))

# Set $(CODENAME) and $(ARCH) for all stamps/x.y.%.foo targets
stamps/% clean-% util-%: ARCH = $(if $(ARCH_$*),$(ARCH_$*),$(BUILD_INDEP_ARCH))
stamps/% clean-% util-%: CODENAME = $(if $(CODENAME_$*),$(CODENAME_$*),$(CA))
stamps/% clean-% util-%: CA = $(*)

###################################################
# Stamp generator functions

# $$(call STAMP_PAT,<pkgindex>,<stepindex>,<pkg>,<pat>,<step>)
STAMP_PAT = stamps/$(strip $(1)).$(strip $(2)).$(strip \
	$(3))$(strip $(4)).$(strip $(5))
# $$(call STAMP_EXPAND_PAT,<VAR>,<name>,<pat>)
STAMP_EXPAND_PAT = $(call STAMP_PAT,\
	$($(1)_INDEX),\
	$(TARGET_$(1)_$(2)_INDEX),\
	$($(1)_SOURCE_NAME),\
	$(3),\
	$(2))
PAT_INDEP=.%
PAT_ARCH=.%
# $$(call STAMP,<pkgindex>,<step>)
# => stamps/<pkgindex>.<stepindex>.%.<step>
STAMP = $(call STAMP_EXPAND_PAT,$(1),$(2),$(if $(3),.$(3),$(PAT_$(TARGET_$(1)_$(2)_TYPE))))
# (These are for internal use)
STAMP_EXPAND_COMMON = $(call STAMP,$(1),$(2))
STAMP_EXPAND_INDEP = $(call C_EXPAND,$(call STAMP_EXPAND_PAT,$(1),$(2),.%))
STAMP_EXPAND_ARCH = $(call CA_EXPAND,$(call STAMP_EXPAND_PAT,$(1),$(2),.%))
# $$(call STAMP_EXPAND,<pkgindex>,<step>)
# => stamps/<pkgindex>.<stepindex>.<codename[-arch]>.<step>
#    for each <codename> or <codename-arch>
STAMP_EXPAND = $(call STAMP_EXPAND_$(TARGET_$(1)_$(2)_TYPE),$(1),$(2))

# Like STAMP_EXPAND, but expands only the BUILD_INDEP codename-arch
STAMP_INDEP_CA = $(patsubst %,$(call STAMP,$(1),$(2)),$(BUILD_ARCH_CHROOT))
# Like STAMP_EXPAND, but expands only non-BUILD_INDEP codename-arches
STAMP_ARCH_CA = $(patsubst %,$(call STAMP,$(1),$(2)),\
	$(filter-out $(BUILD_ARCH_CHROOT),$(ALL_CODENAMES_ARCHES)))

# Like above, but append '-clean' to stamp names
STAMP_CLEAN = $(call STAMP,$(1),$(2))-clean
STAMP_EXPAND_CLEAN = $(patsubst %,%-clean,$(call STAMP_EXPAND,$(1),$(2)))

##############################################
# Stamp and dependency handling

# $(call CA2C_DEPS,bar,foo)
# generates rules like:
# stamps/1.wheezy-amd64.bar: stamps/0.wheezy.foo
#
# This is handy when an arch-specific rule pattern depends on a
# non-arch-specific rule pattern, and codename decoupling is desired
#
# LEAVE THE TRAILING SPACE
define CA2C_DEP
$(strip $(patsubst %,$(call STAMP$(6),$(1),$(2)),$(5)): \
	$(foreach d,$(call STAMP$(6),$(3),$(4)),$(patsubst %,$(d),$(CODENAME_$(5)))))

endef
define CA2C_DEPS
$(foreach ca,$(ALL_CODENAMES_ARCHES),\
	$(call CA2C_DEP,$(1),$(2),$(1),$(3),$(ca)))
endef
define CA2C_DEPS_CLEAN
$(foreach ca,$(ALL_CODENAMES_ARCHES),\
	$(call CA2C_DEP,$(1),$(2),$(1),$(3),$(ca),_CLEAN))
endef


# Auto-generate rules like:
# 1.wheezy.bar: 0.wheezy-i386.foo 0.wheezy-amd64.foo
# ...using:
# $$(call C2CA_DEPS,$(1),bar,foo)
#
# This is handy when an indep rule pattern depends on a
# arch rule pattern, and codename decoupling is desired
#
# LEAVE THE TRAILING SPACE
define C2CA_DEP
$(strip $(patsubst %,$(1),$(3)): \
	$(foreach a,$(ARCHES),\
	  $(if $(findstring $(3)-$(a),$(ALL_CODENAMES_ARCHES)),\
	    $(patsubst %,$(2),$(3)-$(a)))))

endef
define C2CA_DEPS
$(foreach dep,$(3),
  $(foreach c,$(CODENAMES),\
    $(call C2CA_DEP,\
	$(call STAMP$(4),$(1),$(2)),\
	$(call STAMP$(4),$(1),$(dep)),$(c))))
endef
define C2CA_DEPS_CLEAN
$(call C2CA_DEPS,$(1),$(2),$(3),_CLEAN)
endef


# deprecated
define C_TO_CA_DEP
$(strip $(patsubst %,$(1),$(3)): \
	$(foreach a,$(ARCHES),\
	  $(if $(findstring $(3)-$(a),$(ALL_CODENAMES_ARCHES)),\
	    $(patsubst %,$(2),$(3)-$(a)))))

endef
define C_TO_CA_DEPS
$(foreach dep,$(2),\
$(foreach c,$(CODENAMES),$(call C_TO_CA_DEP,$(1),$(dep),$(c))))
endef

###################################################
# File name generator functions

PKG_VERSION = $($(1)_VERSION)-$($(1)_PKG_RELEASE)~$(2)1

DEBIAN_TARBALL_ORIG = $($(1)_SOURCE_NAME)_$($(1)_VERSION).orig.tar.$($(1)_COMPRESSION)
DEBIAN_TARBALL = $($(1)_SOURCE_NAME)_$(call PKG_VERSION,$(1),$$(CODENAME)).debian.tar.$(if $($(1)_DEBIAN_COMPRESSION),$($(1)_DEBIAN_COMPRESSION),gz)
DEBIAN_DSC = $($(1)_SOURCE_NAME)_$(call PKG_VERSION,$(1),$$(CODENAME)).dsc

############################################
# FIXME sort

# Expand a pattern containing a source name
# $$(call SOURCE_NAME_VAR,czmq,TARGETS_%_COMMON)
SOURCE_NAME_VAR = $(patsubst %,$(if $(2),$(2),%),$(SOURCE_NAME_VAR_$(1)))

# Debugging:  tell why a package is being remade
REASON_PAT = @echo "   == making $$(if $$?,,absent )'$$@' $$(if $$?,for '$$?' )=="
REASON = @echo "   == making $(if $?,,absent )'$@' $(if $?,for '$?' )=="


############################################
# Reprepro handling

# The reprepro command and args
REPREPRO = reprepro -VV -b $(REPODIR) \
	--confdir +b/conf-$$(CODENAME) --dbdir +b/db-$$(CODENAME)

# For an arch, list build arches for reprepro; essentially to add
# 'all' to the BUILD_INDEP_ARCH
define REPREPRO_ARCH_MAP
$(eval REPREPRO_ARCH_$(1) := $(1))
endef
$(foreach a,$(BUILD_ARCH_ARCHES),$(eval $(call REPREPRO_ARCH_MAP,$(a))))
REPREPRO_ARCH_$(BUILD_INDEP_ARCH) := $(BUILD_INDEP_ARCH)|all

# List of packages for a particular arch for reprepro
# Includes binary-indep packages for BUILD_INDEP_ARCH
# $$(call REPREPRO_PKGS,XENOMAI,amd64)
REPREPRO_PKGS = $(strip $($(1)_PKGS_ARCH) $($(1)_PKGS_ARCH_$(2)) \
	$(if $(findstring $(2),$(BUILD_INDEP_ARCH)),$($(1)_PKGS_ALL)))

# Lists of generated package paths
PACKAGES_ALL = $(strip $(if $($(1)_PKGS_ALL), $(patsubst %,\
	$(BUILDRESULT)/%_$(call PKG_VERSION,$(1),$(2))_all.deb,\
	$($(1)_PKGS_ALL))))

# List of all build-arch packages
# $$(call PACKAGES_ARCH,<name>,<codename>,<arch>)
PACKAGES_ARCH = $(strip \
	$(patsubst %,$(BUILDRESULT)/%_$(call PKG_VERSION,$(1),$(2))_$(3).deb,\
	    $($(1)_PKGS_ARCH) $($(1)_PKGS_ARCH_$(3))))

# List of package paths for a particular arch for adding to reprepro
# Includes binary-indep packages for BUILD_INDEP_ARCH
# $$(call REPREPRO_PKG_PATHS,XENOMAI,wheezy-amd64)
REPREPRO_PACKAGE_PATHS = \
	$(call PACKAGES_ARCH,$(1),$(CODENAME_$(2)),$(ARCH_$(2))) \
	$(if $(findstring $(ARCH_$(2)),$(BUILD_INDEP_ARCH)),\
	    $(call PACKAGES_ALL,$(1),$(CODENAME_$(2))))

# Given a package name, generate its pool directory
PPA_POOL_PREFIX = $(REPODIR)/pool/main/$(shell echo $($(1)_SOURCE_NAME) | \
	sed 's/^\(\(lib\)\?.\).*$$/\1/')/$($(1)_SOURCE_NAME)

###################################################
# out-of-band checks

# check that pbuilder exists
ifeq ($(shell /bin/ls /usr/sbin/pbuilder 2>/dev/null),)
  $(error /usr/sbin/pbuilder does not exist)
endif


###################################################
# Default rule

all:
.PHONY:  all
ALL_TARGET_INDEP := all
ALL_DESC := Make all packages for all codenames and arches
HELP_VARS_COMMON += ALL

# Define main help items here so they come first in 'make help' list
HELP_PACKAGE_TARGET_INDEP := help-\<package\>
HELP_PACKAGE_DESC := Help for all targets related to a package
HELP_VARS_COMMON += HELP_PACKAGE

HELP_CLEAN_TARGET_INDEP := clean
HELP_CLEAN_DESC := Clean all packages (not downloads/chroots/caches)
HELP_VARS_COMMON += HELP_CLEAN


###################################################
# PPA rules

# list a PPA's packages for a distro
# PPA help target:  print PPA contents
define LIST_PPA
# This has to be in a 'define' list to handle the double-$ stuff
# needed by later targets using REPREPRO
$(call C_EXPAND,util-%.list-ppa): \
util-%.list-ppa:
	@echo "===== $$(CODENAME):  Listing PPA ====="
	$(REASON)
	$(REPREPRO) \
	    list $$(CODENAME)
endef
$(eval $(call LIST_PPA))

INFO_PPA_LIST_TARGET_INDEP := util-\<distro\>.list-ppa
INFO_PPA_LIST_DESC := List current PPA contents for a distro
HELP_VARS_UTIL += INFO_PPA_LIST


###################################################
# 00. Basic build dependencies
#
# 00.1 Generic target for non-<codename>/<arch>-specific targets
stamps/00.1.base-builddeps:
	@echo "===== 00.1. All:  Initialize basic build deps ====="
	touch $@
ifeq ($(DEBUG),)
# While hacking, don't rebuild everything whenever a file is changed
stamps/00.1.base-builddeps: \
		Makefile \
		pbuild/linux-unpacked-chroot-script.sh \
		.gitmodules
# Don't rebuild chroots if these change when hacking
CHROOT_DEPS = \
	pbuild/pbuilderrc.tmpl \
	$(MISCDIR)/pbuilderrc.%
endif

# Other deps, in variables
CHROOT_DEPS += stamps/01.1.keyring-downloaded

.PRECIOUS:  stamps/00.1.base-builddeps
INFRA_TARGETS_ALL += stamps/00.1.base-builddeps

stamps/00.1.base-builddeps-clean:
	rm -f stamps/00.1.base-builddeps
SQUEAKY_ALL += stamps/00.1.base-builddeps-clean


# 00.2 Init distro ppa directories and configuration
define INIT_PPA
$(call C_EXPAND,stamps/00.2.%.ppa-init): \
stamps/00.2.%.ppa-init: $(CHROOT_DEPS)
	@echo "===== 00.2.  $(CODENAME):  Init ppa directories ====="
	$(REASON_PAT)
	mkdir -p $(REPODIR)/conf-$(CODENAME) $(REPODIR)/db-$(CODENAME)
	cat pbuild/ppa-distributions.tmpl | sed \
		-e "s/@codename@/$(CODENAME)/g" \
		-e "s/@arch@/$(call CODENAME_ARCHES,$(CODENAME))/g" \
		> $(REPODIR)/conf-$(CODENAME)/distributions
	$(REPREPRO) export $(CODENAME)

	touch $$@
.PRECIOUS:  $(call C_EXPAND,stamps/00.2.%.ppa-init)
endef
$(eval $(call INIT_PPA))

$(call C_EXPAND,stamps/00.2.%.ppa-init-clean): \
stamps/00.2.%.ppa-init-clean:
	@echo "00.2. $(CODENAME):  Removing ppa directories"
	rm -rf $(REPODIR)/conf-$(CODENAME) $(REPODIR)/db-$(CODENAME)

# 00.3 Init distro ppa
stamps/00.3.all.ppa-init: \
		$(call C_EXPAND,stamps/00.2.%.ppa-init)
	@echo "===== 00.3.  All:  Init ppa directories ====="
	mkdir -p $(REPODIR)/dists $(REPODIR)/pool
	touch $@
.PRECIOUS: stamps/00.3.all.ppa-init
INFRA_TARGETS_ALL += stamps/00.3.all.ppa-init

stamps/00.3.all.ppa-init-clean: \
	$(call C_EXPAND,stamps/00.2.%.ppa-init-clean)
	@echo "00.3.  All:  Remove ppa directories"
	rm -rf $(REPODIR)
SQUEAKY_ALL += stamps/00.3.all.ppa-init-clean


###################################################
# 01. GPG keyring

# 01.1 Download GPG keys for the various distros, needed by pbuilder

stamps/01.1.keyring-downloaded:
	@echo "===== 01.1. All variants:  Creating GPG keyring ====="
	$(REASON)
	mkdir -p $(MISCDIR)
	gpg --no-default-keyring --keyring=$(KEYRING) \
		--keyserver=$(KEYSERVER) --recv-keys \
		--trust-model always \
		$(KEYIDS)
	test -f $(KEYRING)
	chmod +r $(KEYRING)
	touch $@
.PRECIOUS:  stamps/01.1.keyring-downloaded
INFRA_TARGETS_ALL += stamps/01.1.keyring-downloaded

stamps/01.1.keyring-downloaded-clean:
	@echo "01.1. All:  Cleaning package GPG keyring"
	rm -f $(KEYRING)
	rm -f stamps/01.1.keyring-downloaded
SQUEAKY_ALL += stamps/01.1.keyring-downloaded-clean

keyring: stamps/01.1.keyring-downloaded
.PHONY: keyring

KEYRING_TARGET_ALL := keyring
KEYRING_DESC := Download upstream distro GPG keys
HELP_VARS_COMMON += KEYRING


###################################################
# 02. Base chroot tarball

# 02.1.  Build chroot tarball
$(call CA_EXPAND,stamps/02.1.%.chroot-build): \
stamps/02.1.%.chroot-build: \
		$(CHROOT_DEPS)
	@echo "===== 02.1. $(CA):  Creating pbuilder chroot tarball ====="
	$(REASON)
#	# render the pbuilderrc template
	mkdir -p $(MISCDIR)
	sed \
	    -e "s,@TOPDIR@,$(TOPDIR)," \
	    -e "s,@BUILDRESULT@,$(BUILDRESULT)," \
	    -e "s,@APTCACHE@,$(APTCACHE)," \
	    -e "s,@CCACHEDIR@,$(CCACHEDIR)," \
	    -e "s,@CHROOTDIR@,$(CHROOTDIR)," \
	    -e "s,@BUILDPLACE@,$(BUILDPLACE)," \
	    -e "s,@REPODIR@,$(REPODIR)," \
	    -e "s,@SOURCEDIR@,$(SOURCEDIR)," \
	    -e "s,@MISCDIR@,$(MISCDIR)," \
	    -e "s,@PBUILDER_USER@,$(PBUILDER_USER)," \
	    -e "s,@DISTRO_ARCH@,$*," \
	    pbuild/pbuilderrc.tmpl \
		> $(MISCDIR)/pbuilderrc.$(CA)
#	# make all needed directories
	mkdir -p $(BUILDRESULT) $(APTCACHE) $(CHROOTDIR)
#	# create the base.tgz chroot tarball
	$(SUDO) $(PBUILD) --create \
		$(PBUILD_ARGS)
	touch $@
.PRECIOUS:  $(call CA_EXPAND,stamps/02.1.%.chroot-build)
INFRA_TARGETS_ARCH += stamps/02.1.%.chroot-build

# Take care of arch-indep packages
$(call C_EXPAND,stamps/02.1.%.chroot-build): \
stamps/02.1.%.chroot-build: \
		stamps/02.1.%-$(BUILD_INDEP_ARCH).chroot-build

02.1.clean.%.chroot:  stamps/02.1.%.chroot-build
	@echo "02.1. $(CA):  Cleaning chroot tarball"
	rm -f chroots/base-$(CA).tgz
	rm -f stamps/02.1-$(CA)-chroot-build
SQUEAKY_ARCH += 02.1.clean.%.chroot


#
# Log into chroot
#
$(call CA_EXPAND,util-%.chroot): BINDMOUNTS += $(TOPDIR)
$(call CA_EXPAND,util-%.chroot): \
util-%.chroot: \
		stamps/02.1.%.chroot-build
	@echo "===== Logging into $(*) pbuilder chroot ====="
	$(REASON)
	$(SUDO) INTERMEDIATE_REPO=$(REPODIR) \
	    $(PBUILD) --login \
		$(PBUILD_ARGS)
.PHONY:  $(call CA_EXPAND,%.chroot)

CHROOT_LOGIN_TARGET_ARCH := util-\<distro-arch\>.chroot
CHROOT_LOGIN_DESC := Log into a chroot
HELP_VARS_UTIL += CHROOT_LOGIN


###################################################
# Info generator functions

# $$(call INFO,<VAR>,<target>,[<description>])
#   where <scope> is typically $$(CA) or $$(CODENAME)
#
# echoes <index>. <scope>:  <package>:  <description>
define INFO
	@echo
	@echo "====="\
	    "$($(1)_INDEX).$(TARGET_$(1)_$(2)_INDEX)." \
	    "$(if $(findstring $(TARGET_$(1)_$(2)_TYPE),COMMON),all,$$(CA)): " \
	    "$($(1)_SOURCE_NAME): " \
	    "$(if $(3),$(3),$(TARGET_$(1)_$(2)_DESC))" \
	    "====="
ifneq ($(DEBUG_DEPS),)
ifeq ($(3),)
	$(REASON_PAT)
endif
endif
endef
INFO_CLEAN = $(call INFO,$(1),$(2),Cleaning target $(2))


###################################################
# Config variables for each target
define TARGET_VARS
TARGET_$(1)_checkout-submodule_INDEX := 0
TARGET_$(1)_checkout-submodule_TYPE := COMMON
TARGET_$(1)_checkout-submodule_DESC := Check out submodule
TARGETS_$(1) += checkout-submodule

TARGET_$(1)_tarball-download_INDEX := 1
TARGET_$(1)_tarball-download_TYPE := COMMON
TARGET_$(1)_tarball-download_DESC := Download tarball
TARGETS_$(1) += tarball-download

TARGET_$(1)_unpack-tarball_INDEX := 2
TARGET_$(1)_unpack-tarball_TYPE := COMMON
TARGET_$(1)_unpack-tarball_DESC := Unpack tarball
TARGETS_$(1) += unpack-tarball

TARGET_$(1)_debianize-source_INDEX := 3
TARGET_$(1)_debianize-source_TYPE := COMMON
TARGET_$(1)_debianize-source_DESC := Debianize source
TARGETS_$(1) += debianize-source


ifneq ($$($(1)_PACKAGE_DEPS),)
TARGET_$(1)_update-chroot-deps_INDEX := 5
TARGET_$(1)_update-chroot-deps_TYPE := ARCH
TARGET_$(1)_update-chroot-deps_DESC := Update chroot packages from PPA
TARGETS_$(1) += update-chroot-deps
endif

# Add chroot command to regular command for use as flag
$(1)_SOURCE_PACKAGE_CONFIGURE_COMMAND += \
	$($(1)_SOURCE_PACKAGE_CHROOT_CONFIGURE_COMMAND)

ifneq ($$($(1)_SOURCE_PACKAGE_CONFIGURE_COMMAND),)
ifneq ($$($(1)_SOURCE_PACKAGE_CHROOT_CONFIGURE_COMMAND),)
TARGET_$(1)_configure-source-package-chroot_INDEX := 9
TARGET_$(1)_configure-source-package-chroot_TYPE := ARCH
TARGET_$(1)_configure-source-package-chroot_DESC := \
	Configure source package in chroot
TARGETS_$(1) += configure-source-package-chroot
endif # have source pkg chroot configure command

TARGET_$(1)_configure-source-package_INDEX := 8
TARGET_$(1)_configure-source-package_TYPE := COMMON
TARGET_$(1)_configure-source-package_DESC := Configure source package
TARGETS_$(1) += configure-source-package
endif # have source pkg configure command

TARGET_$(1)_build-source-package_INDEX := 4
TARGET_$(1)_build-source-package_TYPE := INDEP
TARGET_$(1)_build-source-package_DESC := Build source package
TARGETS_$(1) += build-source-package

TARGET_$(1)_update-ppa-source_INDEX := 10
TARGET_$(1)_update-ppa-source_TYPE := INDEP
TARGET_$(1)_update-ppa-source_DESC := Update PPA with source package
TARGETS_$(1) += update-ppa-source

TARGET_$(1)_build-binary-package_INDEX := 6
TARGET_$(1)_build-binary-package_TYPE := $$(if $$($(1)_ARCH),$$($(1)_ARCH),ARCH)
TARGET_$(1)_build-binary-package_DESC := Build binary packages
TARGETS_$(1) += build-binary-package

TARGET_$(1)_update-ppa_INDEX := 7
TARGET_$(1)_update-ppa_TYPE := $$(if $$($(1)_ARCH),$$($(1)_ARCH),ARCH)
TARGET_$(1)_update-ppa_DESC := Update PPA with new packages
TARGETS_$(1) += update-ppa

endef


define UPDATE_SUBMODULE
###################################################
# xx.0. Update submodule
#
ifneq ($($(1)_SUBMODULE),)
# $$(call UPDATE_SUBMODULE,<VARIABLE>)
$(call STAMP,$(1),checkout-submodule):
	$(call INFO,$(1),checkout-submodule)
#	# be sure the submodule has been checked out
	test -e $$($(1)_SUBMODULE)/.git || \
	    git submodule update --init $($(1)_SUBMODULE)
	test -e $$($(1)_SUBMODULE)/.git
	touch $$@
.PRECIOUS: $(call STAMP,$(1),checkout-submodule)

$(call STAMP_CLEAN,$(1),checkout-submodule): \
		$(call STAMP_CLEAN,$(1),debianize-source)
	rm -f $(call STAMP,$(1),checkout-submodule)
	touch $$@
endif
endef


define DOWNLOAD_TARBALL
###################################################
# xx.1. Download tarball distribution
#
ifeq ($($(1)_TARBALL_PACKAGE),)
# Download a tarball
$(call STAMP,$(1),tarball-download):
	$(call INFO,$(1),tarball-download)
	mkdir -p $(DISTDIR)
	wget "$($(1)_URL)" -O $(DISTDIR)/$($(1)_TARBALL)
	mkdir -p $$(dir $$@) && touch $$@

else
# Use the same tarball as another package
$(1)_TARBALL_TARGET := \
	$(call STAMP,$(SOURCE_NAME_VAR_$($(1)_TARBALL_PACKAGE)),tarball-download)
$(call STAMP,$(1),tarball-download): \
		$($(1)_TARBALL_TARGET)
	$(call INFO,$(1),tarball-download,\
		Using tarball from package $($(1)_TARBALL_PACKAGE))
	test -e $(DISTDIR)/$($(1)_TARBALL)
	touch $$@
endif

.PRECIOUS: $(call STAMP,$(1),tarball-download)

$(call STAMP_CLEAN,$(1),tarball-download): \
		$(call STAMP_CLEAN,$(1),unpack-tarball)
	$(call INFO_CLEAN,$(1),tarball-download)
	rm -f $(call STAMP,$(1),tarball-download)
ifeq ($($(1)_TARBALL_TARGET),)
	rm -f $(DISTDIR)/$($(1)_TARBALL)
else

# Hook into other package's clean target
$(call STAMP_CLEAN,$($(1)_TARBALL_TARGET),tarball-download): \
	$(call STAMP_CLEAN,$(1),tarball-download)
endif

# Tarball downloads cost time and bandwidth, and are infrequent; only
# clean squeaky
$(1)_SQUEAKY_ALL += $(call STAMP_CLEAN,$(1),tarball-download)
endef


define UNPACK_TARBALL
###################################################
# xx.2. Unpack tarball
#
$(call STAMP,$(1),unpack-tarball): \
		$(call STAMP,$(1),tarball-download)
	$(call INFO,$(1),unpack-tarball)
	rm -rf $(SOURCEDIR)/$($(1)_SOURCE_NAME)/build
	mkdir -p $(SOURCEDIR)/$($(1)_SOURCE_NAME)/build
	tar xC $(SOURCEDIR)/$($(1)_SOURCE_NAME)/build --strip-components=1 \
	    -f $(DISTDIR)/$($(1)_TARBALL)
	touch $$@

$(call STAMP_CLEAN,$(1),unpack-tarball): \
		$(call STAMP_CLEAN,$(1),debianize-source)
	$(call INFO_CLEAN,$(1),unpack-tarball)
	rm -rf $(SOURCEDIR)/$($(1)_SOURCE_NAME)/build
	rm -f $(call STAMP,$(1),unpack-tarball)
$(1)_CLEAN_COMMON += \
	$(call STAMP_CLEAN,$(1),unpack-tarball)
endef


define DEBIANIZE_SOURCE
###################################################
# xx.3. Debianize source

# Some packages include Debianization and need no submodule
ifneq ($($(1)_SUBMODULE),)
$(call STAMP,$(1),debianize-source): $(call STAMP,$(1),checkout-submodule)
endif

$(call STAMP,$(1),debianize-source): \
		$(call STAMP,$(1),unpack-tarball)
	$(call INFO,$(1),debianize-source)
ifneq ($($(1)_SUBMODULE),)
#	# Unpack debianization
	mkdir -p $(SOURCEDIR)/$($(1)_SOURCE_NAME)/build
	git --git-dir="$($(1)_SUBMODULE)/.git" archive --prefix=debian/ HEAD \
	    | tar xCf $(SOURCEDIR)/$($(1)_SOURCE_NAME)/build -
endif
#	# Make clean copy of changelog for later munging
	cp --preserve=all \
	    $(SOURCEDIR)/$($(1)_SOURCE_NAME)/build/debian/changelog \
	    $(SOURCEDIR)/$($(1)_SOURCE_NAME)
#	# Link source tarball with Debian name
	ln -sf $(DISTDIR)/$($(1)_TARBALL) \
	    $(SOURCEDIR)/$($(1)_SOURCE_NAME)/$(call DEBIAN_TARBALL_ORIG,$(1))
#	# Copy Debian tarball to package directory
	mkdir -p $(BUILDRESULT)
	cp --preserve=all $(DISTDIR)/$($(1)_TARBALL) \
	    $(BUILDRESULT)/$(call DEBIAN_TARBALL_ORIG,$(1))
	touch $$@

$(call STAMP_CLEAN,$(1),debianize-source): \
		$(call STAMP_EXPAND_CLEAN,$(1),build-source-package)
	$(call INFO_CLEAN,$(1),debianize-source)
	rm -rf $(SOURCEDIR)/$($(1)_SOURCE_NAME)/debian
	rm -f $(SOURCEDIR)/$($(1)_SOURCE_NAME)/$(call DEBIAN_TARBALL_ORIG,$(1))
	rm -f $(call STAMP,$(1),debianize-source)
$(1)_CLEAN_COMMON += \
	$(call STAMP_CLEAN,$(1),debianize-source)
endef


define UPDATE_CHROOT_DEPS
###################################################
# xx.5. Update chroot with locally-built dependent packages
#
# This is optional; intended for packages depending on other packages
# built here
ifneq ($($(1)_PACKAGE_DEPS),)

$(call STAMP_EXPAND,$(1),update-chroot-deps): \
$(call STAMP,$(1),update-chroot-deps): \
		$$(foreach pkg,$$($(1)_PACKAGE_DEPS),\
		$$(call STAMP,$$(SOURCE_NAME_VAR_$$(pkg)),update-ppa))
	$(call INFO,$(1),update-chroot-deps)
	$(SUDO) $(PBUILD) \
	    --update --override-config \
	    $$(PBUILD_ARGS)
	touch $$@
.PRECIOUS: $(call STAMP_EXPAND,$(1),update-chroot-deps)

# Binary package build dependent on chroot update
$(call STAMP_EXPAND,$(1),build-binary-package): \
$(call STAMP,$(1),build-binary-package): $(call STAMP,$(1),update-chroot-deps)

$(call STAMP_EXPAND_CLEAN,$(1),update-chroot-deps): \
$(call STAMP_CLEAN,$(1),update-chroot-deps): \
		$(call STAMP_CLEAN,$(1),build-binary-package)
	$(call INFO_CLEAN,$(1),update-chroot-deps)
	rm -f $(call STAMP,$(1),update-chroot-deps)
# Cleaning this cleans up all (non-squeaky) arch and indep artifacts
$(1)_SQUEAKY_ARCH += $(call STAMP_CLEAN,$(1),update-chroot-deps)
endif # package deps defined
endef


define CONFIGURE_SOURCE_PACKAGE_CHROOT
###################################################
# xx.10. Configure package source in a chroot
#
# This is only added to those packages needing source package
# configuration in a chroot with specific dependency packages
# installed
ifneq ($($(1)_SOURCE_PACKAGE_CHROOT_CONFIGURE_COMMAND),)
# Configure source package in the BUILD_INDEP chroot with dependent
# packages installed; requires an updated BUILD_INDEP chroot
$(call STAMP_INDEP_CA,$(1),configure-source-package-chroot): \
$(call STAMP,$(1),configure-source-package-chroot): \
		$(call STAMP_INDEP_CA,$(1),update-chroot-deps) \
		$(call STAMP,$(1),debianize-source)
	$(call INFO,$(1),configure-source-package-chroot)
#	# Configure the package in the BUILD_INDEP chroot
	$(SUDO) $(PBUILD) --execute \
		--bindmounts $(SOURCEDIR) \
		$(PBUILD_ARGS) $($(1)_SOURCE_PACKAGE_CHROOT_CONFIGURE_COMMAND)
	touch $$@

# Hook into configure-source-package step
$(call STAMP,$(1),configure-source-package): \
		$(call STAMP_INDEP_CA,$(1),configure-source-package-chroot)

endif
endef

define CONFIGURE_SOURCE_PACKAGE
###################################################
# xx.8. Configure package source
#
# This is only added to those packages needing an extra configuration step
ifneq ($($(1)_SOURCE_PACKAGE_CONFIGURE_COMMAND),)

$(call STAMP,$(1),configure-source-package): \
		$(call STAMP,$(1),debianize-source)
	$(call INFO,$(1),configure-source-package)
#	# Configure the source package normally if no chroot needed
	$(if $($(1)_SOURCE_PACKAGE_CHROOT_CONFIGURE_COMMAND),,\
	    $($(1)_SOURCE_PACKAGE_CONFIGURE_COMMAND))
	touch $$@
.PRECIOUS: $(call STAMP,$(1),configure-source-package)

# Hook into source package build
$(call STAMP_EXPAND,$(1),build-source-package): \
	$(call STAMP,$(1),configure-source-package)

$(call STAMP_CLEAN,$(1),configure-source-package): \
		$(call STAMP_EXPAND_CLEAN,$(1),build-source-package)
	$(call INFO_CLEAN,$(1),configure-source-package)
	rm -f $(call STAMP,$(1),configure-source-package)
CLEAN_COMMON += $(call STAMP_CLEAN,$(1),configure-source-package)

# Cleaning debian source should clean this, too
$(call STAMP_CLEAN,$(1),debianize-source): \
	$(call STAMP_CLEAN,$(1),configure-source-package)
endif
endef


define BUILD_SOURCE_PACKAGE
###################################################
# xx.4. Build source package for each distro

$(call STAMP_EXPAND,$(1),build-source-package): \
$(call STAMP,$(1),build-source-package): \
		$(call STAMP,$(1),unpack-tarball) \
		$(call STAMP,$(1),debianize-source)
	$(call INFO,$(1),build-source-package)

	@echo Adding changelog entry to fresh changelog
	cp --preserve=all $(SOURCEDIR)/$($(1)_SOURCE_NAME)/changelog \
	    $(SOURCEDIR)/$($(1)_SOURCE_NAME)/build/debian
	cd $(SOURCEDIR)/$($(1)_SOURCE_NAME)/build && \
	    $(TOPDIR)/pbuild/tweak-pkg.sh \
	    $$(CODENAME) $(call PKG_VERSION,$(1),$$(CODENAME)) "$$(MAINTAINER)"
ifneq ($$($(1)_SOURCE_PACKAGE_CONFIGURE_COMMAND),)
	@echo Cleaning source package
	cd $(SOURCEDIR)/$($(1)_SOURCE_NAME)/build && \
		dpkg-buildpackage -d -Tclean
endif
	@echo Building source package
	ln -sf $(DISTDIR)/$$($(1)_TARBALL) \
	    $(SOURCEDIR)/$($(1)_SOURCE_NAME)/$(call DEBIAN_TARBALL_ORIG,$(1))
	cd $(SOURCEDIR)/$($(1)_SOURCE_NAME)/build && dpkg-source -i -I -b .
	touch $$@
.PRECIOUS: $(call STAMP_EXPAND,$(1),build-source-package)

$(call STAMP_EXPAND_CLEAN,$(1),build-source-package): \
$(call STAMP_CLEAN,$(1),build-source-package):
	$(call INFO_CLEAN,$(1),build-source-package)
	rm -f $(SOURCEDIR)/$($(1)_SOURCE_NAME)/$(call DEBIAN_DSC,$(1))
	rm -f $(SOURCEDIR)/$($(1)_SOURCE_NAME)/$(call DEBIAN_TARBALL,$(1))
	rm -f $(call STAMP_EXPAND,$(1),build-source-package)
$(call C2CA_DEPS_CLEAN,$(1),build-source-package,build-binary-package)
$(1)_CLEAN_INDEP += $(call STAMP_CLEAN,$(1),build-source-package)
endef


###################################################
# xx.10. Update PPA with source package for a codename
#
define UPDATE_PPA_SOURCE
$(call STAMP_EXPAND,$(1),update-ppa-source): \
$(call STAMP,$(1),update-ppa-source): \
		$(call STAMP,$(1),build-source-package)
	$(call INFO,$(1),update-ppa-source)
#	# Remove source and binary packages from PPA if they exist to
#	# ensure fresh repo
	$(REPREPRO) \
	    removesrc $$(CODENAME) $($(1)_SOURCE_NAME)
#	# Add source package
	$(REPREPRO) -C main \
	    includedsc $$(CODENAME) \
	    $(SOURCEDIR)/$($(1)_SOURCE_NAME)/$(call DEBIAN_DSC,$(1))
	touch $$@
.PRECIOUS:  $(call STAMP_EXPAND,$(1),update-ppa-source)

$(call STAMP_EXPAND_CLEAN,$(1),update-ppa-source): \
$(call STAMP_CLEAN,$(1),update-ppa-source):
	$(call INFO_CLEAN,$(1),update-ppa-source)
#	# Remove source packages from PPA
	$(REPREPRO) -T dsc \
	    remove $$(CODENAME) $($(1)_SOURCE_NAME)
$(call C2CA_DEPS_CLEAN,$(1),update-ppa-source,build-binary-package)
$(1)_CLEAN_INDEP += $(call STAMP_CLEAN,$(1),update-ppa-source)
endef


define BUILD_BINARY_PACKAGE
###################################################
# xx.6. Build binary packages for each distro/arch
#
#   Only build binary-indep packages once:
$(call STAMP,$(1),build-binary-package): \
	BUILDTYPE = $$(if $$(findstring $$(ARCH),$(BUILD_INDEP_ARCH)),-b,-B)

# handle arch-indep packages
# Depends on the source package build
ifeq ($$($(1)_ARCH),INDEP)
$(call STAMP_EXPAND,$(1),build-binary-package): \
$(call STAMP,$(1),build-binary-package): \
		$(call STAMP,$(1),update-ppa-source)
else
$(call CA2C_DEPS,$(1),build-binary-package,update-ppa-source)
endif


$(call STAMP_EXPAND,$(1),build-binary-package): \
$(call STAMP,$(1),build-binary-package): \
		stamps/02.1.%.chroot-build \
		$$(foreach dep,$$($(1)_PACKAGE_DEPS),\
		    $$(call STAMP,$$(SOURCE_NAME_VAR_$$(dep)),update-ppa))
	$(call INFO,$(1),build-binary-package)
	mkdir -p $(BUILDRESULT)
	$(SUDO) $(PBUILD) --build \
	    $$(PBUILD_ARGS) \
	    --debbuildopts $$(BUILDTYPE) \
	    $(call PPA_POOL_PREFIX,$(1))/$(call DEBIAN_DSC,$(1))
	touch $$@
.PRECIOUS: $(call STAMP_EXPAND,$(1),build-binary-package)

$(call STAMP_EXPAND_CLEAN,$(1),build-binary-package): \
$(call STAMP_CLEAN,$(1),build-binary-package): \
		$(call STAMP_CLEAN,$(1),update-ppa)
	$(call INFO_CLEAN,$(1),build-binary-package)
	rm -f $$(call REPREPRO_PACKAGE_PATHS,$(1),$$(CA))
	rm -f $(BUILDRESULT)/$($(1)_SOURCE_NAME)_$(call PKG_VERSION,$(1),$$(CODENAME))-$$(ARCH).build
	rm -f $(BUILDRESULT)/$($(1)_SOURCE_NAME)_$(call PKG_VERSION,$(1),$$(CODENAME))_$$(ARCH).changes
	rm -f $(call STAMP,$(1),build-binary-package,$$(CA))
$(1)_CLEAN_ARCH += $(call STAMP_CLEAN,$(1),build-binary-package)
endef


define UPDATE_PPA
###################################################
# xx.7. Add packages to the PPA for a codename+arch

# Only add binary-indep packages once:
$(call STAMP,$(1),update-ppa):\
	WANT_INDEP = \
	    $$(if $$(findstring $$(CODENAME),$(BUILD_INDEP_CODENAME)),1)

$(call STAMP_EXPAND,$(1),update-ppa):\
$(call STAMP,$(1),update-ppa):\
		$(call STAMP,$(1),build-binary-package) \
		stamps/00.3.all.ppa-init
	$(call INFO,$(1),update-ppa)

	@echo "Removing any existing binary packages from PPA"
	$(REPREPRO) -T deb \
	    $$(if $$(filter-out $$(ARCH),$$(BUILD_INDEP_ARCH)),-A $$(ARCH)) \
	    remove $$(CODENAME) $$(call REPREPRO_PKGS,$(1),$$(ARCH))

	@echo "Adding new binary packages to PPA"
	$(REPREPRO) -C main includedeb $$(CODENAME) \
	    $$(call REPREPRO_PACKAGE_PATHS,$(1),$$(CA))
	touch $$@
.PRECIOUS: $(call STAMP_EXPAND,$(1),update-ppa)

$(1)_ARCH := $(call STAMP,$(1),update-ppa)

$(call STAMP_EXPAND_CLEAN,$(1),update-ppa): \
$(call STAMP_CLEAN,$(1),update-ppa):
	$(call INFO_CLEAN,$(1),update-ppa)
	@echo "Removing any existing binary packages from PPA"
	$(REPREPRO) -T deb -A $$(ARCH) \
	    remove $$(CODENAME) $$(call REPREPRO_PKGS,$(1),$$(ARCH))
	rm -f $(call STAMP,$(1),update-ppa,$$(CA))
$(1)_CLEAN_ARCH += $$(call STAMP_CLEAN,$(1),update-ppa)
endef


define ADD_HOOKS
###################################################
# xx.9. Wrap up

# Hook builds into final builds, if configured
FINAL_DEPS_ARCH += $$($(1)_ARCH)
SQUEAKY_ALL += $$($(1)_SQUEAKY_ALL)
CLEAN_INDEP += $$($(1)_CLEAN_INDEP)
PACKAGES += $(1)
SOURCE_NAME_VAR_$($(1)_SOURCE_NAME) = $(1)

# Build targets
# <package> and <package>-<distro> target, update-ppa by default
$(1)_DEFAULT_TARGET =  update-ppa
# 
$(call C_EXPAND,$($(1)_SOURCE_NAME)-%): \
$($(1)_SOURCE_NAME)-%: $(call STAMP,$(1),$(if \
	$($(1)_DEFAULT_TARGET),$($(1)_DEFAULT_TARGET),update-ppa))
$($(1)_SOURCE_NAME):  $(call STAMP_EXPAND,$(1),$(if \
	$($(1)_DEFAULT_TARGET),$($(1)_DEFAULT_TARGET),update-ppa))
$(1)_TARGET_ALL := $($(1)_SOURCE_NAME)
$(1)_DESC := Build $($(1)_SOURCE_NAME) packages for all distros
HELP_VARS_PACKAGE += $(1)

# Cleaning
$(call CA_EXPAND,$($(1)_SOURCE_NAME)-%-clean): \
$$($(1)_SOURCE_NAME)-%-clean: \
	$$($(1)_CLEAN_ARCH)
$(call C_EXPAND,$($(1)_SOURCE_NAME)-%-clean): \
$$($(1)_SOURCE_NAME)-%-clean: \
	$$($(1)_CLEAN_COMMON) \
	$$($(1)_CLEAN_INDEP) \
	$$(foreach t,$$($(1)_CLEAN_ARCH),$$(patsubst %,$$(t),$$(patsubst %,\%-%,$$(ARCHES))))
$($(1)_SOURCE_NAME)-clean: \
	$(call C_EXPAND,$($(1)_SOURCE_NAME)-%-clean)

endef


###################################################
#
# xx.9. The whole enchilada

define STANDARD_BUILD
$(call UPDATE_SUBMODULE,$(1))
$(call DOWNLOAD_TARBALL,$(1))
$(call UNPACK_TARBALL,$(1))
$(call DEBIANIZE_SOURCE,$(1))
$(call CONFIGURE_SOURCE_PACKAGE_CHROOT,$(1))
$(call CONFIGURE_SOURCE_PACKAGE,$(1))
$(call UPDATE_CHROOT_DEPS,$(1))
$(call BUILD_SOURCE_PACKAGE,$(1))
$(call UPDATE_PPA_SOURCE,$(1))
$(call BUILD_BINARY_PACKAGE,$(1))
$(call UPDATE_PPA,$(1))
$(call ADD_HOOKS,$(1))
endef

# A debuggable build
define DEBUG_BUILD
# Add DEBUG_INFO=xenomai on command line to print the macros
ifeq ($(DEBUG_INFO),$$($(1)_SOURCE_NAME))
$$(info $$(call STANDARD_BUILD,$(1)))
endif
ifneq ($(DEBUG_PACKAGE),)
# Call 'make debuggery DEBUG_PACKAGE=XENOMAI TARGET=<some.target>' on
# command line to give useful errors
ifeq ($(DEBUG_PACKAGE),$(1))
$$(info # doing debuggery:  DEBUG_STAGE = $(DEBUG_STAGE))
debuggery:
ifeq ($(DEBUG_STAGE),)
	@echo In debuggery stage 0
#	# Re-run twice:
	@echo Running debuggery stage 1, render rules into /tmp/makefile.debug
	$(MAKE) -s debuggery DEBUG_STAGE=1 > /tmp/makefile.debug
	@echo Remaking '$(TARGET)' including /tmp/makefile.debug
	$(MAKE) $(TARGET) DEBUG_STAGE=2
endif # Debuggery stage 0
ifeq ($(DEBUG_STAGE),1)
$$(info # Output from debuggery of $(DEBUG_PACKAGE))
$$(info $$(call STANDARD_BUILD,$(1)))
endif # Debuggery stage 1
ifeq ($(DEBUG_STAGE),2)
$$(info *** Including debuggery rules from /tmp/makefile.debug ***)
-include /tmp/makefile.debug
endif # Debuggery stage 2
endif # Debuggery in this package
else # Not debuggering
$(call STANDARD_BUILD,$(1))
endif # Debuggery
endef

###################################################
# Include package build makefiles

-include $(wildcard Makefiles/Makefile.*.mk)


###################################################
# 90. Infra Targets

$(call CA_EXPAND,%.infra): \
%.infra: \
	$(call CA_EXPAND,$(INFRA_TARGETS_ARCH))
.PHONY: $(call CA_EXPAND,%.infra)

$(call C_EXPAND,%.infra): \
%.infra: \
	$(call C_EXPAND,$(INFRA_TARGETS_INDEP))
.PHONY: $(call C_EXPAND,%.infra)

all.infra: \
	$(INFRA_TARGETS_ALL)
.PHONY: all.infra

infra: \
	$(call CA_EXPAND,%.infra) \
	$(call C_EXPAND,%.infra) \
	all.infra
.PHONY: infra

# Haven't used this in a while
# INFRA_TARGET_ALL := "infra"
# INFRA_DESC := "Convenience:  Build all common infra \(chroots, etc.\)"
# HELP_VARS_COMMON += INFRA

###################################################
# 91.  Help targets
#
# These present help for humans

# Print help line
define HELP_ITEM
	@printf "    %-25s  %s\n" $($(1)_TARGET_$(2)) "$($(1)_DESC)"

endef
# Print help for a particular section
define HELP_SECTION
	@echo
	@echo "$(1) TARGETS:"
	$(foreach var,$(HELP_VARS_$(1)),\
	    $(if $($(var)_TARGET_INDEP),\
		$(call HELP_ITEM,$(var),INDEP),\
	    $(if $($(var)_TARGET_ARCH),\
		$(call HELP_ITEM,$(var),ARCH),\
		$(call HELP_ITEM,$(var),ALL))))
endef

help:
	$(foreach sec,COMMON PACKAGE UTIL,$(call HELP_SECTION,$(sec)))
.PHONY: help

# Help for a package
# $$(call PACKAGE_TARGET_HELP,CZMQ,update-ppa,INDEP)
define ECHO
	@echo "$(1)"

endef
define PACKAGE_TARGET_HELP
	$(foreach t,$(strip $(call STAMP_EXPAND,$(1),$(2))),\
	    $(call ECHO,    $(t)))
	@echo "        $(TARGET_$(1)_$(2)_DESC)"

endef
define PACKAGE_HELP
	$(foreach t,$($(call SOURCE_NAME_VAR,$(1),TARGETS_%)),\
	    $(call PACKAGE_TARGET_HELP,$(SOURCE_NAME_VAR_$(1)),$(t),COMMON))
endef
$(foreach p,$(PACKAGES),help-$($(p)_SOURCE_NAME)): \
help-%:
	@echo "targets for package $*:"
	$(call PACKAGE_HELP,$*)


###################################################
# 98. Pbuilder config utilities

$(call C_EXPAND,util-%.pbuilderrc): \
util-%.pbuilderrc:
	@echo TOPDIR=$(TOPDIR)
	@echo BUILDRESULT=$(BUILDRESULT)
	@echo APTCACHE=$(APTCACHE)
	@echo CCACHEDIR=$(CCACHEDIR)
	@echo CHROOTDIR=$(CHROOTDIR)
	@echo BUILDPLACE=$(BUILDPLACE)
	@echo REPODIR=$(REPODIR)

# Haven't used this in a while
# PBUILDERRC_TARGET_ALL := "util-%.pbuilderrc"
# PBUILDERRC_DESC := "Output variables needed in a distro pbuilderrc"
# HELP_VARS_COMMON += PBUILDERRC

###################################################
# 99. Final Targets
#
# 99.0. Final target for each distro
#
# wheezy.all
$(call CA_EXPAND,%.all): \
%.all: \
	$(FINAL_DEPS_ARCH)
.PHONY: $(call C_EXPAND,%.all)

# Final target
all: \
	$(call CA_EXPAND,%.all)
.PHONY: all


# 
# 99.1. Clean targets
#
# distro/arch targets
$(call CA_EXPAND,%.clean): \
%.clean: \
	$(CLEAN_ARCH)
.PHONY:  $(call CA_EXPAND,%.clean)

# distro targets
$(eval $(call C_TO_CA_DEPS,%.clean,%.clean))

$(call C_EXPAND,%.clean): \
%.clean: \
	$(CLEAN_INDEP)
.PHONY:  $(call C_EXPAND,%.clean)

# all targets
clean: \
	$(CLEAN_ALL) \
	$(call C_EXPAND,%.clean)
.PHONY:  clean


#
# 99.2. Squeaky clean targets
#
# These remove things that don't often need removing and are expensive
# to replace

# 99.2.1 Remove aptcache
99.2.1.squeaky-aptcache:
	@echo "99.2.1. All:  Remove aptcache"
	rm -rf aptcache; mkdir -p aptcache
.PHONY: 99.2.1.squeaky-aptcache
SQUEAKY_ALL += 99.2.1.squeaky-aptcache

# 99.2.2 Remove ccache
99.2.2.squeaky-ccache:
	@echo "99.2.2. All:  Remove ccache"
	rm -rf ccache; mkdir -p ccache
.PHONY: 99.2.2.squeaky-ccache
SQUEAKY_ALL += 99.2.2.squeaky-ccache

# 99.2.3 Squeaky clean distro/arch artifacts
$(call CA_EXPAND,99.2.3.%.squeaky-clean): \
99.2.3.%.squeaky-clean: \
	$(SQUEAKY_ARCH)
.PHONY: $(call CA_EXPAND,99.2.3.%.squeaky-clean)

# 99.2.4 Squeaky clean distro artifacts
$(call C_EXPAND,99.2.4.%.squeaky-clean): \
99.2.4.%.squeaky-clean: \
	$(SQUEAKY_INDEP)
.PHONY: $(call C_EXPAND,99.2.4.%.squeaky-clean)

# 99.2.5 Make everything squeaky clean
squeaky-clean: \
	clean \
	$(SQUEAKY_ALL) \
	$(call C_EXPAND,99.2.4.%.squeaky-clean)
.PHONY: squeaky-clean
