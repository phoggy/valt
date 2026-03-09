#!/usr/bin/env bash

# Encryption (Age) and signing (minisign) key generation and usage.
# Generation produces Age & minisign public key files, and a combined 'valt' private key.
# Use via: require 'valt/keys'

# Create new valt keys, encrypting the private key with a passphrase. May show passphrase advice and offer to generate passphrase.
# Args: [keyName] [keyDir] [keyFileResultVar] [publicKeyFileResultVar] [publicSigningKeyFileVar] [testPassResultVar]
#
# A '?' for any arg will ensure the default behavior.
#
#   keyName                  optional name prefix for keys
#   keyDir                   optional directory path where key files will be written, default: ~/.config/valt
#   keyFileResultVar         optional var name to assign the private key file
#   keyFileResultVar         optional var name to assign the private key file
#   publicKeyFileResultVar   optional var name to assign the public key file
#   publicSigningKeyFileVar  optional var name to assign the signing public key file
#   testPassResultVar        optional var name to assign the password for testing

createValtKeys() {
    useValtPinEntry

    local keyName="${1:-?}"
    local keyDir="${2:-?}"
    local _keyFileResultVar="${3:-?}"
    local _publicKeyFileResultVar="${4:-?}"
    local _publicSigningKeyFileResultVar="${5:-?}"
    local _testPassResultVar="${6:-?}"

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

    mapfile -t < <( rage-keygen 2> /dev/null ) agePrivateKey || fail

    # Extract the created line and public key (hopefully future proof)

    index=${ indexOf -r "${ageCreatedPrefix}" agePrivateKey; }
    ageCreated="${agePrivateKey[index]}"
    agePrivateKey=("${agePrivateKey[@]:0:index}" "${agePrivateKey[@]:index+1}")
    index=${ indexOf -r "${agePublicKeyPrefix}" agePrivateKey; }
    line="${agePrivateKey[index]}"
    agePublicKey="${line:${#agePublicKeyPrefix}}"

    # Generate unencrypted signing keys and load into our signingPrivateKey array

    local signingPublicKey=()
    local signingPrivateKey=()
    local _signingPublicKeyFile; _signingPublicKeyFile="${ tempDirPath -r; }"
    local _signingPrivateKeyFile; _signingPrivateKeyFile="${ tempDirPath -r; }"
    minisign -G -p "${_signingPublicKeyFile}" -s "${_signingPrivateKeyFile}" -W > /dev/null || fail
    mapfile -t < <(cat "${_signingPublicKeyFile}") signingPublicKey || fail
    mapfile -t < <(cat "${_signingPrivateKeyFile}") signingPrivateKey || fail
    rm "${_signingPublicKeyFile}" "${_signingPrivateKeyFile}" &> /dev/null

    # Construct the combined 'valt.key' private key

    valtKey+=("${ageCreated}")
    valtKey+=('#')
    for line in "${signingPublicKey[@]}"; do
        valtKey+=("${signingPublicKeyPrefix}${line}")
    done
    valtKey+=('#')
    for line in "${signingPrivateKey[@]}"; do
        valtKey+=("${signingPrivateKeyPrefix}${line}")
    done
    valtKey+=('#')
    for line in "${agePrivateKey[@]}"; do
        valtKey+=("${line}")
    done

    # Construct the combined 'valt.pub' public key

    valtPubKey+=("${ageCreated}")
    valtPubKey+=('#')
    for line in "${signingPublicKey[@]}"; do
        valtPubKey+=("${signingPublicKeyPrefix}${line}")
    done
    valtPubKey+=("#")
    valtPubKey+=("${agePublicKey}")

    # Encrypt the private key, optionally capturing the password for testing

    if (( capture )); then
        export _valtTestTemp; _valtTestTemp="${ makeTempFifo; }"
        printf "%s\n" "${valtKey[@]}" | rage -p -a -o "${_keyFile}" - &
        local ragePid=$!
        local result
        read -r result < "${_valtTestTemp}"
        wait ${ragePid} || fail "encryption failed"
        rm -f "${_valtTestTemp}" 2> /dev/null
        unset _valtTestTemp
        printf -v "${_testPassResultVar}" '%s' "${result}"
    else
        printf "%s\n" "${valtKey[@]}" | rage -p -a -o "${_keyFile}" - || bye
    fi

    # Write public keys

    printf '%s\n'  "${valtPubKey[@]}" > "${_publicKeyFile}"
    printf '%s\n' "${signingPublicKey[@]}" > "${_publicSigningKeyFile}"

    # Turn off our pinentry

    disableValtPinEntry

    # Assign results if var specified

    _assignResultIfVarName ${_keyFileResultVar} "${_keyFile}"
    _assignResultIfVarName ${_publicKeyFileResultVar} "${_publicKeyFile}"
    _assignResultIfVarName ${_publicSigningKeyFileResultVar} "${_publicSigningKeyFile}"
}

# Verify keys by encrypting sample text, signing, verify signature and decrypting, then comparing.
# Fails if decryption does not reproduce the original (e.g. wrong passphrase).
# Args: keyFile publicKeyFile publicSigningKeyFile
#
#   keyFile               path where the passphrase-encrypted private key file will be written
#   publicKeyFile         path where the plain-text public key will be written
#   publicSigningKeyFile  path where the plain-text signing public key will be written

verifyValtKeys() {
    useValtPinEntry

    local keyFile="$1"
    local publicKeyFile="$2"
    local publicSigningKeyFile="$3"

    assertFile "${keyFile}"
    assertFile "${publicKeyFile}"
    assertFile "${publicSigningKeyFile}"

    local encryptedFile; encryptedFile="${ tempDirPath sample.age; }"
    local signatureFle; signatureFile="${ tempDirPath sample.sig; }"
    local sampleText
    _setSampleText sampleText

    fail "TODO!"
    # Encrypt
    echo -n "${sampleText}" | rage -R "${publicKeyFile}" -o "${encryptedFile}" || fail

    # Sign

    fail TODO # TODO

    # Verify signature

    # Decrypt and compare

    local decrypted="${ rage -d -i "${keyFile}" "${encryptedFile}" 2> /dev/null; }"
    diff -u <(echo -n "${sampleText}") <(echo "${decrypted}") > /dev/null || fail "not verified (wrong passphrase?)"
    disableValtPinEntry
}

# Convert a binary age-encrypted file to PEM-style ASCII-armored text and store in a nameref variable.
# Fails if the file does not appear to be a valid age-encrypted file.
# Args: ageFile resultVar
#
#   ageFile   - path to the binary age-encrypted file
#   resultVar - nameref variable to receive the armored text

armorValtKey() {     # TODO: remove, armored at creation
    local ageFile="${1}"
    local -n resultVar="${2}"
    local header="${ head -n 1 "${ageFile}"; }"
    if [[ ${header} =~ ^age-encryption.org/v ]]; then
        # $'x' is bash magic for mapping escaped characters
        local result=
        result+=$'\n'
        # Platform-agnostic base64: try BSD -b flag first, fall back to GNU -w flag
        result+="${ cat "${ageFile}" | base64 -b 65 2>/dev/null || cat "${ageFile}" | base64 -w 65; }"
        result+=$'\n'
        result+="${agePemEnd}"
        result+=$'\n'
        resultVar=${result}
    else
        fail "${ageFile} does not appear to be an age encrypted file"
    fi
}

keyType() {
    local keyFile="$1"
    local keyType
    _keyFileType "${keyFile}" keyType
    echo "${keyType}"
}

extractPublicKey() {
    local keyFile="$1"
    local keyType; keyType="${ keyFileType "${keyFile}"; }"

    fail TODO # TODO

}

tempSigningPublicKeyFile() {
    local keyFile="$1"
    local resultFileVar="$2" decrypt=true prefix="${signingPublicKeyPrefix}"
    _extractKeyToTempFile "${keyFile}" "${prefix}" ${decrypt} ${resultFileVar}
}

tempSigningKeyFile() {
    local keyFile="$1"
    local resultFileVar="$2" decrypt=true prefix="${signingPrivateKeyPrefix}"
    _extractKeyToTempFile "${keyFile}" "${prefix}" ${decrypt} ${resultFileVar}
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

_keyFileType() {
    local _keyFile="$1"
    local -n _keyFileTypeRef="$2"
    local _keyArrayResultVar="${3:-}"
    local _key=()
    local _type _i line

    # Get the key without decryption if it is a valt.key

    _readKeyToArray "${_keyFile}" false _key
    debugVar _key

    # Determine type TODO: convert to constants

    if [[ ${_key[0]} == "untrusted comment: minisign public key"* ]]; then
        _type="minisign.pub"
    elif  [[ ${_key[0]} == "# created "* ]]; then
        if indexOf "${agePemBegin}" _key; then
            _type='valt.key'
        else
            _type='valt.pub'
        fi
    else
        fail "${_keyFile} is not a valt key file"
    fi
    debugVar _type
    # Assign the type and key array (if requested)

    _keyFileTypeRef="${_type}"

    if [[ -n "${_keyArrayResultVar}" ]]; then
        local -n _keyArrayResultRef="${_keyArrayResultVar}"
        _keyArrayResultRef=("${_key[@]}")
    fi
}

_extractKeyToTempFile() {
    local keyFile="$1"
    local keyPrefix="$2"
    local decrypt="$3"
    local -n resultFileRef="$4"
    local _key=()
    local resultArray=()
    local resultFile; resultFile="${ makeTempFile 'XXXXXXXX'; }"

    # Map private key to array

    _readKeyToArray "${keyFile}" ${decrypt} _key

    # Extract the key

    _extractKeyContent _key "${keyPrefix}" resultArray

    # Write it to the temp signing file and assign the result

    printf "%s\n" "${resultArray[@]}" > "${resultFile}"
    resultFileRef="${resultFile}"
}

_readKeyToArray() {
    assertFile "$1"
    local _keyFile="$1"
    local _decrypt="$2"
    local -n resultArrayRef="$3"
    local _result=()

    if [[ ${_decrypt} == true ]]; then
        useValtPinEntry
        export skipReadPasswordCheck=1
        mapfile -t < <( rage -d "${_keyFile}" 2> >(redStream) ) _result || fail
        unset skipReadPasswordCheck
        disableValtPinEntry
    else
debugVar _keyFile
        mapfile -t "${_keyFile}" _result || fail
    fi
    resultArrayRef=("${_result[@]}")
}

_extractKeyContent() {
    local -n valtKeyArrayRef="$1"
    local _keyPrefix="$2"
    local -n _resultArrayRef="$3"
    local line _result=()

    for line in "${valtKeyArrayRef[@]}"; do
        if [[ ${line} == "${_keyPrefix}"* ]]; then
            _result+=( "${line:${#_keyPrefix}}" )
        fi
    done
    _resultArrayRef=( "${_result[@]}" )
}

_maybeOfferPassphraseAdvice() {
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
