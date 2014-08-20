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


# Kernel package names, unlike other packages, include quite a bit of
# extra data with special meaning.  The release also includes more
# data.  An example with component breakdown:
#
# $ dpkg-query -W linux-image-\*
# linux-image-3.8-1-rtai.x86-686-pae   3.8.13-2mk~wheezy1
#
# linux-image:  package base name
# 3.8:  first two components of upstream Linux tarball
# 1:  an 'ABI name', to be bumped with incompatible ABI updates
# rtai.x86:  the featureset name
# 686-pae: the kernel 'flavour'
#
# 3.8.13:  upstream Linux tarball release
# 2mk:  the base package release
# wheezy1:  the codename the package was compiled for (enables shared pool)


###################################################
# Variables that may change

# Pkg release number; bump this for every new package
LINUX_PKG_RELEASE = 9da
# Linux vanilla tarball version
LINUX_VERSION = 3.8.13
# An ABI name; must match the `abiname` defined in config/defines
LINUX_PKG_ABI = 1


###################################################
# Variables that should not change much
# (or auto-generated)

# Source name
LINUX_SOURCE_NAME := linux

# Index
LINUX_INDEX := 15

# Submodule name:
LINUX_SUBMODULE := git/linux-ipipe-deb

# 
# This package appends part of the Linux version and an 'abi name' to
# all binary package names
LINUX_SUBVER := $(shell echo $(LINUX_VERSION) | sed 's/\.[0-9]*$$//')
LINUX_PKG_EXTENSION := $(LINUX_SUBVER)-$(LINUX_PKG_ABI)
#
# It also appends the featureset name to the linux-headers-common
# package, and that plus flavor name to linux-image and linux-headers
# packages
LINUX_FEATURESETS_ENABLED := \
	$(foreach p,$(LINUX_FEATURESET_PKGS),$($(p)_FEATURESETS))
#
# Finally, linux package names include the flavor, so a separate list
# needs to be generated for each arch
define LINUX_PKGS_ARCH_GEN
LINUX_PKGS_ARCH_$(1) := \
	$(foreach fs,$(LINUX_FEATURESETS_ENABLED),\
	    $(foreach flav,$(LINUX_FEATURESET_ARCH_MAP.$(fs).$(1)),\
		linux-image-$(LINUX_PKG_EXTENSION)-$(fs)-$(flav) \
		linux-headers-$(LINUX_PKG_EXTENSION)-$(fs)-$(flav) \
		linux-headers-$(LINUX_PKG_EXTENSION)-common-$(fs)))

endef
$(foreach a,amd64 i386 armhf,$(eval $(call LINUX_PKGS_ARCH_GEN,$(a))))

# Arch indep pkgs
LINUX_PKGS_ALL := linux-support-$(LINUX_PKG_EXTENSION)

# Misc paths, filenames, executables

# Tarball name
LINUX_COMPRESSION := xz
LINUX_TARBALL := linux-$(LINUX_VERSION).tar.$(LINUX_COMPRESSION)
LINUX_URL = http://www.kernel.org/pub/linux/kernel/v3.0/$(LINUX_TARBALL)

# This package likes to use xz compression for the Debian tarball
LINUX_DEBIAN_COMPRESSION := xz

# Dependencies on other locally-built packages
#
# These are added in the respective packages' Makefiles
#LINUX_PACKAGE_DEPS = xenomai rtai

# This package needs to be configured in a chroot and needs to know
# which featuresets are disabled and which dependency packages to
# install
LINUX_KERNEL_FEATURESETS_DISABLED := \
	$(foreach fs,$(LINUX_FEATURESET_PKGS),$($(fs)_FEATURESETS_DISABLED))
LINUX_KERNEL_FEATURESETS_DISABLED_ARG = \
	$(if $(LINUX_KERNEL_FEATURESETS_DISABLED),\
		-d "$(strip $(LINUX_KERNEL_FEATURESETS_DISABLED))",)
LINUX_SOURCE_PACKAGE_CHROOT_CONFIGURE_COMMAND := \
		pbuild/linux-unpacked-chroot-script.sh \
		    $(LINUX_KERNEL_FEATURESETS_DISABLED_ARG) \
		    -b "$(strip $(LINUX_SOURCE_PACKAGE_DEPS))" \
		    -p linux


###################################################
# Do the standard build for this package
$(eval $(call TARGET_VARS,LINUX))
$(eval $(call DEBUG_BUILD,LINUX))
