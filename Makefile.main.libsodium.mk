###################################################
# 20. libsodium build rules
#
# Included by Makefile.main.zeromq4.mk

###################################################
# Variables that may change

# Libsodium package
LIBSODIUM_PKG_RELEASE = 1mk
LIBSODIUM_VERSION = 0.5.0
LIBSODIUM_URL = http://download.libsodium.org/libsodium/releases


###################################################
# Variables that should not change much
# (or auto-generated)

# Misc paths, filenames, executables
LIBSODIUM_TARBALL := libsodium-$(LIBSODIUM_VERSION).tar.gz
LIBSODIUM_TARBALL_DEBIAN_ORIG := libsodium_$(LIBSODIUM_VERSION).orig.tar.gz
LIBSODIUM_PKG_VERSION = $(LIBSODIUM_VERSION)-$(LIBSODIUM_PKG_RELEASE)~$(CODENAME)1


###################################################
# 20.1. Download Libsodium tarball distribution
stamps/20.1.libsodium-tarball-download: \
		stamps/0.1.base-builddeps
	@echo "===== 20.1. All variants:  Downloading Libsodium tarball ====="
	$(REASON)
	mkdir -p dist
	wget $(LIBSODIUM_URL)/$(LIBSODIUM_TARBALL) -O dist/$(LIBSODIUM_TARBALL)
	touch $@
.PRECIOUS: stamps/20.1.libsodium-tarball-download

stamps/20.1.libsodium-tarball-download-squeaky: \
		$(call C_EXPAND,stamps/20.3.%.libsodium-build-source-clean)
	@echo "20.1. All:  Clean libsodium tarball"
	rm -f dist/$(LIBSODIUM_TARBALL)
	rm -f stamps/20.1.libsodium-tarball-download
LIBSODIUM_SQUEAKY_ALL += stamps/20.1.libsodium-tarball-download-squeaky


###################################################
# 20.2. Set up Libsodium sources
stamps/20.2.libsodium-source-setup: \
		stamps/20.1.libsodium-tarball-download
	@echo "===== 20.2. All: " \
	    "Setting up Libsodium source ====="
#	# Unpack source
	rm -rf src/libsodium/build; mkdir -p src/libsodium/build
	tar xC src/libsodium/build --strip-components=1 \
	    -f dist/$(LIBSODIUM_TARBALL)
#	# Unpack debianization
	git --git-dir="git/libsodium-deb/.git" archive --prefix=debian/ HEAD \
	    | tar xCf src/libsodium/build -
#	# Make clean copy of changelog for later munging
	cp --preserve=all src/libsodium/build/debian/changelog \
	    src/libsodium
#	# Link source tarball with Debian name
	ln -f dist/$(LIBSODIUM_TARBALL) \
	    src/libsodium/$(LIBSODIUM_TARBALL_DEBIAN_ORIG)
	ln -f dist/$(LIBSODIUM_TARBALL) \
	    pkgs/$(LIBSODIUM_TARBALL_DEBIAN_ORIG)
	touch $@

$(call C_EXPAND,stamps/20.2.%.libsodium-source-setup-clean): \
stamps/20.2.%.libsodium-source-setup-clean: \
		$(call C_EXPAND,stamps/20.3.%.libsodium-build-source-clean)
	@echo "20.2. All:  Clean libsodium sources"
	rm -rf src/libsodium
LIBSODIUM_CLEAN_INDEP += stamps/20.2.%.libsodium-source-setup-clean


###################################################
# 20.3. Build Libsodium source package for each distro
$(call C_EXPAND,stamps/20.3.%.libsodium-build-source): \
stamps/20.3.%.libsodium-build-source: \
		stamps/20.2.libsodium-source-setup
	@echo "===== 20.3. $(CODENAME)-all: " \
	    "Building Libsodium source package ====="
	$(REASON)
#	# Restore original changelog
	cp --preserve=all src/libsodium/changelog \
	    src/libsodium/build/debian
#	# Add changelog entry
	cd src/libsodium/build && \
	    $(TOPDIR)/pbuild/tweak-pkg.sh \
	    $(CODENAME) $(LIBSODIUM_PKG_VERSION) "$(MAINTAINER)"
#	# Build source package
	cd src/libsodium/build && dpkg-source -i -I -b .
	mv src/libsodium/libsodium_$(LIBSODIUM_PKG_VERSION).debian.tar.gz \
	    src/libsodium/libsodium_$(LIBSODIUM_PKG_VERSION).dsc pkgs
	touch $@
.PRECIOUS:  $(call C_EXPAND,stamps/20.3.%.libsodium-build-source)

$(call C_EXPAND,stamps/20.3.%.libsodium-build-source-clean): \
stamps/20.3.%.libsodium-build-source-clean:
	@echo "20.3. $(CODENAME):  Clean libsodium source package"
	rm -f pkgs/libsodium_$(LIBSODIUM_PKG_VERSION).dsc
	rm -f pkgs/$(LIBSODIUM_TARBALL_DEBIAN_ORIG)
	rm -f pkgs/libsodium_$(LIBSODIUM_PKG_VERSION).debian.tar.gz
	rm -f stamps/20.3.$(CODENAME).libsodium-build-source
$(call C_TO_CA_DEPS,stamps/20.3.%.libsodium-build-source-clean,\
	stamps/20.4.%.libsodium-build-binary-clean)
LIBSODIUM_CLEAN_INDEP += stamps/20.3.%.libsodium-build-source-clean


###################################################
# 20.4. Build Libsodium binary packages for each distro/arch
#
#   Only build binary-indep packages once:
stamps/20.4.%.libsodium-build-binary: \
	BUILDTYPE = $(if $(findstring $(ARCH),$(AN_ARCH)),-b,-A)

$(call CA_TO_C_DEPS,stamps/20.4.%.libsodium-build-binary,\
	stamps/20.3.%.libsodium-build-source)
$(call CA_EXPAND,stamps/20.4.%.libsodium-build-binary): \
stamps/20.4.%.libsodium-build-binary: \
		stamps/2.1.%.chroot-build
	@echo "===== 20.4. $(CA): " \
	    "Building Libsodium binary packages ====="
	$(REASON)
	$(SUDO) $(PBUILD) \
	    --build \
	    $(PBUILD_ARGS) \
	    --debbuildopts $(BUILDTYPE) \
	    pkgs/libsodium_$(LIBSODIUM_PKG_VERSION).dsc
	touch $@
.PRECIOUS: $(call CA_EXPAND,stamps/20.4.%.libsodium-build-binary)

$(call CA_EXPAND,stamps/20.4.%.libsodium-build-binary-clean): \
stamps/20.4.%.libsodium-build-binary-clean:
	@echo "20.4. $(CA):  Clean Libsodium binary build"
	rm -f pkgs/libsodium-dev_$(LIBSODIUM_PKG_VERSION)_all.deb
	rm -f pkgs/libsodium_$(LIBSODIUM_PKG_VERSION)_$(ARCH).deb
	rm -f pkgs/libsodium_$(LIBSODIUM_PKG_VERSION)-$(ARCH).build
	rm -f pkgs/libsodium_$(LIBSODIUM_PKG_VERSION)_$(ARCH).changes
	rm -f stamps/20.4-$(CA)-libsodium-build
$(call CA_TO_C_DEPS,stamps/20.4.%.libsodium-build-binary-clean,\
	stamps/20.5.%.libsodium-ppa-clean)


###################################################
# 20.5. Add Libsodium packages to the PPA for each distro
$(call C_TO_CA_DEPS,stamps/20.5.%.libsodium-ppa,\
	stamps/20.4.%.libsodium-build-binary)
$(call C_EXPAND,stamps/20.5.%.libsodium-ppa): \
stamps/20.5.%.libsodium-ppa: \
		stamps/20.3.%.libsodium-build-source \
		stamps/0.3.all.ppa-init
	$(call BUILD_PPA,20.5,libsodium,\
	    pkgs/libsodium_$(LIBSODIUM_PKG_VERSION).dsc,\
	    $(foreach a,$(call CODENAME_ARCHES,$(CODENAME)),$(wildcard\
		pkgs/libsodium-dev_$(LIBSODIUM_PKG_VERSION)_$(a).deb \
		pkgs/libsodium_$(LIBSODIUM_PKG_VERSION)_$(a).deb)))
LIBSODIUM_INDEP := stamps/20.5.%.libsodium-ppa

$(call C_EXPAND,stamps/20.5.%.libsodium-ppa-clean): \
stamps/20.5.%.libsodium-ppa-clean:
	@echo "20.5. $(CODENAME):  Clean Libsodium PPA stamp"
	rm -f stamps/20.5.$(CODENAME).libsodium-ppa


# Hook Libsodium builds into kernel and final builds, if configured
ifneq ($(filter libsodium.%,$(FEATURESETS)),)
FINAL_DEPS_INDEP += $(LIBSODIUM_INDEP)
SQUEAKY_ALL += $(LIBSODIUM_SQUEAKY_ALL)
CLEAN_INDEP += $(LIBSODIUM_CLEAN_INDEP)
endif
