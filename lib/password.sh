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
#   prompt (string)                              Prompt label displayed before each entry.
#   resultVarRef (string)                        Name of the variable to receive the verified password.
#   [testUseCase] ('account'|'file')              Test password strength and breach status if provided (default: '').
#   [testThreatLevel] ('casual'|'motivated'|      How much guessing power to judge strength against (default: 'determined').
#                      'determined'|'state-level')
#   [timeout] (int)                               Seconds to wait for each entry (default: 30).

readConfirmedPassword() {
    local _p1 _p2
    local _prompt="$1"
    local -n _resultVarRef="$2"
    local _testUseCase="${3:-}"
    local _testThreatLevel="${4:-}"
    local _timeout="${5:-30}"
    local _confirmPrompt; _confirmPrompt="${ padString "Confirm" ${#_prompt} before; }"
    readPassword "${_prompt}" _p1 "${_testUseCase}" "${_testThreatLevel}" "${_timeout}" || fail
    [[ ${_p1} == '' ]] && fail "cancelled" > ${terminal}
    readPassword "${_confirmPrompt}" _p2 '' '' "${_timeout}" || fail
    [[ ${_p1} == "${_p2}" ]] || fail "entries do not match" > ${terminal}
    _resultVarRef="${_p1}"
}

# ◇ Interactively prompts for a password, storing the result in resultVarRef.
#
# · ARGS
#
#   prompt (string)                              Label displayed before the input field.
#   resultVarRef (string)                        Name of the variable to receive the entered password.
#   [testUseCase] ('account'|'file')              Test password strength and breach status if provided (default: '').
#   [testThreatLevel] ('casual'|'motivated'|      How much guessing power to judge strength against (default: 'determined').
#                      'determined'|'state-level')
#   [timeout] (int)                               Seconds to wait for input (default: 30).
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
    local _result _count=0 _mask _key
    local _prompt; _prompt="${ show bold "$1: "; }"
    local -n _resultVarRef="$2"
    local _testUseCase="${3:-}"
    local _testThreatLevel="${4:-}"
    local _timeout="${5:-30}"
    local -i _cancelled=0
    local -i _visible=1
    local -i _show=1
    local _resultCode=0
    _resultVarRef=''
    (( skipReadPasswordCheck )) && _testUseCase=''
    [[ -v passwordVisibility ]] || declare -gx passwordVisibility='none'

    case ${passwordVisibility} in
        none) _visible=0; _show=0; _prompt="$1" ;;
        hide) _show=0 ;;
        show) _show=1 ;;
        *) fail "unknown visibility mode: ${passwordVisibility}"
    esac

    if (( ! _visible )); then
        secureRequest "${_prompt}" _result true < "${terminal}" || return $?
        cursorUpToColumn 1 $(( ${#_prompt} + 12 ))  # re-position back for check
    else
        _readPassword
    fi
    [[ ${_result} == '' ]] && _cancelled=1

    # Check result if requested and not canceled

    if (( ! _cancelled )) && [[ -n ${_testUseCase} ]]; then
        local -a _strengthReport=()
        local _strengthScore
        passwordStrength _result "${_testUseCase}" "${_testThreatLevel}" _strengthScore _strengthReport; _resultCode=$?
        echo -n "  ⮕  ${_strengthReport[0]}"
        if (( _resultCode )); then
            show nl nl "${_strengthReport[1]}" nl
        else
            echo > ${terminal} # complete the line
        fi
    else
        echo > ${terminal} # complete the line
    fi

    # Return the result if not canceled and either unchecked or safe to use

    (( _resultCode == 0 )) && _resultVarRef="${_result}"
    return ${_resultCode}
}

# ◇ Returns a formatted password strength report as an array of description strings. Element 0 is a summary, 1 is a pointer to
#   HaveIBeenPwned for more information on breaches. If safe to use, additional elements each describe one crack-time scenario.
#
# · ARGS
#
#   passVar (string)           Name of the variable holding the password to check.
#   useCase (string)           Either 'account' (online/offline attacks against a service whose password hashing you don't
#                              control) or 'file' (offline attacks against an Age-encrypted file or private key, at Age's default
#                              scrypt work factor).
#   threatLevel (string)       How much guessing power to judge the strength verdict against: 'casual', 'motivated',
#                              'determined', or 'state-level'. Empty defaults to mrld's own default ('determined').
#   strengthRef (intRef)       Name of the variable to return the 0-4 strength value.
#   resultArrayRef (arrayRef)  Name of an array variable to populate with the formatted strength report.
#
# · RETURNS
#
#   0  password appears safe to use.
#   1  password is unsafe to use: HaveIBeenPwned check failed or strength < 3.

passwordStrength() {
    local _passVar="$1"
    local _useCase="$2"
    local _threatLevel="${3:-determined}"
    local -n _scoreRef="$4"
    local -n _resultArrayRef="$5"
    local _breached _apiError=0 _breachCount=0 _breachInfo _breachSummary
    local _score _scoreDesc _strengthSummary _summary _info
    local _time _actor _detail _primary _json
    local _unsafe=0
    local _prefix="${_useCase}/${_threatLevel}: "

    [[ ${_useCase} == account || ${_useCase} == file ]] || \
        fail "unknown use case: '${_useCase}' (expected 'account' or 'file')"
    [[ ${_threatLevel} == casual || ${_threatLevel} == motivated || ${_threatLevel} == determined || ${_threatLevel} == state-level ]] || \
        fail "unknown threat level: '${_threatLevel}' (expected 'casual', 'motivated', 'determined', or 'state-level')"

    # Check pwned database and summarize

    hasNotBeenPwned ${_passVar} _apiError _breachCount; _breached=$?
    if (( _breached == 0 )); then
        _breachSummary="${ show success "no known breaches"; }"
    elif (( _breached == 1 )); then
        local apiErrorMessage; apiErrorMessage=${ _curlErrorMessage "${_apiError}"; }
        _breachSummary="${ show warning "unable to check for breaches:" italic "${apiErrorMessage}" ; }"
        _unsafe=1
    elif (( _breached == 2 )); then
        local end=; (( _breachCount > 1 )) && end='es'
        _breachSummary="${ show error "present in ${_breachCount} breach${end}"; }"
        _unsafe=1
    fi
    _breachInfo="${ show "See" blue "https://haveibeenpwned.com/Passwords" "for breach information."; }"

    # Check strength and summarize — mrld itself now owns crack-time scenario selection,
    # attacker-type labeling, and collapsing for the given use case (see its --use-case flag
    # and --verbose "report" field), so there's nothing left to do here but ask it and render
    # what it returns.

    local -n _passRef="${_passVar}"
    _json="${ printf '%s\n' "${_passRef}" | mrld --verbose --use-case "${_useCase}" --threat-level "${_threatLevel}"; }"
    _score="${ printf '%s' "${_json}" | jq -r '.level'; }"
    _scoreDesc="${ printf '%s' "${_json}" | jq -r '.description'; }"

    if (( _score < 3 )); then
        _strengthSummary="${ show error "${_scoreDesc}" "(" glue error "${_score}/4" glue ")"; }"
        _unsafe=1
    elif (( _unsafe )); then
        _strengthSummary=""
    else
        _strengthSummary="${ show success "${_scoreDesc}" "(" glue success "${_score}/4" glue ")"; }"
    fi

    # Create final summary

    if (( _unsafe )); then
        if (( _breached )); then
            _summary="⛔ ${_prefix}${ show bold error "Do NOT use:" "${_breachSummary}, ${_strengthSummary}"; }"
        else
            _summary="⚠️ ${_prefix}${ show bold warning "Not safe to use:" "${_strengthSummary}, ${_breachSummary}"; }"
        fi
    else
        _summary="✅ ${_prefix}${_strengthSummary}, ${_breachSummary}"
    fi

    # Build result array

    _resultArrayRef=("${_summary}" "${_breachInfo}" )
    if (( ! _unsafe )); then
        while IFS=$'\t' read -r _time _actor _detail _primary; do
            if [[ ${_primary} == true ]]; then
                _info="${ show bold underline "${_time}" "to crack ${_actor} (" glue italic "${_detail}" glue ")"; }"
            else
                _info="${ show bold "${_time}" "to crack ${_actor} (" glue italic "${_detail}" glue ")"; }"
            fi
            _resultArrayRef+=("${_info}")
        done < <(printf '%s' "${_json}" | jq -r '.report[] | [.time, .actor, .detail, .primary] | @tsv')
    fi

    _scoreRef=${_score}
    return ${_unsafe}
}


PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'valt/password' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_valt_password() {
    require 'rayvn/prompt' 'valt/pwned'
}

_readPassword() {
    echo -n "${_prompt}" > ${terminal}
    while :; do
        (( _visible )) && echo -n "${_mask}" > ${terminal}
        IFS= read -s -n 1 -t ${_timeout} _key < ${terminal}

        if (( $? >= 128  )); then                # timeout
            _cancelled=true
            break
        elif [[ ${_key} =~ [[:print:]] ]]; then  # valid character
            _count=$(( _count+1 ))
            (( _show )) && _mask=${_key} || _mask='*'
            _result+=${_key}
        elif [[ ${_key} == $'\177' ]]; then      # backspace
            if (( ${_count} > 0 )); then
                _count=$(( _count-1 ))
                _mask=$'\b \b'
                _result="${_result%?}"
            else
                _mask=''
            fi
        elif [[ ${_key} == $'\e' ]] ; then       # ESC
            _cancelled=true;
            break
        elif [[ ${_key} == '' ]] ; then          # enter
            break
        fi
    done

    # Mask password if we did not do so above

    if (( _show )); then
        repeat $'\b' ${_count} > ${terminal}
        repeat '*' ${_count}  > ${terminal}
    fi
}
