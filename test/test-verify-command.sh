#!/usr/bin/env bash

main() {
    init "$@"

    testVerifyDefaultPublicKey
    testVerifyWithoutPublicKey
    testVerifyMismatchedPublicKey
    testVerifyWrongPassphrase
    testVerifyArchive
    testVerifyArchiveFromAnotherKey
    testVerifyRejectsOtherFiles

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
    newValtKeys 'test' "${keyDir}" pubFile keyFile
    newValtKeys 'other' "${keyDir}" otherPubFile otherKeyFile
}

# Creates a secure archive signed with the given key, setting the named var to its path.

newArchive() {
    local -n archiveRef=$1
    local signingKey="$2" recipientFile="$3"
    local inputDir; inputDir="${ makeTempDir; }"
    echo 'content' > "${inputDir}/file.txt"
    local outputDir; outputDir="${ makeTempDir; }"
    archiveRef="${ newSecureArchive -C "${inputDir}" file.txt -i "${signingKey}" -R "${recipientFile}" -n test -o "${outputDir}"; }"
}

testVerifyDefaultPublicKey() {
    local output; output="${ valt verify -i "${keyFile}" 2>&1; }"
    assertEqual 0 $? "verify must succeed: ${output}"
    assertContains "decrypts with its passphrase" "${output}"
    assertContains "test.pub matches the private key" "${output}"
}

testVerifyWithoutPublicKey() {
    local dir; dir="${ makeTempDir; }"
    cp "${keyFile}" "${dir}/lonely.key" || fail
    local output; output="${ valt verify -i "${dir}/lonely.key" 2>&1; }"
    assertEqual 0 $? "verify of a key with no public key must succeed: ${output}"
    assertContains "decrypts with its passphrase" "${output}"
    assertContains "No public key was found" "${output}"
}

testVerifyMismatchedPublicKey() {
    local output; output="${ valt verify -i "${keyFile}" "${otherPubFile}" 2>&1; }"
    assertNotEqual 0 $? "verify against another public key must fail"
    assertContains "does not match" "${output}"
}

testVerifyWrongPassphrase() {
    local output; output="${ rayvnTest_ValtKeyPassphrase='wrong-passphrase' valt verify -i "${keyFile}" 2>&1; }"
    assertNotEqual 0 $? "verify with the wrong passphrase must fail"
    assertContains "incorrect passphrase" "${output}"
}

testVerifyArchive() {
    local archive; newArchive archive "${keyFile}" "${pubFile}"
    local output; output="${ valt verify -i "${keyFile}" "${archive}" 2>&1; }"
    assertEqual 0 $? "verify of an archive must succeed: ${output}"
    assertContains "matches the private key" "${output}"
    assertContains "Signatures verified for" "${output}"
}

testVerifyArchiveFromAnotherKey() {
    local archive; newArchive archive "${otherKeyFile}" "${pubFile}"
    local output; output="${ valt verify -i "${keyFile}" "${archive}" 2>&1; }"
    assertNotEqual 0 $? "verify of an archive signed with another key must fail"
    [[ ${output} != *"Signatures verified"* ]] || fail "an archive signed with another key must not verify"
}

testVerifyRejectsOtherFiles() {
    local file; file="${ makeTempFile notes.txt; }"
    local output; output="${ valt verify -i "${keyFile}" "${file}" 2>&1; }"
    assertContains "not a public key (.pub) or secure archive (.valt)" "${output}"
}

source rayvn.up 'rayvn/test' 'valt/keys' 'valt/archive'
main "$@"
