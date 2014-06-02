###################################################
# 40. libwebsockets build rules
#
# Included by Makefile.main.libwebsockets.mk

###################################################
# Variables that may change

# Libwebsockets package versions
#
# Built from a git revision
LIBWEBSOCKETS_GIT_REV = dfca3abf
# Be conservative with the pkg release, since Debian carries this package
LIBWEBSOCKETS_PKG_RELEASE = 0.1mk~git$(LIBWEBSOCKETS_GIT_REV)
LIBWEBSOCKETS_VERSION = 2.2
LIBWEBSOCKETS_URL = http://git.libwebsockets.org/cgi-bin/cgit/libwebsockets/snapshot


###################################################
# Variables that should not change much
# (or auto-generated)

# Packages; will be suffixed by _<pkg_version>_<arch>.deb
LIBWEBSOCKETS_PKGS_ALL := 
LIBWEBSOCKETS_PKGS_ARCH := libwebsockets3 libwebsockets-dev \
	libwebsockets-test-server libwebsockets3-dbg

# Misc paths, filenames, executables
LIBWEBSOCKETS_TARBALL := libwebsockets-$(LIBWEBSOCKETS_GIT_REV).tar.gz
LIBWEBSOCKETS_TARBALL_DEBIAN_ORIG := libwebsockets_$(LIBWEBSOCKETS_VERSION).orig.tar.gz
LIBWEBSOCKETS_PKG_VERSION = $(LIBWEBSOCKETS_VERSION)-$(LIBWEBSOCKETS_PKG_RELEASE)~$(CODENAME)1


###################################################
# 40.0. Update Libwebsockets submodule
stamps/40.0.libwebsockets-checkout-submodule:
	@echo "===== 40.0. All: " \
	    "Check out libwebsockets submodule ====="
#	# be sure the submodule has been checked out
	test -e git/libwebsockets-deb/.git || \
	    git submodule update --init git/libwebsockets-deb
	test -e git/libwebsockets-deb/.git
	touch $@


###################################################
# 40.1. Download Libwebsockets tarball distribution
stamps/40.1.libwebsockets-tarball-download: \
		stamps/0.1.base-builddeps
	@echo "===== 40.1. All variants:  Downloading Libwebsockets tarball ====="
	$(REASON)
	mkdir -p dist
	wget $(LIBWEBSOCKETS_URL)/$(LIBWEBSOCKETS_TARBALL) -O dist/$(LIBWEBSOCKETS_TARBALL)
	touch $@
.PRECIOUS: stamps/40.1.libwebsockets-tarball-download

stamps/40.1.libwebsockets-tarball-download-squeaky: \
		$(call C_EXPAND,stamps/40.3.%.libwebsockets-build-source-clean)
	@echo "40.1. All:  Clean libwebsockets tarball"
	rm -f dist/$(LIBWEBSOCKETS_TARBALL)
	rm -f stamps/40.1.libwebsockets-tarball-download
LIBWEBSOCKETS_SQUEAKY_ALL += stamps/40.1.libwebsockets-tarball-download-squeaky


###################################################
# 40.1.1. Check out git submodule
stamps/40.1.1.libwebsockets-package-checkout: \
		stamps/0.1.base-builddeps
	@echo "===== 40.1.1. All variants: "\
	    "Checking out libwebsockets Debian git repo ====="
	$(REASON)
#	# be sure the submodule has been checked out
	mkdir -p git/libwebsockets-deb
	test -f git/libwebsockets-deb/.git || \
           git submodule update --init -- git/libwebsockets-deb
	git submodule update git/libwebsockets-deb
	touch $@

stamps/40.1.1.libwebsockets-package-checkout-clean: \
		$(call C_EXPAND,stamps/40.3.%.libwebsockets-build-source-clean)
	@echo "40.1.1. All:  Clean libwebsockets packaging git submodule stamp"
	rm -f stamps/40.1.1.libwebsockets-package-checkout
LIBWEBSOCKETS_CLEAN_ALL += stamps/40.1.1.libwebsockets-package-checkout-clean

stamps/40.1.1.libwebsockets-package-checkout-squeaky: \
		stamps/40.1.1.libwebsockets-package-checkout-clean
	@echo "40.1.1. All:  Clean libwebsockets packaging git submodule"
	rm -rf git/libwebsockets-deb; mkdir -p git/libwebsockets-deb
LIBWEBSOCKETS_SQUEAKY_ALL += stamps/40.1.1.libwebsockets-package-checkout-squeaky


###################################################
# 40.2. Set up Libwebsockets sources
stamps/40.2.libwebsockets-source-setup: \
		stamps/40.1.libwebsockets-tarball-download \
		stamps/40.1.1.libwebsockets-package-checkout
	@echo "===== 40.2. All: " \
	    "Setting up Libwebsockets source ====="
#	# Unpack source
	rm -rf src/libwebsockets/build; mkdir -p src/libwebsockets/build
	tar xC src/libwebsockets/build --strip-components=1 \
	    -f dist/$(LIBWEBSOCKETS_TARBALL)
#	# Unpack debianization
	git --git-dir="git/libwebsockets-deb/.git" archive --prefix=debian/ HEAD \
	    | tar xCf src/libwebsockets/build -
#	# Make clean copy of changelog for later munging
	cp --preserve=all src/libwebsockets/build/debian/changelog \
	    src/libwebsockets
#	# Link source tarball with Debian name
	ln -f dist/$(LIBWEBSOCKETS_TARBALL) \
	    src/libwebsockets/$(LIBWEBSOCKETS_TARBALL_DEBIAN_ORIG)
	ln -f dist/$(LIBWEBSOCKETS_TARBALL) \
	    pkgs/$(LIBWEBSOCKETS_TARBALL_DEBIAN_ORIG)
	touch $@

$(call C_EXPAND,stamps/40.2.%.libwebsockets-source-setup-clean): \
stamps/40.2.%.libwebsockets-source-setup-clean: \
		$(call C_EXPAND,stamps/40.3.%.libwebsockets-build-source-clean)
	@echo "40.2. All:  Clean libwebsockets sources"
	rm -rf src/libwebsockets
LIBWEBSOCKETS_CLEAN_INDEP += stamps/40.2.%.libwebsockets-source-setup-clean


###################################################
# 40.3. Build Libwebsockets source package for each distro
$(call C_EXPAND,stamps/40.3.%.libwebsockets-build-source): \
stamps/40.3.%.libwebsockets-build-source: \
		stamps/40.2.libwebsockets-source-setup
	@echo "===== 40.3. $(CODENAME)-all: " \
	    "Building Libwebsockets source package ====="
	$(REASON)
#	# Restore original changelog
	cp --preserve=all src/libwebsockets/changelog \
	    src/libwebsockets/build/debian
#	# Add changelog entry
	cd src/libwebsockets/build && \
	    $(TOPDIR)/pbuild/tweak-pkg.sh \
	    $(CODENAME) $(LIBWEBSOCKETS_PKG_VERSION) "$(MAINTAINER)"
#	# Build source package
	cd src/libwebsockets/build && dpkg-source -i -I -b .
	mv src/libwebsockets/libwebsockets_$(LIBWEBSOCKETS_PKG_VERSION).debian.tar.gz \
	    src/libwebsockets/libwebsockets_$(LIBWEBSOCKETS_PKG_VERSION).dsc pkgs
	touch $@
.PRECIOUS:  $(call C_EXPAND,stamps/40.3.%.libwebsockets-build-source)

$(call C_EXPAND,stamps/40.3.%.libwebsockets-build-source-clean): \
stamps/40.3.%.libwebsockets-build-source-clean:
	@echo "40.3. $(CODENAME):  Clean libwebsockets source package"
	rm -f pkgs/libwebsockets_$(LIBWEBSOCKETS_PKG_VERSION).dsc
	rm -f pkgs/$(LIBWEBSOCKETS_TARBALL_DEBIAN_ORIG)
	rm -f pkgs/libwebsockets_$(LIBWEBSOCKETS_PKG_VERSION).debian.tar.gz
	rm -f stamps/40.3.$(CODENAME).libwebsockets-build-source
$(call C_TO_CA_DEPS,stamps/40.3.%.libwebsockets-build-source-clean,\
	stamps/40.5.%.libwebsockets-build-binary)
LIBWEBSOCKETS_CLEAN_INDEP += stamps/40.3.%.libwebsockets-build-source-clean


###################################################
# 40.4. Update chroot with dependent packages
#
# This is only built if deps are defined in the top section
ifneq ($(LIBWEBSOCKETS_DEPS_ARCH)$(LIBWEBSOCKETS_DEPS_INDEP)$(LIBWEBSOCKETS_DEPS),)

$(call CA_TO_C_DEPS,stamps/40.4.%.libwebsockets-deps-update-chroot,\
	$(LIBWEBSOCKETS_DEPS_INDEP))
$(call CA_EXPAND,stamps/40.4.%.libwebsockets-deps-update-chroot): \
stamps/40.4.%.libwebsockets-deps-update-chroot: \
		$(LIBWEBSOCKETS_DEPS)
	$(call UPDATE_CHROOT,40.4)
.PRECIOUS: $(call CA_EXPAND,stamps/40.4.%.libwebsockets-deps-update-chroot)

# Binary package build dependent on chroot update
LIBWEBSOCKETS_CHROOT_UPDATE_DEP := stamps/40.4.%.libwebsockets-deps-update-chroot

$(call CA_EXPAND,stamps/40.4.%.libwebsockets-deps-update-chroot-clean): \
stamps/40.4.%.libwebsockets-deps-update-chroot-clean: \
		stamps/40.5.%.libwebsockets-build-binary-clean
	@echo "40.4. $(CA):  Clean libwebsockets chroot deps update stamp"
	rm -f stamps/40.4.$(CA).libwebsockets-deps-update-chroot
# Hook clean target into previous target
$(call C_TO_CA_DEPS,stamps/40.3.%.libwebsockets-build-source-clean,\
	stamps/40.4.%.libwebsockets-deps-update-chroot)
# Cleaning this cleans up all (non-squeaky) libwebsockets arch and indep artifacts
LIBWEBSOCKETS_CLEAN_ARCH += stamps/40.4.%.libwebsockets-deps-update-chroot-clean

endif # Deps on other locally-built packages


###################################################
# 40.5. Build Libwebsockets binary packages for each distro/arch
#
#   Only build binary-indep packages once:
stamps/40.5.%.libwebsockets-build-binary: \
	BUILDTYPE = $(if $(findstring $(ARCH),$(AN_ARCH)),-b,-B)

$(call CA_TO_C_DEPS,stamps/40.5.%.libwebsockets-build-binary,\
	stamps/40.3.%.libwebsockets-build-source)
$(call CA_EXPAND,stamps/40.5.%.libwebsockets-build-binary): \
stamps/40.5.%.libwebsockets-build-binary: \
		stamps/2.1.%.chroot-build \
		$(LIBWEBSOCKETS_CHROOT_UPDATE_DEP)
	@echo "===== 40.5. $(CA): " \
	    "Building Libwebsockets binary packages ====="
	$(REASON)
	$(SUDO) INTERMEDIATE_REPO=ppa \
	    $(PBUILD) --build \
	    $(PBUILD_ARGS) \
	    --debbuildopts $(BUILDTYPE) \
	    pkgs/libwebsockets_$(LIBWEBSOCKETS_PKG_VERSION).dsc
	touch $@
.PRECIOUS: $(call CA_EXPAND,stamps/40.5.%.libwebsockets-build-binary)

$(call CA_EXPAND,stamps/40.5.%.libwebsockets-build-binary-clean): \
stamps/40.5.%.libwebsockets-build-binary-clean:
	@echo "40.5. $(CA):  Clean Libwebsockets binary build"
	rm -f $(patsubst %,pkgs/%_$(LIBWEBSOCKETS_PKG_VERSION)_all.deb,\
	    $(LIBWEBSOCKETS_PKGS_ALL))
	rm -f $(patsubst %,pkgs/%_$(LIBWEBSOCKETS_PKG_VERSION)_$(ARCH).deb,\
	    $(LIBWEBSOCKETS_PKGS_ARCH))
	rm -f pkgs/libwebsockets_$(LIBWEBSOCKETS_PKG_VERSION)-$(ARCH).build
	rm -f pkgs/libwebsockets_$(LIBWEBSOCKETS_PKG_VERSION)_$(ARCH).changes
	rm -f stamps/40.5-$(CA)-libwebsockets-build
$(call CA_TO_C_DEPS,stamps/40.5.%.libwebsockets-build-binary-clean,\
	stamps/40.6.%.libwebsockets-ppa-clean)


###################################################
# 40.6. Add Libwebsockets packages to the PPA for each distro
$(call C_TO_CA_DEPS,stamps/40.6.%.libwebsockets-ppa,\
	stamps/40.5.%.libwebsockets-build-binary)
$(call C_EXPAND,stamps/40.6.%.libwebsockets-ppa): \
stamps/40.6.%.libwebsockets-ppa: \
		stamps/40.3.%.libwebsockets-build-source \
		stamps/0.3.all.ppa-init
	$(call BUILD_PPA,40.6,libwebsockets,\
	    pkgs/libwebsockets_$(LIBWEBSOCKETS_PKG_VERSION).dsc,\
	    $(patsubst %,pkgs/%_$(LIBWEBSOCKETS_PKG_VERSION)_all.deb,\
		$(LIBWEBSOCKETS_PKGS_ALL)) \
	    $(foreach a,$(call CODENAME_ARCHES,$(CODENAME)),\
		$(patsubst %,pkgs/%_$(LIBWEBSOCKETS_PKG_VERSION)_$(a).deb,\
		    $(LIBWEBSOCKETS_PKGS_ARCH))))

LIBWEBSOCKETS_INDEP := stamps/40.6.%.libwebsockets-ppa

$(call C_EXPAND,stamps/40.6.%.libwebsockets-ppa-clean): \
stamps/40.6.%.libwebsockets-ppa-clean:
	@echo "40.6. $(CODENAME):  Clean Libwebsockets PPA stamp"
	rm -f stamps/40.6.$(CODENAME).libwebsockets-ppa


###################################################
# 40.7. Wrap up

# Hook Libwebsockets builds into final builds, if configured
FINAL_DEPS_INDEP += $(LIBWEBSOCKETS_INDEP)
SQUEAKY_ALL += $(LIBWEBSOCKETS_SQUEAKY_ALL)
CLEAN_INDEP += $(LIBWEBSOCKETS_CLEAN_INDEP)
CLEAN_ALL += $(LIBWEBSOCKETS_CLEAN_ALL)

# Convenience target
libwebsockets:  $(call C_EXPAND,$(LIBWEBSOCKETS_INDEP))
LIBWEBSOCKETS_TARGET_ALL := "libwebsockets"
LIBWEBSOCKETS_DESC := "Convenience:  Build libwebsockets packages for all distros"
LIBWEBSOCKETS_SECTION := packages
HELP_VARS += LIBWEBSOCKETS
