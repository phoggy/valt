#!/usr/bin/env bash

main() {
    init "$@"

    testReadPasswordDefaultsToNoStrengthCheck
    testReadPasswordChecksStrengthForUseCase
    testReadPasswordCallersUseCurrentSignature
    testReadConfirmedPasswordReturnsOnWeak
    testGeneratePassphrase
    testGeneratePassword

    return 0
}

init() {
    while (( $# )); do
        case "$1" in
            --debug*) setDebug "$@"; shift $? ;;
        esac
        shift
    done

    # Simulate typed input and record strength checks, without a terminal or network access.

    declare -g typedPassword='typed-passphrase'
    declare -gi strengthChecks=0
    declare -g strengthUseCase=''
    declare -gi strengthResult=0
    secureRequest() { local -n _typedRef=$2; _typedRef="${typedPassword}"; }
    cursorUpToColumn() { :; }
    passwordStrength() {
        (( strengthChecks++ ))
        strengthUseCase="$2"
        local -n _reportRef=$5; _reportRef=('ok')
        return ${strengthResult}
    }
}

testReadPasswordDefaultsToNoStrengthCheck() {
    strengthChecks=0
    local password; readPassword "Enter passphrase" password > /dev/null
    assertEqual 0 $? "readPassword must succeed"
    assertEqual "${typedPassword}" "${password}"
    assertEqual 0 "${strengthChecks}" "strength must not be checked without a use case"
}

testReadPasswordChecksStrengthForUseCase() {
    strengthChecks=0
    local password; readPassword "Enter passphrase" password file > /dev/null
    assertEqual 0 $? "readPassword must succeed"
    assertEqual "${typedPassword}" "${password}"
    assertEqual 1 "${strengthChecks}" "strength must be checked once"
    assertEqual 'file' "${strengthUseCase}"
}

# A weak first entry must return 1 to the caller (which decides what to do), not exit.

testReadConfirmedPasswordReturnsOnWeak() {
    strengthResult=1
    local password result
    readConfirmedPassword "Enter passphrase" password file > /dev/null 2>&1; result=$?
    strengthResult=0
    assertEqual 1 "${result}" "a weak passphrase must return 1"
    assertEqual '' "${password}" "a weak passphrase must not be returned"
}

# The third argument was once the timeout; passing one there is treated as an unknown use case.

testReadPasswordCallersUseCurrentSignature() {
    local callers; callers="${ grep -rnE 'readPassword "[^"]*" [a-zA-Z_]+ [0-9$]' "${valtHome}/bin" "${valtHome}/lib"; }"
    assertEqual '' "${callers}" "readPassword callers must pass a use case (or nothing) as the third argument"
}

testGeneratePassphrase() {
    local phrase; generatePassphrase phrase 4 '-'
    local -a words; IFS='-' read -ra words <<< "${phrase}"
    assertEqual 4 "${#words[@]}" "passphrase must have the requested word count: ${phrase}"
}

testGeneratePassword() {
    local password i
    for (( i = 0; i < 200; i++ )); do
        generatePassword password 20 24
        (( ${#password} >= 20 && ${#password} <= 24 )) || fail "password length ${#password} not in [20, 24]: ${password}"
    done
    generatePassword password 16 16
    assertEqual 16 "${#password}" "equal min and max lengths must give exactly that length"
}

rayvnTest_ModifiableFunctions=1
source rayvn.up 'rayvn/test' 'valt/password'
main "$@"
