#!/usr/bin/env bash

# My library.
# Use via: require 'valt/archive'

# Create an encrypted, signed archive from one or more files, directories and archives. Uses the tar file
# specification model.
#
# Usage: newSecureArchive [OPTIONS] <recipient[s]> [ -C <dir> | <file> | <dir> | @<archive> ]...
#
# The -C change directory pattern enables full control over the resulting paths in the archive, e.g.
#
#    -C ${HOME}/my/very/long/path/to/dev/ projectX foo.txt misc/file.txt
#
# cds into the dev directory and adds projectX/**, foo.txt and misc/file.txt at the archive root.
#
# Note that the @<archive> syntax extracts the contents and adds them.
#
# Options:
#
#     -d, --dest-dir              Specify the archive destination directory. Defaults to working dir.
#     -n, --name NAME             Specify the archive file name prefix.
#     -t, --timestamp             Add a timestamp to the archive file name.
#     -z, --timezone NAME         Specify the timezone to use for timestamps, e.g. 'America/Los_Angeles'.
#     -f, --force                 Replace any existing archive file without asking.
#
# Recipients:
#
#     -r, --recipient RECIPIENT   Encrypt to the specified RECIPIENT (public key). May be repeated.
#     -R, --recipients-file PATH  Encrypt to the recipients (public keys) listed at PATH. May be repeated.

newSecureArchive() {
    local tarArgs=()
    local fileCount=0
    local i path

    # Options
    local destDir="${PWD}"
    local name='vault'
    local timeZoneName='UTC'
    local addTimeStamp=0
    local force=0

    # Recipients
    local recipients=

# TODO REMOVE
#
#    # Validate arrays
#    (( fileCount )) || fail "no source files provided"
#    (( ${#archivePathsRef} == fileCount )) || fail "source and archive arrays are different lengths."
#
#    # Ensure source files exist and are files
#    for (( i=0; i < fileCount; i++ )); do
#        assertFile "${sourceFilesRef[i]}"
#    done
#
#    # Ensure archive paths are relative
#    for (( i=0; i < fileCount; i++ )); do
#        path="${archivePathsRef[i]}"
#        [[ ${path:0:1} == '/' ]] && fail "archive paths must be relative: ${path}"
#    done

    # Parse options
    while (( ${#} > 0 )); do
        case "$1" in
            -C ) shift; tarArgs+=(-C "$1") ;;
            -d | --dest-dir) shift; assertDirectory "$1"; destDir="$1" ;;
            -r | --recipient) shift; _assertArchiveRecipient "$1"; appendVar recipients "-r $1" ;;
            -R | --recipients-file) shift; assertFile "$1" "recipients file"; appendVar recipients "-R $1" ;;
            -n | --name) shift; name="$1" ;;
            -t | --timestamp) addTimeStamp=1 ;;
            -z | --timezone) shift; timeZoneName="$1" ;;
            -f | --force) force=1 ;;
            *) tarArgs+=("$1"); (( fileCount++ )) ;;
        esac
        shift
    done

    # Make sure we have one or more recipients
    [[ -n ${recipients} ]] || fail "no recipients specified"

    # Make sure we have one or more files to add

    (( fileCount )) || fail "no files to add"

    # Add timestamp if requested
    (( addTimeStamp )) && name+="-${ TZ=${timeZoneName} date +%Y-%m-%d_%H.%M; }"

    # Ok we're good to go, so create file names, temp tar dir and result file

    local encryptedTarName="${name}.${tarFileExtension}.${ageFileExtension}" # tar.xz.age
    local envelopeTarName="${name}.valt"
    local encryptedTarFile; encryptedTarFile="${ tempDirPath ${encryptedTarName}; }"
    local archiveFile="${destDir}/${envelopeTarName}"

    # If result file exists, delete it if force or user confirms

    _removeExistingArchiveFile

    # Create the encrypted archive file

    _createEncryptedArchive

    mv "${archiveFile}" . # TODO remove
}

verifySecureArchive() {
    echo ; # TODO!!
}

extractSecureArchive() {
    echo ; # TODO!!
}


PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'valt/archive' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

# Design Notes
# ------------
#
# Sign encrypted tar using minisign. Encrypt provides confidentiality, signature provides authenticity/integrity:
#
#   - Files can be stored somewhere less trusted (cloud, shared NAS)
#   - family can detect corruption or tampering with confidence
#   - Provide a formal provenance chain, could matter for legal/financial docs
#
# Wrap sig (encrypted with age public key), encrypted tar and readme in envelope tar.
#
# minisign
#
#   - minisign and age keys as are combined as 'valt' keys: sign keys as comments in age keys
#   - use -W when gen minisign keys to skip encryption: valt private keys are encrypted
#   - sign needs PRIVATE key
#   - verify sig needs PUBLIC key
#   - add both keys to age private as comment (before enc, 😜): only 1 private 'valt' key file to encrypt & store
#   - add public key to age public key as comment: only 1 public 'valt' key file to store
#
# Envelope Content
#
#   - sig file encrypted with age PUBLIC key(s)
#   - tar file encrypted with age PUBLIC key(s)
#   - readme.md from HERE doc in clear. Software install/use instructions.
#
# Key Use
#
#   - signature requires sign PRIVATE key: sign ENCRYPTED tar
#   - verify requires age private key, sign public key: recomputes sig, decrypt sig and assert equal. Stream only if possible.
#   - open requires verify.
#
# Key Storage
#
#   - public valt key: local, bitwarden (etc), users github, google drive, iCloud, etc.
#   - private valt key (encrypted): local, bitwarden (etc)

_init_valt_archive() {
    require 'rayvn/core' 'valt/age'
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
            show primary "${archiveFile}" plain "already exists."
            prompt "${ show -n primary "${archiveFile}" plain "already exists. Replace it?" ;}" yes no answer
            [[ ${answer} == "yes" ]] || exit 0
        fi
        rm "${archiveFile}" || fail
    fi
}

_createEncryptedArchive() {
debugVar tarArgs recipients encryptedTarFile
    # TODO: the -H pax arg for extended headers is gnu-tar. Worth it for new dependency?
#    tar -cvJ -H pax "${tarArgs[@]}" 2> redStream | rage ${recipients} > ${encryptedTarFile} || fail # TODO remove 'v' option
   tar cJ "${tarArgs[@]}" | rage -e ${recipients} > ${encryptedTarFile} || fail # TODO remove 'v' option
}


