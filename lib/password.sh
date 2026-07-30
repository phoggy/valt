#!/usr/bin/env bash

# Password/phrase generation.
# Use via: require 'valt/password'

# ◇ Generates a random password of random length within a given range.
#
# · ARGS
#
#   resultVarName (string)  Name of the variable to receive the password.
#   [minLength] (int)       Minimum password length (default: 24).
#   [maxLength] (int)       Maximum password length (default: 32).

generatePassword() {
    local -n resultVarRef=$1
    local -i minLength="${2:-24}"
    local -i maxLength="${3:-32}"
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
    resultVarRef="${password}"
}

# ◇ Generates a random passphrase using the Orchard Street Long word list (17,576 words) via phraze.
#
# · ARGS
#
#   resultVarName (string)  Name of the variable to receive the passphrase.
#   [wordCount] (int)       Number of words in the passphrase (default: 5).
#   [separator] (string)    String placed between words (default: ' ').

generatePassphrase() {
    local -n resultVarRef=$1
    local -i wordCount="${2:-5}"
    local separator="${3:- }"
    local list='l' # Use Orchard Street Long List (17,576 words)
    local phrase; phrase="${ phraze  --list "${list}" --sep "${separator}" --words "${wordCount}"; }"
    resultVarRef="${phrase}"
}

# ◇ Interactively prompts for a password twice and stores the verified result in resultVarRef.
#   Fails if the entries do not match or the first entry is empty.
#
# · ARGS
#
#   prompt (string)        Prompt label displayed before each entry.
#   resultVarRef (string)  Name of the variable to receive the verified password.
#   [timeout] (int)        Seconds to wait for each entry (default: 30).

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

# ◇ Interactively prompts for a password, storing the result in resultVarRef.
#
# · ARGS
#
#   prompt (string)         Label displayed before the input field.
#   resultVarRef (string)   Name of the variable to receive the entered password.
#   [timeout] (int)         Seconds to wait for input (default: 30).
#   [checkResult] (bool)    Check password strength and breach status (default: 'true').
#
# · ENV VARS
#
#   passwordVisibility     Controls input display: 'none' hides input, 'hide' masks it,
#                          'show' reveals it (default: 'none').
#   skipReadPasswordCheck  When set and non-zero, disables strength checking.
#
# · RETURNS
#
#   0  password accepted
#   1  password is unsafe or strength check failed

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
        echo -n "  ⮕  ${resultScore}"
        if (( resultCode )); then
            local _i
            show nl nl "This password/passphrase is" error "not safe" "to use:" nl
            for (( _i=0; _i < ${#notSafeReasons[@]}; _i++ )); do
                show "    " blue "-" error "${notSafeReasons[_i]}"
            done
            echo
        else
            echo > ${terminal} # complete the line
        fi
    else
        echo > ${terminal} # complete the line
    fi

    # Return the result if not canceled and either unchecked or safe to use

    (( resultCode == 0 )) && resultVarRef="${result}"
    return ${resultCode}
}

# ◇ Checks a password against the HaveIBeenPwned breach database and evaluates its strength.
#
# · ARGS
#
#   passVar (string)              Name of the variable holding the password to check.
#   notSafeReasonsRef (arrayRef)  Array populated with formatted failure reason messages.
#   scoreVar (string)             Name of the variable to receive the formatted strength score,
#                                 or empty to skip score output.
#
# · RETURNS
#
#   0  password passed all checks
#   N  number of reasons the password is not safe (breach and/or strength failures)

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
    [[ -n ${_scoreVar} ]] && _scoreRef="${ show "${score[0]} (${score[1]}/4), ${score[2]} to crack (" glue italic "determined attacker" glue ")"; }"
    _notSafeReasonsRef=("${_notSafeReasons[@]}")
    return ${#_notSafeReasons[@]}
}

# ◇ Returns a formatted password strength report as an array of description strings.
#   Element 0 is the overall level/description (e.g. "weak (2/4)"); each subsequent element describes one crack-time
#   scenario as "<characterization>, <type>: <time> to crack".
#
# · ARGS
#
#   passVar (string)           Name of the variable holding the password to check.
#   useCase (string)           Either 'account' (online/offline attacks against a service whose password hashing you don't
#                              control) or 'age' (offline attacks against an Age-encrypted file or private key, at Age's default
#                              scrypt work factor).
#   strengthRef (intRef)       Name of the variable to return the 0-4 strength value.
#   resultArrayRef (arrayRef)  Name of an array variable to populate with the formatted strength report.

passwordStrength() {
    local _passVar="$1"
    local _useCase="$2"
    local -n _scoreRef="$3"
    local -n _resultArrayRef="$4"
    local -A _scores
    local _score _scoreDesc _key _keys _age color

    local -A _crackType=(
        [100-per-hour]="throttled online attack"
        [10-per-second]="unthrottled online attack"
        [10k-per-second]="offline attack, slow hash, many cores"
        [10B-per-second]="offline attack, fast hash, many cores"
        [age-scrypt-1-core]="offline attack, scrypt hash, single core"
        [age-scrypt-32-cores]="offline attack, scrypt hash, 32 cores"
        [age-scrypt-128-cores]="offline attack, scrypt hash, 128 cores"
        [age-scrypt-1024-cores]="offline attack, scrypt hash, 1024 cores")

    local -A _characterization=(
        [100-per-hour]="casual attacker"
        [10-per-second]="motivated attacker"
        [10k-per-second]="determined attacker"
        [10B-per-second]="state-level attacker"
        [age-scrypt-1-core]="casual attacker"
        [age-scrypt-32-cores]="motivated attacker"
        [age-scrypt-128-cores]="determined attacker"
        [age-scrypt-1024-cores]="state-level attacker")

    case "${_useCase}" in
        account)
            _age=false
            _keys=(100-per-hour 10-per-second 10k-per-second 10B-per-second)
            ;;
        age)
            _age=true
            _keys=(age-scrypt-1-core age-scrypt-32-cores age-scrypt-128-cores age-scrypt-1024-cores)
            ;;
        *) fail "unknown use case: '${_useCase}' (expected 'account' or 'age')" ;;
    esac

    _passwordScore "${_passVar}" _score _scoreDesc _scores "${_age}"

    _scoreRef=${_score}
    (( _score < 3 )) && color="error" || color="success"
    _resultArrayRef=( "${ show ${color} "${_scoreDesc} (${_score}/4)"; }")
    local desc
    for _key in "${_keys[@]}"; do
        desc="${ show bold "${_scores[${_key}]}" "to crack for ${_characterization[${_key}]} (" glue italic "${_crackType[${_key}]}" glue ")"; }"
        _resultArrayRef+=("${desc}")
    done
}


PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'valt/password' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_valt_password() {
    require 'rayvn/prompt' 'valt/pwned'
}

_passwordScore() {
    local -n _passRef="$1"
    local -n _scoreRef="$2"
    local -n _scoreDescRef="$3"
    local -n _resultMapRef="$4"
    local _age="${5:-false}"
    local key value mrldArgs=(--verbose)
    [[ ${_age} == true ]] && mrldArgs+=(--age)

    local json; json="${ printf '%s\n' "${_passRef}" | mrld "${mrldArgs[@]}"; }"

    _scoreRef="${ printf '%s' "${json}" | jq -r '.level'; }"
    _scoreDescRef="${ printf '%s' "${json}" | jq -r '.description'; }"

    while IFS='=' read -r key value; do
        _resultMapRef["${key//_/-}"]="${value}"
    done < <(printf '%s' "${json}" | jq -r '.crack_times | to_entries[] | "\(.key)=\(.value)"')
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
