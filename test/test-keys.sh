#!/usr/bin/env bash

main() {
    init "$@"

    testCreateValtKeys
    testKeyType
    testRecipientFromPub
    testRecipientFromKey
    testCreateRecipientsFile
    testPublicSigningKeyToTempFile
    testSigningKeyToTempFile
    testArmorKeyFile

    return 0
}

init() {
    while (( $# )); do
        case "$1" in
            --debug*) setDebug "$@"; shift $? ;;
        esac
        shift
    done

    rayvnTest_ValtKeyPassphrase='valt-test-passphrase-12345'
    skipKeyPassphraseAdvice=1
    declare -g testKeyDir pubFile keyFile
    testKeyDir="${ makeTempDir; }"
    createValtKeys 'test' "${testKeyDir}" pubFile keyFile
}

testCreateValtKeys() {
    assertFile "${pubFile}"
    assertFile "${keyFile}"
    assertEqual "${testKeyDir}/test.pub" "${pubFile}"
    assertEqual "${testKeyDir}/test.key" "${keyFile}"
}

testKeyType() {
    local t
    t="${ keyType "${pubFile}"; }"
    assertEqual 'pub' "${t}"
    t="${ keyType "${keyFile}"; }"
    assertEqual 'key' "${t}"
}

testRecipientFromPub() {
    local r
    r="${ recipient "${pubFile}"; }"
    assertEqual 'age' "${r:0:3}" "recipient from pub should start with 'age'"
}

testRecipientFromKey() {
    local rPub rKey
    rPub="${ recipient "${pubFile}"; }"
    rKey="${ recipient "${keyFile}"; }"
    assertEqual "${rPub}" "${rKey}" "recipient from key should match recipient from pub"
}

testCreateRecipientsFile() {
    local recipientsFile; recipientsFile="${ makeTempFile; }"
    local r; r="${ recipient "${pubFile}"; }"
    createRecipientsFile "${recipientsFile}" "${pubFile}"
    assertTrue "recipients file must contain recipient" grep -qF "${r}" "${recipientsFile}"
}

testPublicSigningKeyToTempFile() {
    local signingKeyFile
    publicSigningKeyToTempFile "${keyFile}" signingKeyFile
    assertFile "${signingKeyFile}"
    local lineCount; lineCount=${ gawk 'END{print NR}' "${signingKeyFile}"; }
    assertEqual '2' "${lineCount}"
}

testSigningKeyToTempFile() {
    local signingKeyFile
    signingKeyToTempFile "${keyFile}" signingKeyFile
    assertFile "${signingKeyFile}"
    assertTrue "signing key file must be non-empty" test -s "${signingKeyFile}"
}

testArmorKeyFile() {
    local armored
    armored="${ armorKeyFile "${keyFile}"; }"
    assertContains '-----BEGIN AGE ENCRYPTED FILE-----' "${armored}"
    assertContains '-----END AGE ENCRYPTED FILE-----' "${armored}"
}

source rayvn.up 'rayvn/test' 'valt/keys'
main "$@"
