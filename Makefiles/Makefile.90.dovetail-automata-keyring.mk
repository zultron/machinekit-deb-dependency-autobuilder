###################################################
# 90. dovetail-automata-keyring build rules

# Enable this package build
ENABLED_BUILDS += DOVETAIL_AUTOMATA_KEYRING

###################################################
# Variables that may change

# Dovetail-Automata-Keyring package
DOVETAIL_AUTOMATA_KEYRING_PKG_RELEASE = 1
DOVETAIL_AUTOMATA_KEYRING_VERSION = 0.1


###################################################
# Variables that should not change much
# (or auto-generated)

# Source name
DOVETAIL_AUTOMATA_KEYRING_SOURCE_NAME := dovetail-automata-keyring

# Index
DOVETAIL_AUTOMATA_KEYRING_INDEX := 90

# Arch-indep pkg
DOVETAIL_AUTOMATA_KEYRING_ARCH := INDEP

# Submodule name
DOVETAIL_AUTOMATA_KEYRING_SUBMODULE := git/dovetail-automata-keyring-deb

# Packages; will be suffixed by _<pkg_version>_<arch>.deb
DOVETAIL_AUTOMATA_KEYRING_PKGS_ALL := dovetail-automata-keyring
DOVETAIL_AUTOMATA_KEYRING_PKGS_ARCH := 

# Misc paths, filenames, executables
DOVETAIL_AUTOMATA_KEYRING_COMPRESSION = gz
# No tarball
DOVETAIL_AUTOMATA_KEYRING_TARBALL := 
DOVETAIL_AUTOMATA_KEYRING_URL = 
