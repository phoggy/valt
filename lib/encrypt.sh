#!/usr/bin/env bash

# Encryption using age.
# Use via: require 'valt/encrypt'

# ◇ Encrypts a string to a file.
#
# · USAGE
#
#   encryptStringToFile [-r] content outputFile recipientKey...
#
#   -r                        Replace output file if it exists.
#   content (string)          The string content.
#   outputFile (string)       Path to the encrypted output file.
#   recipientKey (string...)  Path to a recipient valt key file. May be repeated for multiple recipients, any of which can decrypt
#                             with their valt private key. Private keys may be passed but require decryption so a passphrase will
#                             be requested for each.

encryptString() {
    _parseFullEncryptArgs "$@"
    echo "${_encryptSource}" | _encryptStdIn
}

# ◇ Encrypts a file to a file.
#
# · USAGE
#
#   encryptFileToFile [-r] inputFile outputFile recipientKey...
#
#   -r                        Replace output file if it exists.
#   inputFile (string)        Path to the input file to encrypt.
#   outputFile (string)       Path to the encrypted output file.
#   recipientKey (string...)  Path to a recipient valt key file. May be repeated for multiple recipients, any of which can decrypt
#                             with their valt private key. Private keys may be passed but require decryption so a passphrase will
#                             be requested for each.

encryptFile() {
    _parseFullEncryptArgs "$@"
    assertFile "${_encryptSource}"
    cat "${_encryptSource}" | _encryptStdIn
}

# ◇ Encrypts a variable to a file.
#
# · USAGE
#
#   encryptVarToFile [-r] varName outputFile recipientKey...
#
#   -r                                    Replace output file if it exists.
#   varName (stringRef|arrayRef|fileRef)  Name of a variable containing a string, array or file path.
#   outputFile (string)                   Path to the encrypted output file.
#   recipientKey (string...)              Path to a recipient valt key file. May be repeated for multiple recipients, any of
#                                         which can decrypt with their valt private key. Private keys may be passed but require
#                                         decryption so a passphrase will be requested for each.

encryptVar() {
    _parseFullEncryptArgs "$@"
    [[ -v "${_encryptSource}" ]] || fail "'${_encryptSource}' is not a variable"

    local -n sourceRef="${_encryptSource}"
    local type; type="${ declare -p "${_encryptSource}" | cut -d' ' -f2; }"

    if [[ "${type}" == -A* ]]; then
        invalidArgs "map '${_encryptSource}' must be serialized to an array or string"
    elif [[ "${type}" == -a* ]]; then
        printf '%s\n' "${sourceRef}" | _encryptStdIn
    elif [[ -e "${sourceRef}" ]]; then
        cat "${sourceRef}" | _encryptStdIn
    else
        echo "${sourceRef}" | _encryptStdIn
    fi
}

# ◇ Encrypts stdin to a file.
#
# · USAGE
#
#   encryptToFile [-r] outputFile recipientKey...
#
#   -r                        Replace output file if it exists.
#   outputFile (string)       Path to the encrypted output file.
#   recipientKey (string...)  Path to a recipient valt key file. May be repeated for multiple recipients, any of which can decrypt
#                             with their valt private key. Private keys may be passed but require decryption so a passphrase will be
#                             requested for each.

encrypt() {
    [[ -t 0 ]] && fail "content must be piped to this function"
    read -t 0 || fail "no data in pipe"
    parseOptionalArg '-r' "$1" _encryptReplaceTargetFile 0 1 && shift
    _parseEncryptArgs - "${@}"
    _encryptStdIn
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
    parseOptionalArg '-r' "$1" _encryptReplaceTargetFile 0 1 && shift
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

    # Convert all recipient keys

    for keyFile in "${recipientFiles[@]}"; do
        recipient="${ publicEncryptionKey "${keyFile}"; }"
        _encryptRecipients+=( '-r' "${recipient}" )
    done
}

_encryptStdIn() {
    _age --encrypt "${_encryptRecipients[@]}" > "${_encryptOutputFile}"
}
