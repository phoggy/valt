#!/usr/bin/env bash

# Secure archives.
# Use via: require 'valt/archive'

# ────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
# ◇ DESIGN NOTES
#
# Archive tar is signed using minisign and encrypted with Age. Encryption provides confidentiality, signature provides
# authenticity/integrity:
#
#   - Files can be stored somewhere less trusted (cloud, shared NAS).
#   - Corruption or tampering can be detected with confidence.
#   - Provide a formal provenance chain, could matter for legal/financial docs.
#
# ◇ Valt File Structure
#
#   my-files.valt
#   │
#   ├── encrypted.tar.xz.age
#   │   ├── payload.tar
#   │   ├── payload.tar.minisig
#   │   ├── payload.minisign.pub
#   │   ├── age.pub
#   │   └── README.txt
#   ├── encrypted.tar.xz.age.minisig
#   ├── minisign.pub
#   ├── age.pub
#   ├── valt.meta   # archive version, created date, etc.
#   └── README.txt
#
# The encrypted tar structure ensures there is always a valid payload signature to use even if the outer one is missing or
# tampered with. The clear files are present for single-file convenience. The readme is from a template that includes generic
# description, metadata and instructions along with user supplied content.
#
# Only tar, minisign and rage (or similar) are required for access, valt automates for convenience.
#
# While .valt files should be safe to distribute publicly, users will likely prefer to distribute privately. To support this
# case and to ensure availability of the clear files, a copy is created without the encrypted tar. This can (and should) be made
# publicly available:
#
#   my-files.valt.pub
#   │
#   ├── encrypted.tar.age.minisig
#   ├── minisign.pub
#   ├── age.pub
#   ├── valt.meta   # archive version, created date, etc.
#   └── README.txt
#
# ◇ Valt Keys
#
# See valt/keys for details.
#
# ────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────



# Create an encrypted, signed archive from one or more files, directories and archives. Uses the tar file
# specification model.
#
# Usage: newSecureArchive [OPTIONS] <recipients> [ -C <dir> | <file> | <dir> | @<archive> ]...
#
# The -C change directory pattern enables full control over the resulting paths in the archive, e.g.
#
#    -C ${HOME}/my/very/long/path/to/dev/ projectX foo.txt misc/file.txt
#
# cds into the dev directory and adds projectX/**, foo.txt and misc/file.txt at the archive root.
#
# Note that the @<archive> syntax extracts the contents and adds them.
#
# One or more of the following recipients is required, in any combination:
#
#     -R, --recipients-file  PATH       Encrypt to the recipients listed in file at PATH.
#     -v, --valt-recipient   PATH       Encrypt to the recipient in the valt.pub or valt.key file at PATH.
#     -r, --recipient        RECIPIENT  Encrypt to the specified Age public key string.
#
# Options:
#
#     -d, --dest-dir       Specify the archive destination directory (default: ${PWD}).
#     -n, --name NAME      Specify the archive file name prefix (default: ${USER}).
#     -t, --timestamp      Add a timestamp to the archive file name.
#     -z, --timezone NAME  Specify the timezone to use for timestamps, e.g. 'America/Los_Angeles'.
#     -u, --user-text      User text to include in readme. Can contain '\n'.
#     -f, --force          Replace any existing archive file without asking.

newSecureArchive() {
    local tarArgs=()
    local recipients=()
    local fileCount=0
    local i path

    # Options
    local destDir="${PWD}"
    local name="${USER}"
    local timeZoneName='UTC'
    local addTimeStamp=0
    local force=0
    local readmeText=

    # Parse options

    while (( $# > 0 )); do
        case "$1" in
            -C ) shift; tarArgs+=(-C "$1") ;;
            -d | --dest-dir) shift; assertDirectory "$1"; destDir="$1" ;;
            -v | --valt-recipient) shift; recipients+=(-r "${ extractRecipient "$1"; }")  ;;
            -r | --recipient) shift; _assertArchiveRecipient "$1"; recipients+=(-r "$1") ;;
            -R | --recipients-file) shift; assertFile "$1" "recipients file"; recipients+=(-R "$1") ;;
            -n | --name) shift; name="$1" ;;
            -t | --timestamp) addTimeStamp=1 ;;
            -z | --timezone) shift; timeZoneName="$1" ;;
            -f | --force) force=1 ;;
            -u | --user-text) shift; readmeText="$1" ;;
            *) tarArgs+=("$1"); (( fileCount++ )) ;;
        esac
        shift
    done

# TODO:
#
#    Implementation gap vs. design: The current _createEncryptedArchive pipes tar | rage directly, but signing requires the tar on disk first. The actual flow needs to be:
#    1. Create payload.tar to temp
#    2. Minisign payload.tar → .minisig
#    3. Bundle payload + sig + keys + readme into inner tar
#    4. Encrypt inner tar with rage → encrypted.tar.xz.age
#    5. Minisign the .age file → outer .minisig
#    6. Bundle everything into the outer .valt tar
#
#    Signing key extraction: To sign, valt needs the minisign private key out of the passphrase-encrypted valt.key. That means decrypting it first, extracting the embedded key, using it,
#    then clearing it. This is where the FIFO passphrase flow we discussed becomes relevant — you'll need the passphrase after rage finishes decrypting.
#
#
#  minisign dependency: Not yet in flake.nix / rayvn.pkg.
#

    # Make sure we have one or more recipients

    [[ ${#recipients[@]} ]] || fail "no recipients specified"

    # Make sure we have one or more files to add

    (( fileCount )) || fail "no files to add"

    # Add timestamp to name if requested

    (( addTimeStamp )) && name+="-${ TZ=${timeZoneName} date +%Y-%m-%d_%H.%M; }"

    # Ok we're good to go, so create file names, temp tar dir and result file

    local encryptedTarName="${name}.${tarFileExtension}.${ageFileExtension}" # tar.xz.age
    local envelopeTarName="${name}.valt"
    local encryptedTarFile; encryptedTarFile="${ tempDirPath ${encryptedTarName}; }"
    local archiveFile="${destDir}/${envelopeTarName}"

    # TODO: readme

    # If result file exists, delete it if force or user confirms

    _removeExistingArchiveFile

    # Create the encrypted archive file

    _createEncryptedArchive

    mv "${encryptedTarFile}" .; ls -l ${encryptedTarName} # TODO remove
}

verifySecureArchive() {
    assertFile "$1"
    local keyFile="$1"
    local keyIsPrivate="${2:-false}" # True means full verification with decryption.
    # rayvnTest_ValtKeyPassphrase var can be set for testing.

    echo ; # TODO!!
}

extractSecureArchive() {
    echo ; # TODO!!
}


PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'valt/archive' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"


_init_valt_archive() {
    require 'valt/keys'
}

_assertArchiveRecipient() {
    local recipient="$1"
    if [[ ${recipient} != age* ]]; then
        if [[ -f ${recipient} ]]; then
            fail "${recipient} is not a public key but is a file, use -R instead of -r"
        else
            fail "${recipient} is not a public key"
        fi
    fi
}

_removeExistingArchiveFile() {
    if [[ -e "${archiveFile}" ]]; then
        if (( ! force )); then
            local answer
            show primary "${archiveFile}" "already exists."
            prompt "${ show -n primary "${archiveFile}" "already exists. Replace it?" ;}" yes no answer
            [[ ${answer} == "yes" ]] || exit 0
        fi
        rm "${archiveFile}" || fail
    fi
}

_createEncryptedArchive() {
debugVar tarArgs recipients encryptedTarFile
    # TODO: the -H pax arg for extended headers is gnu-tar. Worth it for new dependency?
    tar cJ "${tarArgs[@]}" | rage "${recipients[@]}" > ${encryptedTarFile} || fail
}


