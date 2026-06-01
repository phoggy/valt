#!/usr/bin/env bash

# Secure archives.
# Use via: require 'valt/archive'

# ◇ Create an encrypted, signed archive from one or more files, directories and archives. The archive file path is written to
#   standard output. Also creates the public version of the archive (same path plus ".pub" suffix). See NOTES below for details.
#
# · USAGE
#
#   newSecureArchive ([-C DIR] INPUT...) -i PATH (-r RECIPIENT | -R PATH)... [-f] [-n NAME] [--zone ZONE] [-u TEXT] [-o DIR]
#
#   -i, --identity PATH        The valt.key file used to sign the archive.
#   -r, --recipient RECIPIENT  Encrypt to the specified RECIPIENT. See the recipient() function in 'valt/keys'.
#   -R, --recipient-file PATH  Encrypt to one or more recipients. PATH can be a valt key or contain a list of recipients (see the
#                              newRecipientsFile() function in 'valt/keys'). Valt private key files require passphrase input
#                              for decryption. Can be repeated.
#   -f, --force                Overwrite any existing output file (default: fail).
#   -n, --name NAME            Specify the archive file name prefix (default: ${USER}).
#   -z, --zone ZONE            Specify the timezone to use for timestamps, e.g. PDT (default: UTC).
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
#
# · NOTES
#
#   Encryption provides confidentiality while signatures provide authenticity/integrity:
#
#     - Files can be stored somewhere less trusted (cloud, shared NAS).
#     - Corruption or tampering can be detected with confidence.
#     - Provides a formal provenance chain for legal/financial docs.
#
#   Valt File Structure
#
#   backup-2026-05-28_23.14_PDT.valt
#   │
#   ├── encrypted.tar.xz.age
#   │   ├── payload.tar
#   │   ├── payload.tar.minisign
#   │   ├── minisign.pub
#   │   ├── age.pub
#   │   └── README.txt
#   ├── encrypted.tar.xz.age.minisign
#   ├── minisign.pub
#   ├── age.pub
#   └── README.txt
#
#   The encrypted tar structure ensures there is always a valid payload signature to use even if the outer one is missing or
#   tampered with. The unencrypted files can be shared publicly and are packaged as a separate file:
#
#   backup-2026-05-28_23.14_PDT.valt.pub
#   │
#   ├── encrypted.tar.age.minisign
#   ├── minisign.pub
#   ├── age.pub
#   └── README.txt
#
#   This file can be recreated from the original via the extractPublicArchive function.
#
#   Only tar, age and minisign are required for access to the contents of a valt archive. The verifySecureArchive and
#   extractSecureArchive functions simplify the process.

newSecureArchive() {
    local privateKey=
    local tarArgs=()
    local encryptArgs=()
    local inputPaths=()
    local hasRecipient=0
    local timestamp=

    # Options
    local destDir="${PWD}"
    local name="${USER}"
    local timeZoneName='UTC'
    local force=0
    local userReadmeText
    local currentDir="${PWD}"

    # Parse options

    while (( $# > 0 )); do
        case "$1" in
            -i | --identity) shift; _assertValtKey "$1"; privateKey="$1" ;;
            -R | --recipient-file) shift; _addRecipientFromKey "$1" encryptArgs hasRecipient ;;
            -r | --recipient) shift; _addRecipient "$1" encryptArgs hasRecipient ;;
            -f | --force) force=1 ;;
            -n | --name) shift; assertValidFileName "$1"; name="$1" ;;
            -z | --zone) shift; timeZoneName="$1" ;;
            -u | --user-text) shift; userReadmeText="$1" ;;
            -o | --output-dir) shift; assertDirectory "$1"; destDir="$1" ;;
            -C ) shift; tarArgs+=(-C "$1"); [[ "$1" == /* ]] && currentDir="$1" || currentDir="${PWD}/$1" ;;
            *) tarArgs+=("$1"); [[ "$1" == /* ]] && inputPaths+=("$1") || inputPaths+=("${currentDir}/$1") ;;
        esac
        shift
    done

    timestamp="${ timeStamp "${timeZoneName}"; }"
    name+="-${timestamp}"

    # Make sure we have required args

    [[ -n "${privateKey}" ]] || invalidArgs "signing identity file required"
    (( hasRecipient )) || invalidArgs "one or more recipients required"
    (( ${#inputPaths[@]} )) || invalidArgs "one or more files required"

    # Check output file conflict

    local archiveName="${name}.valt"
    local archivePubName="${archiveName}.pub"
    local archiveFile="${destDir}/${archiveName}"
    local archivePubFile="${destDir}/${archivePubName}"

    _checkOutputConflict ${force} "${archiveFile}" "${archivePubFile}"

    # Create secure work dir sized to hold payload.tar + encrypted.tar simultaneously (2× input)

    local inputSizeMb; inputSizeMb=${ du -sm "${inputPaths[@]}" 2>/dev/null | gawk '{sum += $1} END {print int(sum) + 1}'; }
    local workDir isRamBacked
    makeSecureTempDir workDir isRamBacked $(( inputSizeMb * 2 + 64 ))
    if (( ! isRamBacked )); then
        local choice
        warn "Could not create secure RAM backed temp storage."
        show "   On disk temporary files will be deleted on exit, but this is not quite as secure as RAM." nl >&${ttyFd}
        confirm "Do you want to continue?" no yes choice || bye
        (( choice == 0 )) && bye
    fi

    # Since we will do three operations that require decrypting the private key, get it now. Store it in a local variable
    # with the same as the text var so that it will go out of scope when we exit.

    local rayvnTest_ValtKeyPassphrase="${rayvnTest_ValtKeyPassphrase}"
    if [[ -z ${rayvnTest_ValtKeyPassphrase} ]]; then
        local path; path="${ tildePath "${privateKey}"; }"
        local prompt; prompt="${ show "Enter passphrase for" blue "${path}"; }"
        readPassword "${prompt}" rayvnTest_ValtKeyPassphrase 30 false || fail
        cursorUpOneAndEraseLine
    fi

    # Create the age.pub file

    recipient "${privateKey}" > "${workDir}/${_archiveAgePubName}" || fail

    # Create the minisign.pub file

    local tempFile
    publicSigningKeyToTempFile "${privateKey}" tempFile || fail
    assertFile "${tempFile}"
    mv "${tempFile}" "${workDir}/${_archiveSigPubName}" || fail

    # Create the private README file

    _privateReadMe "${workDir}/${_archiveReadMeName}" "${archiveName}" "${userReadmeText}"

    # Create the payload file and sign it

    tar cJ "${tarArgs[@]}" > "${workDir}/${_archivePayloadName}" || fail
    signFile "${privateKey}" "${workDir}/${_archivePayloadName}" || fail

    # Create the encrypted tar and sign it

    tar cJ -C "${workDir}" "${_archiveEncryptedFiles[@]}" | encrypt "${encryptArgs[@]}" -o "${workDir}/${_archiveEncryptedName}" || fail
    signFile "${privateKey}" "${workDir}/${_archiveEncryptedName}" || fail

    # Remove the payload files so we only have the encrypted forms

    rm "${workDir}/${_archivePayloadName}" "${workDir}/${_archivePayloadSigName}"|| fail

    # Create the public README file (overwrites the private one already in the encrypted tar)

    _publicReadMe "${workDir}/${_archiveReadMeName}" "${archiveName}" "${userReadmeText}"

    # Create the archive files

    tar cJ -C "${workDir}" "${_archiveFiles[@]}" > ${archiveFile} || fail
    tar cJ -C "${workDir}" "${_archivePubFiles[@]}" > ${archivePubFile} || fail

    # Finally, return the archive file name via stdout

    echo "${archiveFile}"
}

# ◇ Verify the signatures of a secure archive. Checks both the outer encrypted archive signature
#   and the inner payload signature (requires decryption with the private key).
#
# · USAGE
#
#   verifySecureArchive ARCHIVE -i PATH
#
#   ARCHIVE             Path to the .valt archive file.
#   -i, --identity PATH The valt.key file used to decrypt and verify signatures.

verifySecureArchive() {
    local archiveFile= keyFile=

    while (( $# )); do
        case "$1" in
            -i | --identity) shift; _assertValtKey "$1"; keyFile="$1" ;;
            *) [[ -z ${archiveFile} ]] || invalidArgs "unexpected argument: $1"
               assertFile "$1"; archiveFile="$1" ;;
        esac
        shift
    done

    [[ -n ${archiveFile} ]] || invalidArgs "archive file required"
    [[ -n ${keyFile} ]] || invalidArgs "identity file required"

    # Extract outer archive (contents are still encrypted — regular temp dir is fine)

    local outerDir; outerDir="${ makeTempDir; }"
    tar xJf "${archiveFile}" -C "${outerDir}" || fail

    # Verify outer signature

    verifyFileSignature "${keyFile}" "${outerDir}/${_archiveEncryptedName}" \
                        "${outerDir}/${_archiveEncryptedSigName}"

    # Get key passphrase once for both decrypt and inner verify

    local rayvnTest_ValtKeyPassphrase="${rayvnTest_ValtKeyPassphrase}"
    if [[ -z ${rayvnTest_ValtKeyPassphrase} ]]; then
        local path; path="${ tildePath "${keyFile}"; }"
        local prompt; prompt="${ show "Enter passphrase for" blue "${path}"; }"
        readPassword "${prompt}" rayvnTest_ValtKeyPassphrase 30 false || fail
        cursorUpOneAndEraseLine
    fi

    # Decrypt and expand inner archive to a secure temp dir

    local innerDir; makeSecureTempDir innerDir
    decrypt -i "${keyFile}" -o "${innerDir}/decrypted.tar.xz" "${outerDir}/${_archiveEncryptedName}" || fail
    tar xJf "${innerDir}/decrypted.tar.xz" -C "${innerDir}" || fail

    # Verify inner payload signature

    verifyFileSignature "${keyFile}" "${innerDir}/${_archivePayloadName}" \
                        "${innerDir}/${_archivePayloadSigName}"
}

# ◇ Verify and extract the contents of a secure archive into a directory.
#   Checks both the outer and inner signatures before extracting the payload.
#
# · USAGE
#
#   extractSecureArchive ARCHIVE -i PATH [-o DIR]
#
#   ARCHIVE             Path to the .valt archive file.
#   -i, --identity PATH The valt.key file used to decrypt and verify signatures.
#   -o, --output-dir    Directory to extract contents into (default: ${PWD}).

extractSecureArchive() {
    local archiveFile= keyFile= destDir="${PWD}"

    while (( $# )); do
        case "$1" in
            -i | --identity) shift; _assertValtKey "$1"; keyFile="$1" ;;
            -o | --output-dir) shift; assertDirectory "$1"; destDir="$1" ;;
            *) [[ -z ${archiveFile} ]] || invalidArgs "unexpected argument: $1"
               assertFile "$1"; archiveFile="$1" ;;
        esac
        shift
    done

    [[ -n ${archiveFile} ]] || invalidArgs "archive file required"
    [[ -n ${keyFile} ]] || invalidArgs "identity file required"

    # Extract outer archive (contents are still encrypted — regular temp dir is fine)

    local outerDir; outerDir="${ makeTempDir; }"
    tar xJf "${archiveFile}" -C "${outerDir}" || fail

    # Verify outer signature

    verifyFileSignature "${keyFile}" "${outerDir}/${_archiveEncryptedName}" \
                        "${outerDir}/${_archiveEncryptedSigName}"

    # Get key passphrase once for both decrypt and inner verify

    local rayvnTest_ValtKeyPassphrase="${rayvnTest_ValtKeyPassphrase}"
    if [[ -z ${rayvnTest_ValtKeyPassphrase} ]]; then
        local path; path="${ tildePath "${keyFile}"; }"
        local prompt; prompt="${ show "Enter passphrase for" blue "${path}"; }"
        readPassword "${prompt}" rayvnTest_ValtKeyPassphrase 30 false || fail
        cursorUpOneAndEraseLine
    fi

    # Decrypt and expand inner archive to a secure temp dir

    local innerDir; makeSecureTempDir innerDir
    decrypt -i "${keyFile}" -o "${innerDir}/decrypted.tar.xz" "${outerDir}/${_archiveEncryptedName}" || fail
    tar xJf "${innerDir}/decrypted.tar.xz" -C "${innerDir}" || fail

    # Verify inner payload signature

    verifyFileSignature "${keyFile}" "${innerDir}/${_archivePayloadName}" \
                        "${innerDir}/${_archivePayloadSigName}"

    # Extract payload to destination

    tar xJf "${innerDir}/${_archivePayloadName}" -C "${destDir}" || fail
}

# ◇ Extract the public portion of a secure archive, creating a .valt.pub file alongside it.
#   The .valt.pub contains the signature, public keys, and README but not the encrypted payload,
#   making it safe to share publicly. Useful when the .valt.pub was not retained from creation.
#
# · USAGE
#
#   extractPublicArchive ARCHIVE
#
#   ARCHIVE  Path to the .valt archive file.

extractPublicArchive() {
    assertFile "$1"
    local privateArchive="$1"
    local publicArchive="${privateArchive}.pub"
    local tmpDir; tmpDir="${ makeTempDir; }"
    tar xJf "${privateArchive}" -C "${tmpDir}" "${_archivePubFiles[@]}" || fail
    tar cJ -C "${tmpDir}" "${_archivePubFiles[@]}" > "${publicArchive}" || fail
}



PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'valt/archive' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"


_init_valt_archive() {
    require 'valt/keys' 'valt/password' 'valt/decrypt' 'valt/sign' 'rayvn/prompt'

    #   backup-2026-05-28_23.14_PDT.valt
    #   │
    #   ├── encrypted.tar.xz.age              _archiveEncryptedName
    #   │   ├── payload.tar                   _archivePayloadName
    #   │   ├── payload.tar.minisign          _archivePayloadSigName
    #   │   ├── minisign.pub                  _archiveSigPubName
    #   │   ├── age.pub                       _archiveAgePubName
    #   │   └── README.txt                    _archiveReadMeName
    #   ├── encrypted.tar.xz.age.minisign     _archiveEncryptedSigName
    #   ├── minisign.pub                      _archiveSigPubName
    #   ├── age.pub                           _archiveAgePubName
    #   └── README.txt                        _archiveReadMeName

    #   backup-2026-05-28_23.14_PDT.valt.pub
    #   │
    #   ├── encrypted.tar.age.minisign        _archiveEncryptedSigName
    #   ├── minisign.pub                      _archiveSigPubName
    #   ├── age.pub                           _archiveAgePubName
    #   └── README.txt                        _archiveReadMeName

    # File names

    declare -gr _archiveAgePubName="age.pub"
    declare -gr _archiveSigPubName="minisign.pub"
    declare -gr _archiveReadMeName="README.txt"

    declare -gr _archivePayloadName="payload.tar"
    declare -gr _archivePayloadSigName="${_archivePayloadName}.${_signatureFileSuffix}"

    declare -gr _archiveEncryptedName="encrypted.${_tarFileExtension}.${_ageFileExtension}"
    declare -gr _archiveEncryptedSigName="${_archiveEncryptedName}.${_signatureFileSuffix}"

    # File name lists

    declare -gr _archiveEncryptedFiles=("${_archivePayloadName}" "${_archivePayloadSigName}" "${_archiveAgePubName}" \
                                        "${_archiveSigPubName}" "${_archiveReadMeName}")

    declare -gr _archiveFiles=("${_archiveEncryptedName}" "${_archiveEncryptedSigName}" "${_archiveAgePubName}" \
                               "${_archiveSigPubName}" "${_archiveReadMeName}")

    declare -gr _archivePubFiles=("${_archiveEncryptedSigName}" "${_archiveAgePubName}" "${_archiveSigPubName}" \
                                  "${_archiveReadMeName}")

    # Current archive version

    declare -gr _archiveVersion="1.0"
}

_publicReadMe() {
    _renderArchiveReadMe "archive-readme-public.tmpl" "$1" "$2" "$3"
}

_privateReadMe() {
    _renderArchiveReadMe "archive-readme-private.tmpl" "$1" "$2" "$3"
}

_renderArchiveReadMe() {
    local templateName="$1"
    local outputFile="$2"
    local archiveName="$3"
    local userText="$4"

    local template; readFile "${valtHome}/etc/${templateName}" template

    local valtVersion; valtVersion=${ gawk -F"'" '/^projectVersion=/{print $2}' "${valtHome}/rayvn.pkg"; }
    local ageVersion; ageVersion=${ age --version 2>&1 | gsed 's/^v//'; }
    local minisignVersion; minisignVersion=${ minisign -v 2>&1 | gawk '{print $2}'; }
    local created; created="${ TZ=UTC date '+%Y-%m-%d %H:%M:%S UTC'; }"
    local author; author="${USER}@${ hostname -s; }"

    local notesSection=''
    if [[ -n ${userText} ]]; then
        local divider='───────────────────────────────────────────────────────────────────────────────────────────────────'
        userText="${userText//\\n/$'\n'}"
        notesSection=$'\n▋ Notes\n'"${divider}"$'\n\n'"${userText}"$'\n'
    fi

    local substitutions=(
        "ARCHIVE_NAME:${archiveName}"
        "CREATED:${created}"
        "AUTHOR:${author}"
        "VALT_VERSION:${valtVersion}"
        "AGE_VERSION:${ageVersion}"
        "MINISIGN_VERSION:${minisignVersion}"
        "NOTES_SECTION:${notesSection}"
        "ENCRYPTED_NAME:${_archiveEncryptedName}"
        "ENCRYPTED_SIG_NAME:${_archiveEncryptedSigName}"
        "PAYLOAD_NAME:${_archivePayloadName}"
        "PAYLOAD_SIG_NAME:${_archivePayloadSigName}"
    )

    local key value entry
    for entry in "${substitutions[@]}"; do
        key="${entry%%:*}"
        value="${entry#*:}"
        template="${template//\$\{${key}\}/${value}}"
    done

    printf '%s\n' "${template}" > "${outputFile}"
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



