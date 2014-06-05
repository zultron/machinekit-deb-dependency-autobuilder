###################################################
# 35. pyzmq build rules

###################################################
# Variables that may change

# Package versions
PYZMQ_PKG_RELEASE = 2~1mk
PYZMQ_VERSION = 14.3.0


###################################################
# Variables that should not change much
# (or auto-generated)

# Source name
PYZMQ_SOURCE_NAME := pyzmq

# Index
PYZMQ_INDEX := 35

# Submodule name
PYZMQ_SUBMODULE := git/pyzmq-deb

# Packages; will be suffixed by _<pkg_version>_<arch>.deb
# (may contain wildcards)
PYZMQ_PKGS_ALL := 
PYZMQ_PKGS_ARCH := python-zmq  python-zmq-dbg \
		   python3-zmq python3-zmq-dbg

# Misc paths, filenames, executables
PYZMQ_COMPRESSION = gz
PYZMQ_URL = https://github.com/zeromq/pyzmq/archive

# Tarball name
PYZMQ_TARBALL := v$(PYZMQ_VERSION).tar.$(PYZMQ_COMPRESSION)

# Dependencies on other locally-built packages
#
# Arch- and distro-dependent targets
PYZMQ_PACKAGE_DEPS = zeromq4


###################################################
# Do the standard build for this package
$(eval $(call TARGET_VARS,PYZMQ))
$(eval $(call STANDARD_BUILD,PYZMQ))
# Debugging
#$(info $(call STANDARD_BUILD,PYZMQ))
