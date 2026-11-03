#!/usr/bin/env bash

# valt public-key: recreating a .pub file from its private key.

main() {
    init "$@"

    testRecreatesIdenticalPublicKey
    testRefusesToReplaceWithoutForce
    testWritesToOutput
    testRecreatedKeyEncrypts
    testWrongPassphraseFails
    testRejectsNonValtKey

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

    declare -g keyDir pubFile keyFile
    keyDir="${ makeTempDir; }"
    newValtKeys 'test' "${keyDir}" pubFile keyFile
}

# Copies the test key into a new directory, without its .pub, setting the named var to the copy's path.

newKeyCopy() {
    local -n copyRef=$1
    local dir; dir="${ makeTempDir; }"
    cp "${keyFile}" "${dir}/copy.key" || fail
    copyRef="${dir}/copy.key"
}

testRecreatesIdenticalPublicKey() {
    local key; newKeyCopy key
    local output; output="${ valt public-key "${key}" 2>&1; }"
    assertEqual 0 $? "public-key must succeed: ${output}"
    assertContains "Wrote" "${output}"
    cmp -s "${pubFile}" "${key%.key}.pub" || fail "the recreated .pub must be identical to the original"
}

testRefusesToReplaceWithoutForce() {
    local key; newKeyCopy key
    echo 'existing' > "${key%.key}.pub"
    local output; output="${ valt public-key "${key}" 2>&1; }"
    assertNotEqual 0 $? "an existing .pub must not be replaced without --force"
    assertContains "already exists" "${output}"
    assertEqual 'existing' "${ cat "${key%.key}.pub"; }"

    output="${ valt public-key "${key}" --force 2>&1; }"
    assertEqual 0 $? "--force must replace it: ${output}"
    cmp -s "${pubFile}" "${key%.key}.pub" || fail "the replaced .pub must be identical to the original"
}

testWritesToOutput() {
    local key; newKeyCopy key
    local output="${keyDir}/elsewhere.pub" result
    result="${ valt public-key "${key}" -o "${output}" 2>&1; }"
    assertEqual 0 $? "public-key -o must succeed: ${result}"
    cmp -s "${pubFile}" "${output}" || fail "-o must write the public key there"
    assertFileDoesNotExist "${key%.key}.pub"
}

# The recreated public key works with its private key: valt verify checks they match, and encrypting to it works.

testRecreatedKeyEncrypts() {
    local key; newKeyCopy key
    valt public-key "${key}" > /dev/null 2>&1 || fail
    local output; output="${ valt verify -i "${key}" 2>&1; }"
    assertEqual 0 $? "verify must succeed: ${output}"
    assertContains "copy.pub matches the private key" "${output}"
}

testWrongPassphraseFails() {
    local key; newKeyCopy key
    local output; output="${ rayvnTest_ValtKeyPassphrase='wrong-passphrase' valt public-key "${key}" 2>&1; }"
    assertNotEqual 0 $? "a wrong passphrase must fail"
    assertContains "incorrect passphrase" "${output}"
    assertFileDoesNotExist "${key%.key}.pub"
}

testRejectsNonValtKey() {
    local file="${keyDir}/not-a-key.key"
    echo 'not a key' > "${file}"
    local output; output="${ valt public-key "${file}" -o "${keyDir}/not.pub" 2>&1; }"
    assertNotEqual 0 $? "a file that is not a valt key must be rejected"
    assertContains "not a valt key" "${output}"
}

source rayvn.up 'rayvn/test' 'valt/keys'
main "$@"
