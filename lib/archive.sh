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
# Only tar, age and minisign are required for access, valt automates for convenience.
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



# ◇ Create an encrypted, signed archive from one or more files, directories and archives. The archive file path is written to
#   standard output.
#
# · USAGE
#
#   newSecureArchive ([-C DIR] INPUT...) (-r RECIPIENT | -R PATH)... [-f] [-n NAME] [--timestamp [--zone ZONE]] [-u TEXT] [-o DIR]
#   newSecureArchive ([-C DIR] INPUT...) --passphrase [-f] [-n NAME] [--timestamp [--zone ZONE]] [-u TEXT] [-o DIR]
#
#   -r, --recipient RECIPIENT  Encrypt to the specified RECIPIENT. See the recipient() function in 'valt/keys'.
#   -R, --recipient-file PATH  Encrypt to one or more recipients. PATH can be a valt key or contain a list of recipients (see the
#                              createRecipientsFile() function in 'valt/keys'). Valt private key files require passphrase input
#                              for decryption. Can be repeated.
#   -p, --passphrase           Encrypt with a passphrase which will be requested via prompt. Cannot be combined with recipients.
#   -f, --force                Overwrite any existing output file (default: fail).
#   -n, --name NAME            Specify the archive file name prefix (default: ${USER}).
#   -t, --timestamp            Add a timestamp to the archive file name.
#   -z, --zone ZONE            Specify the timezone to use for timestamps, e.g. 'America/Los_Angeles' (default: UTC).
#   -u, --user-text TEXT       User text to include in readme. Can contain '\n'.
#   -o, --output-dir DIR       Specify the archive destination directory path (default: ${PWD}).
#   -C DIR                     Change to the specified directory before processing the remaining relative INPUT paths.
#   INPUT...                   File, directory or @<archive> paths to add. An '@' prefixed file path is treated as a tar archive
#                              whose contents should be extracted and added.
#
# · EXAMPLE
#
#   newSecureArchive project/ -R valt.pub                                 # archive project/ dir to ${USER}.valt in ${PWD}
#   newSecureArchive project/ -R valt.pub -n backup -t -o ~/backups       # timestamped name, written to ~/backups
#   newSecureArchive -C ~/dev/ projectX foo.txt -R valt.pub               # -C sets source root ~/dev/ and adds subsequent inputs
#   newSecureArchive -C ~/dev/ projectX -C ~/docs/ notes.txt -R valt.pub  # each -C sets a new source root for subsequent inputs

newSecureArchive() {
    local tarArgs=()
    local encryptArgs=()
    local usePassphrase=0
    local hasRecipient=0
    local fileCount=0
    local timestamp=
    local i path

    # Options
    local destDir="${PWD}"
    local name="${USER}"
    local timeZoneName='UTC'
    local addTimeStamp=0
    local force=0
    local readmeText

    # Parse options

    while (( $# > 0 )); do
        case "$1" in
            -R | --recipient-file) shift; _addRecipientFromKey "$1" encryptArgs hasRecipient ;;
            -r | --recipient) shift; _addRecipient "$1" encryptArgs hasRecipient ;;
            -p | --passphrase) usePassphrase=1 ;;
            -f | --force) force=1 ;;
            -n | --name) shift; name="$1" ;;
            -t | --timestamp) addTimeStamp=1 ;;
            -z | --zone) shift; timeZoneName="$1" ;;
            -u | --user-text) shift; readmeText="$1" ;;
            -o | --output-dir) shift; assertDirectory "$1"; destDir="$1" ;;
            -C ) shift; tarArgs+=(-C "$1"); (( fileCount++ )) ;;
            *) tarArgs+=("$1"); (( fileCount++ )) ;;
        esac
        shift
    done

    debugVar tarArgs encryptArgs usePassphrase hasRecipient fileCount addTimeStamp

    # Validate args

    if (( usePassphrase )); then
        (( hasRecipient )) && invalidArgs "-p / --password cannot be combined with recipients."
    else
        (( hasRecipient )) || invalidArgs "one or more recipients required"
    fi

    (( fileCount )) || invalidArgs "one or more files required"

    if (( addTimeStamp )); then
        timestamp="${ TZ=${timeZoneName} date +%Y-%m-%d_%H.%M; }"
        name+="-${timestamp}"
    fi

    # Create secure work dir

    local workDir isRamBacked
    makeSecureTempDir workDir isRamBacked

    # TODO: ram backed

    # Ok we're probably good to go: create secure work dir, file names and result archive file

    local encryptedTarName="${name}.${_tarFileExtension}.${_ageFileExtension}" # tar.xz.age
    local encryptedTarFile; encryptedTarFile="${workDir}/${encryptedTarName}"
    local archiveName="${name}.valt"
    local archiveFile="${destDir}/${archiveName}"
debugVar workDir isRamBacked encryptedTarName encryptedTarFile archiveName archiveFile

    # Deal with output file conflict

    if [[ -e "${archiveFile}" ]]; then
        if (( force )); then
            rm "${archiveFile}" || fail
        else
            fail "${archiveFile} already exists, use --force to overwrite."
        fi
    fi

    # Create the temporary encrypted archive file

    # TODO: the -H pax arg for extended headers is gnu-tar. Worth it for new dependency?
    tar cJ "${tarArgs[@]}" | encrypt "${encryptArgs[@]}" -o ${encryptedTarFile} || fail

    # TODO:  Implementation gap vs. design
    #
    #    The current _createEncryptedArchive pipes tar | age directly, but signing requires the tar on disk first. The actual flow needs to be:
    #    1. Create payload.tar to temp
    #    2. Minisign payload.tar → .minisig
    #    3. Bundle payload + sig + keys + readme into inner tar
    #    4. Encrypt inner tar with age → encrypted.tar.xz.age
    #    5. Minisign the .age file → outer .minisig
    #    6. Bundle everything into the outer .valt tar
    #
    #    Signing key extraction: To sign, valt needs the minisign private key out of the passphrase-encrypted valt.key. That means decrypting it first, extracting the embedded key, using it,
    #    then clearing it. This is where the FIFO passphrase flow we discussed becomes relevant — you'll need the passphrase after age finishes decrypting.
    #
    #
    #  minisign dependency: Not yet in flake.nix / rayvn.pkg.
    #

    # TODO: create readme, including any user text. Option for entire readme file?
    # TODO: sign
    # TODO: tar into outer ${archiveFile}

    local readMeFileName="README.txt"
    local readMeFile="${workDir}/${readMeFileName}"
    echo "blah blah" > "${readMeFile}"
    tar cJ -C "${workDir}" "${encryptedTarName}" "${readMeFileName}" > ${archiveFile} || fail

    # Finally, return the archive file name via stdout

    echo "${archiveFile}"
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



