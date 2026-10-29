#!/usr/bin/env bash

main() {
    init "$@"

    # Single files
    testDecryptDefaultOutputName
    testDecryptWarnsWithoutSignature
    testDecryptRefusesExistingOutput
    testDecryptForceOverwrites
    testDecryptToStandardOutput
    testDecryptRequiresOutputForOtherNames
    testDecryptVerifiesSignature
    testDecryptFailsOnForeignSignature
    testDecryptRemindsPaperKey

    # Archives
    testDecryptExtractsArchive

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
    skipReadPasswordStrength=1

    declare -g keyDir pubFile keyFile otherPubFile otherKeyFile
    keyDir="${ makeTempDir; }"
    newValtKeys 'test' "${keyDir}" pubFile keyFile
    newValtKeys 'other' "${keyDir}" otherPubFile otherKeyFile
}

# Creates FILE.age in a new directory, encrypted to the test key, setting the named var to its path.

newEncryptedFile() {
    local -n encryptedFileRef=$1
    local dir; dir="${ makeTempDir; }"
    echo 'secret content' > "${dir}/secret.txt"
    encrypt "${dir}/secret.txt" -R "${pubFile}" -o "${dir}/secret.txt.age" || fail
    rm "${dir}/secret.txt" || fail
    encryptedFileRef="${dir}/secret.txt.age"
}

testDecryptDefaultOutputName() {
    local file; newEncryptedFile file
    local output; output="${ valt decrypt -i "${keyFile}" "${file}" 2>&1; }"
    assertEqual 0 $? "decrypt must succeed: ${output}"
    assertEqual 'secret content' "${ cat "${file%.age}"; }"
    assertContains "Decrypted" "${output}"
}

testDecryptWarnsWithoutSignature() {
    local file; newEncryptedFile file
    local output; output="${ valt decrypt -i "${keyFile}" "${file}" 2>&1; }"
    assertContains "No signature found" "${output}"
}

testDecryptRefusesExistingOutput() {
    local file; newEncryptedFile file
    echo 'existing' > "${file%.age}"
    local output; output="${ valt decrypt -i "${keyFile}" "${file}" 2>&1; }"
    assertContains "already exists" "${output}"
    assertEqual 'existing' "${ cat "${file%.age}"; }"
}

testDecryptForceOverwrites() {
    local file; newEncryptedFile file
    echo 'existing' > "${file%.age}"
    local output; output="${ valt decrypt -f -i "${keyFile}" "${file}" 2>&1; }"
    assertEqual 0 $? "decrypt --force must succeed: ${output}"
    assertEqual 'secret content' "${ cat "${file%.age}"; }"
}

testDecryptToStandardOutput() {
    local file; newEncryptedFile file
    local output; output="${ valt decrypt -i "${keyFile}" -o - "${file}" 2> /dev/null; }"
    assertEqual 'secret content' "${output}"
    assertFileDoesNotExist "${file%.age}"
}

testDecryptRequiresOutputForOtherNames() {
    local file; newEncryptedFile file
    local renamed="${file%.age}.enc"
    mv "${file}" "${renamed}" || fail
    local output; output="${ valt decrypt -i "${keyFile}" "${renamed}" 2>&1; }"
    assertContains "use --output" "${output}"
}

testDecryptVerifiesSignature() {
    local file; newEncryptedFile file
    signFile "${keyFile}" "${file}"
    local output; output="${ valt decrypt -i "${keyFile}" "${file}" 2>&1; }"
    assertEqual 0 $? "decrypt must succeed with a valid signature: ${output}"
    [[ ${output} != *"No signature found"* ]] || fail "signed file must not warn about a missing signature"
    assertEqual 'secret content' "${ cat "${file%.age}"; }"
}

testDecryptFailsOnForeignSignature() {
    local file; newEncryptedFile file
    signFile "${otherKeyFile}" "${file}"
    local output; output="${ valt decrypt -i "${keyFile}" "${file}" 2>&1; }"
    assertContains "Signature verification failed" "${output}"
    assertFileDoesNotExist "${file%.age}"
}

testDecryptRemindsPaperKey() {
    local file; newEncryptedFile file
    local output; output="${ valt decrypt -i "${keyFile}" "${file}" 2>&1; }"
    assertContains "No paper key backup exists" "${output}"
}

testDecryptExtractsArchive() {
    local inputDir; inputDir="${ makeTempDir; }"
    echo 'archived content' > "${inputDir}/file1.txt"
    local archiveDir; archiveDir="${ makeTempDir; }"
    local archive; archive="${ newSecureArchive -C "${inputDir}" file1.txt -i "${keyFile}" -R "${pubFile}" -n test -o "${archiveDir}"; }"
    local destDir; destDir="${ makeTempDir; }"
    local output; output="${ valt decrypt -i "${keyFile}" -o "${destDir}" "${archive}" 2>&1; }"
    assertEqual 0 $? "archive decrypt must succeed: ${output}"
    assertContains "secure archive" "${output}"
    assertEqual 'archived content' "${ cat "${destDir}/file1.txt"; }"
}

source rayvn.up 'rayvn/test' 'valt/keys' 'valt/archive'
main "$@"
