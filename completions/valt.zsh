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
                'default-key:Show or set the default private key file, used by any command when no key is given.'
                'encrypt:Encrypt a single file to FILE.age and sign it with your private key (FILE.age.minisig). Your own'
                'key-info:Fill in the paper key'\''s personal information (the key.info file) in a web page: the letter, the people who can'
                'keys:Generate an age key pair, with the private key encrypted by a passphrase, plus a PDF paper key as backup'
                'paper:Generate the paper key PDF for an existing key pair, personalized from the key.info file. The PDF is written'
                'pass-check:Check a password or passphrase: rate its strength, and look it up in the HaveIBeenPwned'
                'passphrase:Generate random passphrases. Passphrases are made of words chosen at random from a list of'
                'password:Generate random passwords, using letters, digits and symbols, with a random length between'
                'public-key:Recreate the public key file (.pub) for a private key, e.g. if it was lost. The private key contains'
                'verify:Verify a key pair, and optionally files encrypted or archived with it. You will be prompted for the'
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
                                'create:Create a signed, encrypted secure archive (.valt) from files and directories, and its public'
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
                                    '(--identity -i)'{--identity,-i}'[Your private key file, used to sign and to find your public key (the .pub file next to it); default: the default key (see '\''valt default-key'\'').]:identity:_files' \
                                    '(--name -n)'{--name,-n}'[The archive file name prefix (default: your user name).]:name:' \
                                    '(--no-mac-metadata)'--no-mac-metadata'[Do not keep the macOS metadata (extended attributes such as Finder tags, ACLs and file flags) of the files added. It is kept by default, but only macOS tar restores it; other tars, e.g. on Linux, may warn about it.]' \
                                    '(--no-self)'--no-self'[Do not include your own public key as a recipient.]' \
                                    '(--output-dir -o)'{--output-dir,-o}'[The directory to write the archive to (default: the current directory).]:output-dir:_files -/' \
                                    '*'{--recipient,-r}'[Also encrypt to this recipient (an age public key). Can be repeated.]:recipient:' \
                                    '*'{--recipient-file,-R}'[Also encrypt to the recipient(s) in this file, e.g. a valt .pub file. Can be repeated.]:recipient-file:_files' \
                                    '(--user-text -u)'{--user-text,-u}'[Text to include in the archive'\''s README. Can contain '\''\\n'\''.]:user-text:' \
                                    '(--zone -z)'{--zone,-z}'[The time zone for the timestamp in the archive name: '\''local'\'' (the system time zone), '\''UTC'\'', or a name such as '\''America/Los_Angeles'\'' (default: local).]:zone:' \
                                    '*:INPUT...:'
                                    ;;
                                extract)
                                    _arguments \
                                    '(--help -h)'{--help,-h}'[Print this help message.]' \
                                    '(--identity -i)'{--identity,-i}'[Your private key file (default: the default key; see '\''valt default-key'\'').]:identity:_files' \
                                    '(--output-dir -o)'{--output-dir,-o}'[The existing directory to extract into (default: the current directory).]:output-dir:_files -/' \
                                    '1:ARCHIVE:_files'
                                    ;;
                                verify)
                                    _arguments \
                                    '(--help -h)'{--help,-h}'[Print this help message.]' \
                                    '(--identity -i)'{--identity,-i}'[Your private key file (default: the default key; see '\''valt default-key'\'').]:identity:_files' \
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
                    '(--identity -i)'{--identity,-i}'[The private key file (default: the default key; see '\''valt default-key'\'').]:identity:_files' \
                    '(--output -o)'{--output,-o}'[For a file, the output file ('\''-'\'' for standard output; default: FILE without .age). For an archive, the existing directory to extract into (default: the current directory).]:output:' \
                    '1:FILE:_files'
                    ;;
                default-key)
                    _arguments \
                    '(--clear)'--clear'[Remove the setting, so that the built-in default is used.]' \
                    '(--help -h)'{--help,-h}'[Print this help message.]' \
                    '1:KEY_FILE:_files'
                    ;;
                encrypt)
                    _arguments \
                    '(--armor -a)'{--armor,-a}'[Write PEM encoded (text) output.]' \
                    '(--delete)'--delete'[Delete FILE after a successful --verify. This is an ordinary delete, not a secure erase.]' \
                    '(--force -f)'{--force,-f}'[Overwrite an existing output file.]' \
                    '(--help -h)'{--help,-h}'[Print this help message.]' \
                    '(--identity -i)'{--identity,-i}'[Your private key file, used to sign and to find your public key (the .pub file next to it); default: the default key (see '\''valt default-key'\'').]:identity:_files' \
                    '(--no-self)'--no-self'[Do not include your own public key as a recipient.]' \
                    '(--no-sign)'--no-sign'[Do not sign the encrypted file.]' \
                    '(--output -o)'{--output,-o}'[The output file ('\''-'\'' for standard output, which requires --no-sign); default: FILE.age.]:output:' \
                    '*'{--recipient,-r}'[Also encrypt to this recipient (an age public key). Can be repeated.]:recipient:' \
                    '*'{--recipient-file,-R}'[Also encrypt to the recipient(s) in this file, e.g. a valt .pub file. Can be repeated.]:recipient-file:_files' \
                    '(--verify)'--verify'[Decrypt the result with your private key and confirm it matches FILE.]' \
                    '1:FILE:'
                    ;;
                key-info)
                    _arguments \
                    '(--downloads -d)'{--downloads,-d}'[Your browser'\''s downloads directory (default: ~/Downloads).]:downloads:_files -/' \
                    '(--help -h)'{--help,-h}'[Print this help message.]' \
                    '(--key-info -k)'{--key-info,-k}'[Key info file to write (default: key.info in the valt config directory).]:key-info:'
                    ;;
                keys)
                    _arguments \
                    '(--allow-weak-passphrase)'--allow-weak-passphrase'[Accept a passphrase that fails the strength and breach check. Not recommended: the passphrase is all that protects the private key.]' \
                    '(--default -d --no-default)'{--default,-d}'[Make the new key the default key (see '\''valt default-key'\'') without asking. Otherwise you are asked, unless it already is the default.]' \
                    '(--force -f)'{--force,-f}'[Replace existing key files, once the new ones have been created.]' \
                    '(--help -h)'{--help,-h}'[Print this help message.]' \
                    '(--key-info -k)'{--key-info,-k}'[Key info file to use instead of the default for PDF generation.]:key-info:_files' \
                    '(--name -n)'{--name,-n}'[Name to use for key files, e.g. bob -> bob.pub, bob.key.]:name:' \
                    '(--no-advice)'--no-advice'[Do not show passphrase advice.]' \
                    '(--default -d --no-default)'--no-default'[Do not make the new key the default key, and do not ask.]' \
                    '(--no-pdf)'--no-pdf'[Do not generate the paper key PDF.]' \
                    '(--no-verify)'--no-verify'[Do not verify keys.]' \
                    '(--output-dir -o)'{--output-dir,-o}'[Directory for the key files (default: the valt config directory).]:output-dir:_files -/' \
                    '(--quick -q)'{--quick,-q}'[Same as --no-advice --no-verify, and the default key is not offered (--default still applies).]' \
                    '(--style -c)'{--style,-c}'[Typst file with style overrides to apply for PDF generation.]:style:_files' \
                    '(--template -t)'{--template,-t}'[Typst template file to use instead of the default for PDF generation.]:template:_files'
                    ;;
                paper)
                    _arguments \
                    '(--help -h)'{--help,-h}'[Print this help message.]' \
                    '(--key-info -k)'{--key-info,-k}'[Key info file to use instead of the default.]:key-info:_files' \
                    '(--name -n)'{--name,-n}'[Use the NAME.key file in the valt config directory, e.g. bob -> bob.key.]:name:' \
                    '(--style -c)'{--style,-c}'[Typst file with style overrides to apply.]:style:_files' \
                    '(--template -t)'{--template,-t}'[Typst template file to use instead of the default.]:template:_files' \
                    '1:KEY_FILE:_files'
                    ;;
                pass-check)
                    _arguments \
                    '(--breach-only -b)'{--breach-only,-b}'[Only look it up in the breach database; do not rate its strength.]' \
                    '(--help -h)'{--help,-h}'[Print this help message.]' \
                    '(--threat-level -t)'{--threat-level,-t}'[How capable an attacker to judge strength against.]:threat-level:(casual motivated professional nation-state)' \
                    '(--use-case -u)'{--use-case,-u}'[What it protects: '\''account'\'' (an online account, whose password hashes could be stolen and attacked quickly) or '\''file'\'' (an encrypted file or private key, such as a valt key, protected by age'\''s deliberately slow hashing).]:use-case:(account file)'
                    ;;
                passphrase)
                    _arguments \
                    '(--count -n)'{--count,-n}'[The number of passphrases to generate.]:count:' \
                    '(--help -h)'{--help,-h}'[Print this help message.]' \
                    '(--separator -s)'{--separator,-s}'[The text between words (default: a space).]:separator:' \
                    '(--words -w)'{--words,-w}'[The number of words in each passphrase.]:words:'
                    ;;
                password)
                    _arguments \
                    '(--count -n)'{--count,-n}'[The number of passwords to generate.]:count:' \
                    '(--help -h)'{--help,-h}'[Print this help message.]' \
                    '(--max)'--max'[The maximum length.]:max:' \
                    '(--min)'--min'[The minimum length.]:min:'
                    ;;
                public-key)
                    _arguments \
                    '(--force -f)'{--force,-f}'[Replace an existing public key file.]' \
                    '(--help -h)'{--help,-h}'[Print this help message.]' \
                    '(--output -o)'{--output,-o}'[The public key file to write (default: next to the private key, with a .pub suffix).]:output:' \
                    '1:KEY_FILE:_files'
                    ;;
                verify)
                    _arguments \
                    '(--help -h)'{--help,-h}'[Print this help message.]' \
                    '(--identity -i)'{--identity,-i}'[The private key file (default: the default key; see '\''valt default-key'\'').]:identity:_files' \
                    '*:FILE...:'
                    ;;
            esac
            ;;
    esac
}

(( $+functions[compdef] )) && compdef _valt valt
