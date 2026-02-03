#!/usr/bin/env bash

# Library supporting password/phrase generation
# Intended for use via: require 'valt/pinentry'

useValtPinEntry() {
    declare -gx PINENTRY_PROGRAM="${ binaryPath valt-pinentry; }"
}

disableValtPinEntry() {
    unset PINENTRY_PROGRAM
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'valt/pinentry' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_valt_pinentry() {
    require 'rayvn/core'
}


