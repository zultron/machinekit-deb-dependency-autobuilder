###################################################
# 25. zeromq4 build rules
#
# Included by Makefile.main.zeromq4.mk

###################################################
# Variables that may change

# Zeromq4 package
ZEROMQ4_PKG_RELEASE = 1mk
ZEROMQ4_VERSION = 4.0.4
ZEROMQ4_URL = http://download.zeromq.org


###################################################
# Variables that should not change much
# (or auto-generated)

# Packages; will be suffixed by _<pkg_version>_<arch>.deb
ZEROMQ4_PKGS_ALL := 
ZEROMQ4_PKGS_ARCH := libzmq4 libzmq4-dev libzmq4-dbg

# Misc paths, filenames, executables
ZEROMQ4_TARBALL := zeromq-$(ZEROMQ4_VERSION).tar.gz
ZEROMQ4_TARBALL_DEBIAN_ORIG := zeromq4_$(ZEROMQ4_VERSION).orig.tar.gz
ZEROMQ4_PKG_VERSION = $(ZEROMQ4_VERSION)-$(ZEROMQ4_PKG_RELEASE)~$(CODENAME)1


###################################################
# 25.0. Update Zeromq4 submodule
stamps/25.0.zeromq4-checkout-submodule:
	@echo "===== 25.0. All: " \
	    "Check out zeromq4 submodule ====="
#	# be sure the submodule has been checked out
	test -e git/zeromq4-deb/.git || \
	    git submodule update --init git/zeromq4-deb
	test -e git/zeromq4-deb/.git
	touch $@


###################################################
# 25.1. Download Zeromq4 tarball distribution
stamps/25.1.zeromq4-tarball-download: \
		stamps/0.1.base-builddeps
	@echo "===== 25.1. All variants:  Downloading Zeromq4 tarball ====="
	$(REASON)
	mkdir -p dist
	wget $(ZEROMQ4_URL)/$(ZEROMQ4_TARBALL) -O dist/$(ZEROMQ4_TARBALL)
	touch $@
.PRECIOUS: stamps/25.1.zeromq4-tarball-download

stamps/25.1.zeromq4-tarball-download-squeaky: \
		$(call C_EXPAND,stamps/25.3.%.zeromq4-build-source-clean)
	@echo "25.1. All:  Clean zeromq4 tarball"
	rm -f dist/$(ZEROMQ4_TARBALL)
	rm -f stamps/25.1.zeromq4-tarball-download
ZEROMQ4_SQUEAKY_ALL += stamps/25.1.zeromq4-tarball-download-squeaky


###################################################
# 25.2. Set up Zeromq4 sources
stamps/25.2.zeromq4-source-setup: \
		stamps/25.1.zeromq4-tarball-download \
		stamps/25.0.zeromq4-checkout-submodule
	@echo "===== 25.2. All: " \
	    "Setting up Zeromq4 source ====="
#	# Unpack source
	rm -rf src/zeromq4/build; mkdir -p src/zeromq4/build
	tar xC src/zeromq4/build --strip-components=1 \
	    -f dist/$(ZEROMQ4_TARBALL)
#	# Unpack debianization
	git --git-dir="git/zeromq4-deb/.git" archive --prefix=debian/ HEAD \
	    | tar xCf src/zeromq4/build -
#	# Make clean copy of changelog for later munging
	cp --preserve=all src/zeromq4/build/debian/changelog \
	    src/zeromq4
#	# Link source tarball with Debian name
	ln -f dist/$(ZEROMQ4_TARBALL) \
	    src/zeromq4/$(ZEROMQ4_TARBALL_DEBIAN_ORIG)
	ln -f dist/$(ZEROMQ4_TARBALL) \
	    pkgs/$(ZEROMQ4_TARBALL_DEBIAN_ORIG)
	touch $@

$(call C_EXPAND,stamps/25.2.%.zeromq4-source-setup-clean): \
stamps/25.2.%.zeromq4-source-setup-clean: \
		$(call C_EXPAND,stamps/25.3.%.zeromq4-build-source-clean)
	@echo "25.2. All:  Clean zeromq4 sources"
	rm -rf src/zeromq4
ZEROMQ4_CLEAN_INDEP += stamps/25.2.%.zeromq4-source-setup-clean


###################################################
# 25.3. Build Zeromq4 source package for each distro
$(call C_EXPAND,stamps/25.3.%.zeromq4-build-source): \
stamps/25.3.%.zeromq4-build-source: \
		stamps/25.2.zeromq4-source-setup
	@echo "===== 25.3. $(CODENAME)-all: " \
	    "Building Zeromq4 source package ====="
	$(REASON)
#	# Restore original changelog
	cp --preserve=all src/zeromq4/changelog \
	    src/zeromq4/build/debian
#	# Add changelog entry
	cd src/zeromq4/build && \
	    $(TOPDIR)/pbuild/tweak-pkg.sh \
	    $(CODENAME) $(ZEROMQ4_PKG_VERSION) "$(MAINTAINER)"
#	# Build source package
	cd src/zeromq4/build && dpkg-source -i -I -b .
	mv src/zeromq4/zeromq4_$(ZEROMQ4_PKG_VERSION).debian.tar.gz \
	    src/zeromq4/zeromq4_$(ZEROMQ4_PKG_VERSION).dsc pkgs
	touch $@
.PRECIOUS:  $(call C_EXPAND,stamps/25.3.%.zeromq4-build-source)

$(call C_EXPAND,stamps/25.3.%.zeromq4-build-source-clean): \
stamps/25.3.%.zeromq4-build-source-clean:
	@echo "25.3. $(CODENAME):  Clean zeromq4 source package"
	rm -f pkgs/zeromq4_$(ZEROMQ4_PKG_VERSION).dsc
	rm -f pkgs/$(ZEROMQ4_TARBALL_DEBIAN_ORIG)
	rm -f pkgs/zeromq4_$(ZEROMQ4_PKG_VERSION).debian.tar.gz
	rm -f stamps/25.3.$(CODENAME).zeromq4-build-source
$(call C_TO_CA_DEPS,stamps/25.3.%.zeromq4-build-source-clean,\
	stamps/25.4.%.zeromq4-deps-update-chroot)
ZEROMQ4_CLEAN_INDEP += stamps/25.3.%.zeromq4-build-source-clean


###################################################
# 25.4. Update chroot with dependent packages

# Any indep targets should be added to $(ZEROMQ4_DEPS_INDEP), and
# arch or all targets should be added to $(ZEROMQ4_DEPS)
$(call CA_TO_C_DEPS,stamps/25.4.%.zeromq4-deps-update-chroot,\
	$(ZEROMQ4_DEPS_INDEP))
$(call CA_EXPAND,stamps/25.4.%.zeromq4-deps-update-chroot): \
stamps/25.4.%.zeromq4-deps-update-chroot: \
		$(ZEROMQ4_DEPS)
	$(call UPDATE_CHROOT,25.4)
.PRECIOUS: $(call CA_EXPAND,stamps/25.4.%.zeromq4-deps-update-chroot)

$(call CA_EXPAND,stamps/25.4.%.zeromq4-deps-update-chroot-clean): \
stamps/25.4.%.zeromq4-deps-update-chroot-clean: \
		stamps/25.5.%.zeromq4-build-binary-clean
	@echo "25.4. $(CA):  Clean zeromq4 chroot deps update stamp"
	rm -f stamps/25.4.$(CA).zeromq4-deps-update-chroot

# Cleaning this cleans up all (non-squeaky) zeromq4 arch and indep artifacts
ZEROMQ4_CLEAN_ARCH += stamps/25.4.%.zeromq4-deps-update-chroot-clean


###################################################
# 25.5. Build Zeromq4 binary packages for each distro/arch
#
#   Only build binary-indep packages once:
stamps/25.5.%.zeromq4-build-binary: \
	BUILDTYPE = $(if $(findstring $(ARCH),$(AN_ARCH)),-b,-B)

$(call CA_TO_C_DEPS,stamps/25.5.%.zeromq4-build-binary,\
	stamps/25.3.%.zeromq4-build-source)
$(call CA_EXPAND,stamps/25.5.%.zeromq4-build-binary): \
stamps/25.5.%.zeromq4-build-binary: \
		stamps/2.1.%.chroot-build \
		stamps/25.4.%.zeromq4-deps-update-chroot
	@echo "===== 25.5. $(CA): " \
	    "Building Zeromq4 binary packages ====="
	$(REASON)
	$(SUDO) INTERMEDIATE_REPO=ppa \
	    $(PBUILD) --build \
	    $(PBUILD_ARGS) \
	    --debbuildopts $(BUILDTYPE) \
	    pkgs/zeromq4_$(ZEROMQ4_PKG_VERSION).dsc
	touch $@
.PRECIOUS: $(call CA_EXPAND,stamps/25.5.%.zeromq4-build-binary)

$(call CA_EXPAND,stamps/25.5.%.zeromq4-build-binary-clean): \
stamps/25.5.%.zeromq4-build-binary-clean:
	@echo "25.5. $(CA):  Clean Zeromq4 binary build"
	rm -f $(patsubst %,pkgs/%_$(ZEROMQ4_PKG_VERSION)_all.deb,\
	    $(ZEROMQ4_PKGS_ALL))
	rm -f $(patsubst %,pkgs/%_$(ZEROMQ4_PKG_VERSION)_$(ARCH).deb,\
	    $(ZEROMQ4_PKGS_ARCH))
	rm -f pkgs/zeromq4_$(ZEROMQ4_PKG_VERSION)-$(ARCH).build
	rm -f pkgs/zeromq4_$(ZEROMQ4_PKG_VERSION)_$(ARCH).changes
	rm -f stamps/25.5-$(CA)-zeromq4-build
$(call CA_TO_C_DEPS,stamps/25.5.%.zeromq4-build-binary-clean,\
	stamps/25.6.%.zeromq4-ppa-clean)


###################################################
# 25.6. Add Zeromq4 packages to the PPA for each distro
$(call C_TO_CA_DEPS,stamps/25.6.%.zeromq4-ppa,\
	stamps/25.5.%.zeromq4-build-binary)
$(call C_EXPAND,stamps/25.6.%.zeromq4-ppa): \
stamps/25.6.%.zeromq4-ppa: \
		stamps/25.3.%.zeromq4-build-source \
		stamps/0.3.all.ppa-init
	$(call BUILD_PPA,25.6,zeromq4,\
	    pkgs/zeromq4_$(ZEROMQ4_PKG_VERSION).dsc,\
	    $(patsubst %,pkgs/%_$(ZEROMQ4_PKG_VERSION)_all.deb,\
		$(ZEROMQ4_PKGS_ALL)) \
	    $(foreach a,$(call CODENAME_ARCHES,$(CODENAME)),\
		$(patsubst %,pkgs/%_$(ZEROMQ4_PKG_VERSION)_$(a).deb,\
		    $(ZEROMQ4_PKGS_ARCH))))

ZEROMQ4_INDEP := stamps/25.6.%.zeromq4-ppa

$(call C_EXPAND,stamps/25.6.%.zeromq4-ppa-clean): \
stamps/25.6.%.zeromq4-ppa-clean:
	@echo "25.6. $(CODENAME):  Clean Zeromq4 PPA stamp"
	rm -f stamps/25.6.$(CODENAME).zeromq4-ppa


# Hook Zeromq4 builds into final builds, if configured
FINAL_DEPS_INDEP += $(ZEROMQ4_INDEP)
SQUEAKY_ALL += $(ZEROMQ4_SQUEAKY_ALL)
CLEAN_INDEP += $(ZEROMQ4_CLEAN_INDEP)
