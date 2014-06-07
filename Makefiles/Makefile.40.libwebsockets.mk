###################################################
# 40. libwebsockets build rules

###################################################
# Variables that may change

# Libwebsockets package versions
#
# Built from a git revision
LIBWEBSOCKETS_GIT_REV = dfca3abf
# Be conservative with the pkg release, since Debian carries this package
LIBWEBSOCKETS_PKG_RELEASE = 0.1mk~git$(LIBWEBSOCKETS_GIT_REV)
LIBWEBSOCKETS_VERSION = 2.2


###################################################
# Variables that should not change much
# (or auto-generated)

# Source name
LIBWEBSOCKETS_SOURCE_NAME := libwebsockets

# Index
LIBWEBSOCKETS_INDEX := 40

# Submodule name
LIBWEBSOCKETS_SUBMODULE := git/libwebsockets-deb

# Packages; will be suffixed by _<pkg_version>_<arch>.deb
LIBWEBSOCKETS_PKGS_ALL := 
LIBWEBSOCKETS_PKGS_ARCH := libwebsockets3 libwebsockets-dev \
	libwebsockets-test-server libwebsockets3-dbg

# Misc paths, filenames, executables
LIBWEBSOCKETS_COMPRESSION = gz
LIBWEBSOCKETS_URL = http://git.libwebsockets.org/cgi-bin/cgit/libwebsockets/snapshot

# Tarball name
LIBWEBSOCKETS_TARBALL := libwebsockets-$(LIBWEBSOCKETS_GIT_REV).tar.gz


###################################################
# Do the standard build for this package
$(eval $(call TARGET_VARS,LIBWEBSOCKETS))
$(eval $(call DEBUG_BUILD,LIBWEBSOCKETS))
