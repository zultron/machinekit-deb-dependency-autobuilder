###################################################
# 11. RTAI build rules

# FIXME:  This is broken
# It needs a tarball, but is built from git

###################################################
# Variables that may change

# List of Rtai featuresets; passed to kernel build
#
# Enable/disable Rtai builds by moving into the DISABLED list
RTAI_FEATURESETS := \
#    rtai.x86

RTAI_FEATURESETS_DISABLED := \
    rtai.x86

# RTAI package
RTAI_PKG_RELEASE = 0.1mk
RTAI_VERSION = 4.0.0


###################################################
# Variables that should not change much
# (or auto-generated)

# Source name
RTAI_SOURCE_NAME := rtai

# Index
RTAI_INDEX := 11

# Submodule name
RTAI_SUBMODULE := git/rtai-deb

# Packages; will be suffixed by _<pkg_version>_<arch>.deb
RTAI_PKGS_ALL := rtai-doc python-rtai
RTAI_PKGS_ARCH := rtai librtai1 librtai-dev rtai-source 

# Misc paths, filenames, executables
RTAI_COMPRESSION = bz2
RTAI_TARBALL := rtai-$(RTAI_VERSION).tar.$(RTAI_COMPRESSION)
RTAI_URL = ???  # FIXME

# Dependencies on other locally-built packages
#
ifneq ($(RTAI_FEATURESETS),)
# Linux package depends on Rtai
LINUX_PACKAGE_DEPS += rtai
LINUX_SOURCE_PACKAGE_DEPS += rtai-source
endif

# Pass featureset list to Linux package
LINUX_FEATURESET_PKGS += RTAI


###################################################
# Do the standard build for this package
#$(eval $(call TARGET_VARS,RTAI))
#$(eval $(call DEBUG_BUILD,RTAI))
