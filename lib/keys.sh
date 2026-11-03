#!/usr/bin/env bash

# Encryption and signing key generation and usage.
# Use via: require 'valt/keys'

# ────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
#
# ◇ DESIGN NOTES
#
# Valt uses age file encryption system and minisign digital signatures (see https://github.com/filosottile/age and
# https://github.com/jedisct1/minisign).
#
# Quantum resistant encryption keys are used exclusively as defense against the real possibility of quantum computers that can
# break keys based on 256-bit elliptic curves, the current best practice. A consequence of this choice is significantly larger
# public keys, from 63 bytes to 1960 bytes.
#
# A valt key is passphrase encrypted and contains both minisign keys and age public key as comments, along with the age private
# key. A valt public key is plaintext and is an Age public key with minisign public key as comment(s).
#
#   valt.key: secure private key used by valt for signing and decryption
#   valt.pub: public key used by valt for signature verification and encryption
#
# All keys can be extracted from valt.key, and signature verification and encryption functions will accept the private key.
#
# ◇ Example valt.pub
#
#   # created: 2026-04-08T15:20:15-07:00
#   #
#   # [minisign.pub] untrusted comment: minisign public key EE5CD48146AE435D
#   # [minisign.pub] RWRdQ65GgdRc7jF1xg1QozGtd1gWfi7I4RJ58i8ElDvV4qCuzE+zENKo
#   #
#   age1pq1m43p0m52f544e868gyh09rx0wrr6jg8thvcr5cekpdkhzapwa7jjdgh54zlnjp0wny04tcae7h3k5x0s25l3znxpvvq  [ ... ]
#
# ◇ Example valt.key prior to encryption (not stored)
#
#   # created: 2026-03-10T16:57:47-07:00
#   #
#   # [minisign.pub] untrusted comment: minisign public key 86DA637D4FBBE4E5
#   # [minisign.pub] RWTl5LtPfWPahiYfMcUk9+c/cFAfruNplL79ijRei9i1HzJlDa741qHp
#   #
#   # [minisign.key] untrusted comment: minisign encrypted secret key
#   # [minisign.key] RWQAAEIyAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA5eS7T31j2oY  [ ... ]
#   # public key: age1pq1m43p0m52f544e868gyh09rx0wrr6jg8thvcr5cekpdkhzapwa7jjdgh54zlnjp0wny04tcae7h3k5x0s25l3znxpvvq  [ ... ]
#   AGE-SECRET-KEY-1KVCTA4K9RSW85YHCSE62L9XJ2ULTPG9ZVRF7K6KGGALCGYUDFHGQY2SYX7#
#
# ◇ Example valt.key
#
#   # age-encryption.org/v1
#   # -> scrypt WzB5/xdYAB/DggwzorWYPg 18
#   # tdtd2Ew1tyQU2b34sGgI6o2YajyADGt/0D+eW2GN3bk
#   # --- VX6tiDvvH5VCkb44Ifnca1R9eUQuk9RauYKrZ9U2Cto
#   # [... 1565 bytes binary data ...]
#
# ◇ Passphrase Encryption
#
# Users are shown password/phrase advice on key gen to encourage strong, memorable passphrase use, then asked if they already
# have one. If not, a set of generated ones is shown to choose from. This behavior is suppressed after second key gen.
#
# ◇ Valt Key Usage
#
#   - Encrypt/sign requires valt.key for PRIVATE signing key and PUBLIC Age key
#   - Decryption requires valt.key for PRIVATE Age key
#   - Verify requires valt.pub, for PUBLIC signing key
#   - Full verify requires valt.key for PUBLIC signing key(s) and PRIVATE Age key
#   - Extract requires valt.key.
#
# ◇ Key Storage
#
#   valt.key: local, password manager (bitwarden, etc.)
#   valt.pub: local, password manager (bitwarden, etc.), user's github, google drive, iCloud, etc.
#
# ────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────


# ◇ Create new valt keys, encrypting the private key with a passphrase. May show passphrase advice and offer to generate
#   passphrases. Produces keys that combine age and minisign keys:
#
#   valt.pub: age public key + minisign public key
#   valt.key: age public key + minisign public key + age secret key + minisign secret key
#
# · USAGE
#
#   newValtKeys [keyName] [keyDir] [valtPubFileResultVar] [valtKeyFileResultVar]
#
#   A '-' may be passed for any arg to enable passing a subsequent value.
#
#   keyName (string)                  Optional name to use instead of 'valt', e.g. 'test' -> test.key & test.pub.
#   keyDir (string)                   Optional directory path where key files will be written (default: ~/.config/valt).
#   valtPubFileResultVar (stringRef)  Optional var name to assign the valt.pub file.
#   valtKeyFileResultVar (stringRef)  Optional var name to assign the valt.key file.
#
# · EXAMPLE
#
#   newValtKeys                      # creates valt.pub and valt.key files in the ~/.config/valt/ directory.
#   newValtKeys - - pubFile keyFile  # same as above but assigns key paths to pubFile keyFile vars.
#   newValtKeys frodo                # creates frodo.pub and frodo.key in the ~/.config/valt/ directory.
#
# · ENV VARS
#
#   allowWeakKeyPassphrase   When set and non-zero, accepts a passphrase that fails the strength and breach check (default:
#                            the passphrase is rejected, since it is all that protects the private key).
#   skipKeyPassphraseAdvice  When set and non-zero, skips the passphrase advice.

newValtKeys() {
    local keyName="${1:--}"
    local keyDir="${2:--}"
    [[ ${keyName} == '-' ]] && keyName='valt'
    local _valtPubFileResultVar="${3:-?}"
    local _valtKeyFileResultVar="${4:-?}"

    if [[ ${keyDir} == '-' ]]; then
        # Force use of valt config dir
        keyDir="${ configDirPath -p 'valt'; }"
    else
        assertDirectory "${keyDir}"
    fi
    local _keyFile="${keyDir}/${keyName}.${valtPrivateKeySuffix}"
    local _publicKeyFile="${keyDir}/${keyName}.${valtPublicKeySuffix}"
    local _publicSigningKeyFile="${keyDir}/${keyName}.${valtPublicKeySuffix}"
    local ageCreated
    local agePublicKey
    local agePrivateKey=()
    local valtPubKey=()
    local index line
    _assertKeyFileDoesNotExist "${_keyFile}"
    _assertKeyFileDoesNotExist "${_publicKeyFile}"
    _assertKeyFileDoesNotExist "${_publicSigningKeyFile}"

    # Maybe offer passphrase advice and/or generate passphrase if desired

    _maybeOfferPassphraseAdvice

    # Generate the post-quantum age private key (includes public key)

    mapfile -t agePrivateKey < <( age-keygen -pq 2> /dev/null ) || fail

    # Extract the created line and public key (hopefully future proof)

    indexOf -p "${_ageCreatedPrefix}" agePrivateKey index
    ageCreated="${agePrivateKey[index]}"
    agePrivateKey=("${agePrivateKey[@]:0:index}" "${agePrivateKey[@]:index+1}")
    indexOf -p "${_agePublicKeyPrefix}" agePrivateKey index
    line="${agePrivateKey[index]}"
    agePublicKey="${line:${#_agePublicKeyPrefix}}"

    # Generate unencrypted signing keys and load into our signingPrivateKey array

    local signingPublicKey=()
    local signingPrivateKey=()
    local _signingPublicKeyFile; _signingPublicKeyFile="${ tempDirPath -r; }"
    local _signingPrivateKeyFile; _signingPrivateKeyFile="${ tempDirPath -r; }"
    minisign -G -p "${_signingPublicKeyFile}" -s "${_signingPrivateKeyFile}" -W > /dev/null || fail
    mapfile -t signingPublicKey < <(cat "${_signingPublicKeyFile}")  || fail
    mapfile -t signingPrivateKey < <(cat "${_signingPrivateKeyFile}") || fail
    rm "${_signingPublicKeyFile}" "${_signingPrivateKeyFile}" &> /dev/null

    # Construct the common key comments

    local commonKey
    commonKey=("${ageCreated}")
    commonKey+=('#')
    for line in "${signingPublicKey[@]}"; do
        commonKey+=("${_signingPublicKeyPrefix}${line}")
    done
    commonKey+=("#")

    # Construct valt.pub

    valtPubKey=("${commonKey[@]}")
    valtPubKey+=("${agePublicKey}")

    # Construct the combined 'valt.key' plaintext lines

    local plainPrivate
    plainPrivate=("${commonKey[@]}")
    for line in "${signingPrivateKey[@]}"; do
        plainPrivate+=("${_signingPrivateKeyPrefix}${line}")
    done
    plainPrivate+=('#')
    plainPrivate+=("${agePrivateKey[@]}")

    # Encrypt the private key directly to the key file

    # The passphrase must be strong unless allowWeakKeyPassphrase is set

    local -a strengthArgs=(--check-strength)
    (( allowWeakKeyPassphrase )) && strengthArgs=()
    printf "%s\n" "${plainPrivate[@]}" | _age --encrypt --passphrase --confirm "${strengthArgs[@]}" > "${_keyFile}" || { rm -f "${_keyFile}"; fail; }
    chmod 600 "${_keyFile}" 2> /dev/null

    # Write public key

    printf '%s\n' "${valtPubKey[@]}" > "${_publicKeyFile}"

    # Assign results if var specified

    _assignResultIfVarName ${_valtPubFileResultVar} "${_publicKeyFile}"
    _assignResultIfVarName ${_valtKeyFileResultVar} "${_keyFile}"
}

# ◇ Verifies a valt key pair by encrypting sample text with the public key, then decrypting
#   with the private key and comparing results. Fails if they do not match. Also signs encrypted
#   file and verifies the signature.
#
# · USAGE
#
#   verifyValtKeys valtPubFile valtKeyFile
#
#   valtPubFile (string)  Path to the valt.pub file.
#   valtKeyFile (string)  Path to the valt.key file.

verifyValtKeys() {
    require 'valt/sign'
    local valtPubFile="$1"
    local valtKeyFile="$2"

    assertFile "${valtPubFile}"
    assertFile "${valtKeyFile}"

    # Extract public encryption key from valt.key and ensure it matches valt.pub and ensure both start with 'age'

    local publicEncrypt; publicEncrypt="${ gawk '!/^#/ && NF { print; exit }' "${valtPubFile}"; }"
    local rayvnTest_ValtKeyPassphrase="${rayvnTest_ValtKeyPassphrase}"
    _prepareKey "${valtKeyFile}"
    local extractedPublicEncrypt; extractedPublicEncrypt="${ recipient "${valtKeyFile}"; }"

    [[ "${publicEncrypt:0:3}" == 'age' ]] || fail "${valtPubFile} public encryption key does not begin with 'age'"
    [[ "${extractedPublicEncrypt:0:3}" == 'age' ]] || fail "${valtKeyFile} public encryption key doest not begin with 'age'"
    [[ "${extractedPublicEncrypt}" == "${publicEncrypt}" ]] || fail "extracted public encryption key does not match"

    # Extract public signing key from valt.key and ensure it matches valt.pub

    local publicSign; mapfile -t publicSign < <( grep -m 2 '^# \[minisign\.pub\] ' "${valtPubFile}" )
    local extractedPublicSignFile; publicSigningKeyToTempFile "${valtKeyFile}" extractedPublicSignFile
    local extractedPublicSign; mapfile -t extractedPublicSign < <( cat "${extractedPublicSignFile}" )
    (( ${#publicSign[@]} == 2 )) || fail "public signing key must be 2 lines"
    (( ${#extractedPublicSign[@]} == 2 )) || fail "extracted public signing key must be 2 lines"
    local i line
    for (( i=0; i < 2; i++ )); do
        line="${publicSign[i]:17}"
        [[ "${line}" == "${extractedPublicSign[i]}" ]] || fail "extracted public signing key does not match"
    done

    # Encrypt, decrypt and verify

    local sampleText; _setSampleText sampleText
    local sampleTextFile; sampleTextFile="${ makeTempFile sample.txt; }"
    local encryptedFile; encryptedFile="${ makeTempFile sample.encrypted; }"
    local plainTextFile; plainTextFile="${ makeTempFile sample.plain; }"
    echo "${sampleText}" > "${sampleTextFile}"

    encrypt -R "${valtPubFile}" "${sampleTextFile}" -o "${encryptedFile}"
    decrypt -i "${valtKeyFile}" "${encryptedFile}" -o "${plainTextFile}"
    diff -u "${sampleTextFile}" "${plainTextFile}" > /dev/null || fail "round-trip encryption failed"

    # Sign and verify signature

    signFile "${valtKeyFile}" "${encryptedFile}"
    verifyFileSignature "${valtKeyFile}" "${encryptedFile}"
}

# ◇ Outputs the key type suffix for a valt key file, either "pub" or "key".
#
# · USAGE
#
#   keyType keyFile
#
#   keyFile (string)  Path to a valt .pub or .key file.

keyType() {
    local keyFile="$1" _decl mayBeKey=0
    assertFile "$1"
    while read line; do
        if (( ${#line} )); then # Ignore blank lines
            if [[ ${line} == "${_ageEncryptedBegin}" || ${line} == "${_agePemBegin}" ]]; then
                mayBeKey=1 # This could be any encrypted file, so at least check the next line
            elif (( mayBeKey )); then
                if [[ ${line} =~ ${_ageScriptRegex} ]]; then
                    echo "${valtPrivateKeySuffix}"
                    break
                else
                    fail "not a valt key file: ${keyFile}"
                fi
            elif [[ ${line} == "${_ageCreatedPrefix}"* ]]; then
                echo "${valtPublicKeySuffix}"
                break;
            else
                fail "not a valt key file: ${keyFile}"
            fi
        fi
    done < <( cat ${keyFile} )
}

# ◇ Extracts the public encryption key from a valt key file and writes it to standard output.
#   Will accept a private key that will require passphrase input to decrypt.
#
# · USAGE
#
#   recipient keyFile
#
#   keyFile (string)  Path to the key file.

recipient() {
    local keyFile="$1"
    _extractKey "${keyFile}" true "${_agePublicKeyPrefix}" 1
}

# ◇ Writes the public key file (.pub) for a valt private key, recreating it from the private key, which contains
#   everything in it: the created line, the public signing key and the public encryption key. The result is identical
#   to the .pub file made with the key. Requires the private key's passphrase.
#
# · USAGE
#
#   writeValtPublicKey keyFile pubFile
#
#   keyFile (file)    Path to the valt private key file.
#   pubFile (string)  Path to the public key file to write; it is replaced if it exists.

writeValtPublicKey() {
    local keyFile="$1" pubFile="$2"
    _assertValtKey "${keyFile}"
    local plainRaw; plainRaw="${ _age --decrypt --passphrase-for "${keyFile}" < "${keyFile}"; }" || fail
    local -a plain=()
    mapfile -t plain <<< "${plainRaw}"
    eraseVars plainRaw

    # The common lines come first, up to the private signing key; the public encryption key is in the age key's comment

    local -a pubLines=()
    local line agePublicKey='' inCommon=1
    for line in "${plain[@]}"; do
        [[ ${line} == "${_signingPrivateKeyPrefix}"* ]] && inCommon=0
        (( inCommon )) && pubLines+=("${line}")
        [[ ${line} == "${_agePublicKeyPrefix}"* ]] && agePublicKey="${line:${#_agePublicKeyPrefix}}"
    done
    eraseVars plain
    [[ -n ${agePublicKey} ]] && (( ${#pubLines[@]} > 1 )) \
        || fail "${ tildePath "${keyFile}"; } does not contain a valt public key"
    pubLines+=("${agePublicKey}")

    local temp="${pubFile}.new"
    printf '%s\n' "${pubLines[@]}" > "${temp}" && mv "${temp}" "${pubFile}" || fail "could not write ${pubFile}"
}

# ◇ Convert one or more valt key files into a recipients file. Will accept private keys; each will require passphrase input to
#   decrypt.
#
# · USAGE
#
#   newRecipientsFile recipientsFile keyFile...
#
#   recipientsFile (string)      Path to the recipients file to create.
#   keyFile        (string)...   One or more valt .pub or .key file paths.

newRecipientsFile() {
    local recipientsFile="$1"; shift
    local recipient
    (( $# )) || invalidArgs "one or more valt key files required"

    printf "%s\n\n" "# recipients" > "${recipientsFile}"
    while (( $# )); do
        [[ -n "${recipient}" ]] && echo >> "${recipientsFile}"
        recipient="${ _extractKey "$1" true "${_agePublicKeyPrefix}" 1; }"
        echo "${recipient}" >> "${recipientsFile}"
        shift
    done
}

# ◇ Extracts the public signing key from a valt private key file into a temp file.
#
# · USAGE
#
#   publicSigningKeyToTempFile valtKeyFile resultFileRef
#
#   valtKeyFile (string)       Path to the valt private key file.
#   resultFileRef (stringRef)  Name of the variable to receive the path to the temp public signing key file.

publicSigningKeyToTempFile() {
    local valtKeyFile="$1"
    local -n resultFileRef="$2"
    local _tempFile; _tempFile="${ makeTempFile; }"
    _extractKey "${valtKeyFile}" true "${_signingPublicKeyPrefix}" 2 "${_tempFile}"
    resultFileRef="${_tempFile}"
}

# ◇ Extracts the signing key from a valt private key file into a temp file.
#
# · USAGE
#
#   signingKeyToTempFile valtKeyFile resultFileRef
#
#   valtKeyFile   (string)     Path to the valt private key file.
#   resultFileRef (stringRef)  Name of the variable to receive the path to the temp private signing key file.

signingKeyToTempFile() {
    local valtKeyFile="$1"
    local -n resultFileRef="$2"
    local tempFile; tempFile="${ makeTempFile; }"
    _extractKey "${valtKeyFile}" false "${_signingPrivateKeyPrefix}" 2 "${tempFile}"
    resultFileRef="${tempFile}"
}

# ◇ Outputs an ASCII-armored PEM-style encoding of a key file to stdout, in age's armor format: base64 in lines of
#   exactly 64 characters (but the last), which age requires.
#
# · USAGE
#
#   armorKeyFile keyFile
#
#   keyFile (string)  Path to the key file to armor.

armorKeyFile() {
    local keyFile=$1
    printf '%s\n' "${_agePemBegin}"
    base64 < "${keyFile}" | tr -d '\n' | fold -w 64 || fail # GNU base64 wraps at 76 columns, macOS's does not
    printf '\n%s\n' "${_agePemEnd}"
}

# ◇ Fail if the recipients mix post-quantum (age1pq1...) and classic age keys, which age refuses to encrypt to (the
#   file would be open to quantum computers). Recipient files are read for their recipients; others are ignored.
#
# · USAGE
#
#   assertCompatibleRecipients (-r RECIPIENT | -R PATH)...
#
#   -r RECIPIENT  A recipient (age public key).
#   -R PATH       A file of recipients, e.g. a valt .pub file.

assertCompatibleRecipients() {
    local -a recipients=() postQuantum=() classic=()
    local recipient
    while (( $# )); do
        case "$1" in
            -r | --recipient) recipients+=("$2"); shift ;;
            -R | --recipient-file) [[ -f "$2" ]] && mapfile -t -O ${#recipients[@]} recipients < <(grep -E '^(age1|ssh-)' "$2"); shift ;;
        esac
        shift
    done
    for recipient in "${recipients[@]}"; do
        if [[ ${recipient} == age1pq1* ]]; then
            postQuantum+=("${recipient}")
        else
            classic+=("${recipient:0:20}...")
        fi
    done
    (( ${#postQuantum[@]} && ${#classic[@]} )) || return 0
    fail "Cannot encrypt to both post-quantum keys (such as valt keys) and classic age keys, since the result would" \
         "be open to quantum computers. Classic keys: ${classic[*]}. Use only post-quantum keys, or --no-self" \
         "to leave out your own valt key."
}

# ◇ Output the path of the default valt private key file, used when no key is specified: VALT_KEY_FILE if set, else the
#   defaultKeyFile setting in valt.conf in the valt config directory (see setDefaultValtKeyFile), else valt.key in the
#   valt config directory.

defaultValtKeyFile() {
    local keyFile source
    _resolveDefaultValtKeyFile keyFile source
    echo "${keyFile}"
}

# ◇ Output where the default valt private key file comes from: 'VALT_KEY_FILE', the path of the valt.conf file that
#   sets it, or 'built-in'.

defaultValtKeyFileSource() {
    local keyFile source
    _resolveDefaultValtKeyFile keyFile source
    echo "${source}"
}

# ◇ Set the default valt private key file in valt.conf in the valt config directory, or remove the setting.
#
# · ARGS
#
#   [keyFile] (file)  The valt private key file to use by default; omit to remove the setting.

setDefaultValtKeyFile() {
    local configFile; configFile="${ configDirPath -p valt "${_valtConfigFileName}"; }"
    local keyFile=''
    if [[ -n ${1:-} ]]; then
        _assertValtKey "$1"
        setFileVar keyFile "$1" "key file"
        [[ ${keyFile} == *"'"* || ${keyFile} == *$'\n'* ]] && fail "key file path must not contain a quote or newline: ${keyFile}"
    fi

    local -a lines=()
    [[ -f "${configFile}" ]] && mapfile -t lines < <(grep -v '^defaultKeyFile=' "${configFile}")
    [[ -n ${keyFile} ]] && lines+=("defaultKeyFile='${keyFile}'")
    if (( ${#lines[@]} )); then
        printf '%s\n' "${lines[@]}" > "${configFile}" || fail "could not write ${configFile}"
    else
        rm -f "${configFile}"
    fi
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'valt/keys' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_valt_keys() {
    require 'valt/encrypt' 'valt/decrypt'  'valt/sign' 'rayvn/config'
    declare -gr _valtConfigFileName='valt.conf'

    declare -grx valtProjectUrl='https://github.com/phoggy/valt'

    declare -grx valtPublicKeySuffix='pub'
    declare -grx valtPrivateKeySuffix='key'

    declare -grx _valtPublicKeyType='valt.pub'
    declare -grx _valtPrivateKeyType='valt.key'
    declare -grx _ageFileExtension='age'
    declare -grx _tarFileExtension='tar.xz'
    declare -grx _ageCreatedPrefix='# created: '
    declare -grx _agePublicKeyPrefix='# public key: '
    declare -grx _signingPublicKeyPrefix='# [minisign.pub] '
    declare -grx _signingPrivateKeyPrefix='# [minisign.key] '
    declare -grx _valtSigningPublicKeyPrefix='untrusted comment: minisign public key'
    declare -grx _ageEncryptedBegin='age-encryption.org/v1'
    declare -grx _ageScriptRegex='^-\>[[:space:]]+scrypt[[:space:]]+[A-Za-z0-9+/]+=*[[:space:]]+[0-9]+$'
    declare -grx _agePemBegin='-----BEGIN AGE ENCRYPTED FILE-----'
    declare -grx _agePemEnd='-----END AGE ENCRYPTED FILE-----'

    local counterFile; counterFile="${ configDirPath -p 'valt' 'advice.count'; }"
    declare -grx _adviceCounterFile="${counterFile}"
    declare -g _adviceCount=0
}

_assertKeyFileDoesNotExist() {
    [[ $1 != '-' && -f $1 ]] && invalidArgs "$1 already exists"
}

_assignResultIfVarName() {
    local _resultVarRefName=$1
    if [[ -n ${_resultVarRefName} && ${_resultVarRefName} != ? ]]; then
        local -n _resultVarRefRef=${_resultVarRefName}
        _resultVarRefRef="$2"
    fi
}

_extractKey() {
    assertFile "$1"
    local keyFile="$1"
    local allowPublic=$2
    local keyPrefix="$3"
    local keyLineCount=$4
    local resultFile="${5:-}" # echo if none else write to file.
    local firstLine=1 lines=()
    local plain=()
    while read line; do
        if (( "${#line}" )); then # Ignore blank lines
            if (( firstLine )); then
                if [[ ${line} == "${_ageEncryptedBegin}" || ${line} == "${_agePemBegin}" ]]; then

                    # valt.key so decrypt and switch to reading that

                    local plainRaw; plainRaw=${ cat "${keyFile}" | _age --decrypt --passphrase-for "${keyFile}"; } || fail
                    mapfile -t plain <<< "${plainRaw}"
                    eraseVars plainRaw

                    for line in "${plain[@]}"; do
                        if [[ ${line} == "${keyPrefix}"* ]]; then
                            lines+=( "${line:${#keyPrefix}}" )
                            (( --keyLineCount )) || break
                        fi
                    done
                    eraseVars plain
                    break;

                elif [[ ${allowPublic} == true ]]; then

                    # valt.pub is allowed, so continue processing lines.
                    # If we're looking for the age public key we need to
                    # switch the key prefix

                    [[ ${keyPrefix} == "${_agePublicKeyPrefix}" ]] && keyPrefix='age1'

                    if [[ ${line} == "${keyPrefix}"* ]]; then
                        if [[ "${keyPrefix}" == '#'* ]]; then
                            lines+=( "${line:${#keyPrefix}}" )
                        else
                            lines+=( "${line}" )
                        fi
                        (( --keyLineCount )) || break
                    fi
                    firstLine=0
                else
                    fail "requires key type '${valtPrivateKeySuffix}'"
                fi
            else
                if [[ ${line} == "${keyPrefix}"* ]]; then
                    if [[ "${keyPrefix}" == '#'* ]]; then
                        lines+=( "${line:${#keyPrefix}}" )
                    else
                        lines+=( "${line}" )
                    fi
                    (( --keyLineCount )) || break
                fi
            fi
        fi
    done < <( cat "${keyFile}" )

    # Write the lines to the result file or to stdout

    if [[ -n "${resultFile}" ]]; then
        printf '%s\n' "${lines[@]}" > "${resultFile}" || fail
    else
        printf '%s\n' "${lines[@]}"
    fi
}

_prepareKey() {
    local _key="$1"
    if [[ -z ${rayvnTest_ValtKeyPassphrase} ]]; then
        local _path; _path="${ tildePath "${_key}"; }"
        local _prompt; _prompt="${ show "Enter passphrase for" blue "${_path}"; }"
        readPassword "${_prompt}" rayvnTest_ValtKeyPassphrase || fail
        cursorUpOneAndEraseLine
    fi
}

# Set the named vars to the default key file and where it comes from (see defaultValtKeyFile).

_resolveDefaultValtKeyFile() {
    local -n _rdkFileRef=$1
    local -n _rdkSourceRef=$2
    if [[ -n ${VALT_KEY_FILE:-} ]]; then
        _rdkFileRef="${VALT_KEY_FILE}"
        _rdkSourceRef='VALT_KEY_FILE'
        return 0
    fi
    local configDir; configDir="${ configDirPath -p valt; }"
    local configFile="${configDir}/${_valtConfigFileName}"
    if [[ -f "${configFile}" ]]; then
        local configured; configured="${ ( sourceConfigFile "${configFile}"; echo "${defaultKeyFile:-}" ) 2> /dev/null; }"
        if [[ -n ${configured} ]]; then
            _rdkFileRef="${configured}"
            _rdkSourceRef="${configFile}"
            return 0
        fi
    fi
    _rdkFileRef="${configDir}/valt.${valtPrivateKeySuffix}"
    _rdkSourceRef='built-in'
}

_assertValtKey() {
    local key="$1"
    local type; type="${ keyType "${key}"; }"
    [[ ${type} == key ]] || invalidArgs "${key} is not a valt key"
}

_addRecipientFromKey() {
    assertFile "$1"
    local keyFile="$1"
    local -n _argsArrayRef="$2"
    local -n _hasRecipientRef="$3"
    local recipient; recipient="${ recipient "${keyFile}"; }"
    _hasRecipientValue "${recipient}" "${_argsArrayRef[@]}" || _argsArrayRef+=( '-r' "${recipient}" )
    _hasRecipientRef=1
}

_addRecipient() {
    [[ ${1:0:3} == 'age' ]] || fail "not a recipient: $1"
    local recipient; recipient="$1"
    local -n _argsArrayRef="$2"
    local -n _hasRecipientRef="$3"
    _hasRecipientValue "${recipient}" "${_argsArrayRef[@]}" || _argsArrayRef+=( '-r' "${recipient}" )
    _hasRecipientRef=1
}

# Succeeds if recipient is already in the args (as '-r RECIPIENT'), so that it is not added twice: age warns about
# a duplicate recipient, which fails the command. Args: recipient args...

_hasRecipientValue() {
    local recipient="$1"; shift
    while (( $# )); do
        [[ $1 == '-r' && $2 == "${recipient}" ]] && return 0
        shift
    done
    return 1
}


_maybeOfferPassphraseAdvice() {
    if (( ! skipKeyPassphraseAdvice )); then
        _readAdviceCount
        if (( _adviceCount <= 1 )); then
            local choiceIndex phrase i
            _showPrivateKeyPassphraseAdvice
            confirm "Do you already have a strong, memorable passphrase?" no yes choiceIndex || bye
            if (( choiceIndex == 0 )); then
                show nl "Ok, here are some randomly generated ones to choose from:" nl
                for (( i = 0; i < 10; i++ )); do
                    generatePassphrase phrase
                    show "  " bold cyan "${phrase}"
                done
                echo
                confirm "Does one of these work for you?" yep nope choiceIndex || bye
                if (( choiceIndex == 1 )); then
                    show "Ok. If you want to do this later, run:" primary "valt passphrase"
                    _setAdviceCount 1
                    bye
                fi
                show nl "Good." primary italic "Keep this passphrase someplace secure   !" nl
                echo "Ok, now you'll need to enter it for your new keys."
                _setAdviceCount 2
            fi
        fi
    fi
}

_showPrivateKeyPassphraseAdvice() {
    echo "Normally you will need only a single key pair for all your file encryption needs. Your new private key will itself"
    show "be encrypted, so it can be stored anywhere: the passphrase you enter here will be" italic "required" "to use it. You'll be"
    echo "asked for it twice."
    echo
    show "Use a passphrase of several" italic "random" "words rather than a password: it is far easier to remember, and much harder"
    echo "to crack. Since human memory is fallible, keep it on paper too: the paper key valt makes for your key has room for"
    show "it. If the passphrase is lost, so is" bold "everything" "encrypted with this key."
    echo
    show "For more about keys, passphrases and the paper key, run" bold blue "valt key-info" glue ", which also lets you fill in the paper"
    echo "key's personal information."
    echo
}

_readAdviceCount() {
    if [[ -e ${_adviceCounterFile} ]]; then
        _adviceCount="${ cat "${_adviceCounterFile}"; }"
    fi
}

_setAdviceCount() {
    _adviceCount=$1
    _writeAdviceCount
}

_writeAdviceCount() {
    echo "${_adviceCount}" > "${_adviceCounterFile}"
}

_setSampleText() {
    local -n resultVarRef="$1"
    if [[ -z ${resultVarRef} ]]; then
        IFS='' read -d '' -r resultVarRef <<- EOF

	        But the Raven, sitting lonely on the placid bust, spoke only
	    That one word, as if his soul in that one word he did outpour.
	        Nothing farther then he uttered—not a feather then he fluttered—
	        Till I scarcely more than muttered “Other friends have flown before—
	    On the morrow he will leave me, as my Hopes have flown before.”
	                     Then the bird said “Nevermore.”

	EOF
    fi
}

