#!/usr/bin/env bash

# Encryption using age.
# Use via: require 'valt/decrypt'

# ◇ Decrypt input.
#
# · USAGE
#
#   decrypt -i PATH [-o PATH] [INPUT]
#   decrypt --passphrase [-o PATH] [INPUT]
#
#   -i, --identity PATH  Use the valt private key file (identity) at PATH; requires passphrase input to decrypt. Can be repeated.
#   -p, --passphrase     Decrypt with a passphrase which will be requested via prompt. Cannot be combined with an identity.
#   -o, --output PATH    Write the result to PATH. Any existing file will be overwritten (default: standard output).
#   [INPUT]              Optional path to encrypted file (default: standard input).

decrypt() {
    local hasKey=0
    local passphrase=0
    local inputFile
    local outputFile
    local args=()

    while (( $# )); do
        case "$1" in
            -i | --identity) shift; assertFile "$1"; args+=(--key "$1"); hasKey=1 ;;
            -p | --passphrase) passphrase=1; args+=('--passphrase') ;;
            -a | --armor) args+=('--armor') ;;
            -o | --output) shift; outputFile="$1" ;;
            -*) invalidArgs "unknown arg: $1";;
            *)  [[ -n "${inputFIle}" ]] && invalidArgs "only one input is supported"
                assertFile "$1"; inputFile="$1" ;;
        esac
        shift
    done

    if (( passphrase )) ; then
        (( hasKey )) && invalidArgs "-p / --password cannot be combined with identity."
    else
        (( hasKey )) || invalidArgs "identity required"
    fi

    if [[ -n "${inputFile}" ]]; then
        if [[ -n "${outputFile}" ]]; then
            cat "${inputFile}" | _age --decrypt "${args[@]}" > "${outputFile}"
        else
            cat "${inputFile}" | _age --decrypt "${args[@]}"
        fi
    else
        if [[ -n "${outputFile}" ]]; then
            _age --decrypt "${args[@]}" > "${outputFile}"
        else
            _age --decrypt "${args[@]}"
        fi
    fi
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'valt/encrypt' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_valt_decrypt() {
    require 'valt/password' 'rayvn/terminal'
}

# TODO: return 1 instead of fail so caller could recover? Requires change / replace assertCommand!
_age() {
    local operation=$1
    local ageArgs=()
    local requiresPassphrase=0
    local confirmPassphrase=0
    local passphraseFor=
    local keyFile

    while (( $# )); do
        case "$1" in
            --key) shift; assertFile "$1"; keyFile="$1"; requiresPassphrase=1 passphraseFor="${keyFile}" ;;
            --passphrase-for) shift; assertFile "$1"; requiresPassphrase=1 passphraseFor="$1" ;;
            --passphrase) requiresPassphrase=1 ;;
            --confirm) confirmPassphrase=1 ;;
            *) ageArgs+=("$1") ;;
        esac
        shift
    done

    # Do we need a passphrase?

    if (( requiresPassphrase )); then

        # Yep, get it.

        local phraze
        if [[ -n ${rayvnTest_ValtKeyPassphrase} ]]; then
            phraze="${rayvnTest_ValtKeyPassphrase}"
        else
            local prompt="Enter passphrase"
            if [[ -n "${passphraseFor}" ]]; then
                local path; path="${ tildePath "${passphraseFor}"; }"
                prompt+="${ show " for" blue "${path}"; }"
            fi

            if (( confirmPassphrase )); then
                readConfirmedPassword "${prompt}" phraze || fail
                cursorUpOneAndEraseLine
                cursorUpOneAndEraseLine
            else
                readPassword "${prompt}" phraze 30 false || fail
                cursorUpOneAndEraseLine
            fi
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
        eraseVars phrase

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
    [[ ${error} == *"incorrect passphrase" ]] && fail "incorrect passphrase for ${passphraseFor}"
    fail "${error}"
}
