###################################################
# 18. linux-latest package build rules
#
# This is built in much the same way as the kernel

# Enable this package build
ENABLED_BUILDS += LINUX_LATEST

###################################################
# Variables that should not change much
# (or auto-generated)

LINUX_LATEST_PKG_RELEASE := 1da
# Upstream package prepends kernel major versions
LINUX_LATEST_VERSION := 3.8+59

###################################################
# Variables that should not change much
# (or auto-generated)

# This package appends part of the Linux version to all binary package
# names
LINUX_LATEST_SUBVER := $(LINUX_SUBVER)

# Source name
LINUX_LATEST_SOURCE_NAME := linux-latest

# Index
LINUX_LATEST_INDEX := 18

# Submodule name:
LINUX_LATEST_SUBMODULE := git/linux-latest-deb

# Packages; will be suffixed by _<pkg_version>_<arch>.deb
LINUX_LATEST_PKGS_ALL := 
define LINUX_LATEST_PKGS_ARCH_GEN
LINUX_LATEST_PKGS_ARCH_$(1) := \
	$(foreach fs,$(LINUX_FEATURESETS_ENABLED),\
	    $(foreach flav,$(LINUX_FEATURESET_ARCH_MAP.$(fs).$(1)),\
		linux-image-$(fs)-$(flav) \
		linux-headers-$(fs)-$(flav)))
endef
$(foreach a,amd64 i386 armhf,$(eval $(call LINUX_LATEST_PKGS_ARCH_GEN,$(a))))

# Misc paths, filenames, executables
LINUX_LATEST_COMPRESSION := gz
LINUX_LATEST_DEBIAN_COMPRESSION := gz

# Dependencies on other locally-built packages
LINUX_LATEST_PACKAGE_DEPS = linux
LINUX_LATEST_SOURCE_PACKAGE_DEPS = \
	linux-support-$(LINUX_SUBVER)-$(LINUX_PKG_ABI)

# The source package needs to be configured with the below command
LINUX_LATEST_SOURCE_PACKAGE_CONFIGURE_COMMAND := \
	cd $(SOURCEDIR)/linux-latest/build && \
	    debian/rules debian/control || true # always fails

LINUX_LATEST_SOURCE_PACKAGE_CHROOT_CONFIGURE_COMMAND := \
		pbuild/linux-unpacked-chroot-script.sh \
		    -b "$(strip $(LINUX_LATEST_SOURCE_PACKAGE_DEPS))" \
		    -p linux-latest
