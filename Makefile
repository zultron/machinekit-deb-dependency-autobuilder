
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
	# wheezy-armhf \
	# jessie-amd64 \
	# jessie-i386
# Precise doesn't have gcc 4.7; using gcc 4.6 might be the cause of
# the kernel module problems I've been finding
	# precise-amd64 \
	# precise-i386 \

# Define this to have a deterministic chroot for step 5.4
A_CHROOT = wheezy-amd64

# Debian package signature keys
UBUNTU_KEYID = 40976EAF437D05B5
DEBIAN_KEYID = 8B48AD6246925553
KEYIDS = $(UBUNTU_KEYID) $(DEBIAN_KEYID)
KEYSERVER = hkp://keys.gnupg.net

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

# A random chroot to configure a source package in
# (The kernel configuration depends on packages being installed)
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

# PPA help target:  print PPA contents
$(call C_EXPAND,util-%.list-ppa): \
util-%.list-ppa:
	$(call LIST_PPA,info,$(CODENAME))

INFO_PPA_LIST_TARGET_INDEP := "util-%.list-ppa"
INFO_PPA_LIST_DESC := "List current PPA contents for a distro"
INFO_PPA_LIST_SECTION := info
HELP_VARS += INFO_PPA_LIST



###################################################
# 0. Basic build dependencies
#
# 0.1 Generic target for non-<codename>/<arch>-specific targets
stamps/0.1.base-builddeps:
	@echo "===== 0.1. All:  Initialize basic build deps ====="
	mkdir -p git dist src stamps pkgs aptcache chroots logs
	touch $@
ifneq ($(DEBUG),yes)
# While hacking, don't rebuild everything whenever a file is changed
stamps/0.1.base-builddeps: \
		Makefile \
		pbuild/pbuilderrc \
		.gitmodules
endif
.PRECIOUS:  stamps/0.1.base-builddeps
INFRA_TARGETS_ALL += stamps/0.1.base-builddeps

stamps/0.1.base-builddeps-squeaky:
	rm -f stamps/0.1.base-builddeps
SQUEAKY_ALL += stamps/0.1.base-builddeps-squeaky


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
.PRECIOUS:  $(call C_EXPAND,stamps/0.2.%.ppa-init)

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
.PRECIOUS: stamps/0.3.all.ppa-init
INFRA_TARGETS_ALL += stamps/0.3.all.ppa-init

stamps/0.3.all.ppa-init-squeaky: \
	$(call C_EXPAND,stamps/0.2.%.ppa-init-squeaky)
	@echo "0.3.  All:  Remove ppa directories"
	rm -rf ppa
SQUEAKY_ALL += stamps/0.3.all.ppa-init-squeaky

PPA_INIT_TARGET_INDEP := "stamps/0.3.all.ppa-init"
PPA_INIT_DESC := "Create basic PPA directories and initial configuration"
PPA_INIT_SECTION := common
HELP_VARS += PPA_INIT


###################################################
# 1. GPG keyring

# 1.1 Download GPG keys for the various distros, needed by pbuilder

stamps/1.1.keyring-downloaded:
	@echo "===== 1.1. All variants:  Creating GPG keyring ====="
	$(REASON)
	mkdir -p admin
	gpg --no-default-keyring --keyring=$(KEYRING) \
		--keyserver=$(KEYSERVER) --recv-keys \
		--trust-model always \
		$(KEYIDS)
	test -f $(KEYRING) && touch $@  # otherwise, fail
.PRECIOUS:  stamps/1.1.keyring-downloaded
INFRA_TARGETS_ALL += stamps/1.1.keyring-downloaded

stamps/1.1.keyring-downloaded-squeaky:
	@echo "1.1. All:  Cleaning package GPG keyring"
	rm -f $(KEYRING)
	rm -f stamps/1.1.keyring-downloaded
SQUEAKY_ALL += stamps/1.1.keyring-downloaded-squeaky

KEYRING_TARGET_ALL := "stamps/1.1.keyring-downloaded"
KEYRING_DESC := "Download upstream distro GPG keys"
KEYRING_SECTION := common
HELP_VARS += KEYRING


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
INFRA_TARGETS_ARCH += stamps/2.1.%.chroot-build

2.1.clean.%.chroot:  stamps/2.1.%.chroot-build
	@echo "2.1. $(CA):  Cleaning chroot tarball"
	rm -f chroots/base-$(CA).tgz
	rm -f stamps/2.1-$(CA)-chroot-build
SQUEAKY_ARCH += 2.1.clean.%.chroot


#
# Log into chroot
#
$(call CA_EXPAND,util-%.chroot): \
util-%.chroot: \
		stamps/2.1.%.chroot-build
	@echo "===== Logging into $(*) pbuilder chroot ====="
	$(REASON)
	$(SUDO) INTERMEDIATE_REPO=ppa \
	    $(PBUILD) --login \
		--bindmounts $(TOPDIR) \
		$(PBUILD_ARGS)
.PHONY:  $(call CA_EXPAND,%.chroot)

CHROOT_LOGIN_TARGET_ARCH := "util-%.chroot"
CHROOT_LOGIN_DESC := "Log into a chroot"
CHROOT_LOGIN_SECTION := info
HELP_VARS += CHROOT_LOGIN



###################################################
# 03.  Info targets
#
# These present help for humans

# Print arch target help
define HELP_ARCH
	@echo "$(patsubst %,$($(1)_TARGET_ARCH),\<distro\>-\<arch\>):	$($(1)_DESC)"

endef
# Print arch-independent target help
define HELP_INDEP
	@echo "$(patsubst %,$($(1)_TARGET_INDEP),\<distro\>):	$($(1)_DESC)"

endef
# Print arch- and distro-independent target help
define HELP_ALL
	@echo "$($(1)_TARGET_ALL):	$($(1)_DESC)"

endef

help:
	$(foreach var,$(HELP_VARS),\
	    $(if $($(var)_TARGET_INDEP),\
		$(call HELP_INDEP,$(var)),\
	    $(if $($(var)_TARGET_ARCH),\
		$(call HELP_ARCH,$(var)),\
		$(call HELP_ALL,$(var)))))
.PHONY: help

###################################################
# Include package build makefiles

-include $(wildcard Makefile.*.mk)


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
INFRA_SECTION := common
HELP_VARS += INFRA

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
