#!/bin/bash -ex

# #####################################
# Process command line

# Read .dsc, codename and maintainer name from cl args
DSC="$(readlink -f $1)"
CODENAME=$2
MAINTAINER=$3

# Directory variables
TOPDIR="$(dirname $DSC)"
UNPACKDIR="${TOPDIR}/build"


# #####################################
# Create source package

# Clean old build dir and unpack source package
rm -rf "${UNPACKDIR}"
dpkg-source -x "${DSC}" "${UNPACKDIR}"

# Grab package name and version from changelog; append ~<codename>1 to
# version
PACKAGE=$(dpkg-parsechangelog -l${UNPACKDIR}/debian/changelog | \
    awk '/^Source: / { print $2 }')
VER_OLD=$(dpkg-parsechangelog -l${UNPACKDIR}/debian/changelog | \
    awk '/^Version: / { print $2 }')
VER_NEW=${VER_OLD}~${CODENAME}1

# Add a 'rebuilt for <codename>' changelog entry with updated
# version (and keep timestamp)
newlog() {
    cat <<EOF
${PACKAGE} (${VER_NEW}) DA-Kernels; urgency=low

  * Rebuild for ${CODENAME}

 -- ${MAINTAINER}  $(date -R)

EOF
}
mv "${UNPACKDIR}/debian/changelog" "${UNPACKDIR}/debian/changelog-"
{ newlog; cat  "${UNPACKDIR}/debian/changelog-"; } > \
    "${UNPACKDIR}/debian/changelog"
touch -r "${UNPACKDIR}/debian/changelog-" "${UNPACKDIR}/debian/changelog"
rm "${UNPACKDIR}/debian/changelog-"

# Create source package
dpkg-source -b ${UNPACKDIR}


# #####################################
# Build binary packages

# Unpack new source package
rm -r "${UNPACKDIR}"
dpkg-source -x "$(basename ${DSC} ${VER_OLD}.dsc)${VER_NEW}.dsc" "${UNPACKDIR}"

# Build binary packages
cd "${UNPACKDIR}"
dpkg-buildpackage -b -j16
