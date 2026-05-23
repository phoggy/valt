#!/usr/bin/env bash

main() {
    init "$@"

    testDecryptFile
    testDecryptToOutput
    testDecryptStdin
    testDecryptPassphrase
    testRoundTripMultiLine

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
    declare -g testKeyDir pubFile keyFile testText testFile encryptedFile
    testKeyDir="${ makeTempDir; }"
    createValtKeys 'test' "${testKeyDir}" pubFile keyFile
    testText='The quick brown fox jumps over the lazy dog.'
    testFile="${ makeTempFile test.txt; }"
    echo "${testText}" > "${testFile}"
    encryptedFile="${ makeTempFile test.age; }"
    encrypt "${testFile}" -R "${pubFile}" -o "${encryptedFile}"
}

testDecryptFile() {
    local decrypted
    decrypted="${ decrypt -i "${keyFile}" "${encryptedFile}"; }"
    assertEqual "${testText}" "${decrypted}"
}

testDecryptToOutput() {
    local outFile; outFile="${ makeTempFile; }"
    decrypt -i "${keyFile}" "${encryptedFile}" -o "${outFile}"
    local content; readFile "${outFile}" content
    assertContains "${testText}" "${content}"
}

testDecryptStdin() {
    local outFile; outFile="${ makeTempFile; }"
    cat "${encryptedFile}" | decrypt -i "${keyFile}" -o "${outFile}"
    local content; readFile "${outFile}" content
    assertContains "${testText}" "${content}"
}

testDecryptPassphrase() {
    local phraseEncFile; phraseEncFile="${ makeTempFile; }"
    encrypt "${testFile}" -p -o "${phraseEncFile}"
    local decrypted
    decrypted="${ decrypt -p "${phraseEncFile}"; }"
    assertEqual "${testText}" "${decrypted}"
}

testRoundTripMultiLine() {
    local original
    original='Line 1: "quotes", $VARS, & <special> chars'
    original+=$'\nLine 2: unicode — em dash and café'
    original+=$'\nLine 3: trailing'
    local encFile; encFile="${ makeTempFile; }"
    echo "${original}" | encrypt -R "${pubFile}" -o "${encFile}"
    local result
    result="${ decrypt -i "${keyFile}" "${encFile}"; }"
    assertEqual "${original}" "${result}"
}

source rayvn.up 'rayvn/test' 'valt/keys'
main "$@"
