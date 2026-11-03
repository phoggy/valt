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
        COMPREPLY=($(compgen -W "decrypt default-key encrypt key-info keys paper pass-check passphrase password public-key verify archive -v --version -h --help" -- "${cur}"))
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
            [[ "${cur}" == -* ]] && { COMPREPLY=($(compgen -W "--force --help --identity --name --no-mac-metadata --no-self --output-dir --recipient --recipient-file --user-text --zone -f -h -i -n -o -r -R -u -z" -- "${cur}")); return; }
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
                default-key)
                    [[ "${cur}" == -* ]] && { COMPREPLY=($(compgen -W "--clear --help -h" -- "${cur}")); return; }
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
                key-info)
                    [[ "${cur}" == -* ]] && { COMPREPLY=($(compgen -W "--downloads --help --key-info -d -h -k" -- "${cur}")); return; }
                    case "${prev}" in
                        --downloads|-d) COMPREPLY=($(compgen -d -- "${cur}")); return ;;
                    esac
                    ;;
                keys)
                    [[ "${cur}" == -* ]] && { COMPREPLY=($(compgen -W "--allow-weak-passphrase --default --force --help --key-info --name --no-advice --no-default --no-pdf --no-verify --output-dir --quick --style --template -c -d -f -h -k -n -o -q -t" -- "${cur}")); return; }
                    case "${prev}" in
                        --key-info|-k) COMPREPLY=($(compgen -f -- "${cur}")); return ;;
                        --output-dir|-o) COMPREPLY=($(compgen -d -- "${cur}")); return ;;
                        --style|-c) COMPREPLY=($(compgen -f -- "${cur}")); return ;;
                        --template|-t) COMPREPLY=($(compgen -f -- "${cur}")); return ;;
                    esac
                    ;;
                paper)
                    [[ "${cur}" == -* ]] && { COMPREPLY=($(compgen -W "--help --key-info --name --style --template -c -h -k -n -t" -- "${cur}")); return; }
                    case "${prev}" in
                        --key-info|-k) COMPREPLY=($(compgen -f -- "${cur}")); return ;;
                        --style|-c) COMPREPLY=($(compgen -f -- "${cur}")); return ;;
                        --template|-t) COMPREPLY=($(compgen -f -- "${cur}")); return ;;
                    esac
                    local _relIdx=$(( cword - 2 ))
                    (( _relIdx == 0 )) && { COMPREPLY=($(compgen -f -- "${cur}")); return; }
                    ;;
                pass-check)
                    [[ "${cur}" == -* ]] && { COMPREPLY=($(compgen -W "--breach-only --help --threat-level --use-case -b -h -t -u" -- "${cur}")); return; }
                    case "${prev}" in
                        --threat-level|-t) COMPREPLY=($(compgen -W "casual motivated professional nation-state" -- "${cur}")); return ;;
                        --use-case|-u) COMPREPLY=($(compgen -W "account file" -- "${cur}")); return ;;
                    esac
                    ;;
                passphrase)
                    [[ "${cur}" == -* ]] && { COMPREPLY=($(compgen -W "--count --help --separator --words -h -n -s -w" -- "${cur}")); return; }
                    ;;
                password)
                    [[ "${cur}" == -* ]] && { COMPREPLY=($(compgen -W "--count --help --max --min -h -n" -- "${cur}")); return; }
                    ;;
                public-key)
                    [[ "${cur}" == -* ]] && { COMPREPLY=($(compgen -W "--force --help --output -f -h -o" -- "${cur}")); return; }
                    local _relIdx=$(( cword - 2 ))
                    (( _relIdx == 0 )) && { COMPREPLY=($(compgen -f -- "${cur}")); return; }
                    ;;
                verify)
                    [[ "${cur}" == -* ]] && { COMPREPLY=($(compgen -W "--help --identity -h -i" -- "${cur}")); return; }
                    case "${prev}" in
                        --identity|-i) COMPREPLY=($(compgen -f -- "${cur}")); return ;;
                    esac
                    local _relIdx=$(( cword - 2 ))
                    ;;
            esac
            ;;
    esac
}

complete -F __valtComplete valt
