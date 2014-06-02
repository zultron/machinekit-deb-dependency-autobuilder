###################################################
# 50. czmq build rules
#
# Not in Debian

###################################################
# Variables that may change

# Czmq package versions
CZMQ_PKG_RELEASE = 0~1mk
CZMQ_VERSION = 2.2.0


###################################################
# Variables that should not change much
# (or auto-generated)

# Packages; will be suffixed by _<pkg_version>_<arch>.deb
# (may contain wildcards)
CZMQ_PKGS_ALL := 
CZMQ_PKGS_ARCH := libczmq2 libczmq-dbg libczmq-dev

# Misc paths, filenames, executables
CZMQ_URL = http://download.zeromq.org
CZMQ_TARBALL := czmq-$(CZMQ_VERSION).tar.gz
CZMQ_TARBALL_DEBIAN_ORIG := czmq_$(CZMQ_VERSION).orig.tar.gz
CZMQ_PKG_VERSION = $(CZMQ_VERSION)-$(CZMQ_PKG_RELEASE)~$(CODENAME)1

# Dependencies on other locally-built packages
#
# Arch- and distro-dependent targets
CZMQ_DEPS_ARCH = 
# Arch-independent (but distro-dependent) targets
CZMQ_DEPS_INDEP = $(ZEROMQ4_INDEP) $(LIBSODIUM_INDEP)
# Targets built for all distros and arches
CZMQ_DEPS = 


###################################################
# 50.1. Download Czmq tarball distribution
stamps/50.1.czmq-tarball-download: \
		stamps/0.1.base-builddeps
	@echo "===== 50.1. All variants:  Downloading Czmq tarball ====="
	$(REASON)
	mkdir -p dist
	wget $(CZMQ_URL)/$(CZMQ_TARBALL) -O dist/$(CZMQ_TARBALL)
	touch $@
.PRECIOUS: stamps/50.1.czmq-tarball-download

stamps/50.1.czmq-tarball-download-squeaky: \
		$(call C_EXPAND,stamps/50.3.%.czmq-build-source-clean)
	@echo "50.1. All:  Clean czmq tarball"
	rm -f dist/$(CZMQ_TARBALL)
	rm -f stamps/50.1.czmq-tarball-download
CZMQ_SQUEAKY_ALL += stamps/50.1.czmq-tarball-download-squeaky


###################################################
# 50.2. Set up Czmq sources
stamps/50.2.czmq-source-setup: \
		stamps/50.1.czmq-tarball-download
	@echo "===== 50.2. All: " \
	    "Setting up Czmq source ====="
#	# Unpack source
	rm -rf src/czmq/build; mkdir -p src/czmq/build
	tar xC src/czmq/build --strip-components=1 \
	    -f dist/$(CZMQ_TARBALL)
#	# Unpack debianization
	git --git-dir="git/czmq-deb/.git" archive --prefix=debian/ HEAD \
	    | tar xCf src/czmq/build -
#	# Make clean copy of changelog for later munging
	cp --preserve=all src/czmq/build/debian/changelog \
	    src/czmq
#	# Link source tarball with Debian name
	ln -f dist/$(CZMQ_TARBALL) \
	    src/czmq/$(CZMQ_TARBALL_DEBIAN_ORIG)
	ln -f dist/$(CZMQ_TARBALL) \
	    pkgs/$(CZMQ_TARBALL_DEBIAN_ORIG)
	touch $@

$(call C_EXPAND,stamps/50.2.%.czmq-source-setup-clean): \
stamps/50.2.%.czmq-source-setup-clean: \
		$(call C_EXPAND,stamps/50.3.%.czmq-build-source-clean)
	@echo "50.2. All:  Clean czmq sources"
	rm -rf src/czmq
CZMQ_CLEAN_INDEP += stamps/50.2.%.czmq-source-setup-clean


###################################################
# 50.3. Build Czmq source package for each distro
$(call C_EXPAND,stamps/50.3.%.czmq-build-source): \
stamps/50.3.%.czmq-build-source: \
		stamps/50.2.czmq-source-setup
	@echo "===== 50.3. $(CODENAME)-all: " \
	    "Building Czmq source package ====="
	$(REASON)
#	# Restore original changelog
	cp --preserve=all src/czmq/changelog \
	    src/czmq/build/debian
#	# Add changelog entry
	cd src/czmq/build && \
	    $(TOPDIR)/pbuild/tweak-pkg.sh \
	    $(CODENAME) $(CZMQ_PKG_VERSION) "$(MAINTAINER)"
#	# Build source package
	cd src/czmq/build && dpkg-source -i -I -b .
	mv src/czmq/czmq_$(CZMQ_PKG_VERSION).debian.tar.gz \
	    src/czmq/czmq_$(CZMQ_PKG_VERSION).dsc pkgs
	touch $@
.PRECIOUS:  $(call C_EXPAND,stamps/50.3.%.czmq-build-source)

$(call C_EXPAND,stamps/50.3.%.czmq-build-source-clean): \
stamps/50.3.%.czmq-build-source-clean:
	@echo "50.3. $(CODENAME):  Clean czmq source package"
	rm -f pkgs/czmq_$(CZMQ_PKG_VERSION).dsc
	rm -f pkgs/$(CZMQ_TARBALL_DEBIAN_ORIG)
	rm -f pkgs/czmq_$(CZMQ_PKG_VERSION).debian.tar.gz
	rm -f stamps/50.3.$(CODENAME).czmq-build-source
$(call C_TO_CA_DEPS,stamps/50.3.%.czmq-build-source-clean,\
	stamps/50.5.%.czmq-build-binary-clean)
CZMQ_CLEAN_INDEP += stamps/50.3.%.czmq-build-source-clean


###################################################
# 50.4. Update chroot with locally-built dependent packages
#
# This is only built if deps are defined in the top section
ifneq ($(CZMQ_DEPS_ARCH)$(CZMQ_DEPS_INDEP)$(CZMQ_DEPS),)

$(call CA_TO_C_DEPS,stamps/50.4.%.czmq-deps-update-chroot,\
	$(CZMQ_DEPS_INDEP))
$(call CA_EXPAND,stamps/50.4.%.czmq-deps-update-chroot): \
stamps/50.4.%.czmq-deps-update-chroot: \
		$(CZMQ_DEPS)
	$(call UPDATE_CHROOT,50.4)
.PRECIOUS: $(call CA_EXPAND,stamps/50.4.%.czmq-deps-update-chroot)

# Binary package build dependent on chroot update
CZMQ_CHROOT_UPDATE_DEP := stamps/50.4.%.czmq-deps-update-chroot

$(call CA_EXPAND,stamps/50.4.%.czmq-deps-update-chroot-clean): \
stamps/50.4.%.czmq-deps-update-chroot-clean: \
		stamps/50.5.%.czmq-build-binary-clean
	@echo "50.4. $(CA):  Clean czmq chroot deps update stamp"
	rm -f stamps/50.4.$(CA).czmq-deps-update-chroot
# Hook clean target into previous target
$(call C_TO_CA_DEPS,stamps/50.3.%.czmq-build-source-clean,\
	stamps/50.4.%.czmq-deps-update-chroot)
# Cleaning this cleans up all (non-squeaky) czmq arch and indep artifacts
CZMQ_CLEAN_ARCH += stamps/50.4.%.czmq-deps-update-chroot-clean

endif # Deps on other locally-built packages


###################################################
# 50.5. Build Czmq binary packages for each distro/arch
#
#   Only build binary-indep packages once:
stamps/50.5.%.czmq-build-binary: \
	BUILDTYPE = $(if $(findstring $(ARCH),$(AN_ARCH)),-b,-B)

$(call CA_TO_C_DEPS,stamps/50.5.%.czmq-build-binary,\
	stamps/50.3.%.czmq-build-source)
$(call CA_EXPAND,stamps/50.5.%.czmq-build-binary): \
stamps/50.5.%.czmq-build-binary: \
		stamps/2.1.%.chroot-build \
		$(CZMQ_CHROOT_UPDATE_DEP)
	@echo "===== 50.5. $(CA): " \
	    "Building Czmq binary packages ====="
	$(REASON)
	$(SUDO) INTERMEDIATE_REPO=ppa \
	    $(PBUILD) --build \
	    $(PBUILD_ARGS) \
	    --debbuildopts $(BUILDTYPE) \
	    pkgs/czmq_$(CZMQ_PKG_VERSION).dsc
	touch $@
.PRECIOUS: $(call CA_EXPAND,stamps/50.5.%.czmq-build-binary)

$(call CA_EXPAND,stamps/50.5.%.czmq-build-binary-clean): \
stamps/50.5.%.czmq-build-binary-clean:
	@echo "50.5. $(CA):  Clean Czmq binary build"
	rm -f $(patsubst %,pkgs/%_$(CZMQ_PKG_VERSION)_all.deb,\
	    $(CZMQ_PKGS_ALL))
	rm -f $(patsubst %,pkgs/%_$(CZMQ_PKG_VERSION)_$(ARCH).deb,\
	    $(CZMQ_PKGS_ARCH))
	rm -f pkgs/czmq_$(CZMQ_PKG_VERSION)-$(ARCH).build
	rm -f pkgs/czmq_$(CZMQ_PKG_VERSION)_$(ARCH).changes
	rm -f stamps/50.5-$(CA)-czmq-build
$(call CA_TO_C_DEPS,stamps/50.5.%.czmq-build-binary-clean,\
	stamps/50.6.%.czmq-ppa-clean)


###################################################
# 50.6. Add Czmq packages to the PPA for each distro
$(call C_TO_CA_DEPS,stamps/50.6.%.czmq-ppa,\
	stamps/50.5.%.czmq-build-binary)
$(call C_EXPAND,stamps/50.6.%.czmq-ppa): \
stamps/50.6.%.czmq-ppa: \
		stamps/50.3.%.czmq-build-source \
		stamps/0.3.all.ppa-init
	$(call BUILD_PPA,50.6,czmq,\
	    pkgs/czmq_$(CZMQ_PKG_VERSION).dsc,\
	    $(patsubst %,pkgs/%_$(CZMQ_PKG_VERSION)_all.deb,\
		$(CZMQ_PKGS_ALL)) \
	    $(foreach a,$(call CODENAME_ARCHES,$(CODENAME)),$(wildcard\
		$(patsubst %,pkgs/%_$(CZMQ_PKG_VERSION)_$(a).deb,\
		    $(CZMQ_PKGS_ARCH)))))
# Only build for wheezy
CZMQ_INDEP := stamps/50.6.%.czmq-ppa

$(call C_EXPAND,stamps/50.6.%.czmq-ppa-clean): \
stamps/50.6.%.czmq-ppa-clean:
	@echo "50.6. $(CODENAME):  Clean Czmq PPA stamp"
	rm -f stamps/50.6.$(CODENAME).czmq-ppa


# Hook Czmq builds into final builds, if configured
FINAL_DEPS_INDEP += $(CZMQ_INDEP)
SQUEAKY_ALL += $(CZMQ_SQUEAKY_ALL)
CLEAN_INDEP += $(CZMQ_CLEAN_INDEP)
