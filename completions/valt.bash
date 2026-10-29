#!/usr/bin/env bash

# Generated bash completion for the valt CLI — DO NOT EDIT.
# Regenerate via 'rayvn args bin/valt'.

__valtComplete() {
    local cur prev words cword
    if declare -F _init_completion > /dev/null 2>&1; then
        _init_completion || return
    else
        cur="${COMP_WORDS[COMP_CWORD]}"
        prev="${COMP_WORDS[COMP_CWORD-1]}"
        words=("${COMP_WORDS[@]}")
        cword="${COMP_CWORD}"
    fi

    if (( cword == 1 )); then
        COMPREPLY=($(compgen -W "keys paper -v --version -h --help" -- "${cur}"))
        return
    fi

    case "${words[1]}" in
        keys)
            [[ "${cur}" == -* ]] && { COMPREPLY=($(compgen -W "--css --force --help --key-info --name --no-advice --no-pdf --no-verify --output-dir --quick --template -c -f -h -k -n -o -q -t" -- "${cur}")); return; }
            case "${prev}" in
                --css|-c) COMPREPLY=($(compgen -f -- "${cur}")); return ;;
                --key-info|-k) COMPREPLY=($(compgen -f -- "${cur}")); return ;;
                --output-dir|-o) COMPREPLY=($(compgen -d -- "${cur}")); return ;;
                --template|-t) COMPREPLY=($(compgen -f -- "${cur}")); return ;;
            esac
            ;;
        paper)
            [[ "${cur}" == -* ]] && { COMPREPLY=($(compgen -W "--css --help --key-info --name --template -c -h -k -n -t" -- "${cur}")); return; }
            case "${prev}" in
                --css|-c) COMPREPLY=($(compgen -f -- "${cur}")); return ;;
                --key-info|-k) COMPREPLY=($(compgen -f -- "${cur}")); return ;;
                --template|-t) COMPREPLY=($(compgen -f -- "${cur}")); return ;;
            esac
            local _relIdx=$(( cword - 2 ))
            (( _relIdx == 0 )) && { COMPREPLY=($(compgen -f -- "${cur}")); return; }
            ;;
    esac
}

complete -F __valtComplete valt
