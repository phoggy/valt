#!/usr/bin/env bash

main() {
    init "$@"

    testVerifyDefaultPublicKey
    testVerifyWithoutPublicKey
    testVerifyMismatchedPublicKey
    testVerifyWrongPassphrase
    testVerifyArchive
    testVerifyArchiveFromAnotherKey
    testVerifySignedFile
    testVerifyUnsignedArmoredFile
    testVerifyFileForAnotherKey
    testVerifyFileWithBadSignature
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

# Creates a file encrypted to recipientFile, setting the named var to its path. Optional args are passed to encrypt.

newEncryptedFile() {
    local -n encryptedRef=$1
    local recipientFile="$2" name="$3"; shift 3
    local dir; dir="${ makeTempDir; }"
    echo 'secret content' > "${dir}/plain.txt"
    encrypt "${dir}/plain.txt" -R "${recipientFile}" "$@" -o "${dir}/${name}" || fail
    encryptedRef="${dir}/${name}"
}

testVerifySignedFile() {
    local file; newEncryptedFile file "${pubFile}" secret.txt.age
    signFile "${keyFile}" "${file}"
    local output; output="${ valt verify -i "${keyFile}" "${file}" 2>&1; }"
    assertEqual 0 $? "verify of a signed file must succeed: ${output}"
    assertContains "decrypts with the private key, and its signature verifies" "${output}"
}

testVerifyUnsignedArmoredFile() {
    local file; newEncryptedFile file "${pubFile}" secret.enc --armor
    local output; output="${ valt verify -i "${keyFile}" "${file}" 2>&1; }"
    assertEqual 0 $? "verify of an unsigned file must succeed: ${output}"
    assertContains "No signature found" "${output}"
    assertContains "secret.enc decrypts with the private key." "${output}"
}

testVerifyFileForAnotherKey() {
    local file; newEncryptedFile file "${otherPubFile}" other.age
    local output; output="${ valt verify -i "${keyFile}" "${file}" 2>&1; }"
    assertNotEqual 0 $? "verify of a file encrypted to another key must fail"
    [[ ${output} != *"decrypts with the private key"* ]] || fail "a file for another key must not be reported as decrypting"
}

testVerifyFileWithBadSignature() {
    local file; newEncryptedFile file "${pubFile}" signed.age
    signFile "${otherKeyFile}" "${file}"
    local output; output="${ valt verify -i "${keyFile}" "${file}" 2>&1; }"
    assertNotEqual 0 $? "verify of a file signed with another key must fail"
    assertContains "Signature verification failed" "${output}"
}

testVerifyRejectsOtherFiles() {
    local file; file="${ makeTempFile notes.txt; }"
    echo 'plain text' > "${file}"
    local output; output="${ valt verify -i "${keyFile}" "${file}" 2>&1; }"
    assertContains "not a public key (.pub), encrypted file or secure archive (.valt)" "${output}"
}

source rayvn.up 'rayvn/test' 'valt/keys' 'valt/archive' 'valt/encrypt' 'valt/sign'
main "$@"
