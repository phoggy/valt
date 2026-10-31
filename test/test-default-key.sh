#!/usr/bin/env bash

main() {
    init "$@"

    testBuiltInDefault
    testSetAndClear
    testEnvVarOverridesSetting
    testCommandsUseDefaultKey
    testIdentityOverridesDefault
    testSetRejectsNonValtKey
    testSetRejectsKeyFileAndClear
    testKeysSuggestsDefault
    testKeysDefaultOption
    testKeysAlreadyDefault

    return 0
}

init() {
    while (( $# )); do
        case "$1" in
            --debug*) setDebug "$@"; shift $? ;;
        esac
        shift
    done

    declare -gx rayvnTest_ValtKeyPassphrase='valt-test-passphrase-12345'
    skipKeyPassphraseAdvice=1
    allowWeakKeyPassphrase=1

    declare -g keyDir pubFile keyFile otherPubFile otherKeyFile
    keyDir="${ makeTempDir; }"
    keyDir="${ cd "${keyDir}" && pwd -P; }"
    newValtKeys 'mine' "${keyDir}" pubFile keyFile
    newValtKeys 'other' "${keyDir}" otherPubFile otherKeyFile
}

# Runs valt with a fresh home directory, so the real valt config is never touched.

valtInTestHome() {
    local -x HOME="${testHome}"
    valt "$@" 2>&1
}

newTestHome() {
    declare -g testHome; testHome="${ makeTempDir; }"
    unset VALT_KEY_FILE
}

testBuiltInDefault() {
    newTestHome
    local output; output="${ valtInTestHome default-key; }"
    assertContains "Default key: ~/.config/valt/valt.key (from the built-in default)" "${output}"
    assertContains "does not exist" "${output}"
}

testSetAndClear() {
    newTestHome
    local output; output="${ valtInTestHome default-key "${keyFile}"; }"
    assertContains "Default key set to" "${output}"
    assertInFile "defaultKeyFile='${keyFile}'" "${testHome}/.config/valt/valt.conf"
    output="${ valtInTestHome default-key; }"
    assertContains "${keyFile} (from ~/.config/valt/valt.conf)" "${output}"

    output="${ valtInTestHome default-key --clear; }"
    assertContains "Removed the default key setting" "${output}"
    assertContains "(from the built-in default)" "${output}"
    assertFileDoesNotExist "${testHome}/.config/valt/valt.conf"
}

testEnvVarOverridesSetting() {
    newTestHome
    valtInTestHome default-key "${keyFile}" > /dev/null
    local output; output="${ VALT_KEY_FILE="${otherKeyFile}" valtInTestHome default-key; }"
    assertContains "${otherKeyFile} (from the VALT_KEY_FILE environment variable)" "${output}"
}

testCommandsUseDefaultKey() {
    newTestHome
    valtInTestHome default-key "${keyFile}" > /dev/null
    local output; output="${ valtInTestHome verify; }"
    assertEqual 0 $? "verify must use the default key: ${output}"
    assertContains "mine.key decrypts with its passphrase" "${output}"
    assertContains "mine.pub matches the private key" "${output}"
}

testIdentityOverridesDefault() {
    newTestHome
    valtInTestHome default-key "${keyFile}" > /dev/null
    local output; output="${ valtInTestHome verify -i "${otherKeyFile}"; }"
    assertContains "other.key decrypts with its passphrase" "${output}"
}

testSetRejectsNonValtKey() {
    newTestHome
    local file; file="${ makeTempFile; }"
    echo 'not a key' > "${file}"
    local output; output="${ valtInTestHome default-key "${file}"; }"
    assertContains "not a valt key file" "${output}"
    assertFileDoesNotExist "${testHome}/.config/valt/valt.conf"
}

testSetRejectsKeyFileAndClear() {
    newTestHome
    local output; output="${ valtInTestHome default-key "${keyFile}" --clear; }"
    assertContains "Specify either KEY_FILE or --clear, not both" "${output}"
}

# Not on a terminal, 'valt keys' only suggests making the new key the default.

testKeysSuggestsDefault() {
    newTestHome
    local dir; dir="${ makeTempDir; }"
    local output; output="${ valtInTestHome keys -n new -o "${dir}" -q --no-pdf; }"
    assertEqual 0 $? "keys must succeed: ${output}"
    assertContains "valt default-key" "${output}"
    assertFileDoesNotExist "${testHome}/.config/valt/valt.conf"
}

testKeysDefaultOption() {
    newTestHome
    local dir; dir="${ makeTempDir; }"
    dir="${ cd "${dir}" && pwd -P; }"
    local output; output="${ valtInTestHome keys -n new -o "${dir}" -q --no-pdf -d; }"
    assertEqual 0 $? "keys -d must succeed: ${output}"
    assertContains "Default key set to" "${output}"
    assertInFile "defaultKeyFile='${dir}/new.key'" "${testHome}/.config/valt/valt.conf"
}

testKeysAlreadyDefault() {
    newTestHome
    local output; output="${ valtInTestHome keys -q --no-pdf; }"
    assertEqual 0 $? "keys must succeed: ${output}"
    [[ ${output} != *"default-key"* && ${output} != *"Default key set"* ]] || fail "the built-in default key must not be offered: ${output}"
}

source rayvn.up 'rayvn/test' 'valt/keys'
main "$@"
