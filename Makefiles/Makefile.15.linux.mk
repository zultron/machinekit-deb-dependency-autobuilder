###################################################
# 15. Linux kernel build rules

# This kernel can build featuresets for Xenomai and RTAI.  To hook
# dependencies into this build, add to these variables in the
# dependency's Makefile:
#
# LINUX_KERNEL_FEATURESETS :		Add names of enabled featuresets
# LINUX_KERNEL_FEATURESETS_DISABLED :	Add names of featuresets to disable
# LINUX_KERNEL_SOURCE_DEPS :		Add names of packages needed in the
#					chroot to configure the kernel
#					source package
# LINUX_KERNEL_DEPS_INDEP :		Distro target dependencies
# LINUX_KERNEL_DEPS :			Distro-arch or common target
#					dependencies

###################################################
# Variables that may change

# Linux vanilla tarball
LINUX_PKG_RELEASE = 1mk
LINUX_VERSION = 3.8.13


###################################################
# Variables that should not change much
# (or auto-generated)

# This package appends part of the Linux version and an 'abi name' to
# all binary package names
LINUX_SUBVER := $(shell echo $(LINUX_VERSION) | sed 's/\.[0-9]*$$//')
LINUX_PKG_EXTENSION := $(LINUX_SUBVER)-$(LINUX_PKG_RELEASE)
#
# It also appends the featureset name to the linux-headers-common
# package, and that plus flavor name to linux-image and linux-headers
# packages
ARCH_FLAVOR_MAP_x86 = amd64 686-pae
ARCH_FLAVOR_MAP_armhf = omap
LINUX_FEATURESETS_ENABLED := \
	$(foreach p,$(LINUX_FEATURESET_PKGS),$($(p)_FEATURESETS))
LINUX_PKG_COMMON_EXTENSIONS := $(LINUX_FEATURESETS_ENABLED)
LINUX_PKG_ARCH_EXTENSIONS := \
	$(foreach e,$(LINUX_PKG_COMMON_EXTENSIONS),\
	    $(patsubst %,$(e)-%,$(foreach a,$(ARCHES),$(ARCH_FLAVOR_MAP_$(a)))))
$(info LINUX_PKG_ARCH_EXTENSIONS = $(LINUX_PKG_ARCH_EXTENSIONS))

# Source name
LINUX_SOURCE_NAME := linux

# Index
LINUX_INDEX := 15

# Submodule name:
LINUX_SUBMODULE := git/kernel-rt-deb

# Packages; will be suffixed by _<pkg_version>_<arch>.deb
LINUX_PKGS_ALL := 
LINUX_PKGS_ARCH := \
	$(foreach e,$(LINUX_PKG_ARCH_EXTENSIONS),\
	    linux-image-$(LINUX_PKG_EXTENSION)-$(e) \
	    linux-headers-$(LINUX_PKG_EXTENSION)-$(e)) \
	$(foreach e,$(LINUX_PKG_COMMON_EXTENSIONS),\
	    linux-headers-$(LINUX_PKG_EXTENSION)-common-$(e))

# Misc paths, filenames, executables
LINUX_URL = http://www.kernel.org/pub/linux/kernel/v3.0
LINUX_COMPRESSION = xz
# This one package likes to use xz compression for the Debian tarball
LINUX_DEBIAN_COMPRESSION = xz

# Tarball name
LINUX_TARBALL := linux-$(LINUX_VERSION).tar.$(LINUX_COMPRESSION)

# Dependencies on other locally-built packages
#
# These are added in the respective packages' Makefiles
#LINUX_PACKAGE_DEPS = xenomai rtai

# This package needs to be configured in a chroot and needs to know
# which featuresets are disabled and which dependency packages to
# install
LINUX_KERNEL_FEATURESETS_DISABLED := \
	$(foreach fs,$(LINUX_FEATURESET_PKGS),$($(fs)_FEATURESETS_DISABLED))
LINUX_CHROOT_COMMAND := \
		pbuild/linux-unpacked-chroot-script.sh \
		    -d "$(LINUX_KERNEL_FEATURESETS_DISABLED)" \
		    -b "$(LINUX_SOURCE_PACKAGE_DEPS)"


###################################################
# Do the standard build for this package
$(eval $(call TARGET_VARS,LINUX))
$(eval $(call STANDARD_BUILD,LINUX))
# Debugging
#$(info $(call STANDARD_BUILD,LINUX))
