# Sample Config.mk for overriding default build settings
#
# This configuration shows how to build separately for armhf and x86
# architectures so that arch-specific builds are only run on the
# native architecture.  This is necessary for zeromq4, which tickles a
# bug in QEMU and fails unit tests in an emulated environment.

# Use the host architecture to restrict the list of builds
HOST_ARCH = $(shell uname -m)
# ARM builds
ifeq ($(HOST_ARCH),armv7l)
ALL_CODENAMES_ARCHES = \
	wheezy-armhf
else ifeq ($(filter-out $(HOST_ARCH),x86_64),)
ALL_CODENAMES_ARCHES = \
	wheezy-amd64 \
	wheezy-i386 \
	jessie-amd64 \
	jessie-i386
endif

# A codename+arch for building arch-independent artifacts; one will be
# selected randomly if this isn't set
#BUILD_ARCH_CHROOT = wheezy-amd64

# Set the package maintainer name for updating source packages
MAINTAINER := John Doe <jdoe@example.com>

# Local directory for building
#
# The default is to build in the top make directory; set this e.g. to
# use fast, unshared local storage
#LOCAL_DIR := 

# Mount LOCAL_DIR in the chroot (default when not the same as TOPDIR)
#
# If LOCAL_DIR is under TOPDIR for some reason, this should be
# disabled by setting it to the null string
#BINDMOUNTS = $(LOCAL_DIR)

# Fine-grained directory control
#
# Shared directories:
#
# Put downloaded sources here
#DISTDIR = $(TOPDIR)/dist
# Final Debian archive
#REPODIR = $(TOPDIR)/ppa
# Misc. shared files:  keyring; rendered pbuilderrc configs
#MISCDIR = $(TOPDIR)/misc

# Local directories:
#
# Unpack source directories here
#SOURCEDIR = $(LOCAL_DIR)/src
# Cache downloaded packages here
#APTCACHE = $(LOCAL_DIR)/aptcache
# ccache directory
#CCACHEDIR = $(LOCAL_DIR)/ccache
# Put chroot tarball here
#CHROOTDIR = $(LOCAL_DIR)/chroots
# Where to unpack the chroot and build
#BUILDPLACE = $(LOCAL_DIR)/build
# Put package builds here
#BUILDRESULT = $(LOCAL_DIR)/pkgs
