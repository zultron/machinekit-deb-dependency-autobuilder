###################################################
# 45. jansson build rules
#
# Backported to wheezy from Debian jessie

###################################################
# Variables that may change

# Jansson package versions
JANSSON_PKG_RELEASE = 2~1mk
JANSSON_VERSION = 2.6


###################################################
# Variables that should not change much
# (or auto-generated)

# Packages; will be suffixed by _<pkg_version>_<arch>.deb
# (may contain wildcards)
JANSSON_PKGS_ALL := libjansson-doc
JANSSON_PKGS_ARCH := libjansson4 libjansson-dev libjansson-dbg

# Misc paths, filenames, executables
JANSSON_URL = http://www.digip.org/jansson/releases
JANSSON_TARBALL := jansson-$(JANSSON_VERSION).tar.bz2
JANSSON_TARBALL_DEBIAN_ORIG := jansson_$(JANSSON_VERSION).orig.tar.bz2
JANSSON_PKG_VERSION = $(JANSSON_VERSION)-$(JANSSON_PKG_RELEASE)~$(CODENAME)1

# Dependencies on other locally-built packages
#
# Arch- and distro-dependent targets
JANSSON_DEPS_ARCH = 
# Arch-independent (but distro-dependent) targets
JANSSON_DEPS_INDEP = 
# Targets built for all distros and arches
JANSSON_DEPS = 


###################################################
# 45.1. Download Jansson tarball distribution
stamps/45.1.jansson-tarball-download: \
		stamps/0.1.base-builddeps
	@echo "===== 45.1. All variants:  Downloading Jansson tarball ====="
	$(REASON)
	mkdir -p dist
	wget $(JANSSON_URL)/$(JANSSON_TARBALL) -O dist/$(JANSSON_TARBALL)
	touch $@
.PRECIOUS: stamps/45.1.jansson-tarball-download

stamps/45.1.jansson-tarball-download-squeaky: \
		$(call C_EXPAND,stamps/45.3.%.jansson-build-source-clean)
	@echo "45.1. All:  Clean jansson tarball"
	rm -f dist/$(JANSSON_TARBALL)
	rm -f stamps/45.1.jansson-tarball-download
JANSSON_SQUEAKY_ALL += stamps/45.1.jansson-tarball-download-squeaky


###################################################
# 45.2. Set up Jansson sources
stamps/45.2.jansson-source-setup: \
		stamps/45.1.jansson-tarball-download
	@echo "===== 45.2. All: " \
	    "Setting up Jansson source ====="
#	# Unpack source
	rm -rf src/jansson/build; mkdir -p src/jansson/build
	tar xC src/jansson/build --strip-components=1 \
	    -f dist/$(JANSSON_TARBALL)
#	# Unpack debianization
	git --git-dir="git/jansson-deb/.git" archive --prefix=debian/ HEAD \
	    | tar xCf src/jansson/build -
#	# Make clean copy of changelog for later munging
	cp --preserve=all src/jansson/build/debian/changelog \
	    src/jansson
#	# Link source tarball with Debian name
	ln -f dist/$(JANSSON_TARBALL) \
	    src/jansson/$(JANSSON_TARBALL_DEBIAN_ORIG)
	ln -f dist/$(JANSSON_TARBALL) \
	    pkgs/$(JANSSON_TARBALL_DEBIAN_ORIG)
	touch $@

$(call C_EXPAND,stamps/45.2.%.jansson-source-setup-clean): \
stamps/45.2.%.jansson-source-setup-clean: \
		$(call C_EXPAND,stamps/45.3.%.jansson-build-source-clean)
	@echo "45.2. All:  Clean jansson sources"
	rm -rf src/jansson
JANSSON_CLEAN_INDEP += stamps/45.2.%.jansson-source-setup-clean


###################################################
# 45.3. Build Jansson source package for each distro
$(call C_EXPAND,stamps/45.3.%.jansson-build-source): \
stamps/45.3.%.jansson-build-source: \
		stamps/45.2.jansson-source-setup
	@echo "===== 45.3. $(CODENAME)-all: " \
	    "Building Jansson source package ====="
	$(REASON)
#	# Restore original changelog
	cp --preserve=all src/jansson/changelog \
	    src/jansson/build/debian
#	# Add changelog entry
	cd src/jansson/build && \
	    $(TOPDIR)/pbuild/tweak-pkg.sh \
	    $(CODENAME) $(JANSSON_PKG_VERSION) "$(MAINTAINER)"
#	# Build source package
	cd src/jansson/build && dpkg-source -i -I -b .
	mv src/jansson/jansson_$(JANSSON_PKG_VERSION).debian.tar.gz \
	    src/jansson/jansson_$(JANSSON_PKG_VERSION).dsc pkgs
	touch $@
.PRECIOUS:  $(call C_EXPAND,stamps/45.3.%.jansson-build-source)

$(call C_EXPAND,stamps/45.3.%.jansson-build-source-clean): \
stamps/45.3.%.jansson-build-source-clean:
	@echo "45.3. $(CODENAME):  Clean jansson source package"
	rm -f pkgs/jansson_$(JANSSON_PKG_VERSION).dsc
	rm -f pkgs/$(JANSSON_TARBALL_DEBIAN_ORIG)
	rm -f pkgs/jansson_$(JANSSON_PKG_VERSION).debian.tar.gz
	rm -f stamps/45.3.$(CODENAME).jansson-build-source
$(call C_TO_CA_DEPS,stamps/45.3.%.jansson-build-source-clean,\
	stamps/45.5.%.jansson-build-binary-clean)
JANSSON_CLEAN_INDEP += stamps/45.3.%.jansson-build-source-clean


###################################################
# 45.4. Update chroot with locally-built dependent packages
#
# This is only built if deps are defined in the top section
ifneq ($(JANSSON_DEPS_ARCH)$(JANSSON_DEPS_INDEP)$(JANSSON_DEPS),)

$(call CA_TO_C_DEPS,stamps/45.4.%.jansson-deps-update-chroot,\
	$(JANSSON_DEPS_INDEP))
$(call CA_EXPAND,stamps/45.4.%.jansson-deps-update-chroot): \
stamps/45.4.%.jansson-deps-update-chroot: \
		$(JANSSON_DEPS)
	$(call UPDATE_CHROOT,45.4)
.PRECIOUS: $(call CA_EXPAND,stamps/45.4.%.jansson-deps-update-chroot)

# Binary package build dependent on chroot update
JANSSON_CHROOT_UPDATE_DEP := stamps/45.4.%.jansson-deps-update-chroot

$(call CA_EXPAND,stamps/45.4.%.jansson-deps-update-chroot-clean): \
stamps/45.4.%.jansson-deps-update-chroot-clean: \
		stamps/45.5.%.jansson-build-binary-clean
	@echo "45.4. $(CA):  Clean jansson chroot deps update stamp"
	rm -f stamps/45.4.$(CA).jansson-deps-update-chroot
# Hook clean target into previous target
$(call C_TO_CA_DEPS,stamps/45.3.%.jansson-build-source-clean,\
	stamps/45.4.%.jansson-deps-update-chroot)
# Cleaning this cleans up all (non-squeaky) jansson arch and indep artifacts
JANSSON_CLEAN_ARCH += stamps/45.4.%.jansson-deps-update-chroot-clean

endif # Deps on other locally-built packages


###################################################
# 45.5. Build Jansson binary packages for each distro/arch
#
#   Only build binary-indep packages once:
stamps/45.5.%.jansson-build-binary: \
	BUILDTYPE = $(if $(findstring $(ARCH),$(AN_ARCH)),-b,-B)

$(call CA_TO_C_DEPS,stamps/45.5.%.jansson-build-binary,\
	stamps/45.3.%.jansson-build-source)
$(call CA_EXPAND,stamps/45.5.%.jansson-build-binary): \
stamps/45.5.%.jansson-build-binary: \
		stamps/2.1.%.chroot-build \
		$(JANSSON_CHROOT_UPDATE_DEP)
	@echo "===== 45.5. $(CA): " \
	    "Building Jansson binary packages ====="
	$(REASON)
	$(SUDO) INTERMEDIATE_REPO=ppa \
	    $(PBUILD) --build \
	    $(PBUILD_ARGS) \
	    --debbuildopts $(BUILDTYPE) \
	    pkgs/jansson_$(JANSSON_PKG_VERSION).dsc
	touch $@
.PRECIOUS: $(call CA_EXPAND,stamps/45.5.%.jansson-build-binary)

$(call CA_EXPAND,stamps/45.5.%.jansson-build-binary-clean): \
stamps/45.5.%.jansson-build-binary-clean:
	@echo "45.5. $(CA):  Clean Jansson binary build"
	rm -f $(patsubst %,pkgs/%_$(JANSSON_PKG_VERSION)_all.deb,\
	    $(JANSSON_PKGS_ALL))
	rm -f $(patsubst %,pkgs/%_$(JANSSON_PKG_VERSION)_$(ARCH).deb,\
	    $(JANSSON_PKGS_ARCH))
	rm -f pkgs/jansson_$(JANSSON_PKG_VERSION)-$(ARCH).build
	rm -f pkgs/jansson_$(JANSSON_PKG_VERSION)_$(ARCH).changes
	rm -f stamps/45.5-$(CA)-jansson-build
$(call CA_TO_C_DEPS,stamps/45.5.%.jansson-build-binary-clean,\
	stamps/45.6.%.jansson-ppa-clean)


###################################################
# 45.6. Add Jansson packages to the PPA for each distro
$(call C_TO_CA_DEPS,stamps/45.6.%.jansson-ppa,\
	stamps/45.5.%.jansson-build-binary)
$(call C_EXPAND,stamps/45.6.%.jansson-ppa): \
stamps/45.6.%.jansson-ppa: \
		stamps/45.3.%.jansson-build-source \
		stamps/0.3.all.ppa-init
	$(call BUILD_PPA,45.6,jansson,\
	    pkgs/jansson_$(JANSSON_PKG_VERSION).dsc,\
	    $(patsubst %,pkgs/%_$(JANSSON_PKG_VERSION)_all.deb,\
		$(JANSSON_PKGS_ALL)) \
	    $(foreach a,$(call CODENAME_ARCHES,$(CODENAME)),$(wildcard\
		$(patsubst %,pkgs/%_$(JANSSON_PKG_VERSION)_$(a).deb,\
		    $(JANSSON_PKGS_ARCH)))))
# Only build for wheezy
JANSSON_INDEP := stamps/45.6.%.jansson-ppa

$(call C_EXPAND,stamps/45.6.%.jansson-ppa-clean): \
stamps/45.6.%.jansson-ppa-clean:
	@echo "45.6. $(CODENAME):  Clean Jansson PPA stamp"
	rm -f stamps/45.6.$(CODENAME).jansson-ppa


# Hook Jansson builds into final builds, if configured
FINAL_DEPS_INDEP += $(JANSSON_INDEP)
SQUEAKY_ALL += $(JANSSON_SQUEAKY_ALL)
CLEAN_INDEP += $(JANSSON_CLEAN_INDEP)
