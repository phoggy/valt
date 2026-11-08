#!/usr/bin/env bash

main() {
    init "$@"

    testNewValtKeys
    testNewValtKeysDefaultName
    testAdviceCounterInValtConfigDir
    testVerifyValtKeys
    testKeyType
    testRecipientFromPub
    testRecipientFromKey
    testNewRecipientsFile
    testPublicSigningKeyToTempFile
    testSigningKeyToTempFile
    testArmorKeyFile
    testValtReleaseTag

    return 0
}

init() {
    while (( $# )); do
        case "$1" in
            --debug*) setDebug "$@"; shift $? ;;
        esac
        shift
    done

    rayvnTest_ValtKeyPassphrase='valt-test-passphrase-12345'
    skipKeyPassphraseAdvice=1
    declare -g testKeyDir pubFile keyFile
    testKeyDir="${ makeTempDir; }"
    newValtKeys 'test' "${testKeyDir}" pubFile keyFile
}

testNewValtKeys() {
    assertFile "${pubFile}"
    assertFile "${keyFile}"
    assertEqual "${testKeyDir}/test.pub" "${pubFile}"
    assertEqual "${testKeyDir}/test.key" "${keyFile}"
}

testNewValtKeysDefaultName() {
    local dir; dir="${ makeTempDir; }"
    local defaultPubFile defaultKeyFile
    newValtKeys - "${dir}" defaultPubFile defaultKeyFile
    assertEqual "${dir}/alex.pub" "${defaultPubFile}"
    assertEqual "${dir}/alex.key" "${defaultKeyFile}"
    assertFile "${defaultPubFile}"
    assertFile "${defaultKeyFile}"
}

testAdviceCounterInValtConfigDir() {
    assertEqual "${HOME}/.config/valt/advice.count" "${_adviceCounterFile}"
}

testVerifyValtKeys() {
    assertTrue "key pair verification must succeed" verifyValtKeys "${pubFile}" "${keyFile}"
}

testKeyType() {
    local t
    t="${ keyType "${pubFile}"; }"
    assertEqual 'pub' "${t}"
    t="${ keyType "${keyFile}"; }"
    assertEqual 'key' "${t}"
}

testRecipientFromPub() {
    local r
    r="${ recipient "${pubFile}"; }"
    assertEqual 'age' "${r:0:3}" "recipient from pub should start with 'age'"
}

testRecipientFromKey() {
    local rPub rKey
    rPub="${ recipient "${pubFile}"; }"
    rKey="${ recipient "${keyFile}"; }"
    assertEqual "${rPub}" "${rKey}" "recipient from key should match recipient from pub"
}

testNewRecipientsFile() {
    local recipientsFile; recipientsFile="${ makeTempFile; }"
    local r; r="${ recipient "${pubFile}"; }"
    newRecipientsFile "${recipientsFile}" "${pubFile}"
    assertTrue "recipients file must contain recipient" grep -qF "${r}" "${recipientsFile}"
}

testPublicSigningKeyToTempFile() {
    local signingKeyFile
    publicSigningKeyToTempFile "${keyFile}" signingKeyFile
    assertFile "${signingKeyFile}"
    local lineCount; lineCount=${ gawk 'END{print NR}' "${signingKeyFile}"; }
    assertEqual '2' "${lineCount}"
}

testSigningKeyToTempFile() {
    local signingKeyFile
    signingKeyToTempFile "${keyFile}" signingKeyFile
    assertFile "${signingKeyFile}"
    assertTrue "signing key file must be non-empty" test -s "${signingKeyFile}"
}

testArmorKeyFile() {
    local armored
    armored="${ armorKeyFile "${keyFile}"; }"
    assertContains '-----BEGIN AGE ENCRYPTED FILE-----' "${armored}"
    assertContains '-----END AGE ENCRYPTED FILE-----' "${armored}"
    assertArmorFormat "${armored}" "with the system base64"

    # GNU base64 wraps its output at 76 columns, which must not change the armor

    base64() { command base64 "$@" | fold -w 76; }
    armored="${ armorKeyFile "${keyFile}"; }"
    unset -f base64
    assertArmorFormat "${armored}" "with a base64 that wraps at 76 columns"

    # age accepts it: the armored key decrypts with its passphrase

    local armoredKeyFile="${testKeyDir}/armored.key"
    echo "${armored}" > "${armoredKeyFile}"
    local output; output="${ rayvnTest_ValtKeyPassphrase="${rayvnTest_ValtKeyPassphrase}" valt verify -i "${armoredKeyFile}" 2>&1; }"
    assertEqual 0 $? "the armored key must decrypt: ${output}"
}

# Fails unless the armored text is in age's format: base64 lines of exactly 64 characters but the last, which decode to
# the key file.

assertArmorFormat() {
    local armored="$1" context="$2"
    local -a lines=()
    mapfile -t lines <<< "${armored}"
    local last=$(( ${#lines[@]} - 2 )) i
    for (( i = 1; i < last; i++ )); do
        (( ${#lines[${i}]} == 64 )) || fail "armor line ${i} is ${#lines[${i}]} characters, not 64, ${context}"
    done
    (( ${#lines[${last}]} >= 1 && ${#lines[${last}]} <= 64 )) || fail "the last armor line is ${#lines[${last}]} characters, ${context}"
    local decoded; decoded="${ printf '%s\n' "${lines[@]:1:${last}}" | base64 -d | sha256sum; }"
    assertEqual "${ sha256sum < "${keyFile}"; }" "${decoded}" "the armor must decode to the key file, ${context}"
}

# A release (no '+', with a release date) pins recovery to itself; a development version (e.g. 0.2.0+) to the release
# before it

testValtReleaseTag() {
    local pkg; pkg="${ makeTempFile; }"
    printf '%s\n' "projectVersion='0.2.0'" "projectReleaseDate='2026-11-07 10:00:00 PST'" > "${pkg}"
    assertEqual 'v0.2.0' "${ valtReleaseTag "${pkg}"; }"
    printf '%s\n' "projectVersion='0.2.0+'" "projectReleaseDate=''" > "${pkg}"
    assertEqual 'v0.2.0' "${ valtReleaseTag "${pkg}"; }" "a development version must give the release before it"
    printf '%s\n' "projectVersion='0.2.0'" "projectReleaseDate=''" > "${pkg}"
    assertEqual '' "${ valtReleaseTag "${pkg}"; }" "a version without a release date has no tag"
}

declare -gx USER='alex' # so that the default key name is alex
source rayvn.up 'rayvn/test' 'valt/keys'
main "$@"
