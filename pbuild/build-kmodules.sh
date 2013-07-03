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

# Install packages from local PPA
# Packages are unsigned, so --force-yes
apt-get install --force-yes --yes linux-patch-xenomai
apt-get install --force-yes --yes linux-headers-xenomai

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
