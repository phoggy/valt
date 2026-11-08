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
    testFirstKeyBecomesDefault
    testKeysSuggestsDefault
    testKeysNamedAfterUser
    testGenericUserNeedsName
    testKeysDefaultOption
    testKeysAlreadyDefault
    testKeysNoDefault
    testKeysQuickSkipsDefault
    testKeysQuickWithDefault

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
    assertContains "No key exists yet; create a key pair with valt keys." "${output}"
    [[ ${output} != *"Default key:"* ]] || fail "with no key yet, there is no default key to show: ${output}"

    mkdir -p "${testHome}/.config/valt" && cp "${keyFile}" "${testHome}/.config/valt/alex.key" || fail
    output="${ valtInTestHome default-key; }"
    assertContains "Default key: ~/.config/valt/alex.key (from the built-in default)" "${output}"
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
    assertContains "No key exists yet" "${output}" # the built-in default, which does not exist here
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

# The first key becomes the default without asking.

testFirstKeyBecomesDefault() {
    newTestHome
    local dir; dir="${ makeTempDir; }"
    dir="${ cd "${dir}" && pwd -P; }"
    local output; output="${ valtInTestHome keys -n new -o "${dir}" --no-advice --no-verify --no-pdf; }"
    assertEqual 0 $? "keys must succeed: ${output}"
    assertContains "Default key set to" "${output}"
    assertInFile "defaultKeyFile='${dir}/new.key'" "${testHome}/.config/valt/valt.conf"
}

# Once there is a default key, not on a terminal, 'valt keys' only suggests making the new key the default.

testKeysSuggestsDefault() {
    newTestHome
    local dir; dir="${ makeTempDir; }"
    valtInTestHome keys -n first -o "${dir}" --no-advice --no-verify --no-pdf > /dev/null || fail "first keys failed"
    local before; before="${ cat "${testHome}/.config/valt/valt.conf"; }"
    local output; output="${ valtInTestHome keys -n second -o "${dir}" --no-advice --no-verify --no-pdf; }"
    assertEqual 0 $? "keys must succeed: ${output}"
    assertContains "valt default-key" "${output}"
    assertEqual "${before}" "${ cat "${testHome}/.config/valt/valt.conf"; }" "the default key must not change"
}

# Keys are named after the user, unless the user name is too generic, when a name must be given (or, at a terminal,
# is asked for).

testKeysNamedAfterUser() {
    newTestHome
    local output; output="${ valtInTestHome keys -q --no-pdf; }"
    assertEqual 0 $? "keys must succeed: ${output}"
    assertFile "${testHome}/.config/valt/alex.key"
    assertFile "${testHome}/.config/valt/alex.pub"
}

testGenericUserNeedsName() {
    newTestHome
    local output; output="${ USER=root valtInTestHome keys -q --no-pdf; }"
    assertNotEqual 0 $? "keys must fail for a generic user name: ${output}"
    assertContains "too generic to name a key by" "${output}"
    assertEqual '' "${ ls "${testHome}/.config/valt" 2> /dev/null | grep '\.key$'; }" "no key must be made"
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

testKeysNoDefault() {
    newTestHome
    local dir; dir="${ makeTempDir; }"
    local output; output="${ valtInTestHome keys -n new -o "${dir}" -q --no-pdf --no-default; }"
    assertEqual 0 $? "keys --no-default must succeed: ${output}"
    [[ ${output} != *"default-key"* && ${output} != *"Default key set"* ]] || fail "--no-default must not offer or suggest: ${output}"
    assertFileDoesNotExist "${testHome}/.config/valt/valt.conf"
}

testKeysQuickSkipsDefault() {
    newTestHome
    local dir; dir="${ makeTempDir; }"
    local output; output="${ valtInTestHome keys -n new -o "${dir}" -q --no-pdf; }"
    assertEqual 0 $? "keys -q must succeed: ${output}"
    [[ ${output} != *"default-key"* && ${output} != *"Default key set"* ]] || fail "-q must not offer or suggest: ${output}"
    assertFileDoesNotExist "${testHome}/.config/valt/valt.conf"
}

testKeysQuickWithDefault() {
    newTestHome
    local dir; dir="${ makeTempDir; }"
    dir="${ cd "${dir}" && pwd -P; }"
    local output; output="${ valtInTestHome keys -n new -o "${dir}" -q -d --no-pdf; }"
    assertEqual 0 $? "keys -q -d must succeed: ${output}"
    assertInFile "defaultKeyFile='${dir}/new.key'" "${testHome}/.config/valt/valt.conf"
}

declare -gx USER='alex' # so that the default key is alex.key
source rayvn.up 'rayvn/test' 'valt/keys'
main "$@"
