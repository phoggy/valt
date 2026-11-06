#!/usr/bin/env bash

# Operations that decrypt the private key more than once (verifying signatures and decrypting) must ask for its
# passphrase only once. readPassword is replaced to count the prompts, so functions must be modifiable.

main() {
    init "$@"

    testExtractPromptsOnce
    testVerifyPromptsOnce
    testCreatePromptsOnce
    testWrongPassphraseAsksAgain
    testThreeWrongPassphrasesFail

    return 0
}

init() {
    while (( $# )); do
        case "$1" in
            --debug*) setDebug "$@"; shift $? ;;
        esac
        shift
    done

    declare -g passphrase='valt-test-passphrase-12345'
    declare -gx rayvnTest_ValtKeyPassphrase="${passphrase}"
    skipKeyPassphraseAdvice=1
    allowWeakKeyPassphrase=1

    declare -g keyDir pubFile keyFile inputDir archive
    keyDir="${ makeTempDir; }"
    newValtKeys 'test' "${keyDir}" pubFile keyFile
    inputDir="${ makeTempDir; }"
    echo 'content' > "${inputDir}/file.txt"
    archive="${ newSecureArchive -C "${inputDir}" file.txt -i "${keyFile}" -R "${pubFile}" -n test -o "${ makeTempDir; }"; }"
    unset rayvnTest_ValtKeyPassphrase

    # Count prompts in a file (some are made in subshells, such as a pipeline), answering each with the passphrase

    declare -g promptLog; promptLog="${ makeTempFile; }"
    # Answers each prompt with the next of the answers in answersFile (one per line), or the passphrase when none are
    # left

    declare -g answersFile; answersFile="${ makeTempFile; }"
    readPassword() {
        local -n _passwordRef=$2
        echo 'prompt' >> "${promptLog}"
        local answer; answer="${ head -n 1 "${answersFile}"; }"
        gsed -i '1d' "${answersFile}"
        _passwordRef="${answer:-${passphrase}}"
    }
}

resetPromptCount() {
    : > "${promptLog}"
    : > "${answersFile}"
}

assertPromptedOnce() {
    local count; count="${ wc -l < "${promptLog}" | tr -d ' '; }"
    assertEqual 1 "${count}" "$1 must ask for the passphrase once"
}

testExtractPromptsOnce() {
    resetPromptCount
    local destDir; destDir="${ makeTempDir; }"
    extractSecureArchive -i "${keyFile}" -o "${destDir}" "${archive}" > /dev/null 2>&1 || fail "extract failed"
    assertEqual 'content' "${ cat "${destDir}/file.txt"; }"
    assertPromptedOnce extract
}

testVerifyPromptsOnce() {
    resetPromptCount
    verifySecureArchive -i "${keyFile}" "${archive}" > /dev/null 2>&1 || fail "verify failed"
    assertPromptedOnce verify
}

testCreatePromptsOnce() {
    resetPromptCount
    local outputDir; outputDir="${ makeTempDir; }"
    newSecureArchive -C "${inputDir}" file.txt -i "${keyFile}" -R "${pubFile}" -n test -o "${outputDir}" > /dev/null 2>&1 \
        || fail "create failed"
    assertPromptedOnce create
}

# A mistyped passphrase is caught when entered, and asked for again, up to 3 times

testWrongPassphraseAsksAgain() {
    resetPromptCount
    echo 'not the passphrase' > "${answersFile}"
    local output; output="${ ( _prepareKey "${keyFile}"; echo "unlocked: ${rayvnTest_ValtKeyPassphrase}" ) 2>&1; }"
    assertContains "Incorrect passphrase; try again." "${output}"
    assertContains "unlocked: ${passphrase}" "${output}"
    assertEqual 2 "${ wc -l < "${promptLog}" | tr -d ' '; }" "a wrong passphrase must be asked for again, once"
}

testThreeWrongPassphrasesFail() {
    resetPromptCount
    printf '%s\n' wrong1 wrong2 wrong3 > "${answersFile}"
    local output; output="${ ( _prepareKey "${keyFile}"; echo 'unlocked' ) 2>&1; }"
    assertNotEqual 0 $? "three wrong passphrases must fail"
    assertContains "incorrect passphrase for" "${output}"
    [[ ${output} != *unlocked* ]] || fail "the key must not be unlocked: ${output}"
    assertEqual 3 "${ wc -l < "${promptLog}" | tr -d ' '; }" "the passphrase must be asked for 3 times"
}

rayvnTest_ModifiableFunctions=1
source rayvn.up 'rayvn/test' 'valt/keys' 'valt/archive'
main "$@"
