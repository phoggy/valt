#!/usr/bin/env bash

main() {
    init "$@"

    testWeakPassphraseRejected
    testWeakPassphraseAllowed
    testStrongPassphraseAccepted
    testStrongPassphraseAcceptedOffline
    testWeakPassphraseRejectedOffline
    testForceKeepsKeysWhenRejected
    testForceReplacesKeys

    return 0
}

init() {
    while (( $# )); do
        case "$1" in
            --debug*) setDebug "$@"; shift $? ;;
        esac
        shift
    done

    # Check the strength of the supplied test passphrase, against a local copy of the HaveIBeenPwned range API.

    declare -gx rayvnTest_CheckKeyPassphraseStrength=1
    declare -g fakeApiDir; fakeApiDir="${ makeTempDir; }"
    mkdir "${fakeApiDir}/range" || fail
    declare -gx rayvnTest_PwnedApiUrl="file://${fakeApiDir}"

    declare -g weakPassphrase='password123'
    declare -g strongPassphrase='ribbon corridor gravel unbuckle mosaic salvage'
    addToFakeApi "${weakPassphrase}" 42
    addToFakeApi "${strongPassphrase}" 0
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

# Runs 'valt keys' quietly, with the given passphrase and args, writing to dir.

valtKeys() {
    local passphrase="$1" dir="$2"; shift 2
    local -x rayvnTest_ValtKeyPassphrase="${passphrase}"
    valt keys -n test -o "${dir}" -q --no-pdf "$@" 2>&1
}

testWeakPassphraseRejected() {
    local dir; dir="${ makeTempDir; }"
    local output; output="${ valtKeys "${weakPassphrase}" "${dir}"; }"
    assertContains "Passphrase rejected" "${output}"
    assertContains "Do NOT use" "${output}"
    assertFileDoesNotExist "${dir}/test.key"
    assertFileDoesNotExist "${dir}/test.pub"
}

testWeakPassphraseAllowed() {
    local dir; dir="${ makeTempDir; }"
    local output; output="${ valtKeys "${weakPassphrase}" "${dir}" --allow-weak-passphrase; }"
    assertEqual 0 $? "--allow-weak-passphrase must accept a weak passphrase: ${output}"
    assertFile "${dir}/test.key"
    assertFile "${dir}/test.pub"
}

testStrongPassphraseAccepted() {
    local dir; dir="${ makeTempDir; }"
    local output; output="${ valtKeys "${strongPassphrase}" "${dir}"; }"
    assertEqual 0 $? "a strong passphrase must be accepted: ${output}"
    assertFile "${dir}/test.key"
}

# When the breach check cannot run, a strong passphrase is accepted with a warning; a weak one is still rejected.

testStrongPassphraseAcceptedOffline() {
    local dir; dir="${ makeTempDir; }"
    local -x rayvnTest_PwnedApiUrl="file://${fakeApiDir}/missing"
    local output; output="${ valtKeys "${strongPassphrase}" "${dir}"; }"
    assertEqual 0 $? "a strong passphrase must be accepted when breaches cannot be checked: ${output}"
    assertContains "unable to check for breaches" "${output}"
    assertFile "${dir}/test.key"
}

testWeakPassphraseRejectedOffline() {
    local dir; dir="${ makeTempDir; }"
    local -x rayvnTest_PwnedApiUrl="file://${fakeApiDir}/missing"
    local output; output="${ valtKeys "${weakPassphrase}" "${dir}"; }"
    assertContains "Passphrase rejected" "${output}"
    assertFileDoesNotExist "${dir}/test.key"
}

testForceKeepsKeysWhenRejected() {
    local dir; dir="${ makeTempDir; }"
    valtKeys "${strongPassphrase}" "${dir}" > /dev/null || fail "initial keys failed"
    local before; before="${ cat "${dir}/test.pub"; }"
    local output; output="${ valtKeys "${weakPassphrase}" "${dir}" --force; }"
    assertContains "Passphrase rejected" "${output}"
    assertEqual "${before}" "${ cat "${dir}/test.pub"; }" "existing keys must be kept when replacement fails"
    assertFile "${dir}/test.key"
}

testForceReplacesKeys() {
    local dir; dir="${ makeTempDir; }"
    valtKeys "${strongPassphrase}" "${dir}" > /dev/null || fail "initial keys failed"
    local before; before="${ cat "${dir}/test.pub"; }"
    local output; output="${ valtKeys "${strongPassphrase}" "${dir}" --force; }"
    assertEqual 0 $? "--force must succeed: ${output}"
    assertNotEqual "${before}" "${ cat "${dir}/test.pub"; }" "--force must replace the keys"
}

source rayvn.up 'rayvn/test'
main "$@"
