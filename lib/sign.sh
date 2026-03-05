#!/usr/bin/env bash

# Sign files using valt keys.
# Use via: require 'valt/sign'

signFile() {
    assertFile "$1"
    assertFile "$2"
    local privateKeyFile="$1"
    local fileToSign="$2"

    local signingKeyFile
    tempSigningKeyFile "${privateKeyFile}" signingKeyFile
    minisign -S -s "${signingKeyFile}" -c "valt signature" -m "${fileToSign}"
    rm "${signingKeyFile}" &> /dev/null
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'valt/sign' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_valt_sign() {
    require 'valt/keys'
}

