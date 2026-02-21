#!/usr/bin/env bash

# Library supporting password/phrase generation
# Intended for use via: require 'valt/pinentry'

# Set PINENTRY_PROGRAM to valt's custom pinentry binary, enabling passphrase capture.
useValtPinEntry() {
    declare -gx PINENTRY_PROGRAM="${ binaryPath valt-pinentry; }"
}

# Unset PINENTRY_PROGRAM, restoring the default pinentry behavior.
disableValtPinEntry() {
    unset PINENTRY_PROGRAM
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'valt/pinentry' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_valt_pinentry() {
    require 'rayvn/core'
}


