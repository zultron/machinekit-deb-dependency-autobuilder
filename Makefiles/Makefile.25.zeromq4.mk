###################################################
# 25. zeromq4 build rules

###################################################
# Variables that may change

# Zeromq4 package
ZEROMQ4_PKG_RELEASE = 1mk
ZEROMQ4_VERSION = 4.0.4


###################################################
# Variables that should not change much
# (or auto-generated)

# Source name
ZEROMQ4_SOURCE_NAME := zeromq4

# Index
ZEROMQ4_INDEX := 35

# Submodule name
ZEROMQ4_SUBMODULE := git/zeromq4-deb

# Packages; will be suffixed by _<pkg_version>_<arch>.deb
ZEROMQ4_PKGS_ALL := 
ZEROMQ4_PKGS_ARCH := libzmq4 libzmq4-dev libzmq4-dbg

# Misc paths, filenames, executables
ZEROMQ4_COMPRESSION = gz
ZEROMQ4_URL = http://download.zeromq.org

# Tarball name
ZEROMQ4_TARBALL := zeromq-$(ZEROMQ4_VERSION).tar.$(ZEROMQ4_COMPRESSION)


# Dependencies on other locally-built packages
#
# Arch- and distro-dependent targets
ZEROMQ4_DEPS_ARCH = 
# Arch-independent (but distro-dependent) targets
ZEROMQ4_DEPS_INDEP = libsodium
# Targets built for all distros and arches
ZEROMQ4_DEPS = 


###################################################
# Do the standard build for this package
$(eval $(call TARGET_VARS,ZEROMQ4))
$(eval $(call STANDARD_BUILD,ZEROMQ4))
# Debugging
#$(info $(call STANDARD_BUILD,ZEROMQ4))
