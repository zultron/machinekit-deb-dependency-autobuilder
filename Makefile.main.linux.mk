###################################################
# 5. Linux kernel build rules

###################################################
# Variables that may change

# Linux vanilla tarball
LINUX_PKG_RELEASE = 1mk
LINUX_VERSION = 3.8.13
LINUX_URL = http://www.kernel.org/pub/linux/kernel/v3.0

# List of all featuresets; defined in Makefile.linux-deps.*.mk
FEATURESETS = 

# Explicitly define featureset list to enable; default all
#FEATURESETS_ENABLED = 


###################################################
# Variables that should not change much
# (or auto-generated)

# Misc paths, filenames, executables
LINUX_TARBALL := linux-$(LINUX_VERSION).tar.xz
LINUX_TARBALL_DEBIAN_ORIG := linux_$(LINUX_VERSION).orig.tar.xz
LINUX_NAME_EXT := $(shell echo $(LINUX_VERSION) | sed 's/\.[0-9]*$$//')
LINUX_PKG_VERSION = $(LINUX_VERSION)-$(LINUX_PKG_RELEASE)~$(CODENAME)1

# All featuresets enabled by default
FEATURESETS_ENABLED ?= $(FEATURESETS)
# Disabled featuresets
FEATURESETS_DISABLED = $(filter-out $(FEATURESETS_ENABLED),$(FEATURESETS))


###################################################
# 5.1. Check out git submodule
stamps/5.1.linux-kernel-package-checkout: \
		stamps/0.1.base-builddeps
	@echo "===== 5.1. All variants: "\
	    "Checking out kernel Debian git repo ====="
	$(REASON)
#	# be sure the submodule has been checked out
	git submodule update --recursive --init git/kernel-rt-deb2
	touch $@

stamps/5.1.linux-kernel-package-checkout-clean: \
		$(call CA_EXPAND,\
			stamps/5.3.%.linux-kernel-deps-update-chroot-clean)
	@echo "5.1. All:  Clean linux kernel packaging git submodule stamp"
	rm -f stamps/5.1.linux-kernel-package-checkout

stamps/5.1.linux-kernel-package-checkout-squeaky: \
		stamps/5.1.linux-kernel-package-checkout-clean
	@echo "5.1. All:  Clean linux kernel packaging git submodule"
	rm -rf git/kernel-rt-deb2; mkdir -p git/kernel-rt-deb2
LINUX_SQUEAKY_ALL += stamps/5.1.linux-kernel-package-checkout-squeaky


###################################################
# 5.2. Download linux tarball
stamps/5.2.linux-kernel-tarball-downloaded: \
		stamps/0.1.base-builddeps
	@echo "===== 5.2. All variants: " \
	    "Downloading vanilla Linux tarball ====="
	$(REASON)
	rm -f dist/$(LINUX_TARBALL)
	wget $(LINUX_URL)/$(LINUX_TARBALL) -O dist/$(LINUX_TARBALL)
	touch $@

stamps/5.2.linux-kernel-tarball-downloaded-clean: \
		$(call CA_EXPAND,\
			stamps/5.3.%.linux-kernel-deps-update-chroot-clean)
	@echo "5.2. All:  Clean up linux kernel tarball"
	rm -f dist/$(LINUX_TARBALL)
	rm -f stamps/5.2.linux-kernel-tarball-downloaded
LINUX_SQUEAKY_ALL += stamps/5.2.linux-kernel-tarball-downloaded


###################################################
# 5.3. Update chroot with dependent packages

# Any indep targets should be added to $(LINUX_KERNEL_DEPS_INDEP), and
# arch or all targets should be added to $(LINUX_KERNEL_DEPS)
$(call CA_TO_C_DEPS,stamps/5.3.%.linux-kernel-deps-update-chroot,\
	$(LINUX_KERNEL_DEPS_INDEP))
$(call CA_EXPAND,stamps/5.3.%.linux-kernel-deps-update-chroot): \
stamps/5.3.%.linux-kernel-deps-update-chroot: \
		stamps/5.1.linux-kernel-package-checkout \
		stamps/5.2.linux-kernel-tarball-downloaded \
		$(LINUX_KERNEL_DEPS)
	$(call UPDATE_CHROOT,5.3)
.PRECIOUS: $(call CA_EXPAND,stamps/5.3.%.linux-kernel-deps-update-chroot)

$(call CA_EXPAND,stamps/5.3.%.linux-kernel-deps-update-chroot-clean): \
stamps/5.3.%.linux-kernel-deps-update-chroot-clean:
	@echo "5.3. $(CA):  Clean linux kernel chroot deps update stamp"
	rm -f stamps/5.3.$(CA).linux-kernel-deps-update-chroot
$(call CA_TO_C_DEPS,stamps/5.3.%.linux-kernel-deps-update-chroot-clean,\
	stamps/5.5.%.linux-kernel-source-package-clean)

# Cleaning this cleans up all (non-squeaky) linux arch and indep artifacts
LINUX_CLEAN_ARCH := stamps/5.3.%.linux-kernel-deps-update-chroot-clean


###################################################
# 5.4. Unpack and configure Linux package source tree

# This has to be done in a chroot with the featureset packages
stamps/5.4.linux-kernel-package-configured: CODENAME = $(A_CODENAME)
stamps/5.4.linux-kernel-package-configured: ARCH = $(AN_ARCH)
stamps/5.4.linux-kernel-package-configured: \
		stamps/5.3.$(A_CHROOT).linux-kernel-deps-update-chroot
	@echo "===== 5.4. All:  Unpacking and configuring" \
	    " Linux source package ====="
	$(REASON)
#	# Starting clean, copy debian packaging and hardlink source tarball
	rm -rf src/linux/build; mkdir -p src/linux/build
	git --git-dir="git/kernel-rt-deb2/.git" archive --prefix=debian/ HEAD \
	    | tar xCf src/linux/build -
#	# Hardlink linux tarball with Debian-format path name
	ln -f dist/$(LINUX_TARBALL) \
	    pkgs/$(LINUX_TARBALL_DEBIAN_ORIG)
	ln -f dist/$(LINUX_TARBALL) \
	    src/linux/$(LINUX_TARBALL_DEBIAN_ORIG)
#	# Configure the package in a chroot
	chmod +x pbuild/linux-unpacked-chroot-script.sh
	$(SUDO) INTERMEDIATE_REPO=ppa \
	    $(PBUILD) \
		--execute --bindmounts ${TOPDIR}/src/linux \
		$(PBUILD_ARGS) \
		pbuild/linux-unpacked-chroot-script.sh \
		$(FEATURESETS_DISABLED)
#	# Make copy of changelog for later munging
	cp --preserve=all src/linux/build/debian/changelog src/linux
#	# Build the source tree and clean up
	cd src/linux/build && debian/rules orig
	cd src/linux/build && debian/rules clean
	touch $@
.PRECIOUS: stamps/5.4.linux-kernel-package-configured

stamps/5.4.linux-kernel-package-configured-clean: \
		$(call C_EXPAND,stamps/5.5.%.linux-kernel-source-package-clean)
	@echo "5.4.  All: Clean configured linux kernel source directory"
	rm -rf src/linux
	rm -f pkgs/$(LINUX_TARBALL_DEBIAN_ORIG)
	rm -f stamps/5.4.linux-kernel-package-configured
LINUX_CLEAN_ALL += stamps/5.4.linux-kernel-package-configured-clean


###################################################
# 5.5. Build Linux kernel source package for each distro
$(call C_EXPAND,stamps/5.5.%.linux-kernel-source-package): \
stamps/5.5.%.linux-kernel-source-package: \
		stamps/5.1.linux-kernel-package-checkout \
		stamps/5.4.linux-kernel-package-configured
	@echo "===== 5.5. $(CODENAME)-all: " \
	    "Building Linux source package ====="
	$(REASON)
#	# Restore original changelog
	cp --preserve=all src/linux/changelog src/linux/build/debian
#	# Add changelog entry
	cd src/linux/build && \
	    $(TOPDIR)/pbuild/tweak-pkg.sh \
	    $(CODENAME) $(LINUX_PKG_VERSION) "$(MAINTAINER)"
#	# Create source pkg
	cd src/linux/build && dpkg-source -i -I -b .
	mv src/linux/linux_$(LINUX_PKG_VERSION).debian.tar.xz \
	    src/linux/linux_$(LINUX_PKG_VERSION).dsc pkgs
	touch $@
.PRECIOUS: $(call C_EXPAND,stamps/5.5.%.linux-kernel-source-package)

$(call C_EXPAND,stamps/5.5.%.linux-kernel-source-package-clean): \
stamps/5.5.%.linux-kernel-source-package-clean:
	@echo "5.5.  $(CODENAME):  Clean linux kernel source build"
	rm -f pkgs/linux_$(LINUX_PKG_VERSION).debian.tar.xz
	rm -f pkgs/linux_$(LINUX_PKG_VERSION).dsc
	rm -f stamps/5.5.linux-kernel-source-package
$(call C_TO_CA_DEPS,stamps/5.5.%.linux-kernel-source-package-clean,\
	stamps/5.6.%.linux-kernel-build-clean)

###################################################
# 5.6. Build kernel packages for each distro/arch
#
# Use the PPA with featureset devel packages
$(call CA_TO_C_DEPS,stamps/5.6.%.linux-kernel-build,\
	stamps/5.5.%.linux-kernel-source-package)

$(call CA_EXPAND,stamps/5.6.%.linux-kernel-build): \
stamps/5.6.%.linux-kernel-build: \
		stamps/5.3.%.linux-kernel-deps-update-chroot
	@echo "===== 5.6. $(CA):  Building Linux binary package ====="
	$(REASON)
	$(SUDO) INTERMEDIATE_REPO=ppa \
	    $(PBUILD) --build \
		$(PBUILD_ARGS) \
	        pkgs/linux_$(LINUX_PKG_VERSION).dsc || \
	    (rm -f $@ && exit 1)
	touch $@
.PRECIOUS: $(call CA_EXPAND,stamps/5.6.%.linux-kernel-build)
LINUX_ARTIFACTS_ARCH += stamps/5.6.%.linux-kernel-build

$(call CA_EXPAND,stamps/5.6.%.linux-kernel-build-clean): \
stamps/5.6.%.linux-kernel-build-clean:
	@echo "5.6.  $(CA):  Clean linux kernel binary builds"
	rm -f $(wildcard pkgs/linux-headers-*_$(LINUX_PKG_VERSION)_$(ARCH).deb)
	rm -f $(wildcard pkgs/linux-image-*_$(LINUX_PKG_VERSION)_$(ARCH).deb)
	rm -f pkgs/linux_$(LINUX_PKG_VERSION)-$(ARCH).build
	rm -f pkgs/linux_$(LINUX_PKG_VERSION)_$(ARCH).changes
	rm -f stamps/5.6.$*.linux-kernel-build
$(call CA_TO_C_DEPS,stamps/5.6.%.linux-kernel-build-clean,\
	stamps/5.7.%.linux-kernel-ppa-clean)

###################################################
# 5.7. Add kernel packages to the PPA for each distro

# e.g.:
# linux-headers-3.8-1mk-common-xenomai.x86_3.8.13-1mk~wheezy1_i386.deb
# linux-headers-3.8-1mk-xenomai.x86-686-pae_3.8.13-1mk~wheezy1_i386.deb
# linux-image-3.8-1mk-xenomai.x86-686-pae_3.8.13-1mk~wheezy1_i386.deb
$(call C_TO_CA_DEPS,stamps/5.7.%.linux-kernel-ppa,\
	stamps/5.6.%.linux-kernel-build)
$(call C_EXPAND,stamps/5.7.%.linux-kernel-ppa): \
stamps/5.7.%.linux-kernel-ppa: \
		stamps/5.5.%.linux-kernel-source-package \
		stamps/0.3.all.ppa-init
	$(call BUILD_PPA,5.7,linux,\
	    pkgs/linux_$(LINUX_PKG_VERSION).dsc,\
	    $(foreach a,$(call CODENAME_ARCHES,$(CODENAME)),$(wildcard\
		pkgs/linux-headers-*_$(LINUX_PKG_VERSION)_$(a).deb \
		pkgs/linux-image-*_$(LINUX_PKG_VERSION)_$(a).deb)))

# This is the final result of the linux kernel build
LINUX_INDEP := stamps/5.7.%.linux-kernel-ppa

$(call C_EXPAND,stamps/5.7.%.linux-kernel-ppa-clean): \
stamps/5.7.%.linux-kernel-ppa-clean:
	@echo "5.7.  $(CODENAME):  Clean linux kernel PPA stamp"
	rm -f stamps/5.7.%.linux-kernel-ppa-clean


# Hook kernel build into final build
FINAL_DEPS_INDEP += $(LINUX_INDEP)
SQUEAKY_ALL += $(LINUX_SQUEAKY_ALL)
CLEAN_ARCH += $(LINUX_CLEAN_ARCH)
CLEAN_ALL += $(LINUX_CLEAN_ALL)


