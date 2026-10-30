#!/usr/bin/env bash

main() {
    init "$@"

    # passphrase
    testPassphraseDefault
    testPassphraseOptions
    testPassphraseCheckWeak
    testPassphraseCheckStrong

    # password
    testPasswordOptions
    testPasswordMinGreaterThanMax
    testPasswordCheckDefaultsToAccount

    # pwned
    testPwnedFound
    testPwnedFoundOnce
    testPwnedNotFound
    testPwnedApiError
    testPwnedNoInput

    return 0
}

init() {
    while (( $# )); do
        case "$1" in
            --debug*) setDebug "$@"; shift $? ;;
        esac
        shift
    done

    # Use a local copy of the HaveIBeenPwned range API, so that tests are offline and deterministic.

    declare -g fakeApiDir; fakeApiDir="${ makeTempDir; }"
    mkdir "${fakeApiDir}/range" || fail
    declare -gx rayvnTest_PwnedApiUrl="file://${fakeApiDir}"
}

# Adds secret to the fake API with the given breach count (0 adds only an unrelated entry for its hash prefix).

addToFakeApi() {
    local secret="$1" count=$2
    local hash; hash="${ printf '%s' "${secret}" | sha1sum | cut -d' ' -f1 | tr '[:lower:]' '[:upper:]'; }"
    local rangeFile="${fakeApiDir}/range/${hash:0:5}"
    printf '%s:%d\r\n' '0000000000000000000000000000000000A' 7 >> "${rangeFile}"
    (( count )) && printf '%s:%d\r\n' "${hash:5}" "${count}" >> "${rangeFile}"
    return 0
}

# ---- passphrase ----

testPassphraseDefault() {
    local output; output="${ valt passphrase 2> /dev/null; }"
    assertEqual 0 $? "passphrase must succeed"
    local -a words; read -ra words <<< "${output}"
    assertEqual 5 "${#words[@]}" "default passphrase must have 5 words: ${output}"
}

testPassphraseOptions() {
    local -a lines; mapfile -t lines < <(valt passphrase -n 3 -w 4 -s - 2> /dev/null)
    assertEqual 3 "${#lines[@]}" "--count must set the number of passphrases"
    local line
    for line in "${lines[@]}"; do
        local -a words; IFS='-' read -ra words <<< "${line}"
        assertEqual 4 "${#words[@]}" "--words and --separator must be used: ${line}"
    done
}

testPassphraseCheckWeak() {
    addToFakeApi 'password123' 3
    local output; output="${ echo 'password123' | valt passphrase --check 2>&1; }"
    assertEqual 1 $? "a weak, breached passphrase must fail the check"
    assertContains "Do NOT use" "${output}"
    assertContains "present in 3 breaches" "${output}"
}

testPassphraseCheckStrong() {
    local phrase; phrase="${ valt passphrase -w 6 2> /dev/null; }"
    addToFakeApi "${phrase}" 0
    local output; output="${ echo "${phrase}" | valt passphrase --check 2>&1; }"
    assertEqual 0 $? "a strong, unbreached passphrase must pass the check: ${output}"
    assertContains "no known breaches" "${output}"
    assertContains "file attacker" "${output}"
}

# ---- password ----

testPasswordOptions() {
    local -a lines; mapfile -t lines < <(valt password -n 4 --min 12 --max 14 2> /dev/null)
    assertEqual 4 "${#lines[@]}" "--count must set the number of passwords"
    local line
    for line in "${lines[@]}"; do
        (( ${#line} >= 12 && ${#line} <= 14 )) || fail "password length ${#line} not in [12, 14]: ${line}"
    done
}

testPasswordMinGreaterThanMax() {
    local output; output="${ valt password --min 20 --max 10 2>&1; }"
    assertContains "--min must not be greater than --max" "${output}"
}

testPasswordCheckDefaultsToAccount() {
    local password; password="${ valt password 2> /dev/null; }"
    addToFakeApi "${password}" 0
    local output; output="${ echo "${password}" | valt password --check 2>&1; }"
    assertEqual 0 $? "a random password must pass the check: ${output}"
    assertContains "account attacker" "${output}"
}

# ---- pwned ----

testPwnedFound() {
    addToFakeApi 'found-secret' 1234
    local output; output="${ echo 'found-secret' | valt pwned 2>&1; }"
    assertEqual 1 $? "a breached secret must exit 1"
    assertContains "Found in 1,234 breaches" "${output}"
}

testPwnedFoundOnce() {
    addToFakeApi 'found-once-secret' 1
    local output; output="${ echo 'found-once-secret' | valt pwned 2>&1; }"
    assertContains "Found in 1 breach." "${output}"
}

testPwnedNotFound() {
    addToFakeApi 'clean-secret' 0
    local output; output="${ echo 'clean-secret' | valt pwned 2>&1; }"
    assertEqual 0 $? "an unbreached secret must exit 0: ${output}"
    assertContains "Not found in any known breach" "${output}"
}

testPwnedApiError() {
    local output; output="${ echo 'secret-not-in-fake-api' | valt pwned 2>&1; }"
    assertContains "Unable to check for breaches" "${output}"
}

testPwnedNoInput() {
    local output; output="${ valt pwned < /dev/null 2>&1; }"
    assertContains "no input" "${output}"
}

source rayvn.up 'rayvn/test'
main "$@"
