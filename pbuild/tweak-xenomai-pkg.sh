#!/bin/bash -x
#
# Update Xenomai source packaging
#
# To be run in the unpacked source directory

CODENAME=$1
PKG_VER=$2
MAINTAINER=$3

# Add changelog entry with given version, e.g. 2.6.3-mk1~wheezy1
mv debian/changelog debian/changelog-
cat > debian/changelog <<EOF
xenomai (${PKG_VER}) unstable; urgency=low

  * Machinekit rebuild for ${CODENAME}

 -- ${MAINTAINER}  $(date -R)

EOF
cat debian/changelog- >> debian/changelog
touch -r debian/changelog- debian/changelog
rm debian/changelog-
# Debug info
dpkg-parsechangelog -ldebian/changelog

# Fix package format
echo "3.0 (quilt)" > debian/source/format

# Fix control file:  Maintainer, and add armhf arch
mv debian/control debian/control-
sed -e "s/^Maintainer: .*/Maintainer: ${MAINTAINER}/" \
    -e '/^Architecture: .*amd64/ s/$/ armhf/' \
    debian/control- > debian/control
touch -r debian/control- debian/control
rm debian/control-
