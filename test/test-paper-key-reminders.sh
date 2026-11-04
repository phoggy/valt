#!/usr/bin/env bash

# The printed and stored questions that remindPaperKey asks, with answers given by rayvnTest_PaperKeyAnswers. HOME is a
# temp dir, so that the answers are recorded there rather than in the real valt config.

main() {
    init "$@"

    testAsksPrintedThenStored
    testPrintedThenRemindAsksTheRest
    testNotedThenRemindAsksStoredOnly
    testRemindPostpones
    testNoAnswerRemindsTomorrow
    testRemindZeroDaysAsksNextTime
    testStopAsking
    testRegeneratedPaperKeyAsksAgain
    testNoQuestionsWithoutTerminal
    testNoQuestionsForOutOfDatePaperKey
    testEncryptAsks
    testAnyCommandAsks
    testCommandAsksAboutDefaultKeyOnly
    testNoRemindersWhenDisabled
    testClearPaperKeyState

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

# Sets up a key copy with a current paper key (a stand-in PDF newer than the key and key.info), setting the named vars
# to the key, key.info and PDF paths.

newPaperKeySetup() {
    local -n setupKeyRef=$1
    local -n setupInfoRef=$2
    local -n setupPdfRef=$3
    local dir; dir="${ makeTempDir; }"
    cp "${keyFile}" "${dir}/test.key" || fail
    cp "${pubFile}" "${dir}/test.pub" || fail
    echo "completed='yes'" > "${dir}/key.info"
    echo "paper key ${dir}" > "${dir}/test-key.pdf"
    touch -t 202001010000 "${dir}/test.key" "${dir}/test.pub" "${dir}/key.info" || fail
    setupKeyRef="${dir}/test.key"
    setupInfoRef="${dir}/key.info"
    setupPdfRef="${ _paperKeyFile "${dir}/test.key"; }" # the path as valt records it (symlinks resolved)
}

# Runs remindPaperKey with the given answers (separated by spaces), setting the named var to its output and
# leftoverRef to any answers it did not use.

remindWith() {
    local -n remindOutputRef=$1
    local -n remindLeftoverRef=$2
    local answers="$3" key="$4" info="$5"
    declare -g rayvnTest_PaperKeyAnswers="${answers}"
    remindOutputRef="${ remindPaperKey "${key}" "${info}" 2>&1; }"
    remindOutputRef="${ stripAnsi "${remindOutputRef}"; }" # compare the text, not its styling
    remindLeftoverRef="${rayvnTest_PaperKeyAnswers}"
    unset rayvnTest_PaperKeyAnswers
}

assertState() {
    local pdf="$1" expected="$2"
    local state remindAfter
    _readPaperKeyState "${pdf}" state remindAfter
    assertEqual "${expected}" "${state}" "paper key state is '${state}', not '${expected}', in ${FUNCNAME[1]}"
}

# Fails unless the reminder is due about the given number of days from now.

assertRemindInDays() {
    local pdf="$1" days=$2
    local state remindAfter
    _readPaperKeyState "${pdf}" state remindAfter
    local expected=$(( EPOCHSECONDS + days * 86400 ))
    (( remindAfter >= expected - 60 && remindAfter <= expected + 60 )) \
        || fail "the reminder must be due in ${days} days: ${remindAfter} vs ${expected}"
}

testAsksPrintedThenStored() {
    local key info pdf output leftover; newPaperKeySetup key info pdf
    remindWith output leftover 'yes yes yes' "${key}" "${info}"
    assertEqual '' "${leftover}" "all three questions must be asked"
    assertContains "ready if ever needed" "${output}"
    assertState "${pdf}" stored

    remindWith output leftover 'yes' "${key}" "${info}"
    assertEqual 'yes' "${leftover}" "a stored paper key must not be asked about"
}

testPrintedThenRemindAsksTheRest() {
    local key info pdf output leftover; newPaperKeySetup key info pdf
    remindWith output leftover 'yes remind:2' "${key}" "${info}"
    assertContains "the next time you use valt after 2 days." "${output}"
    assertState "${pdf}" printed
    assertRemindInDays "${pdf}" 2

    remindWith output leftover 'yes' "${key}" "${info}"
    assertEqual 'yes' "${leftover}" "nothing must be asked before the reminder is due"

    _writePaperKeyState "${pdf}" printed 0 # the reminder is now due
    remindWith output leftover 'yes yes' "${key}" "${info}"
    assertEqual '' "${leftover}" "the passphrase and stored questions must be asked"
    assertState "${pdf}" stored
}

testNotedThenRemindAsksStoredOnly() {
    local key info pdf output leftover; newPaperKeySetup key info pdf
    remindWith output leftover 'yes yes remind:1' "${key}" "${info}"
    assertState "${pdf}" noted
    assertRemindInDays "${pdf}" 1

    _writePaperKeyState "${pdf}" noted 0 # the reminder is now due
    remindWith output leftover 'yes yes' "${key}" "${info}"
    assertEqual 'yes' "${leftover}" "only the stored question must be asked"
    assertState "${pdf}" stored
}

testRemindPostpones() {
    local key info pdf output leftover; newPaperKeySetup key info pdf
    remindWith output leftover 'remind:5' "${key}" "${info}"
    assertContains "after 5 days." "${output}"
    assertState "${pdf}" new
    assertRemindInDays "${pdf}" 5
}

testRemindZeroDaysAsksNextTime() {
    local key info pdf output leftover; newPaperKeySetup key info pdf
    remindWith output leftover 'yes remind:0' "${key}" "${info}"
    assertContains "I'll ask again the next time you use valt." "${output}"
    assertState "${pdf}" printed
    remindWith output leftover 'yes yes' "${key}" "${info}"
    assertEqual '' "${leftover}" "0 days must ask again the next time"
    assertState "${pdf}" stored
}

testNoAnswerRemindsTomorrow() {
    local key info pdf output leftover; newPaperKeySetup key info pdf
    remindWith output leftover 'timeout' "${key}" "${info}"
    assertContains "after 1 day." "${output}"
    assertRemindInDays "${pdf}" 1
}

testStopAsking() {
    local key info pdf output leftover; newPaperKeySetup key info pdf
    remindWith output leftover 'stop' "${key}" "${info}"
    assertContains "no more questions about this paper key" "${output}"
    assertState "${pdf}" stopped

    remindWith output leftover 'yes' "${key}" "${info}"
    assertEqual 'yes' "${leftover}" "nothing must be asked once stopped"
}

testRegeneratedPaperKeyAsksAgain() {
    local key info pdf output leftover; newPaperKeySetup key info pdf
    remindWith output leftover 'yes yes yes' "${key}" "${info}"
    assertState "${pdf}" stored

    echo "regenerated" > "${pdf}" # same path, new contents
    assertState "${pdf}" new
    remindWith output leftover 'yes yes yes' "${key}" "${info}"
    assertEqual '' "${leftover}" "a regenerated paper key must be asked about again"
}

testNoQuestionsWithoutTerminal() {
    local key info pdf; newPaperKeySetup key info pdf
    unset rayvnTest_PaperKeyAnswers
    local output; output="${ remindPaperKey "${key}" "${info}" 2>&1 < /dev/null; }"
    assertEqual '' "${output}" "nothing must be asked without a terminal"
    assertState "${pdf}" new
}

testNoQuestionsForOutOfDatePaperKey() {
    local key info pdf output leftover; newPaperKeySetup key info pdf
    touch "${info}" # key.info is now newer than the paper key
    remindWith output leftover 'yes yes' "${key}" "${info}"
    assertEqual 'yes yes' "${leftover}" "an out of date paper key must not be asked about"
    assertContains "key.info has changed" "${output}"
}

# valt encrypt (which signs) asks once it has encrypted the file.

testEncryptAsks() {
    local key info pdf; newPaperKeySetup key info pdf
    local file; file="${ dirName "${key}"; }/secret.txt"
    echo 'secret' > "${file}"
    local output; output="${ VALT_KEY_FILE="${key}" rayvnTest_PaperKeyAnswers='yes remind:3' valt encrypt "${file}" 2>&1; }"
    assertEqual 0 $? "encrypt must succeed: ${output}"
    output="${ stripAnsi "${output}"; }"
    assertFile "${file}.age"
    assertContains "after 3 days." "${output}"
    assertState "${pdf}" printed
}

# Any command asks, not only those that sign: here, generating a passphrase.

testAnyCommandAsks() {
    local key info pdf; newPaperKeySetup key info pdf
    local output; output="${ VALT_KEY_FILE="${key}" rayvnTest_PaperKeyAnswers='remind:4' valt passphrase 2>&1; }"
    assertEqual 0 $? "passphrase must succeed: ${output}"
    assertContains "after 4 days." "${ stripAnsi "${output}"; }"
    assertState "${pdf}" new
}

# Only the default key is asked about: someone recovering files passes another's key with -i.

testCommandAsksAboutDefaultKeyOnly() {
    local key info pdf other otherInfo otherPdf
    newPaperKeySetup key info pdf
    newPaperKeySetup other otherInfo otherPdf
    local output; output="${ VALT_KEY_FILE="${key}" rayvnTest_PaperKeyAnswers='stop' valt verify -i "${other}" 2>&1; }"
    assertEqual 0 $? "verify must succeed: ${output}"
    assertState "${pdf}" stopped
    assertState "${otherPdf}" new
}

testNoRemindersWhenDisabled() {
    local key info pdf; newPaperKeySetup key info pdf
    local output; output="${ VALT_KEY_FILE="${key}" VALT_NO_PAPER_KEY_REMINDERS=1 rayvnTest_PaperKeyAnswers='stop' \
        valt passphrase 2>&1; }"
    assertEqual 0 $? "passphrase must succeed: ${output}"
    assertState "${pdf}" new
}

# Clearing a paper key's answers asks again, and leaves other paper keys' answers.

testClearPaperKeyState() {
    local key info pdf otherKey otherInfo otherPdf output leftover
    newPaperKeySetup key info pdf
    newPaperKeySetup otherKey otherInfo otherPdf
    remindWith output leftover 'stop' "${key}" "${info}"
    remindWith output leftover 'stop' "${otherKey}" "${otherInfo}"
    _clearPaperKeyState "${pdf}"
    assertState "${pdf}" new
    assertState "${otherPdf}" stopped
}

# Use a temp HOME, so that the paper key state file is not the real one

declare -gx HOME; HOME="${ mktemp -d; }"
source rayvn.up 'rayvn/test' 'valt/keys' 'valt/paper-keys'
main "$@"
