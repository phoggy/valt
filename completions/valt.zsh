#compdef valt

# Generated zsh completion for the valt CLI — DO NOT EDIT.
# Regenerate via 'rayvn args bin/valt'.

_valt() {
    local curcontext="$curcontext" state line
    typeset -A opt_args

    _arguments -C \
        '1: :->command' \
        '*::arg:->args'

    case $state in
        command)
            local -a commands=(
                'decrypt:Decrypt an encrypted file, or verify and extract a secure archive (.valt). You will be prompted'
                'keys:Generate an age key pair, with the private key encrypted by a passphrase, plus a PDF paper key as backup'
                'paper:Generate the paper key PDF for an existing key pair, personalized from the key.info file. The PDF is written'
            )
            _describe 'command' commands
            ;;
        args)
            case $words[1] in
                decrypt)
                    _arguments \
                    '(--force -f)'{--force,-f}'[Overwrite an existing output file.]' \
                    '(--help -h)'{--help,-h}'[Print this help message.]' \
                    '(--identity -i)'{--identity,-i}'[The private key file (default: valt.key in the valt config directory).]:identity:_files' \
                    '(--output -o)'{--output,-o}'[For a file, the output file ('\''-'\'' for standard output; default: FILE without .age). For an archive, the existing directory to extract into (default: the current directory).]:output:' \
                    '1:FILE:_files'
                    ;;
                keys)
                    _arguments \
                    '(--css -c)'{--css,-c}'[CSS file with style overrides to apply for PDF generation.]:css:_files' \
                    '(--force -f)'{--force,-f}'[Overwrite existing key files.]' \
                    '(--help -h)'{--help,-h}'[Print this help message.]' \
                    '(--key-info -k)'{--key-info,-k}'[Key info file to use instead of the default for PDF generation.]:key-info:_files' \
                    '(--name -n)'{--name,-n}'[Name to use for key files, e.g. bob -> bob.pub, bob.key.]:name:' \
                    '(--no-advice)'--no-advice'[Do not show passphrase advice.]' \
                    '(--no-pdf)'--no-pdf'[Do not generate the paper key PDF.]' \
                    '(--no-verify)'--no-verify'[Do not verify keys.]' \
                    '(--output-dir -o)'{--output-dir,-o}'[Directory for the key files (default: the valt config directory).]:output-dir:_files -/' \
                    '(--quick -q)'{--quick,-q}'[Same as --no-advice --no-verify.]' \
                    '(--template -t)'{--template,-t}'[HTML template file to use instead of the default for PDF generation.]:template:_files'
                    ;;
                paper)
                    _arguments \
                    '(--css -c)'{--css,-c}'[CSS file with style overrides to apply.]:css:_files' \
                    '(--help -h)'{--help,-h}'[Print this help message.]' \
                    '(--key-info -k)'{--key-info,-k}'[Key info file to use instead of the default.]:key-info:_files' \
                    '(--name -n)'{--name,-n}'[Use the NAME.key file in the valt config directory, e.g. bob -> bob.key.]:name:' \
                    '(--template -t)'{--template,-t}'[HTML template file to use instead of the default.]:template:_files' \
                    '1:KEY_FILE:_files'
                    ;;
            esac
            ;;
    esac
}

(( $+functions[compdef] )) && compdef _valt valt
