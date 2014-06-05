###################################################
# 10. Xeno build rules

###################################################
# Variables that may change

# List of Xenomai featuresets; passed to kernel build
#
# Xenomai builds by moving into the DISABLED list
XENOMAI_FEATURESETS := \
    xenomai.x86 \
    xenomai.beaglebone

XENOMAI_FEATURESETS_DISABLED := \
    # xenomai.x86 \
    # xenomai.beaglebone

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

# Build-dep for kernel build
XENOMAI_LINUX_KERNEL_SOURCE_DEPS := xenomai-kernel-source

###################################################
# 10.1. Download Xenomai tarball distribution
stamps/10.1.xenomai-tarball-download: \
		stamps/0.1.base-builddeps
	@echo "===== 10.1. All variants:  Downloading Xenomai tarball ====="
	$(REASON)
	mkdir -p dist
	wget $(XENOMAI_URL)/$(XENOMAI_TARBALL) -O dist/$(XENOMAI_TARBALL)
	touch $@
.PRECIOUS: stamps/10.1.xenomai-tarball-download

stamps/10.1.xenomai-tarball-download-squeaky: \
		$(call C_EXPAND,stamps/10.2.%.xenomai-build-source-clean)
	@echo "10.1. All:  Clean xenomai tarball"
	rm -f dist/$(XENOMAI_TARBALL)
	rm -f stamps/10.1.xenomai-tarball-download
XENOMAI_SQUEAKY_ALL += stamps/10.1.xenomai-tarball-download-squeaky


###################################################
# 10.1.1. Set up Xenomai sources
stamps/10.1.1.xenomai-source-setup: \
		stamps/10.1.xenomai-tarball-download
	@echo "===== 10.1.1. All: " \
	    "Setting up Xenomai source ====="
#	# Unpack source
	rm -rf $(SOURCEDIR)/xenomai/build; mkdir -p $(SOURCEDIR)/xenomai/build
	tar xC $(SOURCEDIR)/xenomai/build --strip-components=1 \
	    -f dist/$(XENOMAI_TARBALL)
#	# Make clean copy of changelog for later munging
	cp --preserve=all $(SOURCEDIR)/xenomai/build/debian/changelog \
	    $(SOURCEDIR)/xenomai
#	# Link source tarball with Debian name
	ln -sf $(TOPDIR)/dist/$(XENOMAI_TARBALL) \
	    $(SOURCEDIR)/xenomai/$(XENOMAI_TARBALL_DEBIAN_ORIG)
	cp --preserve=all dist/$(XENOMAI_TARBALL) \
	    $(BUILDRESULT)/$(XENOMAI_TARBALL_DEBIAN_ORIG)
	touch $@

$(call C_EXPAND,stamps/10.1.1.%.xenomai-source-setup-clean): \
stamps/10.1.1.%.xenomai-source-setup-clean: \
		$(call C_EXPAND,stamps/10.2.%.xenomai-build-source-clean)
	@echo "10.1.1. All:  Clean xenomai sources"
	rm -rf $(SOURCEDIR)/xenomai
XENOMAI_CLEAN_INDEP += stamps/10.1.1.%.xenomai-source-setup-clean


###################################################
# 10.2. Build Xenomai source package for each distro
$(call C_EXPAND,stamps/10.2.%.xenomai-build-source): \
stamps/10.2.%.xenomai-build-source: \
		stamps/10.1.1.xenomai-source-setup
	@echo "===== 10.2. $(CODENAME)-all: " \
	    "Building Xenomai source package ====="
	$(REASON)
#	# Restore original changelog
	cp --preserve=all $(SOURCEDIR)/xenomai/changelog \
	    $(SOURCEDIR)/xenomai/build/debian
#	# Add changelog entry
	cd $(SOURCEDIR)/xenomai/build && \
	    $(TOPDIR)/pbuild/tweak-pkg.sh \
	    $(CODENAME) $(XENOMAI_PKG_VERSION) "$(MAINTAINER)"
#	# Build source package
	cd $(SOURCEDIR)/xenomai/build && dpkg-source -i -I -b .
	mv $(SOURCEDIR)/xenomai/xenomai_$(XENOMAI_PKG_VERSION).debian.tar.gz \
	    $(SOURCEDIR)/xenomai/xenomai_$(XENOMAI_PKG_VERSION).dsc $(BUILDRESULT)
	touch $@
.PRECIOUS:  $(call C_EXPAND,stamps/10.2.%.xenomai-build-source)

$(call C_EXPAND,stamps/10.2.%.xenomai-build-source-clean): \
stamps/10.2.%.xenomai-build-source-clean:
	@echo "10.2. $(CODENAME):  Clean xenomai source package"
	rm -f $(BUILDRESULT)/xenomai_$(XENOMAI_PKG_VERSION).dsc
	rm -f $(BUILDRESULT)/$(XENOMAI_TARBALL_DEBIAN_ORIG)
	rm -f $(BUILDRESULT)/xenomai_$(XENOMAI_PKG_VERSION).debian.tar.gz
	rm -f stamps/10.2.$(CODENAME).xenomai-build-source
$(call C_TO_CA_DEPS,stamps/10.2.%.xenomai-build-source-clean,\
	stamps/10.3.%.xenomai-build-binary-clean)
XENOMAI_CLEAN_INDEP += stamps/10.2.%.xenomai-build-source-clean


###################################################
# 10.3. Build Xenomai binary packages for each distro/arch
#
#   Only build binary-indep packages once:
stamps/10.3.%.xenomai-build-binary: \
	BUILDTYPE = $(if $(findstring $(ARCH),$(AN_ARCH)),-b,-B)

$(call CA_TO_C_DEPS,stamps/10.3.%.xenomai-build-binary,\
	stamps/10.2.%.xenomai-build-source)
$(call CA_EXPAND,stamps/10.3.%.xenomai-build-binary): \
stamps/10.3.%.xenomai-build-binary: \
		stamps/2.1.%.chroot-build
	@echo "===== 10.3. $(CA): " \
	    "Building Xenomai binary packages ====="
	$(REASON)
	$(SUDO) $(PBUILD) \
	    --build  \
	    $(PBUILD_ARGS) \
	    --debbuildopts $(BUILDTYPE) \
	    $(BUILDRESULT)/xenomai_$(XENOMAI_PKG_VERSION).dsc
	touch $@
.PRECIOUS: $(call CA_EXPAND,stamps/10.3.%.xenomai-build-binary)

$(call CA_EXPAND,stamps/10.3.%.xenomai-build-binary-clean): \
stamps/10.3.%.xenomai-build-binary-clean:
	@echo "10.3. $(CA):  Clean Xenomai binary build"
	rm -f $(BUILDRESULT)/libxenomai-dev_$(XENOMAI_PKG_VERSION)_$(ARCH).deb
	rm -f $(BUILDRESULT)/libxenomai1_$(XENOMAI_PKG_VERSION)_$(ARCH).deb
	rm -f $(BUILDRESULT)/xenomai-runtime_$(XENOMAI_PKG_VERSION)_$(ARCH).deb
	rm -f $(BUILDRESULT)/xenomai-doc_$(XENOMAI_PKG_VERSION)_all.deb
	rm -f $(BUILDRESULT)/xenomai-kernel-source_$(XENOMAI_PKG_VERSION)_all.deb
	rm -f $(BUILDRESULT)/xenomai_$(XENOMAI_PKG_VERSION)-$(ARCH).build
	rm -f $(BUILDRESULT)/xenomai_$(XENOMAI_PKG_VERSION)_all.changes
	rm -f $(BUILDRESULT)/xenomai_$(XENOMAI_PKG_VERSION)_$(ARCH).changes
	rm -f stamps/10.3-$(CA)-xenomai-build
$(call CA_TO_C_DEPS,stamps/10.3.%.xenomai-build-binary-clean,\
	stamps/10.4.%.xenomai-ppa-clean)


###################################################
# 10.4. Add Xenomai packages to the PPA for each distro
$(call C_TO_CA_DEPS,stamps/10.4.%.xenomai-ppa,\
	stamps/10.3.%.xenomai-build-binary)
$(call C_EXPAND,stamps/10.4.%.xenomai-ppa): \
stamps/10.4.%.xenomai-ppa: \
		stamps/10.2.%.xenomai-build-source \
		stamps/0.3.all.ppa-init
	$(call BUILD_PPA,10.4,xenomai,\
	    $(BUILDRESULT)/xenomai_$(XENOMAI_PKG_VERSION).dsc,\
	    $(BUILDRESULT)/xenomai-doc_$(XENOMAI_PKG_VERSION)_all.deb \
	    $(BUILDRESULT)/xenomai-kernel-source_$(XENOMAI_PKG_VERSION)_all.deb \
	    $(foreach a,$(call CODENAME_ARCHES,$(CODENAME)),$(wildcard\
		$(BUILDRESULT)/libxenomai-dev_$(XENOMAI_PKG_VERSION)_$(a).deb \
		$(BUILDRESULT)/libxenomai1_$(XENOMAI_PKG_VERSION)_$(a).deb \
		$(BUILDRESULT)/xenomai-runtime_$(XENOMAI_PKG_VERSION)_$(a).deb)))
XENOMAI_INDEP := stamps/10.4.%.xenomai-ppa

$(call C_EXPAND,stamps/10.4.%.xenomai-ppa-clean): \
stamps/10.4.%.xenomai-ppa-clean:
	@echo "10.4. $(CODENAME):  Clean Xenomai PPA stamp"
	rm -f stamps/10.4.$(CODENAME).xenomai-ppa


###################################################
# 10.5. Wrap up

XENOMAI_TARGET_ALL := "xenomai"
XENOMAI_DESC := "Convenience:  Build Xenomai packages for all distros"
XENOMAI_SECTION := packages
HELP_VARS += XENOMAI

# Hook Xenomai builds into kernel and final builds, if configured
ifneq ($(XENOMAI_FEATURESETS),)
# Pass information to Linux kernel build
#
# lists of enabled/disabled featuresets
LINUX_KERNEL_FEATURESETS += $(XENOMAI_FEATURESETS)
LINUX_KERNEL_FEATURESETS_DISABLED += $(XENOMAI_FEATURESETS_DISABLED)
# list of kernel source package dependencies
LINUX_KERNEL_SOURCE_DEPS += $(XENOMAI_LINUX_KERNEL_SOURCE_DEPS)
# list of make target deps
LINUX_KERNEL_DEPS_INDEP += $(XENOMAI_INDEP)

# Pass lists of make targets to common build
FINAL_DEPS_INDEP += $(XENOMAI_INDEP)
SQUEAKY_ALL += $(XENOMAI_SQUEAKY_ALL)
CLEAN_INDEP += $(XENOMAI_CLEAN_INDEP)

# Convenience target
xenomai:  $(call C_EXPAND,$(XENOMAI_INDEP))

else # xenomai featureset disabled
XENOMAI_DESC := "*** Xenomai featureset is disabled ***"
endif