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
# A valt key is passphrase encrypted and contains both minisign keys and age public key as comments, along with age private key.
# A valt public key is plaintext and is an Age public key with minisign public key as comment(s).
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

newValtKeys() {
    local keyName="${1:-valt}"
    local keyDir="${2:-?}"
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
    local index _decl
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

    printf "%s\n" "${plainPrivate[@]}" | _age --encrypt --passphrase --confirm > "${_keyFile}" || fail
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
    local i
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

# ◇ Outputs an ASCII-armored PEM-style encoding of a key file to stdout.
#
# · USAGE
#
#   armorKeyFile keyFile
#
#   keyFile (string)  Path to the key file to armor.

armorKeyFile() {
    local keyFile=$1
    printf '%s\n' "${_agePemBegin}"
    base64 < "${keyFile}" | fold -w 64
    printf '%s\n' "${_agePemEnd}"
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'valt/keys' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_valt_keys() {
    require 'valt/encrypt' 'valt/decrypt'  'valt/sign'

    declare -grx valtPublicKeySuffix='pub'
    declare -grx valtPrivateKeySuffix='key'

    declare -grx _xkcdPasswordsUrl="https://xkcd.com/936/"
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

    local counterFile; counterFile="${ configDirPath 'advice.count'; }"
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
        readPassword "${_prompt}" rayvnTest_ValtKeyPassphrase 30 false || fail
        cursorUpOneAndEraseLine
    fi
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
    _argsArrayRef+=( '-r' "${recipient}" )
    _hasRecipientRef=1
}

_addRecipient() {
    [[ ${1:0:3} == 'age' ]] || fail "not a recipient: $1"
    local recipient; recipient="$1"
    local -n _argsArrayRef="$2"
    local -n _hasRecipientRef="$3"
    _argsArrayRef+=( '-r' "${recipient}" )
    _hasRecipientRef=1
}


_maybeOfferPassphraseAdvice() {
    if (( ! skipKeyPassphraseAdvice )); then
        _readAdviceCount
        if (( _adviceCount <= 1 )); then
            local choiceIndex
            _showPrivateKeyPassphraseAdvice
            confirm "Do you already have a strong, memorable passphrase?" no yes choiceIndex || bye
            if (( choiceIndex == 0 )); then
                show nl "Ok, here a some randomly generated ones to choose from:" nl
                for i in {1..10}; do
                    generatePassphrase
                done
                echo
                confirm "Does one of these work for you?" yep nope choiceIndex || bye
                if (( choiceIndex == 1 )); then
                    show "Ok. If you want to do this later, run:" primary "valt pass"
                    _setAdviceCount 1
                    bye
                fi
                show nl "Good." primary italic "Keep this passphrase someplace secure!" nl
                echo "Ok, now you'll need to enter it for your new keys."
                _setAdviceCount 2
            fi
        fi
    fi
}

_showPrivateKeyPassphraseAdvice() {
    echo "Normally you will need only a single key pair for all your file encryption needs. Your new private key will itself"
    echo "be encrypted so that it can be safely stored anywhere: the password you enter here will be" italic "required" "to use it."
    echo "You'll be prompted to enter it twice for verification during key generation."
    echo
    echo "Rather than a typical password, a multi word 'passphrase' is a" italic "much" "better choice since it is far easier to"
    echo "remember. Just as with a password manager, the idea is that you remember" bold "one" "secret that gives you access to a"
    show "all of your encrypted data. Since human memory" bold italic "is" "fallible, it is extremely important that you keep"
    show "copies on paper somewhere secure (e.g. a safe-deposit box, home safe, trusted family or friend) in case you forget or"
    show "become incapacitated. Your private key (valt.key) can be printed and stored along with it."
    echo
    echo "If you use a password manager (" italic "strongly recommended" glue "), definitely store the keys and password in it!"
    echo
    echo "When you create a key pair, valt will generate a document containing your private key along with instructions for use."
    echo "This document is intended to be the 'paper copy' that you store somewhere secure. It will contain your passphrase, "
    echo "automatically if sent directly to your printer, or space for you to write it if not."
    echo
    echo "The following are examples of passwords and passphrases, with rough estimates of 'crack' times using modern systems:"
    echo
    show "  " bold cyan "My dog Oscar" "                    ⮕ " bold green "easy" "to remember" red "non-random" "&" red "short" ":  6 days to crack"
    show "  " bold cyan "BkZB&XWGj%3Tx" "                   ⮕ " bold red "hard" "to remember random password:     31 years to crack"
    show "  " bold cyan "repossess thursday flaky lazy" "   ⮕ " bold "fair" "to remember random passphrase:   centuries to crack"
    echo
    show "A good passphrase requires randomness, and we humans are very bad at that. There's a famous" magenta "xkcd" "comic on"
    show "this subject" blue "${_xkcdPasswordsUrl}" "that ends with this gem:"
    echo
    echo "     Through 20 years of effort, we've successfully trained everyone to use passwords that"
    echo "     are hard for humans to remember, but easy for computers to guess."
    echo "                                                                           — Randall Munroe"
    echo
    echo "That comic makes another important point in the last cell: creating a mental scene to represent your passphrase is an"
    show italic "excellent" "way to help remember it."
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

