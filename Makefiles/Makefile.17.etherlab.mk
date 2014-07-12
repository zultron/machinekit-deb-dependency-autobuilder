###################################################
# 17. etherlab package build rules

###################################################
# Variables that should not change much
# (or auto-generated)

# Built from a git revision
ETHERLAB_HG_REV = 8dd49f6f6d325857557ccc8478b354f4179f6288
http://sourceforge.net/code-snapshots/hg/e/et/etherlabmaster/code/etherlabmaster-code-8dd49f6f6d325857557ccc8478b354f4179f6288.zip
http://www.etherlab.org/download/ethercat/ethercat-1.5.2.tar.bz2

ETHERLAB_PKG_RELEASE := 1da
ETHERLAB_VERSION := $(LINUX_VERSION)

###################################################
# Variables that should not change much
# (or auto-generated)

# This package appends part of the Linux version to all binary package
# names
ETHERLAB_SUBVER := \
	$(shell echo $(ETHERLAB_VERSION) | sed 's/\.[0-9]*$$//')

# Source name
ETHERLAB_SOURCE_NAME := etherlab

# Index
ETHERLAB_INDEX := 17

# Submodule name:
ETHERLAB_SUBMODULE := git/etherlab-deb

# Packages; will be suffixed by _<pkg_version>_<arch>.deb
ETHERLAB_PKGS_ALL := 
ETHERLAB_PKGS_ARCH := \
	linux-kbuild-$(ETHERLAB_SUBVER) \
	etherlab-$(ETHERLAB_SUBVER)

# Misc paths, filenames, executables
ETHERLAB_COMPRESSION := $(LINUX_COMPRESSION)
# This package likes to use xz compression for the Debian tarball
ETHERLAB_DEBIAN_COMPRESSION := xz

# Tarball name
# This package uses the same tarball as the linux package
ETHERLAB_TARBALL := $(LINUX_TARBALL)
ETHERLAB_TARBALL_PACKAGE = linux

# This package likes to use xz compression for the Debian tarball
ETHERLAB_DEBIAN_COMPRESSION = xz

# Dependencies on other locally-built packages
ETHERLAB_PACKAGE_DEPS = linux

# The source package needs to be configured with the below command
ETHERLAB_SOURCE_PACKAGE_CONFIGURE_COMMAND := \
	cd $(SOURCEDIR)/etherlab/build && \
	    debian/rules debian/control || true # always fails

###################################################
# Do the standard build for this package
# DISABLED until this is working
#$(eval $(call TARGET_VARS,ETHERLAB))
#$(eval $(call DEBUG_BUILD,ETHERLAB))
