#!/usr/bin/env bash

# Encryption using age.
# Use via: require 'valt/encrypt'

# ◇ Encrypts a string to a file.
#
# · USAGE
#
#   encryptStringToFile [-r] content outputFile recipient...
#
#   -r                     Replace output file if it exists.
#   content (string)       The string content.
#   outputFile (string)    Path to the encrypted output file.
#   recipient (string...)  Path to a recipient valt key file. May be repeated for multiple recipients, any of which can decrypt
#                          with their valt private key. Private keys may be passed but require decryption so a passphrase will be
#                          requested for each.

encryptStringToFile() {
    _parseFullEncryptArgs "$@"
    echo "${_encryptSource}" | _encryptStdInToFile
}

# ◇ Encrypts a file to a file.
#
# · USAGE
#
#   encryptFileToFile [-r] inputFile outputFile recipient...
#
#   -r                     Replace output file if it exists.
#   inputFile (string)     Path to the input file to encrypt.
#   outputFile (string)    Path to the encrypted output file.
#   recipient (string...)  Path to a recipient valt key file. May be repeated for multiple recipients, any of which can decrypt
#                          with their valt private key. Private keys may be passed but require decryption so a passphrase will be
#                          requested for each.

encryptFileToFile() {
    _parseFullEncryptArgs "$@"
    assertFile "${_encryptSource}"
    cat "${_encryptSource}" | _encryptStdInToFile
}

# ◇ Encrypts a variable to a file.
#
# · USAGE
#
#   encryptVarToFile [-r] varName outputFile recipient...
#
#   -r                                    Replace output file if it exists.
#   varName (stringRef|arrayRef|fileRef)  Name of a variable containing a string, array or file path.
#   outputFile (string)                   Path to the encrypted output file.
#   recipient (string...)                 Path to a recipient valt key file. May be repeated for multiple recipients, any of
#                                         which can decrypt with their valt private key. Private keys may be passed but require
#                                         decryption so a passphrase will be requested for each.

encryptVarToFile() {
    _parseFullEncryptArgs "$@"
    [[ -v "${_encryptSource}" ]] || fail "'${_encryptSource}' is not a variable"

    local -n sourceRef="${_encryptSource}"
    local type; type="${ declare -p "${_encryptSource}" | cut -d' ' -f2; }"

    if [[ "${type}" == -A* ]]; then
        invalidArgs "map '${_encryptSource}' must be serialized to an array or string"
    elif [[ "${type}" == -a* ]]; then
        printf '%s\n' "${sourceRef}" | _encryptStdInToFile
    elif [[ -e "${sourceRef}" ]]; then
        cat "${sourceRef}" | _encryptStdInToFile
    else
        echo "${sourceRef}" | _encryptStdInToFile
    fi
}

# ◇ Encrypts stdin to a file.
#
# · USAGE
#
#   encryptToFile [-r] outputFile recipient...
#
#   -r                     Replace output file if it exists.
#   outputFile (string)    Path to the encrypted output file.
#   recipient (string...)  Path to a recipient valt key file. May be repeated for multiple recipients, any of which can decrypt
#                          with their valt private key. Private keys may be passed but require decryption so a passphrase will be
#                          requested for each.

encryptToFile() {
    [[ -t 0 ]] && fail "content must be piped to this function"
    read -t 0 || fail "no data in pipe"
    parseOptionalArg '-r' "$1" _encryptReplaceTargetFile 1 0 && shift
    _parseEncryptArgs - "${@}"
    _encryptStdInToFile
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'valt/encrypt' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_valt_encrypt() {
    require 'valt/keys'

    declare -g _encryptSource
    declare -g _encryptOutputFile
    declare -g _encryptReplaceTargetFile
    declare -ga _encryptRecipients
}

_parseFullEncryptArgs() {
    parseOptionalArg '-r' "$1" _encryptReplaceTargetFile 1 0 && shift
    _parseEncryptArgs "$@"
}

_parseEncryptArgs() {
    _encryptRecipients=()
    _encryptSource="$1"
    _encryptOutputFile="$2"
    local recipientFiles=("${@:3}")
    local keyFile recipient

    # Fail if output file exists and -r is not set

    if (( _encryptReplaceTargetFile == 0 )) && [[ -e "${_encryptOutputFile}" ]]; then
        fail "${_encryptOutputFile} is an existing file, pass -r to replace"
    fi

    # Fail if no recipients

    (( ${#recipientFiles[@]} )) || fail "one or more recipient key files required"

    # Convert all recipients keys

    for keyFile in "${recipientFiles[@]}"; do
        recipient="${ publicEncryptionKey "${keyFile}"; }"
        _encryptRecipients+=( '-r' "${recipient}" )
    done

    debugVar _encryptSource _encryptOutputFile _encryptRecipients
    debug
}

_encryptStdInToFile() {

    # Do we need a passphrase to decrypt the key?

    if [[ "${_encryptKeyFileType}" == "${valtPrivateKeySuffix}" ]]; then

        # Yes, get it

        local phraze passFd
        if [[ -n ${rayvnTest_ValtKeyPassphrase} ]]; then
            phraze="${rayvnTest_ValtKeyPassphrase}"
        else
            readVerifiedPassword phraze || fail
        fi

        # Feed the passphrase via a dynamically allocated fd using process substitution: printf exits after
        # writing, closing the write end of the pipe, so the batchpass plugin's io.ReadAll receives EOF
        # immediately and will not hang waiting for it. See plugin source at
        # https://github.com/FiloSottile/age/blob/main/cmd/age-plugin-batchpass/plugin-batchpass.go

        exec {passFd}< <(printf '%s' "${phraze}")
        debugVar passFd phraze

        # Encrypt stdin

        AGE_PASSPHRASE_FD="${passFd}" age "${_encryptRecipients[@]}" -e -j batchpass > "${_encryptOutputFile}" || bye

        # Close the fd

        exec {passFd}<&-
    else

        # Encrypt stdin

        AGE_PASSPHRASE_FD="${passFd}" age "${_encryptRecipients[@]}" -e > "${_encryptOutputFile}" || bye
    fi
}
