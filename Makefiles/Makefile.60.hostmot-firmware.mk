###################################################
# 60. hostmot2-firmware build rules
#
# Not in Debian

# DISABLED
# (see end)
# ghdl is no longer in Debian, so this can't be built.

###################################################
# Variables that may change

# hostmot2-firmware package versions
HOSTMOT2_FIRMWARE_PKG_RELEASE := 0.1da
HOSTMOT2_FIRMWARE_VERSION := 0.8
# Corresponds to the v0.8 tag
HOSTMOT2_FIRMWARE_COMMIT := 8aac1861

# Optional:  set to 'INDEP' for architecture-independent packages
HOSTMOT2_FIRMWARE_ARCH := INDEP


###################################################
# Variables that should not change much
# (or auto-generated)

# Source name
HOSTMOT2_FIRMWARE_SOURCE_NAME := hostmot2-firmware

# Index
HOSTMOT2_FIRMWARE_INDEX := 60

# Git submodule location
HOSTMOT2_FIRMWARE_SUBMODULE := git/hostmot2-firmware

# Packages; will be suffixed by _<pkg_version>_<arch>.deb
# (may contain wildcards)
HOSTMOT2_FIRMWARE_PKGS_ALL := \
	hostmot2-firmware-all \
	hostmot2-firmware-3x20-1 \
	hostmot2-firmware-4i65 \
	hostmot2-firmware-4i68 \
	hostmot2-firmware-5i20 \
	hostmot2-firmware-5i22-1 \
	hostmot2-firmware-5i22-1.5 \
	hostmot2-firmware-5i23 \
	hostmot2-firmware-7i43-2 \
	hostmot2-firmware-7i43-4
HOSTMOT2_FIRMWARE_PKGS_ARCH := 

# Misc paths, filenames, executables
HOSTMOT2_FIRMWARE_COMPRESSION = gz
HOSTMOT2_FIRMWARE_URL_BASE := \
	http://git.linuxcnc.org/gitweb?p=hostmot2-firmware.git;a=snapshot
HOSTMOT2_FIRMWARE_URL = \
	$(HOSTMOT2_FIRMWARE_URL_BASE);h=$(HOSTMOT2_FIRMWARE_COMMIT);sf=tgz

# Tarball name
HOSTMOT2_FIRMWARE_TARBALL := hostmot2-firmware-$(HOSTMOT2_FIRMWARE_VERSION).tar.$(HOSTMOT2_FIRMWARE_COMPRESSION)

# This package needs to be configured
HOSTMOT2_FIRMWARE_SOURCE_PACKAGE_CONFIGURE_COMMAND = \
	cd $(SOURCEDIR)/$($(1)_SOURCE_NAME)/build && debian/gencontrol

###################################################
# Do the standard build for this package

# DISABLED:  this is broken
#$(eval $(call TARGET_VARS,HOSTMOT2_FIRMWARE))
#$(eval $(call DEBUG_BUILD,HOSTMOT2_FIRMWARE))
