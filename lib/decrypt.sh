#!/usr/bin/env bash

# Encryption using age.
# Use via: require 'valt/decrypt'

# ◇ Decrypts a file.
#
# · USAGE
#
#   decryptFile valtKey inputFile [outputFile]
#
#   valtKey (string)     Path to a recipient valt key file. Requires decryption so a passphrase will be requested.
#   inputFile (string)   Path to the encrypted file.
#   outputFile (string)  Optional path to the decrypted output file (default: write to stdout).

decrypt() {
    local valtKeyFile="${1}"
    local inputFile="${2}"
    local outputFile="${3:-}"
    assertFile "${valtKeyFile}"
    assertFile "${inputFile}"
    if [[ -n "${outputFile}" ]]; then
        cat "${inputFile}" | _age --decrypt --key "${valtKeyFile}" > "${outputFile}"
    else
        cat "${inputFile}" | _age --decrypt --key "${valtKeyFile}"
    fi
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'valt/encrypt' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_valt_decrypt() {
    require 'valt/password'
}

_age() {
    local operation=$1
    local ageArgs=()
    local requiresPassphrase=0
    local keyFile

    while (( $# )); do
        case "$1" in
            --key) shift; assertFile "$1"; keyFile="$1"; requiresPassphrase=1 ;;
            --pass) requiresPassphrase=1 ;;
            *) ageArgs+=("$1") ;;
        esac
        shift
    done


    # Do we need a passphrase to decrypt?

    if (( requiresPassphrase )); then

        # Yes, get it.

        local phraze
        if [[ -n ${rayvnTest_ValtKeyPassphrase} ]]; then
            phraze="${rayvnTest_ValtKeyPassphrase}"
        else
            readConfirmedPassword "Enter key passphrase" phraze || fail
        fi

        # Feed passphrase via a pipe fd: printf exits immediately after writing, closing the write end,
        # so batchpass's io.ReadAll receives EOF without hanging.

        local passFd
        exec {passFd}< <(printf '%s' "${phraze}")

        if [[ -n "${keyFile}" ]]; then

            # First decrypt the passphrase-protected key file using batchpass,
            # then pipe its plain-text output as a -i identity to decrypt the cipher on stdin.
            # The -i <(...) path bypasses EncryptedIdentity (age's interactive-only handler) entirely.

            assertCommand --transform _ageError age "${operation}" -i <(_decryptKey) "${ageArgs[@]}"

        else
            AGE_PASSPHRASE_FD="${passFd}" assertCommand --transform _ageError age ${operation} "${ageArgs[@]}" -j batchpass
        fi

        exec {passFd}<&- # close the fd

    else
        assertCommand --transform _ageError age ${operation} "${ageArgs[@]}"
    fi
}


_decryptKey() {
    AGE_PASSPHRASE_FD="${passFd}" assertCommand --transform _ageError age --decrypt -j batchpass < "${keyFile}"
}

_ageError() {
    local error; error="${ echo "$*" | head -n 1; }"
    [[ ${error} == *"no identity matched any of the recipients" ]] && fail "${operation} key does not match recipient: ${keyFile}"
    fail "${error}"
}
