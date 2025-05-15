#!/usr/bin/env bash

# Library supporting password/phrase generation
# Intended for use via: require 'valt/pinentry'

require 'rayvn/core'

useValtPinEntry() {
    declare -gx PINENTRY_PROGRAM="${valtHome}/bin/valt-pinentry"
}

disableValtPinEntry() {
    unset PINENTRY_PROGRAM
}

