#!/usr/bin/env bash

# Creates a PDF documenting use of the included "paper key" generated from a valt.key. A paper key is a printable
# backup of the valt.key binary file, both as a QR code and as PEM file.
#
# Use via: require 'valt/paper-keys'

preparePaperKey() {
    local keyInfoFile="${1:-${_defaultKeyInfoFile}}"
    {
        _loadKeyInfo "${keyInfoFile}"
    }
}

newPaperKey() {
    _assertValtKey "$1"
    local privateKeyFile="$1"
    local -n resultVarRef="$2"
    local keyInfoFile="${3:-${_defaultKeyInfoFile}}"
    local cssOverrideFile="${4:-}"
    local htmlTemplateFile="${5:-}"
    local _paperKeyFile; _paperKeyFile="${ _paperKeyFile "${privateKeyFile}"; }"
    local workDir; _initSecureTempDir workDir

    [[ -n "${cssOverrideFile}" ]] && assertFile "${cssOverrideFile}"
    [[ -n "${htmlTemplateFile}" ]] && assertFile "${htmlTemplateFile}" || htmlTemplateFile="${_defaultHtmlTemplateFile}"

    _loadKeyInfo "${keyInfoFile}"
    _newPaperKey "${privateKeyFile}" "${keyInfoFile}" "${htmlTemplateFile}" "${workDir}" "${_paperKeyFile}"
    resultVarRef="${_paperKeyFile}"
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'valt/paper-keys' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_valt_paper-keys() {
    require 'valt/keys' 'valt/pdf'

    currentProjectName='valt' # force, since part of valt project
    local configDir; configDir="${ configDirPath; }"
    declare -gr valtConfigDir="${configDir}"
    declare -gr _defaultKeyInfoFile="${valtConfigDir}/key.info"
    declare -gr _defaultHtmlTemplateFile="${valtHome}/etc/key-doc-template.html"
    declare -gr _keyInfoTemplateFile="${valtHome}/etc/key-info-template.sh"
    declare -gr _cssMainFileName="key-doc.css"
    declare -gr _logoFileName="phoggy.png"
    declare -gr _assetFiles=("${_cssMainFileName}" "${_logoFileName}")
    declare -gr _cssOverrideFileName='override.css'
    declare -gr _htmlFileName='note.html'
    declare -gr _qrCodeFileName='qr.svg'
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

    if ! declare -p "${name}" 2> /dev/null | grep -q '^declare \-a'; then
    bye "The '${name}' variable must be an array in ${file}."
    fi

    local -n nameRef="${name}"
    (( ${#nameRef[@]} > 0 )) || bye "The '${name}' array variable cannot be empty in ${file}."
}

_newPaperKey() {
    local keyFile="$1"
    local keyInfoFile="$2"
    local htmlTemplateFile="$3"
    local workDir="$4"
    local outputFile="$5"

    # Copy asset files

    local assetFile
    for assetFile in "${_assetFiles[@]}"; do
        cp "${valtHome}/etc/${assetFile}" "${workDir}/${assetFile}" || fail
    done

    if [[ -n ${cssOverrideFile} ]]; then
        cp "${cssOverrideFile}" "${workDir}/${_cssOverrideFileName}" || fail
    fi

    # Create QR code using the best error correction level we can given the file size

    local qrCodeFile="${workDir}/${_qrCodeFileName}"
    _createQRCodeSvg "${keyFile}" "${qrCodeFile}"
    assertFileExists "${qrCodeFile}"

    # Get the key in armored form and checksum to include as a backup in case of QR code issues

    local armoredKey; armoredKey="${ armorKeyFile ${keyFile}; }"
    _CHECKSUM="${ sha256sum ${keyFile} | head -c 16; }"

    # Generate substituted html file and footer template

    htmlFile="${workDir}/${_htmlFileName}"
    _generateHtml "${keyFile}" "${keyInfoFile}" "${htmlTemplateFile}" "${htmlFile}"
    assertFileExists "${htmlFile}"
    local footerTemplate; footerTemplate="${ _generateFooterTemplate; }"

    # Move to work dir so that relative paths in html work correctly and generate the pdf

    cd ${workDir} || fail
    generatePdf "${htmlFile}" "${outputFile}" "${footerTemplate}" > /dev/null || fail

    # Set metadata and encrypt with a strong password

    local title='Private Key Pair Backup & Usage Instructions'
    local creator; creator="${ projectVersion valt; }, ${valtProjectUrl}"
    local subject="File decryption."
    local keywords; keywords="${author}, valt, private key, backup, encryption, decryption, security"

    exiftool \
      -Title="${title}" \
      -Author="${author}" \
      -Subject="${subject}" \
      -Keywords="${keywords}" \
      -Creator="${creator}" \
      -overwrite_original \
      "${outputFile}"  > /dev/null || fail

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

_generateFooterTemplate() {
    local footerClass; footerClass="${ awk '
        /^[[:space:]]*\.footer[[:space:]]*\{/ {
            print
            brace_count = 1
            while (( getline line) > 0) {
                print line
                # Count opening and closing braces
                temp1 = line
                gsub(/[^{]/, "", temp1)
                opening = length(temp1)
                temp2 = line
                gsub(/[^}]/, "", temp2)
                closing = length(temp2)
                brace_count += opening - closing
                if (brace_count == 0) break
            }
            exit
        }
        ' "${valtHome}/etc/key-doc.css"; }"

    # lint-skip-start
    cat <<- EOF
		<style>
		    ${footerClass}
		    .page-info .pageNumber::after {
		        content: " / ";
		    }
		</style>
		<div class="footer">
		    <span> ${author} Private Key</span>
		    <span> ${ date '+%B %e, %Y'; }</span>
		    <span class="page-info"> <span class="pageNumber"> </span> <span class="totalPages"> </span> </span>
		< /div>
	EOF
    # lint-skip-end
}

_passphraseGridHtml() {
    # lint-skip-start
    cat <<- EOF
		<passphrase-grid length="140"> </passphrase-grid>
		<script>
		    class PassphraseGrid extends HTMLElement {
		        connectedCallback() {
		            const length = this.getAttribute('length') || 80;
		            this.render(length);
		        }
		        render(length) {
		            let html = '<div class="grid-container">';
		            for (let i = 0; i < length; i++) {
		                html += '<div class="char-box"></div>';
		            }
		            html += '</div>';
		            this.innerHTML = html;
		        }
		    }
		    customElements.define('passphrase-grid', PassphraseGrid);
		</script>
	EOF
    # lint-skip-end
}

_generateHtml() {
    local keyFile="$1"
    local keyInfoFile="$2"
    local templateFile="$3"
    local outputFile="$4"
    local html contact note value
    readFile "${templateFile}" html || fail

    # Get the key in armored form and checksum to include as a backup in case of QR code issues

    local armoredKey; armoredKey="${ armorKeyFile ${keyFile}; }"
    _CHECKSUM="${ sha256sum ${keyFile} | head -c 16; }"

    # Set built-in substitution values (clobbering any that the user might have defined)

    local _GREETING="${greeting}"
    local _DATE; _DATE="${ date "+%B %d, %Y %r %Z"; }"
    local _CSS_PATH="${_cssMainFileName}"
    local _LOGO_PATH="${_logoFileName}"
    local _QR_CODE_PATH="${_qrCodeFileName}"
    local _ARMORED_KEY="${armoredKey}"
    local _CSS_OVERRIDE='<!-- placeholder -->'
    if [[ -n ${cssOverrideFile} ]]; then
        _CSS_OVERRIDE="<link rel="stylesheet" href="${_cssOverrideFileName}">"
    fi

    # Transform contacts into list items

    local _CONTACTS_LIST=
    for contact in "${contacts[@]}"; do
        _CONTACTS_LIST+="<li>${contact}</li>"
    done

    # Grid for handwriting passphrase

    local _PASSPHRASE_SECTION; _PASSPHRASE_SECTION="${ _passphraseGridHtml; }"

    # Transform notes into paragraphs

    local _NOTES=
    for note in "${notes[@]}"; do
        _NOTES+="<p>${note}</p>"
    done

    # Collect all required substitution keys (consumes tempHtml)

    local tempHtml="${html}"
    local requiredSubstitutionKeys=()

    while [[ ${tempHtml} =~ \$\{([A-Za-z_][A-Za-z0-9_]*)\}(.*) ]]; do
        requiredSubstitutionKeys+=("${BASH_REMATCH[1]}")
        tempHtml="${BASH_REMATCH[2]}"
    done

    # Perform the substitutions, failing if a required substitution is not defined

    for key in "${requiredSubstitutionKeys[@]}"; do
        value="${!key}"
        [[ -v key ]] || fail "${key} not set in ${keyInfoFile}"
        [[ -n "${value}" ]] || fail "${key} value not set in ${keyInfoFile}"
        html=${html/\$\{${key}\}/${value}}
    done
    echo "${html}" > "${outputFile}"
}

