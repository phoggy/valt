#!/usr/bin/env bash

# ◇ Checks that the key info file is complete, so that a paper key PDF can be made from it, exiting with what it still
#   needs if not (see keyInfoProblems).
#
# · ARGS
#
#   [keyInfoFile] (string)  Path to the key info file (default: ${valtConfigDir}/key-info.json)

preparePaperKey() {
    _assertKeyInfoComplete "${1:-${_defaultKeyInfoFile}}"
}

# ◇ Warns if a valt private key has no paper key, or if its paper key is older than the key or
#   the key info file. Otherwise, when at a terminal, asks whether the paper key has been printed
#   and its copies stored securely, and whether the private key file has been backed up, offering
#   to be reminded in a number of days or to stop asking.
#   The answers are kept per paper key, so a regenerated paper key is asked about again. Does
#   nothing for files that are not valt private keys.
#
# · ARGS
#
#   keyFile (string)        Path to a private key file.
#   [keyInfoFile] (string)  Path to the key info file (default: ${valtConfigDir}/key-info.json)
#
# · ENV VARS
#
#   rayvnTest_PaperKeyAnswers  Test hook: answers to use instead of prompting, in order, separated
#                              by spaces: 'yes', 'stop', 'remind:DAYS' or 'timeout'.

remindPaperKey() {
    local keyFile="$1"
    local keyInfoFile="${2:-${_defaultKeyInfoFile}}"
    local type; type="${ ( keyType "${keyFile}" ) 2> /dev/null; }"
    [[ ${type} == "${valtPrivateKeySuffix}" ]] || return 0

    migrateLegacyKeyInfo "${keyInfoFile}"
    local paperKeyFile; paperKeyFile="${ _paperKeyFile "${keyFile}"; }"
    local key; key="${ tildePath "${keyFile}"; }"
    local command; command="${ paperKeyCommand "${keyFile}"; }"

    if [[ ! -f "${paperKeyFile}" ]]; then
        warn "No paper key backup exists for" bold "${key}" glue "; generate one with" bold blue "${command}"
    elif [[ "${keyFile}" -nt "${paperKeyFile}" ]]; then
        warn "The paper key for" bold "${key}" "is older than the key; regenerate it with" bold blue "${command}"
    elif [[ "${keyInfoFile}" -nt "${paperKeyFile}" ]]; then
        warn "Your key info has changed since the paper key for" bold "${key}" "was generated; regenerate it with" \
             bold blue "${command}"
    elif [[ -n ${rayvnTest_PaperKeyAnswers:-} ]] || [[ -t 0 && -t 1 ]]; then
        _askAboutPaperKey "${paperKeyFile}" "${keyFile}"
    fi
    return 0
}

# ◇ Outputs the paper command for a private key file, omitting the path if it is the default key.
#
# · ARGS
#
#   keyFile (file)  Path to a private key file.

paperKeyCommand() {
    local keyFile="$1"
    if [[ ${keyFile} == "${ defaultValtKeyFile; }" ]]; then
        echo 'valt paper'
    else
        echo "valt paper ${ tildePath "${keyFile}"; }"
    fi
}

# ◇ Generates a paper key PDF from a private key file, storing the output path in a result variable.
#
# · ARGS
#
#   privateKeyFile (string)   Path to the private key file.
#   resultVarRef   (string)   Name of the variable to receive the output paper key file path.
#   [keyInfoFile]  (string)   Path to the key info file (default: ${valtConfigDir}/key-info.json).
#   [styleFile]    (string)   Path to an optional typst style override file (see etc/key-doc-style.typ).
#   [templateFile] (string)   Path to a typst template file (default: ${valtHome}/etc/key-doc-template.typ).

newPaperKey() {
    _assertValtKey "$1"
    local privateKeyFile="$1"
    local -n resultVarRef="$2"
    local keyInfoFile="${3:-${_defaultKeyInfoFile}}"
    local styleFile="${4:-}"
    local templateFile="${5:-}"
    local _paperKeyFile; _paperKeyFile="${ _paperKeyFile "${privateKeyFile}"; }"
    local workDir; _initSecureTempDir workDir

    [[ -n "${styleFile}" ]] && assertFile "${styleFile}"
    [[ -n "${templateFile}" ]] && assertFile "${templateFile}" || templateFile="${_defaultTemplateFile}"

    _assertKeyInfoComplete "${keyInfoFile}"
    _newPaperKey "${privateKeyFile}" "${keyInfoFile}" "${templateFile}" "${styleFile}" "${workDir}" "${_paperKeyFile}"
    resultVarRef="${_paperKeyFile}"
}

# ◇ Shows the steps to take after a paper key is generated, as a numbered list, and that valt will ask about them
#   later (see remindPaperKey).
#
# · ARGS
#
#   keyFile (string)    Path to the private key file the paper key was made from, for the step to back it up.
#   [replacing] (bool)  1 if the paper key replaced an earlier one, adding a step to destroy its printed copies
#                       (default: 0).

showPaperKeyNextSteps() {
    local keyFile="$1"
    local replacing=${2:-0}
    local -a steps=(
        "${ show bold "Print" italic primary "at least" bold "one copy."; }"
        "${ show bold "Decide on your passphrase:" "write it on the last page, or, more securely, say in the Notes" \
               "where to find it."; }"
        "${ show bold "Store copies in secure locations" glue ", e.g. a safe deposit box or fire safe, and/or with" \
               "trusted people."; }"
        "${ show bold "Back up your private key file" glue ":" "copy" cyan "${ tildePath "${keyFile}"; }" \
               "to a password manager, USB drive or cloud storage (it is encrypted, so copies are safe)."; }"
    )
    (( replacing )) && steps+=("${ show bold "Destroy any printed copies of the previous paper key" glue \
                                    ", so that its outdated information is not relied upon."; }")
    header 2 "Important Next Steps"
    printList "${steps[@]}"
    echo
    echo "Both passphrase choices have trade-offs. These, and some good places to keep a passphrase, are described in"
    show bold "Where to keep the passphrase" "on the" bold "How it works" "tab of the" bold blue "valt key-info" "page."
    echo
    echo "To remind you of these critical steps, valt will ask whether you have done them the next time you use it,"
    echo "until you confirm them."
}

# ◇ Shows why and how to back up a private key file: copies are safe to keep, since it is encrypted with its
#   passphrase, and without one, losing the computer leaves only the paper key (if any) to recover files with.
#
# · ARGS
#
#   keyFile (string)  Path to the private key file.

showKeyBackupAdvice() {
    local keyFile="$1"
    echo
    header 2 "Back Up Your Private Key"
    show "Copy" cyan "${ tildePath "${keyFile}"; }" "to at least one other place: a password manager (as an attachment), a"
    echo "USB drive, or cloud storage. It is encrypted with your passphrase, so a copy is useless to anyone without it."
    echo "Without a copy, losing this computer leaves only a paper key, if you have made one, to recover your files with."
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'valt/paper-keys' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_valt_paper-keys() {
    require 'rayvn/config' 'valt/keys' 'valt/key-info'

    currentProjectName='valt' # force, since part of valt project
    local configDir; configDir="${ configDirPath; }"
    declare -gr valtConfigDir="${configDir}"
    declare -gr _defaultKeyInfoFile="${valtConfigDir}/key-info.json"
    declare -gr _defaultTemplateFile="${valtHome}/etc/key-doc-template.typ"
    declare -gr _defaultStyleFile="${valtHome}/etc/key-doc-style.typ"
    declare -gr _paperKeyStateFile="${valtConfigDir}/paper-keys.state" # answers to the printed and stored questions
    declare -gr _fontsDir="${valtHome}/etc/fonts"
    declare -gr _logoFile="${valtHome}/etc/phoggy.png"

    # File names in the work dir, where the template finds them (the template and style names are fixed, since the
    # template imports the style file)

    declare -gr _templateFileName='template.typ'
    declare -gr _styleFileName='style.typ'
    declare -gr _dataFileName='data.json'
    declare -gr _logoFileName='logo.png'
    declare -gr _qrCodeFileName='qr.svg'
    declare -gr _armoredKeyFileName='key.pem'
}

# Asks whether the paper key has been printed, whether the passphrase is written on the copies (or where to find it is
# noted), whether the copies are stored securely, and whether the private key file is backed up, starting from the
# first not yet answered yes, unless all are done, the user stopped the questions, or the reminder date they chose has
# not passed. Answers are kept in the state file.

_askAboutPaperKey() {
    local pdfFile="$1" keyFile="$2"
    local state remindAfter reminder
    _readPaperKeyState "${pdfFile}" state remindAfter
    [[ ${state} == backedUp || ${state} == stopped ]] && return 0
    (( remindAfter > EPOCHSECONDS )) && return 0

    require 'rayvn/prompt'
    local path; path="${ tildePath "${pdfFile}"; }"
    header -u 5 "Paper Key Reminder 📅" "${ show "File" blue "${path}"; }"

    if [[ ${state} == new ]]; then
        reminder="Have you printed copies of your paper key?"
        _askPaperKeyQuestion "${pdfFile}" new "${reminder}" || return 0
        _writePaperKeyState "${pdfFile}" printed 0
        state=printed
    fi
    if [[ ${state} == printed ]]; then
        reminder="Have you written your passphrase on the last page of the copies, or added notes saying where to find it?"
        _askPaperKeyQuestion "${pdfFile}" printed "${reminder}" || return 0
        _writePaperKeyState "${pdfFile}" noted 0
        state=noted
    fi
    if [[ ${state} == noted ]]; then
        reminder="Have you stored your paper key copies somewhere secure, e.g. a safe deposit box, fire safe and/or with people you trust?"
        _askPaperKeyQuestion "${pdfFile}" noted "${reminder}" || return 0
        _writePaperKeyState "${pdfFile}" stored 0
        show nl "Great. Your paper keys are now ready if ever needed."
    fi
    reminder="Have you backed up your private key file, ${ tildePath "${keyFile}"; }, e.g. in a password manager, on a USB drive or in cloud storage?"
    _askPaperKeyQuestion "${pdfFile}" stored "${reminder}" || return 0
    _writePaperKeyState "${pdfFile}" backedUp 0
    show nl "Great. Your private key is backed up."
}

# Asks a yes / remind me / stop asking question about the paper key, in its current state. Succeeds on yes; otherwise
# records the reminder date (asking for the number of days) or that the user stopped the questions, and fails. No
# answer (a timeout, or ESC) means remind tomorrow.

_askPaperKeyQuestion() {
    local pdfFile="$1" state="$2" question="$3"
    local answer days=1
    if [[ -n ${rayvnTest_PaperKeyAnswers:-} ]]; then
        answer="${rayvnTest_PaperKeyAnswers%% *}"
        rayvnTest_PaperKeyAnswers="${rayvnTest_PaperKeyAnswers#"${answer}"}"
        rayvnTest_PaperKeyAnswers="${rayvnTest_PaperKeyAnswers# }"
        [[ ${answer} == remind:* ]] && { days="${answer#remind:}"; answer=remind; }
    else
        local -a choices=('yes' 'remind me later' 'stop asking')
        local choice
        if choose "${ echo "${question}"; }" choices choice; then
            answer="${ case ${choice} in 0) echo yes ;; 1) echo remind ;; 2) echo stop ;; esac; }"
            [[ ${answer} == remind ]] && _askReminderDays days
        else
            answer=timeout
        fi
    fi

    case ${answer} in
        yes) return 0 ;;
        stop)
            _writePaperKeyState "${pdfFile}" stopped 0
            show nl "OK, no more questions about this paper key. Regenerating it will ask again."
            ;;
        *)
            _writePaperKeyState "${pdfFile}" "${state}" $(( EPOCHSECONDS + days * 86400 ))
            if (( days == 0 )); then
                show nl "OK, I'll ask again the next time you use valt."
            else
                show nl "OK, I'll ask again the next time you use valt after ${ _countOf ${days} day; }."
            fi
            ;;
    esac
    return 1
}

# Asks for a number of days until the next reminder (default 7; 0 means the next time it applies), setting the named
# var. No answer means 1.

_askReminderDays() {
    local -n _ardDaysRef=$1
    local input
    while true; do
        request "Remind you in how many days? (default 7, enter 0 for the next time)" input false || { _ardDaysRef=1; return 0; }
        [[ -z ${input} ]] && input=7
        if [[ ${input} =~ ^[0-9]+$ ]]; then
            _ardDaysRef=$(( 10#${input} )) # 10#: so that e.g. 07 is not read as octal
            return 0
        fi
        warn "Please enter a whole number of days."
    done
}

# Prints the count and noun, adding an 's' unless the count is 1, e.g. '1 day', '7 days'.

_countOf() {
    local count=$1 noun="$2"
    (( count == 1 )) && echo "${count} ${noun}" || echo "${count} ${noun}s"
}

# Sets the named vars to the paper key's state ('new', 'printed', 'noted' (the passphrase, or where to find it, is on the
# copies), 'stored' or 'stopped') and the epoch seconds before which not to ask again. The state is 'new' unless
# recorded for this PDF's current contents, so a regenerated paper key starts over.

_readPaperKeyState() {
    local pdfFile="$1"
    local -n _rpksStateRef=$2
    local -n _rpksRemindAfterRef=$3
    _rpksStateRef=new
    _rpksRemindAfterRef=0
    [[ -f ${_paperKeyStateFile} ]] || return 0
    local fingerprint; fingerprint="${ _paperKeyFingerprint "${pdfFile}"; }"
    # (record* names, so as not to hide the caller's vars from the namerefs, e.g. 'state')
    local recordPath recordPrint recordState recordRemindAfter
    while IFS=$'\t' read -r recordPath recordPrint recordState recordRemindAfter; do
        if [[ ${recordPath} == "${pdfFile}" && ${recordPrint} == "${fingerprint}" ]]; then
            _rpksStateRef="${recordState}"
            _rpksRemindAfterRef="${recordRemindAfter:-0}"
        fi
    done < "${_paperKeyStateFile}"
}

# Records the paper key's state and reminder time, replacing any earlier record for its path.

_writePaperKeyState() {
    local pdfFile="$1" state="$2" remindAfter="$3"
    local fingerprint; fingerprint="${ _paperKeyFingerprint "${pdfFile}"; }"
    local -a lines=()
    local line
    if [[ -f ${_paperKeyStateFile} ]]; then
        while IFS= read -r line; do
            [[ ${line%%$'\t'*} == "${pdfFile}" ]] || lines+=("${line}")
        done < "${_paperKeyStateFile}"
    fi
    lines+=("${pdfFile}"$'\t'"${fingerprint}"$'\t'"${state}"$'\t'"${remindAfter}")
    printf '%s\n' "${lines[@]}" > "${_paperKeyStateFile}" || fail "could not write ${_paperKeyStateFile}"
}

# Forgets the answers for a paper key, so that its questions are asked again.

_clearPaperKeyState() {
    local pdfFile="$1"
    [[ -f ${_paperKeyStateFile} ]] || return 0
    local -a lines=()
    local line
    while IFS= read -r line; do
        [[ ${line%%$'\t'*} == "${pdfFile}" ]] || lines+=("${line}")
    done < "${_paperKeyStateFile}"
    if (( ${#lines[@]} )); then
        printf '%s\n' "${lines[@]}" > "${_paperKeyStateFile}" || fail "could not write ${_paperKeyStateFile}"
    else
        rm -f "${_paperKeyStateFile}" || fail
    fi
}

_paperKeyFingerprint() {
    sha256sum < "$1" | head -c 16
}

_paperKeyFile() {
    local keyFile="$1"
    local keyDir; keyDir="${ dirName "${keyFile}"; }"
    local keyName; keyName="${ baseName "${keyFile}"; }"
    echo "${keyDir}/${keyName//./-}.pdf"
}

_initSecureTempDir() {
    local resultVarName="$1"
    local isRamBacked
    makeSecureTempDir "${resultVarName}" isRamBacked
    (( isRamBacked )) || warn "Secure temp storage unavailable; passphrase will be written to disk temporarily."
}

# Exits, saying what it still needs and how to fill it in, unless the key info file is complete.

_assertKeyInfoComplete() {
    local keyInfoFile="$1"
    local -a problems=()
    mapfile -t problems < <(keyInfoProblems "${keyInfoFile}")
    (( ${#problems[@]} )) || return 0
    echo
    show "Your key info" bold "${ tildePath "${keyInfoFile}"; }" "is not complete yet. It needs:"
    printList "${problems[@]}"
    echo
    show "Fill it in with" bold blue "valt key-info" glue ", then try again."
    bye
}

_newPaperKey() {
    local keyFile="$1"
    local keyInfoFile="$2"
    local templateFile="$3"
    local styleFile="$4"
    local workDir="$5"
    local outputFile="$6"

    # Copy the template, style and logo files to the work dir

    cp "${templateFile}" "${workDir}/${_templateFileName}" || fail
    cp "${styleFile:-${_defaultStyleFile}}" "${workDir}/${_styleFileName}" || fail
    cp "${_logoFile}" "${workDir}/${_logoFileName}" || fail

    # Create QR code using the best error correction level we can given the file size

    local qrCodeFile="${workDir}/${_qrCodeFileName}"
    _createQRCodeSvg "${keyFile}" "${qrCodeFile}"
    assertFileExists "${qrCodeFile}"

    # Write the key in armored form, and a checksum, as a backup in case of QR code issues

    armorKeyFile "${keyFile}" > "${workDir}/${_armoredKeyFileName}" || fail
    local checksum; checksum="${ sha256sum "${keyFile}" | head -c 16; }"

    # Write the document data (key info values and generated values) and compile the PDF. System fonts are ignored
    # (the bundled ones are used) unless a style file is given, which may use any installed font.

    _writeDocumentData "${keyInfoFile}" "${checksum}" "${workDir}/${_dataFileName}"
    _assertTypstVersion
    local -a typstArgs=(--root "${workDir}" --font-path "${_fontsDir}")
    [[ -z ${styleFile} ]] && typstArgs+=(--ignore-system-fonts)
    if ! typst compile "${typstArgs[@]}" "${workDir}/${_templateFileName}" "${outputFile}"; then
        local sources; sources="${ tildePath "${templateFile}"; }"
        [[ -n ${styleFile} ]] && sources+=" (${_styleFileName} is ${ tildePath "${styleFile}"; })"
        fail "could not generate the paper key PDF from ${sources}; see the errors above"
    fi

    # Set the creator (typst sets the title, author, subject and keywords from the template)

    local creator; creator="${ projectVersion valt; }, ${valtProjectUrl}"
    exiftool -Creator="${creator}" -overwrite_original "${outputFile}" > /dev/null || fail

    # Encrypt with a strong owner password so that permissions cannot be changed, ensuring
    # that the user password is empty so viewing does not require a password. The owner
    # password should never be required. Note that if we ever want actual form fields,
    # the --modify option must be changed to allow filling.

    local ownerPW; ownerPW="${ phraze; }"
    local userPW=''

    qpdf ${outputFile} \
      --encrypt "${userPW}" "${ownerPW}" 256 --modify=none -- \
      --replace-input  || fail
}

# Fails unless typst 0.15 or later, the first to support the variable fonts in etc/fonts, is installed.

_assertTypstVersion() {
    local version major minor rest
    version="${ typst --version 2> /dev/null; }" || fail "typst is required to generate the paper key PDF"
    version="${version#typst }"
    version="${version%% *}"
    IFS=. read -r major minor rest <<< "${version}"
    (( major > 0 || minor >= 15 )) || fail "typst ${version} is too old: the paper key PDF needs typst 0.15 or later"
}

# Writes the data the template reads: every value in the key info file ('notes' always a list), plus a 'generated'
# object with the date, the key checksum, the work dir names of the logo, QR code and armored key files, and valt's
# release tag (see valtReleaseTag).

_writeDocumentData() {
    local keyInfoFile="$1"
    local checksum="$2"
    local outputFile="$3"
    jq --arg date "${ date '+%B %-d, %Y'; }" --arg checksum "${checksum}" --arg logo "${_logoFileName}" \
       --arg qrCode "${_qrCodeFileName}" --arg armoredKey "${_armoredKeyFileName}" --arg releaseTag "${ valtReleaseTag; }" '
        .notes = (.notes // [])
        | .generated = {date: $date, checksum: $checksum, logo: $logo, qrCode: $qrCode, armoredKey: $armoredKey,
                        releaseTag: $releaseTag}
    ' "${keyInfoFile}" > "${outputFile}" || fail "could not read ${ tildePath "${keyInfoFile}"; }"
}

_createQRCodeSvg() {
    local inputFile="$1"
    local outputFile="$2"
    local size; size=$(( ${ wc -c < "${inputFile}"; } ))
    local level

    # Use the best error correction level we can given the file size
    #
    #    ┌───────┬───────────┐
    #    │ Level │ Max bytes │
    #    ├───────┼───────────┤
    #    │ L     │ 2953      │
    #    ├───────┼───────────┤
    #    │ M     │ 1817      │
    #    ├───────┼───────────┤
    #    │ Q     │ 1273      │
    #    ├───────┼───────────┤
    #    │ H     │ 858       │
    #    └───────┴───────────┘

    local level;
    if (( size <= 858 )); then
        level=H
    elif (( size <= 1273 )); then
        level=Q
    elif (( size <= 1817 )); then
        level=M
    elif (( size <= 2953 )); then
        level=L
    else
        fail "cannot construct QR code, data size too large"
    fi
    qrtool encode -r "${inputFile}" -l "${level}" -t svg -o "${outputFile}" || fail
}

