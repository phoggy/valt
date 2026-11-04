#!/usr/bin/env bash

# Filling in key.info, the paper key's personal information, from a web page.
# Use via: require 'valt/key-info'

# ◇ Writes the key info web page (a single HTML file with no network access) to a directory, with the current values
#   from the key info file filled in, so that it can be opened in a browser. Values that are still the template's
#   samples are left out, unless key.info is marked completed. The page's Save button downloads valt-key-info-ID.json (ID being unique to this page),
#   encrypted with one-time keys that are also embedded in the page, for decryptKeyInfoDownload.
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
    local json; json="${ _currentKeyInfoJson "${keyInfoFile}"; }" || fail
    json="${json//<\//<\\/}" # so that a value cannot end the script element
    html="${html/'<script id="key-info-data" type="application/json">{}</script>'/<script id=\"key-info-data\" type=\"application/json\">${json}</script>}"

    local id encryptionKey macKey
    id="${ printf '%06d' $(( 16#${ _randomHex 4; } % 1000000 )); }" || fail
    encryptionKey="${ _randomHex 32; }" || fail
    macKey="${ _randomHex 32; }" || fail
    local keysJson="{\"id\":\"${id}\",\"encryptionKey\":\"${encryptionKey}\",\"macKey\":\"${macKey}\",\"expires\":${expires}}" # (a literal } would end the substitution)
    html="${html/'<script id="key-info-keys" type="application/json">{}</script>'/<script id=\"key-info-keys\" type=\"application/json\">${keysJson}</script>}"

    printf '%s\n' "${html}" > "${_nkipPageFile}" || fail "could not write ${_nkipPageFile}"
    _nkipResultRef="${_nkipPageFile}"
    _nkipKeysRef="${id} ${encryptionKey} ${macKey}"
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

# ◇ Imports the key info page's JSON into the key info file, which is replaced and marked completed. Variables in an
#   existing key info file other than those the page sets (e.g. for a custom template) are kept.
#
# · ARGS
#
#   jsonFile (file)       The downloaded JSON.
#   keyInfoFile (string)  Path to the key info file to write.

importKeyInfo() {
    local jsonFile="$1" keyInfoFile="$2"
    assertFile "${jsonFile}"
    jq -e '
        (.greeting, .closing, .author | type == "string" and length > 0)
        and (.contacts | type == "array" and length > 0 and all(type == "string" and length > 0))
        and ((.notes // []) | type == "array" and all(type == "string"))
    ' "${jsonFile}" > /dev/null 2>&1 || fail "${ tildePath "${jsonFile}"; } is not valid key info"

    local greeting closing author
    greeting="${ jq -r '.greeting' "${jsonFile}"; }" || fail
    closing="${ jq -r '.closing' "${jsonFile}"; }" || fail
    author="${ jq -r '.author' "${jsonFile}"; }" || fail
    local -a contacts=() notes=()
    mapfile -t contacts < <(jq -r '.contacts[] | gsub("\n"; " ")' "${jsonFile}")
    mapfile -t notes < <(jq -r '(.notes // [])[] | gsub("\n"; " ")' "${jsonFile}")
    local extras=''
    [[ -f ${keyInfoFile} ]] && extras="${ _extraKeyInfoVars "${keyInfoFile}"; }"

    local temp="${keyInfoFile}.new"
    {
        printf '%s\n' '#!/usr/bin/env bash' '' \
            "# The paper key's personal information. Written by 'valt key-info', which can edit it again, but it can also" \
            "# be edited by hand: see valt's etc/key-info-template.sh for what each value means." ''
        printf 'greeting=%s\n' "${ _shellQuote "${greeting}"; }"
        printf 'closing=%s\n' "${ _shellQuote "${closing}"; }"
        printf 'author=%s\n\n' "${ _shellQuote "${author}"; }"
        _printArrayAssignment contacts "${contacts[@]}"
        _printArrayAssignment notes "${notes[@]}"
        [[ -n ${extras} ]] && printf '%s\n\n' "${extras}"
        printf "completed='yes'\n"
    } > "${temp}" || fail "could not write ${temp}"
    chmod 600 "${temp}" && mv "${temp}" "${keyInfoFile}" || fail "could not write ${keyInfoFile}"
}

# ◇ Outputs the values a key info file sets (every variable, as declare -p output, sorted by name), or nothing if it does
#   not exist, so that two versions can be compared by value whatever their layout.
#
# · ARGS
#
#   keyInfoFile (string)  Path to the key info file.

keyInfoValues() (
    local keyInfoFile="$1"
    [[ -f ${keyInfoFile} ]] || return 0
    local -a names=()
    local line
    while IFS= read -r line; do
        [[ ${line} =~ ^([A-Za-z][A-Za-z0-9_]*)= ]] && names+=("${BASH_REMATCH[1]}")
    done < "${keyInfoFile}"
    (( ${#names[@]} )) || return 0
    sourceConfigFile "${keyInfoFile}"
    local name
    while IFS= read -r name; do
        [[ -v ${name} ]] && declare -p "${name}"
    done < <(printf '%s\n' "${names[@]}" | sort -u)
)

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'valt/key-info' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_valt_key-info() {
    require 'rayvn/config'
    declare -gr _keyInfoPageFile="${valtHome}/etc/key-info.html"
    declare -gr _keyInfoTemplate="${valtHome}/etc/key-info-template.sh"
    declare -gra _keyInfoPageVars=(greeting closing author contacts notes)
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

# Outputs the key info file's page values as JSON (notes as an array). While it is not marked completed, values that are
# still the template's samples are left out. Runs in a subshell, so that the file's variables do not leak.

_currentKeyInfoJson() (
    local keyInfoFile="$1"

    # The template's sample values, to leave out

    sourceConfigFile "${_keyInfoTemplate}"
    local sampleGreeting="${greeting}" sampleClosing="${closing}" sampleAuthor="${author}"
    local sampleContacts="${contacts[*]}"
    unset greeting closing author contacts notes

    # The current values. sourceConfigFile sets globals, so these are not locals (this runs in a subshell)

    greeting='' closing='' author='' completed=''
    contacts=()
    [[ -f ${keyInfoFile} ]] && sourceConfigFile "${keyInfoFile}"

    # Leave out the samples only while key.info is not yet marked completed (e.g. as first created from the template):
    # once it is, show exactly what it holds, so that samples left in it are noticed

    if [[ ${completed} != yes ]]; then
        [[ ${greeting} == "${sampleGreeting}" ]] && greeting=''
        [[ ${closing} == "${sampleClosing}" ]] && closing=''
        [[ ${author} == "${sampleAuthor}" ]] && author=''
        [[ "${contacts[*]}" == "${sampleContacts}" ]] && contacts=()
    fi
    local -a noteList=()
    if [[ ${ declare -p notes 2> /dev/null; } =~ ^declare\ -[A-Za-z]*a ]]; then
        noteList=("${notes[@]}")
    elif [[ -n ${notes:-} ]]; then
        noteList=("${notes}")
    fi
    jq -nc --arg greeting "${greeting}" --arg closing "${closing}" --arg author "${author}" \
        --argjson contacts "${ jq -n '$ARGS.positional' --args "${contacts[@]}"; }" \
        --argjson notes "${ jq -n '$ARGS.positional' --args "${noteList[@]}"; }" \
        '{greeting: $greeting, closing: $closing, author: $author, contacts: $contacts, notes: $notes}'
)

# Outputs count random bytes as hex.

_randomHex() {
    local count=$1
    od -An -tx1 -N "${count}" /dev/urandom | tr -d ' \n'
}

# Outputs assignments for the variables set in the key info file other than those the page sets and 'completed', so
# that importing keeps them (e.g. values used by a custom template).

_extraKeyInfoVars() (
    local keyInfoFile="$1"
    local -a names=()
    local line name
    while IFS= read -r line; do
        [[ ${line} =~ ^([A-Za-z][A-Za-z0-9_]*)= ]] || continue
        name="${BASH_REMATCH[1]}"
        [[ ${name} == completed ]] && continue
        memberOf "${name}" _keyInfoPageVars && continue
        memberOf "${name}" names || names+=("${name}")
    done < "${keyInfoFile}"
    (( ${#names[@]} )) || return 0
    sourceConfigFile "${keyInfoFile}"
    for name in "${names[@]}"; do
        [[ -v ${name} ]] || continue
        if [[ ${ declare -p "${name}" 2> /dev/null; } =~ ^declare\ -[A-Za-z]*a ]]; then
            local -n arrayRef="${name}"
            _printArrayAssignment "${name}" "${arrayRef[@]}"
            unset -n arrayRef
        else
            printf '%s=%s\n' "${name}" "${ _shellQuote "${!name}"; }"
        fi
    done
)

# Outputs an array assignment of the values, one per line.

_printArrayAssignment() {
    local name="$1"; shift
    printf '%s=(\n' "${name}"
    local value
    for value in "$@"; do
        printf '    %s\n' "${ _shellQuote "${value}"; }"
    done
    printf ')\n\n'
}

# Outputs the value single-quoted for bash, e.g. it's -> 'it'\''s'.

_shellQuote() {
    local value="$1"
    printf "'%s'" "${value//\'/\'\\\'\'}"
}
