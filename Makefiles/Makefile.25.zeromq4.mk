###################################################
# 25. zeromq4 build rules

# Enable this package build
ENABLED_BUILDS += ZEROMQ4

###################################################
# Variables that may change

# Zeromq4 package
ZEROMQ4_PKG_RELEASE = 1da
ZEROMQ4_VERSION = 4.0.4


###################################################
# Variables that should not change much
# (or auto-generated)

# Source name
ZEROMQ4_SOURCE_NAME := zeromq4

# Index
ZEROMQ4_INDEX := 25

# Submodule name
ZEROMQ4_SUBMODULE := git/zeromq4-deb

# Packages; will be suffixed by _<pkg_version>_<arch>.deb
ZEROMQ4_PKGS_ALL := 
ZEROMQ4_PKGS_ARCH := libzmq4 libzmq4-dev libzmq4-dbg

# Misc paths, filenames, executables
ZEROMQ4_COMPRESSION = gz
ZEROMQ4_TARBALL := zeromq-$(ZEROMQ4_VERSION).tar.$(ZEROMQ4_COMPRESSION)
ZEROMQ4_URL = http://download.zeromq.org/$(ZEROMQ4_TARBALL)


# Dependencies on other locally-built packages
#
ZEROMQ4_PACKAGE_DEPS = libsodium
