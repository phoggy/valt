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
    local -n _passwordRef=$1
    local -i _minLength="${2:-24}"
    local -i _maxLength="${3:-32}"
    local -i _extraLength=0
    (( _maxLength > _minLength )) && randomInteger _extraLength $(( _maxLength - _minLength ))
    local -i _passwordLength=$(( _minLength + _extraLength ))
    local _charSet=( a b c d e f g h i j k l m n o p q r s t u v w x y z A B C D E F G H I J K L M N O P Q R S T U V W X Y Z \
                     0 1 2 3 4 5 6 7 8 9 '!' '@' '#' '$' '%' '^' '&' '*' )
    local -i _charSetLen=${#_charSet[@]}
    local -i _i _index
    local _password=''

    for (( _i = 0; _i < ${_passwordLength}; _i++ )); do
        randomInteger _index $(( _charSetLen - 1 ))
        _password+=${_charSet[${_index}]}
    done
    _passwordRef="${_password}"
}

# ◇ Generates a random passphrase using the Orchard Street Long word list (17,576 words) via phraze.
#
# · ARGS
#
#   resultVarName (string)  Name of the variable to receive the passphrase.
#   [wordCount] (int)       Number of words in the passphrase (default: 5).
#   [separator] (string)    String placed between words (default: ' ').

generatePassphrase() {
    local -n _phraseRef=$1
    local -i _wordCount="${2:-5}"
    local _separator="${3:- }"
    local _list='l' # Use Orchard Street Long List (17,576 words)
    local _phrase; _phrase="${ phraze --list "${_list}" --sep "${_separator}" --words "${_wordCount}"; }"
    _phraseRef="${_phrase}"
}

# ◇ Interactively prompts for a password twice and stores the confirmed result in resultVarRef.
#   Fails if the first entry is empty or the two entries do not match. Returns 1 if the strength test (when requested)
#   finds the first entry unsafe, after showing why.
#
# · ARGS
#
#   prompt (string)                                                         Label displayed before the first entry; 'Confirm' is shown, aligned, before the second.
#   resultVarRef (stringRef)                                                Name of the variable to receive the confirmed password.
#   [testUseCase] ('account'|'file')                                        Test the first entry's strength and breach status if provided (default: '').
#   [testThreatLevel] ('casual'|'motivated'|'professional'|'nation-state')  How much guessing power to judge strength against (default: 'professional').
#   [timeout] (int)                                                         Seconds to wait for each entry (default: 30).

readConfirmedPassword() {
    local _p1 _p2
    local _rcpPrompt="$1"
    local -n _resultVarRef="$2"
    local _testUseCase="${3:-}"
    local _testThreatLevel="${4:-}"
    local _timeout="${5:-30}"
    local _confirmPrompt; _confirmPrompt="${ padString "Confirm" ${#_rcpPrompt} before; }"
    readPassword "${_rcpPrompt}" _p1 "${_testUseCase}" "${_testThreatLevel}" "${_timeout}" || return 1
    [[ ${_p1} == '' ]] && fail "cancelled" > ${terminal}
    readPassword "${_confirmPrompt}" _p2 '' '' "${_timeout}" || fail
    [[ ${_p1} == "${_p2}" ]] || fail "entries do not match" > ${terminal}
    _resultVarRef="${_p1}"
}

# ◇ Interactively prompts for a password, storing the result in resultVarRef.
#
# · ARGS
#
#   prompt (string)             Label displayed before the input field.
#   resultVarRef (string)       Name of the variable to receive the entered password.
#   [strengthUseCase] (string)  If provided, estimates password strength and breach status; either 'account'
#                               (online/offline attacks against a service whose password hashing you don't
#                               control) or 'file' (offline attacks against an Age-encrypted file or private
#                               key, at Age's default scrypt work factor).
#   [threatLevel] (string)      Guessing power to judge the strength verdict against: 'casual', 'motivated',
#                               'professional', or 'nation-state' (default: 'professional').
#   [timeout] (int)             Seconds to wait for input (default: 30).
#
# · ENV VARS
#
#   passwordVisibility        Controls input display: 'none' hides input, 'hide' masks it, 'show' reveals it (default: 'none'). [R/W]
#   skipReadPasswordStrength  When set and non-zero, disables strength checking.
#
# · RETURNS
#
#   0  password accepted (with a warning shown if known breaches could not be checked)
#   1  password is unsafe: too weak, or found in a known breach

readPassword() {
    local _result _count=0 _mask _key
    # Not named _prompt: rayvn/prompt assigns that name (unscoped), which would replace ours through dynamic scoping

    local _rpPrompt; _rpPrompt="${ show bold "$1: "; }"
    local -n _resultVarRef="$2"
    local _testUseCase="${3:-}"
    local _testThreatLevel="${4:-}"
    local _timeout="${5:-30}"
    local -i _cancelled=0
    local -i _visible=1
    local -i _show=1
    local _resultCode=0
    _resultVarRef=''
    (( skipReadPasswordStrength )) && _testUseCase=''
    [[ -v passwordVisibility ]] || declare -gx passwordVisibility='none'

    case ${passwordVisibility} in
        none) _visible=0; _show=0; _rpPrompt="$1" ;;
        hide) _show=0 ;;
        show) _show=1 ;;
        *) fail "unknown visibility mode: ${passwordVisibility}"
    esac

    if (( ! _visible )); then
        secureRequest "${_rpPrompt}" _result true < "${terminal}" || return $?
        [[ -z ${_testUseCase} ]] && cursorUpToColumn 1 $(( _promptCol + ${#_promptPlainHint} + 3 ))  # back to the prompt line
    else
        _readPassword
        [[ -n ${_testUseCase} ]] && echo > ${terminal} # end the prompt line, so the report starts below it
    fi
    [[ ${_result} == '' ]] && _cancelled=1

    # Check result if requested and not canceled

    if (( ! _cancelled )) && [[ -n ${_testUseCase} ]]; then
        local -a _strengthReport=()
        local _strengthScore
        passwordStrength _result "${_testUseCase}" "${_testThreatLevel}" _strengthScore _strengthReport; _resultCode=$?
        # Show the summary after the prompt on its line if it fits, otherwise on the next line, indented. Write to the
        # terminal like the prompt itself, never stdout: callers may redirect stdout (e.g. to a key file)

        _showStrengthSummary "${_strengthReport[0]}"
        if (( _resultCode == 1 )); then
            local _line
            for _line in "${_strengthReport[@]:1}"; do
                echo "${_line:+    }${_line}" > ${terminal}
            done
        fi
        (( _resultCode == 2 )) && _resultCode=0 # strong enough; the summary warns that breaches were not checked
    else
        echo > ${terminal} # complete the line
    fi

    # Return the result if not canceled and either unchecked or safe to use

    (( _resultCode == 0 )) && _resultVarRef="${_result}"
    return ${_resultCode}
}

# ◇ Evaluates password strength and breach status, populating a formatted report array: element 0 is a summary, and
#   later elements give more detail.
#
# · ARGS
#
#   passVar (stringRef)        Name of the variable holding the password to check.
#   useCase (string)           'account' (online/offline attacks against a service whose password hashing you don't
#                              control) or 'file' (offline attacks against an Age-encrypted file or private key, at
#                              Age's default scrypt work factor).
#   threatLevel (string)       Guessing power to judge the strength verdict against: 'casual', 'motivated',
#                              'professional', or 'nation-state' (default: 'professional').
#   scoreRef (intRef)          Name of the variable to receive the 0-4 strength score.
#   resultArrayRef (arrayRef)  Name of the array variable to populate with the formatted strength report.
#
# · RETURNS
#
#   0  Password appears safe to use.
#   1  Password is unsafe: present in a known breach, or strength score is below 3.
#   2  Password is strong enough but breach status could not be checked (e.g. offline).

passwordStrength() {

    # Copy the password before declaring any other local, so that the caller's variable is read even if its name is
    # the same as one of ours (e.g. readPassword passes '_result')

    local -n _psPasswordRef="$1"
    local _psPassword="${_psPasswordRef}"
    local _useCase="$2"
    local _threatLevel="${3:-professional}"
    local -n _scoreRef="$4"
    local -n _resultArrayRef="$5"
    local _breached _apiError=0 _breachCount=0 _breachInfo _breachSummary _sourcesInfo
    local _score _scoreDesc _strengthSummary _crackSummary _crackTimes _primaryCount _summary _info
    local _time _actor _detail _primary _json
    local _psResult=0
    local _context="against ${_threatLevel} ${_useCase} attacker"

    [[ ${_useCase} == account || ${_useCase} == file ]] || \
        fail "unknown use case: '${_useCase}' (expected 'account' or 'file')"
    [[ ${_threatLevel} == casual || ${_threatLevel} == motivated || ${_threatLevel} == professional || ${_threatLevel} == nation-state ]] || \
        fail "unknown threat level: '${_threatLevel}' (expected 'casual', 'motivated', 'professional', or 'nation-state')"

    # Check pwned database and summarize

    hasNotBeenPwned _psPassword _apiError _breachCount; _breached=$?
    if (( _breached == 0 )); then
        _breachSummary="${ show success "no known breaches"; }"
    elif (( _breached == 1 )); then
        local apiErrorMessage; apiErrorMessage=${ _curlErrorMessage "${_apiError}"; }
        _breachSummary="${ show warning "unable to check for breaches:" italic "${apiErrorMessage}" ; }"
    elif (( _breached == 2 )); then
        local end=; (( _breachCount > 1 )) && end='es'
        local breachCountText; breachCountText="${ printf "%'d" "${_breachCount}"; }"
        _breachSummary="${ show error "present in ${breachCountText} breach${end}"; }"
    fi
    _breachInfo="${ show "See" blue "https://haveibeenpwned.com/Passwords" "for more on password breaches."; }"
    _sourcesInfo="${ show "See" blue "https://github.com/phoggy/mrld#methodology-and-sources" "for how these estimates are calculated."; }"

    # Check strength and summarize — mrld itself now owns crack-time scenario selection,
    # attacker-type labeling, and collapsing for the given use case (see its --use-case flag
    # and --verbose "report" field), so there's nothing left to do here but ask it and render
    # what it returns.

    _json="${ printf '%s\n' "${_psPassword}" | mrld --verbose --use-case "${_useCase}" --threat-level "${_threatLevel}"; }"
    _score="${ printf '%s' "${_json}" | jq -r '.level'; }"
    _scoreDesc="${ printf '%s' "${_json}" | jq -r '.description'; }"

    local _weak=0
    if (( _score < 3 )); then
        _weak=1
        _strengthSummary="${ show error "${_scoreDesc}" "(" glue error "${_score}/4" glue ")" error "${_context}"; }"
    else
        _strengthSummary="${ show success "${_scoreDesc}" "(" glue success "${_score}/4" glue ")" success "${_context}"; }"
    fi

    # Create final summary

    if (( _breached == 2 )); then
        _summary="⛔ ${ show bold error "Do NOT use:" "${_breachSummary}, ${_strengthSummary}"; }"
        _psResult=1
    elif (( _weak )); then
        _summary="⚠️ ${ show bold warning "Not safe to use:" "${_strengthSummary}, ${_breachSummary}"; }"
        _psResult=1
    elif (( _breached == 1 )); then
        _summary="⚠️ ${_strengthSummary}, but ${_breachSummary}"
        _psResult=2
    else
        _summary="✅ ${_strengthSummary}, ${_breachSummary}"
    fi

    # Build crack times

    _primaryCount=0
    _crackTimes=()
    _crackSummary="Strength score based on the underlined crack time scenario"
    while IFS=$'\t' read -r _time _actor _detail _primary; do
        if [[ ${_primary} == true ]]; then
            (( _primaryCount++ )); (( _primaryCount == 2 )) && _crackSummary+="s"
            _info="${ show bold underline "${_time}" "to crack ${_actor} (" glue italic "${_detail}" glue ")"; }"
        else
            _info="${ show bold "${_time}" "to crack ${_actor} (" glue italic "${_detail}" glue ")"; }"
        fi
        _crackTimes+=("- ${_info}")
    done < <(printf '%s' "${_json}" | jq -r '.report[] | [.time, .actor, .detail, .primary] | @tsv')

    # Finalize results

    _resultArrayRef=("${_summary}" "" "${_crackSummary}:" "" "${_crackTimes[@]}" "" "${_breachInfo}" "${_sourcesInfo}")
    _scoreRef=${_score}
    return ${_psResult}
}


PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'valt/password' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_valt_password() {
    require 'rayvn/prompt' 'valt/pwned'
}

# Show a strength summary on the line of the hidden prompt just entered, after its '[hidden]' hint, if it fits;
# otherwise on the next line, indented. Uses readPassword's _visible and the position rayvn/prompt recorded for the
# hint (_promptCol, _promptPlainHint); on success the prompt leaves the cursor at the start of the next line.

_showStrengthSummary() {
    local summary="$1"
    if (( ! _visible )) && [[ -n ${_promptCol:-} ]]; then
        local rows=0 cols=0
        terminalSize rows cols 2> /dev/null || cols=0
        local visibleSummary; visibleSummary="${ stripAnsi "${summary}"; }"
        local summaryCol=$(( _promptCol + ${#_promptPlainHint} + 3 )) # after the hint and one space
        debug "strength summary: promptCol=${_promptCol} hint=${_promptPlainHint} summaryCol=${summaryCol} cols=${cols} length=${#visibleSummary}"
        if (( cols > 0 && summaryCol + 3 + ${#visibleSummary} <= cols )); then
            cursorUpToColumn 1 ${summaryCol}
            echo "⮕  ${summary}" > ${terminal}
            return 0
        fi
    fi
    echo "    ⮕  ${summary}" > ${terminal}
}

_readPassword() {
    echo -n "${_rpPrompt}" > ${terminal}
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
