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
A_CHROOT ?= wheezy-amd64

# Your "Firstname Lastname <email@address>"; leave out to use git config
#MAINTAINER = John Doe <jdoe@example.com>

# Uncomment to remove dependencies on Makefile and pbuilderrc while
# hacking this script
DEBUG ?= yes
# Uncomment to print reasons a target is being built/rebuilt
DEBUG_DEPS ?= yes

# Directories that pbuilderrc needs
#
# The directory where this Makefile lives
TOPDIR := $(shell pwd)
# Where to place packages
BUILDRESULT ?= $(TOPDIR)/pkgs
# Apt package cach
APTCACHE ?= $(TOPDIR)/aptcache
# ccache
CCACHEDIR ?= $(TOPDIR)/ccache
# chroot tarball directory
CHROOTDIR ?= $(TOPDIR)/chroots
# Where to unpack the chroot and build
BUILDPLACE ?= $(TOPDIR)/build
# Where to build the Apt package repository
REPODIR ?= $(TOPDIR)/ppa

# Other directories
#
# Where to unpack sources
SOURCEDIR ?= $(TOPDIR)/src

# User to run as in pbuilder
PBUILDER_USER ?= ${USER}

###################################################
# Variables that should not change much
# (or auto-generated)

# Debian package signature keys
UBUNTU_KEYID = 40976EAF437D05B5
DEBIAN_KEYID = 8B48AD6246925553
KEYIDS = $(UBUNTU_KEYID) $(DEBIAN_KEYID)
KEYSERVER = hkp://keys.gnupg.net

# Misc paths, filenames, executables
SUDO := sudo

KEYRING := $(TOPDIR)/admin/keyring.gpg

# Pass any 'DEBBUILDOPTS=foo' arg into dpkg-buildpackage
DEBBUILDOPTS_ARG = $(if $(DEBBUILDOPTS),--debbuildopts "$(DEBBUILDOPTS)")

# pbuilder command line
BINDMOUNTS_ARG = --bindmounts "$(BINDMOUNTS)"
PBUILD = pbuilder
PBUILD_ARGS = --configfile \
	admin/pbuilderrc.$(if $(CODENAME),$(CODENAME)-$(ARCH),$(A_CHROOT)) \
	--allow-untrusted \
	$(DEBBUILDOPTS_ARG) $(BINDMOUNTS_ARG)

# Auto generate Maintainer: field if not set above
MAINTAINER ?= $(shell git config user.name) <$(shell git config user.email)>

# Set $(CODENAME) and $(ARCH) for all stamps/x.y.%.foo targets
define setca
ARCH_$(1) = $(shell echo $(1) | sed 's/.*-//')
CODENAME_$(1) = $(shell echo $(1) | sed 's/-.*//')
endef
$(foreach ca,$(ALL_CODENAMES_ARCHES),$(eval $(call setca,$(ca))))
stamps/% clean-% util-%: ARCH = $(ARCH_$*)
stamps/% clean-% util-%: CODENAME = $(if $(CODENAME_$*),$(CODENAME_$*),$(CA))
stamps/% clean-% util-%: CA = $(*)

# Lists of codenames and arches and functions to expand them
uniq = $(if $1,$(firstword $1) $(call uniq,$(filter-out $(firstword $1),$1)))
CODENAMES = $(call uniq,$(foreach ca,$(ALL_CODENAMES_ARCHES),$(CODENAME_$(ca))))
ARCHES = $(call uniq,$(foreach ca,$(ALL_CODENAMES_ARCHES),$(ARCH_$(ca))))
CODENAME_ARCHES = $(call uniq,$(strip \
	$(foreach ca,$(ALL_CODENAMES_ARCHES),\
	  $(if $(findstring $(CODENAME_$(ca)),$(1)),$(ARCH_$(ca))))))
C_EXPAND = $(foreach i,$(1),$(patsubst %,$(i),$(CODENAMES)))
A_EXPAND = $(foreach i,$(1),$(patsubst %,$(i),$(ARCHES)))
CA_EXPAND = $(foreach i,$(1),$(patsubst %,$(i),$(ALL_CODENAMES_ARCHES)))

# $(call CA2C_DEPS,bar,foo)
# generates rules like:
# stamps/1.wheezy-amd64.bar: stamps/0.wheezy.foo
#
# This is handy when an arch-specific rule pattern depends on a
# non-arch-specific rule pattern, and codename decoupling is desired
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
# Set a dependency on another package being in the PPA
define CA2C_PPA_DEP
$(call CA2C_DEP,$(1),update-chroot-deps,$(SOURCE_NAME_VAR_$(2)),update-ppa,$(3))

endef
define CA2C_PPA_DEPS
$(foreach d,$(2),$(foreach ca,$(ALL_CODENAMES_ARCHES),\
	$(call CA2C_PPA_DEP,$(1),$(d),$(ca))))
endef


# Auto-generate rules like:
# 1.wheezy.bar: 0.wheezy-i386.foo 0.wheezy-amd64.foo
# ...using:
# $$(call C2CA_DEPS,$(1),bar,foo)
#
# This is handy when an indep rule pattern depends on a
# arch rule pattern, and codename decoupling is desired
define C2CA_DEP
$(patsubst %,$(1),$(3)): $(strip \
	$(foreach a,$(ARCHES),\
	  $(if $(findstring $(3)-$(a),$(ALL_CODENAMES_ARCHES)),\
	    $(patsubst %,$(2),$(3)-$(a)))))
endef
define C2CA_DEPS
$(strip $(foreach dep,$(3),
  $(foreach c,$(CODENAMES),\
    $(call C2CA_DEP,\
	$(call STAMP$(4),$(1),$(2)),\
	$(call STAMP$(4),$(1),$(dep)),$(c)))))
endef
define C2CA_DEPS_CLEAN
$(call C2CA_DEPS,$(1),$(2),$(3),_CLEAN)
endef


# deprecated
define C_TO_CA_DEP
$(patsubst %,$(1),$(3)): $(strip \
	$(foreach a,$(ARCHES),\
	  $(if $(findstring $(3)-$(a),$(ALL_CODENAMES_ARCHES)),\
	    $(patsubst %,$(2),$(3)-$(a)))))
endef
define C_TO_CA_DEPS
$(foreach dep,$(2),
  $(foreach c,$(CODENAMES),$(call C_TO_CA_DEP,$(1),$(dep),$(c))))
endef

# A random chroot to configure a source package in
# (The kernel configuration depends on packages being installed)
A_CHROOT ?= $(wordlist 1,1,$(ALL_CODENAMES_ARCHES))
AN_ARCH = $(ARCH_$(A_CHROOT))
A_CODENAME = $(CODENAME_$(A_CHROOT))

# The reprepro command and args
REPREPRO = reprepro -VV -b $(REPODIR) \
	--confdir +b/conf-$$(CODENAME) --dbdir +b/db-$$(CODENAME)

# Expand a pattern containing a source name
# $$(call SOURCE_NAME_VAR,czmq,TARGETS_%_COMMON)
SOURCE_NAME_VAR = $(patsubst %,$(if $(2),$(2),%),$(SOURCE_NAME_VAR_$(1)))

# Lists of generated package names
PACKAGES_ALL = $(strip $(if $($(1)_PKGS_ALL), $(patsubst %,\
	$(BUILDRESULT)/%_$(call PKG_VERSION,$(1))_all.deb,\
	$($(1)_PKGS_ALL))))

PACKAGES_ARCH = $(strip $(if $($(1)_PKGS_ARCH),$(call A_EXPAND,\
	$(patsubst %,$(BUILDRESULT)/%_$(call PKG_VERSION,$(1))_%.deb,\
	$($(1)_PKGS_ARCH)))))

PACKAGES_ALL_ARCH = $(strip \
	$(call PACKAGES_ALL,$(1)) $(call PACKAGES_ARCH,$(1)))

# Debugging:  tell why a package is being remade
REASON_PAT = @echo "   == making $$(if $$?,,absent )'$$@' $$(if $$?,for '$$?' )=="
REASON = @echo "   == making $(if $?,,absent )'$@' $(if $?,for '$?' )=="


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

# PPA help target:  print PPA contents
$(call C_EXPAND,util-%.list-ppa): \
util-%.list-ppa:
	$(call LIST_PPA,info,$(CODENAME))

INFO_PPA_LIST_TARGET_INDEP := "util-%.list-ppa"
INFO_PPA_LIST_DESC := "List current PPA contents for a distro"
HELP_VARS_UTIL += INFO_PPA_LIST



###################################################
# 00. Basic build dependencies
#
# 00.1 Generic target for non-<codename>/<arch>-specific targets
stamps/00.1.base-builddeps:
	@echo "===== 00.1. All:  Initialize basic build deps ====="
	mkdir -p git dist stamps $(BUILDRESULT) aptcache chroots logs
	touch $@
ifeq ($(DEBUG),)
# While hacking, don't rebuild everything whenever a file is changed
stamps/00.1.base-builddeps: \
		Makefile \
		pbuild/linux-unpacked-chroot-script.sh \
		.gitmodules
# Don't rebuild chroots if these change when hacking
CHROOT_DEPS = \
	stamps/01.1.keyring-downloaded \
	pbuild/pbuilderrc.tmpl \
	admin/pbuilderrc.%
endif
.PRECIOUS:  stamps/00.1.base-builddeps
INFRA_TARGETS_ALL += stamps/00.1.base-builddeps

stamps/00.1.base-builddeps-clean:
	rm -f stamps/00.1.base-builddeps
SQUEAKY_ALL += stamps/00.1.base-builddeps-clean


# 00.2 Init distro ppa directories and configuration
$(call C_EXPAND,stamps/00.2.%.ppa-init): \
stamps/00.2.%.ppa-init: $(CHROOT_DEPS)
	@echo "===== 00.2.  $(CODENAME):  Init ppa directories ====="
	$(REASON)
	mkdir -p ppa/conf-$(CODENAME) ppa/db-$(CODENAME)
	cat pbuild/ppa-distributions.tmpl | sed \
		-e "s/@codename@/$(CODENAME)/g" \
		-e "s/@arch@/$(call CODENAME_ARCHES,$(CODENAME))/g" \
		> ppa/conf-$(CODENAME)/distributions

	touch $@
.PRECIOUS:  $(call C_EXPAND,stamps/00.2.%.ppa-init)

$(call C_EXPAND,stamps/00.2.%.ppa-init-clean): \
stamps/00.2.%.ppa-init-clean:
	@echo "00.2. $(CODENAME):  Removing ppa directories"
	rm -rf ppa/conf-$(CODENAME) ppa/db-$(CODENAME)


# 00.3 Init distro ppa
stamps/00.3.all.ppa-init: \
		$(call C_EXPAND,stamps/00.2.%.ppa-init)
	@echo "===== 00.3.  All:  Init ppa directories ====="
	mkdir -p ppa/dists ppa/pool
	touch $@
.PRECIOUS: stamps/00.3.all.ppa-init
INFRA_TARGETS_ALL += stamps/00.3.all.ppa-init

stamps/00.3.all.ppa-init-clean: \
	$(call C_EXPAND,stamps/00.2.%.ppa-init-clean)
	@echo "00.3.  All:  Remove ppa directories"
	rm -rf ppa
SQUEAKY_ALL += stamps/00.3.all.ppa-init-clean

PPA_INIT_TARGET_INDEP := "stamps/00.3.all.ppa-init"
PPA_INIT_DESC := "Create basic PPA directories and initial configuration"
HELP_VARS_COMMON += PPA_INIT


###################################################
# 01. GPG keyring

# 01.1 Download GPG keys for the various distros, needed by pbuilder

stamps/01.1.keyring-downloaded:
	@echo "===== 01.1. All variants:  Creating GPG keyring ====="
	$(REASON)
	mkdir -p admin
	gpg --no-default-keyring --keyring=$(KEYRING) \
		--keyserver=$(KEYSERVER) --recv-keys \
		--trust-model always \
		$(KEYIDS)
	test -f $(KEYRING) && touch $@  # otherwise, fail
.PRECIOUS:  stamps/01.1.keyring-downloaded
INFRA_TARGETS_ALL += stamps/01.1.keyring-downloaded

stamps/01.1.keyring-downloaded-clean:
	@echo "01.1. All:  Cleaning package GPG keyring"
	rm -f $(KEYRING)
	rm -f stamps/01.1.keyring-downloaded
SQUEAKY_ALL += stamps/01.1.keyring-downloaded-clean

KEYRING_TARGET_ALL := "stamps/01.1.keyring-downloaded"
KEYRING_DESC := "Download upstream distro GPG keys"
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
	sed \
	    -e "s,@TOPDIR@,$(TOPDIR)," \
	    -e "s,@BUILDRESULT@,$(BUILDRESULT)," \
	    -e "s,@APTCACHE@,$(APTCACHE)," \
	    -e "s,@CCACHEDIR@,$(CCACHEDIR)," \
	    -e "s,@CHROOTDIR@,$(CHROOTDIR)," \
	    -e "s,@BUILDPLACE@,$(BUILDPLACE)," \
	    -e "s,@REPODIR@,$(REPODIR)," \
	    -e "s,@SOURCEDIR@,$(SOURCEDIR)," \
	    -e "s,@PBUILDER_USER@,$(PBUILDER_USER)," \
	    -e "s,@DISTRO_ARCH@,$*," \
	    pbuild/pbuilderrc.tmpl \
		> admin/pbuilderrc.$$(CA)
#	# make all the codename/i386 directories needed right here
	mkdir -p $(BUILDRESULT) aptcache
#	# create the base.tgz chroot tarball
	$(SUDO) $(PBUILD) --create \
		$(PBUILD_ARGS)
	touch $@
.PRECIOUS:  $(call CA_EXPAND,stamps/02.1.%.chroot-build)
INFRA_TARGETS_ARCH += stamps/02.1.%.chroot-build

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
	$(SUDO) INTERMEDIATE_REPO=ppa \
	    $(PBUILD) --login \
		$(PBUILD_ARGS)
.PHONY:  $(call CA_EXPAND,%.chroot)

CHROOT_LOGIN_TARGET_ARCH := "util-%.chroot"
CHROOT_LOGIN_DESC := "Log into a chroot"
HELP_VARS_UTIL += CHROOT_LOGIN


###################################################
# Stamp generator functions

# $$(call STAMP_PAT,<index>,<subindex>,<pkg>,<pat>,<target>)
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
STAMP = $(call STAMP_EXPAND_PAT,$(1),$(2),$(if $(3),.$(3),$(PAT_$(TARGET_$(1)_$(2)_TYPE))))
STAMP_EXPAND_COMMON = $(call STAMP,$(1),$(2))
STAMP_EXPAND_INDEP = $(call C_EXPAND,$(call STAMP_EXPAND_PAT,$(1),$(2),.%))
STAMP_EXPAND_ARCH = $(call CA_EXPAND,$(call STAMP_EXPAND_PAT,$(1),$(2),.%))
STAMP_EXPAND = $(call STAMP_EXPAND_$(TARGET_$(1)_$(2)_TYPE),$(1),$(2))

STAMP_CLEAN = $(call STAMP,$(1),$(2))-clean
STAMP_EXPAND_CLEAN = $(patsubst %,%-clean,$(call STAMP_EXPAND,$(1),$(2)))

###################################################
# Info generator functions

# $$(call INFO,<VAR>,<target>,[<description>])
#   where <scope> is typically $$(CA) or $$(CODENAME)
#
# echoes <index>. <scope>:  <package>:  <description>
define INFO
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
# File name generator functions

PKG_VERSION = $($(1)_VERSION)-$($(1)_PKG_RELEASE)~$$(CODENAME)1

DEBIAN_TARBALL_ORIG = $($(1)_SOURCE_NAME)_$($(1)_VERSION).orig.tar.$($(1)_COMPRESSION)
DEBIAN_TARBALL = $($(1)_SOURCE_NAME)_$(call PKG_VERSION,$(1)).debian.tar.$(if $($(1)_DEBIAN_COMPRESSION),$($(1)_DEBIAN_COMPRESSION),gz)
DEBIAN_DSC = $($(1)_SOURCE_NAME)_$(call PKG_VERSION,$(1)).dsc


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

ifneq ($($(1)_PACKAGE_DEPS),)
TARGET_$(1)_update-chroot-deps_INDEX := 5
TARGET_$(1)_update-chroot-deps_TYPE := ARCH
TARGET_$(1)_update-chroot-deps_DESC := Update chroot packages from PPA
TARGETS_$(1) += update-chroot-deps
endif

ifneq ($($(1)_CHROOT_COMMAND),)
TARGET_$(1)_configure-source-package_INDEX := 8
TARGET_$(1)_configure-source-package_TYPE := COMMON
TARGET_$(1)_configure-source-package_DESC := Configure package in chroot
TARGETS_$(1) += configure-source-package
endif

TARGET_$(1)_build-source-package_INDEX := 4
TARGET_$(1)_build-source-package_TYPE := INDEP
TARGET_$(1)_build-source-package_DESC := Build source package
TARGETS_$(1) += build-source-package

TARGET_$(1)_build-binary-package_INDEX := 6
TARGET_$(1)_build-binary-package_TYPE := ARCH
TARGET_$(1)_build-binary-package_DESC := Build binary packages
TARGETS_$(1) += build-binary-package

TARGET_$(1)_update-ppa_INDEX := 7
TARGET_$(1)_update-ppa_TYPE := INDEP
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
	test -e $($(1)_SUBMODULE)/.git || \
	    git submodule update --init $($(1)_SUBMODULE)
	test -e $($(1)_SUBMODULE)/.git
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
$(call STAMP,$(1),tarball-download):
	$(call INFO,$(1),tarball-download)
	mkdir -p dist
	wget $($(1)_URL)/$($(1)_TARBALL) -O dist/$($(1)_TARBALL)
	touch $$@
.PRECIOUS: $(call STAMP,$(1),tarball-download)

$(call STAMP_CLEAN,$(1),tarball-download): \
		$(call STAMP_CLEAN,$(1),unpack-tarball)
	$(call INFO_CLEAN,$(1),tarball-download)
	rm -f dist/$($(1)_TARBALL)
	rm -f $(call STAMP,$(1),tarball-download)
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
	    -f dist/$($(1)_TARBALL)
	touch $$@

$(call STAMP_CLEAN,$(1),unpack-tarball): \
		$(call STAMP_CLEAN,$(1),debianize-source)
	$(call INFO_CLEAN,$(1),unpack-tarball)
	rm -rf $(SOURCEDIR)/$($(1)_SOURCE_NAME)
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
	cp -f $(TOPDIR)/dist/$($(1)_TARBALL) \
	    $(SOURCEDIR)/$($(1)_SOURCE_NAME)/$(call DEBIAN_TARBALL_ORIG,$(1))
#	# Copy Debian tarball to package directory
	cp --preserve=all dist/$($(1)_TARBALL) \
	    $(BUILDRESULT)/$(call DEBIAN_TARBALL_ORIG,$(1))
	touch $$@

$(call STAMP_CLEAN,$(1),debianize-source): \
		$(call STAMP_EXPAND_CLEAN,$(1),build-source-package)
	$(call INFO_CLEAN,$(1),debianize-source)
	rm -rf $(SOURCEDIR)/$($(1)_SOURCE_NAME)/debian
	rm -f $(call STAMP,$(1),debianize-source)
	rm -f $(SOURCEDIR)/$($(1)_SOURCE_NAME)/$(call DEBIAN_TARBALL_ORIG,$(1))
	rm -f $(BUILDRESULT)/$(call DEBIAN_TARBALL_ORIG,$(1))
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

# Set dependency on dependent packages' presence in the PPA
# CA2C_PPA_DEPS,$(1),$($(1)_PACKAGE_DEPS)
$(call CA2C_PPA_DEPS,$(1),$($(1)_PACKAGE_DEPS))

$(call STAMP_EXPAND,$(1),update-chroot-deps): \
$(call STAMP,$(1),update-chroot-deps): \
		$($(1)_DEPS)
	$(call INFO,$(1),update-chroot-deps)
	$(SUDO) $(PBUILD) \
	    --update --override-config \
	    $$(PBUILD_ARGS)
	touch $$@
.PRECIOUS: $(call STAMP_EXPAND,$(1),update-chroot-deps)

# Binary package build dependent on chroot update
$(call STAMP_EXPAND,$(1),build-binary-package): \
$(call STAMP,$(1),build-binary-package): $(call STAMP,$(1),update-chroot-deps)

# # PPA status dependent on other package PPA status
# Is this necessary?  Anyway it's broken.
# $(foreach p,$($(1)_PACKAGE_DEPS),\
# $(call STAMP_EXPAND,$(1),update-ppa): \
# $(call STAMP,$(1),update-ppa): $(call STAMP,$(SOURCE_NAME_VAR_$(p)),update-ppa))

$(call STAMP_EXPAND_CLEAN,$(1),update-chroot-deps): \
$(call STAMP_CLEAN,$(1),update-chroot-deps): \
		$(call STAMP_CLEAN,$(1),build-binary-package)
	$(call INFO_CLEAN,$(1),update-chroot-deps)
	rm -f $(call STAMP,$(1),update-chroot-deps)
# Cleaning this cleans up all (non-squeaky) arch and indep artifacts
$(1)_CLEAN_ARCH += $(call STAMP_CLEAN,$(1),update-chroot-deps)
endif # package deps defined
endef


define CONFIGURE_SOURCE_PACKAGE
###################################################
# xx.8. Configure package source

# This is only added to those packages needing an extra configuration step
ifneq ($($(1)_CHROOT_COMMAND),)
# This has to be done in a chroot with the featureset packages
$(call STAMP,$(1),configure-source-package): \
		$(patsubst %,$(call STAMP,$(1),update-chroot-deps),$(A_CHROOT))
	$(call INFO,$(1),configure-source-package)
#	# Configure the package in a chroot
	$(SUDO) $(PBUILD) --execute \
		--bindmounts $(SOURCEDIR) \
		$(PBUILD_ARGS) $($(1)_CHROOT_COMMAND)
	touch $$@
.PRECIOUS: $(call STAMP,$(1),configure-source-package)

# Source package build depends on source package configuration
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
#	# Restore original changelog
	cp --preserve=all $(SOURCEDIR)/$($(1)_SOURCE_NAME)/changelog \
	    $(SOURCEDIR)/$($(1)_SOURCE_NAME)/build/debian
#	# Add changelog entry
	cd $(SOURCEDIR)/$($(1)_SOURCE_NAME)/build && \
	    $(TOPDIR)/pbuild/tweak-pkg.sh \
	    $$(CODENAME) $(call PKG_VERSION,$(1)) "$$(MAINTAINER)"
#	# Build source package
	cd $(SOURCEDIR)/$($(1)_SOURCE_NAME)/build && make -f debian/rules clean \
		|| true
	cd $(SOURCEDIR)/$($(1)_SOURCE_NAME)/build && dpkg-source -i -I -b .
	mv $(SOURCEDIR)/$($(1)_SOURCE_NAME)/$(call DEBIAN_TARBALL,$(1)) \
	    $(SOURCEDIR)/$($(1)_SOURCE_NAME)/$(call DEBIAN_DSC,$(1)) \
	    $(BUILDRESULT)
	touch $$@
.PRECIOUS: $(call STAMP_EXPAND,$(1),build-source-package)

$(call STAMP_EXPAND_CLEAN,$(1),build-source-package): \
$(call STAMP_CLEAN,$(1),build-source-package):
	$(call INFO_CLEAN,$(1),build-source-package)
	rm -f $(BUILDRESULT)/$(call DEBIAN_DSC,$(1))
	rm -f $(BUILDRESULT)/$(call DEBIAN_TARBALL_ORIG,$(1))
	rm -f $(BUILDRESULT)/$(call DEBIAN_TARBALL,$(1))
	rm -f $(call STAMP,$(1),build-source-package)
$(call C2CA_DEPS_CLEAN,$(1),build-source-package,build-binary-package)
$(1)_CLEAN_INDEP += $(call STAMP_CLEAN,$(1),build-source-package)
endef


define BUILD_BINARY_PACKAGE
###################################################
# xx.6. Build binary packages for each distro/arch
#
#   Only build binary-indep packages once:
$(call STAMP,$(1),build-binary-package): \
	BUILDTYPE = $$(if $$(findstring $$(ARCH),$(AN_ARCH)),-b,-B)

# Depends on the source package build
$(call CA2C_DEPS,$(1),build-binary-package,build-source-package)

$(call STAMP_EXPAND,$(1),build-binary-package): \
$(call STAMP,$(1),build-binary-package): \
		stamps/02.1.%.chroot-build
	$(call INFO,$(1),build-binary-package)
	$(SUDO) $(PBUILD) --build \
	    $$(PBUILD_ARGS) \
	    --debbuildopts $$(BUILDTYPE) \
	    $(BUILDRESULT)/$(call DEBIAN_DSC,$(1))
	touch $$@
.PRECIOUS: $(call STAMP_EXPAND,$(1),build-binary-package)

$(call STAMP_EXPAND_CLEAN,$(1),build-binary-package): \
$(call STAMP_CLEAN,$(1),build-binary-package):
	$(call INFO_CLEAN,$(1),build-binary-package)
	rm -f $(patsubst %,$(BUILDRESULT)/%_$(call PKG_VERSION,$(1))_all.deb,\
	    $($(1)_PKGS_ALL)) \
	    $(patsubst %,$(BUILDRESULT)/%_$(call PKG_VERSION,$(1))_$$(ARCH).deb,\
	    $($(1)_PKGS_ARCH))
	rm -f $(BUILDRESULT)/$($(1)_SOURCE_NAME)_$(call PKG_VERSION,$(1))-$$(ARCH).build
	rm -f $(BUILDRESULT)/$($(1)_SOURCE_NAME)_$(call PKG_VERSION,$(1))_$$(ARCH).changes
	rm -f $(call STAMP,$(1),build-binary-package,$$(CA))
$(call CA2C_DEPS_CLEAN,$(1),build-binary-package,update-ppa)
$(1)_CLEAN_ARCH += $(call STAMP_CLEAN,$(1),build-binary-package)
endef


define UPDATE_PPA
###################################################
# xx.7. Add packages to the PPA for each distro

# Depends on binary package builds for all arches
$(call C2CA_DEPS,$(1),update-ppa,build-binary-package)

$(call STAMP_EXPAND,$(1),update-ppa):\
$(call STAMP,$(1),update-ppa):\
		$(call STAMP,$(1),build-source-package) \
		stamps/00.3.all.ppa-init
	$(call INFO,$(1),update-ppa)
#	# Remove packages if they exist
	$(REPREPRO) \
	    removesrc $$(CODENAME) $($(1)_SOURCE_NAME)
#	# Add source package
	$(REPREPRO) -C main \
	    includedsc $$(CODENAME) $(BUILDRESULT)/$(call DEBIAN_DSC,$(1))
#	# Add binary packages
	$(REPREPRO) -C main \
	    includedeb $$(CODENAME) \
	    $(call PACKAGES_ALL_ARCH,$(1))
	touch $$@
.PRECIOUS: $(call STAMP_EXPAND,$(1),update-ppa)

$(1)_INDEP := $(call STAMP,$(1),update-ppa)

$(call STAMP_EXPAND_CLEAN,$(1),update-ppa): \
$(call STAMP_CLEAN,$(1),update-ppa):
	$(call INFO_CLEAN,$(1),update-ppa)
	rm -f $(call STAMP,$(1),update-ppa,$$(CODENAME))
$(1)_CLEAN_INDEP += $(call STAMP_CLEAN,$(1),update-ppa)
endef


define ADD_HOOKS
###################################################
# xx.8. Wrap up

# Cleaning
$(call C_EXPAND,clean-$($(1)_SOURCE_NAME)-%): \
clean-$($(1)_SOURCE_NAME)-%: \
	$($(1)_CLEAN_INDEP) \
	$(foreach t,$($(1)_CLEAN_ARCH),$(patsubst %,$(t),$(patsubst %,\%-%,$(ARCHES))))

# Hook builds into final builds, if configured
FINAL_DEPS_INDEP += $($(1)_INDEP)
SQUEAKY_ALL += $($(1)_SQUEAKY_ALL)
CLEAN_INDEP += $($(1)_CLEAN_INDEP)
PACKAGES += $(1)
SOURCE_NAME_VAR_$($(1)_SOURCE_NAME) = $(1)

# <package> and <package>-<distro> target, update-ppa by default
$(1)_DEFAULT_TARGET =  update-ppa
# 
$(call C_EXPAND,$($(1)_SOURCE_NAME)-%): \
$($(1)_SOURCE_NAME)-%: $(call STAMP,$(1),$(if \
	$($(1)_DEFAULT_TARGET),$($(1)_DEFAULT_TARGET),update-ppa))
$($(1)_SOURCE_NAME):  $(call STAMP_EXPAND,$(1),$(if \
	$($(1)_DEFAULT_TARGET),$($(1)_DEFAULT_TARGET),update-ppa))
$(1)_TARGET_ALL := "$($(1)_SOURCE_NAME)"
$(1)_DESC := "Build $($(1)_SOURCE_NAME) packages for all distros"
HELP_VARS_PACKAGE += $(1)
endef


###################################################
#
# xx.9. The whole enchilada

define STANDARD_BUILD
$(call UPDATE_SUBMODULE,$(1))
$(call DOWNLOAD_TARBALL,$(1))
$(call UNPACK_TARBALL,$(1))
$(call DEBIANIZE_SOURCE,$(1))
$(call CONFIGURE_SOURCE_PACKAGE,$(1))
$(call UPDATE_CHROOT_DEPS,$(1))
$(call BUILD_SOURCE_PACKAGE,$(1))
$(call BUILD_BINARY_PACKAGE,$(1))
$(call UPDATE_PPA,$(1))
$(call ADD_HOOKS,$(1))
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

INFRA_TARGET_ALL := "infra"
INFRA_DESC := "Convenience:  Build all common infra \(chroots, etc.\)"
HELP_VARS_COMMON += INFRA

###################################################
# 91.  Help targets
#
# These present help for humans

# Print arch target help
define HELP_ARCH
	@echo "	$(patsubst %,$($(1)_TARGET_ARCH),\<distro\>-\<arch\>):"
	@echo "			$($(1)_DESC)"

endef
# Print arch-independent target help
define HELP_INDEP
	@echo "	$(patsubst %,$($(1)_TARGET_INDEP),\<distro\>):"
	@echo "			$($(1)_DESC)"

endef
# Print arch- and distro-independent target help
define HELP_ALL
	@echo "	$($(1)_TARGET_ALL):"
	@echo "			$($(1)_DESC)"

endef
# Print help for a particular section
define HELP_SECTION
	@echo "$(1) TARGETS:"
	$(foreach var,$(HELP_VARS_$(1)),\
	    $(if $($(var)_TARGET_INDEP),\
		$(call HELP_INDEP,$(var)),\
	    $(if $($(var)_TARGET_ARCH),\
		$(call HELP_ARCH,$(var)),\
		$(call HELP_ALL,$(var)))))
endef

help:
	$(foreach sec,UTIL COMMON PACKAGE,$(call HELP_SECTION,$(sec)))
.PHONY: help

# Help for a package
# $$(call PACKAGE_TARGET_HELP,CZMQ,update-ppa,INDEP)
define ECHO
	@echo "$(1)"
endef
define PACKAGE_TARGET_HELP
	$(foreach t,$(call STAMP_EXPAND,$(1),$(2)),$(call ECHO,	$(t)))
	@echo "			$(TARGET_$(1)_$(2)_DESC)"

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

PBUILDERRC_TARGET_ALL := "util-%.pbuilderrc"
PBUILDERRC_DESC := "Output variables needed in a distro pbuilderrc"
HELP_VARS_COMMON += PBUILDERRC

###################################################
# 99. Final Targets
#
# 99.0. Final target for each distro
#
# wheezy.all
$(call C_EXPAND,%.all): \
%.all: \
	$(FINAL_DEPS_INDEP)
.PHONY: $(call C_EXPAND,%.all)

# Final target
all: \
	$(call C_EXPAND,%.all)
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
$(call C_TO_CA_DEPS,%.clean,%.clean)
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
