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

UNCONFIGURED_FEATURE_SETS="$*"
cd ${TOPDIR}/src/linux/build

# Install packages containing the i-pipe patches
XENOMAI_PKGS=xenomai-kernel-source

for featureset in $UNCONFIGURED_FEATURE_SETS; do
    case $featureset in
	xenomai) XENOMAI_PKGS="" ;;
    esac
done
apt-get install -y --force-yes $XENOMAI_PKGS

# Unconfigure any requested featuresets
unconfigure_featureset() {
    fs=$1
    # List files to unconfigure featureset
    DEFINES_FILES="$(find debian/config -name defines \
	-exec grep -l '^ *'${fs} '{}' \;)"
    # Comment out featureset in each file
    for f in $DEFINES_FILES; do
	sed -i 's/^\( *xenomai$\)/#\1/' $f
    done
}
for featureset in $UNCONFIGURED_FEATURE_SETS; do
    unconfigure_featureset $featureset
done

# Build the debian/control file
#
# Install python, needed by genconfig.py
apt-get install -y --force-yes python

debian/rules debian/control || true # always fails
