###################################################
# 30. cython build rules
#
# Included by Makefile.main.cython.mk

###################################################
# Variables that may change

# Cython package
CYTHON_PKG_RELEASE = 1mk
CYTHON_VERSION = 0.20.1
CYTHON_URL = http://cython.org/release


###################################################
# Variables that should not change much
# (or auto-generated)

# Misc paths, filenames, executables
CYTHON_TARBALL := Cython-$(CYTHON_VERSION).tar.gz
CYTHON_TARBALL_DEBIAN_ORIG := cython_$(CYTHON_VERSION).orig.tar.gz
CYTHON_PKG_VERSION = $(CYTHON_VERSION)-$(CYTHON_PKG_RELEASE)~$(CODENAME)1


###################################################
# 30.1. Download Cython tarball distribution
stamps/30.1.cython-tarball-download: \
		stamps/0.1.base-builddeps
	@echo "===== 30.1. All variants:  Downloading Cython tarball ====="
	$(REASON)
	mkdir -p dist
	wget $(CYTHON_URL)/$(CYTHON_TARBALL) -O dist/$(CYTHON_TARBALL)
	touch $@
.PRECIOUS: stamps/30.1.cython-tarball-download

stamps/30.1.cython-tarball-download-squeaky: \
		$(call C_EXPAND,stamps/30.3.%.cython-build-source-clean)
	@echo "30.1. All:  Clean cython tarball"
	rm -f dist/$(CYTHON_TARBALL)
	rm -f stamps/30.1.cython-tarball-download
CYTHON_SQUEAKY_ALL += stamps/30.1.cython-tarball-download-squeaky


###################################################
# 30.2. Set up Cython sources
stamps/30.2.cython-source-setup: \
		stamps/30.1.cython-tarball-download
	@echo "===== 30.2. All: " \
	    "Setting up Cython source ====="
#	# Unpack source
	rm -rf src/cython/build; mkdir -p src/cython/build
	tar xC src/cython/build --strip-components=1 \
	    -f dist/$(CYTHON_TARBALL)
#	# Unpack debianization
	git --git-dir="git/cython-deb/.git" archive --prefix=debian/ HEAD \
	    | tar xCf src/cython/build -
#	# Make clean copy of changelog for later munging
	cp --preserve=all src/cython/build/debian/changelog \
	    src/cython
#	# Link source tarball with Debian name
	ln -f dist/$(CYTHON_TARBALL) \
	    src/cython/$(CYTHON_TARBALL_DEBIAN_ORIG)
	ln -f dist/$(CYTHON_TARBALL) \
	    pkgs/$(CYTHON_TARBALL_DEBIAN_ORIG)
	touch $@

$(call C_EXPAND,stamps/30.2.%.cython-source-setup-clean): \
stamps/30.2.%.cython-source-setup-clean: \
		$(call C_EXPAND,stamps/30.3.%.cython-build-source-clean)
	@echo "30.2. All:  Clean cython sources"
	rm -rf src/cython
CYTHON_CLEAN_INDEP += stamps/30.2.%.cython-source-setup-clean


###################################################
# 30.3. Build Cython source package for each distro
$(call C_EXPAND,stamps/30.3.%.cython-build-source): \
stamps/30.3.%.cython-build-source: \
		stamps/30.2.cython-source-setup
	@echo "===== 30.3. $(CODENAME)-all: " \
	    "Building Cython source package ====="
	$(REASON)
#	# Restore original changelog
	cp --preserve=all src/cython/changelog \
	    src/cython/build/debian
#	# Add changelog entry
	cd src/cython/build && \
	    $(TOPDIR)/pbuild/tweak-pkg.sh \
	    $(CODENAME) $(CYTHON_PKG_VERSION) "$(MAINTAINER)"
#	# Build source package
	cd src/cython/build && dpkg-source -i -I -b .
	mv src/cython/cython_$(CYTHON_PKG_VERSION).debian.tar.gz \
	    src/cython/cython_$(CYTHON_PKG_VERSION).dsc pkgs
	touch $@
.PRECIOUS:  $(call C_EXPAND,stamps/30.3.%.cython-build-source)

$(call C_EXPAND,stamps/30.3.%.cython-build-source-clean): \
stamps/30.3.%.cython-build-source-clean:
	@echo "30.3. $(CODENAME):  Clean cython source package"
	rm -f pkgs/cython_$(CYTHON_PKG_VERSION).dsc
	rm -f pkgs/$(CYTHON_TARBALL_DEBIAN_ORIG)
	rm -f pkgs/cython_$(CYTHON_PKG_VERSION).debian.tar.gz
	rm -f stamps/30.3.$(CODENAME).cython-build-source
$(call C_TO_CA_DEPS,stamps/30.3.%.cython-build-source-clean,\
	stamps/30.5.%.cython-build-binary-clean)
CYTHON_CLEAN_INDEP += stamps/30.3.%.cython-build-source-clean


###################################################
# 30.5. Build Cython binary packages for each distro/arch
#
#   Only build binary-indep packages once:
stamps/30.5.%.cython-build-binary: \
	BUILDTYPE = $(if $(findstring $(ARCH),$(AN_ARCH)),-b,-B)

$(call CA_TO_C_DEPS,stamps/30.5.%.cython-build-binary,\
	stamps/30.3.%.cython-build-source)
$(call CA_EXPAND,stamps/30.5.%.cython-build-binary): \
stamps/30.5.%.cython-build-binary: \
		stamps/2.1.%.chroot-build
	@echo "===== 30.5. $(CA): " \
	    "Building Cython binary packages ====="
	$(REASON)
	$(SUDO) INTERMEDIATE_REPO=ppa \
	    $(PBUILD) --build \
	    $(PBUILD_ARGS) \
	    --debbuildopts $(BUILDTYPE) \
	    pkgs/cython_$(CYTHON_PKG_VERSION).dsc
	touch $@
.PRECIOUS: $(call CA_EXPAND,stamps/30.5.%.cython-build-binary)

$(call CA_EXPAND,stamps/30.5.%.cython-build-binary-clean): \
stamps/30.5.%.cython-build-binary-clean:
	@echo "30.5. $(CA):  Clean Cython binary build"
	rm -f pkgs/cython-dev_$(CYTHON_PKG_VERSION)_all.deb
	rm -f pkgs/cython_$(CYTHON_PKG_VERSION)_$(ARCH).deb
	rm -f pkgs/cython_$(CYTHON_PKG_VERSION)-$(ARCH).build
	rm -f pkgs/cython_$(CYTHON_PKG_VERSION)_$(ARCH).changes
	rm -f stamps/30.5-$(CA)-cython-build
$(call CA_TO_C_DEPS,stamps/30.5.%.cython-build-binary-clean,\
	stamps/30.6.%.cython-ppa-clean)


###################################################
# 30.6. Add Cython packages to the PPA for each distro
$(call C_TO_CA_DEPS,stamps/30.6.%.cython-ppa,\
	stamps/30.5.%.cython-build-binary)
$(call C_EXPAND,stamps/30.6.%.cython-ppa): \
stamps/30.6.%.cython-ppa: \
		stamps/30.3.%.cython-build-source \
		stamps/0.3.all.ppa-init
	$(call BUILD_PPA,30.6,cython,\
	    pkgs/cython_$(CYTHON_PKG_VERSION).dsc,\
	    $(foreach a,$(call CODENAME_ARCHES,$(CODENAME)),$(wildcard\
		pkgs/cython-dev_$(CYTHON_PKG_VERSION)_$(a).deb \
		pkgs/cython_$(CYTHON_PKG_VERSION)_$(a).deb)))
CYTHON_INDEP := stamps/30.6.%.cython-ppa

$(call C_EXPAND,stamps/30.6.%.cython-ppa-clean): \
stamps/30.6.%.cython-ppa-clean:
	@echo "30.6. $(CODENAME):  Clean Cython PPA stamp"
	rm -f stamps/30.6.$(CODENAME).cython-ppa


# Hook Cython builds into final builds, if configured
FINAL_DEPS_INDEP += $(CYTHON_INDEP)
SQUEAKY_ALL += $(CYTHON_SQUEAKY_ALL)
CLEAN_INDEP += $(CYTHON_CLEAN_INDEP)
