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
#CODENAMES = precise lucid hardy wheezy squeeze
#
# FIXME disabling hardy; autoconf >= 2.62 required by xenomai, but
# hardy has 2.61
CODENAMES = precise lucid wheezy squeeze

# Keyring:  Ubuntu, Squeeze, & Wheezy keys
KEYIDS = 40976EAF437D05B5 AED4B06F473041FA 8B48AD6246925553
KEYSERVER = hkp://keys.gnupg.net

# Xenomai git repo
GITURL_XENOMAI = git://github.com/zultron/xenomai-src.git
GITBRANCH_XENOMAI = v2.6.2.1-deb

# Linux debian git repo and vanilla tarball
GITURL_LINUX = git://github.com/zultron/kernel-rt-deb.git
GITBRANCH_LINUX = master
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
LINUX_TARBALL = linux-$(LINUX_VERSION).tar.bz2
KEYRING = $(TOPDIR)/admin/keyring.gpg
PACKAGES = xenomai linux
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
	# be sure the submodule has been checked out
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
# PPA build rules

# generate an intermediate PPA including the xenomai runtime pkgs,
# needed to build the kernel
#
# if one already exists, blow it away and start from scratch
%/.stamp-xenomai-ppa:  %/.stamp-builddeps %/.stamp-xenomai
	@echo "===== Building Xenomai PPA ====="
	rm -rf $*/ppa/db $*/ppa/dists $*/ppa/pool
	cat pbuild/ppa-distributions.tmpl | sed \
		-e "s/@codename@/$(*D)/g" \
		-e "s/@arch@/$(*F)/g" \
		> $*/ppa/conf/distributions
	reprepro -C main -VVb $*/ppa includedeb $(*D) $*/pkgs/*.deb
	touch $@


###################################################
# Update base.tgz with PPA pkgs

# Update the base chroot to pick up the Xenomai runtime packages,
# prerequisite to the Xenomai kernel package build
%/.stamp-base.tgz-xenomai-updated: %/.stamp-xenomai-ppa
	@echo "===== Updating pbuilder chroot with Xenomai PPA packages ====="
	$(SUDO) DIST=$(*D) ARCH=$(*F) INTERMEDIATE_REPO=$*/ppa \
	    $(PBUILD) --update --override-config \
		$(PBUILD_ARGS)
	touch $@


###################################################
# Kernel build rules

git/linux/debian/changelog: git/.dir-exists
	@echo "===== Checking out kernel Debian git repo ====="
	# be sure the submodule has been checked out
	git submodule update --recursive --init git/linux/debian

src/$(LINUX_TARBALL):
	@echo "===== Downloading vanilla Linux tarball ====="
	test -d src || mkdir -p src
	cd src && wget $(LINUX_URL)/$(LINUX_TARBALL)

git/.stamp-linux: git/.dir-exists src/$(LINUX_TARBALL)
	@echo "===== Unpacking Linux tarball ====="
	# unpack tarball into git directory
	tar xjCf git/linux src/$(LINUX_TARBALL) --strip-components=1


src/.stamp-linux: git/.stamp-linux git/linux/debian/changelog
	@echo "===== Building Linux source package ====="
	# create source pkg
	rm -f src/linux-source-*
	cd src && dpkg-source -i -I -b $(TOPDIR)/git/linux
	touch $@

# build kernel packages, including the PPA with xenomai devel packages
%/.stamp-linux: %/.stamp-builddeps src/.stamp-linux \
		%/.stamp-base.tgz-xenomai-updated
	@echo "===== Building Linux binary package ====="
	$(SUDO) DIST=$(*D) ARCH=$(*F) INTERMEDIATE_REPO=$*/ppa \
	    $(PBUILD) --build \
		$(PBUILD_ARGS) \
	        src/linux-source-*.dsc || \
	    (rm -f $@ && exit 1)
	touch $@

