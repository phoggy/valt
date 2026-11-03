#!/usr/bin/env bash

# The key info web page and its import into key.info. HOME is a temp dir, so the real valt config is never touched.

main() {
    init "$@"

    testPageHasCurrentValues
    testPageLeavesOutTemplateSamples
    testPageCannotEndItsScript
    testImportRoundTrip
    testImportKeepsExtraVars
    testImportRejectsInvalidInfo
    testImportedFileIsPrivate
    testCommandImportsDownload
    testCommandIgnoresOlderDownload
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

# Sets the named var to the values the key info file defines, as declare -p output.

keyInfoValues() {
    local -n valuesRef=$2
    valuesRef="${ ( sourceConfigFile "$1"; declare -p greeting closing author contacts ) 2>&1; }"
}

testPageHasCurrentValues() {
    local info="${testDir}/current.info" pageFile # the name valt key-info uses, which once collided with a local
    writeKeyInfo "${info}"
    newKeyInfoPage "${info}" "${testDir}" pageFile
    assertFile "${pageFile}"
    local data; data="${ pageData "${pageFile}"; }"
    assertEqual "Bob O'Brien" "${ jq -r '.author' <<< "${data}"; }"
    assertEqual 2 "${ jq '.contacts | length' <<< "${data}"; }"
    assertEqual '["The passphrase is in the safe."]' "${ jq -c '.notes' <<< "${data}"; }" "a notes string must become a list"
}

testPageLeavesOutTemplateSamples() {
    local info="${testDir}/template.info" page
    cp "${valtHome}/etc/key-info-template.sh" "${info}" || fail
    newKeyInfoPage "${info}" "${testDir}" page
    assertEqual '{"greeting":"","closing":"","author":"","contacts":[],"notes":[]}' "${ pageData "${page}"; }"

    newKeyInfoPage "${testDir}/missing.info" "${testDir}" page
    assertEqual '' "${ pageData "${page}" | jq -r '.author'; }" "a missing key.info must give an empty form"
}

testPageCannotEndItsScript() {
    local info="${testDir}/script.info" page
    printf '%s\n' "author='</script><script>alert(1)</script>'" "contacts=('x: y')" > "${info}"
    newKeyInfoPage "${info}" "${testDir}" page
    assertEqual 2 "${ grep -c '</script>' "${page}"; }" "a value must not end the data script"
    assertEqual '</script><script>alert(1)</script>' "${ pageData "${page}" | jq -r '.author'; }"
}

testImportRoundTrip() {
    local info="${testDir}/roundtrip.info" page
    writeKeyInfo "${info}"
    local before; keyInfoValues "${info}" before
    newKeyInfoPage "${info}" "${testDir}" page
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
    echo '{"greeting":"Hi","closing":"Bye","author":"From The Page","contacts":["A: 1"]}' > "${downloads}/valt-key-info.json"
    wait ${pid}
    assertEqual 0 $? "key-info must succeed: ${ cat "${outputFile}"; }"
    assertContains "Saved" "${ cat "${outputFile}"; }"
    [[ ${ cat "${outputFile}"; } != *"command not found"* && ${ cat "${outputFile}"; } != *"🔺"* ]] \
        || fail "key-info must run without errors: ${ cat "${outputFile}"; }"
    assertContains 'author="From The Page"' "${ ( sourceConfigFile "${info}"; declare -p author ); }"
    assertFileDoesNotExist "${downloads}/valt-key-info.json"
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
    echo '{"greeting":"New","closing":"New","author":"New Download","contacts":["A: 1"]}' > "${downloads}/valt-key-info (1).json"
    wait ${pid}
    assertContains 'author="New Download"' "${ ( sourceConfigFile "${info}"; declare -p author ); }" \
        "a download from before the page was opened must be ignored"
    assertFile "${downloads}/valt-key-info.json"
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
    echo '{"greeting":"Hi","closing":"Bye","author":"Kept","contacts":["A: 1"]}' > "${downloads}/valt-key-info.json"
    chmod 555 "${downloads}" || fail
    wait ${pid}
    local status=$?
    chmod 755 "${downloads}"
    assertEqual 0 ${status} "key-info must still succeed: ${ cat "${outputFile}"; }"
    assertContains 'author="Kept"' "${ ( sourceConfigFile "${info}"; declare -p author ); }"
    assertContains "please delete it yourself" "${ stripAnsi "${ cat "${outputFile}"; }"; }"
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
    echo "${json}" > "${downloads}/valt-key-info.json"
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

# Use a temp HOME, so that the real valt config is not touched

declare -gx HOME; HOME="${ mktemp -d; }"
source rayvn.up 'rayvn/test' 'rayvn/config' 'valt/key-info' 'valt/paper-keys'
main "$@"
