###################################################
# 3.0. Xeno build rules
#
# Included by Makefile.main.linux.mk

###################################################
# Variables that may change

# Add Xenomai featuresets
FEATURESETS += \
    xenomai.x86 \
    xenomai.beaglebone

# Explicitly define Xenomai featureset list to enable; default all
#FEATURESETS_ENABLED += xenomai.beaglebone xenomai.x86

# Xenomai package
XENOMAI_PKG_RELEASE = 1mk
XENOMAI_VERSION = 2.6.3
XENOMAI_URL = http://download.gna.org/xenomai/stable

###################################################
# Variables that should not change much
# (or auto-generated)

# Misc paths, filenames, executables
XENOMAI_TARBALL := xenomai-$(XENOMAI_VERSION).tar.bz2
XENOMAI_TARBALL_DEBIAN_ORIG := xenomai_$(XENOMAI_VERSION).orig.tar.bz2
XENOMAI_PKG_VERSION = $(XENOMAI_VERSION)-$(XENOMAI_PKG_RELEASE)~$(CODENAME)1


###################################################
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


###################################################
# 3.0.1.1. Set up Xenomai sources
stamps/3.0.1.1.xenomai-source-setup: \
		stamps/3.0.1.xenomai-tarball-download
	@echo "===== 3.0.1.1. All: " \
	    "Setting up Xenomai source ====="
#	# Unpack source
	rm -rf src/xenomai/build; mkdir -p src/xenomai/build
	tar xC src/xenomai/build --strip-components=1 \
	    -f dist/$(XENOMAI_TARBALL)
#	# Make clean copy of changelog for later munging
	cp --preserve=all src/xenomai/build/debian/changelog \
	    src/xenomai
#	# Link source tarball with Debian name
	ln -f dist/$(XENOMAI_TARBALL) \
	    src/xenomai/$(XENOMAI_TARBALL_DEBIAN_ORIG)
	ln -f dist/$(XENOMAI_TARBALL) \
	    pkgs/$(XENOMAI_TARBALL_DEBIAN_ORIG)
	touch $@

$(call C_EXPAND,stamps/3.0.1.1.%.xenomai-source-setup-clean): \
stamps/3.0.1.1.%.xenomai-source-setup-clean: \
		$(call C_EXPAND,stamps/3.0.2.%.xenomai-build-source-clean)
	@echo "3.0.1.1. All:  Clean xenomai sources"
	rm -rf src/xenomai
XENOMAI_CLEAN_INDEP += stamps/3.0.1.1.%.xenomai-source-setup-clean


###################################################
# 3.0.2. Build Xenomai source package for each distro
$(call C_EXPAND,stamps/3.0.2.%.xenomai-build-source): \
stamps/3.0.2.%.xenomai-build-source: \
		stamps/3.0.1.1.xenomai-source-setup
	@echo "===== 3.0.2. $(CODENAME)-all: " \
	    "Building Xenomai source package ====="
	$(REASON)
#	# Restore original changelog
	cp --preserve=all src/xenomai/changelog \
	    src/xenomai/build/debian
#	# Add changelog entry
	cd src/xenomai/build && \
	    $(TOPDIR)/pbuild/tweak-pkg.sh \
	    $(CODENAME) $(XENOMAI_PKG_VERSION) "$(MAINTAINER)"
#	# Build source package
	cd src/xenomai/build && dpkg-source -i -I -b .
	mv src/xenomai/xenomai_$(XENOMAI_PKG_VERSION).debian.tar.gz \
	    src/xenomai/xenomai_$(XENOMAI_PKG_VERSION).dsc pkgs
	touch $@
.PRECIOUS:  $(call C_EXPAND,stamps/3.0.2.%.xenomai-build-source)

$(call C_EXPAND,stamps/3.0.2.%.xenomai-build-source-clean): \
stamps/3.0.2.%.xenomai-build-source-clean:
	@echo "3.0.2. $(CODENAME):  Clean xenomai source package"
	rm -f pkgs/xenomai_$(XENOMAI_PKG_VERSION).dsc
	rm -f pkgs/$(XENOMAI_TARBALL_DEBIAN_ORIG)
	rm -f pkgs/xenomai_$(XENOMAI_PKG_VERSION).debian.tar.gz
	rm -f stamps/3.0.2.$(CODENAME).xenomai-build-source
$(call C_TO_CA_DEPS,stamps/3.0.2.%.xenomai-build-source-clean,\
	stamps/3.0.3.%.xenomai-build-binary-clean)
XENOMAI_CLEAN_INDEP += stamps/3.0.2.%.xenomai-build-source-clean


###################################################
# 3.0.3. Build Xenomai binary packages for each distro/arch
#
#   Only build binary-indep packages once:
stamps/3.0.3.%.xenomai-build-binary: \
	BUILDTYPE = $(if $(findstring $(ARCH),$(AN_ARCH)),-b,-B)

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
	rm -f pkgs/xenomai_$(XENOMAI_PKG_VERSION)_all.changes
	rm -f pkgs/xenomai_$(XENOMAI_PKG_VERSION)_$(ARCH).changes
	rm -f stamps/3.0.3-$(CA)-xenomai-build
$(call CA_TO_C_DEPS,stamps/3.0.3.%.xenomai-build-binary-clean,\
	stamps/3.0.4.%.xenomai-ppa-clean)


###################################################
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


