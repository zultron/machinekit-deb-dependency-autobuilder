###################################################
# 10. Xeno build rules

###################################################
# Variables that may change

# List of Xenomai featuresets; passed to kernel build
#
# Enable/disable Xenomai builds by moving into the DISABLED list
XENOMAI_FEATURESETS := \
    $(if $(filter amd64 i386,$(ARCHES)),xenomai.x86) \
    $(if $(filter armhf,$(ARCHES)),xenomai.beaglebone)

XENOMAI_FEATURESETS_DISABLED := \
    # xenomai.x86 \
    # xenomai.beaglebone

# Xenomai package
XENOMAI_PKG_RELEASE = 0.1mk
XENOMAI_VERSION = 2.6.3


###################################################
# Variables that should not change much
# (or auto-generated)

# Source name
XENOMAI_SOURCE_NAME := xenomai

# Index
XENOMAI_INDEX := 10

# Submodule name:  Xenomai is built from unchanged source
#XENOMAI_SUBMODULE := git/xenomai-deb

# Packages; will be suffixed by _<pkg_version>_<arch>.deb
XENOMAI_PKGS_ALL := xenomai-kernel-source xenomai-doc
XENOMAI_PKGS_ARCH := xenomai-runtime libxenomai1 libxenomai-dev

# Misc paths, filenames, executables
XENOMAI_URL = http://download.gna.org/xenomai/stable
XENOMAI_COMPRESSION = bz2

# Tarball name
XENOMAI_TARBALL := xenomai-$(XENOMAI_VERSION).tar.$(XENOMAI_COMPRESSION)

# Dependencies on other locally-built packages
#
ifneq ($(XENOMAI_FEATURESETS),)
# Actually, the Linux *source* package depends on Xenomai
LINUX_PACKAGE_DEPS += xenomai
LINUX_SOURCE_PACKAGE_DEPS += xenomai-kernel-source
endif

# Pass featureset list to Linux package
LINUX_FEATURESET_PKGS += XENOMAI


###################################################
# Do the standard build for this package
$(eval $(call TARGET_VARS,XENOMAI))

ifeq ($(DEBUG_PACKAGE),)
ifeq ($(DEBUG_INFO),xenomai)
$(info $(call STANDARD_BUILD,XENOMAI))
endif
$(eval $(call STANDARD_BUILD,XENOMAI))

else # Debugging
ifeq ($(DEBUG_PACKAGE),xenomai)
$(info # doing debuggery:  DEBUG_STAGE = $(DEBUG_STAGE))
debuggery:
ifeq ($(DEBUG_STAGE),)
	@echo In debuggery stage 0
#	# Re-run twice:
	@echo Running debuggery stage 1, render rules into /tmp/makefile.debug
	$(MAKE) -s debuggery DEBUG_STAGE=1 > /tmp/makefile.debug
	@echo Remaking '$(TARGET)' including /tmp/makefile.debug
	$(MAKE) $(TARGET) DEBUG_STAGE=2
endif # Debuggery stage 0
ifeq ($(DEBUG_STAGE),1)
$(info # Output from debuggery of $(DEBUG_PACKAGE))
$(info $(call STANDARD_BUILD,XENOMAI))
endif # Debuggery stage 1
ifeq ($(DEBUG_STAGE),2)
$(info *** Including debuggery rules from /tmp/makefile.debug ***)
-include /tmp/makefile.debug
endif # Debuggery stage 2
endif # Debuggery in this package
endif # Debuggery
