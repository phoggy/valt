#!/usr/bin/env bash

# The key info web page and its import into key.info. HOME is a temp dir, so the real valt config is never touched.

main() {
    init "$@"

    testPageHasCurrentValues
    testPageLeavesOutTemplateSamples
    testPageShowsSamplesWhenCompleted
    testPageCannotEndItsScript
    testImportRoundTrip
    testImportKeepsExtraVars
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

writeKeyInfo() {
    cat > "$1" <<'INFO'
greeting="Hi, it's me"
closing='Don'\''t panic!'
author="Bob O'Brien"
contacts=(
    "Aunt Martha: +44 791, martha@example.com"
    'Billy "BB" Bob: $HOME is not expanded'
)
notes="The passphrase is in the safe."
completed='yes'
INFO
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

# Sets the named var to the values the key info file defines, as declare -p output.

keyInfoValues() {
    local -n valuesRef=$2
    valuesRef="${ ( sourceConfigFile "$1"; declare -p greeting closing author contacts ) 2>&1; }"
}

testPageHasCurrentValues() {
    local keys
    local info="${testDir}/current.info" pageFile # the name valt key-info uses, which once collided with a local
    writeKeyInfo "${info}"
    newKeyInfoPage "${info}" "${testDir}" pageFile keys $(( EPOCHSECONDS + 3600 ))
    assertFile "${pageFile}"
    local data; data="${ pageData "${pageFile}"; }"
    assertEqual "Bob O'Brien" "${ jq -r '.author' <<< "${data}"; }"
    assertEqual 2 "${ jq '.contacts | length' <<< "${data}"; }"
    assertEqual '["The passphrase is in the safe."]' "${ jq -c '.notes' <<< "${data}"; }" "a notes string must become a list"
}

testPageLeavesOutTemplateSamples() {
    local keys
    local info="${testDir}/template.info" page
    cp "${valtHome}/etc/key-info-template.sh" "${info}" || fail
    newKeyInfoPage "${info}" "${testDir}" page keys $(( EPOCHSECONDS + 3600 ))
    assertEqual '{"greeting":"","closing":"","author":"","contacts":[],"notes":[]}' "${ pageData "${page}"; }"

    newKeyInfoPage "${testDir}/missing.info" "${testDir}" page keys $(( EPOCHSECONDS + 3600 ))
    assertEqual '' "${ pageData "${page}" | jq -r '.author'; }" "a missing key.info must give an empty form"
}

# Once key.info is marked completed, the page shows what it holds, even values that are still the template's samples,
# so that they are noticed.

testPageShowsSamplesWhenCompleted() {
    local info="${testDir}/completed-template.info" page keys
    gsed "s/^completed=.*/completed=\"yes\"/" "${valtHome}/etc/key-info-template.sh" > "${info}" || fail
    newKeyInfoPage "${info}" "${testDir}" page keys $(( EPOCHSECONDS + 3600 ))
    local data; data="${ pageData "${page}"; }"
    assertEqual 'Bob Barker' "${ jq -r '.author' <<< "${data}"; }"
    assertEqual 2 "${ jq '.contacts | length' <<< "${data}"; }"
}

testPageCannotEndItsScript() {
    local keys
    local info="${testDir}/script.info" page
    printf '%s\n' "author='</script><script>alert(1)</script>'" "contacts=('x: y')" > "${info}"
    newKeyInfoPage "${info}" "${testDir}" page keys $(( EPOCHSECONDS + 3600 ))
    assertEqual 3 "${ grep -c '</script>' "${page}"; }" "a value must not end the data script" # data, keys and code
    assertEqual '</script><script>alert(1)</script>' "${ pageData "${page}" | jq -r '.author'; }"
}

testImportRoundTrip() {
    local keys
    local info="${testDir}/roundtrip.info" page
    writeKeyInfo "${info}"
    local before; keyInfoValues "${info}" before
    newKeyInfoPage "${info}" "${testDir}" page keys $(( EPOCHSECONDS + 3600 ))
    pageData "${page}" > "${testDir}/valt-key-info.json"
    importKeyInfo "${testDir}/valt-key-info.json" "${info}"
    local after; keyInfoValues "${info}" after
    assertEqual "${before}" "${after}" "the values must survive the round trip"
    assertTrue "the imported key.info must be complete" isKeyInfoComplete "${info}"
    local notes; notes="${ ( sourceConfigFile "${info}"; declare -p notes ); }"
    assertContains '[0]="The passphrase is in the safe."' "${notes}"
}

testImportKeepsExtraVars() {
    local info="${testDir}/extras.info" json="${testDir}/extras.json"
    writeKeyInfo "${info}"
    printf '%s\n' "favoriteColor='blue'" "pets=('cat' 'dog')" >> "${info}"
    echo '{"greeting":"Hello","closing":"Bye","author":"New Name","contacts":["A: 1"],"notes":[]}' > "${json}"
    importKeyInfo "${json}" "${info}"
    local values; values="${ ( sourceConfigFile "${info}"; declare -p author favoriteColor pets ); }"
    assertContains 'author="New Name"' "${values}"
    assertContains 'favoriteColor="blue"' "${values}"
    assertContains '[1]="dog"' "${values}"
}

testImportRejectsInvalidInfo() {
    local info="${testDir}/invalid.info" json="${testDir}/invalid.json" output
    writeKeyInfo "${info}"
    local before; readFile "${info}" before
    for data in '{"greeting":"Hi","closing":"Bye","author":"","contacts":["A: 1"]}' \
                '{"greeting":"Hi","closing":"Bye","author":"Me","contacts":[]}' \
                'not json'; do
        echo "${data}" > "${json}"
        output="${ ( importKeyInfo "${json}" "${info}" ) 2>&1; }"
        assertNotEqual 0 $? "invalid key info must be rejected: ${data}"
        assertContains "is not valid key info" "${output}"
    done
    local after; readFile "${info}" after
    assertEqual "${before}" "${after}" "a rejected import must leave key.info unchanged"
}

testImportedFileIsPrivate() {
    local info="${testDir}/private.info" json="${testDir}/private.json"
    echo '{"greeting":"Hi","closing":"Bye","author":"Me","contacts":["A: 1"]}' > "${json}"
    importKeyInfo "${json}" "${info}"
    local mode; mode="${ stat -f '%Lp' "${info}" 2> /dev/null || stat -c '%a' "${info}"; }"
    assertEqual 600 "${mode}" "key.info holds contacts' details, so must be readable only by its owner"
}

# Runs 'valt key-info' (without a browser) in the background, writing a download once it is waiting.

testCommandImportsDownload() {
    local downloads="${testDir}/downloads" info="${testDir}/command.info"
    mkdir -p "${downloads}" || fail
    local outputFile="${testDir}/command.out"
    env rayvnTest_KeyInfoNoBrowser=1 valt key-info -k "${info}" -d "${downloads}" > "${outputFile}" 2>&1 &
    local pid=$!
    sleep 2
    local page; page="${ pageFromOutput "${outputFile}"; }"
    local keys; keys="${ pageKeys "${page}"; }"
    encryptLikePage '{"greeting":"Hi","closing":"Bye","author":"From The Page","contacts":["A: 1"]}' "${keys}" \
        "${downloads}/${ downloadName "${keys}"; }"
    wait ${pid}
    assertEqual 0 $? "key-info must succeed: ${ cat "${outputFile}"; }"
    assertContains "Saved" "${ cat "${outputFile}"; }"
    [[ ${ cat "${outputFile}"; } != *"command not found"* && ${ cat "${outputFile}"; } != *"🔺"* ]] \
        || fail "key-info must run without errors: ${ cat "${outputFile}"; }"
    assertContains 'author="From The Page"' "${ ( sourceConfigFile "${info}"; declare -p author ); }"
    assertFileDoesNotExist "${downloads}/${ downloadName "${keys}"; }"
}

testCommandIgnoresOlderDownload() {
    local downloads="${testDir}/downloads2" info="${testDir}/command2.info"
    mkdir -p "${downloads}" || fail
    echo '{"greeting":"Old","closing":"Old","author":"Old Download","contacts":["A: 1"]}' > "${downloads}/valt-key-info.json"
    touch -t 202001010000 "${downloads}/valt-key-info.json"
    local outputFile="${testDir}/command2.out"
    env rayvnTest_KeyInfoNoBrowser=1 valt key-info -k "${info}" -d "${downloads}" > "${outputFile}" 2>&1 &
    local pid=$!
    sleep 2
    local page; page="${ pageFromOutput "${outputFile}"; }"
    local keys; keys="${ pageKeys "${page}"; }"
    local name; name="${ downloadName "${keys}"; }"
    encryptLikePage '{"greeting":"New","closing":"New","author":"New Download","contacts":["A: 1"]}' "${keys}" \
        "${downloads}/${name%.json} (1).json"
    wait ${pid}
    assertContains 'author="New Download"' "${ ( sourceConfigFile "${info}"; declare -p author ); }" \
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
    local downloads="${testDir}/downloads3" info="${testDir}/command3.info"
    mkdir -p "${downloads}" || fail
    local outputFile="${testDir}/command3.out"
    env rayvnTest_KeyInfoNoBrowser=1 valt key-info -k "${info}" -d "${downloads}" > "${outputFile}" 2>&1 &
    local pid=$!
    sleep 2
    local page; page="${ pageFromOutput "${outputFile}"; }"
    local keys; keys="${ pageKeys "${page}"; }"
    encryptLikePage '{"greeting":"Hi","closing":"Bye","author":"Kept","contacts":["A: 1"]}' "${keys}" \
        "${downloads}/${ downloadName "${keys}"; }"
    chmod 555 "${downloads}" || fail
    wait ${pid}
    local status=$?
    chmod 755 "${downloads}"
    assertEqual 0 ${status} "key-info must still succeed: ${ cat "${outputFile}"; }"
    assertContains 'author="Kept"' "${ ( sourceConfigFile "${info}"; declare -p author ); }"
    assertContains "useless to anyone" "${ stripAnsi "${ cat "${outputFile}"; }"; }"
}

testValuesIgnoreLayout() {
    local a="${testDir}/layout-a.info" b="${testDir}/layout-b.info"
    printf '%s\n' "author='Me'" "contacts=('A: 1' 'B: 2')" > "${a}"
    printf '%s\n' '# a comment' 'contacts=(' '    "A: 1"' "    'B: 2'" ')' 'author="Me"' > "${b}"
    assertEqual "${ keyInfoValues "${a}"; }" "${ keyInfoValues "${b}"; }" "the same values in another layout must be equal"
    printf '%s\n' "author='You'" "contacts=('A: 1' 'B: 2')" > "${b}"
    assertNotEqual "${ keyInfoValues "${a}"; }" "${ keyInfoValues "${b}"; }" "changed values must differ"
    assertEqual '' "${ keyInfoValues "${testDir}/missing.info"; }"
}

# Runs 'valt key-info' (without a browser) with the given download, setting the named var to its output.

keyInfoCommandWith() {
    local -n commandOutputRef=$1
    local json="$2" info="$3" downloads="$4"
    local outputFile="${testDir}/offer.out"
    env rayvnTest_KeyInfoNoBrowser=1 valt key-info -k "${info}" -d "${downloads}" > "${outputFile}" 2>&1 &
    local pid=$!
    sleep 2
    local page; page="${ pageFromOutput "${outputFile}"; }"
    local keys; keys="${ pageKeys "${page}"; }"
    encryptLikePage "${json}" "${keys}" "${downloads}/${ downloadName "${keys}"; }"
    wait ${pid} || fail "key-info failed: ${ cat "${outputFile}"; }"
    commandOutputRef="${ stripAnsi "${ cat "${outputFile}"; }"; }"
}

testCommandOffersRegenerationOnlyOnChange() {
    local downloads="${testDir}/downloads4" info="${testDir}/offer.info" output
    mkdir -p "${downloads}" || fail

    # A default key, so that regenerating its paper key can be offered

    local configDir="${HOME}/.config/valt" pub key
    mkdir -p "${configDir}" || fail
    local -x rayvnTest_ValtKeyPassphrase='valt-test-passphrase-12345'
    local skipKeyPassphraseAdvice=1 allowWeakKeyPassphrase=1
    newValtKeys valt "${configDir}" pub key

    local json='{"greeting":"Hi","closing":"Bye","author":"Offer","contacts":["A: 1"]}'
    keyInfoCommandWith output "${json}" "${info}" "${downloads}"
    assertContains "Saved" "${output}"
    assertContains "To regenerate the paper key, run:" "${output}"

    keyInfoCommandWith output "${json}" "${info}" "${downloads}"
    assertContains "No changes to" "${output}"
    [[ ${output} != *"To regenerate"* ]] || fail "an unchanged key.info must not offer to regenerate: ${output}"
}

# ---- decryptKeyInfoDownload ----

newPageForDecrypt() {
    local -n decryptPageRef=$1
    local -n decryptKeysRef=$2
    local dir; dir="${ makeTempDir; }"
    newKeyInfoPage "${testDir}/missing.info" "${dir}" decryptPageRef decryptKeysRef $(( EPOCHSECONDS + 3600 ))
}

testDecryptRoundTrip() {
    local page keys; newPageForDecrypt page keys
    assertEqual "${keys}" "${ pageKeys "${page}"; }" "the returned keys must be the ones in the page"
    assertEqual '</html>' "${ tail -n 1 "${page}"; }" "nothing may be left over after the page"
    local json='{"author":"Zoë O'"'"'Brien","contacts":["Café: ☕"]}'
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
    echo '{"greeting":"Hi","closing":"Bye","author":"Me","contacts":["A: 1"]}' > "${testDir}/plain.json"
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
    newKeyInfoPage "${testDir}/missing.info" "${testDir}" page keys ${expires}
    local json; json="${ gsed -n 's|.*<script id="key-info-keys" type="application/json">\(.*\)</script>.*|\1|p' "${page}"; }"
    assertEqual "${expires}" "${ jq -r '.expires' <<< "${json}"; }" "the page must know when it expires"
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
    local downloads="${testDir}/downloads7" info="${testDir}/cancel.info"
    mkdir -p "${downloads}" || fail
    writeKeyInfo "${info}"
    local before; readFile "${info}" before
    local outputFile="${testDir}/cancel.out"
    env rayvnTest_KeyInfoNoBrowser=1 valt key-info -k "${info}" -d "${downloads}" > "${outputFile}" 2>&1 &
    local pid=$!
    sleep 2
    local page; page="${ pageFromOutput "${outputFile}"; }"
    local keys; keys="${ pageKeys "${page}"; }"
    encryptLikePage '{"cancelled":true}' "${keys}" "${downloads}/${ downloadName "${keys}"; }"
    wait ${pid}
    assertEqual 0 $? "cancel must succeed: ${ cat "${outputFile}"; }"
    assertContains "Cancelled;" "${ stripAnsi "${ cat "${outputFile}"; }"; }"
    local after; readFile "${info}" after
    assertEqual "${before}" "${after}" "cancel must leave key.info unchanged"
    assertFileDoesNotExist "${downloads}/${ downloadName "${keys}"; }"
}

testCommandTimeout() {
    local downloads="${testDir}/downloads8" info="${testDir}/timeout.info"
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
