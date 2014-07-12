###################################################
# 11. RTAI build rules

# FIXME:  This is broken
# It needs a tarball, but is built from git

###################################################
# Variables that may change

# List of Rtai featuresets; passed to kernel build
#
# Enable/disable Rtai builds by moving into the DISABLED list
RTAI_FEATURESETS := \
    rtai.x86

RTAI_FEATURESETS_DISABLED := \
#    rtai.x86

# Give the Linux rules a mapping of featureset -> flavors for the
# funky pkg name extensions
LINUX_FEATURESET_ARCH_MAP.rtai.x86.amd64 = amd64
LINUX_FEATURESET_ARCH_MAP.rtai.x86.i386 = 686-pae

# RTAI package
RTAI_GIT_COMMIT = 44557fc9
RTAI_PKG_RELEASE = 4.1da.git$(RTAI_GIT_COMMIT)
RTAI_VERSION = 4.0.0


###################################################
# Variables that should not change much
# (or auto-generated)

# Source name
RTAI_SOURCE_NAME := rtai

# Index
RTAI_INDEX := 11

# Submodule name
RTAI_SUBMODULE := git/rtai-deb

# Packages; will be suffixed by _<pkg_version>_<arch>.deb
RTAI_PKGS_ALL := rtai-doc python-rtai
RTAI_PKGS_ARCH := rtai librtai1 librtai-dev rtai-source 

# Misc paths, filenames, executables
RTAI_COMPRESSION = gz
RTAI_TARBALL := rtai-$(RTAI_VERSION).tar.$(RTAI_COMPRESSION)
RTAI_URL = https://github.com/ShabbyX/RTAI/archive/master.tar.gz

LINUX_RTAI_TARBALL_ORIG = linux_$(LINUX_VERSION).orig-rtai.tar.bz2

# Dependencies on other locally-built packages
#
ifneq ($(RTAI_FEATURESETS),)
# Linux package depends on Rtai
LINUX_PACKAGE_DEPS += rtai
LINUX_SOURCE_PACKAGE_DEPS += rtai-source
endif

# Pass featureset list to Linux package
LINUX_FEATURESET_PKGS += RTAI

# Set up a rule to move the RTAI source tarball from the chroot build
# into $DISTDIR, symlink it as a second Debian upstream source
# tarball, and unpack it the source directory
#
# Insert it before 15.4, build-source-package, and after 15.8,
# configure-source-package
stamps/15.8.linux.configure-source-package: \
		stamps/15.8.linux.link-rtai-source-tarball

stamps/15.8.linux.link-rtai-source-tarball: \
		stamps/15.9.linux.$(BUILD_ARCH_CHROOT).configure-source-package-chroot
	@echo "===== 15.8. All:  RTAI source tarball ====="
	! test -f \
	    $(SOURCEDIR)/linux/$(LINUX_RTAI_TARBALL_ORIG) -a \
	    ! -h $(SOURCEDIR)/linux/$(LINUX_RTAI_TARBALL_ORIG) || \
	    mv -f $(SOURCEDIR)/linux/$(LINUX_RTAI_TARBALL_ORIG) $(DISTDIR)
	ln -sf $(DISTDIR)/$(LINUX_RTAI_TARBALL_ORIG) \
	    $(SOURCEDIR)/linux/$(LINUX_RTAI_TARBALL_ORIG)
	rm -rf  $(SOURCEDIR)/linux/build/rtai
	mkdir -p $(SOURCEDIR)/linux/build/rtai
#	# If a source tarball top-level directory only contains a
#	# single subdirectory, Debian strips the top directory while
#	# unpacking and renames the subdirectory to match the source
#	# name
	tar xCf \
	    $(SOURCEDIR)/linux/build/rtai \
	    $(DISTDIR)/$(LINUX_RTAI_TARBALL_ORIG) \
	    --strip-components=1
	touch $@

# Clean target, hooked into configure-source-package-clean
stamps/15.8.linux.link-rtai-source-tarball-clean:
	rm -f $(DISTDIR)/$(LINUX_RTAI_TARBALL_ORIG)
	rm -f $(SOURCEDIR)/linux/$(LINUX_RTAI_TARBALL_ORIG)
	rm -f stamps/15.8.linux.link-rtai-source-tarball
stamps/15.8.linux.configure-source-package-clean: \
		stamps/15.8.linux.link-rtai-source-tarball-clean

###################################################
# Do the standard build for this package
$(eval $(call TARGET_VARS,RTAI))
$(eval $(call DEBUG_BUILD,RTAI))
