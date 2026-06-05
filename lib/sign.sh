#!/usr/bin/env bash

# Sign files using valt keys.
# Use via: require 'valt/sign'

# ◇ Sign a file using a valt private key, creating a detached signature file.
#
# · USAGE
#
#   signFile keyFile targetFile [signatureFile]
#
#   keyFile        (string)  Path to the valt private key file.
#   targetFile     (string)  Path to the file to sign.
#   signatureFile  (string)  Optional path for the signature output file (default: targetFile.minisig).

signFile() {
    assertFile "$1"
    assertFile "$2"
    local keyFile="$1"
    local targetFile="$2"
    local signatureFile; _setSignatureFile "${targetFile}" signatureFile "$3"

    # Extract the private key

    local signingKeyFile; signingKeyToTempFile "${keyFile}" signingKeyFile

    # Sign

    minisign -S -s "${signingKeyFile}" -c "valt signature" -m "${targetFile}" -x "${signatureFile}" || fail

    # Remove the extracted signing key file

    rm "${signingKeyFile}" &> /dev/null
}

# ◇ Verify the signature of a file using a valt key. Accepts either a public or private key.
#
# · USAGE
#
#   verifyFileSignature keyFile targetFile [signatureFile]
#
#   keyFile        (string)  Path to a valt .pub or .key file.
#   targetFile     (string)  Path to the file to verify.
#   signatureFile  (string)  Optional path to the signature file (default: targetFile.minisig).

verifyFileSignature() {
    assertFile "$1"
    assertFile "$2"
    local keyFile="$1"
    local targetFile="$2"
    local signatureFile; _setSignatureFile "${targetFile}" signatureFile "$3"
    assertFile "${signatureFile}"

    # Extract the public key

    local signingPublicKeyFile; publicSigningKeyToTempFile "${keyFile}" signingPublicKeyFile

    # Verify signature

    minisign -V -p "${signingPublicKeyFile}" -x "${signatureFile}" -m "${targetFile}" -q || fail

    # Remove the extracted signing key file

    rm "${signingPublicKeyFile}" &> /dev/null
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'valt/sign' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_valt_sign() {
    require 'valt/keys'
    declare -grx _signatureFileSuffix="minisig"
}

_setSignatureFile() {
    local _targetFile="$1"
    local -n resultRef="$2"
    local _signatureFile
    if [[ -n "$3" ]]; then
        _signatureFile="$3"
    else
        _signatureFile="${_targetFile}.${_signatureFileSuffix}"
    fi
    resultRef="${_signatureFile}"
}


