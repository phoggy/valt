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
        COMPREPLY=($(compgen -W "decrypt encrypt keys paper passphrase password pwned archive -v --version -h --help" -- "${cur}"))
        return
    fi

    case "${words[1]}" in
        archive)
            if (( cword == 2 )); then
                COMPREPLY=($(compgen -W "create extract verify" -- "${cur}"))
                return
            fi
            ;;
    esac

    case "${words[1]} ${words[2]:-}" in
        "archive create")
            [[ "${cur}" == -* ]] && { COMPREPLY=($(compgen -W "--force --help --identity --name --no-self --output-dir --recipient --recipient-file --user-text --zone -f -h -i -n -o -r -R -u -z" -- "${cur}")); return; }
            case "${prev}" in
                --identity|-i) COMPREPLY=($(compgen -f -- "${cur}")); return ;;
                --output-dir|-o) COMPREPLY=($(compgen -d -- "${cur}")); return ;;
                --recipient-file|-R) COMPREPLY=($(compgen -f -- "${cur}")); return ;;
            esac
            local _relIdx=$(( cword - 3 ))
            ;;
        "archive extract")
            [[ "${cur}" == -* ]] && { COMPREPLY=($(compgen -W "--help --identity --output-dir -h -i -o" -- "${cur}")); return; }
            case "${prev}" in
                --identity|-i) COMPREPLY=($(compgen -f -- "${cur}")); return ;;
                --output-dir|-o) COMPREPLY=($(compgen -d -- "${cur}")); return ;;
            esac
            local _relIdx=$(( cword - 3 ))
            (( _relIdx == 0 )) && { COMPREPLY=($(compgen -f -- "${cur}")); return; }
            ;;
        "archive verify")
            [[ "${cur}" == -* ]] && { COMPREPLY=($(compgen -W "--help --identity -h -i" -- "${cur}")); return; }
            case "${prev}" in
                --identity|-i) COMPREPLY=($(compgen -f -- "${cur}")); return ;;
            esac
            local _relIdx=$(( cword - 3 ))
            (( _relIdx == 0 )) && { COMPREPLY=($(compgen -f -- "${cur}")); return; }
            ;;
        *)
            case "${words[1]}" in
                decrypt)
                    [[ "${cur}" == -* ]] && { COMPREPLY=($(compgen -W "--force --help --identity --output -f -h -i -o" -- "${cur}")); return; }
                    case "${prev}" in
                        --identity|-i) COMPREPLY=($(compgen -f -- "${cur}")); return ;;
                    esac
                    local _relIdx=$(( cword - 2 ))
                    (( _relIdx == 0 )) && { COMPREPLY=($(compgen -f -- "${cur}")); return; }
                    ;;
                encrypt)
                    [[ "${cur}" == -* ]] && { COMPREPLY=($(compgen -W "--armor --delete --force --help --identity --no-self --no-sign --output --recipient --recipient-file --verify -a -f -h -i -o -r -R" -- "${cur}")); return; }
                    case "${prev}" in
                        --identity|-i) COMPREPLY=($(compgen -f -- "${cur}")); return ;;
                        --recipient-file|-R) COMPREPLY=($(compgen -f -- "${cur}")); return ;;
                    esac
                    local _relIdx=$(( cword - 2 ))
                    ;;
                keys)
                    [[ "${cur}" == -* ]] && { COMPREPLY=($(compgen -W "--allow-weak-passphrase --css --force --help --key-info --name --no-advice --no-pdf --no-verify --output-dir --quick --template -c -f -h -k -n -o -q -t" -- "${cur}")); return; }
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
                passphrase)
                    [[ "${cur}" == -* ]] && { COMPREPLY=($(compgen -W "--check --count --help --separator --threat-level --use-case --words -c -h -n -s -t -u -w" -- "${cur}")); return; }
                    case "${prev}" in
                        --threat-level|-t) COMPREPLY=($(compgen -W "casual motivated professional nation-state" -- "${cur}")); return ;;
                        --use-case|-u) COMPREPLY=($(compgen -W "file account" -- "${cur}")); return ;;
                    esac
                    ;;
                password)
                    [[ "${cur}" == -* ]] && { COMPREPLY=($(compgen -W "--check --count --help --max --min --threat-level --use-case -c -h -n -t -u" -- "${cur}")); return; }
                    case "${prev}" in
                        --threat-level|-t) COMPREPLY=($(compgen -W "casual motivated professional nation-state" -- "${cur}")); return ;;
                        --use-case|-u) COMPREPLY=($(compgen -W "account file" -- "${cur}")); return ;;
                    esac
                    ;;
                pwned)
                    [[ "${cur}" == -* ]] && { COMPREPLY=($(compgen -W "--help -h" -- "${cur}")); return; }
                    ;;
            esac
            ;;
    esac
}

complete -F __valtComplete valt
