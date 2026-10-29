#!/usr/bin/env bash

main() {
    init "$@"

    # encrypt
    testEncryptDefaults
    testEncryptRecipientBeforeFile
    testEncryptRecipientFiles
    testEncryptNoSelf
    testEncryptNoSelfRequiresRecipient
    testEncryptMissingSelfPublicKey
    testEncryptRejectsDirectory
    testEncryptRefusesExistingOutput
    testEncryptForceOverwrites
    testEncryptNoSign
    testEncryptStandardOutput
    testEncryptStandardOutputRequiresNoSign
    testEncryptArmor
    testEncryptVerifyAndDelete
    testEncryptDeleteRequiresVerify
    testEncryptVerifyRejectsNoSelf

    # archive
    testArchiveRequiresSubcommand
    testArchiveCreateRequiresInput
    testArchiveCreateVerifyExtract

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

    declare -g keyDir pubFile keyFile otherPubFile otherKeyFile otherRecipient
    keyDir="${ makeTempDir; }"
    newValtKeys 'test' "${keyDir}" pubFile keyFile
    newValtKeys 'other' "${keyDir}" otherPubFile otherKeyFile
    otherRecipient="${ recipient "${otherPubFile}"; }"
}

# Creates secret.txt in a new directory, setting the named var to its path.

newPlainFile() {
    local -n plainFileRef=$1
    local dir; dir="${ makeTempDir; }"
    echo 'secret content' > "${dir}/secret.txt"
    plainFileRef="${dir}/secret.txt"
}

# Succeeds if keyFile decrypts encryptedFile to 'secret content'.

decryptsWith() {
    local keyFile="$1" encryptedFile="$2"
    local decrypted; decrypted="${ ( decrypt -i "${keyFile}" "${encryptedFile}" ) 2> /dev/null; }" || return 1
    [[ ${decrypted} == 'secret content' ]]
}

# ---- encrypt ----

testEncryptDefaults() {
    local file; newPlainFile file
    local output; output="${ valt encrypt -i "${keyFile}" "${file}" 2>&1; }"
    assertEqual 0 $? "encrypt must succeed: ${output}"
    assertFile "${file}.age"
    assertFile "${file}.age.minisig"
    assertFile "${file}"
    assertTrue "self must be a recipient by default" decryptsWith "${keyFile}" "${file}.age"
    assertTrue "signature must verify with own key" verifyFileSignature "${keyFile}" "${file}.age"

    rm "${file}" || fail
    output="${ valt decrypt -i "${keyFile}" "${file}.age" 2>&1; }"
    assertEqual 0 $? "valt decrypt must succeed: ${output}"
    [[ ${output} != *"No signature found"* ]] || fail "signed file must not warn about a missing signature"
    assertEqual 'secret content' "${ cat "${file}"; }"
}

testEncryptRecipientBeforeFile() {
    local file; newPlainFile file
    local output; output="${ valt encrypt -i "${keyFile}" -r "${otherRecipient}" "${file}" 2>&1; }"
    assertEqual 0 $? "encrypt with -r before FILE must succeed: ${output}"
    assertTrue "self must be a recipient" decryptsWith "${keyFile}" "${file}.age"
    assertTrue "-r recipient must be a recipient" decryptsWith "${otherKeyFile}" "${file}.age"
}

testEncryptRecipientFiles() {
    local file; newPlainFile file
    local output; output="${ valt encrypt -i "${keyFile}" --no-self -R "${pubFile}" -R "${otherPubFile}" "${file}" 2>&1; }"
    assertEqual 0 $? "encrypt with repeated -R must succeed: ${output}"
    assertTrue "first -R must be a recipient" decryptsWith "${keyFile}" "${file}.age"
    assertTrue "second -R must be a recipient" decryptsWith "${otherKeyFile}" "${file}.age"
}

testEncryptNoSelf() {
    local file; newPlainFile file
    local output; output="${ valt encrypt -i "${keyFile}" --no-self -r "${otherRecipient}" "${file}" 2>&1; }"
    assertEqual 0 $? "encrypt --no-self must succeed: ${output}"
    assertFalse "self must not be a recipient" decryptsWith "${keyFile}" "${file}.age"
    assertTrue "-r recipient must be a recipient" decryptsWith "${otherKeyFile}" "${file}.age"
    assertTrue "--no-self must still sign with the identity" verifyFileSignature "${keyFile}" "${file}.age"
}

testEncryptNoSelfRequiresRecipient() {
    local file; newPlainFile file
    local output; output="${ valt encrypt -i "${keyFile}" --no-self "${file}" 2>&1; }"
    assertContains "requires at least one --recipient" "${output}"
    assertFileDoesNotExist "${file}.age"
}

testEncryptMissingSelfPublicKey() {
    local dir; dir="${ makeTempDir; }"
    cp "${keyFile}" "${dir}/lonely.key" || fail
    local file; newPlainFile file
    local output; output="${ valt encrypt -i "${dir}/lonely.key" "${file}" 2>&1; }"
    assertContains "No public key found" "${output}"
}

testEncryptRejectsDirectory() {
    local dir; dir="${ makeTempDir; }"
    local output; output="${ valt encrypt -i "${keyFile}" "${dir}" 2>&1; }"
    assertContains "valt archive create" "${output}"
}

testEncryptRefusesExistingOutput() {
    local file; newPlainFile file
    echo 'existing' > "${file}.age"
    local output; output="${ valt encrypt -i "${keyFile}" "${file}" 2>&1; }"
    assertContains "already exists" "${output}"
    assertEqual 'existing' "${ cat "${file}.age"; }"
}

testEncryptForceOverwrites() {
    local file; newPlainFile file
    echo 'existing' > "${file}.age"
    echo 'existing' > "${file}.age.minisig"
    local output; output="${ valt encrypt -f -i "${keyFile}" "${file}" 2>&1; }"
    assertEqual 0 $? "encrypt --force must succeed: ${output}"
    assertTrue "forced output must decrypt" decryptsWith "${keyFile}" "${file}.age"
    assertTrue "forced signature must verify" verifyFileSignature "${keyFile}" "${file}.age"
}

testEncryptNoSign() {
    local file; newPlainFile file
    local output; output="${ valt encrypt -i "${keyFile}" --no-sign "${file}" 2>&1; }"
    assertEqual 0 $? "encrypt --no-sign must succeed: ${output}"
    assertFile "${file}.age"
    assertFileDoesNotExist "${file}.age.minisig"
}

testEncryptStandardOutput() {
    local file; newPlainFile file
    local dir; dir="${ makeTempDir; }"
    valt encrypt -i "${keyFile}" --no-sign -o - "${file}" > "${dir}/piped.age" 2> /dev/null || fail "encrypt to stdout failed"
    assertTrue "stdout output must decrypt" decryptsWith "${keyFile}" "${dir}/piped.age"
    assertFileDoesNotExist "${file}.age"
}

testEncryptStandardOutputRequiresNoSign() {
    local file; newPlainFile file
    local output; output="${ valt encrypt -i "${keyFile}" -o - "${file}" 2>&1; }"
    assertContains "Signing requires an output file" "${output}"
}

testEncryptArmor() {
    local file; newPlainFile file
    local output; output="${ valt encrypt -i "${keyFile}" --armor "${file}" 2>&1; }"
    assertEqual 0 $? "encrypt --armor must succeed: ${output}"
    assertEqual '-----BEGIN AGE ENCRYPTED FILE-----' "${ head -n 1 "${file}.age"; }"
    assertTrue "armored output must decrypt" decryptsWith "${keyFile}" "${file}.age"
}

testEncryptVerifyAndDelete() {
    local file; newPlainFile file
    local output; output="${ valt encrypt -i "${keyFile}" --verify --delete "${file}" 2>&1; }"
    assertEqual 0 $? "encrypt --verify --delete must succeed: ${output}"
    assertContains "Verified" "${output}"
    assertFileDoesNotExist "${file}"
    assertTrue "verified output must decrypt" decryptsWith "${keyFile}" "${file}.age"
}

testEncryptDeleteRequiresVerify() {
    local file; newPlainFile file
    local output; output="${ valt encrypt -i "${keyFile}" --delete "${file}" 2>&1; }"
    assertContains "--delete requires --verify" "${output}"
    assertFile "${file}"
}

testEncryptVerifyRejectsNoSelf() {
    local file; newPlainFile file
    local output; output="${ valt encrypt -i "${keyFile}" --verify --no-self -r "${otherRecipient}" "${file}" 2>&1; }"
    assertContains "--verify cannot be combined with --no-self" "${output}"
}

# ---- archive ----

testArchiveRequiresSubcommand() {
    local output; output="${ valt archive 2>&1; }"
    assertContains "archive requires a subcommand" "${output}"
}

testArchiveCreateRequiresInput() {
    local output; output="${ valt archive create -i "${keyFile}" 2>&1; }"
    assertContains "missing required argument: INPUT" "${output}"
}

testArchiveCreateVerifyExtract() {
    local inputDir; inputDir="${ makeTempDir; }"
    echo 'first' > "${inputDir}/a.txt"
    mkdir "${inputDir}/sub" || fail
    echo 'nested' > "${inputDir}/sub/b.txt"
    local archiveDir; archiveDir="${ makeTempDir; }"

    local output; output="${ valt archive create -i "${keyFile}" -C "${inputDir}" a.txt sub -n test -o "${archiveDir}" 2>&1; }"
    assertEqual 0 $? "archive create must succeed: ${output}"
    assertContains "Created secure archive" "${output}"
    local archive; archive="${ ls "${archiveDir}"/test-*.valt; }"
    assertFile "${archive}"
    assertFile "${archive}.pub"

    output="${ valt archive verify -i "${keyFile}" "${archive}" 2>&1; }"
    assertEqual 0 $? "archive verify must succeed: ${output}"
    assertContains "Signatures verified" "${output}"

    local destDir; destDir="${ makeTempDir; }"
    output="${ valt archive extract -i "${keyFile}" -o "${destDir}" "${archive}" 2>&1; }"
    assertEqual 0 $? "archive extract must succeed: ${output}"
    assertEqual 'first' "${ cat "${destDir}/a.txt"; }"
    assertEqual 'nested' "${ cat "${destDir}/sub/b.txt"; }"
}

source rayvn.up 'rayvn/test' 'valt/keys' 'valt/sign'
main "$@"
