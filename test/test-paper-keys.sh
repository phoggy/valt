#!/usr/bin/env bash

main() {
    init "$@"

    # isKeyInfoComplete
    testIsKeyInfoCompleteCreatesMissingFile
    testIsKeyInfoCompleteTemplateIsIncomplete
    testIsKeyInfoCompleteWhenCompleted

    # paperKeyCommand
    testPaperKeyCommandDefaultKey
    testPaperKeyCommandOtherKey

    # remindPaperKey
    testRemindIgnoresNonValtKey
    testRemindMissingPaperKey
    testRemindCurrentPaperKey
    testRemindKeyNewerThanPaperKey
    testRemindKeyInfoNewerThanPaperKey

    # paper command
    testPaperGeneratesPdf
    testPaperReplacesPdf
    testPaperUsesTemplate
    testPaperIncompleteKeyInfo
    testPaperRejectsNameAndKeyFile
    testPaperMissingKeyFile

    # keys command
    testKeysDefaultName
    testKeysDefersPdfWhenKeyInfoIncomplete
    testKeysVersion
    testKeysHelp

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

    declare -g testDir keyFile pubFile incompleteInfoFile completedInfoFile
    testDir="${ makeTempDir; }"
    newValtKeys 'test' "${testDir}" pubFile keyFile

    incompleteInfoFile="${testDir}/incomplete.info"
    cp "${valtHome}/etc/key-info-template.sh" "${incompleteInfoFile}" || fail
    completedInfoFile="${testDir}/completed.info"
    gsed "s/^completed=.*/completed='yes'/" "${incompleteInfoFile}" > "${completedInfoFile}" || fail
}

# Copies the test key into a new directory, so that each test has its own paper key path.

newKeyCopy() {
    local -n keyCopyRef=$1
    local dir; dir="${ makeTempDir; }"
    cp "${keyFile}" "${dir}/test.key" || fail
    keyCopyRef="${dir}/test.key"
}

# Sets file modification times from YYYYMMDDhhmm values, in order: key, key.info, paper key.

setTimes() {
    local key="$1" info="$2" pdf="$3"
    touch -t "$4" "${key}" || fail
    touch -t "$5" "${info}" || fail
    touch -t "$6" "${pdf}" || fail
}

# ---- isKeyInfoComplete ----

testIsKeyInfoCompleteCreatesMissingFile() {
    local infoFile="${testDir}/missing.info"
    assertFalse "missing key.info must be incomplete" isKeyInfoComplete "${infoFile}"
    assertFile "${infoFile}"
    assertInFile "completed=" "${infoFile}"
}

testIsKeyInfoCompleteTemplateIsIncomplete() {
    assertFalse "template key.info must be incomplete" isKeyInfoComplete "${incompleteInfoFile}"
}

testIsKeyInfoCompleteWhenCompleted() {
    unset completed author
    assertTrue "completed key.info must be complete" isKeyInfoComplete "${completedInfoFile}"
    assertVarIsNotDefined completed
    assertVarIsNotDefined author
}

# ---- paperKeyCommand ----

testPaperKeyCommandDefaultKey() {
    local command; command="${ paperKeyCommand "${valtConfigDir}/valt.key"; }"
    assertEqual 'paper' "${command}"
}

testPaperKeyCommandOtherKey() {
    local command; command="${ paperKeyCommand "${keyFile}"; }"
    assertEqual "paper ${ tildePath "${keyFile}"; }" "${command}"
}

# ---- remindPaperKey ----

testRemindIgnoresNonValtKey() {
    local file="${testDir}/not-a-key.txt"
    echo 'hello' > "${file}"
    local output; output="${ remindPaperKey "${file}" 2>&1; }"
    assertEqual 0 $? "remindPaperKey must succeed"
    assertEqual '' "${output}"
}

testRemindMissingPaperKey() {
    local key; newKeyCopy key
    local output; output="${ remindPaperKey "${key}" "${completedInfoFile}" 2>&1; }"
    assertEqual 0 $? "remindPaperKey must succeed"
    assertContains "No paper key backup exists" "${output}"
    assertContains "${ paperKeyCommand "${key}"; }" "${output}"
}

testRemindCurrentPaperKey() {
    local key; newKeyCopy key
    local pdf; pdf="${ _paperKeyFile "${key}"; }"
    local info="${testDir}/current.info"
    cp "${completedInfoFile}" "${info}" || fail
    setTimes "${key}" "${info}" "${pdf}" 202001010000 202001020000 202001030000
    local output; output="${ remindPaperKey "${key}" "${info}" 2>&1; }"
    assertEqual 0 $? "remindPaperKey must succeed when the paper key is current"
    assertEqual '' "${output}"
}

testRemindKeyNewerThanPaperKey() {
    local key; newKeyCopy key
    local pdf; pdf="${ _paperKeyFile "${key}"; }"
    local info="${testDir}/key-newer.info"
    cp "${completedInfoFile}" "${info}" || fail
    setTimes "${key}" "${info}" "${pdf}" 202001040000 202001010000 202001030000
    local output; output="${ remindPaperKey "${key}" "${info}" 2>&1; }"
    assertContains "is older than the key" "${output}"
}

testRemindKeyInfoNewerThanPaperKey() {
    local key; newKeyCopy key
    local pdf; pdf="${ _paperKeyFile "${key}"; }"
    local info="${testDir}/info-newer.info"
    cp "${completedInfoFile}" "${info}" || fail
    setTimes "${key}" "${info}" "${pdf}" 202001010000 202001040000 202001030000
    local output; output="${ remindPaperKey "${key}" "${info}" 2>&1; }"
    assertContains "key.info has changed" "${output}"
}

# ---- paper command ----

testPaperGeneratesPdf() {
    declare -g paperTestKey; newKeyCopy paperTestKey
    local output; output="${ paper -k "${completedInfoFile}" "${paperTestKey}" 2>&1; }"
    assertEqual 0 $? "paper must succeed: ${output}"
    assertFile "${ _paperKeyFile "${paperTestKey}"; }"
    assertContains "Paper key file:" "${output}"
    [[ ${output} != *"previous paper key was replaced"* ]] || fail "first paper key must not report a replacement"
}

testPaperReplacesPdf() {
    local output; output="${ paper -k "${completedInfoFile}" "${paperTestKey}" 2>&1; }"
    assertEqual 0 $? "paper must succeed: ${output}"
    assertContains "previous paper key was replaced" "${output}"
}

testPaperUsesTemplate() {
    local key; newKeyCopy key
    local template="${testDir}/template.html"
    echo '<html><body>${UNDEFINED_TEST_VAR}</body></html>' > "${template}"
    local output; output="${ paper -k "${completedInfoFile}" -t "${template}" "${key}" 2>&1; }"
    assertContains "UNDEFINED_TEST_VAR not set in" "${output}" "custom template must be used"
}

testPaperIncompleteKeyInfo() {
    local key; newKeyCopy key
    local output; output="${ paper -k "${incompleteInfoFile}" "${key}" 2>&1; }"
    assertContains "has not been completed" "${output}"
    assertFileDoesNotExist "${ _paperKeyFile "${key}"; }"
}

testPaperRejectsNameAndKeyFile() {
    local output; output="${ paper -n test "${keyFile}" 2>&1; }"
    assertContains "not both" "${output}"
}

testPaperMissingKeyFile() {
    local output; output="${ paper "${testDir}/missing.key" 2>&1; }"
    assertContains "not found" "${output}"
}

# ---- keys command ----

testKeysDefaultName() {
    local dir; dir="${ makeTempDir; }"
    local output; output="${ keys -o "${dir}" -q --no-pdf 2>&1; }"
    assertEqual 0 $? "keys must succeed: ${output}"
    assertFile "${dir}/valt.key"
    assertFile "${dir}/valt.pub"
}

testKeysDefersPdfWhenKeyInfoIncomplete() {
    local dir; dir="${ makeTempDir; }"
    local output; output="${ keys -n test -o "${dir}" -q -k "${incompleteInfoFile}" 2>&1; }"
    assertEqual 0 $? "keys must succeed: ${output}"
    assertFile "${dir}/test.key"
    assertFileDoesNotExist "${dir}/test-key.pdf"
    assertContains "Paper key not generated" "${output}"
    assertContains "paper ${ tildePath "${dir}/test.key"; } -k ${ tildePath "${incompleteInfoFile}"; }" "${output}"
}

testKeysVersion() {
    local output; output="${ keys -v 2>&1; }"
    assertEqual 0 $? "keys -v must succeed: ${output}"
    assertContains "valt " "${output}"
}

testKeysHelp() {
    local output; output="${ keys --help 2>&1; }"
    assertContains "Print the version." "${output}"
    assertContains "-q, --quick" "${output}"
}

source rayvn.up 'rayvn/test' 'valt/paper-keys'
main "$@"
