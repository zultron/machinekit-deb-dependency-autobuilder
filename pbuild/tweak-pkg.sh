#!/bin/bash -xe
#
# Update source packaging
#
# To be run in the unpacked source directory

PACKAGE=$(dpkg-parsechangelog -ldebian/changelog | \
    awk '/^Source:/ { print $2 }')
PACKAGE_VERSION=$(dpkg-parsechangelog -ldebian/changelog | \
    awk '/^Version:/ { print $2 }')
CODENAME=$1
PACKAGE_RELEASE=$2
MAINTAINER=$3

# Add changelog entry with given version, e.g. 2.6.3-mk1~wheezy1
mv debian/changelog debian/changelog-
cat > debian/changelog <<EOF
${PACKAGE} (${PACKAGE_RELEASE}) stable; urgency=low

  * Machinekit rebuild for ${CODENAME}

 -- ${MAINTAINER}  $(date -R)

EOF
cat debian/changelog- >> debian/changelog
touch -r debian/changelog- debian/changelog
rm debian/changelog-
# Debug info
dpkg-parsechangelog -ldebian/changelog

# Xenomai tweaks
if test $PACKAGE = xenomai; then
    # Fix package format
    echo "3.0 (quilt)" > debian/source/format

    # Fix control file:  Maintainer, and add armhf arch
    mv debian/control debian/control-
    sed -e "s/^Maintainer: .*/Maintainer: ${MAINTAINER}/" \
	-e '/^Architecture: .*amd64/ s/$/ armhf/' \
	debian/control- > debian/control
    touch -r debian/control- debian/control
    rm debian/control-
fi
