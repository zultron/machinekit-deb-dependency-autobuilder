###################################################
# 21. linux-tools package build rules
#
# This is built in much the same way as the kernel

###################################################
# Variables that should not change much
# (or auto-generated)

# Misc paths, filenames, executables
LINUX_TOOLS_TARBALL_DEBIAN_ORIG := linux-tools_$(LINUX_VERSION).orig.tar.xz
LINUX_TOOLS_NAME_EXT := $(shell echo $(LINUX_VERSION) | sed 's/\.[0-9]*$$//')
LINUX_TOOLS_PKG_NAME := linux-tools-$(LINUX_TOOLS_NAME_EXT)
LINUX_KBUILD_PKG_NAME := linux-kbuild-$(LINUX_TOOLS_NAME_EXT)


###################################################
# 21.1.  Update linux-tools git submodule
stamps/21.1.linux-tools-package-checkout: \
		stamps/0.1.base-builddeps
	@echo "===== 21.1. All variants: " \
	    "Checking out linux-tools-deb git repo ====="
	$(REASON)
#	# be sure the submodule has been checked out
	git submodule update --recursive --init git/linux-tools-deb
	touch $@

stamps/21.1.linux-tools-package-checkout-clean: \
		stamps/21.2.linux-tools-unpacked-clean
	@echo "21.2.  All:  Remove linux-tools git submodule stamp"
	rm -f stamps/21.1.linux-tools-package-checkout

stamps/21.1.linux-tools-package-checkout-squeaky: \
		stamps/21.1.linux-tools-package-checkout-clean
	@echo "21.2.  All:  Cleaning up linux-tools git submodule"
	rm -rf git/linux-tools-deb; mkdir -p git/linux-tools-deb
LINUX_TOOLS_SQUEAKY_ALL += stamps/21.1.linux-tools-package-checkout-squeaky


###################################################
# 21.2. Prepare linux-tools tarball and prepare source tree
stamps/21.2.linux-tools-unpacked: \
		stamps/0.1.base-builddeps \
		$(LINUX_TARBALL_TARGET) \
		stamps/21.1.linux-tools-package-checkout
	@echo "===== 21.2. All variants: " \
	    "Unpacking linux-tools source directory ====="
	$(REASON)
	rm -rf src/linux-tools
	mkdir -p src/linux-tools/build
	git --git-dir="git/linux-tools-deb/.git" archive --prefix=debian/ HEAD \
	    | tar xCf src/linux-tools/build -
	cd src/linux-tools/build && debian/bin/genorig.py \
	    ../../../dist/$(LINUX_TARBALL)
	cd src/linux-tools/build && debian/rules debian/control \
	    || true # always fails
#	# Make copy of changelog for later munging
	cp --preserve=all src/linux-tools/build/debian/changelog \
	    src/linux-tools
#	# Build the source tree and clean up
	cd src/linux-tools/build && debian/rules orig
	cd src/linux-tools/build && debian/rules clean
#	# Hardlink linux-tools tarball with Debian-format path name
	ln -f src/linux-tools/orig/$(LINUX_TOOLS_TARBALL_DEBIAN_ORIG) \
	    pkgs/$(LINUX_TOOLS_TARBALL_DEBIAN_ORIG)
	touch $@

stamps/21.2.linux-tools-unpacked-clean: \
		$(call C_EXPAND,stamps/21.3.%.linux-tools-source-package-clean)
	@echo "21.2.  All:  Cleaning up linux-tools unpacked sources"
	rm -rf src/linux-tools
	rm -f pkgs/linux-tools_$(LINUX_VERSION).orig.tar.xz
	rm -f stamps/21.2.linux-tools-unpacked
LINUX_TOOLS_CLEAN_ALL += stamps/21.2.linux-tools-unpacked-clean

###################################################
# 21.3. Build linux-tools source package for each distro

$(call C_EXPAND,stamps/21.3.%.linux-tools-source-package): \
stamps/21.3.%.linux-tools-source-package: \
		stamps/21.2.linux-tools-unpacked
	@echo "===== 21.3. $(CODENAME)-all: " \
	    "Building linux-tools source package ====="
	$(REASON)
#	# Restore original changelog
	cp --preserve=all src/linux-tools/changelog \
	    src/linux-tools/build/debian
#	# Add changelog entry
	cd src/linux-tools/build && \
	    $(TOPDIR)/pbuild/tweak-pkg.sh \
	    $(CODENAME) $(LINUX_PKG_VERSION) "$(MAINTAINER)"
#	# create source pkg
	cd src/linux-tools/build && dpkg-source -i -I -b .
	mv src/linux-tools/linux-tools_$(LINUX_PKG_VERSION).debian.tar.xz \
	    src/linux-tools/linux-tools_$(LINUX_PKG_VERSION).dsc pkgs
	touch $@
.PRECIOUS: $(call C_EXPAND,stamps/21.3.%.linux-tools-source-package)

$(call C_EXPAND,stamps/21.3.%.linux-tools-source-package-clean): \
stamps/21.3.%.linux-tools-source-package-clean:
	@echo "21.3. $(CODENAME):  Cleaning up linux-tools source package"
	rm -f pkgs/linux-tools_$(LINUX_PKG_VERSION).debian.tar.xz
	rm -f pkgs/linux-tools_$(LINUX_PKG_VERSION).dsc
	rm -f stamps/21.3.$(CODENAME).linux-tools-source-package
$(call C_TO_CA_DEPS,stamps/21.3.%.linux-tools-source-package-clean,\
	stamps/21.4.%.linux-tools-build-clean)
LINUX_TOOLS_CLEAN_INDEP += stamps/21.3.%.linux-tools-source-package-clean


###################################################
# 21.4. Build linux-tools binary packages for each distro/arch against
# distro src pkg

$(call CA_TO_C_DEPS,stamps/21.4.%.linux-tools-build,\
	stamps/21.3.%.linux-tools-source-package)

$(call CA_EXPAND,stamps/21.4.%.linux-tools-build): \
stamps/21.4.%.linux-tools-build:
	@echo "===== 21.4. $(CA):  Building linux-tools binary package ====="
	$(REASON)
	$(SUDO) INTERMEDIATE_REPO=ppa \
	    $(PBUILD) --build \
		$(PBUILD_ARGS) \
	        pkgs/linux-tools_$(LINUX_PKG_VERSION).dsc
	touch $@
.PRECIOUS: $(call CA_EXPAND,stamps/21.4.%.linux-tools-build)

stamps/21.4.%.linux-tools-build-clean:
	@echo "21.4. $(CA):  Cleaning up linux-tools binary build"
	rm -f pkgs/linux-tools-*_$(LINUX_PKG_VERSION)_$(ARCH).deb
	rm -f pkgs/linux-kbuild-*_$(LINUX_PKG_VERSION)_$(ARCH).deb
	rm -f pkgs/linux-tools_$(LINUX_PKG_VERSION)-$(ARCH).build
	rm -f pkgs/linux-tools_$(LINUX_PKG_VERSION)_$(ARCH).changes
	rm -f stamps/21.4.$(CA).linux-tools-build
# Clean up the distro PPA
$(call CA_TO_C_DEPS,stamps/21.4.%.linux-tools-build-clean,\
	stamps/21.5.%.linux-tools-ppa-clean)

# 21.5. Add linux-tools binary packages to the PPA for each distro
$(call C_TO_CA_DEPS,stamps/21.5.%.linux-tools-ppa,\
	stamps/21.4.%.linux-tools-build)
$(call C_EXPAND,stamps/21.5.%.linux-tools-ppa): \
stamps/21.5.%.linux-tools-ppa: \
		stamps/21.3.%.linux-tools-source-package \
		stamps/0.3.all.ppa-init
	$(call BUILD_PPA,21.5,linux-tools,\
	    pkgs/linux-tools_$(LINUX_PKG_VERSION).dsc,\
	    $(foreach a,$(call CODENAME_ARCHES,$(CODENAME)),\
		pkgs/$(LINUX_TOOLS_PKG_NAME)_$(LINUX_PKG_VERSION)_$(a).deb \
		pkgs/$(LINUX_KBUILD_PKG_NAME)_$(LINUX_PKG_VERSION)_$(a).deb))
# This target is the main result of the linux-tools build
LINUX_TOOLS_INDEP := stamps/21.5.%.linux-tools-ppa

$(call C_EXPAND,stamps/21.5.%.linux-tools-ppa-clean): \
stamps/21.5.%.linux-tools-ppa-clean:
	@echo "21.5. $(CODENAME):  Clean linux-tools PPA stamp"
	rm -f stamps/21.5.$(CODENAME).linux-tools-ppa


# Hook linux-tools builds into final build
FINAL_DEPS_INDEP += $(LINUX_TOOLS_INDEP)
SQUEAKY_ALL += $(LINUX_TOOLS_SQUEAKY_ALL)
CLEAN_ALL += $(LINUX_TOOLS_CLEAN_ALL)
CLEAN_INDEP += $(LINUX_TOOLS_CLEAN_INDEP)


