#!/usr/bin/env bash

# Library supporting password/phrase generation
# Intended for use via: require 'valt/passwords'

# TODO: don't display strength (via mrld) as it is inaccurate. Just pick a threshold and warn is week if below.

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
        _randomIndex ${charSetLen} index
        password+=${charSet[${index}]}
    done
    echo "${password}"
}

generatePassphrase() {
    local -i wordCount="${1:-5}"
    local separator="${2:- }"
    local list='l' # Use Orchard Street Long List (17,576 words)
    phraze  --list "${list}" --sep "${separator}" --words "${wordCount}"
}

readVerifiedPassword() {
    local p1 p2
    local -n resultVar="${1}"
    local timeout="${2:-30}"
    readPassword "Password" p1 "${timeout}" true || fail
    [[ ${p1} == '' ]] && fail "cancelled"  > ${terminal}
    readPassword "  Verify" p2 "${timeout}" false || fail
    [[ ${p1} == "${p2}" ]] || fail "entries do not match" > ${terminal}
    resultVar="${p1}"
}

readPassword() {
    local result count=0 mask key
    local prompt="${ show cyan "${1}: " ;}"
    local -n resultVar="${2}"
    local timeout="${3:-30}"
    local checkResult="${4:-true}"
    local -i cancelled=0
    local -i visible=1
    local -i show=1
    local -i pwned=
    local score=
    resultVar=''

    case ${passwordVisibility} in
        none) visible=0; show=0; prompt="${ show cyan "${1}" plain dim "[hidden]" ;} " ;;
        hide) show=0 ;;
        show) show=1 ;;
        *) fail "unknown visibility mode: ${passwordVisibility}"
    esac

    # Prompt

    echo -n "${prompt}" > ${terminal}

    if (( ! visible )); then
        read -t ${timeout} -rs result < ${terminal}  # TODO: use rayvn/prompt after adding support for hidden input??
    else

        # Process one character at a time

        while :; do
            (( visible )) && echo -n "${mask}" > ${terminal}
            IFS= read -s -n 1 -t ${timeout} key < ${terminal}

            if (( $? >= 128  )); then                # timeout
                cancelled=true
                break
            elif [[ ${key} =~ [[:print:]] ]]; then   # valid character
                count=$((count+1))
                (( show )) && mask=${key} || mask='*'
                result+=${key}
            elif [[ ${key} == $'\177' ]]; then       # backspace
                if (( ${count} > 0 )); then
                    count=$((count-1))
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
    fi

    [[ ${result} == '' ]] && cancelled=1

    if (( ! cancelled )); then

        # Check result if requested

        if (( checkResult )); then
            IFS=',' read -r -a score <<< "$(echo "${result}" | mrld -t)"
            echo -n "  ⮕  ${score[0]} (${score[1]}/4), ${score[2]} to crack" > ${terminal}
            hasNotBeenPwned "${result}"; pwned=${?}
        fi
    fi
    echo > ${terminal} # complete the line

    # Return the result if not cancelled and not pwned

    if (( ! cancelled )); then
        if (( pwned == 1 )); then
            warn "Could not check if this password/phrase has been breached!" > ${terminal}
            if [[ ${expertMode} ]]; then
                resultVar="${result}"
            fi
        elif (( pwned == 2 )); then
            error "This password/phrase is present in a large set of breached passwords so is not safe to use!" > ${terminal}
        else
            resultVar="${result}"
        fi
    fi
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'valt/password' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_valt_password() {
    require 'rayvn/core' 'valt/pwned'
}

_randomIndex() {
    local -i maxIndex="${1}"
    local -n resultInt=${2}
    local -i randomInt

    if [[ ! ${checkedDevUrandom} ]]; then
        declare -grx hasDevUrandom=$(ls /dev/urandom > /dev/null && echo -n 'true' || echo -n '')
        declare -grx checkedDevUrandom='true'
        if [[ ! ${hasDevUrandom} ]]; then
            warn "generated passwords/phrases *may* not be random enough: use ${webPasswordGenUrl}"
        fi
    fi
    if [[ ${hasDevUrandom} ]]; then
        randomInt=$(head -c4 /dev/urandom | od -An -tu4)
    else
        randomInt=${SRANDOM}
    fi
    resultInt=$(( ${randomInt} % ${maxIndex} ))
}
