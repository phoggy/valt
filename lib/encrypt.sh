#!/usr/bin/env bash

# Encryption using age.
# Use via: require 'valt/encrypt'

# ◇ Encrypt input.
#
# · USAGE
#
#   encrypt [INPUT | -v NAME] (-r RECIPIENT | -R PATH)... [--armor] [-o PATH]
#   encrypt [INPUT | -v NAME] --passphrase [--armor] [-o PATH]
#
#   -r, --recipient RECIPIENT  Encrypt to the specified RECIPIENT. See the recipient() function in 'valt/keys'.
#   -R, --recipient-file PATH  Encrypt to one or more recipients. PATH can be a valt key or contain a list of recipients (see the
#                              createRecipientsFile() function in 'valt/keys'). Valt private key files require passphrase input
#                              for decryption. Can be repeated.
#   -a, --armor                Encrypt to a PEM encoded format.
#   -p, --passphrase           Encrypt with a passphrase which will be requested via prompt. Cannot be combined with recipients.
#   -v, --var NAME             Encrypt the value of scalar shell variable NAME. Cannot be combined with INPUT path.
#   -o, --output PATH          Write the result to the file at PATH (default: standard output). Any existing file will be
#                              overwritten.
#   [INPUT]                    Optional file path (default: standard input). If INPUT is a directory, it will be converted to a
#                              tar file before encryption. Path cannot be combined with -v / --var.
#
# · EXAMPLE
#
#   local test="my secret"
#   echo "${test}" | encrypt -R "${keyDir}/valt.pub" -o "test.enc"  # Encrypt content of stdin using public key to test.enc file.
#   encrypt -v test -R "${keyDir}/valt.pub" -o "test.enc"           # Encrypt value of test var using public key to test.enc file.
#   encrypt "test.txt" -R "${keyDir}/valt.pub" -o "test.enc"        # Encrypt test.txt file to test.enc file.
#   encrypt "foo" -R "${keyDir}/valt.pub"  -o "foo.tar.xz"          # Encrypt tar file created from foo directory.

encrypt() {
    _parseEncryptArgs "$@"
    _encrypt
}


PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'valt/encrypt' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_valt_encrypt() {     # TODO: _valt_encrypt_init  reads properly
    require 'valt/keys'

    declare -g _encryptVarName
    declare -g _encryptInputFile
    declare -g _encryptOutputFile
    declare -ga _encryptArgs
}

_parseEncryptArgs() {
    _encryptVarName=
    _encryptInputFile=
    _encryptOutputFile=
    _encryptArgs=()

    local passphrase=0
    local hasRecipient=0

    while (( $# )); do
        case "$1" in
            -R | --recipient-file) shift; _addRecipientFromKey "$1" ;;
            -r | --recipient) shift; _addRecipient "$1" ;;
            -v | --var) shift; _encryptVarName="$1" ;;
            -p | --passphrase) passphrase=1; _encryptArgs+=('--passphrase') ;;
            -a | --armor) _encryptArgs+=('--armor') ;;
            -o | --output) shift; _encryptOutputFile="$1" ;;
            -*) invalidArgs "unknown arg: $1";;
            *)  [[ -n "${_encryptInputFile}" ]] && invalidArgs "only one input supported"
                _encryptInputFile="$1" ;;
        esac
        shift
    done

    [[ -n "${_encryptVarName}" && -n "${_encryptInputFile}" ]] && invalidArgs "-v / --var cannot be combined with INPUT"

    if (( passphrase )); then
        (( hasRecipient )) && invalidArgs "-p / --password cannot be combined with recipients."
    else
        (( hasRecipient )) || invalidArgs "one or more recipients required"
    fi
}

_addRecipientFromKey() {
    assertFile "$1"
    local keyFile="$1" recipient
    recipient="${ recipient "${keyFile}"; }"
    _encryptArgs+=( '-r' "${recipient}" )
    hasRecipient=1
}

_addRecipient() {
    [[ ${1:0:3} == 'age' ]] || fail "not a recipient: $1"
    local recipient; recipient="$1"
    _encryptArgs+=( '-r' "${recipient}" )
    hasRecipient=1
}

_encrypt() {
    if [[ -n "${_encryptVarName}" ]]; then
        local decl; decl="${ declare -p "${_encryptVarName}" 2>/dev/null; }"
        [[ -z "${decl}" ]] && fail "'${_encryptVarName}' is not defined"
        [[ "${decl}" =~ ^'declare -'[aA] ]] && invalidArgs "-v / --var: '${_encryptVarName}' must be a scalar; serialize arrays first"
        local -n _encryptVarRef="${_encryptVarName}"
        printf '%s' "${_encryptVarRef}" | _encryptStdIn
    elif [[ -n "${_encryptInputFile}" ]]; then
        [[ -e "${_encryptInputFile}" ]] || fail "not a file or directory: ${_encryptInputFile}"
        [[ -d "${_encryptInputFile}" ]] && _convertSourceToTar
        cat "${_encryptInputFile}" | _encryptStdIn
    else
        _encryptStdIn
    fi
}

_convertSourceToTar() {
    local source; source="${ realpath "${_encryptInputFile}"; }" || fail "could not resolve real path of '${_encryptInputFile}'"
    local name; name="${ baseName "${source}"; }"
    local parent; parent="${ dirName "${source}"; }"
    local tarFile; tarFile="${ makeTempFile "${name}.tar.xz"; }"
    tar -C "${parent}" -cJf "${tarFile}" "${name}" || fail
    _encryptInputFile="${tarFile}"
}

_encryptStdIn() {
    if [[ -n "${_encryptOutputFile}" ]]; then
        _age --encrypt "${_encryptArgs[@]}" > "${_encryptOutputFile}"
    else
        _age --encrypt "${_encryptArgs[@]}"
    fi
}
