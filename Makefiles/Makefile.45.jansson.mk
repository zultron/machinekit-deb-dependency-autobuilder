###################################################
# 45. jansson build rules
#
# Backported to wheezy from Debian jessie

# Enable this package build
ENABLED_BUILDS += JANSSON

###################################################
# Variables that may change

# Jansson package versions
JANSSON_PKG_RELEASE = 2~1da
JANSSON_VERSION = 2.6


###################################################
# Variables that should not change much
# (or auto-generated)

# Source name
JANSSON_SOURCE_NAME := jansson

# Index
JANSSON_INDEX := 45

# Submodule name
JANSSON_SUBMODULE := git/jansson-deb

# Packages; will be suffixed by _<pkg_version>_<arch>.deb
# (may contain wildcards)
JANSSON_PKGS_ALL := libjansson-doc
JANSSON_PKGS_ARCH := libjansson4 libjansson-dev libjansson-dbg

# Misc paths, filenames, executables
JANSSON_COMPRESSION = bz2
JANSSON_TARBALL := jansson-$(JANSSON_VERSION).tar.$(JANSSON_COMPRESSION)
JANSSON_URL = http://www.digip.org/jansson/releases/$(JANSSON_TARBALL)
