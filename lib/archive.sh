#!/usr/bin/env bash

# Secure archives.
# Use via: require 'valt/archive'

#@notes
# ## Secure Archives
#
# A secure archive (a `.valt` file) holds any number of files and directories, encrypted with age to one or more
# recipients and signed with minisign. Encryption keeps the contents private; the signatures prove who made it and that
# nothing has changed since. So an archive can be stored somewhere less trusted, such as cloud storage or a shared NAS;
# corruption or tampering is detected with confidence; and it gives a provenance chain, e.g. for legal or financial
# documents.
#
# It is a tar file. The files are packed in a payload, which is signed, then encrypted together with the signature, a
# signed manifest (see Manifests below), the public keys and a README; the encrypted file is signed again, and kept next
# to its signature, the public keys and a README with instructions for anyone opening it:
#
#     backup-2026-05-28_23.14_PDT.valt
#     │
#     ├── encrypted.tar.xz.age
#     │   ├── payload.tar
#     │   ├── payload.tar.minisig
#     │   ├── manifest.json
#     │   ├── manifest.json.minisig
#     │   ├── minisign.pub
#     │   ├── age.pub
#     │   └── README.txt
#     ├── encrypted.tar.xz.age.minisig
#     ├── minisign.pub
#     ├── age.pub
#     └── README.txt
#
# The signature inside the encryption means there is always a valid payload signature to check, even if the outer one is
# missing or has been tampered with.
#
# The unencrypted parts can be shared publicly, as a separate *public companion* (`.valt.pub`), which shows who made the
# archive and lets anyone check its outer signature without being able to open it:
#
#     backup-2026-05-28_23.14_PDT.valt.pub
#     │
#     ├── encrypted.tar.xz.age.minisig
#     ├── minisign.pub
#     ├── age.pub
#     └── README.txt
#
# `valt archive create` makes both; a missing public companion can be recreated from the archive (extractPublicArchive).
#
# Opening an archive needs only tar, age and minisign, as its README explains; `valt decrypt` (or `valt archive
# extract`) verifies both signatures and extracts it in one step, and `valt archive verify` checks it without
# extracting.
#
# ### Manifests
#
# Every archive has a manifest (`manifest.json`, inside the encryption and signed) saying what it is, with the valt and
# archive format versions it was made with; by default, a valt secure archive:
#
#     { "kind": "valt secure archive", "tool": "valt", "version": "0.3.0", "valtVersion": "0.3.0", "archiveVersion": "1.0" }
#
# An archive made by another program, e.g. a wardn vault backup, can give its own, saying what it is and how to restore
# it (valt adds the versions): restoring a vault backup means importing it with wardn, not extracting the vault's
# unencrypted export. For example:
#
#     {
#       "kind": "wardn vault backup",
#       "tool": "wardn",
#       "version": "0.2.0",
#       "extract": "discouraged",
#       "restore": {
#         "args": ["restore", "{archive}", "-i", "{identity}"],
#         "nix": "github:phoggy/wardn/v0.2.0#restore",
#         "brew": "rayvn-central/tap/wardn"
#       }
#     }
#
# Before extracting, `valt decrypt` says what the archive is and offers to restore it with the program, in whichever
# ways this computer can: the program if it is installed, Nix (running the pinned release without installing it), or
# Homebrew (installing it first). It extracts the files only if asked to (`--extract`), and warns when the manifest
# discourages it. Nothing in the archive is run: the manifest only names a published program. Like the rest of the
# archive, it is only accepted when signed by the key that decrypts it. The archive's README gives the same commands.
#
# ### Included files
#
# An archive can include other encrypted files, still encrypted: secure archives (`.valt`) and files encrypted with
# `valt encrypt` (`.age`, with its `.age.minisig` signature), e.g. a wardn vault backup can carry an export of an
# authenticator app's tokens, so that everything needed to recover is in one place. They are added under `included/`,
# listed in the manifest (`included`: each file's path, type and modification time) and in the README, and opened
# with `valt decrypt` like any other.
#
# The one rule: an included file must be signed by, and openable with, the archive's key (other recipients are fine).
# So the key that opens the archive opens everything in it, and a file someone else made cannot be slipped in: a
# public key is public, so anyone can encrypt to it, but only its owner can sign. A file that breaks the rule fails
# the archive, rather than being left out unnoticed.
#
# A file can have a note: plain text in a file of the same name plus `.note` (e.g. `tokens.age.note`), saying what it
# is and how to recover from it, e.g. how to import the tokens and where to find the export's password. The note is
# included with it, and shown in the README, by `valt decrypt` when it extracts the archive, and by programs that
# restore it (see showIncludedFiles). It is inside the encrypted part, but should still never hold a secret itself.
#@end

# ◇ Create an encrypted, signed archive from one or more files, directories and archives. The archive file path is written to
#   standard output. Also creates the public version of the archive (same path plus ".pub" suffix) unless --no-public. See
#   Secure Archives below for details.
#
# · USAGE
#
#   newSecureArchive ([-C DIR] INPUT...) -i PATH (-r RECIPIENT | -R PATH)... [-f] [-n NAME] [-z ZONE] [-u TEXT] [-o DIR]
#                    [-m PATH] [--include PATH]... [--include-max-age DAYS] [--no-mac-metadata] [--no-public]
#
#   -i, --identity PATH        The valt private key file used to sign the archive.
#   -r, --recipient RECIPIENT  Encrypt to the specified RECIPIENT. See the recipient() function in 'valt/keys'.
#   -R, --recipient-file PATH  Encrypt to one or more recipients. PATH can be a valt key or contain a list of recipients (see the
#                              newRecipientsFile() function in 'valt/keys'). Valt private key files require passphrase input
#                              for decryption. Can be repeated.
#   -f, --force                Overwrite any existing output file (default: fail).
#   -n, --name NAME            Specify the archive file name prefix (default: ${USER}).
#   -z, --zone ZONE            The time zone for the timestamp in the name: 'local' (the system time zone), 'UTC', or a
#                              zone name such as 'America/Los_Angeles' (default: local).
#   -u, --user-text TEXT       User text to include in readme. Can contain '\n'.
#   -o, --output-dir DIR       Specify the archive destination directory path (default: ${PWD}).
#   -m, --manifest PATH        A manifest (JSON) saying what the archive is and how to restore it, for an archive made
#                              by another program, e.g. a wardn vault backup (default: one saying that it is a valt
#                              secure archive). See Manifests below.
#   --include PATH             Include an encrypted file, still encrypted: a secure archive (.valt), or a file
#                              encrypted with valt encrypt (.age, next to its .age.minisig); or every such file in a
#                              directory (not its subdirectories). Each must be signed by, and openable with, the -i
#                              key, or the archive is not created. A FILE.note next to one is included as its note.
#                              See Included files below. Can be repeated.
#   --include-max-age DAYS     Warn about included files last modified more than DAYS days ago (default: no warning).
#   --no-mac-metadata          Do not keep the macOS metadata (extended attributes such as Finder tags, ACLs and file
#                              flags) of the INPUT files. It is kept by default, but only macOS tar restores it; other
#                              tars may warn about it. Metadata is never kept for the archive's own files.
#   --no-public                Do not create the public companion (ARCHIVE.pub).
#   -C DIR                     Change to the specified directory before processing the remaining relative INPUT paths.
#   INPUT...                   File, directory or @<archive> paths to add. An '@' prefixed file path is treated as a tar archive
#                              whose contents should be extracted and added.
#
# · EXAMPLE
#
#   newSecureArchive project/ -R bob.pub                                  # archive project/ dir to ${USER}.valt in ${PWD}
#   newSecureArchive project/ -R bob.pub -n backup -t -o ~/backups        # timestamped name, written to ~/backups
#   newSecureArchive -C ~/dev/ projectX foo.txt -R bob.pub                # -C sets source root ~/dev/ and adds subsequent inputs
#   newSecureArchive -C ~/dev/ projectX -C ~/docs/ notes.txt -R bob.pub   # each -C sets a new source root for subsequent inputs

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
    local timeZoneName='local'
    local force=0
    local userReadmeText
    local currentDir="${PWD}"
    local stripMetadata=0
    local createPublic=1
    local manifestFile=''
    local -a includeFiles=()
    local includeMaxAge=0

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
            -m | --manifest) shift; _assertArchiveManifest "$1"; manifestFile="$1" ;;
            --include) shift; _addArchiveIncludes "$1" includeFiles ;;
            --include-max-age) shift; [[ $1 =~ ^[0-9]+$ ]] || invalidArgs "--include-max-age: not a number of days: $1"
                               includeMaxAge=$1 ;;
            --no-mac-metadata) stripMetadata=1 ;;
            --no-public) createPublic=0 ;;
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
    assertCompatibleRecipients "${encryptArgs[@]}"
    (( ${#inputPaths[@]} )) || invalidArgs "one or more files required"

    # Check output file conflict

    local archiveName="${name}.valt"
    local archivePubName="${archiveName}.pub"
    local archiveFile="${destDir}/${archiveName}"
    local archivePubFile="${destDir}/${archivePubName}"

    if (( createPublic )); then
        _checkOutputConflict ${force} "${archiveFile}" "${archivePubFile}"
    else
        _checkOutputConflict ${force} "${archiveFile}"
    fi

    # Create secure work dir sized to hold payload.tar + encrypted.tar simultaneously (2× input)

    local inputSizeMb; inputSizeMb=${ du -sm "${inputPaths[@]}" 2> /dev/null | gawk '{sum += $1} END {print int(sum) + 1}'; }
    if (( ${#includeFiles[@]} )); then # copied into the work dir too, so counted again
        local includeSizeMb; includeSizeMb=${ du -sm "${includeFiles[@]}" | gawk '{sum += $1} END {print int(sum) + 1}'; }
        (( inputSizeMb += includeSizeMb * 2 ))
    fi
    local workDir isRamBacked
    makeSecureTempDir workDir isRamBacked $(( inputSizeMb * 2 + 64 ))
    if (( ! isRamBacked )); then
        local choice
        warn "Could not create secure RAM backed temp storage."
        show "   On disk temporary files will be deleted on exit, but this is not quite as secure as RAM." nl >&${ttyFd}
        confirm "Do you want to continue?" no yes choice || bye
        (( choice == 0 )) && bye
    fi

    # Since we will do multiple operations that require decrypting the private key, prepare for it once. Shadow with a local
    # variable so that it will go out of scope when we exit.

    local rayvnTest_ValtKeyPassphrase="${rayvnTest_ValtKeyPassphrase}"
    _prepareKey "${privateKey}"

    # Create the age.pub file

    recipient "${privateKey}" > "${workDir}/${_archiveAgePubName}" || fail

    # Create the minisign.pub file

    local tempFile
    publicSigningKeyToTempFile "${privateKey}" tempFile || fail
    assertFile "${tempFile}"
    mv "${tempFile}" "${workDir}/${_archiveSigPubName}" || fail

    # Check and copy the included files (see Included files), before anything is written that depends on them

    local -a includedEntries=()
    if (( ${#includeFiles[@]} )); then
        _addIncludedFiles "${privateKey}" "${workDir}" ${includeMaxAge} includeFiles includedEntries
        tarArgs+=(-C "${workDir}" "${_archiveIncludedDirName}")
    fi

    # Write the manifest and sign it: the one given, or a default saying that this is a valt secure archive, either way
    # with the valt and archive format versions it was made with

    local valtVersion; valtVersion=${ gawk -F"'" '/^projectVersion=/{print $2}' "${valtHome}/rayvn.pkg"; }
    local versions='{valtVersion: $valtVersion, archiveVersion: $archiveVersion}'
    if [[ -n ${manifestFile} ]]; then
        jq --arg valtVersion "${valtVersion}" --arg archiveVersion "${_archiveVersion}" ". + ${versions}" \
           "${manifestFile}" > "${workDir}/${_archiveManifestName}" || fail
    else
        jq -n --arg valtVersion "${valtVersion}" --arg archiveVersion "${_archiveVersion}" \
           "{kind: \"valt secure archive\", tool: \"valt\", version: \$valtVersion} + ${versions}" \
           > "${workDir}/${_archiveManifestName}" || fail
    fi
    if (( ${#includedEntries[@]} )); then
        local withIncluded="${workDir}/${_archiveManifestName}.new"
        jq --slurpfile included <(printf '%s\n' "${includedEntries[@]}") '. + {included: $included}' \
           "${workDir}/${_archiveManifestName}" > "${withIncluded}" || fail
        mv "${withIncluded}" "${workDir}/${_archiveManifestName}" || fail
    fi
    signFile "${privateKey}" "${workDir}/${_archiveManifestName}" || fail

    # Create the private README file (the public one does not list the included files)

    _privateReadMe "${workDir}/${_archiveReadMeName}" "${archiveName}" "${userReadmeText}" "${timestamp}" \
                   "${manifestFile}" "${workDir}/${_archiveManifestName}"

    # Create the payload file and sign it

    _tarCreate ${stripMetadata} "${tarArgs[@]}" > "${workDir}/${_archivePayloadName}" || fail
    signFile "${privateKey}" "${workDir}/${_archivePayloadName}" || fail

    # Create the encrypted tar and sign it

    _tarCreate 1 -C "${workDir}" "${_archiveEncryptedFiles[@]}" | encrypt "${encryptArgs[@]}" -o "${workDir}/${_archiveEncryptedName}" || fail
    signFile "${privateKey}" "${workDir}/${_archiveEncryptedName}" || fail

    # Remove the payload files so we only have the encrypted forms

    rm -f "${workDir}/${_archivePayloadName}" "${workDir}/${_archivePayloadSigName}" "${workDir}/${_archiveManifestName}" \
          "${workDir}/${_archiveManifestSigName}" || fail

    # Create the public README file (overwrites the private one already in the encrypted tar)

    _publicReadMe "${workDir}/${_archiveReadMeName}" "${archiveName}" "${userReadmeText}" "${timestamp}" "${manifestFile}"

    # Create the archive files

    _tarCreate 1 -C "${workDir}" "${_archiveFiles[@]}" > ${archiveFile} || fail
    if (( createPublic )); then
        _tarCreate 1 -C "${workDir}" "${_archivePubFiles[@]}" > ${archivePubFile} || fail
    fi

    # Finally, return the archive file name via stdout

    echo "${archiveFile}"
}

# ◇ Verify the signatures of a secure archive. Checks both the outer encrypted archive signature
#   and the inner payload signature (requires decryption with the private key), and the manifest's, if any.
#
# · USAGE
#
#   verifySecureArchive ARCHIVE -i PATH [--manifest-handler FN]
#
#   ARCHIVE                Path to the .valt archive file.
#   -i, --identity PATH    The valt private key file used to decrypt and verify signatures.
#   --manifest-handler FN  A function to call with the path of the archive's verified manifest, if it has one.

verifySecureArchive() {
    local archiveFile keyFile manifestHandler=''

    while (( $# )); do
        case "$1" in
            -i | --identity) shift; _assertValtKey "$1"; keyFile="$1" ;;
            --manifest-handler) shift; manifestHandler="$1" ;;
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

    # Verifying each signature and decrypting all decrypt the private key, so ask for its passphrase once, before the
    # first. Shadow with a local variable so that it will go out of scope when we exit.

    local rayvnTest_ValtKeyPassphrase="${rayvnTest_ValtKeyPassphrase}"
    _prepareKey "${keyFile}"

    # Verify outer signature

    verifyFileSignature "${keyFile}" "${outerDir}/${_archiveEncryptedName}" \
                        "${outerDir}/${_archiveEncryptedSigName}"

    # Decrypt and expand inner archive to a secure temp dir

    local innerDir; _makeInnerDir "${archiveFile}" innerDir
    decrypt -i "${keyFile}" -o "${innerDir}/decrypted.tar.xz" "${outerDir}/${_archiveEncryptedName}" || fail
    tar xJf "${innerDir}/decrypted.tar.xz" -C "${innerDir}" || fail

    # Verify inner payload signature, and the manifest's

    verifyFileSignature "${keyFile}" "${innerDir}/${_archivePayloadName}" \
                        "${innerDir}/${_archivePayloadSigName}"
    _verifyArchiveManifest "${keyFile}" "${innerDir}"
    [[ -n ${manifestHandler} && -f ${innerDir}/${_archiveManifestName} ]] &&
        "${manifestHandler}" "${innerDir}/${_archiveManifestName}"
    return 0
}

# ◇ Verify and extract the contents of a secure archive into a directory.
#   Checks both the outer and inner signatures before decrypting and extracting the payload.
#
# · USAGE
#
#   extractSecureArchive -i PATH [-o DIR] [--manifest-handler FN] ARCHIVE
#
#   ARCHIVE (file)               The secure archive file to extract.
#   -i, --identity PATH (file)   The valt key file used to decrypt and verify signatures.
#   -o, --output-dir DIR (dir)   Directory to extract contents into (default: ${PWD}).
#   --manifest-handler FN        A function to call with the path of the archive's verified manifest, if it has one
#                                (see Manifests below), before extracting: extracting goes ahead only if it succeeds.

extractSecureArchive() {
    local archiveFile keyFile destDir="${PWD}" manifestHandler=''

    while (( $# )); do
        case "$1" in
            -i | --identity) shift; _assertValtKey "$1"; keyFile="$1" ;;
            --manifest-handler) shift; manifestHandler="$1" ;;
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

    # Verifying each signature and decrypting all decrypt the private key, so ask for its passphrase once, before the
    # first. Shadow with a local variable so that it will go out of scope when we exit.

    local rayvnTest_ValtKeyPassphrase="${rayvnTest_ValtKeyPassphrase}"
    _prepareKey "${keyFile}"

    # Verify outer signature

    verifyFileSignature "${keyFile}" "${outerDir}/${_archiveEncryptedName}" \
                        "${outerDir}/${_archiveEncryptedSigName}"

    # Decrypt and expand inner archive to a secure temp dir

    local innerDir; _makeInnerDir "${archiveFile}" innerDir
    decrypt -i "${keyFile}" -o "${innerDir}/decrypted.tar.xz" "${outerDir}/${_archiveEncryptedName}" || fail
    tar xJf "${innerDir}/decrypted.tar.xz" -C "${innerDir}" || fail

    # Verify inner payload signature, and the manifest's

    verifyFileSignature "${keyFile}" "${innerDir}/${_archivePayloadName}" \
                        "${innerDir}/${_archivePayloadSigName}"
    _verifyArchiveManifest "${keyFile}" "${innerDir}"

    # A manifest handler decides whether to extract, e.g. restoring with the program that made the archive instead

    if [[ -n ${manifestHandler} && -f ${innerDir}/${_archiveManifestName} ]]; then
        "${manifestHandler}" "${innerDir}/${_archiveManifestName}" || return 0
    fi

    # Extract payload to destination

    tar xJf "${innerDir}/${_archivePayloadName}" -C "${destDir}" || fail
}

# ◇ Extracts the public portion of a secure archive, writing ARCHIVE.pub (e.g. NAME.valt.pub) alongside it. It holds
#   the signature, public keys and README but not the encrypted payload, so is safe to share publicly. Useful when the
#   .pub file was not kept from creation.
#
# · ARGS
#
#   archive (file)  Path to the secure archive (.valt) file.

extractPublicArchive() {
    assertFile "$1"
    local privateArchive="$1"
    local publicArchive="${privateArchive}.pub"
    local tmpDir; tmpDir="${ makeTempDir; }"
    tar xJf "${privateArchive}" -C "${tmpDir}" "${_archivePubFiles[@]}" || fail
    _tarCreate 1 -C "${tmpDir}" "${_archivePubFiles[@]}" > "${publicArchive}" || fail
}


# ◇ Set the named array to the ways an archive's manifest offers to restore it that are available here, in order of
#   preference: 'installed' (its program is on the PATH), 'nix' (with Nix, running the program's pinned release without
#   installing it) and 'brew' (with Homebrew, installing the program first). Empty if it offers none, or none of them is
#   available.
#
# · ARGS
#
#   manifestFile (file)       The archive's manifest (see Manifests in the notes).
#   pathwaysRef (arrayRef)    Name of the array to set.
#
# · ENV VARS
#
#   rayvnTest_ArchiveCommands  Test hook: the commands to treat as available, separated by spaces, instead of looking
#                              them up on the PATH.

archiveRestorePathways() {
    local manifestFile="$1"
    local -n _arpPathwaysRef=$2
    _arpPathwaysRef=()
    [[ -n ${ jq -r '.restore // empty' "${manifestFile}"; } ]] || return 0
    local tool; tool="${ jq -r '.tool' "${manifestFile}"; }"
    local installed=0
    _archiveCommandAvailable "${tool}" && { installed=1; _arpPathwaysRef+=(installed); }
    [[ -n ${ jq -r '.restore.nix // empty' "${manifestFile}"; } ]] && _archiveCommandAvailable nix && _arpPathwaysRef+=(nix)
    (( installed )) || { [[ -n ${ jq -r '.restore.brew // empty' "${manifestFile}"; } ]] && _archiveCommandAvailable brew &&
                         _arpPathwaysRef+=(brew); }
    return 0
}

# ◇ Restore an archive the way its manifest says, by one of the ways archiveRestorePathways lists. Returns the
#   restoring program's status.
#
# · ARGS
#
#   manifestFile (file)  The archive's manifest.
#   pathway (string)     'installed', 'nix' or 'brew' (for a formula from a third-party tap, taps and trusts the
#                        tap first).
#   archiveFile (file)   The archive to restore.
#   keyFile (file)       The private key file to restore it with.

runArchiveRestore() {
    local manifestFile="$1" pathway="$2" archiveFile="$3" keyFile="$4"
    local -a args=()
    _archiveRestoreArgs "${manifestFile}" "${archiveFile}" "${keyFile}" args
    local tool; tool="${ jq -r '.tool' "${manifestFile}"; }"
    case ${pathway} in
        installed) "${tool}" "${args[@]}" ;;
        nix) nix run "${ jq -r '.restore.nix' "${manifestFile}"; }" -- "${args[@]}" ;;
        brew)
            local formula; formula="${ jq -r '.restore.brew' "${manifestFile}"; }"
            local tap; tap="${ _archiveBrewTap "${formula}"; }"
            if [[ -n ${tap} ]]; then
                brew tap "${tap}" && brew trust --tap "${tap}" || return 1
            fi
            brew install "${formula}" && "${tool}" "${args[@]}"
            ;;
        *) fail "unknown restore pathway: ${pathway}" ;;
    esac
}

# ◇ Output the commands to restore an archive the way its manifest says, one way per paragraph (with the program
#   installed, with Nix, with Homebrew), whether or not each is available here. For a formula from a third-party tap,
#   the Homebrew commands tap and trust it first.
#
# · ARGS
#
#   manifestFile (file)  The archive's manifest.
#   archive (string)     The archive's path or name, as shown in the commands.
#   keyFile (string)     The private key file's path, or a placeholder such as '<private-key-file>'.
#   [indent] (int)       Spaces to indent by (default: 0).

showArchiveRestoreCommands() {
    local manifestFile="$1" archive="$2" keyFile="$3" indent="${4:-0}"
    local pad; pad="${ printf '%*s' "${indent}" ''; }"
    local -a args=()
    _archiveRestoreArgs "${manifestFile}" "${archive}" "${keyFile}" args
    local tool nix brew command
    tool="${ jq -r '.tool' "${manifestFile}"; }"
    nix="${ jq -r '.restore.nix // empty' "${manifestFile}"; }"
    brew="${ jq -r '.restore.brew // empty' "${manifestFile}"; }"
    command="${ printf '%s' "${tool}"; printf ' %s' "${args[@]}"; }"
    printf '%sWith %s installed:\n\n%s    %s\n' "${pad}" "${tool}" "${pad}" "${command}"
    [[ -n ${nix} ]] && printf '\n%sWith Nix, without installing it:\n\n%s    nix run %s --%s\n' "${pad}" "${pad}" "${nix}" \
        "${ printf ' %s' "${args[@]}"; }"
    if [[ -n ${brew} ]]; then
        local tap; tap="${ _archiveBrewTap "${brew}"; }"
        printf '\n%sWith Homebrew, installing it first:\n\n' "${pad}"
        [[ -n ${tap} ]] && printf '%s    brew tap %s\n%s    brew trust --tap %s\n' "${pad}" "${tap}" "${pad}" "${tap}"
        printf '%s    brew install %s\n%s    %s\n' "${pad}" "${brew}" "${pad}" "${command}"
    fi
    return 0
}

# ◇ Show the files an archive includes (see Included files), extracted to a directory: each one's name, followed by
#   its note, if it has one, then how to open them. Shows nothing if the directory has no included files.
#
# · ARGS
#
#   dir (dir)  The directory holding the included files, e.g. an extracted archive's included/.

showIncludedFiles() {
    local dir="$1"
    local -a files=()
    local file note line
    for file in "${dir}"/*.valt "${dir}"/*.age; do
        [[ -f ${file} ]] && files+=("${file}")
    done
    (( ${#files[@]} )) || return 0
    for file in "${files[@]}"; do
        show nl "   " bold "${file##*/}"
        if [[ -f ${file}.${_archiveNoteSuffix} ]]; then
            echo
            readFile "${file}.${_archiveNoteSuffix}" note
            while IFS= read -r line; do
                show "       " "${line}"
            done <<< "${note%$'\n'}"
            echo
        fi
    done
    show "Open each with" blue "valt decrypt FILE" glue ", following its note if it has one."
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'valt/archive' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"


_init_valt_archive() {
    require 'valt/keys' 'valt/password' 'valt/decrypt' 'valt/sign' 'rayvn/prompt'

    # macOS tar (bsdtar) records macOS metadata by default; GNU tar does not unless asked

    declare -gri _bsdTar=${ tar --version 2> /dev/null | grep -q bsdtar && echo 1 || echo 0; }

    # File names
    #
    #   backup-2026-05-28_23.14_PDT.valt
    #   │
    #   ├── encrypted.tar.xz.age              _archiveEncryptedName
    #   │   ├── payload.tar                   _archivePayloadName
    #   │   ├── payload.tar.minisig          _archivePayloadSigName
    #   │   ├── manifest.json                 _archiveManifestName (archives made by valt 0.2.0 and earlier have none)
    #   │   ├── manifest.json.minisig        _archiveManifestSigName
    #   │   ├── minisign.pub                  _archiveSigPubName
    #   │   ├── age.pub                       _archiveAgePubName
    #   │   └── README.txt                    _archiveReadMeName
    #   ├── encrypted.tar.xz.age.minisig     _archiveEncryptedSigName
    #   ├── minisign.pub                      _archiveSigPubName
    #   ├── age.pub                           _archiveAgePubName
    #   └── README.txt                        _archiveReadMeName

    #   backup-2026-05-28_23.14_PDT.valt.pub
    #   │
    #   ├── encrypted.tar.xz.age.minisig        _archiveEncryptedSigName
    #   ├── minisign.pub                      _archiveSigPubName
    #   ├── age.pub                           _archiveAgePubName
    #   └── README.txt                        _archiveReadMeName

    declare -gr _archiveAgePubName="age.pub"
    declare -gr _archiveSigPubName="minisign.pub"
    declare -gr _archiveReadMeName="README.txt"

    declare -gr _archivePayloadName="payload.tar"
    declare -gr _archivePayloadSigName="${_archivePayloadName}.${_signatureFileSuffix}"

    declare -gr _archiveManifestName="manifest.json"
    declare -gr _archiveManifestSigName="${_archiveManifestName}.${_signatureFileSuffix}"

    declare -gr _archiveEncryptedName="encrypted.${_tarFileExtension}.${_ageFileExtension}"
    declare -gr _archiveEncryptedSigName="${_archiveEncryptedName}.${_signatureFileSuffix}"

    declare -gr _archiveIncludedDirName="included" # in the payload (see Included files)
    declare -gr _archiveNoteSuffix="note"          # an included file's note: FILE.note

    # File name lists

    declare -gr _archiveEncryptedFiles=("${_archivePayloadName}" "${_archivePayloadSigName}" "${_archiveManifestName}" \
                                        "${_archiveManifestSigName}" "${_archiveAgePubName}" "${_archiveSigPubName}" \
                                        "${_archiveReadMeName}")

    declare -gr _archiveFiles=("${_archiveEncryptedName}" "${_archiveEncryptedSigName}" "${_archiveAgePubName}" \
                               "${_archiveSigPubName}" "${_archiveReadMeName}")

    declare -gr _archivePubFiles=("${_archiveEncryptedSigName}" "${_archiveAgePubName}" "${_archiveSigPubName}" \
                                  "${_archiveReadMeName}")

    # Current archive version

    declare -gr _archiveVersion="1.0"
}

_publicReadMe() {
    _renderArchiveReadMe "archive-readme-public.tmpl" "$1" "$2" "$3" "$4" "${5:-}"
}

_privateReadMe() {
    _renderArchiveReadMe "archive-readme-private.tmpl" "$1" "$2" "$3" "$4" "${5:-}" "${6:-}"
}

_renderArchiveReadMe() {
    local templateName="$1"
    local outputFile="$2"
    local archiveName="$3"
    local userText="$4"
    local created="$5"
    local manifestFile="${6:-}"
    local builtManifestFile="${7:-}" # the archive's own manifest, which lists any included files

    local template; readFile "${valtHome}/etc/${templateName}" template

    local valtVersion; valtVersion=${ gawk -F"'" '/^projectVersion=/{print $2}' "${valtHome}/rayvn.pkg"; }
    local ageVersion; ageVersion=${ age --version 2>&1 | gsed 's/^v//'; }
    local minisignVersion; minisignVersion=${ minisign -v 2>&1 | gawk '{print $2}'; }
    local author; author="${USER}@${ hostname -s; }"

    local notesSection=''
    if [[ -n ${userText} ]]; then
        local divider='───────────────────────────────────────────────────────────────────────────────────────────────────'
        userText="${userText//\\n/$'\n'}"
        notesSection=$'\n▋ Notes\n'"${divider}"$'\n\n'"${userText}"$'\n'
    fi

    # How to restore an archive made by another program, from its manifest

    local restoreSection=''
    if [[ -n ${manifestFile} ]]; then
        local divider='───────────────────────────────────────────────────────────────────────────────────────────────────'
        local about; about="${ _archiveManifestAbout "${manifestFile}"; }"
        restoreSection=$'\n▋ Restore\n'"${divider}"$'\n\n'"  This archive is ${about}."
        if [[ -n ${ jq -r '.restore // empty' "${manifestFile}"; } ]]; then
            restoreSection+=$'\n'"  Rather than extracting its files, restore it, in any of these ways:"$'\n\n'
            restoreSection+="${ showArchiveRestoreCommands "${manifestFile}" "${archiveName}" '<private-key-file>' 2; }"$'\n'
            restoreSection+=$'\n'"  valt decrypt ${archiveName} offers whichever of these this computer can do."
        fi
        restoreSection+=$'\n'
    fi

    # The included files, if any (see Included files)

    local includedSection=''
    if [[ -n ${builtManifestFile} ]] && jq -e '.included // [] | length > 0' "${builtManifestFile}" > /dev/null; then
        local divider='───────────────────────────────────────────────────────────────────────────────────────────────────'
        includedSection=$'\n▋ Included\n'"${divider}"$'\n\n'
        includedSection+="  This archive includes encrypted files, made with the same key, in ${_archiveIncludedDirName}/. They"
        includedSection+=$'\n'"  stay encrypted when it is extracted:"$'\n\n'
        # Each file, then its note (if any) indented below it
        local listFiles='.included[] | "    \(.path)  (\(.type), modified \(.modified[0:10]))"'
        listFiles+=' + if .note then "\n\n" + (.note | split("\n") | map("        " + . | rtrimstr(" ")) | join("\n"))'
        listFiles+=' + "\n" else "" end'
        includedSection+="${ jq -r "${listFiles}" "${builtManifestFile}"; }"$'\n\n'
        includedSection+="  Open each one with the same key, following its note if it has one, e.g.:"$'\n\n'
        includedSection+="    valt decrypt ${ jq -r '.included[0].path' "${builtManifestFile}"; } -i <private-key-file>"$'\n'
    fi

    # Recovery with Nix: pinned to the valt release current now, with the latest version as the fallback

    local latest="    nix run github:phoggy/valt#recover -- decrypt ${archiveName} -i <private-key-file>"
    local recoverCommands releaseTag; releaseTag="${ valtReleaseTag; }"
    if [[ -n ${releaseTag} ]]; then
        recoverCommands="  With the valt release current when this archive was made:"$'\n\n'
        recoverCommands+="    nix run github:phoggy/valt/${releaseTag}#recover -- decrypt ${archiveName} -i <private-key-file>"$'\n\n'
        recoverCommands+="  If that fails, with the latest version:"$'\n\n'"${latest}"
    else
        recoverCommands="${latest}"
    fi

    local substitutions=(
        "ARCHIVE_NAME:${archiveName}"
        "RECOVER_COMMANDS:${recoverCommands}"
        "CREATED:${created}"
        "AUTHOR:${author}"
        "VALT_VERSION:${valtVersion}"
        "AGE_VERSION:${ageVersion}"
        "MINISIGN_VERSION:${minisignVersion}"
        "NOTES_SECTION:${notesSection}"
        "RESTORE_SECTION:${restoreSection}"
        "INCLUDED_SECTION:${includedSection}"
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

# Fails unless a file is a valid archive manifest: a JSON object with a kind, an optional extract of 'allowed' (the
# default) or 'discouraged', and, to offer restoring, a tool (a command name), restore.args (strings, in which
# {archive} and {identity} are replaced) and, optionally, restore.nix (a flake app) and restore.brew (a formula).
_assertArchiveManifest() {
    local manifestFile="$1"
    assertFile "${manifestFile}" "manifest file"
    # lint-skip-start (jq program)
    jq -e '
        def text: type == "string" and length > 0;
        type == "object" and (.kind | text)
        and ((.extract // "allowed") | . == "allowed" or . == "discouraged")
        and (if has("restore") then
                (.tool | text and test("^[A-Za-z0-9][A-Za-z0-9._-]*$"))
                and (.restore.args | type == "array" and all(type == "string"))
                and ((.restore.nix // "x") | text) and ((.restore.brew // "x") | text)
             else true end)
    ' "${manifestFile}" > /dev/null 2>&1 || invalidArgs "${manifestFile} is not a valid archive manifest"
    # lint-skip-end
}

# Verifies the manifest in an archive's decrypted inner dir against its signature, if there is a manifest.
_verifyArchiveManifest() {
    local keyFile="$1" innerDir="$2"
    [[ -f ${innerDir}/${_archiveManifestName} ]] || return 0
    verifyFileSignature "${keyFile}" "${innerDir}/${_archiveManifestName}" "${innerDir}/${_archiveManifestSigName}"
}

# Outputs what a manifest says the archive is, e.g. 'a wardn vault backup, made with wardn 0.2.0'.
_archiveManifestAbout() {
    jq -r '"a \(.kind)" + (if .tool then ", made with \(.tool)" + (if .version then " \(.version)" else "" end) else "" end)' "$1"
}

# Sets the named array to a manifest's restore args, with {archive} and {identity} replaced.
_archiveRestoreArgs() {
    local manifestFile="$1" archive="$2" keyFile="$3"
    local -n _araArgsRef=$4
    mapfile -t _araArgsRef < <(jq -r --arg archive "${archive}" --arg identity "${keyFile}" \
        '.restore.args[] | gsub("\\{archive\\}"; $archive) | gsub("\\{identity\\}"; $identity)' "${manifestFile}")
}

# Outputs the tap of a Homebrew formula named by its full name (user/tap/formula), or nothing for a formula from
# Homebrew's own tap. A third-party tap must be trusted before installing from it: since Homebrew 7, installing a
# formula by its full name trusts only that formula, so its dependencies from the same tap (e.g. wardn's rayvn and
# valt) are refused.
_archiveBrewTap() {
    [[ $1 == */*/* ]] && echo "${1%/*}"
    return 0
}

# Adds an --include PATH to the named array: the file, or every .valt and .age file in the directory, sorted (not
# hidden files, nor those in subdirectories). Warns when a directory has none, or several archives with the same name.

_addArchiveIncludes() {
    local path="$1"
    local -n _aaiFilesRef=$2
    if [[ -d ${path} ]]; then
        local -a found=()
        local file
        for file in "${path%/}"/*; do
            [[ -f ${file} && ( ${file} == *.valt || ${file} == *.age ) ]] && found+=("${file}")
        done
        (( ${#found[@]} )) || warn "--include: no .valt or .age files in ${ tildePath "${path}"; }"
        _warnRepeatedArchiveNames found "${path}"
        for file in "${found[@]}"; do
            _assertIncludeFile "${file}"
            _aaiFilesRef+=("${file}")
        done
    else
        _assertIncludeFile "${path}"
        _aaiFilesRef+=("${path}")
    fi
}

_assertIncludeFile() {
    local file="$1"
    local name; name="${ tildePath "${file}"; }"
    [[ -f ${file} ]] || invalidArgs "--include: not found: ${name}"
    case ${file} in
        *.valt) ;;
        *.age) [[ -f ${file}.${_signatureFileSuffix} ]] || invalidArgs "--include: ${name} has no signature" \
                   "(${name}.${_signatureFileSuffix}): encrypt it with valt encrypt, which signs it" ;;
        *) invalidArgs "--include: not a .valt or .age file: ${name}" ;;
    esac
}

# Warns about archives in an included directory that differ only in their timestamp: all are included, though only
# the newest is likely needed.

_warnRepeatedArchiveNames() {
    local -n _wranFilesRef=$1
    local dir="$2"
    local -A counts=()
    local file prefix
    for file in "${_wranFilesRef[@]}"; do
        [[ ${file##*/} =~ ^(.+)-[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9.]+_[^_]+\.valt$ ]] || continue
        prefix="${BASH_REMATCH[1]}"
        counts["${prefix}"]=$(( ${counts["${prefix}"]:-0} + 1 ))
    done
    for prefix in "${!counts[@]}"; do
        (( ${counts["${prefix}"]} > 1 )) && warn "--include: ${counts["${prefix}"]} archives named ${prefix}-* in" \
            "${ tildePath "${dir}"; }: all are included, but the older ones can probably be removed"
    done
    return 0
}

# Checks each included file (see Included files), failing on the first that breaks the rule, and copies it (and an
# .age file's signature) into the work dir's included directory, adding its manifest entry (JSON) to the named array.
# Says what is included, with how long ago each was modified, warning about any older than maxAge days (if not 0).

_addIncludedFiles() {
    local privateKey="$1" workDir="$2" maxAge=$3
    local -n _aifFilesRef=$4
    local -n _aifEntriesRef=$5
    local dir="${workDir}/${_archiveIncludedDirName}"
    local checkDir="${workDir}/include-check"
    mkdir "${dir}" || fail
    local signingPubFile; publicSigningKeyToTempFile "${privateKey}" signingPubFile || fail

    local file name base type epoch modified days ago with note
    local -a parts
    for file in "${_aifFilesRef[@]}"; do
        name="${ tildePath "${file}"; }"
        base="${file##*/}"
        [[ -e ${dir}/${base} ]] && fail "--include: more than one file is named ${base}"
        _checkIncludedFile "${file}" "${privateKey}" "${signingPubFile}" "${checkDir}"
        cp -p "${file}" "${dir}/" || fail
        parts=()
        if [[ ${file} == *.valt ]]; then
            type=valt
        else
            type=age
            parts+=(signature)
            cp -p "${file}.${_signatureFileSuffix}" "${dir}/" || fail
        fi
        note=''
        if [[ -f ${file}.${_archiveNoteSuffix} ]]; then
            readFile "${file}.${_archiveNoteSuffix}" note
            [[ -n ${note//[[:space:]]/} ]] || fail "--include: ${name}.${_archiveNoteSuffix} is empty"
            cp -p "${file}.${_archiveNoteSuffix}" "${dir}/" || fail
            parts+=(note)
        fi
        with="${parts[*]}"
        with="${with// / and }"
        with="${with:+with its ${with}}"

        epoch="${ _fileModifiedEpoch "${file}"; }"
        printf -v modified '%(%Y-%m-%dT%H:%M:%S%z)T' "${epoch}"
        _aifEntriesRef+=("${ jq -c -n --arg path "${_archiveIncludedDirName}/${base}" --arg type "${type}" \
            --arg modified "${modified}" --arg note "${note}" \
            '{path: $path, type: $type, modified: $modified} + (if $note == "" then {} else {note: $note} end)'; }")

        days=$(( (EPOCHSECONDS - epoch) / 86400 ))
        case ${days} in
            0) ago='today' ;;
            1) ago='1 day ago' ;;
            *) ago="${days} days ago" ;;
        esac
        if (( maxAge && days > maxAge )); then
            warn "Including ${name}${with:+ ${with}}, last modified ${ago} (more than ${maxAge} days): is it up to date?"
        else
            show "Including" bold "${name}" dim "(${with}${with:+, }modified ${ago})" >&2
        fi
    done
    rm -rf "${checkDir}" "${signingPubFile}"
}

# Fails unless a file to include is signed by, and openable with, the archive's key: for a secure archive, its
# encrypted part (whose outer signature anyone could check).

_checkIncludedFile() {
    local file="$1" privateKey="$2" signingPubFile="$3" checkDir="$4"
    local name; name="${ tildePath "${file}"; }"
    local keyName; keyName="${ tildePath "${privateKey}"; }"
    local rule="included files must be signed by, and openable with, the archive's key (${keyName})"
    local target="${file}" signature="${file}.${_signatureFileSuffix}"
    if [[ ${file} == *.valt ]]; then
        rm -rf "${checkDir}"
        mkdir "${checkDir}" || fail
        tar -xf "${file}" -C "${checkDir}" "${_archiveEncryptedName}" "${_archiveEncryptedSigName}" 2> /dev/null ||
            fail "--include: ${name} is not a valt secure archive"
        target="${checkDir}/${_archiveEncryptedName}"
        signature="${checkDir}/${_archiveEncryptedSigName}"
    fi
    minisign -V -q -p "${signingPubFile}" -x "${signature}" -m "${target}" > /dev/null 2>&1 ||
        fail "--include: ${name} is not signed by this key: ${rule}"
    _canDecryptWithKey "${privateKey}" "${target}" || fail "--include: ${name} cannot be opened with this key: ${rule}"
}

# Outputs a file's modification time, in epoch seconds (GNU stat, else BSD stat).

_fileModifiedEpoch() {
    stat -c %Y "$1" 2> /dev/null || stat -f %m "$1"
}

# Succeeds if a command is available: on the PATH, or listed in rayvnTest_ArchiveCommands when that is set.
_archiveCommandAvailable() {
    if [[ -v rayvnTest_ArchiveCommands ]]; then
        [[ " ${rayvnTest_ArchiveCommands} " == *" $1 "* ]]
    else
        command -v "$1" > /dev/null 2>&1
    fi
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

# Create an xz compressed tar archive (writing to stdout unless -f is in args), without macOS metadata (extended
# attributes, ACLs and file flags) if strip is 1. Only macOS tar (bsdtar) records it by default.
# Args: strip tarArgs...

_tarCreate() {
    local strip=$1; shift
    local -a metadataArgs=()
    if (( strip && _bsdTar )); then
        metadataArgs=(--no-xattrs --no-acls --no-fflags)
        (( onMacOS )) && metadataArgs+=(--no-mac-metadata)
    fi
    tar cJ "${metadataArgs[@]}" "$@"
}

# Output the size (MB) of secure temp storage needed to decrypt and expand an archive's inner archive: the decrypted
# inner archive, plus the (still compressed) payload and other files expanded from it.
# Args: archiveFile

_innerDirSizeMb() {
    local archiveMb; archiveMb=${ du -sm "$1" | gawk '{print $1}'; }
    echo $(( archiveMb * 2 + 64 ))
}

# Makes the secure temp dir that an archive's inner (decrypted) part is expanded in, setting the named var to its path,
# and warns if it is not RAM-backed (see makeSecureTempDir).

_makeInnerDir() {
    local archiveFile="$1"
    local -n _midDirRef=$2
    local isRamBacked
    makeSecureTempDir _midDirRef isRamBacked "${ _innerDirSizeMb "${archiveFile}"; }"
    (( isRamBacked )) || warn "Could not create secure RAM backed temp storage: the archive is decrypted in a temporary" \
        "directory on disk, deleted on exit, which is not quite as secure as RAM."
    return 0
}
