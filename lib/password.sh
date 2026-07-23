#!/usr/bin/env bash

# Password/phrase generation.
# Use via: require 'valt/password'

# TODO: don't display strength (via mrld) as it is inaccurate. Just pick a threshold and warn is week if below.

# Generate a random password of random length within the given range.
# Prints the generated password.
# Args: [minLength] [maxLength]
#
#   minLength - minimum password length (default: 24)
#   maxLength - maximum password length (default: 32)
generatePassword() {
    local -i minLength="${1:-24}"
    local -i maxLength="${2:-32}"
    local -i passwordLength=$(( ${minLength} + ( ${RANDOM} % ( ${maxLength} - ${minLength} ) ) ))
    local charSet=( a b c d e f g h i j k l m n o p q r s t u v w x y z A B C D E F G H I J K L M N O P Q R S T U V W X Y Z \
                    0 1 2 3 4 5 6 7 8 9 '!' '@' '#' '$' '%' '^' '&' '*' )
    local -i charSetLen=${#charSet[@]}
    local -i i
    local -i index
    local password=''

    for (( i = 0; i < ${passwordLength}; i++ )); do
        randomInteger index ${charSetLen}
        password+=${charSet[${index}]}
    done
    echo "${password}"
}

# Generate a random passphrase using the Orchard Street Long word list via phraze.
# Prints the generated passphrase.
# Args: [wordCount] [separator]
#
#   wordCount - number of words in the passphrase (default: 5)
#   separator - string placed between words (default: space)
generatePassphrase() {
    local -i wordCount="${1:-5}"
    local separator="${2:- }"
    local list='l' # Use Orchard Street Long List (17,576 words)
    phraze  --list "${list}" --sep "${separator}" --words "${wordCount}"
}

# Interactively prompt for a password twice and verify both entries match.
# Stores the verified password in a nameref variable. Fails if entries do not match.
# Args: resultVarRef [timeout]
#
#   prompt - prompt string, e.g. "Password"
#   resultVarRef - nameref variable to receive the verified password
#   timeout   - seconds to wait for each entry before timing out (default: 30)
readConfirmedPassword() {
    local p1 p2
    local prompt="$1"
    local -n resultVarRef="$2"
    local timeout="${3:-30}"
    local confirmPrompt; confirmPrompt="${ padString "Confirm" ${#prompt} before; }"
    readPassword "${prompt}" p1 "${timeout}" true || fail
    [[ ${p1} == '' ]] && fail "cancelled"  > ${terminal}
    readPassword "${confirmPrompt}" p2 "${timeout}" false || fail
    [[ ${p1} == "${p2}" ]] || fail "entries do not match" > ${terminal}
    resultVarRef="${p1}"
}

# Interactively prompt for a password with optional strength checking and breach detection.
# Stores the entered password in a nameref variable. Visibility controlled by passwordVisibility.
# Args: prompt resultVarRef [timeout] [checkResult]
#
#   prompt      - label displayed before the input field
#   resultVarRef   - nameref variable to receive the entered password
#   timeout     - seconds to wait for input before timing out (default: 30)
#   checkResult - if 'true', check strength and breach status (default: 'true')
readPassword() {
    local result count=0 mask key
    local prompt; prompt="${ show bold "$1: "; }"
    local -n resultVarRef="$2"
    local timeout="${3:-30}"
    local checkResult="${4:-true}"
    local -i cancelled=0
    local -i visible=1
    local -i show=1
    local resultCode=0
    resultVarRef=''
    (( skipReadPasswordCheck )) && checkResult=false
    [[ -v passwordVisibility ]] || declare -gx passwordVisibility='none'

    case ${passwordVisibility} in
        none) visible=0; show=0; prompt="$1" ;;
        hide) show=0 ;;
        show) show=1 ;;
        *) fail "unknown visibility mode: ${passwordVisibility}"
    esac

    if (( ! visible )); then
        secureRequest "${prompt}" result true < "${terminal}" || return $?
        cursorUpToColumn 1 $(( ${#prompt} + 12 ))  # re-position back for check
    else
        _readPassword
    fi
    [[ ${result} == '' ]] && cancelled=1

    # Check result if requested and not canceled

    if (( ! cancelled )) && [[ ${checkResult} == true ]]; then
        local notSafeReasons=() resultScore
        checkPassword result notSafeReasons resultScore; resultCode=$?
debugVar resultScore
        echo -n "  ⮕  ${resultScore}"
        if (( resultCode )); then
            local _i
            show nl nl "This password/passphrase is" error "not safe" "to use:" nl
            for (( _i=0; _i < ${#notSafeReasons[@]}; _i++ )); do
                show "    " blue "-" error "${notSafeReasons[_i]}"
            done
            echo
        fi
    else
        echo > ${terminal} # complete the line
    fi

    # Return the result if not canceled and either unchecked or safe to use

    (( resultCode == 0 )) && resultVarRef="${result}"
    return ${resultCode}
}

checkPassword() {
    local _passVar=$1
    local -n _notSafeReasonsRef=$2
    local _scoreVar=$3
    local -n _scoreRef=$3
    local pwned score apiError=0 breachCount=0 _notSafeReasons=()

    # Check pwned database

    hasNotBeenPwned ${_passVar} apiError breachCount; pwned=$?
    if (( pwned == 1 )); then
        local apiErrorMessage; apiErrorMessage=${ _curlErrorMessage "${apiError}"; }
        _notSafeReasons+=( "${ show error "breach check failed:" warning "${apiErrorMessage}"; }" )
    elif (( pwned == 2 )); then
        local s=; (( breachCount > 1 )) && s='s'
        _notSafeReasons+=( "${ show error "breached ${breachCount} time$s" "(see" blue "https://haveibeenpwned.com/Passwords" glue ")"; }" )
    fi

    # Check strength and return score message if requested

    IFS=',' read -r -a score <<< "${ echo "${result}" | mrld -t; }"
    (( score[1] > 2 )) || _notSafeReasons+=( "${ show error "too weak"; }")
    [[ -n ${_scoreVar} ]] && _scoreRef="${score[0]} (${score[1]}/4), ${score[2]} to crack"
debugVar _passVar _scoreVar _notSafeReasons
    _notSafeReasonsRef=("${_notSafeReasons[@]}")
    return ${#_notSafeReasons[@]}
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'valt/password' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_valt_password() {
    require 'rayvn/prompt' 'valt/pwned'
}

_readPassword() {
    echo -n "${prompt}" > ${terminal}
    while :; do
        (( visible )) && echo -n "${mask}" > ${terminal}
        IFS= read -s -n 1 -t ${timeout} key < ${terminal}

        if (( $? >= 128  )); then                # timeout
            cancelled=true
            break
        elif [[ ${key} =~ [[:print:]] ]]; then   # valid character
            count=$(( count+1 ))
            (( show )) && mask=${key} || mask='*'
            result+=${key}
        elif [[ ${key} == $'\177' ]]; then       # backspace
            if (( ${count} > 0 )); then
                count=$(( count-1 ))
                mask=$'\b \b'
                result="${result%?}"
            else
                mask=''
            fi
        elif [[ ${key} == $'\e' ]] ; then        # ESC
            cancelled=true;
            break
        elif [[ ${key} == '' ]] ; then           # enter
            break
        fi
    done

    # Mask password if we did not do so above

    if (( show )); then
        repeat $'\b' ${count} > ${terminal}
        repeat '*' ${count}  > ${terminal}
    fi
}
