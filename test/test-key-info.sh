#!/usr/bin/env bash

# The key info file, its web page and import, and converting the old key.info. HOME is a temp dir, so the real valt
# config is never touched.

main() {
    init "$@"

    testPageHasCurrentValues
    testPageForMissingFileIsEmpty
    testPageCannotEndItsScript
    testProblems
    testMigrateLegacyKeyInfo
    testMigrateLeavesOutSamples
    testMigrateKeepsExistingFile
    testImportRoundTrip
    testImportKeepsExtraVars
    testImportKeepsOnePreferredWay
    testImportRejectsInvalidInfo
    testImportedFileIsPrivate
    testCommandImportsDownload
    testCommandIgnoresOlderDownload
    testWaitPicksNewestDownload
    testDecryptRoundTrip
    testDecryptRejectsChangedFile
    testDecryptRejectsOtherKeys
    testDecryptRejectsPlainFile
    testEachPageHasNewKeys
    testPageHasExpiry
    testWaitStopsAtDeadline
    testCommandCancel
    testCommandTimeout
    testCommandWarnsWhenDownloadKept
    testValuesIgnoreLayout
    testCommandOffersRegenerationOnlyOnChange

    return 0
}

init() {
    while (( $# )); do
        case "$1" in
            --debug*) setDebug "$@"; shift $? ;;
        esac
        shift
    done
    declare -g testDir; testDir="${ makeTempDir; }"
}

# Outputs the JSON embedded in a key info page.

pageData() {
    gsed -n 's|.*<script id="key-info-data" type="application/json">\(.*\)</script>.*|\1|p' "$1"
}

# lint-skip-start (JSON, not tests)
writeKeyInfo() {
    cat > "$1" <<'INFO'
{
  "greeting": "Hi, it's me",
  "closing": "Don't panic!",
  "author": "Bob O'Brien",
  "contacts": [
    { "name": "Aunt Martha", "ways": [ { "type": "phone", "value": "+44 791 112 4456" },
                                       { "type": "email", "value": "martha@example.com" } ] },
    { "name": "Billy \"BB\" Bob", "ways": [ { "type": "social", "value": "$HOME is not expanded" } ] }
  ],
  "notes": [ "The passphrase is in the safe." ]
}
INFO
}
# lint-skip-end

# A download's contacts: one person with a phone number

contactsJson='[{"name":"A","ways":[{"type":"phone","value":"+1 555 555 1212"}]}]'

# Outputs a page download's JSON with the given author (and the other values the page always sends).

downloadJson() {
    echo "{\"greeting\":\"Hi\",\"closing\":\"Bye\",\"author\":\"$1\",\"contacts\":${contactsJson},\"notes\":[]}"
}

# Outputs a value from a key info file, e.g. author.

keyInfoValue() {
    jq -r ".$2" "$1"
}

# Outputs the id and one-time keys embedded in a key info page, as "ID ENCRYPTION_KEY MAC_KEY".

pageKeys() {
    local json; json="${ gsed -n 's|.*<script id="key-info-keys" type="application/json">\(.*\)</script>.*|\1|p' "$1"; }"
    echo "${ jq -r '.id' <<< "${json}"; } ${ jq -r '.encryptionKey' <<< "${json}"; } ${ jq -r '.macKey' <<< "${json}"; }"
}

# Outputs the name the page's Save gives its download, for the page's id and keys.

downloadName() {
    echo "valt-key-info-${1%% *}.json"
}

# Writes JSON encrypted with the keys, as the page's Save does (AES-256-CBC, then HMAC-SHA256 of IV_HEX.CIPHERTEXT).

encryptLikePage() {
    local json="$1" keys="$2" outputFile="$3"
    local id encryptionKey macKey
    read -r id encryptionKey macKey <<< "${keys}"
    local iv; iv="${ od -An -tx1 -N 16 /dev/urandom | tr -d ' \n'; }"
    local ciphertext; ciphertext="${ printf '%s' "${json}" | openssl enc -aes-256-cbc -K "${encryptionKey}" -iv "${iv}" \
        | base64 | tr -d '\n'; }"
    local mac; mac="${ printf '%s' "${iv}.${ciphertext}" | openssl dgst -sha256 -hmac "${macKey}" -r; }"
    jq -n --arg iv "${iv}" --arg ciphertext "${ciphertext}" --arg mac "${mac%% *}" \
        '{format: "valt-key-info-encrypted", version: 1, iv: $iv, ciphertext: $ciphertext, mac: $mac}' > "${outputFile}"
}

# Outputs the page path that 'valt key-info' printed (with rayvnTest_KeyInfoNoBrowser) to its output file.

pageFromOutput() {
    gsed -n 's/^Key info page: //p' "$1" | head -n 1
}

# Waits up to 60 seconds for 'valt key-info' to print its page path to its output file, then outputs it.

waitForPageFromOutput() {
    local outputFile="$1" page i
    for (( i=0; i < 240; i++ )); do
        page="${ pageFromOutput "${outputFile}"; }"
        [[ -n ${page} ]] && { echo "${page}"; return 0; }
        sleep 0.25
    done
    return 1
}

testPageHasCurrentValues() {
    local keys
    local info="${testDir}/current.json" pageFile # the name valt key-info uses, which once collided with a local
    writeKeyInfo "${info}"
    newKeyInfoPage "${info}" "${testDir}" pageFile keys $(( EPOCHSECONDS + 3600 ))
    assertFile "${pageFile}"
    local data; data="${ pageData "${pageFile}"; }"
    assertEqual "Bob O'Brien" "${ jq -r '.author' <<< "${data}"; }"
    assertEqual 2 "${ jq '.contacts | length' <<< "${data}"; }"
    assertEqual '{"type":"email","value":"martha@example.com"}' "${ jq -c '.contacts[0].ways[1]' <<< "${data}"; }"
    assertEqual '["The passphrase is in the safe."]' "${ jq -c '.notes' <<< "${data}"; }"
}

testPageForMissingFileIsEmpty() {
    local page keys
    newKeyInfoPage "${testDir}/missing.json" "${testDir}" page keys $(( EPOCHSECONDS + 3600 ))
    assertEqual '{"greeting":"","closing":"","author":"","contacts":[],"notes":[]}' "${ pageData "${page}"; }" \
        "a missing key info file must give an empty form"
}

testPageCannotEndItsScript() {
    local keys
    local info="${testDir}/script.json" page
    echo '{"author":"</script><script>alert(1)</script>"}' > "${info}"
    newKeyInfoPage "${info}" "${testDir}" page keys $(( EPOCHSECONDS + 3600 ))
    assertEqual 3 "${ grep -c '</script>' "${page}"; }" "a value must not end the data script" # data, keys and code
    assertEqual 4 "${ grep -c '^@font-face .*;base64,[A-Za-z0-9+/=]*) format(' "${page}"; }" \
        "the page must embed the paper key's fonts"
    assertEqual '</script><script>alert(1)</script>' "${ pageData "${page}" | jq -r '.author'; }"
}

testProblems() {
    local info="${testDir}/problems.json"
    writeKeyInfo "${info}"
    assertEqual '' "${ keyInfoProblems "${info}"; }" "a complete key info file must have no problems"
    assertTrue "a complete key info file must be complete" isKeyInfoComplete "${info}"

    echo '{"greeting":"Hi","contacts":[{"name":"","ways":[{"type":"phone","value":"1"}]},
            {"name":"B","ways":[{"type":"fax","value":"1"}]}, {"name":"C","ways":[{"type":"email","value":" "}]}]}' \
        > "${info}"
    local problems; problems="${ keyInfoProblems "${info}"; }"
    assertContains "a closing line" "${problems}"
    assertContains "your name" "${problems}"
    assertContains "to reach person 1" "${problems}" "a person needs a name"
    assertContains "to reach person 2" "${problems}" "a way's type must be known"
    assertContains "to reach person 3" "${problems}" "a person needs a way with a value"
    assertFalse "an incomplete key info file must not be complete" isKeyInfoComplete "${info}"

    echo 'not json' > "${info}"
    assertContains "valid JSON" "${ keyInfoProblems "${info}"; }"
    assertContains "valt key-info" "${ keyInfoProblems "${testDir}/missing.json"; }"
}

# An old key.info, next to where the key info file belongs, is converted on first use, and kept as key.info.bak

testMigrateLegacyKeyInfo() {
    local dir="${testDir}/legacy" output
    mkdir -p "${dir}" || fail
    cat > "${dir}/key.info" <<'INFO'
greeting="Hi, it's me"
closing='Don'\''t panic!'
author="Bob O'Brien"
contacts=(
    "Aunt Martha: +44 791 112 4456, martha@example.com, 1 Park Row, Leeds LS1 5AB, UK"
    'Billy "BB" Bob: Signal @bb'
)
notes="The passphrase is in the safe."
favoriteColor='blue'
completed='yes'
INFO
    output="${ migrateLegacyKeyInfo "${dir}/key-info.json" 2>&1; }"
    assertContains "Converted" "${output}"
    assertFileDoesNotExist "${dir}/key.info"
    assertFile "${dir}/key.info.bak"
    local info="${dir}/key-info.json"
    assertEqual "Bob O'Brien" "${ keyInfoValue "${info}" author; }"
    assertEqual '["phone","email","address"]' "${ jq -c '[.contacts[0].ways[].type]' "${info}"; }"
    assertEqual '1 Park Row, Leeds LS1 5AB, UK' "${ jq -r '.contacts[0].ways[2].value' "${info}"; }" \
        "an address's parts must be kept together"
    assertEqual 'Billy "BB" Bob' "${ jq -r '.contacts[1].name' "${info}"; }"
    assertEqual '{"type":"social","value":"Signal @bb"}' "${ jq -c '.contacts[1].ways[0]' "${info}"; }"
    assertEqual '["The passphrase is in the safe."]' "${ jq -c '.notes' "${info}"; }"
    assertEqual 'blue' "${ keyInfoValue "${info}" favoriteColor; }" "other values must be kept"
    assertEqual 'null' "${ keyInfoValue "${info}" completed; }" "completed is no longer used"
    assertTrue "a converted complete key.info must be complete" isKeyInfoComplete "${info}"
    local mode; mode="${ stat -f '%Lp' "${info}" 2> /dev/null || stat -c '%a' "${info}"; }"
    assertEqual 600 "${mode}"
}

# A key.info not yet marked completed loses the old template's sample values

testMigrateLeavesOutSamples() {
    local dir="${testDir}/legacy-samples"
    mkdir -p "${dir}" || fail
    cat > "${dir}/key.info" <<'INFO'
greeting="Greetings,"
closing="I hope you never need this!"
author="Bob Barker"
contacts=(
    "Billy Bob: +1 555-555-1212, @billy_bob1725, billy_bob@gmail.com. 14 Main Street, Small Town, AR 95466 USA"
    "Aunt Martha: +44 791 112 4456, @aunt_martha1, martha@aol.com. 221B Baker Street, London, NW1 6XE UNITED KINGDOM"
)
notes=""
completed="no"
INFO
    local page keys
    newKeyInfoPage "${dir}/key-info.json" "${testDir}" page keys $(( EPOCHSECONDS + 3600 )) 2> /dev/null
    assertEqual '{"greeting":"","closing":"","author":"","contacts":[],"notes":[]}' "${ pageData "${page}"; }"
}

testMigrateKeepsExistingFile() {
    local dir="${testDir}/legacy-both"
    mkdir -p "${dir}" || fail
    echo "author='Old'" > "${dir}/key.info"
    writeKeyInfo "${dir}/key-info.json"
    migrateLegacyKeyInfo "${dir}/key-info.json"
    assertFile "${dir}/key.info" "key.info must be left alone once there is a key info file"
    assertEqual "Bob O'Brien" "${ keyInfoValue "${dir}/key-info.json" author; }"
}

testImportRoundTrip() {
    local keys
    local info="${testDir}/roundtrip.json" page
    writeKeyInfo "${info}"
    local before; before="${ keyInfoValues "${info}"; }"
    [[ -n ${before} ]] || fail "keyInfoValues must output the values"
    newKeyInfoPage "${info}" "${testDir}" page keys $(( EPOCHSECONDS + 3600 ))
    pageData "${page}" > "${testDir}/valt-key-info.json"
    importKeyInfo "${testDir}/valt-key-info.json" "${info}"
    assertEqual "${before}" "${ keyInfoValues "${info}"; }" "the values must survive the round trip"
    assertTrue "the imported key info must be complete" isKeyInfoComplete "${info}"
}

testImportKeepsExtraVars() {
    local info="${testDir}/extras.json" json="${testDir}/extras-download.json"
    writeKeyInfo "${info}"
    jq '.favoriteColor = "blue" | .pets = ["cat", "dog"]' "${info}" > "${info}.tmp" && mv "${info}.tmp" "${info}"
    downloadJson "New Name" > "${json}"
    importKeyInfo "${json}" "${info}"
    assertEqual "New Name" "${ keyInfoValue "${info}" author; }"
    assertEqual "blue" "${ keyInfoValue "${info}" favoriteColor; }"
    assertEqual "dog" "${ keyInfoValue "${info}" 'pets[1]'; }"
}

# A person's preferred way is kept; if several are marked, only the first

testImportKeepsOnePreferredWay() {
    local info="${testDir}/preferred.json" json="${testDir}/preferred-download.json"
    echo '{"greeting":"Hi","closing":"Bye","author":"Me","contacts":[{"name":"A","ways":[
            {"type":"phone","value":"+1 555 555 1212"},{"type":"email","value":"a@example.com","preferred":true},
            {"type":"social","value":"@a","preferred":true}]}],"notes":[]}' > "${json}"
    importKeyInfo "${json}" "${info}"
    assertEqual '[null,true,null]' "${ jq -c '[.contacts[0].ways[].preferred]' "${info}"; }"
    local page keys
    newKeyInfoPage "${info}" "${testDir}" page keys $(( EPOCHSECONDS + 3600 ))
    assertEqual '[null,true,null]' "${ pageData "${page}" | jq -c '[.contacts[0].ways[].preferred]'; }" \
        "the page must show which way is preferred"
}

testImportRejectsInvalidInfo() {
    local info="${testDir}/invalid.json" json="${testDir}/invalid-download.json" output
    writeKeyInfo "${info}"
    local before; readFile "${info}" before
    for data in "${ downloadJson ""; }" \
                '{"greeting":"Hi","closing":"Bye","author":"Me","contacts":[]}' \
                '{"greeting":"Hi","closing":"Bye","author":"Me","contacts":["A: 1"]}' \
                '{"greeting":"Hi","closing":"Bye","author":"Me","contacts":[{"name":"A","ways":[{"type":"fax","value":"1"}]}]}' \
                'not json'; do
        echo "${data}" > "${json}"
        output="${ ( importKeyInfo "${json}" "${info}" ) 2>&1; }"
        assertNotEqual 0 $? "invalid key info must be rejected: ${data}"
        assertContains "is not valid key info" "${output}"
    done
    local after; readFile "${info}" after
    assertEqual "${before}" "${after}" "a rejected import must leave the key info file unchanged"
}

testImportedFileIsPrivate() {
    local info="${testDir}/private.json" json="${testDir}/private-download.json"
    downloadJson "Me" > "${json}"
    importKeyInfo "${json}" "${info}"
    local mode; mode="${ stat -f '%Lp' "${info}" 2> /dev/null || stat -c '%a' "${info}"; }"
    assertEqual 600 "${mode}" "the key info file holds contacts' details, so must be readable only by its owner"
}

# Runs 'valt key-info' (without a browser) in the background, writing a download once it is waiting.

testCommandImportsDownload() {
    local downloads="${testDir}/downloads" info="${testDir}/command.json"
    mkdir -p "${downloads}" || fail
    local outputFile="${testDir}/command.out"
    env rayvnTest_KeyInfoNoBrowser=1 valt key-info -k "${info}" -d "${downloads}" > "${outputFile}" 2>&1 &
    local pid=$!
    local page; page="${ waitForPageFromOutput "${outputFile}"; }" || fail "no key info page: ${ cat "${outputFile}"; }"
    local keys; keys="${ pageKeys "${page}"; }"
    encryptLikePage "${ downloadJson "From The Page"; }" "${keys}" "${downloads}/${ downloadName "${keys}"; }"
    wait ${pid}
    assertEqual 0 $? "key-info must succeed: ${ cat "${outputFile}"; }"
    assertContains "Saved" "${ cat "${outputFile}"; }"
    [[ ${ cat "${outputFile}"; } != *"command not found"* && ${ cat "${outputFile}"; } != *"🔺"* ]] \
        || fail "key-info must run without errors: ${ cat "${outputFile}"; }"
    assertEqual "From The Page" "${ keyInfoValue "${info}" author; }"
    assertFileDoesNotExist "${downloads}/${ downloadName "${keys}"; }"
}

testCommandIgnoresOlderDownload() {
    local downloads="${testDir}/downloads2" info="${testDir}/command2.json"
    mkdir -p "${downloads}" || fail
    downloadJson "Old Download" > "${downloads}/valt-key-info.json"
    touch -t 202001010000 "${downloads}/valt-key-info.json"
    local outputFile="${testDir}/command2.out"
    env rayvnTest_KeyInfoNoBrowser=1 valt key-info -k "${info}" -d "${downloads}" > "${outputFile}" 2>&1 &
    local pid=$!
    local page; page="${ waitForPageFromOutput "${outputFile}"; }" || fail "no key info page: ${ cat "${outputFile}"; }"
    local keys; keys="${ pageKeys "${page}"; }"
    local name; name="${ downloadName "${keys}"; }"
    encryptLikePage "${ downloadJson "New Download"; }" "${keys}" "${downloads}/${name%.json} (1).json"
    wait ${pid}
    assertEqual "New Download" "${ keyInfoValue "${info}" author; }" \
        "a download from before the page was opened must be ignored"
    assertFile "${downloads}/valt-key-info.json"
}

# With several downloads since the page was opened, the most recently modified is used; older ones are ignored.

testWaitPicksNewestDownload() {
    local downloads="${testDir}/downloads5" marker="${testDir}/marker5" keys='123456 x y'
    mkdir -p "${downloads}" || fail
    echo '{}' > "${downloads}/valt-key-info-123456 (2).json"
    touch -t 202001010000 "${downloads}/valt-key-info-123456 (2).json" # before the page: ignored, though named last
    touch -t 202001020000 "${marker}"
    echo '{}' > "${downloads}/valt-key-info-123456.json"
    echo '{}' > "${downloads}/valt-key-info-123456 (1).json"
    echo '{}' > "${downloads}/valt-key-info-654321.json"
    touch -t 202001030000 "${downloads}/valt-key-info-123456.json"
    touch -t 202001040000 "${downloads}/valt-key-info-123456 (1).json"  # the newest for this page
    touch -t 202001050000 "${downloads}/valt-key-info-654321.json"      # newer still, but another page's
    assertEqual "${downloads}/valt-key-info-123456 (1).json" "${ waitForKeyInfoDownload "${downloads}" "${marker}" "${keys}" $(( EPOCHSECONDS + 60 )); }"
}

# When the download cannot be deleted (e.g. security software protects Downloads), valt says so. A read-only downloads
# dir stands in for that.

testCommandWarnsWhenDownloadKept() {
    local downloads="${testDir}/downloads3" info="${testDir}/command3.json"
    mkdir -p "${downloads}" || fail
    local outputFile="${testDir}/command3.out"
    env rayvnTest_KeyInfoNoBrowser=1 valt key-info -k "${info}" -d "${downloads}" > "${outputFile}" 2>&1 &
    local pid=$!
    local page; page="${ waitForPageFromOutput "${outputFile}"; }" || fail "no key info page: ${ cat "${outputFile}"; }"
    local keys; keys="${ pageKeys "${page}"; }"
    encryptLikePage "${ downloadJson "Kept"; }" "${keys}" "${downloads}/${ downloadName "${keys}"; }"
    chmod 555 "${downloads}" || fail
    wait ${pid}
    local status=$?
    chmod 755 "${downloads}"
    assertEqual 0 ${status} "key-info must still succeed: ${ cat "${outputFile}"; }"
    assertEqual "Kept" "${ keyInfoValue "${info}" author; }"
    assertContains "useless to anyone" "${ stripAnsi "${ cat "${outputFile}"; }"; }"
}

testValuesIgnoreLayout() {
    local a="${testDir}/layout-a.json" b="${testDir}/layout-b.json"
    echo '{"author":"Me","notes":["A","B"]}' > "${a}"
    printf '%s\n' '{' '  "notes": [ "A", "B" ],' '  "author": "Me"' '}' > "${b}"
    assertEqual "${ keyInfoValues "${a}"; }" "${ keyInfoValues "${b}"; }" "the same values in another layout must be equal"
    echo '{"author":"You","notes":["A","B"]}' > "${b}"
    assertNotEqual "${ keyInfoValues "${a}"; }" "${ keyInfoValues "${b}"; }" "changed values must differ"
    assertEqual '' "${ keyInfoValues "${testDir}/missing.json"; }"
}

# Runs 'valt key-info' (without a browser) with the given download, setting the named var to its output.

keyInfoCommandWith() {
    local -n commandOutputRef=$1
    local json="$2" info="$3" downloads="$4"
    local outputFile="${testDir}/offer.out"
    env rayvnTest_KeyInfoNoBrowser=1 valt key-info -k "${info}" -d "${downloads}" > "${outputFile}" 2>&1 &
    local pid=$!
    local page; page="${ waitForPageFromOutput "${outputFile}"; }" || fail "no key info page: ${ cat "${outputFile}"; }"
    local keys; keys="${ pageKeys "${page}"; }"
    encryptLikePage "${json}" "${keys}" "${downloads}/${ downloadName "${keys}"; }"
    wait ${pid} || fail "key-info failed: ${ cat "${outputFile}"; }"
    commandOutputRef="${ stripAnsi "${ cat "${outputFile}"; }"; }"
}

testCommandOffersRegenerationOnlyOnChange() {
    local downloads="${testDir}/downloads4" info="${testDir}/offer.json" output
    mkdir -p "${downloads}" || fail

    # A default key, so that regenerating its paper key can be offered

    local configDir="${HOME}/.config/valt" pub key
    mkdir -p "${configDir}" || fail
    local -x rayvnTest_ValtKeyPassphrase='valt-test-passphrase-12345'
    local skipKeyPassphraseAdvice=1 allowWeakKeyPassphrase=1
    newValtKeys valt "${configDir}" pub key

    local json; json="${ downloadJson "Offer"; }"
    keyInfoCommandWith output "${json}" "${info}" "${downloads}"
    assertContains "Saved" "${output}"
    assertContains "To regenerate the paper key, run:" "${output}"

    keyInfoCommandWith output "${json}" "${info}" "${downloads}"
    assertContains "No changes to" "${output}"
    [[ ${output} != *"To regenerate"* ]] || fail "unchanged key info must not offer to regenerate: ${output}"
}

# ---- decryptKeyInfoDownload ----

newPageForDecrypt() {
    local -n decryptPageRef=$1
    local -n decryptKeysRef=$2
    local dir; dir="${ makeTempDir; }"
    newKeyInfoPage "${testDir}/missing.json" "${dir}" decryptPageRef decryptKeysRef $(( EPOCHSECONDS + 3600 ))
}

testDecryptRoundTrip() {
    local page keys; newPageForDecrypt page keys
    assertEqual "${keys}" "${ pageKeys "${page}"; }" "the returned keys must be the ones in the page"
    assertEqual '</html>' "${ tail -n 1 "${page}"; }" "nothing may be left over after the page"
    local json='{"author":"Zoë O'"'"'Brien","contacts":[{"name":"Café","ways":[{"type":"social","value":"☕"}]}]}'
    encryptLikePage "${json}" "${keys}" "${testDir}/round.json"
    decryptKeyInfoDownload "${testDir}/round.json" "${keys}" "${testDir}/round.plain"
    assertEqual "${json}" "${ cat "${testDir}/round.plain"; }"
}

testDecryptRejectsChangedFile() {
    local page keys output; newPageForDecrypt page keys
    encryptLikePage '{"author":"Me"}' "${keys}" "${testDir}/changed.json"
    jq '.ciphertext |= (.[0:4] + "AAAA" + .[8:])' "${testDir}/changed.json" > "${testDir}/changed2.json"
    output="${ ( decryptKeyInfoDownload "${testDir}/changed2.json" "${keys}" "${testDir}/changed.plain" ) 2>&1; }"
    assertNotEqual 0 $? "a changed download must be rejected"
    assertContains "or has been changed" "${output}"
    assertFileDoesNotExist "${testDir}/changed.plain"
}

testDecryptRejectsOtherKeys() {
    local page keys otherPage otherKeys output
    newPageForDecrypt page keys
    newPageForDecrypt otherPage otherKeys
    encryptLikePage '{"author":"Me"}' "${otherKeys}" "${testDir}/other.json"
    output="${ ( decryptKeyInfoDownload "${testDir}/other.json" "${keys}" "${testDir}/other.plain" ) 2>&1; }"
    assertNotEqual 0 $? "a download from another page must be rejected"
    assertContains "was not saved by this key info page" "${output}"
}

testDecryptRejectsPlainFile() {
    local page keys output; newPageForDecrypt page keys
    downloadJson "Me" > "${testDir}/plain.json"
    output="${ ( decryptKeyInfoDownload "${testDir}/plain.json" "${keys}" "${testDir}/plain.out" ) 2>&1; }"
    assertNotEqual 0 $? "an unencrypted file must be rejected"
    assertContains "is not from the key info page" "${output}"
}

testEachPageHasNewKeys() {
    local page keys otherPage otherKeys
    newPageForDecrypt page keys
    newPageForDecrypt otherPage otherKeys
    [[ ${keys} =~ ^[0-9]{6}\ [0-9a-f]{64}\ [0-9a-f]{64}$ ]] || fail "expected a 6 digit id and two 32 byte hex keys: ${keys}"
    assertNotEqual "${keys#* }" "${otherKeys#* }" "each page must have its own keys"
}

# ---- cancel and timeout ----

testPageHasExpiry() {
    local page keys expires=$(( EPOCHSECONDS + 1234 ))
    newKeyInfoPage "${testDir}/missing.json" "${testDir}" page keys ${expires}
    local json; json="${ gsed -n 's|.*<script id="key-info-keys" type="application/json">\(.*\)</script>.*|\1|p' "${page}"; }"
    assertEqual "${expires}" "${ jq -r '.expires' <<< "${json}"; }" "the page must know when it expires"
    local started; started="${ jq -r '.started' <<< "${json}"; }"
    (( started > 0 && started <= EPOCHSECONDS )) || fail "the page must know when it was made: ${started}"
}

testWaitStopsAtDeadline() {
    local downloads="${testDir}/downloads6" marker="${testDir}/marker6"
    mkdir -p "${downloads}" || fail
    touch "${marker}" || fail
    local started=${EPOCHSECONDS}
    ( waitForKeyInfoDownload "${downloads}" "${marker}" '123456 x y' $(( EPOCHSECONDS + 1 )) ) > /dev/null
    assertEqual 1 $? "waiting must fail once the deadline passes"
    (( EPOCHSECONDS - started < 10 )) || fail "waiting must stop at the deadline"
}

testCommandCancel() {
    local downloads="${testDir}/downloads7" info="${testDir}/cancel.json"
    mkdir -p "${downloads}" || fail
    writeKeyInfo "${info}"
    local before; readFile "${info}" before
    local outputFile="${testDir}/cancel.out"
    env rayvnTest_KeyInfoNoBrowser=1 valt key-info -k "${info}" -d "${downloads}" > "${outputFile}" 2>&1 &
    local pid=$!
    local page; page="${ waitForPageFromOutput "${outputFile}"; }" || fail "no key info page: ${ cat "${outputFile}"; }"
    local keys; keys="${ pageKeys "${page}"; }"
    encryptLikePage '{"cancelled":true}' "${keys}" "${downloads}/${ downloadName "${keys}"; }"
    wait ${pid}
    assertEqual 0 $? "cancel must succeed: ${ cat "${outputFile}"; }"
    assertContains "Cancelled;" "${ stripAnsi "${ cat "${outputFile}"; }"; }"
    local after; readFile "${info}" after
    assertEqual "${before}" "${after}" "cancel must leave the key info file unchanged"
    assertFileDoesNotExist "${downloads}/${ downloadName "${keys}"; }"
}

testCommandTimeout() {
    local downloads="${testDir}/downloads8" info="${testDir}/timeout.json"
    mkdir -p "${downloads}" || fail
    local output; output="${ env rayvnTest_KeyInfoNoBrowser=1 rayvnTest_KeyInfoTimeoutSeconds=2 \
        valt key-info -k "${info}" -d "${downloads}" 2>&1; }"
    assertEqual 0 $? "a timeout must exit cleanly: ${output}"
    assertContains "Stopped waiting" "${ stripAnsi "${output}"; }"
    assertFileDoesNotExist "${info}"
}

# Use a temp HOME, so that the real valt config is not touched

declare -gx HOME; HOME="${ mktemp -d; }"
source rayvn.up 'rayvn/test' 'rayvn/config' 'valt/key-info' 'valt/paper-keys'
main "$@"
