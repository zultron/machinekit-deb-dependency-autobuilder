#!/bin/bash -xe
#
# This script is run in a random pbuilder chroot to set up the Linux
# kernel source package.
#
# At the same time, any feature sets passed in on the command line
# will be unconfigured.
#
# The set up requires the linux-patch-xenomai package, generated
# earlier in the make run, to be installed, so this is best done in a
# chroot.

shell() {
    /bin/bash -i
}
trap shell ERR

cd ${TOPDIR}/src/linux/build

# Read list of build deps and disabled featuresets from command line
BUILD_DEPS=
DISABLED_FEATURESETS=
while getopts b:d: ARG; do
    case $ARG in
        b) BUILD_DEPS="$BUILD_DEPS $OPTARG" ;;
        d) DISABLED_FEATURESETS="$DISABLED_FEATURESETS $OPTARG" ;;
    esac
done

apt-get install -y --force-yes $BUILD_DEPS

# Disable any requested featuresets
disable_featureset() {
    fs=$1
    sed -i 's/^\( *'$fs'$\)/#\1/' debian/config/defines
}
for featureset in $DISABLED_FEATURESETS; do
    disable_featureset $featureset
done

# Build the debian/control file
#
# Install python, needed by genconfig.py
apt-get install -y --force-yes python

debian/rules debian/control NOFAIL=true
