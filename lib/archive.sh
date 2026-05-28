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
#   │   ├── payload.tar.minisign
#   │   ├── minisign.pub
#   │   ├── age.pub
#   │   └── README.txt # include metadata: created date, archive/valt/rayvn versions, USER, machine info, etc.
#   ├── encrypted.tar.xz.age.minisign
#   ├── minisign.pub
#   ├── age.pub
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
#   ├── encrypted.tar.age.minisign
#   ├── minisign.pub
#   ├── age.pub
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
#   newSecureArchive ([-C DIR] INPUT...) -i PATH (-r RECIPIENT | -R PATH)... [-f] [-n NAME] [--zone ZONE] [-u TEXT] [-o DIR]
#
#   -i, --identity PATH        The valt.key file used to sign the archive.
#   -r, --recipient RECIPIENT  Encrypt to the specified RECIPIENT. See the recipient() function in 'valt/keys'.
#   -R, --recipient-file PATH  Encrypt to one or more recipients. PATH can be a valt key or contain a list of recipients (see the
#                              createRecipientsFile() function in 'valt/keys'). Valt private key files require passphrase input
#                              for decryption. Can be repeated.
#   -f, --force                Overwrite any existing output file (default: fail).
#   -n, --name NAME            Specify the archive file name prefix (default: ${USER}).
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
    local privateKey=
    local tarArgs=()
    local encryptArgs=()
    local hasRecipient=0
    local fileCount=0
    local timestamp=
    local i path

    # Options
    local destDir="${PWD}"
    local name="${USER}"
    local timeZoneName='UTC'
    local force=0
    local readmeText

    # Parse options

    while (( $# > 0 )); do
        case "$1" in
            -i | --identity) shift; assertFile "$1"; privateKey="$1" ;;
            -R | --recipient-file) shift; _addRecipientFromKey "$1" encryptArgs hasRecipient ;;
            -r | --recipient) shift; _addRecipient "$1" encryptArgs hasRecipient ;;
            -f | --force) force=1 ;;
            -n | --name) shift; assertValidFileName "$1"; name="$1" ;;
            -z | --zone) shift; timeZoneName="$1" ;;
            -u | --user-text) shift; readmeText="$1" ;;
            -o | --output-dir) shift; assertDirectory "$1"; destDir="$1" ;;
            -C ) shift; tarArgs+=(-C "$1"); (( fileCount++ )) ;;
            *) tarArgs+=("$1"); (( fileCount++ )) ;;
        esac
        shift
    done
    timestamp="${ TZ=${timeZoneName} date +%Y-%m-%d_%H.%M; }-${timeZoneName}"
    name+="-${timestamp}"

    debugVar signingKey tarArgs encryptArgs hasRecipient fileCount name

    # Make sure we have required args

    [[ -n "${privateKey}" ]] || invalidArgs "signing identity file required"
    (( hasRecipient )) || invalidArgs "one or more recipients required"
    (( fileCount )) || invalidArgs "one or more files required"

    # Create secure work dir

    local workDir isRamBacked
    makeSecureTempDir workDir isRamBacked

    # TODO: ram backed

    # Chack output file conflict

    local archiveName="${name}.valt"
    local archivePubName="${archiveName}.pub"
    local archiveFile="${destDir}/${archiveName}"
    local archivePubFile="${destDir}/${archivePubName}"

    _checkOutputConflict ${force} "${archiveFile}" "${archivePubFile}"

    # Ok we're probably good to go: create secure work dir, file names and result archive file

    # TWO OUTPUT FILES!

    #   my-files.valt                       archiveName
    #   │
    #   ├── encrypted.tar.xz.age            encryptedTarName
    #   │   ├── payload.tar                 payloadTarName
    #   │   ├── payload.tar.minisign        payloadTarSigName
    #   │   ├── minisign.pub                sigPubName
    #   │   ├── age.pub                     agePubName
    #   │   └── README.txt                  readMeName # include metadata: created date, archive/valt/rayvn versions, USER, machine info, etc.
    #   ├── encrypted.tar.xz.age.minisign   encryptedTarSigName
    #   ├── minisign.pub                    sigPubName
    #   ├── age.pub                         agePubName
    #   └── README.txt                      readMeName

    #   my-files.valt.pub                   archivePubName
    #   │
    #   ├── encrypted.tar.age.minisign      encryptedTarSigName
    #   ├── minisign.pub                    sigPubName
    #   ├── age.pub                         agePubName
    #   └── README.txt                      readMeName


    # Common file names

    local agePubName="age.pub"
    local sigPubName="minisign.pub"
    local readMeName="README.txt"

    # Encrypted file names

    local payloadTarName="payload.tar"
    local payloadTarSigName="${payloadTarName}.${_signatureFileSuffix}"

    # Envelope tar file names

    local encryptedTarName="encrypted.${_tarFileExtension}.${_ageFileExtension}"
    local encryptedTarSigName="${encryptedTarName}.${_signatureFileSuffix}"

    # Content file names

    local payloadFileNames=("${payloadTarName}" "${payloadTarSigName}" "${agePubName}" "${sigPubName}" "${readMeName}")
    local archiveFileNames=("${encryptedTarName}" "${encryptedTarSigName}" "${agePubName}" "${sigPubName}" "${readMeName}")
    local archivePubFileNames=("${encryptedTarSigName}" "${agePubName}" "${sigPubName}" "${readMeName}")

    # Create the age.pub file

    recipient "${privateKey}" > "${workDir}/${agePubName}" || fail

    # Create the minisign.pub file

    local tempFile
    publicSigningKeyToTempFile "${privateKey}" tempFile || fail
    assertFile "${tempFile}"
    mv "${tempFile}" "${workDir}/${sigPubName}" || fail

    # Create the README file TODO!!

    local readMeFile="${workDir}/${readMeName}"
    echo "blah blah" > "${readMeFile}"

    # Create the payload file and sign it
    echo "creating payload.tar" > ${terminal}

    # TODO: the -H pax arg for extended headers is gnu-tar. Worth it for new dependency?
    tar cJ "${tarArgs[@]}" > "${workDir}/${payloadTarName}" || fail
    signFile "${privateKey}" "${workDir}/${payloadTarName}" || fail

    # Create the encrypted payload tar and sign it

    echo "encrypting payload.tar" > ${terminal}
    encrypt "${workDir}/${payloadTarName}" "${encryptArgs[@]}" -o "${workDir}/${encryptedTarName}" || fail
    echo "signing encrypted payload.tar" > ${terminal}
    signFile "${privateKey}" "${workDir}/${encryptedTarName}" || fail

    # Remove the payload files so we only have the encrypted forms

    rm "${workDir}/${payloadTarName}" "${workDir}/${payloadTarSigName}"|| fail


echo "creating archives" > ${terminal}
    # Create the archive files

    tar cJ -C "${workDir}" "${archiveFileNames[@]}" > ${archiveFile} || fail
    tar cJ -C "${workDir}" "${archivePubFileNames[@]}" > ${archivePubFile} || fail

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
    declare -gr _archiveVersion="1.0"
}

_checkOutputConflict() {
    local _force="$1"; shift
    while (( $# )); do
        if [[ -e "$1" ]]; then
            [[ -d "$1" ]] && fail "$1 already exists and is a directory"
            if (( _force )); then
                rm "$1" || fail
            else
                fail "$1 already exists, use --force to overwrite"
            fi
        fi
        shift
    done
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



