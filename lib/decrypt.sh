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
        cat "${inputFile}" | _age --decrypt true "${valtKeyFile}" > "${outputFile}" || fail
    else
        cat "${inputFile}" | _age --decrypt true "${valtKeyFile}" || fail
    fi
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'valt/encrypt' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_valt_decrypt() {
    require 'valt/password'
}

_age() {
    local operation=$1
    local decryptKey=$2
    local ageArgs=("${@:3}")

    # Do we need a passphrase to decrypt the key?

    if [[ "${decryptKey}" == "true" ]]; then

        # Yes, get it.

        local phraze
        if [[ -n ${rayvnTest_ValtKeyPassphrase} ]]; then
            phraze="${rayvnTest_ValtKeyPassphrase}"
        else
            readVerifiedPassword phraze || fail
        fi

        # Feed the passphrase via a dynamically allocated fd using process substitution: printf exits after
        # writing, closing the write end of the pipe, so the batchpass plugin's io.ReadAll receives EOF
        # immediately and will not hang waiting for it. See plugin source at
        # https://github.com/FiloSottile/age/blob/main/cmd/age-plugin-batchpass/plugin-batchpass.go

        local passFd
        exec {passFd}< <(printf '%s' "${phraze}")
        AGE_PASSPHRASE_FD="${passFd}" age ${operation} "${ageArgs[@]}" -j batchpass 2> >(errorStream) || fail
        exec {passFd}<&-

    else
        AGE_PASSPHRASE_FD="${passFd}" age ${operation} "${ageArgs[@]}" 2> >(errorStream) || fail
    fi
}
