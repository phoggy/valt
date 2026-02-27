#!/usr/bin/env bash

# My library.
# Use via: require 'valt/archive'

# Create an encrypted, signed archive from one or more files or directories.
#
# Usage: newSecureArchive [OPTIONS] <recipient> <sourceFilesArrayVarName> <archivePathsArrayVarName>
#
# Options:
#
#     -d, --dest-dir              Specify the destination directory. Defaults to working dir.
#     -n, --name NAME             Specify the output file name prefix.
#     -t, --timestamp             Add a timestamp to the output file name.
#     -z, --timezone NAME         Specify the timezone to use for timestamps, e.g. 'America/Los_Angeles'.
#     -f, --force                 Replace any existing output file without asking.
#
# Recipients:
#
#     -r, --recipient RECIPIENT   Encrypt to the specified RECIPIENT (public key). May be repeated.
#     -R, --recipients-file PATH  Encrypt to the recipients (public keys) listed at PATH. May be repeated.

newSecureArchive() {
    local -n sourceFilesRef=$1
    local -n archivePathsRef=$2
    local fileCount=${#sourceFilesRef}
    local i path

    # Options
    local destDir="${PWD}"
    local name='vault'
    local timeZoneName='UTC'
    local addTimeStamp=0
    local force=0

    # Recipients
    local recipients=

    # Validate arrays
    (( fileCount )) || fail "no source files provided"
    (( ${#archivePathsRef} == fileCount )) || fail "source and archive arrays are different lengths."

    # Ensure source files exist and are files
    for (( i=0; i < fileCount; i++ )); do
        assertFile "${sourceFilesRef[i]}"
    done

    # Ensure archive paths are relative
    for (( i=0; i < fileCount; i++ )); do
        path="${archivePathsRef[i]}"
        [[ ${path:0:1} == '/' ]] && fail "archive paths must be relative: ${path}"
    done

    # Parse options
    while (( ${#} > 0 )); do
        case "${1}" in
        -d | --dest-dir) shift; assertDirectory "$1"; destDir="$1" ;;
        -r | --recipient) shift; assertRecipient "$1"; appendVar recipients "-r $1" ;;
        -R | --recipients-file) shift; assertFile "$1" "recipients file"; appendVar recipients "-R $1" ;;
        -n | --name) shift; name="$1" ;;
        -t | --timestamp) addTimeStamp=1 ;;
        -z | --timezone) shift; timeZoneName="$1" ;;
        -f | --force) force=1 ;;
        *) fail "unknown option: $1"
        esac
        shift
    done

    # Make sure we have one or more recipients
    [[ -n ${recipients} ]] || fail "no recipients specified"

    # Add timestamp if requested
    (( addTimeStamp )) && name+="-${ TZ=${timeZoneName} date +%Y-%m-%d_%H.%M; }"

    # Ok we're good to go, so create file names, temp tar dir and result file

    local tarDirName="${name}.${tarFileExtension}"  # tar.xz
    local encryptedTarName="${name}.${tarFileExtension}.${ageFileExtension}" # tar.xz.age
    local envelopeTarName="${name}.valt"
    local tarDir; tarDir="${ tempDirPath ${tarDirName}; }"
    local encryptedTarFile; encryptedTarFile="${ tempDirPath ${encryptedTarName}; }"
    local archiveFile="${destDir}/${envelopeTarName}"

    # If result file exists, delete it if force or user confirms

    _removeExistingArchiveFile

    # Create the encrypted archive file

    _createEncryptedArchive
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'valt/archive' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

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
    local sourceDir
    if (( fileCount == 1 )) && [[ -d ${sourceFilesRef[0]} ]]; then
        sourceDir=${sourceFilesRef[0]}
    else
        _populateArchiveDir
        sourceDir="${tarDir}"
    fi
    tar cvJ "${tarDir}" | rage ${recipients} > ${encryptedTarFile} || fail # TODO remove 'v' option
}

_populateArchiveDir() {
    local i src dst dir
    for (( i=0; i < fileCount; i++ )); do
        src="${sourceFilesRef[i]}"
        dst="${archivePathsRef[i]}"
        if [[ ${dst} == */* ]]; then
            dir="${ dirName "${dst}"; }"
            mkdir -p "${tarDir}/${dir}" || fail
        fi
        cp "${src}" "${dst}" || fail
    done
}


