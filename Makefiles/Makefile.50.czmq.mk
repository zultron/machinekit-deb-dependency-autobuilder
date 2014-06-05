###################################################
# 50. czmq build rules
#
# Not in Debian

###################################################
# Variables that may change

# Czmq package versions
CZMQ_PKG_RELEASE = 0.1mk
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
CZMQ_URL = http://download.zeromq.org

# Tarball name
CZMQ_TARBALL := czmq-$(CZMQ_VERSION).tar.$(CZMQ_COMPRESSION)

# Dependencies on other locally-built packages
#
# Arch- and distro-dependent targets
CZMQ_DEPS_ARCH = 
# Arch-independent (but distro-dependent) targets
CZMQ_DEPS_INDEP = $(ZEROMQ4_INDEP) $(LIBSODIUM_INDEP)
# Targets built for all distros and arches
CZMQ_DEPS = 


###################################################
# Do the standard build for this package
#$$(call STANDARD_BUILD,CZMQ)
$(eval $(call TARGET_VARS,CZMQ))
$(eval $(call STANDARD_BUILD,CZMQ))
