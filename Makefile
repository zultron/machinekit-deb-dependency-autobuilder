###################################################
# Variables that may change

# Arches to build
ARCHES = i386 amd64

# Ubuntu codename data
UBUNTU_CODENAMES = precise lucid
UBUNTU_MIRROR = http://archive.ubuntu.com/ubuntu

# Debian codename data
DEBIAN_CODENAMES = squeeze
DEBIAN_MIRROR = http://ftp.at.debian.org/debian/

# Ubuntu keys
UBUNTU_KEYID = 40976EAF437D05B5
UBUNTU_KEYRING = $(TOPDIR)/admin/ubuntu-keyring.gpg
KEYSERVER = hkp://keys.gnupg.net


###################################################
# Variables that should not change much
# (or auto-generated)

# Other variables
TOPDIR = $(shell pwd)
SUDO = sudo
DIRS = admin tmp
ALLDIRS = $(patsubst %,%/.dir-exists,$(DIRS) $(CODENAMES))
CODENAMES = $(UBUNTU_CODENAMES) $(DEBIAN_CODENAMES)
BASE_CHROOT_TARBALLS = $(foreach C,$(CODENAMES),$(foreach A,$(ARCHES),\
  $(C)/base-$(A).tgz))


###################################################
# Functions

# Given codename, return mirror
MIRROR = $(if $(findstring $(1),$(UBUNTU_CODENAMES)),$(UBUNTU_MIRROR),\
	$(if $(findstring $(1),$(DEBIAN_CODENAMES)),$(DEBIAN_MIRROR)))

# Given codename, return --debootstrapopts --keyring= args to pbuilder
DEBOOTSTRAPOPTS = $(if $(findstring $(1),$(UBUNTU_CODENAMES)),\
	--debootstrapopts --keyring=$(TOPDIR)/admin/ubuntu-keyring.gpg)


###################################################
# out-of-band checks

# check that pbuilder exists
ifeq ($(shell /bin/ls /usr/sbin/pbuilder 2>/dev/null),)
  $(error /usr/sbin/pbuilder does not exist)
endif


###################################################
# Rules

.PHONY:  all
all:  $(BASE_CHROOT_TARBALLS)

.dir-exists%:
	mkdir -p $(@D) && touch $@

admin/ubuntu-keyring.gpg: $(ALLDIRS)
	gpg --no-default-keyring --keyring=$(UBUNTU_KEYRING) \
		--keyserver=$(KEYSERVER) --recv-keys \
		--trust-model always $(UBUNTU_KEYID)

# base chroot tarballs are named e.g. lucid/base-i386.tgz
# in this case, $(*D) = lucid; $(*F) = i386
base-%.tgz: admin/ubuntu-keyring.gpg $(*D)/aptcache/$(*F)/.dir-exists
	@echo "distro $(*D); arch $(*F); mirror $(call MIRROR,$(*D))"
	$(SUDO) pbuilder --create --basetgz $@ --buildplace tmp \
	  --buildresult $(*D) --distribution $(*D) --architecture $(*F) \
	  --logfile $(*D)/$$(basename $@ .tgz).create.log \
	  --mirror $(call MIRROR,$(*D)) \
	  --aptcache $(TOPDIR)/$(*D)/aptcache/$(*F) \
	  $(call DEBOOTSTRAPOPTS,$(*D))

.PHONY:  clean_base_chroot_tarballs
clean_base_chroot_tarballs:
	for codename in $(CODENAMES); do \
	    for arch in $(ARCHES); do \
		rm -f $$codename/base-$$arch.tgz \
		rm -f $$codename/base-$$arch.create.log \
	    done \
	done

test:
	@echo BASE_CHROOT_TARBALLS:
	@for i in $(BASE_CHROOT_TARBALLS); do echo "    $$i"; done
