###################################################
# 10. Xeno build rules

###################################################
# Variables that may change

# List of Xenomai featuresets; passed to kernel build
#
# Enable/disable Xenomai builds by moving into the DISABLED list
XENOMAI_FEATURESETS := \
    $(if $(filter amd64 i386,$(ARCHES)),xenomai.x86) \
    $(if $(filter armhf,$(ARCHES)),xenomai.beaglebone)

XENOMAI_FEATURESETS_DISABLED := \
    # xenomai.x86 \
    # xenomai.beaglebone

# Give the Linux rules a mapping of featureset -> flavors for the
# funky pkg name extensions
LINUX_FEATURESET_ARCH_MAP.xenomai.x86.amd64 = amd64
LINUX_FEATURESET_ARCH_MAP.xenomai.x86.i386 = 686-pae
LINUX_FEATURESET_ARCH_MAP.xenomai.beaglebone.armhf = omap

# Xenomai package
XENOMAI_PKG_RELEASE = 0.1da
XENOMAI_VERSION = 2.6.3


###################################################
# Variables that should not change much
# (or auto-generated)

# Source name
XENOMAI_SOURCE_NAME := xenomai

# Index
XENOMAI_INDEX := 10

# Submodule name:  Xenomai is built from unchanged source
#XENOMAI_SUBMODULE := git/xenomai-deb

# Packages; will be suffixed by _<pkg_version>_<arch>.deb
XENOMAI_PKGS_ALL := xenomai-kernel-source xenomai-doc
XENOMAI_PKGS_ARCH := xenomai-runtime libxenomai1 libxenomai-dev

# Misc paths, filenames, executables
XENOMAI_COMPRESSION = bz2
XENOMAI_TARBALL := xenomai-$(XENOMAI_VERSION).tar.$(XENOMAI_COMPRESSION)
XENOMAI_URL = http://download.gna.org/xenomai/stable/$(XENOMAI_TARBALL)

# Dependencies on other locally-built packages
#
ifneq ($(XENOMAI_FEATURESETS),)
# Actually, the Linux *source* package depends on Xenomai
LINUX_PACKAGE_DEPS += xenomai
LINUX_SOURCE_PACKAGE_DEPS += xenomai-kernel-source
endif

# Pass featureset list to Linux package
LINUX_FEATURESET_PKGS += XENOMAI


###################################################
# Do the standard build for this package
$(eval $(call TARGET_VARS,XENOMAI))
$(eval $(call DEBUG_BUILD,XENOMAI))
