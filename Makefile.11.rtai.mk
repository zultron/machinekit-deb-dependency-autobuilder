###################################################
# 11. RTAI build rules


###################################################
# Variables that may change

# Add RTAI featuresets
# (disabled)
# FEATURESETS += \
#     rtai.x86

# Explicitly define featureset list to enable; default all
#FEATURESETS_ENABLED += rtai

# RTAI package
RTAI_PKG_RELEASE = 1mk
RTAI_VERSION = 4.0.0
RTAI_URL = ???


###################################################
# Variables that should not change much
# (or auto-generated)

RTAI_TARBALL := rtai-$(RTAI_VERSION).tar.bz2
RTAI_TARBALL_DEBIAN_ORIG := rtai_$(RTAI_VERSION).orig.tar.bz2
RTAI_PKG_VERSION = $(RTAI_VERSION)-$(RTAI_PKG_RELEASE)~$(CODENAME)1

# Build-dep for kernel build
RTAI_LINUX_KERNEL_SOURCE_DEPS := rtai-source


###################################################
# 11. RTAI build rules
#
# Included by Makefile.main.linux.mk

# NOTE:  this is broken:
#  -- needs updating to new format
#  -- needs issue with rtai source tarball worked out

# Add RTAI to featuresets
# FEATURESETS += \
#     rtai

ifeq (foo,)
# 11.1. clone & update the rtai submodule
stamps/11.1.rtai-source-checkout: \
		stamps/0.1.base-builddeps
	@echo "===== 11.1. All variants:  Checking out RTAI git repo ====="
	$(REASON)
	mkdir -p git/rtai
#	# be sure the submodule has been checked out
	test -f git/rtai/.git || \
           git submodule update --init -- git/rtai
	git submodule update git/rtai
	touch $@
.PRECIOUS: stamps/11.1.rtai-source-checkout

clean-rtai-source-checkout: \
		clean-rtai-source-package
	@echo "cleaning up RTAI git submodule directory"
	rm -rf git/rtai; mkdir -p git/rtai
	rm -f stamps/11.1.rtai-source-checkout
SQUEAKY_CLEAN += clean-rtai-source-checkout

# 11.2. clone & update the rtai-deb submodule
stamps/11.2.rtai-deb-source-checkout: \
		stamps/0.1.base-builddeps
	@echo "===== 11.2. All variants: " \
	    "Checking out RTAI Debian git repo ====="
	$(REASON)
	mkdir -p git/rtai-deb
#	# be sure the submodule has been checked out
	test -f git/rtai-deb/.git || \
           git submodule update --init -- git/rtai-deb
	git submodule update git/rtai-deb
	touch $@
.PRECIOUS: stamps/11.2.rtai-deb-source-checkout

clean-rtai-deb-source-checkout: \
		clean-rtai-source-package
	@echo "cleaning up RTAI Debian git submodule directory"
	rm -rf git/rtai-deb; mkdir -p git/rtai-deb
	rm -f stamps/11.2.rtai-deb-source-checkout
SQUEAKY_CLEAN += clean-rtai-deb-source-checkout

# 11.3. Build RTAI orig source tarball
stamps/11.3.rtai-source-tarball: \
		stamps/11.1.rtai-source-checkout
	@echo "===== 11.3. All variants:  Building RTAI source tarball ====="
	$(REASON)
	mkdir -p src/rtai
	rm -f src/rtai/rtai_*.orig.tar.gz
	RTAI_VER=`sed -n '1 s/rtai *(\([0-9.][0-9.]*\).*/\1/p' \
		git/rtai-deb/changelog` && \
	git --git-dir="git/rtai/.git" archive HEAD | \
	    gzip > src/rtai/rtai_$${RTAI_VER}.orig.tar.gz
	touch $@
.PRECIOUS: stamps/11.3.rtai-source-tarball

clean-rtai-source-tarball: \
		clean-rtai-source-package
	@echo "cleaning up unpacked rtai source"
	rm -f src/rtai/rtai_*.dsc
	rm -f src/rtai/rtai_*.tar.gz
	rm -f stamps/11.3.rtai-source-tarball
CLEAN_TARGETS += clean-rtai-source-tarball

# 11.4. Build RTAI source package
stamps/11.4.rtai-source-package: \
		stamps/11.2.rtai-deb-source-checkout \
		stamps/11.3.rtai-source-tarball
	@echo "===== 11.4. All variants:  Build RTAI source package ====="
	$(REASON)
	rm -rf src/rtai/build; mkdir -p src/rtai/build
	rm -f src/rtai/rtai_*.dsc
	rm -f src/rtai/rtai_*.debian.tar.gz
	tar xzCf src/rtai/build src/rtai/rtai_*.orig.tar.gz
	git --git-dir="git/rtai-deb/.git" archive --prefix=debian/ HEAD | \
	    tar xCf src/rtai/build -
	cd src/rtai && dpkg-source -i -I -b build
	touch $@
.PRECIOUS: stamps/11.4.rtai-source-package

clean-rtai-source-package: \
		$(call CA_EXPAND,%/clean-rtai-build)
	rm -rf src/rtai/build
	rm -f stamps/11.4.rtai-source-package
CLEAN_TARGETS += clean-rtai-source-tarball

# 11.5. Build the RTAI binary packages
%/.stamp.11.5.rtai-build: \
		%/.stamp.2.1.chroot-build \
		stamps/11.4.rtai-source-package
	@echo "===== 11.5. $(CA):  Building RTAI binary packages ====="
	$(REASON)
#	# ARM arch is broken
#	# jessie is broken (no libcomedi)
	test $(ARCH) = armhf -o $(CODENAME) = jessie || \
	    $(SUDO) $(PBUILD) \
		--build $(PBUILD_ARGS) \
	        src/rtai/rtai_*.dsc
	touch $@
.PRECIOUS: %/.stamp.11.5.rtai-build

%/clean-rtai-build:
	@echo "cleaning up $* rtai binary-build"
# FIXME
	# rm -f $*/pkgs/rtai_*.build
	# rm -f $*/pkgs/rtai_*.changes
	# rm -f $*/pkgs/rtai_*.dsc
	# rm -f $*/pkgs/rtai_*.tar.gz
	# rm -f $*/pkgs/rtai-doc_*.deb
	# rm -f $*/pkgs/rtai-runtime_*.deb
	# rm -f $*/pkgs/linux-patch-rtai_*.deb
	# rm -f $*/pkgs/librtai1_*.deb
	# rm -f $*/pkgs/librtai-dev_*.deb
	# rm -f $*/.stamp.3.3.rtai-build
	exit 1
ARCH_CLEAN_TARGETS += rtai-build

# Hook into rest of build
ifneq ($(filter rtai,$(FEATURESETS_ENABLED)),)
PPA_INTERMEDIATE_DEPS += %/.stamp.11.5.rtai-build
endif

endif #disable everything


###################################################
# 11.6. Wrap up

# Hook RTAI builds into kernel and final builds, if configured
ifneq ($(filter rtai.%,$(FEATURESETS)),)
LINUX_KERNEL_DEPS_INDEP += $(RTAI_INDEP)
LINUX_KERNEL_SOURCE_DEPS += $(RTAI_LINUX_KERNEL_SOURCE_DEPS)
FINAL_DEPS_INDEP += $(RTAI_INDEP)
SQUEAKY_ALL += $(RTAI_SQUEAKY_ALL)
CLEAN_INDEP += $(RTAI_CLEAN_INDEP)
endif

# Convenience target
rtai:  $(call C_EXPAND,$(RTAI_INDEP))
RTAI_TARGET_ALL := "rtai"
RTAI_DESC := "Convenience:  Build Rtai packages for all distros"
RTAI_SECTION := packages
HELP_VARS += RTAI
