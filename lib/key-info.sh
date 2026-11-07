#!/usr/bin/env bash

# The paper key's personal information (the key info file), and filling it in.
# From a web page or an editor; also checks the file, converts the key.info file earlier versions of valt used, and
# writes the guide to keys and passphrases for valt's web site.
# Use via: require 'valt/key-info'

#@notes
# ## Key info file format
#
# The key info file, key-info.json in the valt config directory, is JSON: the letter's greeting, closing and author,
# the people who can help (contacts, each with a name and the ways to reach them, each with a type and a value) and
# notes. Any other values are kept, for a custom paper key template:
#
#     {
#       "greeting": "Greetings,",
#       "closing": "I hope you never need this!",
#       "author": "Bob Barker",
#       "contacts": [
#         { "name": "Aunt Martha", "ways": [ { "type": "phone", "value": "+44 791 112 4456", "preferred": true },
#                                            { "type": "address", "value": "1 Park Row, Leeds LS1 5AB, UK" } ] }
#       ],
#       "notes": [ "The passphrase is in the envelope in the fire safe." ]
#     }
#
# A way's type is phone, email, social or address. One of a person's ways may be marked preferred, the one to try
# first. An optional authorShortName is how the paper key refers to the author after first giving their full name
# (default: the first word of it), e.g. a nickname, or the given name of a name with the family name first.
#@end

# ◇ Writes the key info web page (a single HTML file with no network access) to a directory, with the current values
#   from the key info file filled in, so that it can be opened in a browser. The page's Save button downloads
#   valt-key-info-ID.json (ID being unique to this page), encrypted with one-time keys that are also embedded in the
#   page, for decryptKeyInfoDownload. The paper key's fonts are embedded too, for the page's preview of the letter
#   (browsers do not load fonts from beside a local page).
#
# · ARGS
#
#   keyInfoFile (string)   Path to the key info file; it need not exist.
#   dir (dir)              Directory to write the page to.
#   resultRef (stringRef)  Name of the var to receive the page path.
#   keysRef (stringRef)    Name of the var to receive the page's id and one-time keys, for waitForKeyInfoDownload and
#                          decryptKeyInfoDownload.
#   expires (int)          When the page expires, in epoch seconds: after that it no longer saves.

newKeyInfoPage() {
    local keyInfoFile="$1" dir="$2"
    local -n _nkipResultRef=$3
    local -n _nkipKeysRef=$4
    local expires=$5
    local _nkipPageFile="${dir}/key-info.html" # prefixed: a caller may name its var pageFile
    local html; readFile "${_keyInfoPageFile}" html || fail
    local json; json="${ _pageKeyInfoJson "${keyInfoFile}"; }" || fail
    json="${json//<\//<\\/}" # so that a value cannot end the script element
    html="${html/'<script id="key-info-data" type="application/json">{}</script>'/<script id=\"key-info-data\" type=\"application/json\">${json}</script>}"

    local id encryptionKey macKey
    id="${ printf '%06d' $(( 16#${ _randomHex 4; } % 1000000 )); }" || fail
    encryptionKey="${ _randomHex 32; }" || fail
    macKey="${ _randomHex 32; }" || fail
    local keysJson="{\"id\":\"${id}\",\"encryptionKey\":\"${encryptionKey}\",\"macKey\":\"${macKey}\",\"started\":${EPOCHSECONDS},\"expires\":${expires}}" # (a literal } would end the substitution)
    html="${html/'<script id="key-info-keys" type="application/json">{}</script>'/<script id=\"key-info-keys\" type=\"application/json\">${keysJson}</script>}"

    local fontsPlaceholder='<style id="key-info-fonts"></style>'
    {
        printf '%s' "${html%%"${fontsPlaceholder}"*}"
        _keyInfoFontsStyle
        printf '%s\n' "${html#*"${fontsPlaceholder}"}"
    } > "${_nkipPageFile}" || fail "could not write ${_nkipPageFile}"
    _nkipResultRef="${_nkipPageFile}"
    _nkipKeysRef="${id} ${encryptionKey} ${macKey}"
}

# ◇ Writes the key info file's values to a file for editing by hand: pretty printed, with every value the page edits
#   (empty if not yet set), and an empty person to fill in if there is no one yet.
#
# · ARGS
#
#   keyInfoFile (string)  Path to the key info file; it need not exist.
#   draftFile (string)    Path to write the draft to (best in secure temp storage).

newKeyInfoDraft() {
    local keyInfoFile="$1" draftFile="$2"
    migrateLegacyKeyInfo "${keyInfoFile}"
    local existing='{}'
    [[ -f ${keyInfoFile} ]] && existing="${ jq -c 'if type == "object" then . else {} end' "${keyInfoFile}" 2> /dev/null; }"
    jq --argjson page "${ _pageKeyInfoJson "${keyInfoFile}"; }" '
        $page + del(.greeting, .closing, .author, .contacts, .notes)
        | if (.contacts | length) == 0
          then .contacts = [{name: "", ways: [{type: "phone", value: ""}, {type: "email", value: ""}]}] else . end
    ' <<< "${existing:-{\}}" > "${draftFile}" || fail "could not write ${draftFile}"
}

# ◇ Tidies a key info file edited by hand, as the page does on save: ways with no value, and people with no name or way,
#   are dropped. Leaves a file that is not valid JSON alone, for keyInfoProblems to report.
#
# · ARGS
#
#   draftFile (file)  The edited file.

tidyKeyInfoDraft() {
    local draftFile="$1"
    jq -e 'type == "object"' "${draftFile}" > /dev/null 2>&1 || return 0
    local tidy; tidy="${ jq "${_keyInfoJq}"'
        .contacts = [(.contacts // [])[]? | .ways = [(.ways // [])[]? | select(.value | text)]
                     | select(if .name | text then true else .ways | length > 0 end)]
        | if (.authorShortName // "") | text then . else del(.authorShortName) end
    ' "${draftFile}"; }" || fail "could not read ${draftFile}"
    printf '%s\n' "${tidy}" > "${draftFile}" || fail "could not write ${draftFile}"
}

# ◇ Writes the guide to keys and passphrases for valt's web site (a Jekyll page): the key info page's explanatory tabs
#   ('How it works', 'Strong passphrases' and 'Strength in detail'), so that they can be read without the page, e.g.
#   over ssh (see editKeyInfo). The page is the one source: its form, navigation and buttons are left out, and tab links
#   become links within the guide.
#
# · ARGS
#
#   outputFile (string)  Path to write the guide to, e.g. guide/index.html in the pages dir.

writeKeyInfoGuide() {
    local outputFile="$1"
    # lint-skip-start (HTML in the gawk program, not redirects)
    local panels; panels="${ gawk '
        /^    <div id="panel-(understand|strength|detail)" / {
            match($0, /panel-([a-z]+)/, m); inPanel = 1
            print "<section id=\"" m[1] "\" class=\"valt-guide-section\">"; next
        }
        inPanel && /^    <\/div>$/ { print "</section>"; inPanel = 0; next }
        !inPanel { next }
        /<p class="muted">.*Skip to your information/ { next }   # navigation within the page
        /<div class="actions">/ { inActions = 1 }
        inActions { if (/<\/div>/) inActions = 0; next }        # the Next buttons
        {
            gsub(/ data-tab="[a-z]+"/, "")
            for (level = 4; level >= 1; level--) {   # each heading one level down, under the guide page title
                gsub("<h" level, "<h" (level + 1)); gsub("</h" level ">", "</h" (level + 1) ">")
            }
            print
        }
    ' "${_keyInfoPageFile}"; }" || fail "could not read ${_keyInfoPageFile}"
    # lint-skip-end
    [[ ${panels} == *'id="understand"'*'id="strength"'*'id="detail"'* ]] \
        || fail "the key info page's tabs were not found in ${_keyInfoPageFile}"
    ensureDir "${ dirName "${outputFile}"; }"
    {
        cat "${_keyInfoGuideHead}" || fail
        printf '%s\n' "${panels}"
        cat "${_keyInfoGuideTail}" || fail
    } > "${outputFile}" || fail "could not write ${outputFile}"
}

# ◇ Decrypts the key info page's download, written with the one-time keys from newKeyInfoPage, into a file for
#   importKeyInfo. Fails, decrypting nothing, unless the download was made with those keys and is unchanged.
#
# · ARGS
#
#   downloadFile (file)  The downloaded valt-key-info.json.
#   keys (string)        The page's id and keys, from newKeyInfoPage.
#   outputFile (string)  Path to write the decrypted JSON to (best in secure temp storage).

decryptKeyInfoDownload() {
    local downloadFile="$1" keys="$2" outputFile="$3"
    local encryptionKey macKey
    read -r _ encryptionKey macKey <<< "${keys}"
    local name; name="${ tildePath "${downloadFile}"; }"
    jq -e '.format == "valt-key-info-encrypted" and .version == 1 and (.iv | type == "string")
           and (.ciphertext | type == "string") and (.mac | type == "string")' "${downloadFile}" > /dev/null 2>&1 \
        || fail "${name} is not from the key info page"
    local iv ciphertext mac
    iv="${ jq -r '.iv' "${downloadFile}"; }" || fail
    ciphertext="${ jq -r '.ciphertext' "${downloadFile}"; }" || fail
    mac="${ jq -r '.mac' "${downloadFile}"; }" || fail
    [[ ${iv} =~ ^[0-9a-f]{32}$ ]] || fail "${name} is not from the key info page"

    # Check the MAC before decrypting anything. (The keys are briefly visible to this user's processes, e.g. with ps,
    # as openssl arguments; they are used once, for a file that only this user can read.)

    local expected; expected="${ printf '%s' "${iv}.${ciphertext}" | openssl dgst -sha256 -hmac "${macKey}" -r; }" \
        || fail "could not check ${name}"
    [[ ${expected%% *} == "${mac}" ]] || fail "${name} was not saved by this key info page, or has been changed"
    printf '%s' "${ciphertext}" | base64 -d | openssl enc -d -aes-256-cbc -K "${encryptionKey}" -iv "${iv}" \
        > "${outputFile}" 2> /dev/null || fail "could not decrypt ${name}"
}

# ◇ Opens the key info page in the default web browser. On macOS that is the app registered for https links, since the
#   page's own file type may be handled by another app (e.g. an editor). The page must not be on a volume macOS hides
#   from Finder (as rayvn's temp storage is): browsers cannot be given files there.
#
# · ARGS
#
#   pageFile (file)  The page, from newKeyInfoPage.

openKeyInfoPage() {
    local pageFile="$1"
    canOpenUrls || return 1
    if [[ ${OSTYPE} == darwin* ]]; then
        open -b "${ _defaultBrowserBundleId; }" "${pageFile}"
    else
        xdg-open "${pageFile}"
    fi
}

# ◇ Waits for the key info page's download (valt-key-info-ID.json, or a browser's renamed copy such as
#   'valt-key-info-ID (1).json') to appear in a directory after a marker file was created, and outputs its path. If
#   there are several, the most recently modified is used. Downloads from other pages, or from before the marker, are
#   ignored.
#
# · ARGS
#
#   downloadsDir (dir)  The browser's downloads directory.
#   markerFile (file)   A file created before the page was opened; only downloads newer than it count.
#   keys (string)       The page's id and keys, from newKeyInfoPage.
#   deadline (int)      When to stop waiting, in epoch seconds.
#
# · RETURNS
#
#   0  a download was found
#   1  the deadline passed first

waitForKeyInfoDownload() {
    local downloadsDir="$1" markerFile="$2" keys="$3" deadline=$4
    local id="${keys%% *}"
    local file newest
    while true; do

        # The most recently modified of the downloads made since the marker, e.g. if the page was saved twice

        newest=''
        while IFS= read -r -d '' file; do
            [[ -z ${newest} || ${file} -nt ${newest} ]] && newest="${file}"
        done < <(find "${downloadsDir}" -maxdepth 1 -type f -name "valt-key-info-${id}*.json" -newer "${markerFile}" \
                     -print0 2> /dev/null)
        if [[ -n ${newest} ]]; then
            sleep 0.5 # let the browser finish writing it
            echo "${newest}"
            return 0
        fi
        (( EPOCHSECONDS < deadline )) || return 1
        sleep 0.5
    done
}

# ◇ Succeeds if a decrypted key info download is the page's Cancel, rather than its Save.
#
# · ARGS
#
#   jsonFile (file)  The decrypted download, from decryptKeyInfoDownload.

isKeyInfoCancel() {
    jq -e '.cancelled == true' "$1" > /dev/null 2>&1
}

# ◇ Imports the key info page's JSON into the key info file, which is replaced. Values in an existing key info file other
#   than those the page sets (e.g. for a custom template) are kept.
#
# · ARGS
#
#   jsonFile (file)       The downloaded JSON.
#   keyInfoFile (string)  Path to the key info file to write.

importKeyInfo() {
    local jsonFile="$1" keyInfoFile="$2"
    assertFile "${jsonFile}"
    jq -e "${_keyInfoJq}"' isValidDownload' "${jsonFile}" > /dev/null 2>&1 \
        || fail "${ tildePath "${jsonFile}"; } is not valid key info"
    local existing='{}'
    [[ -f ${keyInfoFile} ]] && existing="${ jq -c 'if type == "object" then . else {} end' "${keyInfoFile}" 2> /dev/null; }"
    local temp="${keyInfoFile}.new"
    jq --argjson existing "${existing:-{\}}" "${_keyInfoJq}"'
        (normalized | {greeting, closing, author}
                      + (if (.authorShortName // "") | text then {authorShortName: (.authorShortName | oneLine)} else {} end)
                      + {contacts, notes})
        + ($existing | del(.greeting, .closing, .author, .authorShortName, .contacts, .notes))
    ' "${jsonFile}" > "${temp}" || fail "could not write ${temp}"
    chmod 600 "${temp}" && mv "${temp}" "${keyInfoFile}" || fail "could not write ${keyInfoFile}"
}

# ◇ Outputs the key info file's values as compact JSON with sorted keys, or nothing if it does not exist, so that two
#   versions can be compared by value whatever their layout.
#
# · ARGS
#
#   keyInfoFile (string)  Path to the key info file.

keyInfoValues() {
    local keyInfoFile="$1"
    [[ -f ${keyInfoFile} ]] || return 0
    jq -cS . "${keyInfoFile}" 2> /dev/null || cat "${keyInfoFile}"
}

# ◇ Outputs what the key info file still needs before a paper key can be made from it, one item per line (e.g. 'a
#   greeting'), or nothing if it is complete.
#
# · ARGS
#
#   keyInfoFile (string)  Path to the key info file; it need not exist.

keyInfoProblems() {
    local keyInfoFile="$1"
    migrateLegacyKeyInfo "${keyInfoFile}"
    if [[ ! -f ${keyInfoFile} ]]; then
        echo "your information, from 'valt key-info'"
    elif ! jq -e . "${keyInfoFile}" > /dev/null 2>&1; then
        echo "valid JSON in ${ tildePath "${keyInfoFile}"; }"
    else
        jq -r "${_keyInfoJq}"' problems[]' "${keyInfoFile}"
    fi
}

# ◇ Succeeds if the key info file is complete, so that a paper key can be made from it (see keyInfoProblems).
#
# · ARGS
#
#   keyInfoFile (string)  Path to the key info file; it need not exist.

isKeyInfoComplete() {
    [[ -z ${ keyInfoProblems "$1"; } ]]
}

# ◇ Converts the key.info file that earlier versions of valt used (a bash file, in the same directory) to the key info
#   file, if that does not exist yet, keeping the old file as key.info.bak. Each contact's ways are split out, their
#   types guessed as the key info page does. Values that are still the old template's samples are left out, unless the
#   file was marked completed. Says so on stderr when it converts.
#
# · ARGS
#
#   keyInfoFile (string)  Path to the key info file.

migrateLegacyKeyInfo() {
    local keyInfoFile="$1"
    local legacyFile; legacyFile="${ dirName "${keyInfoFile}"; }/key.info"
    [[ -f ${keyInfoFile} || ! -f ${legacyFile} || ${keyInfoFile} == "${legacyFile}" ]] && return 0
    local json; json="${ _legacyKeyInfoJson "${legacyFile}"; }" || fail "could not convert ${ tildePath "${legacyFile}"; }"
    local temp="${keyInfoFile}.new"
    jq . <<< "${json}" > "${temp}" && chmod 600 "${temp}" && mv "${temp}" "${keyInfoFile}" \
        || fail "could not write ${keyInfoFile}"
    mv "${legacyFile}" "${legacyFile}.bak" || fail "could not rename ${ tildePath "${legacyFile}"; }"
    show "Converted" bold "${ tildePath "${legacyFile}"; }" "to" bold "${ tildePath "${keyInfoFile}"; }" \
         glue "; the old file is now" bold "${ tildePath "${legacyFile}.bak"; }" glue "." >&2
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'valt/key-info' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_valt_key-info() {
    require 'rayvn/config'
    declare -gr _keyInfoPageFile="${valtHome}/etc/key-info.html"
    declare -gr _keyInfoGuideHead="${valtHome}/etc/key-info-guide-head.html" # the guide's front matter and styles
    declare -gr _keyInfoGuideTail="${valtHome}/etc/key-info-guide-tail.html" # its script

    # jq definitions for the key info file and the page's download. A way's type guess (wayType) matches the page's.

    declare -gr _keyInfoJq='
        def wayTypes: ["phone", "email", "social", "address"];
        def text: type == "string" and (gsub("\\s"; "") | length > 0);
        def isValidDownload:
            (.greeting, .closing, .author | text)
            and (.contacts | type == "array" and length > 0 and all(
                (.name | text) and (.ways | type == "array" and length > 0
                                    and all((.type as $t | wayTypes | index($t)) and (.value | text)
                                            and ((.preferred // false) | type == "boolean")))))
            and ((.notes // []) | type == "array" and all(type == "string"))
            and ((.authorShortName // "") | type == "string");
        def oneLine: gsub("\\s*\n\\s*"; " ") | gsub("^\\s+|\\s+$"; "");
        def normalized:
            .greeting |= oneLine | .closing |= oneLine | .author |= oneLine
            | .contacts |= map({name: (.name | oneLine),
                                ways: (reduce .ways[] as $way ({ways: [], preferred: false};
                                           ($way.preferred == true and (.preferred | not)) as $first
                                           | .ways += [{type: $way.type, value: ($way.value | oneLine)}
                                                       + (if $first then {preferred: true} else {} end)]
                                           | .preferred = (.preferred or $first)) | .ways)})
            | .notes = [(.notes // [])[] | oneLine | select(length > 0)];
        def problems:
            [ (if (.greeting | text) then empty else "a greeting" end),
              (if (.closing | text) then empty else "a closing line" end),
              (if (.author | text) then empty else "your name (the signature)" end),
              (if (.contacts | type == "array" and length > 0) then empty else "at least one person who can help" end),
              ((.contacts // []) | if type == "array" then to_entries[] else empty end
               | select((.value.name | text | not)
                        or ([(.value.ways // [])[]? | select(.value | text)] | length == 0)
                        or ([(.value.ways // [])[]? | .type as $t | wayTypes | index($t)] | any(. == null)))
               | "a name and a way (phone, email, social or address) to reach person \(.key + 1)") ];
        def wayType:
            if test("^[^\\s@]+@[^\\s@]+$") then "email"
            elif test("^\\+?[\\d\\s().-]+$") and (gsub("\\D"; "") | length >= 7) then "phone"
            elif test("^https?://\\S+$") or test("^([A-Za-z]+\\s+)?@[\\w.-]+$") then "social"
            else "address" end;
        def parseContact:
            (index(": ")) as $at
            | (if $at != null and $at > 0 then [.[:$at], .[$at + 2:]] else ["", .] end) as [$name, $rest]
            | {name: $name, ways: ([$rest | splits("\\s*,\\s*") | select(length > 0)]
                                   | reduce .[] as $part ([]; ($part | wayType) as $type
                                       | if $type == "address" and length > 0 and .[-1].type == "address"
                                         then .[-1].value += ", " + $part else . + [{type: $type, value: $part}] end))};
    '
    declare -gr _keyInfoFontsDir="${valtHome}/etc/fonts"
    # family (_ for space), file, format, weight (- for a range) and style of each font the page's preview uses
    declare -gr _keyInfoFonts="Google_Sans_Flex GoogleSansFlex[ROND,opsz,slnt,wdth,wght].ttf ttf 100-1000 normal
Shantell_Sans Shantell_Sans-Normal-Regular.otf otf 400 normal
Shantell_Sans Shantell_Sans-Normal-Regular_Italic.otf otf 400 italic
Yellowtail Yellowtail-Regular.ttf ttf 400 normal"
}

# Outputs a style element with the paper key's fonts, as used by the key info page's preview, embedded as data URLs.

_keyInfoFontsStyle() {
    local family file format weight style cssFormat
    echo '<style id="key-info-fonts">'
    while read -r family file format weight style; do
        cssFormat=truetype
        [[ ${format} == otf ]] && cssFormat=opentype
        printf '@font-face { font-family: "%s"; font-weight: %s; font-style: %s; src: url(data:font/%s;base64,' \
               "${family//_/ }" "${weight/-/ }" "${style}" "${format}"
        base64 < "${_keyInfoFontsDir}/${file}" | tr -d '\n' || fail "could not read ${file}"
        printf ') format("%s"); }\n' "${cssFormat}"
    done <<< "${_keyInfoFonts}"
    echo '</style>'
}

# Outputs the bundle id of the macOS default web browser (the https handler), or Safari's if none is set.

_defaultBrowserBundleId() {
    local id
    id="${ defaults export com.apple.LaunchServices/com.apple.launchservices.secure - 2> /dev/null \
           | plutil -convert json -o - - 2> /dev/null \
           | jq -r '[.LSHandlers[]? | select(.LSHandlerURLScheme == "https" or .LSHandlerURLScheme == "http")
                    | .LSHandlerRoleAll // empty] | first // empty' 2> /dev/null; }"
    echo "${id:-com.apple.Safari}"
}

# Outputs the key info file's values that the page edits, as compact JSON with defaults for any that are missing.

_pageKeyInfoJson() {
    local keyInfoFile="$1"
    migrateLegacyKeyInfo "${keyInfoFile}"
    local json='{}'
    [[ -f ${keyInfoFile} ]] && json="${ jq -c 'if type == "object" then . else {} end' "${keyInfoFile}" 2> /dev/null; }"
    jq -c '{greeting: (.greeting // ""), closing: (.closing // ""), author: (.author // ""),
            authorShortName: (.authorShortName // ""),
            contacts: [(.contacts // [])[]? | {name: (.name // ""),
                                               ways: [(.ways // [])[]? | {type, value}
                                                      + (if .preferred == true then {preferred: true} else {} end)]}],
            notes: [(.notes // [])[]? | tostring]}' <<< "${json:-{\}}"
}

# Outputs a key.info file (the bash format earlier versions of valt used) as key info JSON. Runs in a subshell, so that
# the file's variables do not leak.

_legacyKeyInfoJson() (
    local legacyFile="$1"
    local -a names=()
    local line name
    while IFS= read -r line; do
        [[ ${line} =~ ^([A-Za-z][A-Za-z0-9_]*)= ]] || continue
        memberOf "${BASH_REMATCH[1]}" names || names+=("${BASH_REMATCH[1]}")
    done < "${legacyFile}"
    sourceConfigFile "${legacyFile}"

    # Each value as JSON: arrays as lists (notes always one), others as strings, leaving out 'completed'

    local json='{}' value
    for name in "${names[@]}"; do
        [[ ${name} == completed || ! -v ${name} ]] && continue
        if [[ ${ declare -p "${name}" 2> /dev/null; } =~ ^declare\ -[A-Za-z]*a ]]; then
            local -n arrayRef="${name}"
            value="${ jq -n '$ARGS.positional' --args "${arrayRef[@]}"; }" || return 1
            unset -n arrayRef
        elif [[ ${name} == notes ]]; then
            value="${ jq -n --arg note "${!name}" 'if $note == "" then [] else [$note] end'; }" || return 1
        else
            value="${ jq -n --arg value "${!name}" '$value'; }" || return 1
        fi
        json="${ jq --arg name "${name}" --argjson value "${value}" '.[$name] = $value' <<< "${json}"; }" || return 1
    done

    # Contacts' ways split out, and, unless completed, the old template's samples left out

    jq --arg completed "${completed:-}" "${_keyInfoJq}"'
        .contacts = [(.contacts // [])[] | select(length > 0) | parseContact]
        | if $completed == "yes" then . else
              (if .greeting == "Greetings," then .greeting = "" else . end)
              | (if .closing == "I hope you never need this!" then .closing = "" else . end)
              | (if .author == "Bob Barker" then .author = "" else . end)
              | (if [.contacts[].name] == ["Billy Bob", "Aunt Martha"] then .contacts = [] else . end)
          end
        | {greeting: (.greeting // ""), closing: (.closing // ""), author: (.author // ""), contacts,
           notes: (.notes // [])} + del(.greeting, .closing, .author, .contacts, .notes)
    ' <<< "${json}"
)

# Outputs count random bytes as hex.

_randomHex() {
    local count=$1
    od -An -tx1 -N "${count}" /dev/urandom | tr -d ' \n'
}
