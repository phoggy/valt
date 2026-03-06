#!/usr/bin/env bash

# Sign files using valt keys.
# Use via: require 'valt/sign'

signFile() {
    assertFile "$1"
    assertFile "$2"
    local privateKeyFile="$1"
    local fileToSign="$2"
    local signatureFile="$3"  # optional

    if [[ ! -n "${signatureFile}" ]]; then
        signatureFile="${fileToSign}.${defaultSignatureSuffix}"
debugVar signatureFile
    fi

    # Extract the private key

    local signingKeyFile
    tempSigningKeyFile "${privateKeyFile}" signingKeyFile

    # Sign
debugVar signingKeyFile fileToSign signatureFile
    minisign -S -s "${signingKeyFile}" -c "valt signature" -m "${fileToSign}" -x "${signatureFile}" || fail
debug "signed"
    # Remove the extracted signing key file

    rm "${signingKeyFile}" &> /dev/null
}

verifyFileSignature() {
    assertFile "$1"
    assertFile "$2"
    assertFile "$3"
    local publicKeyFile="$1"
    local signedFile="$2"
    local signatureFile="$3"

    # Verify signature

    minisign -V -p "${publicKeyFile}" -x "${signatureFile}" -m "${signedFile}" -q || fail
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'valt/sign' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_valt_sign() {
    require 'valt/keys'
    declare -grx defaultSignatureSuffix="signature"
}

