#!/usr/bin/env bash

# Enable/disable use of valt pinentry for password input.
# Use via: require 'valt/pinentry'

# ◇ Sets PINENTRY_PROGRAM to the path of the valt-pinentry binary.

useValtPinEntry() {
    declare -gx PINENTRY_PROGRAM="${ binaryPath valt-pinentry; }"
}

# ◇ Unsets PINENTRY_PROGRAM, restoring the default pinentry behavior.

disableValtPinEntry() {
    unset PINENTRY_PROGRAM
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'valt/pinentry' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_valt_pinentry() {
    :
}


