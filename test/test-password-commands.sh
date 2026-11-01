#!/usr/bin/env bash

main() {
    init "$@"

    # passphrase
    testPassphraseDefault
    testPassphraseOptions
    testPassphraseHasNoCheck

    # typed passphrases (the interactive path, with only the terminal input simulated)
    testTypedStrongPassphraseAccepted
    testTypedWeakPassphraseRejected
    testTypedKeyPassphraseMakesValidKey

    # password
    testPasswordOptions
    testPasswordMinGreaterThanMax

    # pass-check
    testPassCheckWeak
    testPassCheckStrongForFile
    testPassCheckDefaultsToAccount
    testPassCheckUnchecked

    # pass-check --breach-only
    testBreachOnlyFound
    testBreachOnlyFoundOnce
    testBreachOnlyNotFound
    testBreachOnlyApiError
    testPassCheckNoInput

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

# Checking moved to 'valt pass-check'.

testPassphraseHasNoCheck() {
    local output; output="${ valt passphrase --check 2>&1 < /dev/null; }"
    assertContains "unknown argument: --check" "${output}" "passphrase --check must no longer be accepted"
}

# ---- typed passphrases ----

# Simulates typing the given text at a passphrase prompt.

typePassphrase() {
    declare -g typedText="$1"
    secureRequest() { local -n _typedRef=$2; _typedRef="${typedText}"; }
    cursorUpToColumn() { :; }
}

testTypedStrongPassphraseAccepted() {
    local phrase='ribbon corridor gravel unbuckle mosaic salvage'
    addToFakeApi "${phrase}" 0
    typePassphrase "${phrase}"
    local entered; readPassword "Enter passphrase" entered file > /dev/null 2>&1
    assertEqual 0 $? "a strong typed passphrase must be accepted"
    assertEqual "${phrase}" "${entered}"

    # The strength report goes to the terminal, never stdout, which a caller may redirect (e.g. to a key file)
    local stdout; stdout="${ readPassword "Enter passphrase" entered file 2> /dev/null; }"
    assertEqual '' "${stdout}" "readPassword must not write to stdout"
    local confirmed; readConfirmedPassword "Enter passphrase" confirmed file > /dev/null 2>&1
    assertEqual 0 $? "a strong typed and confirmed passphrase must be accepted"
    assertEqual "${phrase}" "${confirmed}"
}

testTypedWeakPassphraseRejected() {
    addToFakeApi 'password123' 3
    typePassphrase 'password123'
    local stdout; stdout="${ readPassword "Enter passphrase" entered file 2> /dev/null; }"
    assertEqual '' "${stdout}" "readPassword must not write its report to stdout"
    local entered; readPassword "Enter passphrase" entered file > /dev/null 2>&1
    assertEqual 1 $? "a weak typed passphrase must be rejected"
    assertEqual '' "${entered}"
}

# Key creation with a typed (and so strength checked) passphrase must write a valid key, which then verifies.

testTypedKeyPassphraseMakesValidKey() {
    local phrase='ribbon corridor gravel unbuckle mosaic salvage'
    addToFakeApi "${phrase}" 0
    typePassphrase "${phrase}"
    cursorUpOneAndEraseLine() { :; }
    local dir; dir="${ makeTempDir; }"
    local pub key
    ( unset rayvnTest_ValtKeyPassphrase; skipKeyPassphraseAdvice=1; newValtKeys typed "${dir}" pub key ) > /dev/null 2>&1 \
        || fail "key creation with a typed passphrase failed"
    local firstLine; read -r firstLine < "${dir}/typed.key"
    [[ ${firstLine} == 'age-encryption.org/v1' || ${firstLine} == '-----BEGIN AGE ENCRYPTED FILE-----' ]] \
        || fail "the key file must start with the age header, not: ${firstLine}"
    ( unset rayvnTest_ValtKeyPassphrase; verifyValtKeys "${dir}/typed.pub" "${dir}/typed.key" ) > /dev/null 2>&1 \
        || fail "a key created with a typed passphrase must verify"
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

# ---- pass-check ----

testPassCheckWeak() {
    addToFakeApi 'password123' 3
    local output; output="${ echo 'password123' | valt pass-check 2>&1; }"
    assertEqual 1 $? "a weak, breached secret must fail the check"
    assertContains "Do NOT use" "${output}"
    assertContains "present in 3 breaches" "${output}"
}

testPassCheckStrongForFile() {
    local phrase; phrase="${ valt passphrase -w 6 2> /dev/null; }"
    addToFakeApi "${phrase}" 0
    local output; output="${ echo "${phrase}" | valt pass-check -u file 2>&1; }"
    assertEqual 0 $? "a strong, unbreached passphrase must pass the check: ${output}"
    assertContains "no known breaches" "${output}"
    assertContains "file attacker" "${output}"
}

testPassCheckDefaultsToAccount() {
    local password; password="${ valt password 2> /dev/null; }"
    addToFakeApi "${password}" 0
    local output; output="${ echo "${password}" | valt pass-check 2>&1; }"
    assertEqual 0 $? "a random password must pass the check: ${output}"
    assertContains "account attacker" "${output}"
}

testPassCheckUnchecked() {
    local phrase; phrase="${ valt passphrase -w 6 2> /dev/null; }"
    local output; output="${ echo "${phrase}" | rayvnTest_PwnedApiUrl="file://${fakeApiDir}/missing" valt pass-check -u file 2>&1; }"
    assertEqual 2 $? "a strong secret that cannot be checked for breaches must exit 2: ${output}"
    assertContains "but unable to check for breaches" "${output}"
}

# ---- pass-check --breach-only ----

testBreachOnlyFound() {
    addToFakeApi 'found-secret' 1234
    local output; output="${ echo 'found-secret' | valt pass-check -b 2>&1; }"
    assertEqual 1 $? "a breached secret must exit 1"
    assertContains "Found in 1,234 breaches" "${output}"
}

testBreachOnlyFoundOnce() {
    addToFakeApi 'found-once-secret' 1
    local output; output="${ echo 'found-once-secret' | valt pass-check -b 2>&1; }"
    assertContains "Found in 1 breach." "${output}"
}

testBreachOnlyNotFound() {
    addToFakeApi 'clean-secret' 0
    local output; output="${ echo 'clean-secret' | valt pass-check -b 2>&1; }"
    assertEqual 0 $? "an unbreached secret must exit 0: ${output}"
    assertContains "Not found in any known breach" "${output}"
}

testBreachOnlyApiError() {
    local output; output="${ echo 'secret-not-in-fake-api' | valt pass-check -b 2>&1; }"
    assertContains "Unable to check for breaches" "${output}"
}

testPassCheckNoInput() {
    local output; output="${ valt pass-check -b < /dev/null 2>&1; }"
    assertContains "no input" "${output}"
}

rayvnTest_ModifiableFunctions=1
source rayvn.up 'rayvn/test' 'valt/password' 'valt/keys'
main "$@"
