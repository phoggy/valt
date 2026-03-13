#!/usr/bin/env bash

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
#   testPassResultVar     optional var name to assign the password for testing

createValtKeys() {
    useValtPinEntry
    local keyName="${1:-?}"
    local keyDir="${2:-?}"
    local _valtPubFileResultVar="${3:-?}"
    local _valtKeyFileResultVar="${4:-?}"
    local _testPassResultVar="${5:-?}"

    local keyPrefix=
    [[ ${keyName} != '?' ]] && keyPrefix="${keyName}-"
    if [[ ${keyDir} == '?' ]]; then
        # Force use of valt config dir
        local origProject="${currentProjectName}"
        currentProjectName='valt'
        keyDir="${ configDirPath; }"
        currentProjectName=${origProject}
    else
        assertDirectory "${keyDir}"
    fi
    local _keyFile="${keyDir}/${keyPrefix}${valtPrivateKeySuffix}"
    local _publicKeyFile="${keyDir}/${keyPrefix}${valtPublicKeySuffix}"
    local _publicSigningKeyFile="${keyDir}/${keyPrefix}${valtSigningPublicKeySuffix}"
    local capture=0
    local armoredKey
    local armoredKeyFile
    local ageCreated
    local agePublicKey
    local agePrivateKey=()
    local valtKey=()
    local valtPubKey=()
    local index line
    _assertKeyFileDoesNotExist "${_keyFile}"
    _assertKeyFileDoesNotExist "${_publicKeyFile}"
    _assertKeyFileDoesNotExist "${_publicSigningKeyFile}"
    [[ -n "${_testPassResultVar}" && "${_testPassResultVar}" != '?' ]] && capture=1

    # Maybe offer passphrase advice and/or generate passphrase if desired

    _maybeOfferPassphraseAdvice

    # Generate the age private key (includes public key)

    mapfile -t agePrivateKey < <( rage-keygen 2> /dev/null ) || fail

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
    ls -l ${_signingPublicKeyFile}
    ls -l ${_signingPrivateKeyFile}
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

    # Encrypt the private components, optionally capturing the password for testing

    armoredKeyFile="${ makeTempFile; }"
    if (( capture )); then
        export _valtTestTemp; _valtTestTemp="${ makeTempFifo; }"
        printf "%s\n" "${plainPrivate[@]}" | rage -p -a -o "${armoredKeyFile}" - &
        local ragePid=$!
        local result
        read -r result < "${_valtTestTemp}"
        wait ${ragePid} || fail "encryption failed"
        rm -f "${_valtTestTemp}" 2> /dev/null
        unset _valtTestTemp
        printf -v "${_testPassResultVar}" '%s' "${result}"
    else
        printf "%s\n" "${plainPrivate[@]}" | rage -p -a -o "${armoredKeyFile}" - || bye
    fi
    mapfile -t armoredKey < <( cat "${armoredKeyFile}" )

    # Construct valt.key. Comments are ONLY supported WITHIN encrypted content, per the Age spec.

    valtKey=("${armoredKey[@]}")

    # Write keys

    printf '%s\n' "${valtPubKey[@]}" > "${_publicKeyFile}"
    printf '%s\n' "${valtKey[@]}" > "${_keyFile}"

    # Assign results if var specified

    _assignResultIfVarName ${_valtPubFileResultVar} "${_publicKeyFile}"
    _assignResultIfVarName ${_valtKeyFileResultVar} "${_keyFile}"

    # Disable valt-pinentry

    disableValtPinEntry
}

# Verify keys by encrypting sample text, signing, verify signature and decrypting, then comparing.
# Fails if decryption does not reproduce the original (e.g. wrong passphrase).
# Args: keyFile valtPubFile valtKeyFile
#
#   valtPubFile  path to the valt.pub file
#   valtKeyFile  path to the valt.key file

verifyValtKeys() {
    useValtPinEntry

    local valtPubFile="$1"
    local valtKeyFile="$2"

    assertFile "${valtPubFile}"
    assertFile "${valtKeyFile}"

    local encryptedFile; encryptedFile="${ tempDirPath sample.age; }"
    local signatureFle; signatureFile="${ tempDirPath sample.minisign; }"
    local sampleText
    _setSampleText sampleText

    # TODO:
    #   - extract public keys from both valt.key and valt.pub and ensure equal
    #   - encrypt sample text file using valt.key
    #   - sign encrypted sample file and verify signature
    #   - decrypt using valt.key and ensure equal to sample text
    fail TODO

    # Encrypt

    echo -n "${sampleText}" | rage -R "${valtKeyFile}" -o "${encryptedFile}" || fail

    # Sign

    # Verify signature

    # Decrypt and compare

    local decrypted="${ rage -d -i "${valtKeyFile}" "${encryptedFile}" 2> /dev/null; }"
    diff -u <(echo -n "${sampleText}") <(echo "${decrypted}") > /dev/null || fail "not verified (wrong passphrase?)"
    disableValtPinEntry
}

# accepts either valt.pub or valt.key, echos 'valt.pub', 'valt.key'
keyType() {
    local keyFile="$1"
    while read line; do
        if (( "${#line}" )); then # Ignore blank lines
            if [[ ${line} == "${agePemBegin}" ]]; then
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
    local tempFile; tempFile="${ makeTempFile 'XXXXXXXX'; }"
    _extractKey "${keyFile}" true "${signingPublicKeyPrefix}" 2 "${tempFile}"
    resultFileRef="${tempFile}"
}

# accepts valt.key only
signingKeyToTempFile() {
    local keyFile="$1"
    local -n resultFileRef="$2"
    local tempFile; tempFile="${ makeTempFile 'XXXXXXXX'; }"
    _extractKey "${keyFile}" false "${signingPrivateKeyPrefix}" 2 "${tempFile}"
    resultFileRef="${tempFile}"
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'valt/keys' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_valt_keys() {
    require 'rayvn/core' 'valt/pinentry' 'valt/password' 'rayvn/prompt'
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
    declare -grx agePemBegin='-----BEGIN AGE ENCRYPTED FILE-----'
    declare -grx agePemEnd='-----END AGE ENCRYPTED FILE-----'

    local counterFile; counterFile="${ configDirPath 'advice.count'; }"
    declare -grx adviceCounterFile="${counterFile}"
    declare -g _adviceCount=0
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
    local line

    while read line; do
        if (( "${#line}" )); then # Ignore blank lines
            if (( firstLine )); then
                if [[ ${line} == "${agePemBegin}" ]]; then

                    # valt.key so decrypt and switch to reading that

                    useValtPinEntry
                    export skipReadPasswordCheck=1
                    while read line; do
                        if [[ ${line} == "${keyPrefix}"* ]]; then
                            lines+=( "${line:${#keyPrefix}}" )
                            (( --keyLineCount )) || break
                        fi
                    done < <( rage -d "${keyFile}" 2> >(redStream) )  || fail
                    unset skipReadPasswordCheck
                    disableValtPinEntry
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
    echo "Normally you will need only a single set of keys for all your file encryption needs. Your new private key will itself"
    echo "be encrypted so that it can be safely stored anywhere: the password you enter here will always be required to use it."
    echo "You'll be prompted to enter it twice for verification."
    echo
    echo "Rather than a typical password, a multi word 'passphrase' is a much better choice here since it will be far easier"
    echo "to remember. Just as with a password manager, the idea is that you remember one secret that gives you access to a"
    show "whole collection of encrypted data. Since human memory" bold italic "is" plain "fallible, it's very important that you keep"
    echo "a copy of the private key in a password manager" bold " and written copies somewhere secure (e.g. a safe, a good friend,"
    echo "a safe-deposit box) in case you forget or become incapacitated."
    echo
    echo "The following are examples of passwords and passphrases, with rough estimates of 'crack' times using modern systems:"
    echo
    show "  " bold cyan "My dog Oscar" plain "                    ⮕ " bold green "easy" plain "to remember" red "non-random" plain "&" red "short" plain ":  6 days to crack"
    show "  " bold cyan "BkZB&XWGj%3Tx" plain "                   ⮕ " bold red "hard" plain "to remember random password:     31 years to crack"
    show "  " bold cyan "repossess thursday flaky lazy" plain "   ⮕ " bold "fair" plain "to remember random passphrase:   centuries to crack"
    echo
    show "A good passphrase requires randomness, and we humans are very bad at that. There's a famous" magenta "xkcd" plain "comic on"
    show "this subject" blue "${xkcdPasswordsUrl}" plain "that ends with this gem:"
    echo
    echo "     Through 20 years of effort, we've successfully trained everyone to use passwords that"
    echo "     are hard for humans to remember, but easy for computers to guess."
    echo "                                                                           — Randall Munroe"
    echo
    echo "That comic makes another important point in the last cell: creating a mental scene to represent your passphrase is an"
    show italic "excellent" plain "way to help remember it."
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
    local -n resultVar="${1}"
    if [[ ! ${resultVar} ]]; then
        IFS='' read -d '' -r resultVar <<'HEREDOC'
                                🌑🌒🌓🌔🌕🌖🌗🌘

            But the Raven, sitting lonely on the placid bust, spoke only
        That one word, as if his soul in that one word he did outpour.
            Nothing farther then he uttered—not a feather then he fluttered—
            Till I scarcely more than muttered “Other friends have flown before—
        On the morrow he will leave me, as my Hopes have flown before.”
                         Then the bird said “Nevermore.”

                                🌑🌒🌓🌔🌕🌖🌗🌘
HEREDOC
    fi
}
