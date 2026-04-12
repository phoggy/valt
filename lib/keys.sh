#!/usr/bin/env bash

# ────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
#
# ◇ DESIGN NOTES
#
# Age supports '#' comments in both public and private keys. A valt key is passphrase encrypted in PEM format and contains both
# minisign keys and Age public key as comments, along with Age private key. A valt public key is plaintext and is an Age public
# key with minisign public key as comment(s).
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
#   # age1pq1m43p0m52f544e868gyh09rx0wrr6jg8thvcr5cekpdkhzapwa7jjdgh54zlnjp0wny04tcae7h3k5x0s25l3znxpvvq  [ ... ]
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
# have one. If no, then shown a set of generated ones to choose from. This behavior is suppressed after second key gen.
#
# ◇ Valt Key Use
#
#   - Encrypt/sign requires valt.key for PRIVATE signing key and PUBLIC Age key
#   - Decryption requires valt.key for PRIVATE Age key
#   - Verify requires valt.pub, for PUBLIC signing key
#   - Full verify requires valt.key for PUBLIC signing key(s) and PRIVATE Age key
#   - Extract requires valt.key. Warns if sig not verified and asks if should proceed.
#
# ◇ Key Storage
#
#   valt.key: local, password manager (bitwarden, etc.)
#   valt.pub: local, password manager (bitwarden, etc.), user's github, google drive, iCloud, etc.
#
# ────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────


# Encryption (Age) and signing (minisign) key generation and usage.
# Use via: require 'valt/keys'

# Create new valt keys, encrypting the private key with a passphrase. May show passphrase advice and offer to generate passphrase.
# Produces keys that combine minisign keys (as comments) and Age keys:
#
#   [name-]valt.pub: minisign public key comment + Age public key
#   [name-]valt.key: minisign public key comment + Age public key comment + encrypted minisign secret key comment + Age secret key
#
# Args: [keyName] [keyDir] [valtPubFileResultVar] [valtKeyFileResultVar] [testPassResultVar]
#
# Passing '?' for any arg will ensure the default behavior.
#
#   keyName               optional name prefix for keys
#   keyDir                optional directory path where key files will be written, default: ~/.config/valt
#   valtPubFileResultVar  optional var name to assign the valt.pub file
#   valtKeyFileResultVar  optional var name to assign the valt.key file
#   testPassResultVar     optional var name to assign the password to for testing

createValtKeys() {
    local keyName="${1:-?}"
    local keyDir="${2:-?}"
    local _valtPubFileResultVar="${3:-?}"
    local _valtKeyFileResultVar="${4:-?}"
    local _testPassResultVar="${5:-}"

    local keyPrefix=
    [[ ${keyName} != '?' ]] && keyPrefix="${keyName}-"
    if [[ ${keyDir} == '?' ]]; then
        # Force use of valt config dir
        keyDir="${ configDirPath -p 'valt'; }"
    else
        assertDirectory "${keyDir}"
    fi
    local _keyFile="${keyDir}/${keyPrefix}${valtPrivateKeySuffix}"
    local _publicKeyFile="${keyDir}/${keyPrefix}${valtPublicKeySuffix}"
    local _publicSigningKeyFile="${keyDir}/${keyPrefix}${valtSigningPublicKeySuffix}"
    local capture=0
    local ageCreated
    local agePublicKey
    local agePrivateKey=()
    local valtPubKey=()
    local index line
    _assertKeyFileDoesNotExist "${_keyFile}"
    _assertKeyFileDoesNotExist "${_publicKeyFile}"
    _assertKeyFileDoesNotExist "${_publicSigningKeyFile}"
    if [[ -n "${_testPassResultVar}" ]]; then
        [[ "${_testPassResultVar}" == '?' ]] && unset _testPassResultVar || capture=1
    fi

    # Maybe offer passphrase advice and/or generate passphrase if desired

    _maybeOfferPassphraseAdvice

    # Generate the post-quantum age private key (includes public key)

    mapfile -t agePrivateKey < <( age-keygen -pq 2> /dev/null ) || fail

    # Extract the created line and public key (hopefully future proof)

    indexOf -p "${ageCreatedPrefix}" agePrivateKey index
    ageCreated="${agePrivateKey[index]}"
    agePrivateKey=("${agePrivateKey[@]:0:index}" "${agePrivateKey[@]:index+1}")
    indexOf -p "${agePublicKeyPrefix}" agePrivateKey index
    line="${agePrivateKey[index]}"
    agePublicKey="${line:${#agePublicKeyPrefix}}"

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
        commonKey+=("${signingPublicKeyPrefix}${line}")
    done
    commonKey+=("#")

    # Construct valt.pub

    valtPubKey=("${commonKey[@]}")
    valtPubKey+=("${agePublicKey}")

    # Construct the combined 'valt.key' plaintext lines

    local plainPrivate
    plainPrivate=("${commonKey[@]}")
    for line in "${signingPrivateKey[@]}"; do
        plainPrivate+=("${signingPrivateKeyPrefix}${line}")
    done
    plainPrivate+=('#')
    plainPrivate+=("${agePrivateKey[@]}")

    # Encrypt the private components directly to the key file, optionally capturing the passphrase for testing

    _encryptKey plainPrivate "${_keyFile}" "${_testPassResultVar}"
    chmod 600 "${_keyFile}" 2> /dev/null

    # Write public key

    printf '%s\n' "${valtPubKey[@]}" > "${_publicKeyFile}"

    # Assign results if var specified

    _assignResultIfVarName ${_valtPubFileResultVar} "${_publicKeyFile}"
    _assignResultIfVarName ${_valtKeyFileResultVar} "${_keyFile}"
}

# Verify keys by encrypting sample text, signing, verify signature and decrypting, then comparing.
# Fails if decryption does not reproduce the original (e.g. wrong passphrase).
# Args: keyFile valtPubFile valtKeyFile
#
#   valtPubFile  path to the valt.pub file
#   valtKeyFile  path to the valt.key file

verifyValtKeys() {
    local valtPubFile="$1"
    local valtKeyFile="$2"

    assertFile "${valtPubFile}"
    assertFile "${valtKeyFile}"

    local encryptedFile; encryptedFile="${ tempDirPath sample.age; }"
    local signatureFle; signatureFile="${ tempDirPath sample.minisign; }"
    local sampleText; _setSampleText sampleText

    # TODO:
    #   - extract public keys from both valt.key and valt.pub and ensure equal
    #   - encrypt sample text file using valt.key
    #   - sign encrypted sample file and verify signature
    #   - decrypt using valt.key and ensure equal to sample text
    fail TODO

    # Encrypt

    echo -n "${sampleText}" | age -R "${valtKeyFile}" -o "${encryptedFile}" || fail

    # Sign

    # Verify signature

    # Decrypt and compare

    local decrypted="${ age -d -i "${valtKeyFile}" "${encryptedFile}" 2> /dev/null; }"
    diff -u <(echo -n "${sampleText}") <(echo "${decrypted}") > /dev/null || fail "not verified (wrong passphrase?)"
}

# accepts either valt.pub or valt.key, echos 'valt.pub', 'valt.key'
keyType() {
    local keyFile="$1"
    while read line; do
        if (( "${#line}" )); then # Ignore blank lines
            if [[ ${line} == "${ageEncryptedBegin}" || ${line} == "${agePemBegin}" ]]; then
                echo "${valtPrivateKeySuffix}"
            elif [[ ${line} == "${ageCreatedPrefix}"* ]]; then
                echo "${valtPublicKeySuffix}"
            else
                fail "not a valt key file"
            fi
            break;
        fi
    done < <( cat ${keyFile} )
}

# accepts either valt.pub or valt.key
publicEncryptionKey() {
    local keyFile="$1"
    _extractKey "${keyFile}" true "${agePublicKeyPrefix}" 1
}

# accepts either valt.pub or valt.key
publicSigningKeyToTempFile() {
    local keyFile="$1"
    local -n resultFileRef="$2"
    local tempFile; tempFile="${ makeTempFile; }"
    _extractKey "${keyFile}" true "${signingPublicKeyPrefix}" 2 "${tempFile}"
    resultFileRef="${tempFile}"
}

# accepts valt.key only
signingKeyToTempFile() {
    local keyFile="$1"
    local -n resultFileRef="$2"
    local tempFile; tempFile="${ makeTempFile; }"
    _extractKey "${keyFile}" false "${signingPrivateKeyPrefix}" 2 "${tempFile}"
    resultFileRef="${tempFile}"
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'valt/keys' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_valt_keys() {
    require 'valt/password' 'rayvn/prompt'
    declare -grx xkcdPasswordsUrl="https://xkcd.com/936/"
    declare -grx valtPublicKeySuffix='valt.pub'
    declare -grx valtPrivateKeySuffix='valt.key'
    declare -grx valtSigningPublicKeySuffix='minisign.pub'
    declare -grx ageFileExtension='age'
    declare -grx tarFileExtension='tar.xz'
    declare -grx ageCreatedPrefix='# created: '
    declare -grx agePublicKeyPrefix='# public key: '
    declare -grx signingPublicKeyPrefix='# [minisign.pub] '
    declare -grx signingPrivateKeyPrefix='# [minisign.key] '
    declare -grx valtSigningPublicKeyPrefix='untrusted comment: minisign public key'
    declare -grx ageEncryptedBegin='age-encryption.org/v1'
    declare -grx agePemBegin='-----BEGIN AGE ENCRYPTED FILE-----'

    local counterFile; counterFile="${ configDirPath 'advice.count'; }"
    declare -grx adviceCounterFile="${counterFile}"
    declare -g _adviceCount=0
}

_encryptKey() {
    local -n keyRef=$1
    local destFile=$2
    local captureVar="${3:-}"
    local phraze passFd

    # Get the user's passphrase

    if [[ -n ${rayvnTest_ValtKeyPassphrase} ]]; then
        phraze="${rayvnTest_ValtKeyPassphrase}"
    else
        readVerifiedPassword phraze || fail
    fi

    # Encrypt directly to destFile. Feed the passphrase via a dynamically allocated fd using process
    # substitution — printf exits after writing, closing the write end of the pipe,
    # so the plugin's io.ReadAll receives EOF immediately and does not hang.
    # See https://github.com/FiloSottile/age/blob/main/cmd/age-plugin-batchpass/plugin-batchpass.go
    # Note: do NOT use -a (ASCII armor) — the binary format is required to avoid QR code size limits.
    # Binary output must never be read into a bash array; write directly to the destination file.

    exec {passFd}< <(printf '%s' "${phraze}")
    printf "%s\n" "${keyRef[@]}" | AGE_PASSPHRASE_FD="${passFd}" age -e -j batchpass > "${destFile}" || bye
    exec {passFd}<&-

    # Capture if we're in test mode

    [[ -n "${captureVar}" ]] && printf -v "${captureVar}" '%s' "${phraze}"
}

_assertKeyFileDoesNotExist() {
    [[ $1 != '?' && -f $1 ]] && invalidArgs "$1 already exists"
}

_assignResultIfVarName() {
    local _resultVarName=$1
    if [[ -n ${_resultVarName} && ${_resultVarName} != ? ]]; then
        local -n _resultVarRef=${_resultVarName}
        _resultVarRef="$2"
    fi
}

_extractKey() {
    local keyFile="$1"
    local allowPublic=$2
    local keyPrefix="$3"
    local keyLineCount=$4
    local resultFile="${5:-}" # echo if none else write to file.
    local firstLine=1 lines=()
    local line phraze passFd plain=()
    while read line; do
        if (( "${#line}" )); then # Ignore blank lines
            if (( firstLine )); then
                if [[ ${line} == "${ageEncryptedBegin}" || ${line} == "${agePemBegin}" ]]; then

                    # valt.key so decrypt and switch to reading that

                    if [[ -n ${rayvnTest_ValtKeyPassphrase} ]]; then
                        phraze="${rayvnTest_ValtKeyPassphrase}"
                    else
                        readPassword "Password" phraze 30 false || fail
                    fi
                    local plainFile; plainFile="${ makeTempFile; }"
                    exec {passFd}< <(printf '%s' "${phraze}")
                    cat "${keyFile}" | AGE_PASSPHRASE_FD="${passFd}" age -d -j batchpass > "${plainFile}" 2> >(errorStream) || fail
                    exec {passFd}<&-
                    mapfile -t plain < "${plainFile}"
                    rm "${plainFile}" 2> /dev/null

                    for line in "${plain[@]}"; do
                        if [[ ${line} == "${keyPrefix}"* ]]; then
                            lines+=( "${line:${#keyPrefix}}" )
                            (( --keyLineCount )) || break
                        fi
                    done
                    break;

                elif [[ ${allowPublic} == true ]]; then

                    # valt.pub is allowed, so continue processing lines.
                    # If we're looking for the age public key we need to
                    # switch the key prefix

                    [[ ${keyPrefix} == "${agePublicKeyPrefix}" ]] && keyPrefix='age1'

                    if [[ ${line} == "${keyPrefix}"* ]]; then
                        lines+=( "${line}" )
                        (( --keyLineCount )) || break
                    fi
                    firstLine=0
                else
                    fail "requires key type '${valtPrivateKeySuffix}'"
                fi
            else
                if [[ ${line} == "${keyPrefix}"* ]]; then
                    lines+=( "${line}" )
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
    show "this subject" blue "${xkcdPasswordsUrl}" "that ends with this gem:"
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
    if [[ -e ${adviceCounterFile} ]]; then
        _adviceCount="${ cat "${adviceCounterFile}"; }"
    fi
}

_setAdviceCount() {
    _adviceCount=$1
    _writeAdviceCount
}

_writeAdviceCount() {
    echo "${_adviceCount}" > "${adviceCounterFile}"
}

_setSampleText() {
    local -n resultVar="$1"
    if [[ ! ${resultVar} ]]; then
        IFS='' read -d '' -r resultVar <<'QUOTE'

            But the Raven, sitting lonely on the placid bust, spoke only
        That one word, as if his soul in that one word he did outpour.
            Nothing farther then he uttered—not a feather then he fluttered—
            Till I scarcely more than muttered “Other friends have flown before—
        On the morrow he will leave me, as my Hopes have flown before.”
                         Then the bird said “Nevermore.”

QUOTE
    fi
}
