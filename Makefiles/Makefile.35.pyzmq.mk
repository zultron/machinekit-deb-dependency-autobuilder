###################################################
# 35. pyzmq build rules

###################################################
# Variables that may change

# Pyzmq package versions
PYZMQ_PKG_RELEASE = 2~1mk
PYZMQ_VERSION = 14.3.0


###################################################
# Variables that should not change much
# (or auto-generated)

# Packages; will be suffixed by _<pkg_version>_<arch>.deb
# (may contain wildcards)
PYZMQ_PKGS_ALL := 
PYZMQ_PKGS_ARCH := python-zmq  python-zmq-dbg \
		   python3-zmq python3-zmq-dbg

# Misc paths, filenames, executables
PYZMQ_URL = https://github.com/zeromq/pyzmq/archive
PYZMQ_TARBALL := v$(PYZMQ_VERSION).tar.gz
PYZMQ_TARBALL_DEBIAN_ORIG := pyzmq_$(PYZMQ_VERSION).orig.tar.gz
PYZMQ_PKG_VERSION = $(PYZMQ_VERSION)-$(PYZMQ_PKG_RELEASE)~$(CODENAME)1

# Dependencies on other locally-built packages
#
# Arch- and distro-dependent targets
PYZMQ_DEPS_ARCH = 
# Arch-independent (but distro-dependent) targets
PYZMQ_DEPS_INDEP = $(ZEROMQ4_INDEP) $(CYTHON_INDEP)
# Targets built for all distros and arches
PYZMQ_DEPS = 


###################################################
# 35.0. Update Pyzmq submodule
stamps/35.0.pyzmq-checkout-submodule:
	@echo "===== 35.0. All: " \
	    "Check out pyzmq submodule ====="
#	# be sure the submodule has been checked out
	test -e git/pyzmq-deb/.git || \
	    git submodule update --init git/pyzmq-deb
	test -e git/pyzmq-deb/.git
	touch $@


###################################################
# 35.1. Download Pyzmq tarball distribution
stamps/35.1.pyzmq-tarball-download: \
		stamps/0.1.base-builddeps
	@echo "===== 35.1. All variants:  Downloading Pyzmq tarball ====="
	$(REASON)
	mkdir -p dist
	wget $(PYZMQ_URL)/$(PYZMQ_TARBALL) -O dist/$(PYZMQ_TARBALL)
	touch $@
.PRECIOUS: stamps/35.1.pyzmq-tarball-download

stamps/35.1.pyzmq-tarball-download-squeaky: \
		$(call C_EXPAND,stamps/35.3.%.pyzmq-build-source-clean)
	@echo "35.1. All:  Clean pyzmq tarball"
	rm -f dist/$(PYZMQ_TARBALL)
	rm -f stamps/35.1.pyzmq-tarball-download
PYZMQ_SQUEAKY_ALL += stamps/35.1.pyzmq-tarball-download-squeaky


###################################################
# 35.2. Set up Pyzmq sources
stamps/35.2.pyzmq-source-setup: \
		stamps/35.1.pyzmq-tarball-download \
		stamps/35.0.pyzmq-checkout-submodule
	@echo "===== 35.2. All: " \
	    "Setting up Pyzmq source ====="
#	# Unpack source
	rm -rf $(SOURCEDIR)/pyzmq/build; mkdir -p $(SOURCEDIR)/pyzmq/build
	tar xC $(SOURCEDIR)/pyzmq/build --strip-components=1 \
	    -f dist/$(PYZMQ_TARBALL)
#	# Unpack debianization
	git --git-dir="git/pyzmq-deb/.git" archive --prefix=debian/ HEAD \
	    | tar xCf $(SOURCEDIR)/pyzmq/build -
#	# Make clean copy of changelog for later munging
	cp --preserve=all $(SOURCEDIR)/pyzmq/build/debian/changelog \
	    $(SOURCEDIR)/pyzmq
#	# Link source tarball with Debian name
	ln -sf $(TOPDIR)/dist/$(PYZMQ_TARBALL) \
	    $(SOURCEDIR)/pyzmq/$(PYZMQ_TARBALL_DEBIAN_ORIG)
	cp --preserve=all dist/$(PYZMQ_TARBALL) \
	    $(BUILDRESULT)/$(PYZMQ_TARBALL_DEBIAN_ORIG)
	touch $@

$(call C_EXPAND,stamps/35.2.%.pyzmq-source-setup-clean): \
stamps/35.2.%.pyzmq-source-setup-clean: \
		$(call C_EXPAND,stamps/35.3.%.pyzmq-build-source-clean)
	@echo "35.2. All:  Clean pyzmq sources"
	rm -rf $(SOURCEDIR)/pyzmq
PYZMQ_CLEAN_INDEP += stamps/35.2.%.pyzmq-source-setup-clean


###################################################
# 35.3. Build Pyzmq source package for each distro
$(call C_EXPAND,stamps/35.3.%.pyzmq-build-source): \
stamps/35.3.%.pyzmq-build-source: \
		stamps/35.2.pyzmq-source-setup
	@echo "===== 35.3. $(CODENAME)-all: " \
	    "Building Pyzmq source package ====="
	$(REASON)
#	# Restore original changelog
	cp --preserve=all $(SOURCEDIR)/pyzmq/changelog \
	    $(SOURCEDIR)/pyzmq/build/debian
#	# Add changelog entry
	cd $(SOURCEDIR)/pyzmq/build && \
	    $(TOPDIR)/pbuild/tweak-pkg.sh \
	    $(CODENAME) $(PYZMQ_PKG_VERSION) "$(MAINTAINER)"
#	# Build source package
	cd $(SOURCEDIR)/pyzmq/build && dpkg-source -i -I -b .
	mv $(SOURCEDIR)/pyzmq/pyzmq_$(PYZMQ_PKG_VERSION).debian.tar.gz \
	    $(SOURCEDIR)/pyzmq/pyzmq_$(PYZMQ_PKG_VERSION).dsc $(BUILDRESULT)
	touch $@
.PRECIOUS:  $(call C_EXPAND,stamps/35.3.%.pyzmq-build-source)

$(call C_EXPAND,stamps/35.3.%.pyzmq-build-source-clean): \
stamps/35.3.%.pyzmq-build-source-clean:
	@echo "35.3. $(CODENAME):  Clean pyzmq source package"
	rm -f $(BUILDRESULT)/pyzmq_$(PYZMQ_PKG_VERSION).dsc
	rm -f $(BUILDRESULT)/$(PYZMQ_TARBALL_DEBIAN_ORIG)
	rm -f $(BUILDRESULT)/pyzmq_$(PYZMQ_PKG_VERSION).debian.tar.gz
	rm -f stamps/35.3.$(CODENAME).pyzmq-build-source
$(call C_TO_CA_DEPS,stamps/35.3.%.pyzmq-build-source-clean,\
	stamps/35.5.%.pyzmq-build-binary-clean)
PYZMQ_CLEAN_INDEP += stamps/35.3.%.pyzmq-build-source-clean


###################################################
# 35.4. Update chroot with locally-built dependent packages
#
# This is only built if deps are defined in the top section
ifneq ($(PYZMQ_DEPS_ARCH)$(PYZMQ_DEPS_INDEP)$(PYZMQ_DEPS),)

$(call CA_TO_C_DEPS,stamps/35.4.%.pyzmq-deps-update-chroot,\
	$(PYZMQ_DEPS_INDEP))
$(call CA_EXPAND,stamps/35.4.%.pyzmq-deps-update-chroot): \
stamps/35.4.%.pyzmq-deps-update-chroot: \
		$(PYZMQ_DEPS)
	$(call UPDATE_CHROOT,35.4)
.PRECIOUS: $(call CA_EXPAND,stamps/35.4.%.pyzmq-deps-update-chroot)

# Binary package build dependent on chroot update
PYZMQ_CHROOT_UPDATE_DEP := stamps/35.4.%.pyzmq-deps-update-chroot

$(call CA_EXPAND,stamps/35.4.%.pyzmq-deps-update-chroot-clean): \
stamps/35.4.%.pyzmq-deps-update-chroot-clean: \
		stamps/35.5.%.pyzmq-build-binary-clean
	@echo "35.4. $(CA):  Clean pyzmq chroot deps update stamp"
	rm -f stamps/35.4.$(CA).pyzmq-deps-update-chroot
# Hook clean target into previous target
$(call C_TO_CA_DEPS,stamps/35.3.%.pyzmq-build-source-clean,\
	stamps/35.4.%.pyzmq-deps-update-chroot)
# Cleaning this cleans up all (non-squeaky) pyzmq arch and indep artifacts
PYZMQ_CLEAN_ARCH += stamps/35.4.%.pyzmq-deps-update-chroot-clean

endif # Deps on other locally-built packages


###################################################
# 35.5. Build Pyzmq binary packages for each distro/arch
#
#   Only build binary-indep packages once:
stamps/35.5.%.pyzmq-build-binary: \
	BUILDTYPE = $(if $(findstring $(ARCH),$(AN_ARCH)),-b,-B)

$(call CA_TO_C_DEPS,stamps/35.5.%.pyzmq-build-binary,\
	stamps/35.3.%.pyzmq-build-source)
$(call CA_EXPAND,stamps/35.5.%.pyzmq-build-binary): \
stamps/35.5.%.pyzmq-build-binary: \
		stamps/2.1.%.chroot-build \
		$(PYZMQ_CHROOT_UPDATE_DEP)
	@echo "===== 35.5. $(CA): " \
	    "Building Pyzmq binary packages ====="
	$(REASON)
	$(SUDO) INTERMEDIATE_REPO=ppa \
	    $(PBUILD) --build \
	    $(PBUILD_ARGS) \
	    --debbuildopts $(BUILDTYPE) \
	    $(BUILDRESULT)/pyzmq_$(PYZMQ_PKG_VERSION).dsc
	touch $@
.PRECIOUS: $(call CA_EXPAND,stamps/35.5.%.pyzmq-build-binary)

$(call CA_EXPAND,stamps/35.5.%.pyzmq-build-binary-clean): \
stamps/35.5.%.pyzmq-build-binary-clean:
	@echo "35.5. $(CA):  Clean Pyzmq binary build"
	rm -f $(patsubst %,$(BUILDRESULT)/%_$(PYZMQ_PKG_VERSION)_all.deb,\
	    $(PYZMQ_PKGS_ALL))
	rm -f $(patsubst %,$(BUILDRESULT)/%_$(PYZMQ_PKG_VERSION)_$(ARCH).deb,\
	    $(PYZMQ_PKGS_ARCH))
	rm -f $(BUILDRESULT)/pyzmq_$(PYZMQ_PKG_VERSION)-$(ARCH).build
	rm -f $(BUILDRESULT)/pyzmq_$(PYZMQ_PKG_VERSION)_$(ARCH).changes
	rm -f stamps/35.5-$(CA)-pyzmq-build
$(call CA_TO_C_DEPS,stamps/35.5.%.pyzmq-build-binary-clean,\
	stamps/35.6.%.pyzmq-ppa-clean)


###################################################
# 35.6. Add Pyzmq packages to the PPA for each distro
$(call C_TO_CA_DEPS,stamps/35.6.%.pyzmq-ppa,\
	stamps/35.5.%.pyzmq-build-binary)
$(call C_EXPAND,stamps/35.6.%.pyzmq-ppa): \
stamps/35.6.%.pyzmq-ppa: \
		stamps/35.3.%.pyzmq-build-source \
		stamps/0.3.all.ppa-init
	$(call BUILD_PPA,35.6,pyzmq,\
	    $(BUILDRESULT)/pyzmq_$(PYZMQ_PKG_VERSION).dsc,\
	    $(patsubst %,$(BUILDRESULT)/%_$(PYZMQ_PKG_VERSION)_all.deb,\
		$(PYZMQ_PKGS_ALL)) \
	    $(foreach a,$(call CODENAME_ARCHES,$(CODENAME)),$(wildcard\
		$(patsubst %,$(BUILDRESULT)/%_$(PYZMQ_PKG_VERSION)_$(a).deb,\
		    $(PYZMQ_PKGS_ARCH)))))
PYZMQ_INDEP := stamps/35.6.%.pyzmq-ppa

$(call C_EXPAND,stamps/35.6.%.pyzmq-ppa-clean): \
stamps/35.6.%.pyzmq-ppa-clean:
	@echo "35.6. $(CODENAME):  Clean Pyzmq PPA stamp"
	rm -f stamps/35.6.$(CODENAME).pyzmq-ppa


###################################################
# 35.7. Wrap up

# Hook Pyzmq builds into final builds, if configured
FINAL_DEPS_INDEP += $(PYZMQ_INDEP)
SQUEAKY_ALL += $(PYZMQ_SQUEAKY_ALL)
CLEAN_INDEP += $(PYZMQ_CLEAN_INDEP)

# Convenience target
pyzmq:  $(call C_EXPAND,$(PYZMQ_INDEP))
PYZMQ_TARGET_ALL := "pyzmq"
PYZMQ_DESC := "Convenience:  Build pyzmq packages for all distros"
PYZMQ_SECTION := packages
HELP_VARS += PYZMQ
