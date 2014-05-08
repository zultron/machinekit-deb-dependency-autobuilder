#!/bin/bash -xe
#
# This script is run in a random pbuilder chroot to set up the Linux
# kernel source package.
#
# The set up requires the linux-patch-xenomai package, generated
# earlier in the make run, to be installed, so this is best done in a
# chroot.

apt-get install -y --force-yes linux-patch-xenomai
cd ${TOPDIR}/src/linux/build
debian/rules debian/control || true # always fails
