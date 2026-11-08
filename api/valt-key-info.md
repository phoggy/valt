---
layout: default
title: "valt/key-info"
parent: "Paper Keys"
grand_parent: API Reference
nav_order: 7
---

# valt/key-info

The paper key's personal information (the key info file), and filling it in.

See the [Key info file format](#key-info-file-format) below for details.

## Functions

### newKeyInfoPage()

Writes the key info web page (a single HTML file with no network access) to a directory, with the current values
from the key info file filled in, so that it can be opened in a browser. The page's Save button downloads
valt-key-info-ID.json (ID being unique to this page), encrypted with one-time keys that are also embedded in the
page, for decryptKeyInfoDownload. The paper key's fonts are embedded too, for the page's preview of the letter
(browsers do not load fonts from beside a local page).


*args*

| | |
|---|---|
| `keyInfoFile` *(string)* | Path to the key info file; it need not exist. |
| `dir` *(dir)* | Directory to write the page to. |
| `resultRef` *(stringRef)* | Name of the var to receive the page path. |
| `keysRef` *(stringRef)* | Name of the var to receive the page's id and one-time keys, for waitForKeyInfoDownload and decryptKeyInfoDownload. |
| `expires` *(int)* | When the page expires, in epoch seconds: after that it no longer saves. |
{: .args-table}

### newKeyInfoDraft()

Writes the key info file's values to a file for editing by hand: pretty printed, with every value the page edits.
Those not yet set are filled with short placeholders in angle brackets that say what goes there, e.g.
"<your full name, e.g. Bob Barker>", and if there is no one yet, a sample person with each type of way to reach
them, so that the file explains itself. Placeholders left in are dropped on saving (see tidyKeyInfoDraft).


*args*

| | |
|---|---|
| `keyInfoFile` *(string)* | Path to the key info file; it need not exist. |
| `draftFile` *(string)* | Path to write the draft to (best in secure temp storage). |
{: .args-table}

### tidyKeyInfoDraft()

Tidies a key info file edited by hand, as the page does on save: placeholders left in (values in angle brackets,
see newKeyInfoDraft) are emptied, then ways with no value, people with no name or way, empty notes and an empty
short name are dropped. Leaves a file that is not valid JSON alone, for keyInfoProblems to report.


*args*

| | |
|---|---|
| `draftFile` *(file)* | The edited file. |
{: .args-table}

### writeKeyInfoGuide()

Writes the guide to keys and passphrases for valt's web site (a Jekyll page): the key info page's explanatory tabs
('How it works', 'Strong passphrases' and 'Strength in detail'), so that they can be read without the page, e.g.
over ssh (see editKeyInfo). The page is the one source: its form, navigation and buttons are left out, and tab links
become links within the guide.


*args*

| | |
|---|---|
| `outputFile` *(string)* | Path to write the guide to, e.g. guide/index.html in the pages dir. |
{: .args-table}

### decryptKeyInfoDownload()

Decrypts the key info page's download, written with the one-time keys from newKeyInfoPage, into a file for
importKeyInfo. Fails, decrypting nothing, unless the download was made with those keys and is unchanged.


*args*

| | |
|---|---|
| `downloadFile` *(file)* | The downloaded valt-key-info.json. |
| `keys` *(string)* | The page's id and keys, from newKeyInfoPage. |
| `outputFile` *(string)* | Path to write the decrypted JSON to (best in secure temp storage). |
{: .args-table}

### openKeyInfoPage()

Opens the key info page in the default web browser. On macOS that is the app registered for https links, since the
page's own file type may be handled by another app (e.g. an editor). The page must not be on a volume macOS hides
from Finder (as rayvn's temp storage is): browsers cannot be given files there.


*args*

| | |
|---|---|
| `pageFile` *(file)* | The page, from newKeyInfoPage. |
{: .args-table}

### waitForKeyInfoDownload()

Waits for the key info page's download (valt-key-info-ID.json, or a browser's renamed copy such as
'valt-key-info-ID (1).json') to appear in a directory after a marker file was created, and outputs its path. If
there are several, the most recently modified is used. Downloads from other pages, or from before the marker, are
ignored.


*args*

| | |
|---|---|
| `downloadsDir` *(dir)* | The browser's downloads directory. |
| `markerFile` *(file)* | A file created before the page was opened; only downloads newer than it count. |
| `keys` *(string)* | The page's id and keys, from newKeyInfoPage. |
| `deadline` *(int)* | When to stop waiting, in epoch seconds. |
{: .args-table}

*returns*

| | |
|---|---|
| `0` | a download was found |
| `1` | the deadline passed first |
{: .args-table}

### isKeyInfoCancel()

Succeeds if a decrypted key info download is the page's Cancel, rather than its Save.


*args*

| | |
|---|---|
| `jsonFile` *(file)* | The decrypted download, from decryptKeyInfoDownload. |
{: .args-table}

### importKeyInfo()

Imports the key info page's JSON into the key info file, which is replaced. Values in an existing key info file other
than those the page sets (e.g. for a custom template) are kept.


*args*

| | |
|---|---|
| `jsonFile` *(file)* | The downloaded JSON. |
| `keyInfoFile` *(string)* | Path to the key info file to write. |
{: .args-table}

### keyInfoValues()

Outputs the key info file's values as compact JSON with sorted keys, or nothing if it does not exist, so that two
versions can be compared by value whatever their layout.


*args*

| | |
|---|---|
| `keyInfoFile` *(string)* | Path to the key info file. |
{: .args-table}

### keyInfoProblems()

Outputs what the key info file still needs before a paper key can be made from it, one item per line (e.g. 'a
greeting'), or nothing if it is complete.


*args*

| | |
|---|---|
| `keyInfoFile` *(string)* | Path to the key info file; it need not exist. |
{: .args-table}

### isKeyInfoComplete()

Succeeds if the key info file is complete, so that a paper key can be made from it (see keyInfoProblems).


*args*

| | |
|---|---|
| `keyInfoFile` *(string)* | Path to the key info file; it need not exist. |
{: .args-table}

### migrateLegacyKeyInfo()

Converts the key.info file that earlier versions of valt used (a bash file, in the same directory) to the key info
file, if that does not exist yet, keeping the old file as key.info.bak. Each contact's ways are split out, their
types guessed as the key info page does. Values that are still the old template's samples are left out, unless the
file was marked completed. Says so on stderr when it converts.


*args*

| | |
|---|---|
| `keyInfoFile` *(string)* | Path to the key info file. |
{: .args-table}


## Key info file format

The key info file, key-info.json in the valt config directory, is JSON: the letter's greeting, closing and author,
the people who can help (contacts, each with a name and the ways to reach them, each with a type and a value) and
notes. Any other values are kept, for a custom paper key template:

    {
      "greeting": "Greetings,",
      "closing": "I hope you never need this!",
      "author": "Bob Barker",
      "contacts": [
        { "name": "Aunt Martha", "ways": [ { "type": "phone", "value": "+44 791 112 4456", "preferred": true },
                                           { "type": "address", "value": "1 Park Row, Leeds LS1 5AB, UK" } ] }
      ],
      "notes": [ "The passphrase is in the envelope in the fire safe." ]
    }

A way's type is phone, email, social or address. One of a person's ways may be marked preferred, the one to try
first. An optional authorShortName is how the paper key refers to the author after first giving their full name
(default: the first word of it), e.g. a nickname, or the given name of a name with the family name first.
