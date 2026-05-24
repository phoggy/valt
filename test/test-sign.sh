#!/usr/bin/env bash

main() {
    init "$@"

    testSignFile
    testVerifyFileSignature
    testVerifyWithPublicKey
    testVerifyFailsOnModifiedFile
    testVerifyFailsOnMissingSignature
    testCustomSignatureFile

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
    declare -g testKeyDir pubFile keyFile testFile
    testKeyDir="${ makeTempDir; }"
    createValtKeys 'test' "${testKeyDir}" pubFile keyFile
    testFile="${ makeTempFile test.txt; }"
    echo 'The quick brown fox jumps over the lazy dog.' > "${testFile}"
}

testSignFile() {
    signFile "${keyFile}" "${testFile}"
    assertFile "${testFile}.${defaultSignatureSuffix}"
    assertTrue "signature file must be non-empty" test -s "${testFile}.${defaultSignatureSuffix}"
}

testVerifyFileSignature() {
    signFile "${keyFile}" "${testFile}"
    verifyFileSignature "${keyFile}" "${testFile}"
}

testVerifyWithPublicKey() {
    signFile "${keyFile}" "${testFile}"
    verifyFileSignature "${pubFile}" "${testFile}"
}

testVerifyFailsOnModifiedFile() {
    signFile "${keyFile}" "${testFile}"
    echo 'tampered' >> "${testFile}"
    ( verifyFileSignature "${keyFile}" "${testFile}" ) 2> /dev/null && fail "verification must fail on modified file"
    return 0
}

testVerifyFailsOnMissingSignature() {
    local unsignedFile; unsignedFile="${ makeTempFile unsigned.txt; }"
    echo 'unsigned content' > "${unsignedFile}"
    ( verifyFileSignature "${keyFile}" "${unsignedFile}" ) 2> /dev/null && fail "verification must fail with no signature file"
    return 0
}

testCustomSignatureFile() {
    local sigFile; sigFile="${ makeTempFile test.sig; }"
    signFile "${keyFile}" "${testFile}" "${sigFile}"
    assertFile "${sigFile}"
    verifyFileSignature "${keyFile}" "${testFile}" "${sigFile}"
}

source rayvn.up 'rayvn/test' 'valt/sign'
main "$@"
