#!/bin/bash -xe
#
# 

TOPDIR=/tmp/buildd
PACKAGE_DIR=$1

cd $TOPDIR
tar xzf $TOPDIR/kmodule-srcs.tgz

# tar xzf src/linux-source-*.tar.gz

# cd linux

# kconfigtool
#apt-get install --yes python2.7
# kernel package build

# Install upstream packages for building kernel modules
apt-get install --yes quilt
apt-get install --yes module-assistant
apt-get install --yes debhelper

# get linux-image-xenomai pkg name
XENO_PKG=$(/bin/ls $PACKAGE_DIR/linux-image-* | grep -v .-dbg_)

# Install packages from local pkg directory
dpkg -i $PACKAGE_DIR/linux-headers-*
dpkg -i $PACKAGE_DIR/linux-patch-xenomai_*
dpkg -i $XENO_PKG

# Set kernel package variables
KSRC=`echo /usr/src/linux-headers-*`
KPKG=${KSRC#/usr/src/}
KVER=${KPKG#linux-headers-}-$(dpkg-query --show -f '${Version}' ${KPKG})

# Build kernel module packages
make \
    KSRC=$KSRC \
    KVERS=$KVER \
    MODULE_LOC=/tmp/buildd/git/kmodule \
    build

# Copy packages into the directory given in command line arg
cp /usr/src/kmod-*.deb $PACKAGE_DIR
