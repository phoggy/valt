# Sources: backup and restore in valt

Status: agreed 2026-11-27, not started. Replaces the unreleased include types (`valt/include`, `valt include ...`), and makes
wardn a source.

## Why

A backup made for recovery should hold everything needed to recover, in one signed archive, with every prompt (key
passphrase, logins, questions) asked early and together, so that a distraction cannot cause a timeout halfway through.
Today wardn does this by hand for one source, a Bitwarden vault, and include types bolt a second kind of data (an
authenticator export) onto it. A source is the general form of both: valt runs the backup and restore, and each source
knows only how to get its own data and put it back.

## Commands

    valt backup [SOURCE...] [-i KEY] [-r RECIPIENT | -R FILE]... [-o DIR] [-n NAME] [-z ZONE]
    valt restore ARCHIVE [SOURCE...] [-i KEY] [-o DIR]
    valt source list [PROJECT...]

- A SOURCE is named with its project, as a library is in `require`: `PROJECT/NAME`, e.g. `wardn/bitwarden`, is the
  library `wardn/source-bitwarden`. valt's own need no project: `2fas` is `valt/2fas`.
- `valt backup` needs at least one source: those named, or else those in `VALT_BACKUP_SOURCES` (separated by spaces,
  e.g. `2fas wardn/bitwarden`). With neither, it fails and says how to name them. Naming sources replaces the list
  rather than adding to it.
- `valt restore` restores every source in the archive, or only those named. A source whose project is not installed
  fails before anything is restored, saying which project to install.
- `valt source list` shows the sources of the projects named, or else of valt and the projects in
  `VALT_BACKUP_SOURCES`, with what each would back up now. There is no list of all installed projects to show (see
  Finding sources).
- A new source is made with `rayvn new backup-source NAME`, in a rayvn project (see Making a source).
- `valt decrypt` recognizes a sources archive and offers `valt restore`, as it offers wardn today.

The options common to all sources (key, recipients, output dir, name, time zone) are valt's. A source's own options,
e.g. Bitwarden's server URL, are its settings (see Settings). To change one for a single run, a wrapper maps its own
options to them (e.g. `wardn -u URL`); a general option such as `--set NAME.KEY=VALUE` waits until a second source
needs it.

`valt restore` writes to `-o DIR` if given, else next to the archive: `ARCHIVE-restored/SOURCE/` (as wardn saves
included files today, `BACKUP-included/`). A source that restores into a service, e.g. a Bitwarden vault, ignores it.

## Phases

Backup:

1. **open**, for every source: logins, unlocking, checks, questions. valt asks for the key passphrase first, once.
   Nothing is written yet, so a failure here leaves nothing behind.
2. **collect**, for every source: each writes its data into its own directory in secure (RAM backed) temp storage,
   sized from the sources' estimates, and outputs a JSON summary for the manifest. If any source's collect fails, the
   backup fails: a recovery backup silently missing a source is worse than none.
3. valt writes the manifest and creates one signed, encrypted archive.
4. **close**, for every source opened, always, including after a failure: logout and cleanup.

Restore:

1. valt asks for the key passphrase, verifies both signatures and decrypts the archive into secure temp storage. This
   comes first, because a source's open may need its part, e.g. which Bitwarden server the backup came from.
2. **open**, for every source being restored, with its part: logins and checks, e.g. that the target vault is empty.
   Nothing is changed yet.
3. **restore**, for every source: e.g. import the vault, or save the 2FAS export.
4. **close**, for every source opened, always.
5. valt shows each source's note, then checks the references between sources (see Lookups).

## Interface

A source is a set of bash functions, loaded into valt (in process), named `sourceNameHook`. Name is the source's
NAME in whatever case reads best, e.g. `source2FASOpen` and `sourceBitwardenOpen`: valt matches it to NAME ignoring
case, and fails if two functions match. NAME itself, as typed in `valt backup 2fas`, is lower case.

Every hook is required: valt has no hidden defaults, and fails, naming the hook, for a source that lacks one. So the
source's file shows all it does. Where a source does what valt already knows how to do, its hook is one call to a
library function (see Snapshot sources); a hook with nothing to do says so (`:`, or `return 1` for Lookup).

| Hook | Called | Does |
|---|---|---|
| `Describe` | any time | One line: what it backs up, e.g. "Bitwarden vault". |
| `Settings` | before open | Declares its settings, with `sourceSetting` (see Helpers). None: `:`. |
| `Open MODE [PART]` | open | MODE is `backup` or `restore`; PART is its part's directory on restore. Prompts, logs in, checks. Fails to stop the run before anything is written or changed. |
| `Size` | after open, backup | Megabytes of secure temp storage its collect needs. |
| `Collect DIR` | collect | Writes its data into DIR, and records its manifest entry and a summary with `sourceEntry` and `sourceSummary`. |
| `Restore PART` | restore | Puts its data back from PART, reading its manifest entry with `sourceEntryValue`. |
| `Note PART` | after restore | What to do by hand to finish, shown once everything is restored. None: `:`. |
| `Lookup KIND VALUE` | after restore | Answers another source's reference (see Lookups), e.g. where vault item VALUE is. None: `return 1`. |
| `Close MODE` | close | Logout, cleanup. Must be safe to call after a failed or partial open. |

No hook outputs anything for valt to parse: what a hook tells valt, it tells with a helper, so its output (progress,
the tools it runs, a stray `echo`) goes to the user and can never corrupt the manifest. The exceptions are the hooks
whose output is the point: `Describe`, `Size`, `Note`, `Lookup`, and `Find` (see Snapshot sources).

### Helpers

Each acts on the source whose hook is running; valt keeps track of which.

| Helper | In | Does |
|---|---|---|
| `sourceSetting KEY KIND QUESTION` | `Settings` | Declares a setting. KIND is e.g. `text` or `vault-item` (see Lookups). valt asks QUESTION the first time, and saves the answer in `~/.config/valt/sources.json`. |
| `sourceSettingValue KEY` | any hook after `Settings` | Outputs a setting's value. |
| `sourceEntry [-n \| -b \| -j] KEY VALUE` | `Collect` | Adds KEY to its manifest entry: a string, or with `-n` a number, `-b` a boolean (`true` or `false`), `-j` JSON. Each is checked, and valt quotes them (`jq --arg`), so a source never writes JSON by hand. Keys that valt sets (`name`, `projectVersion`, `settings`) fail. |
| `sourceSummary TEXT` | `Collect` | One line to show for it, e.g. "312 items, 4 attachments". |
| `sourceEntryValue KEY` | `Restore`, `Note`, `Lookup` | Outputs a value from its manifest entry (a number or boolean as text, JSON as compact JSON), or fails if there is none. |

Types are always explicit, never guessed from the value (`007` is a string unless given with `-n`). The snapshot
functions use the same helpers, e.g. `snapshotCollect` records the export's file name and when it was made.

For example:

```bash
sourceBitwardenSettings() {
    sourceSetting server text "Which Bitwarden server? (default: https://vault.bitwarden.com)"
}

sourceBitwardenCollect() {
    local dir="$1"
    ...export into ${dir}...
    sourceEntry -n items "${itemCount}"
    sourceEntry -n attachments "${attachmentCount}"
    sourceEntry server "${ sourceSettingValue server; }"
    sourceSummary "${itemCount} items, ${attachmentCount} attachments"
}
```

Sources also get valt's other helpers: secure temp storage, the key (encrypt to it, sign with it, verify), and the
prompts.

## Making a source

A source is code, so it lives in a rayvn project, as a library: `lib/source-NAME.sh`, with its tests, doc comments,
`rayvn lint`, git history and releases. A source of your own goes in a project of your own (`rayvn new project`).

`rayvn new backup-source NAME` makes one, as `rayvn new library` does, without rayvn knowing about sources: `rayvn new`
also looks for templates in the `templates/` of the rayvn projects the current project depends on (the `valtPkg` and
similar in its `flake.nix`, which `rayvn/dependencies` already reads), so valt's `templates/backup-source-template.sh`
adds the `backup-source` kind, named from the template file, to any project that uses valt. No list of installed
projects is needed. (Not just `source`: in rayvn, that is a valt term out of context, and bash's own command.) A kind
that two of those projects offer, or that is one of rayvn's own (project, library, script, test), fails, naming the
projects.

It writes `lib/source-NAME.sh` in the current project with every hook, each calling the snapshot functions, since a new
source is most often an app's export: fill in `Describe`, `Find` and `Note`, and replace any call to do that step
differently. A test template (`templates/backup-source-test-template.sh`) gives it a test too. The template is also the
interface's documentation.

## Archive layout

    sources/
        wardn/bitwarden/    the wardn/bitwarden source's part
            vault.json
            attachments/...
        valt/2fas/
            2fas-2026-11-19_13.07.16_PST.2fas.age
            2fas-2026-11-19_13.07.16_PST.2fas.age.minisig
    manifest.json

The manifest lists each source: its name (`PROJECT/NAME`), its project's version, its settings, and what its collect
recorded with `sourceEntry`:

    {
      "kind": "valt backup", "tool": "valt", "version": "0.4.0", "archiveVersion": "2.0",
      "sources": [
        {"name": "wardn/bitwarden", "projectVersion": "0.3.0", "items": 312, "attachments": 4,
         "server": "https://vault.bitwarden.com"},
        {"name": "valt/2fas", "projectVersion": "0.4.0",
         "settings": {"passwordItem": {"kind": "vault-item", "value": "2FAS export password"}}}
      ]
    }

The name always includes the project, so that a restore on another computer can say what to install (as the
manifest's `restore` does for wardn today).

## Snapshot sources

valt has no kinds of source, only hooks; but most sources are one of two shapes:

- **Live**: the data can be read whenever a backup runs, e.g. a Bitwarden vault. It writes its own hooks: collect
  exports the data.
- **Snapshot**: the data only exists when you make an export by hand, e.g. 2FAS. Its hooks call valt's snapshot
  functions, which keep the newest export encrypted to your key, signed, in a store between backups
  (`~/valt-sources/PROJECT/NAME/`, where you can see it: it holds only encrypted, signed files), and collect copies it from
  there. `snapshotOpen` calls back the source's one extra hook, `Find`, which outputs the newest export's path (or
  nothing), so it can use any logic, e.g. checking the file's contents. It asks whether to take a new export; then it
  encrypts, signs and verifies it into the store, and deletes the unencrypted export and the older copy. It warns
  about a stored export older than 90 days. On restore it is saved still encrypted to the key, with its signature
  checked, and the note says how to open it with `valt decrypt`.

For example, the 2FAS source:

```bash
source2FASDescribe() { echo "2FAS authenticator tokens"; }
source2FASSettings() { sourceSetting passwordItem vault-item "Which vault item holds the export password?"; }
source2FASFind()     { newestFile ~/Downloads/'*.2fas'; }    # where new exports appear
source2FASOpen()     { snapshotOpen 2fas "$@"; }              # calls source2FASFind, asks, stores
source2FASSize()     { snapshotSize 2fas; }
source2FASCollect()  { snapshotCollect 2fas "$@"; }
source2FASRestore()  { snapshotRestore 2fas "$@"; }
source2FASNote()     { echo "To restore the tokens to a phone: ..."; }
source2FASLookup()   { return 1; }
source2FASClose()    { snapshotClose 2fas "$@"; }
```

A later **files** source would back up a fixed set of files or directories, e.g. SSH keys; it would also cover
`--include` for a backup.

## Lookups

A setting of kind `vault-item` (the 2FAS export password's item) names something another source restores. After the
restore, valt asks each restored source's `Lookup` about it, and shows the answer with the note, e.g.
"✔ 2FAS export password is in the restored vault, in the folder Recovery", or that no source found it. This is wardn's
check today, made general. A lookup never shows a secret, only where to find it.

## Sources in this plan

| Source | Provider | Kind | Notes |
|---|---|---|---|
| `bitwarden` | wardn (`lib/source-bitwarden.sh`) | live | Today's wardn backup and restore, split into the hooks; Lookup `vault-item`. |
| `2fas` | valt (`lib/source-2fas.sh`) | snapshot | From the dropped 2fas include type (see the patch), with the snapshot functions. |
| `files` | valt | files | Later. |

## Finding sources

- Source `PROJECT/NAME` is `lib/source-NAME.sh` in rayvn project PROJECT, loaded with `require 'PROJECT/source-NAME'`,
  and nowhere else. rayvn.up already finds a project by name, from its executable on PATH, so rayvn needs no list of
  installed projects, and valt keeps none: scanning PATH for projects would mean resolving every executable in it
  (hundreds, in Homebrew's shared `bin`). The Homebrew formula and Nix flake install `lib/*.sh`, so no packaging
  changes are needed.
- A project that has only sources still needs an executable named after it on PATH, as every rayvn project does, e.g.
  one that runs its sources' checks.
- Two projects can each have a source of the same NAME. But their hook functions would have the same names, so
  using both in one run fails (rayvn's functions are readonly), naming both.
- Settings: `~/.config/valt/sources.json`, keyed by `PROJECT/NAME`. Never secrets.

Sources are bash code run inside valt, while it holds the key's passphrase, so only install projects you trust. The
docs should say so.

## wardn

- `wardn backup` becomes `valt backup wardn/bitwarden` plus the sources in `VALT_BACKUP_SOURCES`, mapping its options (`-u`,
  `--login`, `-p`, `-b`) to valt's options and the Bitwarden source's settings.
- `wardn restore` becomes `valt restore`.
- Existing backups keep restoring: valt restore recognizes a `wardn vault backup` manifest (vault.json at the top,
  `included/`) and hands it to the Bitwarden source with the old layout; wardn keeps restoring legacy age tar backups.
- Whether the `wardn` command stays for good, or later goes away in favor of `valt backup`, can wait.

## What replaces what

- `valt/include`, `valt include list|new|collect`, include types → `valt/source`, `valt/backup`, `valt source
  list`, `rayvn new backup-source`, sources.
- `FILE.include.json` → the manifest's source entry.
- `VALT_INCLUDE_PATH`, `VALT_INCLUDE_MAX_AGE_DAYS`, `~/valt-includes`, `--include-default` → the snapshot source's store,
  `~/valt-sources/PROJECT/NAME/` (and an age warning per snapshot source).
- `valt archive create --include` and `included/` stay as they are, for archives that are not backups.

None of the include work has been released, so nothing needs a migration, except the files already in your own
include directory (move the newest into the 2fas store). The uncommitted include work was dropped when this design was
agreed; a patch of it is kept for reference outside the repo.

## Staging

1. Release the fixes found along the way, without the include types: rayvn's `request` overwriting a caller's `key`.
2. ~~Agree this design.~~ Done 2026-11-27.
3. rayvn: `rayvn new` finds templates in the `templates/` of the projects the current project depends on (see Making a
   source). Release rayvn.
4. `valt/source` and `valt/backup`, `valt backup`, `valt restore` and `valt source list`, the source templates, and the
   `2fas` source. Tests use a test source.
5. The Bitwarden source in wardn, `wardn backup` and `wardn restore` as wrappers, and restoring existing backups.
   Test with the dev account in `~/dev/profiles/wardn.profile`.
6. Docs: valt and wardn READMEs, sites, and help.
7. Release valt, then wardn.

## Decisions

Made 2026-11-27, and described above:

1. **Which sources**: at least one is required, named or from `VALT_BACKUP_SOURCES` (see Commands).
2. **Changing a setting for one run**: left to the wrappers' options, e.g. `wardn -u`; no general option yet.
3. **The snapshot store**: `~/valt-sources/PROJECT/NAME/`, where you would look, not in valt's data directory.
4. **Restore destination**: `-o DIR`, else `ARCHIVE-restored/SOURCE/` next to the archive.
5. **Partial failure**: any source's collect failing fails the backup; close still runs for every source opened.
6. **In process**: sources are bash functions loaded into valt, not separate programs.
7. **Every hook required**: no hidden defaults; a snapshot source's hooks each call a snapshot function, and
   `snapshotOpen` calls the source's `Find`.
8. **Sources are code in rayvn projects**: made with `rayvn new backup-source NAME` from valt's template; no
   `valt source new`, and no sources in `~/.config/valt`.
9. **Hooks tell valt things through helpers**, not output to parse: `sourceSetting`, `sourceEntry` (explicit types),
   `sourceSummary`, and `sourceSettingValue` and `sourceEntryValue` to read them back.
10. **Sources are named with their project**, `PROJECT/NAME` (valt's own without it), as libraries are in `require`:
    valt finds them as rayvn.up finds any project, so there is no list of installed projects; `rayvn new` finds
    templates through the current project's dependencies.
