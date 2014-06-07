###################################################
# 20. libsodium build rules

###################################################
# Variables that may change

# Libsodium package
LIBSODIUM_PKG_RELEASE = 0.1mk
LIBSODIUM_VERSION = 0.5.0


###################################################
# Variables that should not change much
# (or auto-generated)

# Source name
LIBSODIUM_SOURCE_NAME := libsodium

# Index
LIBSODIUM_INDEX := 20

# Submodule name
LIBSODIUM_SUBMODULE := git/libsodium-deb

# Packages; will be suffixed by _<pkg_version>_<arch>.deb
LIBSODIUM_PKGS_ALL := libsodium-dev
LIBSODIUM_PKGS_ARCH := libsodium

# Misc paths, filenames, executables
LIBSODIUM_URL = http://download.libsodium.org/libsodium/releases
LIBSODIUM_COMPRESSION = gz

# Tarball name
LIBSODIUM_TARBALL := libsodium-$(LIBSODIUM_VERSION).tar.$(LIBSODIUM_COMPRESSION)


###################################################
# Do the standard build for this package
$(eval $(call TARGET_VARS,LIBSODIUM))
$(eval $(call DEBUG_BUILD,LIBSODIUM))
