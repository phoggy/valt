#!/usr/bin/env bash

# Encryption/signing key generation.
# Use via: require 'valt/keygen'

# Print guidance about creating an age key pair, including passphrase strength advice.
showAgeKeyPairAdvice() {

    echo "Generally, you will only need a single key pair for all your file encryption needs. Your new private key will itself be"
    echo "encrypted so that it can be safely stored anywhere: the password you enter here will always be required to use it."
    echo "You'll be prompted to enter it twice for verification."
    echo
    echo "Rather than a typical password, a multi word 'passphrase' is a better choice here since it will be far easier"
    echo "to remember. Just as with a password manager, the idea is that you remember one secret that gives you access to a"
    show "whole collection of encrypted data. Since human memory" bold italic "is" plain "fallible, it's very important that you also keep"
    echo "written copies somewhere secure (e.g. a safe, a good friend, a safe-deposit box) in case you forget or become incapacitated."
    echo ""
    echo "!!! TODO!!!" # TODO
    echo

    echo "Your new private key will itself be encrypted, and you will be prompted to enter a 'passphrase' for it (twice). By using"
    echo "a multiple words rather than a terse sequence of numbers, a passphrase can be memorized. Generally and it is"
    echo "important that you use a strong one. preferably one that is easy for you to remember. The following are examples of passwords and passphrases, with rough"
    echo "estimated 'crack' times using modern systems:"
    echo
    show "  " bold cyan "My dog Oscar" plain "                    ⮕ " bold green "easy" plain "to remember" red "non-random" plain "&" red "short" plain ":  6 days to crack"
    show "  " bold cyan "BkZB&XWGj%3Tx" plain "                   ⮕ " bold red "hard" plain "to remember random password:     31 years to crack"
    show "  " bold cyan "repossess thursday flaky lazy" plain "   ⮕ " bold "fair" plain "to remember random passphrase:   centuries to crack"
    echo
    show "A good passphrase requires randomness, and we humans are very bad at that. There's a famous" magenta "xkcd"
    show "comic on this subject (" blue "${webXkcdPasswordsUrl}" plain ") that ends with this:"
    echo
    echo "    \"Through 20 years of effort, we've successfully trained everyone to use passwords that"
    echo "     are hard for humans to remember, but easy for computers to guess.\""
    echo "                                                                           — Randall Munroe"
    echo
    echo "That comic makes another important point in the last cell: creating a mental scene to represent your"
    echo "passphrase is an excellent way to help remember it."
    echo
    show "Please use a" bold green "strong" plain "passphrase, preferably generated. When you enter it below, a srayvn will be shown"
    echo "so you can see the strength of your passphrase."
    echo
}

# Generate a new age key pair with signing keys, encrypting the private key with a passphrase via rage -p.
# Args: keyFile publicKeyFile publicSigningKeyFile [captureVarName]
#
#   keyFile               - path where the passphrase-encrypted private key file will be written
#   publicKeyFile         - path where the plain-text public key will be written
#   publicSigningKeyFile  - path where the plain-text signing public key will be written
#   captureVarName        - optional variable name to receive the passphrase entered during encryption

createAgeKeyPair() {
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
    local index line
    [[ -n "${keyFile}" ]] || invalidArgs "keyFile not provided"
    [[ -n "${publicKeyFile}" ]] || invalidArgs "publicKeyFile not provided"
    [[ -n "${publicSigningKeyFile}" ]] || invalidArgs "publicSigningKeyFile not provided"

    [[ -f ${keyFile} ]] && invalidArgs "${keyFile} should have been deleted!"
    [[ -n "${captureVarName}" ]] && capture=1

    # Generate the age private key (includes public key)

    mapfile -t < <( rage-keygen 2> /dev/null ) agePrivateKey || fail

    # Extract the created line and public key (hopefully future proof)

    index=${ indexOf -r "created: " agePrivateKey; }
    ageCreated="${agePrivateKey[index]}"
    agePrivateKey=("${agePrivateKey[@]:0:index}" "${agePrivateKey[@]:index+1}")

    index=${ indexOf -r "public key: age1" agePrivateKey; }
    agePublicKey="${agePrivateKey[index]}"

    # Generate unencrypted signing keys and load into our signingPrivateKey array

    local signingPublicKey=()
    local signingPrivateKey=()
    local signingPublicKeyFile; signingPublicKeyFile="${ tempDirPath -r; }"
    local signingPrivateKeyFile; signingPrivateKeyFile="${ tempDirPath -r; }"
    minisign -G -p "${signingPublicKeyFile}" -s "${signingPrivateKeyFile}" -W > /dev/null || fail
    mapfile -t < <(cat "${signingPublicKeyFile}") signingPublicKey || fail
    mapfile -t < <(cat "${signingPrivateKeyFile}") signingPrivateKey || fail
    rm "${signingPublicKeyFile}" "${signingPrivateKeyFile}"

    # Construct the combined 'valt' private key

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

    # Configure a pipe to capture the passphrase if requested

    export _rayvnAnonymousPipe
    (( capture )) && _rayvnAnonymousPipe="${ makeTempFile 'XXXXXXXXXXXX'; }"

    # Encrypt the private key

    printf "%s\n" "${valtKey[@]}" | rage -p -a -o "${keyFile}" - || bye

    # Grab and return the passphrase if requested

    if (( capture )) && [[ -s "${_rayvnAnonymousPipe}" ]]; then
        local result
        read -r result < "${_rayvnAnonymousPipe}"
        rm -f "${_rayvnAnonymousPipe}" 2> /dev/null
        printf -v "${captureVarName}" '%s' "${result}"
    fi

    # Write out public key files

    echo "${agePublicKey}" > "${publicKeyFile}"
    printf '%s\n' "${signingPublicKey[@]}" > "${publicSigningKeyFile}"

    # Turn off our pinentry

    disableValtPinEntry
}

# Verify an age key pair by encrypting sample text and decrypting it, then comparing.
# Fails if decryption does not reproduce the original (e.g. wrong passphrase).
# Args: keyFile publicKeyFile
#
#   keyFile       - path to the passphrase-encrypted private key file
#   publicKeyFile - path to the plain-text public key file
verifyAgeKeyPair() {
    local sampleText
    local keyFile="${1}"
    local publicKeyFile="${2}"
    local tempEncryptedFile="${ tempDirPath sample.age; }"
    useValtPinEntry

    setSampleText sampleText
    echo -n "${sampleText}" | rage -R "${publicKeyFile}" -o "${tempEncryptedFile}" || fail
    local decrypted="${ rage -d -i "${keyFile}" "${tempEncryptedFile}" 2> /dev/null; }"
    diff -u <(echo -n "${sampleText}") <(echo "${decrypted}") > /dev/null || fail "not verified (wrong passphrase?)"
    disableValtPinEntry
}

# Convert a binary age-encrypted file to PEM-style ASCII-armored text and store in a nameref variable.
# Fails if the file does not appear to be a valid age-encrypted file.
# Args: ageFile resultVar
#
#   ageFile   - path to the binary age-encrypted file
#   resultVar - nameref variable to receive the armored text
armorAgeFile() {
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

tempSigningKeyFile() {
    assertFile "$1"
    useValtPinEntry

    local encryptedPrivateKeyFile="$1"
    local -n resultFileRef="$2"
    local resultFile; resultFile="${ makeTempFile 'XXXXXXXX'; }"
    local privateKey=()
    local signingKey=()
    local line

    # Decrypt and map private key content (and skip check

    export _skipReadPasswordCheck=1
    mapfile -t < <( rage -d "${encryptedPrivateKeyFile}" 2> >(redStream) ) privateKey || fail
    unset _skipReadPasswordCheck

    # Extract the signing key

    for line in "${privateKey[@]}"; do
        if [[ ${line} == "${signingPrivateKeyPrefix}"* ]]; then
            signingKey+=( "${line:${#signingPrivateKeyPrefix}}" )
        fi
    done

    # Write it to the temp signing file and assign the result

    printf "%s\n" "${signingKey[@]}" > "${resultFile}"
    resultFileRef="${resultFile}"
}

# Populate a nameref variable with a multi-line sample text if not already set.
# Args: resultVar
#
#   resultVar - nameref variable to populate (only written if currently empty)
setSampleText() {
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

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'valt/keygen' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_valt_keygen() {
    require 'rayvn/core' 'valt/pinentry'
    declare -grx ageFileExtension='age'
    declare -grx tarFileExtension='tar.xz'
    declare -grx signingPublicKeyPrefix='# [sign public] '
    declare -grx signingPrivateKeyPrefix='# [sign secret] '
}

