#!/usr/bin/env bash

# ◇ Loads key info from a file to prepare a paper key PDF, sourcing key metadata
#   needed for QR and PEM generation.
#
# · ARGS
#
#   [keyInfoFile] (string)  Path to the key info file (default: ${valtConfigDir}/key.info)

preparePaperKey() {
    local keyInfoFile="${1:-${_defaultKeyInfoFile}}"
    {
        _loadKeyInfo "${keyInfoFile}"
    }
}

# ◇ Returns 0 if the key info file has been marked completed, 1 otherwise. If the file does not
#   exist, it is created from the template so that it can be edited.
#
# · ARGS
#
#   [keyInfoFile] (string)  Path to the key info file (default: ${valtConfigDir}/key.info)

isKeyInfoComplete() {
    local keyInfoFile="${1:-${_defaultKeyInfoFile}}"
    if [[ ! -f "${keyInfoFile}" ]]; then
        cp "${_keyInfoTemplateFile}" "${keyInfoFile}" || fail
        return 1
    fi
    ( sourceConfigFile "${keyInfoFile}"; [[ ${completed} == 'yes' ]] )
}

# ◇ Warns if a valt private key has no paper key, or if its paper key is older than the key or
#   the key.info file. Does nothing for files that are not valt private keys.
#
# · ARGS
#
#   keyFile (string)        Path to a private key file.
#   [keyInfoFile] (string)  Path to the key info file (default: ${valtConfigDir}/key.info)

remindPaperKey() {
    local keyFile="$1"
    local keyInfoFile="${2:-${_defaultKeyInfoFile}}"
    local type; type="${ ( keyType "${keyFile}" ) 2> /dev/null; }"
    [[ ${type} == "${valtPrivateKeySuffix}" ]] || return 0

    local paperKeyFile; paperKeyFile="${ _paperKeyFile "${keyFile}"; }"
    local key; key="${ tildePath "${keyFile}"; }"
    local command; command="${ paperKeyCommand "${keyFile}"; }"

    if [[ ! -f "${paperKeyFile}" ]]; then
        warn "No paper key backup exists for" bold "${key}" glue "; generate one with" bold blue "${command}"
    elif [[ "${keyFile}" -nt "${paperKeyFile}" ]]; then
        warn "The paper key for" bold "${key}" "is older than the key; regenerate it with" bold blue "${command}"
    elif [[ "${keyInfoFile}" -nt "${paperKeyFile}" ]]; then
        warn "key.info has changed since the paper key for" bold "${key}" "was generated; regenerate it with" \
             bold blue "${command}"
    fi
    return 0
}

# ◇ Outputs the paper command for a private key file, omitting the path if it is the default key.
#
# · ARGS
#
#   keyFile (string)  Path to a private key file.

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
#   [keyInfoFile]  (string)   Path to the key info file (default: ${valtConfigDir}/key.info).
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

    _loadKeyInfo "${keyInfoFile}"
    _newPaperKey "${privateKeyFile}" "${keyInfoFile}" "${templateFile}" "${styleFile}" "${workDir}" "${_paperKeyFile}"
    resultVarRef="${_paperKeyFile}"
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'valt/paper-keys' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_valt_paper-keys() {
    require 'rayvn/config' 'valt/keys'

    currentProjectName='valt' # force, since part of valt project
    local configDir; configDir="${ configDirPath; }"
    declare -gr valtConfigDir="${configDir}"
    declare -gr _defaultKeyInfoFile="${valtConfigDir}/key.info"
    declare -gr _defaultTemplateFile="${valtHome}/etc/key-doc-template.typ"
    declare -gr _defaultStyleFile="${valtHome}/etc/key-doc-style.typ"
    declare -gr _keyInfoTemplateFile="${valtHome}/etc/key-info-template.sh"
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

_loadKeyInfo() {
    local infoFile="$1"
    local status="has not been"

    if [[ ! -f "${infoFile}" ]]; then
        cp "${_keyInfoTemplateFile}" "${infoFile}" || fail
        status="must be"
     else
        sourceConfigFile "${infoFile}"
        _assertKeyInfoVar "${infoFile}" closing author completed
        _assertKeyInfoArrayVar "${infoFile}" contacts

        if [[ ${completed} == 'yes' ]]; then
            return 0
        fi
    fi

    echo
    show "The" bold "key.info" "file at" blue "${valtConfigDir}" "${status} completed."
    echo "Please edit and complete it before proceeding."
    bye
}

_assertKeyInfoVar() {
    local file="$1"; shift
    while (( $# > 0 )); do
        local varName="$1"
        [[ -v ${varName} ]] || bye "The '${varName}' variable is missing in ${file}."
        [[ -n ${!varName} ]] || bye "The '${varName}' variable cannot be empty in ${file}."
        shift
    done
}

_assertKeyInfoArrayVar() {
    local file="$1"
    local name="$2"
    declare -p "${name}" &> /dev/null || bye "The '${name}' array variable is missing in ${file}."

    [[ ${ declare -p "${name}" 2> /dev/null; } =~ ^declare\ -[A-Za-z]*a ]] || bye "The '${name}' variable must be an array in ${file}."

    local -n nameRef="${name}"
    (( ${#nameRef[@]} > 0 )) || bye "The '${name}' array variable cannot be empty in ${file}."
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

    # Write the document data (key.info values and generated values) and compile the PDF. System fonts are ignored
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

# Writes the data the template reads: every variable set in key.info (an array as a JSON array, e.g. contacts, otherwise
# a string; 'notes' is always an array), plus a 'generated' object with the date, the key checksum and the work dir names
# of the logo, QR code and armored key files.

_writeDocumentData() {
    local keyInfoFile="$1"
    local checksum="$2"
    local outputFile="$3"
    local -a names=()
    local line name
    while IFS= read -r line; do
        [[ ${line} =~ ^([A-Za-z][A-Za-z0-9_]*)= ]] || continue
        name="${BASH_REMATCH[1]}"
        [[ ${name} == completed ]] || memberOf "${name}" names || names+=("${name}")
    done < "${keyInfoFile}"

    local json; json="${ jq -n \
        --arg date "${ date '+%B %-d, %Y'; }" --arg checksum "${checksum}" --arg logo "${_logoFileName}" \
        --arg qrCode "${_qrCodeFileName}" --arg armoredKey "${_armoredKeyFileName}" \
        '{generated: {date: $date, checksum: $checksum, logo: $logo, qrCode: $qrCode, armoredKey: $armoredKey}}'; }" || fail
    local value
    for name in "${names[@]}"; do
        [[ -v ${name} ]] || continue
        if [[ ${ declare -p "${name}" 2> /dev/null; } =~ ^declare\ -[A-Za-z]*a ]]; then # an indexed array
            local -n arrayRef="${name}"
            value="${ jq -n '$ARGS.positional | map(select(length > 0))' --args "${arrayRef[@]}"; }" || fail
            unset -n arrayRef
        elif [[ ${name} == notes ]]; then
            value="${ jq -n --arg note "${!name}" 'if $note == "" then [] else [$note] end'; }" || fail
        else
            value="${ jq -n --arg value "${!name}" '$value'; }" || fail
        fi
        json="${ jq --arg name "${name}" --argjson value "${value}" '.[$name] = $value' <<< "${json}"; }" || fail
    done
    [[ -v notes ]] || json="${ jq '.notes = []' <<< "${json}"; }"
    echo "${json}" > "${outputFile}" || fail
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

