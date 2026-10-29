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
                'encrypt:Encrypt a single file to FILE.age and sign it with your private key (FILE.age.minisig). Your own'
                'keys:Generate an age key pair, with the private key encrypted by a passphrase, plus a PDF paper key as backup'
                'paper:Generate the paper key PDF for an existing key pair, personalized from the key.info file. The PDF is written'
                'archive:'
            )
            _describe 'command' commands
            ;;
        args)
            case $words[1] in
                archive)
                    _arguments -C \
                        '1: :->subcommand' \
                        '*::arg:->args'
                    case $state in
                        subcommand)
                            local -a subcommands=(
                                'create:Create a signed, encrypted secure archive (.valt) from files and directories.'
                                'extract:Verify and extract a secure archive (.valt). Same as '\''valt decrypt ARCHIVE'\''.'
                                'verify:Verify both signatures of a secure archive (.valt) without extracting it.'
                            )
                            _describe 'subcommand' subcommands
                            ;;
                        args)
                            case $words[1] in
                                create)
                                    _arguments \
                                    '(--force -f)'{--force,-f}'[Overwrite an existing archive.]' \
                                    '(--help -h)'{--help,-h}'[Print this help message.]' \
                                    '(--identity -i)'{--identity,-i}'[Your private key file, used to sign and to find your public key (the .pub file next to it); default: valt.key in the valt config directory.]:identity:_files' \
                                    '(--name -n)'{--name,-n}'[The archive file name prefix (default: your user name).]:name:' \
                                    '(--no-self)'--no-self'[Do not include your own public key as a recipient.]' \
                                    '(--output-dir -o)'{--output-dir,-o}'[The directory to write the archive to (default: the current directory).]:output-dir:_files -/' \
                                    '*'{--recipient,-r}'[Also encrypt to this recipient (an age public key). Can be repeated.]:recipient:' \
                                    '*'{--recipient-file,-R}'[Also encrypt to the recipient(s) in this file, e.g. a valt .pub file. Can be repeated.]:recipient-file:_files' \
                                    '(--user-text -u)'{--user-text,-u}'[Text to include in the archive'\''s README. Can contain '\''\\n'\''.]:user-text:' \
                                    '(--zone -z)'{--zone,-z}'[The timezone for the timestamp in the archive name, e.g. PDT (default: UTC).]:zone:' \
                                    '*:INPUT...:'
                                    ;;
                                extract)
                                    _arguments \
                                    '(--help -h)'{--help,-h}'[Print this help message.]' \
                                    '(--identity -i)'{--identity,-i}'[Your private key file (default: valt.key in the valt config directory).]:identity:_files' \
                                    '(--output-dir -o)'{--output-dir,-o}'[The existing directory to extract into (default: the current directory).]:output-dir:_files -/' \
                                    '1:ARCHIVE:_files'
                                    ;;
                                verify)
                                    _arguments \
                                    '(--help -h)'{--help,-h}'[Print this help message.]' \
                                    '(--identity -i)'{--identity,-i}'[Your private key file (default: valt.key in the valt config directory).]:identity:_files' \
                                    '1:ARCHIVE:_files'
                                    ;;
                            esac
                            ;;
                    esac
                    ;;
                decrypt)
                    _arguments \
                    '(--force -f)'{--force,-f}'[Overwrite an existing output file.]' \
                    '(--help -h)'{--help,-h}'[Print this help message.]' \
                    '(--identity -i)'{--identity,-i}'[The private key file (default: valt.key in the valt config directory).]:identity:_files' \
                    '(--output -o)'{--output,-o}'[For a file, the output file ('\''-'\'' for standard output; default: FILE without .age). For an archive, the existing directory to extract into (default: the current directory).]:output:' \
                    '1:FILE:_files'
                    ;;
                encrypt)
                    _arguments \
                    '(--armor -a)'{--armor,-a}'[Write PEM encoded (text) output.]' \
                    '(--delete)'--delete'[Delete FILE after a successful --verify. This is an ordinary delete, not a secure erase.]' \
                    '(--force -f)'{--force,-f}'[Overwrite an existing output file.]' \
                    '(--help -h)'{--help,-h}'[Print this help message.]' \
                    '(--identity -i)'{--identity,-i}'[Your private key file, used to sign and to find your public key (the .pub file next to it); default: valt.key in the valt config directory.]:identity:_files' \
                    '(--no-self)'--no-self'[Do not include your own public key as a recipient.]' \
                    '(--no-sign)'--no-sign'[Do not sign the encrypted file.]' \
                    '(--output -o)'{--output,-o}'[The output file ('\''-'\'' for standard output, which requires --no-sign); default: FILE.age.]:output:' \
                    '*'{--recipient,-r}'[Also encrypt to this recipient (an age public key). Can be repeated.]:recipient:' \
                    '*'{--recipient-file,-R}'[Also encrypt to the recipient(s) in this file, e.g. a valt .pub file. Can be repeated.]:recipient-file:_files' \
                    '(--verify)'--verify'[Decrypt the result with your private key and confirm it matches FILE.]' \
                    '1:FILE:'
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
