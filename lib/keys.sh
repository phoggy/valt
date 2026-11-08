#!/usr/bin/env bash

# Encryption and signing key generation and usage.
# Use via: require 'valt/keys'

#@notes
# ## Design Notes
#
# valt uses the [age](https://github.com/FiloSottile/age) file encryption system and
# [minisign](https://github.com/jedisct1/minisign) digital signatures.
#
# ### Post-Quantum Encryption
#
# valt keys are always post-quantum age keys (made with `age-keygen -pq`, their public keys starting with `age1pq1`):
# a hybrid of ML-KEM-768 and X25519, so that files are protected against future quantum computers, which could break
# keys based on elliptic curves alone, the current best practice. This matters for encryption today, since encrypted
# files can be recorded now and attacked later. The cost is much larger public keys: about 2,000 characters, where
# classic ones have 62. age will not encrypt to both post-quantum and classic keys at once, since the result would be
# only as strong as the classic key, so neither does valt.
#
# Signatures use minisign's Ed25519 keys, which are not post-quantum: a signature only needs to resist forgery when it
# is checked.
#
# ### Key Files
#
# A valt private key (`valt.key`) is encrypted with a passphrase, and holds the age private key, with both minisign
# keys and the age public key as comments. A valt public key (`valt.pub`) is plain text: the age public key, with the
# minisign public key as comments. Since the private key holds every key, signature verification and encryption also
# accept it.
#
# An example `valt.pub`:
#
#     # created: 2026-04-08T15:20:15-07:00
#     #
#     # [minisign.pub] untrusted comment: minisign public key EE5CD48146AE435D
#     # [minisign.pub] RWRdQ65GgdRc7jF1xg1QozGtd1gWfi7I4RJ58i8ElDvV4qCuzE+zENKo
#     #
#     age1pq1m43p0m52f544e868gyh09rx0wrr6jg8thvcr5cekpdkhzapwa7jjdgh54zlnjp0wny04tcae7h3k5x0s25l3znxpvvq  [ ... ]
#
# A `valt.key` before it is encrypted (never stored like this):
#
#     # created: 2026-03-10T16:57:47-07:00
#     #
#     # [minisign.pub] untrusted comment: minisign public key 86DA637D4FBBE4E5
#     # [minisign.pub] RWTl5LtPfWPahiYfMcUk9+c/cFAfruNplL79ijRei9i1HzJlDa741qHp
#     #
#     # [minisign.key] untrusted comment: minisign encrypted secret key
#     # [minisign.key] RWQAAEIyAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA5eS7T31j2oY  [ ... ]
#     # public key: age1pq1m43p0m52f544e868gyh09rx0wrr6jg8thvcr5cekpdkhzapwa7jjdgh54zlnjp0wny04tcae7h3k5x0s25l3znxpvvq  [ ... ]
#     AGE-SECRET-KEY-PQ-1KVCTA4K9RSW85YHCSE62L9XJ2ULTPG9ZVRF7K6KGGALCGYUDFHGQY2SYX7
#
# And as stored, encrypted with the passphrase:
#
#     age-encryption.org/v1
#     -> scrypt WzB5/xdYAB/DggwzorWYPg 18
#     tdtd2Ew1tyQU2b34sGgI6o2YajyADGt/0D+eW2GN3bk
#     --- VX6tiDvvH5VCkb44Ifnca1R9eUQuk9RauYKrZ9U2Cto
#     [... 1565 bytes binary data ...]
#
# ### Which Key Each Operation Needs
#
# - Encrypting and signing: `valt.key`, for the private signing key and the public age key.
# - Decrypting: `valt.key`, for the private age key.
# - Verifying a signature: `valt.pub`, for the public signing key.
# - Full verification (decrypting too): `valt.key`, for the public signing keys and the private age key.
# - Extracting an archive: `valt.key`.
#
# ### Storing Keys
#
# Keep backup copies of `valt.key`: being encrypted, it is safe in a password manager, on a USB drive or in cloud
# storage, and the paper key is a printed copy. `valt.pub` can be shared anywhere, e.g. on GitHub.
#
# ### Passphrases
#
# When making a key, valt shows advice on strong, memorable passphrases, then asks whether the user already has one;
# if not, it offers generated ones to choose from. After the second key, the advice is no longer shown.
#@end

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

    # Get a good passphrase first, offering advice and generated ones (see _readNewKeyPassphrase)

    local _newKeyPassphrase=''
    _readNewKeyPassphrase _newKeyPassphrase

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

    printf "%s\n" "${plainPrivate[@]}" | _age --encrypt --passphrase-var _newKeyPassphrase > "${_keyFile}" \
        || { rm -f "${_keyFile}"; eraseVars _newKeyPassphrase; fail; }
    eraseVars _newKeyPassphrase
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

# ◇ Outputs the tag of the valt release current when this valt was built (e.g. v0.1.1), for recovery commands pinned to
#   it (nix run github:phoggy/valt/TAG#recover ...): this version, if it is a release, or for a development version
#   (e.g. 0.1.1+, as rayvn's release process marks the versions after a release) the release before it, since its own
#   commit may not be published. Outputs nothing if the version is neither.
#
# · ARGS
#
#   [pkgFile] (file)  The rayvn.pkg to read the version from (default: valt's own).

valtReleaseTag() {
    local pkgFile="${1:-${valtHome}/rayvn.pkg}"
    local version releaseDate
    version="${ gawk -F"'" '/^projectVersion=/ { print $2 }' "${pkgFile}"; }"
    releaseDate="${ gawk -F"'" '/^projectReleaseDate=/ { print $2 }' "${pkgFile}"; }"
    if [[ ${version} =~ ^[0-9]+(\.[0-9]+)*\+$ ]]; then
        echo "v${version%+}"
    elif [[ -n ${version} && ${version} != *+* && -n ${releaseDate} ]]; then
        echo "v${version}"
    fi
    return 0
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
    declare -grx valtGuideUrl='https://rayvn.ink/valt/guide/' # written by writeKeyInfoGuide, via valt's pages hook

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

# Asks for the passphrase of a key, unless already known (in rayvnTest_ValtKeyPassphrase, which callers make local), so
# that operations using the key more than once ask only once. The passphrase is tried on the key at once, and asked for
# again if it is wrong, up to 3 times, rather than failing later at the first typo.

_prepareKey() {
    local _key="$1"
    [[ -n ${rayvnTest_ValtKeyPassphrase} ]] && return 0
    local _path; _path="${ tildePath "${_key}"; }"
    local _prompt; _prompt="${ show "Enter passphrase for" blue "${_path}"; }"
    local -i _attempt
    local _error
    for (( _attempt = 1; _attempt <= 3; _attempt++ )); do
        readPassword "${_prompt}" rayvnTest_ValtKeyPassphrase || fail
        cursorUpOneAndEraseLine
        [[ -n ${rayvnTest_ValtKeyPassphrase} ]] || fail "cancelled"
        _error="${ ( _age --decrypt --passphrase-var rayvnTest_ValtKeyPassphrase < "${_key}" > /dev/null ) 2>&1; }" \
            && return 0
        [[ ${_error} == *"incorrect passphrase"* ]] || fail "could not unlock ${_path}: ${_error}"
        rayvnTest_ValtKeyPassphrase=''
        (( _attempt < 3 )) && show warning "Incorrect passphrase; try again."
    done
    fail "incorrect passphrase for ${_path}"
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


# Sets the named var to the passphrase for a new key, asking for it (twice) until it is strong and confirmed (unless
# allowWeakKeyPassphrase is set, when it need only be confirmed). Unless skipKeyPassphraseAdvice is set, the advice is
# shown the first times, then the question whether the user already has a strong passphrase: if not, or with no answer,
# generated ones are offered to choose from, as they are again whenever the one entered is rejected. With
# rayvnTest_ValtKeyPassphrase set, that is the passphrase rather than one entered (checked only if
# rayvnTest_CheckKeyPassphraseStrength is set): the advice is still shown, but the question is not, the answer taken
# as yes.

_readNewKeyPassphrase() {
    local -n _rnkpResultRef=$1
    local -i offerGenerated=0 adviceShown=0
    local choiceIndex
    if (( ! skipKeyPassphraseAdvice )); then
        _readAdviceCount
        if (( _adviceCount <= 1 )); then
            _showPrivateKeyPassphraseAdvice
            adviceShown=1
            if [[ -z ${rayvnTest_ValtKeyPassphrase} ]]; then # a test passphrase: take the answer as yes
                confirm "Do you already have a strong, memorable passphrase?" no yes choiceIndex
                case $? in
                    0) (( choiceIndex == 0 )) && offerGenerated=1 ;;
                    124) offerGenerated=1 ;; # timed out: take it as no, and offer some
                    *) bye ;;                # cancelled
                esac
            fi
        fi
    fi

    if [[ -n ${rayvnTest_ValtKeyPassphrase} ]]; then
        _rnkpResultRef="${rayvnTest_ValtKeyPassphrase}"
        (( rayvnTest_CheckKeyPassphraseStrength && ! allowWeakKeyPassphrase )) && _assertPassphraseStrength _rnkpResultRef
        return 0
    fi

    local strengthUseCase='file'
    (( allowWeakKeyPassphrase )) && strengthUseCase=''
    local prompt='Passphrase for the new key'
    local confirmPrompt; confirmPrompt="${ padString "Confirm" ${#prompt} before; }"
    local _rnkpFirst _rnkpSecond status
    while true; do
        if (( offerGenerated )); then
            _showGeneratedPassphrases
            offerGenerated=0
        fi
        readPassword "${prompt}" _rnkpFirst "${strengthUseCase}"; status=$?
        case ${status} in
            0) ;;
            1) show nl "That passphrase is not safe enough to protect a private key; choose another, e.g. one of these."
               offerGenerated=1
               continue ;;
            *) bye "Cancelled; no key was created." ;;
        esac
        [[ -n ${_rnkpFirst} ]] || bye "Cancelled; no key was created."
        readPassword "${confirmPrompt}" _rnkpSecond || bye "Cancelled; no key was created."
        if [[ ${_rnkpFirst} != "${_rnkpSecond}" ]]; then
            show nl "The two entries do not match; enter it again." nl
            continue
        fi
        break
    done
    _rnkpResultRef="${_rnkpFirst}"
    eraseVars _rnkpFirst _rnkpSecond
    (( adviceShown )) && _setAdviceCount 2
    show nl "Good." primary italic "Keep this passphrase someplace secure!" nl
}

# Shows passphrases generated by valt, to choose one of.

_showGeneratedPassphrases() {
    local phrase i
    show nl "Here are some randomly generated ones to choose from:" nl
    for (( i = 0; i < 32; i++ )); do
        generatePassphrase phrase
        show "  " bold cyan "${phrase}"
    done
    show nl "Enter one of these (or another strong passphrase of your own) below." nl
}

_showPrivateKeyPassphraseAdvice() {
    echo "Normally you will need only a single key pair for all your file encryption needs. Your new private key will itself"
    show "be encrypted, so it can be stored anywhere: the passphrase you enter here will be" italic "required" "to use it. You'll be"
    echo "asked for it twice."
    echo
    show "Use a passphrase of several" italic "random" "words rather than a password: it is far easier to remember, and much harder"
    echo "to crack. People are poor at picking words at random, so let valt pick them: answer no to the question below and"
    show "it will show you some to choose from (or run" bold blue "valt passphrase" "at any time)."
    echo
    echo "Since human memory is fallible, keep a record of the passphrase: on the paper key valt makes for your key or, more"
    show "securely, somewhere its notes point to. If the passphrase is lost, so is" bold "everything" "encrypted with this key."
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

