#!/usr/bin/env bash

# Encryption using age.
# Use via: require 'valt/encrypt'

# ◇ Encrypt input.
#
# · USAGE
#
#   encrypt (-r RECIPIENT | -R PATH)... [--armor] [-o PATH] [INPUT]
#   encrypt --passphrase [--armor] [-o PATH] [INPUT]
#
#   -r, --recipient RECIPIENT  Encrypt to the specified RECIPIENT. See the recipient() function in 'valt/keys'.
#   -R, --recipient-file PATH  Encrypt to one or more recipients. PATH can be a valt key or contain a list of recipients (see the
#                              createRecipientsFile() function in 'valt/keys'). Valt private key files require passphrase input
#                              for decryption. Can be repeated.
#   -a, --armor                Encrypt to a PEM encoded format.
#   -p, --passphrase           Encrypt with a passphrase which will be requested via prompt. Cannot be combined with recipients.
#   -o, --output PATH          Write the result to the file at PATH. Any existing file will be overwritten. Defaults to standard
#                              output.
#   [INPUT]                    Defaults to standard input. If INPUT is a directory, it will be converted to a tar file before
#                              encryption.
#
# · EXAMPLE
#
#   echo "test" | encrypt -R "${keyDir}/valt.pub" -o "test.enc"  # Encrypt content of stdin using public key to test.enc file.
#   encrypt "test.txt" -R "${keyDir}/valt.pub" -o "test.enc"     # Encrypt test.txt file to test.enc file.
#   encrypt "foo" -R "${keyDir}/valt.pub"  -o "foo.tar.xz"       # Encrypt tar file created from foo directory.

encrypt() {
    _parseEncryptArgs "$@"
    _encryptSource
}

# ◇ Encrypts the content of a string, array or file variable.
#
# · USAGE
#
#   encryptVar varName (-r RECIPIENT | -R PATH)... [--armor] [-o PATH]
#
#   -r, --recipient RECIPIENT  Encrypt to the specified RECIPIENT. See the recipient() function in 'valt/keys'.
#   -R, --recipient-file PATH  Encrypt to one or more recipients. PATH can be a valt key or contain a list of recipients (see the
#                              createRecipientsFile() function in 'valt/keys'). Valt private key files require passphrase input
#                              for decryption. Can be repeated.
#   -a, --armor                Encrypt to a PEM encoded format.
#   -p, --passphrase           Encrypt with a passphrase which will be requested via prompt. Cannot be combined with recipients.
#   -o, --output PATH          Write the result to the file at PATH. Any existing file will be overwritten. Defaults to standard
#                              output.
#   varName                    Name of a variable containing a string, array or file path. If a directory, it will be converted
#                              tar file. Maps (associative arrays) are not supported.
#
# · EXAMPLE TODO
#

encryptVar() {
    _parseEncryptArgs "$@"
    [[ -v "${_encryptSource}" ]] || fail "'${_encryptSource}' is not a variable"

    local -n sourceRef="${_encryptSource}"
    local type; type="${ declare -p "${_encryptSource}" | cut -d' ' -f2; }"

    if [[ "${type}" == -A* ]]; then
        invalidArgs "map '${_encryptSource}' must be serialized to an array or string"
    elif [[ "${type}" == -a* ]]; then
        printf '%s\n' "${sourceRef}" | _encryptStdIn
    elif [[ -e "${sourceRef}" ]]; then
        _encryptSource="${sourceRef}"
        _encryptSource
    else
        echo "${sourceRef}" | _encryptStdIn
    fi
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'valt/encrypt' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_valt_encrypt() {     # TODO: _valt_encrypt_init  reads properly
    require 'valt/keys'

    declare -g _encryptSource
    declare -g _encryptSourceIsFile
    declare -g _encryptPassphrase
    declare -g _encryptArmor
    declare -g _encryptHasRecipient
    declare -ga _encryptRecipientArgs
    declare -g _encryptOutputFile
}

_parseEncryptArgs() {
    _encryptSource=
    _encryptSourceIsFile=0
    _encryptPassphrase=0
    _encryptArmor=0
    _encryptHasRecipient=0
    _encryptRecipientArgs=()
    _encryptOutputFile=

    while (( $# )); do
        case "$1" in
            -R | --recipient-file) shift; _addRecipientFile "$1" ;;
            -r | --recipient) shift; _addRecipient "$1" ;;
            -p | --passphrase) _encryptPassphrase=1 ;;
            -a | --armor) _encryptArmor=1 ;;
            -o | --output) shift; _encryptOutputFile="$1" ;;
            -*) invalidArgs "unknown arg: $1";;
            *) [[ -n "${_encryptSource}" ]] && invalidArgs "only one input is supported"; _encryptSource="$1" ;;
        esac
        shift
    done

    if (( _encryptPassphrase )); then
        (( _encryptHasRecipient )) && invalidArgs "-p / --password cannot be combined with recipients."
    else
        (( _encryptHasRecipient )) || invalidArgs "one or more recipients required"
    fi
}

_checkFileSource() {
    if [[ -n "${_encryptSource}" ]] && [[ -e "${_encryptSource}" ]]; then
        if [[ -d "${_encryptSource}" ]]; then
            _encryptSource="${ realpath "${_encryptSource}"; }" || fail "could not resolve real path of '${_encryptSource}'"
            local name; name="${ baseName "${_encryptSource}"; }"
            local dir; dir="${ dirName "${_encryptSource}"; }"
            local tarFile; tarFile="${ makeTempFile "${dir}.tar.xz"; }"
            tar cJf "${tarFile}" "${_encryptSource}" || fail
            _encryptSource="${tarFile}"
        fi
        _encryptSourceIsFile=1
    fi
}

_addRecipientFile() {
    assertFile "$1"
    local keyFile="$1" recipient
    recipient="${ recipient "${keyFile}"; }"
    _encryptRecipientArgs+=( '-r' "${recipient}" )
    _encryptHasRecipient=1
}

_addRecipient() {
    [[ ${1:0:3} == 'age' ]] || fail "not a recipient: $1"
    local recipient; recipient="$1"
    _encryptRecipientArgs+=( '-r' "${recipient}" )
    _encryptHasRecipient=1
}

_encryptSource() {
    _checkFileSource
    if (( _encryptSourceIsFile )); then
        cat "${_encryptSource}" | _encryptStdIn
    else
        _encryptStdIn
    fi
}

_encryptStdIn() {
    local args=()
    (( _encryptPassphrase )) && args=('--passphrase')
    if [[ -n "${_encryptOutputFile}" ]]; then
        _age --encrypt "${_encryptRecipientArgs[@]}" "${args[@]}" > "${_encryptOutputFile}"
    else
        _age --encrypt "${_encryptRecipientArgs[@]}" "${args[@]}"
    fi
}
