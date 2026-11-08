#!/usr/bin/env bash

# Getting the passphrase for a new key (_readNewKeyPassphrase): it asks until the passphrase is strong and confirmed,
# offering generated ones when asked, on no answer, and after a rejected one. readPassword, confirm and bye are replaced
# with scripted ones, so functions must be modifiable. HOME is a temp dir, since the advice counter is in valt's config.

main() {
    init "$@"

    testYesThenStrongPassphrase
    testNoOffersGeneratedPassphrases
    testNoAnswerOffersGeneratedPassphrases
    testWeakPassphraseIsRejected
    testMismatchAsksAgain
    testEmptyEntryCancels
    testCancelledQuestionExits
    testAllowWeakSkipsStrengthCheck
    testAdviceShownOnlyAtFirst
    testPresetPassphraseIsNotEntered

    return 0
}

init() {
    while (( $# )); do
        case "$1" in
            --debug*) setDebug "$@"; shift $? ;;
        esac
        shift
    done
    declare -g strong='repossess thursday flaky lazy'

    # readPassword answers from passwordAnswers, each 'STATUS:VALUE', recording each use case it was asked to check
    # with; confirm answers confirmAnswer (an index) with confirmStatus; bye records its message and ends the subshell

    readPassword() {
        local -n _mockResultRef=$2
        echo "${3:-none}" >> "${useCaseLog}"
        local answer="${passwordAnswers[0]}"
        passwordAnswers=("${passwordAnswers[@]:1}")
        _mockResultRef="${answer#*:}"
        return "${answer%%:*}"
    }
    confirm() {
        local -n _mockChoiceRef=$4
        _mockChoiceRef=${confirmAnswer}
        return ${confirmStatus}
    }
    bye() {
        echo "BYE: $*"
        exit 0
    }
    generatePassphrase() {
        local -n _mockPhraseRef=$1
        _mockPhraseRef='generated words here'
    }
}

# Runs _readNewKeyPassphrase in a subshell, setting the named var to its output and the result, as 'OUTPUT|RESULT'.
# Args: resultVarName confirmAnswer confirmStatus answer...

readNewKeyPassphrase() {
    local -n _runResultRef=$1
    declare -g confirmAnswer=$2 confirmStatus=$3
    shift 3
    declare -ga passwordAnswers=("$@")
    declare -g useCaseLog; useCaseLog="${ makeTempFile; }"
    rm -f "${_adviceCounterFile}"
    _runResultRef="${ (
        local passphrase=''
        _readNewKeyPassphrase passphrase
        echo "|${passphrase}"
    ) 2>&1; }"
}

testYesThenStrongPassphrase() {
    local output
    readNewKeyPassphrase output 1 0 "0:${strong}" "0:${strong}"
    assertContains "|${strong}" "${output}"
    [[ ${output} != *"randomly generated"* ]] || fail "answering yes must not offer generated passphrases: ${output}"
    assertEqual "file none" "${ tr '\n' ' ' < "${useCaseLog}" | gsed 's/ $//'; }" \
        "the passphrase must be checked as a key's, and its confirmation not checked again"
}

testNoOffersGeneratedPassphrases() {
    local output
    readNewKeyPassphrase output 0 0 "0:${strong}" "0:${strong}"
    assertContains "randomly generated" "${output}"
    assertContains "generated words here" "${output}"
    assertContains "|${strong}" "${output}"
}

testNoAnswerOffersGeneratedPassphrases() {
    local output
    readNewKeyPassphrase output 1 124 "0:${strong}" "0:${strong}"
    assertContains "randomly generated" "${output}" "no answer must be taken as no"
    assertContains "|${strong}" "${output}"
}

testWeakPassphraseIsRejected() {
    local output
    readNewKeyPassphrase output 1 0 "1:" "0:${strong}" "0:${strong}"
    assertContains "not safe enough to protect a private key" "${output}"
    assertContains "randomly generated" "${output}" "a rejected passphrase must bring generated ones"
    assertContains "|${strong}" "${output}"
}

testMismatchAsksAgain() {
    local output
    readNewKeyPassphrase output 1 0 "0:${strong}" "0:something else" "0:${strong}" "0:${strong}"
    assertContains "do not match" "${output}"
    assertContains "|${strong}" "${output}"
}

testEmptyEntryCancels() {
    local output
    readNewKeyPassphrase output 1 0 "0:"
    assertContains "BYE: Cancelled; no key was created." "${output}"
}

testCancelledQuestionExits() {
    local output
    readNewKeyPassphrase output 0 130
    assertContains "BYE:" "${output}"
    [[ ${output} != *"randomly generated"* ]] || fail "ESC must not go on: ${output}"
}

testAllowWeakSkipsStrengthCheck() {
    local output allowWeakKeyPassphrase=1
    readNewKeyPassphrase output 1 0 "0:weak" "0:weak"
    assertContains "|weak" "${output}"
    assertEqual "none none" "${ tr '\n' ' ' < "${useCaseLog}" | gsed 's/ $//'; }" "with allowWeakKeyPassphrase, nothing is checked"
}

testAdviceShownOnlyAtFirst() {
    local output
    readNewKeyPassphrase output 1 0 "0:${strong}" "0:${strong}"
    assertContains "Normally you will need only a single key pair" "${output}"
    assertEqual 2 "${ cat "${_adviceCounterFile}"; }" "the advice must not be shown again once a passphrase is chosen"
    output="${ ( _readNewKeyPassphrase p ) 2>&1 <<< ''; }" # passwordAnswers is now empty: only the advice matters
    [[ ${output} != *"Normally you will need only a single key pair"* ]] || fail "the advice must be shown only at first"
}

# A preset passphrase (as try onboard --bob uses) is not entered, and the advice is still shown, but not the question
# whether the user already has a strong one: that is taken as yes, so no generated ones are offered (the mock confirm would answer no)

testPresetPassphraseIsNotEntered() {
    local output rayvnTest_ValtKeyPassphrase="${strong}"
    readNewKeyPassphrase output 0 0
    assertContains "|${strong}" "${output}"
    assertEqual '' "${ cat "${useCaseLog}"; }" "a preset passphrase must not be asked for"
    assertContains "Normally you will need only a single key pair" "${output}" "the advice must still be shown"
    [[ ${output} != *"randomly generated"* ]] || fail "a preset passphrase must not be offered generated ones"
}

# Use a temp HOME, so that the real valt config is not touched

declare -gx HOME; HOME="${ mktemp -d; }"
rayvnTest_ModifiableFunctions=1
source rayvn.up 'rayvn/test' 'valt/keys'
main "$@"
