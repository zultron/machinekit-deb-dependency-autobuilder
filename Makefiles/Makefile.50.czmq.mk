###################################################
# 50. czmq build rules
#
# Not in Debian

# Enable this package build
ENABLED_BUILDS += CZMQ

###################################################
# Variables that may change

# Czmq package versions
CZMQ_PKG_RELEASE = 0.1da
CZMQ_VERSION = 2.2.0


###################################################
# Variables that should not change much
# (or auto-generated)

# Source name
CZMQ_SOURCE_NAME := czmq

# Index
CZMQ_INDEX := 50

# Submodule name
CZMQ_SUBMODULE := git/czmq-deb

# Packages; will be suffixed by _<pkg_version>_<arch>.deb
# (may contain wildcards)
CZMQ_PKGS_ALL := 
CZMQ_PKGS_ARCH := libczmq2 libczmq-dbg libczmq-dev

# Misc paths, filenames, executables
CZMQ_COMPRESSION = gz
CZMQ_TARBALL := czmq-$(CZMQ_VERSION).tar.$(CZMQ_COMPRESSION)
CZMQ_URL = http://download.zeromq.org/$(CZMQ_TARBALL)

# Dependencies on other locally-built packages
#
CZMQ_PACKAGE_DEPS = zeromq4 libsodium
