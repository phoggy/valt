#!/usr/bin/env bash

main() {
    init "$@"

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
    testPaperRelativePaths
    testPaperUsesTemplate
    testPaperUsesStyle
    testPaperDocumentData
    testTypstVersionCheck
    testPaperIncompleteKeyInfo
    testPaperRejectsNameAndKeyFile
    testPaperMissingKeyFile

    # keys command
    testKeysDefaultName
    testKeysDefersPdfWhenKeyInfoIncomplete
    testKeysHelp

    # valt command
    testValtVersion
    testValtHelp

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

    incompleteInfoFile="${testDir}/incomplete.json"
    echo '{"greeting":"Hi"}' > "${incompleteInfoFile}" || fail
    completedInfoFile="${testDir}/completed.json"
    # lint-skip-start (JSON, not tests)
    cat > "${completedInfoFile}" <<'INFO' || fail
{
  "greeting": "Greetings,",
  "closing": "I hope you never need this!",
  "author": "Bob Barker",
  "contacts": [
    { "name": "Aunt Martha", "ways": [ { "type": "phone", "value": "+44 791 112 4456" } ] },
    { "name": "Sam Ortiz", "ways": [ { "type": "email", "value": "sam@ortiz.dev" } ] }
  ],
  "notes": []
}
INFO
    # lint-skip-end
}

# Copies the test key into a new directory, so that each test has its own paper key path.

newKeyCopy() {
    local -n keyCopyRef=$1
    local dir; dir="${ makeTempDir; }"
    cp "${keyFile}" "${dir}/test.key" || fail
    keyCopyRef="${dir}/test.key"
}

# Sets file modification times from YYYYMMDDhhmm values, in order: key, key info, paper key.

setTimes() {
    local key="$1" info="$2" pdf="$3"
    touch -t "$4" "${key}" || fail
    touch -t "$5" "${info}" || fail
    touch -t "$6" "${pdf}" || fail
}

# ---- paperKeyCommand ----

testPaperKeyCommandDefaultKey() {
    local command; command="${ paperKeyCommand "${ defaultValtKeyFile; }"; }"
    assertEqual 'valt paper' "${command}" "the default key (wherever it is set) needs no path"
}

testPaperKeyCommandOtherKey() {
    local command; command="${ paperKeyCommand "${keyFile}"; }"
    assertEqual "valt paper ${ tildePath "${keyFile}"; }" "${command}"
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
    local info="${testDir}/current.json"
    cp "${completedInfoFile}" "${info}" || fail
    setTimes "${key}" "${info}" "${pdf}" 202001010000 202001020000 202001030000
    local output; output="${ remindPaperKey "${key}" "${info}" 2>&1; }"
    assertEqual 0 $? "remindPaperKey must succeed when the paper key is current"
    assertEqual '' "${output}"
}

testRemindKeyNewerThanPaperKey() {
    local key; newKeyCopy key
    local pdf; pdf="${ _paperKeyFile "${key}"; }"
    local info="${testDir}/key-newer.json"
    cp "${completedInfoFile}" "${info}" || fail
    setTimes "${key}" "${info}" "${pdf}" 202001040000 202001010000 202001030000
    local output; output="${ remindPaperKey "${key}" "${info}" 2>&1; }"
    assertContains "is older than the key" "${output}"
}

testRemindKeyInfoNewerThanPaperKey() {
    local key; newKeyCopy key
    local pdf; pdf="${ _paperKeyFile "${key}"; }"
    local info="${testDir}/info-newer.json"
    cp "${completedInfoFile}" "${info}" || fail
    setTimes "${key}" "${info}" "${pdf}" 202001010000 202001040000 202001030000
    local output; output="${ remindPaperKey "${key}" "${info}" 2>&1; }"
    assertContains "key info has changed" "${output}"
}

# ---- paper command ----

testPaperGeneratesPdf() {
    declare -g paperTestKey; newKeyCopy paperTestKey
    local output; output="${ valt paper -k "${completedInfoFile}" "${paperTestKey}" 2>&1; }"
    assertEqual 0 $? "paper must succeed: ${output}"
    assertFile "${ _paperKeyFile "${paperTestKey}"; }"
    assertContains "Paper key file:" "${output}"
    [[ ${output} != *"previous paper key"* ]] || fail "first paper key must not report a replacement"
    assertContains "1. Print at least one copy." "${ stripAnsi "${output}"; }"
    assertContains "3. Store copies in secure locations" "${ stripAnsi "${output}"; }"
}

testPaperReplacesPdf() {
    local output; output="${ valt paper -k "${completedInfoFile}" "${paperTestKey}" 2>&1; }"
    assertEqual 0 $? "paper must succeed: ${output}"
    assertContains "4. Destroy any printed copies of the previous paper key" "${ stripAnsi "${output}"; }"
}

testPaperRelativePaths() {
    local key; newKeyCopy key
    cp "${completedInfoFile}" "${ dirName "${key}"; }/relative.json" || fail
    local output; output="${ cd "${ dirName "${key}"; }" && valt paper -k relative.json "${ baseName "${key}"; }" 2>&1; }"
    assertEqual 0 $? "paper with relative paths must succeed: ${output}"
    assertFile "${ _paperKeyFile "${key}"; }"
}

testPaperUsesTemplate() {
    local key; newKeyCopy key
    local template="${testDir}/template.typ"
    echo '#let data = json("data.json")
#data.undefinedTestVar' > "${template}"
    local output; output="${ valt paper -k "${completedInfoFile}" -t "${template}" "${key}" 2>&1; }"
    assertNotEqual 0 $? "a template using an undefined value must fail"
    assertContains "undefinedTestVar" "${output}" "custom template must be used"
    assertContains "could not generate the paper key PDF from ${ tildePath "${template}"; }" "${output}"
}

testPaperUsesStyle() {
    local key; newKeyCopy key
    local style="${testDir}/style.typ"
    echo '#let style(doc) = { set text(fill: undefinedTestColor); doc }' > "${style}"
    local output; output="${ valt paper -k "${completedInfoFile}" -c "${style}" "${key}" 2>&1; }"
    assertNotEqual 0 $? "a style using an undefined value must fail"
    assertContains "undefinedTestColor" "${output}" "the style file must be used"
    assertContains "style.typ is ${ tildePath "${style}"; }" "${output}"

    echo '#let style(doc) = { show heading: set text(fill: rgb("#7852ee")); doc }' > "${style}"
    output="${ valt paper -k "${completedInfoFile}" -c "${style}" "${key}" 2>&1; }"
    assertEqual 0 $? "a valid style must succeed: ${output}"
    assertFile "${ _paperKeyFile "${key}"; }"
}

# typst 0.15 or later is required, for the variable fonts.

testTypstVersionCheck() {
    local fakeVersion # not 'version', which the fake would see as _assertTypstVersion's own local
    for fakeVersion in 0.15.0 0.15.1 0.16.0 1.0.0; do
        typst() { echo "typst ${fakeVersion} (abcdef12)"; }
        ( _assertTypstVersion ) > /dev/null 2>&1 || fail "typst ${fakeVersion} must be accepted"
    done
    typst() { echo 'typst 0.14.2 (abcdef12)'; }
    local output; output="${ ( _assertTypstVersion ) 2>&1; }"
    assertNotEqual 0 $? "typst 0.14 must be rejected"
    assertContains 'typst 0.14.2 is too old' "${output}"
    unset -f typst
}

# The template's data: every key info value (notes always a list), plus generated values.

testPaperDocumentData() {
    local info="${testDir}/data.json"
    jq 'del(.notes) | .favoriteColor = "blue" | .pets = ["cat", "dog"]' "${completedInfoFile}" > "${info}" || fail
    local jsonFile="${testDir}/document-data.json"
    _writeDocumentData "${info}" 0123456789abcdef "${jsonFile}"
    assertEqual 'Bob Barker' "${ jq -r '.author' "${jsonFile}"; }"
    assertEqual 2 "${ jq '.contacts | length' "${jsonFile}"; }"
    assertEqual 'Sam Ortiz' "${ jq -r '.contacts[1].name' "${jsonFile}"; }"
    assertEqual '[]' "${ jq -c '.notes' "${jsonFile}"; }" "notes must always be a list"
    assertEqual 'blue' "${ jq -r '.favoriteColor' "${jsonFile}"; }"
    assertEqual '["cat","dog"]' "${ jq -c '.pets' "${jsonFile}"; }"
    assertEqual '0123456789abcdef' "${ jq -r '.generated.checksum' "${jsonFile}"; }"
    assertEqual 'key.pem' "${ jq -r '.generated.armoredKey' "${jsonFile}"; }"
}

testPaperIncompleteKeyInfo() {
    local key; newKeyCopy key
    local output; output="${ valt paper -k "${incompleteInfoFile}" "${key}" 2>&1; }"
    assertContains "is not complete yet" "${output}"
    assertContains "a closing line" "${output}" "what is missing must be listed"
    assertFileDoesNotExist "${ _paperKeyFile "${key}"; }"
}

testPaperRejectsNameAndKeyFile() {
    local output; output="${ valt paper -n test "${keyFile}" 2>&1; }"
    assertContains "not both" "${output}"
}

testPaperMissingKeyFile() {
    local output; output="${ valt paper "${testDir}/missing.key" 2>&1; }"
    assertContains "not found" "${output}"
}

# ---- keys command ----

testKeysDefaultName() {
    local dir; dir="${ makeTempDir; }"
    local output; output="${ valt keys -o "${dir}" -q --no-pdf 2>&1; }"
    assertEqual 0 $? "keys must succeed: ${output}"
    assertFile "${dir}/valt.key"
    assertFile "${dir}/valt.pub"
}

testKeysDefersPdfWhenKeyInfoIncomplete() {
    local dir; dir="${ makeTempDir; }"
    local output; output="${ valt keys -n test -o "${dir}" -q -k "${incompleteInfoFile}" 2>&1; }"
    assertEqual 0 $? "keys must succeed: ${output}"
    assertFile "${dir}/test.key"
    assertFileDoesNotExist "${dir}/test-key.pdf"
    assertContains "Paper key not generated" "${output}"
    assertContains "valt paper ${ tildePath "${dir}/test.key"; } -k ${ tildePath "${incompleteInfoFile}"; }" "${output}"
}

testValtVersion() {
    local output; output="${ valt -v 2>&1; }"
    assertEqual 0 $? "valt -v must succeed: ${output}"
    assertContains "valt " "${output}"
}

testValtHelp() {
    local output; output="${ valt --help 2>&1; }"
    assertContains "keys" "${output}"
    assertContains "paper" "${output}"
    assertContains "Print the version." "${output}"
}

testKeysHelp() {
    local output; output="${ valt keys --help 2>&1; }"
    assertContains "-q, --quick" "${output}"
    assertContains "Same as --no-advice --no-verify, and the default key is not offered" "${output}"
}

source rayvn.up 'rayvn/test' 'valt/paper-keys'
main "$@"
