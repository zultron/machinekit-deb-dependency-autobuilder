###################################################
# 16. linux-tools package build rules
#
# This is built in much the same way as the kernel

###################################################
# Variables that should not change much
# (or auto-generated)

LINUX_TOOLS_PKG_RELEASE := 1mk
LINUX_TOOLS_VERSION := $(LINUX_VERSION)

###################################################
# Variables that should not change much
# (or auto-generated)

# This package appends part of the Linux version to all binary package
# names
LINUX_TOOLS_SUBVER := \
	$(shell echo $(LINUX_TOOLS_VERSION) | sed 's/\.[0-9]*$$//')

# Source name
LINUX_TOOLS_SOURCE_NAME := linux-tools

# Index
LINUX_TOOLS_INDEX := 16

# Submodule name:
LINUX_TOOLS_SUBMODULE := git/linux-tools-deb

# Packages; will be suffixed by _<pkg_version>_<arch>.deb
LINUX_TOOLS_PKGS_ALL := 
LINUX_TOOLS_PKGS_ARCH := \
	linux-kbuild-$(LINUX_TOOLS_SUBVER) \
	linux-tools-$(LINUX_TOOLS_SUBVER)

# Misc paths, filenames, executables
LINUX_TOOLS_COMPRESSION := $(LINUX_COMPRESSION)
# This package likes to use xz compression for the Debian tarball
LINUX_TOOLS_DEBIAN_COMPRESSION := xz

# Tarball name
# This package uses the same tarball as the linux package
LINUX_TOOLS_TARBALL := $(LINUX_TARBALL)
LINUX_TOOLS_TARBALL_PACKAGE = linux

# This package likes to use xz compression for the Debian tarball
LINUX_TOOLS_DEBIAN_COMPRESSION = xz

# Dependencies on other locally-built packages
LINUX_TOOLS_PACKAGE_DEPS = linux

# The source package needs to be configured with the below command
LINUX_TOOLS_SOURCE_PACKAGE_CONFIGURE_COMMAND := \
	cd $(SOURCEDIR)/linux-tools/build && \
	    debian/rules debian/control || true # always fails

###################################################
# Do the standard build for this package
$(eval $(call TARGET_VARS,LINUX_TOOLS))
$(eval $(call DEBUG_BUILD,LINUX_TOOLS))
