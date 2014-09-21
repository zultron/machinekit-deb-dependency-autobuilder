###################################################
# 55. python-pyftpdlib build rules
#
# Not in Debian

# Enable this package build
ENABLED_BUILDS += PYTHON_PYFTPDLIB

###################################################
# Variables that may change

# python-pyftpdlib package versions
PYTHON_PYFTPDLIB_PKG_RELEASE = 3~1da
PYTHON_PYFTPDLIB_VERSION = 1.2.0


###################################################
# Variables that should not change much
# (or auto-generated)

# Source name
PYTHON_PYFTPDLIB_SOURCE_NAME := python-pyftpdlib

# Index
PYTHON_PYFTPDLIB_INDEX := 55

# Arch-indep pkg
PYTHON_PYFTPDLIB_ARCH := INDEP

# Submodule name
PYTHON_PYFTPDLIB_SUBMODULE := git/python-pyftpdlib-deb

# Packages; will be suffixed by _<pkg_version>_<arch>.deb
# (may contain wildcards)
PYTHON_PYFTPDLIB_PKGS_ALL := python-pyftpdlib
PYTHON_PYFTPDLIB_PKGS_ARCH := 

# Misc paths, filenames, executables
PYTHON_PYFTPDLIB_COMPRESSION = gz
PYTHON_PYFTPDLIB_TARBALL := pyftpdlib-$(PYTHON_PYFTPDLIB_VERSION).tar.$(PYTHON_PYFTPDLIB_COMPRESSION)
PYTHON_PYFTPDLIB_URL = \
    https://github.com/giampaolo/pyftpdlib/archive/release-$(PYTHON_PYFTPDLIB_VERSION).tar.gz

# Dependencies on other locally-built packages
#
PYTHON_PYFTPDLIB_PACKAGE_DEPS = 
