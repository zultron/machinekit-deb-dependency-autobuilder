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
CODENAMES = precise lucid hardy wheezy squeeze

# Keyring:  Ubuntu, Squeeze, & Wheezy keys
KEYIDS = 40976EAF437D05B5 AED4B06F473041FA 8B48AD6246925553
KEYRING = $(TOPDIR)/admin/keyring.gpg
KEYSERVER = hkp://keys.gnupg.net

# Xenomai package
PACKAGES += xenomai
GITURL_XENOMAI = git://github.com/zultron/xenomai-src.git
GITBRANCH_XENOMAI = v2.6.2.1-deb

# Linux package
PACKAGES += linux
GITURL_LINUX = git://github.com/zultron/kernel-rt-deb.git
GITBRANCH_LINUX = master
LINUX_URL = http://www.kernel.org/pub/linux/kernel/v3.0
LINUX_VERSION = 3.5.7


###################################################
# Variables that should not change much
# (or auto-generated)

# Other variables
TOPDIR = $(shell pwd)
SUDO = sudo
DIRS = admin tmp src git
ALLDIRS = $(patsubst %,%/.dir-exists,$(DIRS) $(CODENAMES))
BASE_CHROOT_TARBALLS = $(foreach C,$(CODENAMES),$(foreach A,$(ARCHES),\
  $(C)/base-$(A).tgz))
LINUX_TARBALL = linux-$(LINUX_VERSION).tar.bz2
ALLSTAMPS = $(foreach c,$(CODENAMES),\
	$(foreach a,$(ARCHES),\
	$(foreach p,$(PACKAGES),$(c)/$(a)/.stamp-$(p))))
PBUILD = TOPDIR=$(TOPDIR) pbuilder
PBUILD_ARGS = --configfile pbuild/pbuilderrc --allow-untrusted

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
	@echo BASE_CHROOT_TARBALLS:
	@for i in $(BASE_CHROOT_TARBALLS); do echo "    $$i"; done
	@echo ALLTAMPS:
	@for i in $(ALLSTAMPS); do echo "    $$i"; done


###################################################
# Base chroot tarball rules

admin/keyring.gpg: admin/.dir-exists Makefile
	gpg --no-default-keyring --keyring=$(KEYRING) \
		--keyserver=$(KEYSERVER) --recv-keys \
		--trust-model always $(KEYIDS)
	test -f $@ && touch $@

# base chroot tarballs are named e.g. lucid/i386/base.tgz
# in this case, $(*D) = lucid; $(*F) = i386
.PRECIOUS:  %/base.tgz
%/base.tgz: admin/keyring.gpg %/aptcache/.dir-exists
	$(SUDO) DIST=$(*D) ARCH=$(*F) \
	    $(PBUILD) --create \
		$(PBUILD_ARGS) || \
	    (rm -f $@ && exit 1)

# Update the base chroot to pick up the Xenomai runtime packages,
# prerequisite to the Xenomai kernel package build
%/.stamp-base.tgz-xenomai-updated: %/.stamp-xenomai-ppa
	$(SUDO) DIST=$(*D) ARCH=$(*F) INTERMEDIATE_REPO=$*/ppa \
	    $(PBUILD) --update --override-config \
		$(PBUILD_ARGS) || \
	    (rm -f $@ && exit 1)


###################################################
# Xeno build rules

# clone & update the xenomai submodule
git/.stamp-xenomai: git/.dir-exists
	# be sure the submodule has been checked out
	test -f git/xenomai/.git || \
           git submodule update --init -- git/xenomai
	git submodule update git/xenomai
	touch $@

# create the source package
src/.stamp-xenomai: src/.dir-exists git/.stamp-xenomai
	rm -f src/xenomai_*
	cd src && dpkg-source -i -I -b $(TOPDIR)/git/xenomai
	touch $@

# build the binary packages
%/.stamp-xenomai: src/.stamp-xenomai %/base.tgz %/pkgs/.dir-exists
	$(SUDO) DIST=$(*D) ARCH=$(*F) $(PBUILD) \
		--build $(PBUILD_ARGS) \
	    src/xenomai_*.dsc || \
	    (rm -f $@ && exit 1)
	touch $@


###################################################
# PPA build rules

# generate an intermediate PPA including the xenomai runtime pkgs,
# needed to build the kernel
#
# if one already exists, blow it away and start from scratch
%/.stamp-xenomai-ppa:  %/.stamp-xenomai %/ppa/conf/.dir-exists
	rm -rf $*/ppa/db $*/ppa/dists $*/ppa/pool
	cat admin/ppa-distributions.tmpl | sed \
		-e "s/@codename@/$(*D)/g" \
		-e "s/@origin@/Xenomai-build-intermediate/g" \
		-e "s/@arch@/$(*F)/g" \
		> $*/ppa/conf/distributions
	reprepro -C main -Vb $*/ppa includedeb $(*D) $*/pkgs/*.deb
	touch $@


###################################################
# Kernel build rules

git/linux/debian/changelog: git/.dir-exists
	# be sure the submodule has been checked out
	git submodule update --recursive --init git/linux/debian

src/$(LINUX_TARBALL):
	test -d src || mkdir -p src
	cd src && wget $(LINUX_URL)/$(LINUX_TARBALL)

git/.stamp-linux: src/$(LINUX_TARBALL)
	# unpack tarball into git directory
	tar xjCf git/linux src/$(LINUX_TARBALL) --strip-components=1


src/.stamp-linux: git/.stamp-linux git/linux/debian/changelog
	# create source pkg
	rm -f src/linux-source-*
	cd src && dpkg-source -i -I -b $(TOPDIR)/git/linux
	touch $@

# build kernel packages, including the PPA with xenomai devel packages
%/.stamp-linux: src/.stamp-linux %/base.tgz %/.stamp-xenomai-ppa \
		%/.stamp-base.tgz-xenomai-updated
	test -d $(*D)/pkgs || mkdir -p $(*D)/pkgs
	$(SUDO) DIST=$(*D) ARCH=$(*F) INTERMEDIATE_REPO=$*/ppa \
	    $(PBUILD) --build \
		$(PBUILD_ARGS) \
	        src/linux-source-*.dsc || \
	    (rm -f $@ && exit 1)
	touch $@

