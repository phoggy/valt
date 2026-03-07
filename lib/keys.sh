#!/usr/bin/env bash

# Encryption (Age) and signing (minisign) key generation and usage.
# Generation produces Age & minisign public key files, and a combined 'valt' private key.
# Use via: require 'valt/keys'

# Create new valt keys, encrypting the private key with a passphrase. May show passphrase advice and offer to generate passphrase.
# Args: keyFile publicKeyFile publicSigningKeyFile [captureVarName]
#
#   keyFile               path where the passphrase-encrypted private key file will be written
#   publicKeyFile         path where the plain-text public key will be written
#   publicSigningKeyFile  path where the plain-text signing public key will be written
#   captureVarName        optional variable name to receive the passphrase entered during encryption

createValtKeys() {
    useValtPinEntry
    local keyFile="$1"
    local publicKeyFile="$2"
    local publicSigningKeyFile="$3"
    local captureVarName="${4:-}"
    local capture=0
    local ageCreated
    local agePublicKey
    local agePrivateKey=()
    local valtKey=()
    local valtPubKey=()
    local index line
    [[ -n "${keyFile}" ]] || invalidArgs "keyFile not provided"
    [[ -n "${publicKeyFile}" ]] || invalidArgs "publicKeyFile not provided"
    [[ -n "${publicSigningKeyFile}" ]] || invalidArgs "publicSigningKeyFile not provided"

    [[ -f ${keyFile} ]] && invalidArgs "${keyFile} should have been deleted!"
    [[ -n "${captureVarName}" ]] && capture=1

    # Maybe offer passphrase advice and/or generate passphrase if desired

    _maybeOfferPassphraseAdvice

    # Generate the age private key (includes public key)

    mapfile -t < <( rage-keygen 2> /dev/null ) agePrivateKey || fail

    # Extract the created line and public key (hopefully future proof)

    index=${ indexOf -r "${ageCreatedPrefix}" agePrivateKey; }
    ageCreated="${agePrivateKey[index]}"
    agePrivateKey=("${agePrivateKey[@]:0:index}" "${agePrivateKey[@]:index+1}")
debugVar agePrivateKey
    index=${ indexOf -r "${agePublicKeyPrefix}" agePrivateKey; }
    line="${agePrivateKey[index]}"
    agePublicKey="${line:${#agePublicKeyPrefix}}"

    # Generate unencrypted signing keys and load into our signingPrivateKey array

    local signingPublicKey=()
    local signingPrivateKey=()
    local signingPublicKeyFile; signingPublicKeyFile="${ tempDirPath -r; }"
    local signingPrivateKeyFile; signingPrivateKeyFile="${ tempDirPath -r; }"
    minisign -G -p "${signingPublicKeyFile}" -s "${signingPrivateKeyFile}" -W > /dev/null || fail
    mapfile -t < <(cat "${signingPublicKeyFile}") signingPublicKey || fail
    mapfile -t < <(cat "${signingPrivateKeyFile}") signingPrivateKey || fail
    rm "${signingPublicKeyFile}" "${signingPrivateKeyFile}" &> /dev/null

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
debugVar valtKey

    # Construct the combined 'valt.pub' public key

    for line in "${signingPublicKey[@]}"; do
        valtPubKey+=("${signingPublicKeyPrefix}${line}")
    done
    valtPubKey+=("#")
    valtPubKey+=("${agePublicKey}")
debugVar valtPubKey

    # Configure a pipe to capture the passphrase if requested

    export _rayvnAnonymousPipe
    (( capture )) && _rayvnAnonymousPipe="${ makeTempFile 'XXXXXXXXXXXX'; }"

    # Encrypt the private key

    echo
    printf "%s\n" "${valtKey[@]}" | rage -p -a -o "${keyFile}" - || bye

    # Grab and return the passphrase if requested

    if (( capture )) && [[ -s "${_rayvnAnonymousPipe}" ]]; then
        local result
        read -r result < "${_rayvnAnonymousPipe}"
        rm -f "${_rayvnAnonymousPipe}" 2> /dev/null
        printf -v "${captureVarName}" '%s' "${result}"
    fi

    # Write out public keys

    printf '%s\n'  "${valtPubKey[@]}" > "${publicKeyFile}"
    printf '%s\n' "${signingPublicKey[@]}" > "${publicSigningKeyFile}"

    # Turn off our pinentry

    disableValtPinEntry
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

armorValtKey() {
    local ageFile="${1}"
    local -n resultVar="${2}"
    local header="${ head -n 1 "${ageFile}"; }"
    if [[ ${header} =~ ^age-encryption.org/v ]]; then
        # $'x' is bash magic for mapping escaped characters
        local result=$'-----BEGIN AGE ENCRYPTED FILE-----\n'
        # Platform-agnostic base64: try BSD -b flag first, fall back to GNU -w flag
        result+="${ cat "${ageFile}" | base64 -b 65 2>/dev/null || cat "${ageFile}" | base64 -w 65; }"
        result+=$'\n'
        result+=$'-----END AGE ENCRYPTED FILE-----\n'
        resultVar=${result}
    else
        fail "${ageFile} does not appear to be an age encrypted file"
    fi
}

tempPublicKeyFile() {
    local decrypt=false prefix="${agePublicKeyPrefix}"
    local keyFile="$1" resultFileVar="$2"
    _extractKeyToTempFile "${keyFile}" "${prefix}" ${decrypt} ${resultFileVar}
}

tempSigningPublicKeyFile() {
    local decrypt=false prefix="${signingPublicKeyPrefix}"
    local keyFile="$1" resultFileVar="$2"
    _extractKeyToTempFile "${keyFile}" "${prefix}" ${decrypt} ${resultFileVar}
}

tempSigningKeyFile() {
    local decrypt=true prefix="${signingPrivateKeyPrefix}"
    local keyFile="$1" resultFileVar="$2"
    _extractKeyToTempFile "${keyFile}" "${prefix}" ${decrypt} ${resultFileVar}
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'valt/keys' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_valt_keys() {
    require 'rayvn/core' 'valt/pinentry' 'valt/password' 'rayvn/prompt'
    declare -grx xkcdPasswordsUrl="https://xkcd.com/936/"
    declare -grx ageFileExtension='age'
    declare -grx tarFileExtension='tar.xz'
    declare -grx ageCreatedPrefix='# created: '
    declare -grx agePublicKeyPrefix='# public key: '
    declare -grx signingPublicKeyPrefix='# [sign public] '
    declare -grx signingPrivateKeyPrefix='# [sign secret] '

    local counterFile; counterFile="${ configDirPath 'advice.count'; }"
    declare -grx adviceCounterFile="${counterFile}"
    declare -g _adviceCount=0
}

_extractKeyToTempFile() {
    local keyFile="$1"
    local keyPrefix="$2"
    local decrypt="$3"
    local -n resultFileRef="$4"
    local _key=()
    local resultArray=()
    local resultFile; resultFile="${ makeTempFile 'XXXXXXXX'; }"
debugVar keyFile keyPrefix decrypt
    # Map private key to array

    _readKeyToArray "${keyFile}" ${decrypt} _key
 debugVar _key
    (( ${#_key} == 0 )) && fail ")_key not assigned!" # TODO Fix and remove
    # Extract the key

    _extractKeyContent _key "${keyPrefix}" resultArray
debugVar resultArray
    # Write it to the temp signing file and assign the result

    printf "%s\n" "${resultArray[@]}" > "${resultFile}"
    resultFileRef="${resultFile}"
}

_readKeyToArray() {
    assertFile "$1"
    useValtPinEntry
    local keyFile="$1"
    local decrypt="$2"
    local resultArrayRef="$3"
    local _result=()
debug "_readKeyToArray"
    debugVar keyFile decrypt rayvnTest_ValtKeyPassphrase
    if [[ ${decrypt} == true ]]; then
        [[ -n "${rayvnTest_ValtKeyPassphrase}" ]] && debug "using passphrase to decrypt private key and map" || debug "requesting passphrase to decrypt private key and map"
        export skipReadPasswordCheck=1
        mapfile -t < <( rage -d "${keyFile}" 2> >(redStream) ) _result || fail
        unset skipReadPasswordCheck
    else
debug "mapping public key"
        mapfile -t "${keyFile}" _result || fail
    fi
    debugVar _result
    debug "${_result[@]}"
    resultArrayRef=("${_result[@]}")
}

_extractKeyContent() {
    local -n valtKeyArrayRef="$1"
    local keyPrefix="$2"
    local -n _resultArrayRef="$3"
    local line _result=()

    for line in "${valtKeyArrayRef[@]}"; do
        if [[ ${line} == "${keyPrefix}"* ]]; then
            _result+=( "${line:${#keyPrefix}}" )
        fi
    done
    debugVar _result
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
