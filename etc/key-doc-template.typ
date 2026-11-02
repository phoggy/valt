// The valt paper key document, compiled to PDF by typst (https://typst.app).
//
// Values come from data.json, written by valt: every variable set in key.info (e.g. data.author, data.contacts), plus
// data.generated, set by valt (date, checksum, and the logo, QR code and armored key file names). Style overrides
// (valt keys/paper --css) are applied by the style function in style.typ, after the rules below.

#import "style.typ": style

#let data = json("data.json")
#let generated = data.generated

// ---- Theme

#let bodyFont = "Google Sans Flex"
#let humanFont = "Shantell Sans"
#let codeFont = "Fira Code"
#let textColor = rgb("#222222")
#let headingColor = rgb("#1d3e81")
#let linkColor = rgb("#086ddd")

#let calloutColors = (
  warning: (border: rgb("#ff9100"), text: rgb("#663c00"), title: rgb("#ff9100")),
  danger: (border: rgb("#dc267f"), text: rgb("#5c1a3b"), title: rgb("#dc267f")),
  quote: (border: rgb("#9e9e9e"), text: rgb("#424242"), title: rgb("#9e9e9e")),
)

// ---- Document and page

#set document(
  title: "Private Key Pair Backup & Usage Instructions",
  author: data.author,
  description: "File decryption.",
  keywords: (data.author, "valt", "private key", "backup", "encryption", "decryption", "security"),
)

#set page(
  paper: "us-letter",
  margin: (x: 0.75in, top: 0.7in, bottom: 0.9in),
  footer: context {
    set text(size: 9pt, style: "italic", fill: luma(90))
    grid(
      columns: (1fr, auto, 1fr),
      align(left)[#data.author Private Key],
      align(center, generated.date),
      align(right, counter(page).display("1 / 1", both: true)),
    )
  },
)

#set text(font: bodyFont, size: 11pt, fill: textColor)
#set par(leading: 0.6em, spacing: 1.1em)
#set list(spacing: 0.8em, indent: 1em)
#set enum(spacing: 0.8em, indent: 1em)

#show heading: set text(fill: headingColor)
#show heading: set block(above: 1.6em, below: 0.9em)
#show heading.where(level: 1): set text(size: 22pt)
#show heading.where(level: 2): set text(size: 16.5pt)
#show heading.where(level: 3): set text(size: 13pt)

#show link: set text(fill: linkColor)
// No ligatures in code: Fira Code would otherwise join e.g. the dashes in '--option' and the armored key's '-----'
#show raw: set text(font: codeFont, size: 9pt, ligatures: false, features: (calt: 0))
#show raw.where(block: true): it => block(width: 100%, fill: rgb("#f9f9f9"), inset: 1em, it)

#show: style

// ---- Elements

#let callout(kind, body) = {
  let colors = calloutColors.at(kind)
  block(
    width: 100%,
    breakable: false,
    inset: (x: 16pt, y: 12pt),
    radius: 6pt,
    fill: colors.border.transparentize(90%),
    stroke: (left: 4pt + colors.border),
    {
      set text(fill: colors.text)
      body
    },
  )
}

#let calloutTitle(kind, title) = text(weight: "semibold", fill: calloutColors.at(kind).title, title)

// 20 boxes per row, so that the default 140 fill 7 even rows
#let passphraseGrid(length) = align(center, grid(
  columns: (0.31in,) * 20,
  rows: 0.31in,
  gutter: 2pt,
  ..range(length).map(_ => rect(width: 100%, height: 100%, radius: 3pt, stroke: 1.5pt + rgb("#dddddd"))),
))

#let noteLines(count) = for _ in range(count) {
  block(width: 100%, height: 0.28in, below: 0pt, stroke: (bottom: 0.75pt + rgb("#d8d8d8")))
}

// ---- Letter

// The size the HTML template gave the 308 pixel logo: one pixel per 1/96 inch
#image(generated.logo, width: 308in / 96)
#v(3em)

#data.greeting

This document contains a private key that can unlock files encrypted with the associated public key. It is intended as
a backup so *must* be kept in at least one secure place, e.g. a safe-deposit box, fire safe, a trusted friend or family
member. Instructions for using the key to unlock a file are provided. The instructions are a bit technical, so it
includes some ways to get help if needed.

Know that the key _itself_ is encrypted, so it *cannot* be used without the passphrase used to create it. The last page
has space for the passphrase to be hand written. If not there, the notes below should provide some information to help
find the passphrase. If you don't have or can't get the passphrase, so sorry but there is nothing you can do but stop
here.

Welcome to the modern world of digital security.

If all of this has you thinking _"uh… what?"_, please see #link(<getting-help>)[Getting Help].

#v(2.5em)
#text(font: humanFont, size: 13.5pt, style: "italic", data.closing)
#v(1.5em)
#text(font: humanFont, size: 18pt, tracking: 1pt, data.author)

#pagebreak()

// ---- Getting help

= Getting Help <getting-help>

The following are contacts that I trust and who have agreed to help if needed:

#enum(..data.contacts)

If they aren't available, don't worry – there are people out there who can help you through this process. Since what
you're trying to decrypt may be extremely sensitive (e.g. a password manager backup), you need to be careful about who you
trust and how you get help...

== Finding Help

=== Your Best Options: In-Person Help

*Friends or Family in Tech:* Think about anyone in your network who works with computers professionally – software
developers, IT support, network administrators, or even tech-savvy relatives. They might be willing to help, and you
already know them personally.

*Local Computer Repair Shops:* This is probably your best bet. Most towns have at least one computer repair shop, and
many of their technicians know their way around the command line. When you call, you can say something like: "I need
help following some written instructions to run commands in a terminal. It involves decrypting a very sensitive file, so
I need someone who can work on this in person and agrees not to keep any copies of my files or information."

*Computer Store Support:* Many computer stores and manufacturers offer in-store help (for example, the Genius Bar at an
Apple Store). While they might not help with the actual decryption, they can help you get comfortable with opening a
terminal and understanding basic navigation. Make an appointment and explain that you need to learn some basic command
line skills for accessing your own files.

*Local College IT Departments:* If you have a community college or university nearby, their IT support staff are usually
knowledgeable and trustworthy. You might be able to arrange a consultation where they walk you through the process.

=== Community Resources

*Library Technology Centers:* Many public libraries have tech help sessions or staff who assist with computer problems.
While they might not know the specific commands, they can help you get comfortable with the basics.

*Senior Centers or Community Centers:* If you're looking for a comfortable, non-intimidating environment, these often
have volunteer tech helpers who are patient and understanding.

=== Last Resort: Online Help

#callout("warning")[
  *Only if you absolutely cannot find in-person help*, you might consider freelance platforms like Upwork or Fiverr. But
  please understand – this is risky because what you're decrypting may be extremely sensitive, such as a password
  manager backup or financial records. If you go this route:

  - Never, ever share your actual files or private keys
  - Only ask for general guidance on the process
  - Work with someone who has excellent reviews and a long track record
  - Consider having them walk you through the steps over video call rather than doing the work themselves
]

=== What to Say to Anyone Helping You

Here's some language you can use to protect yourself:

#callout("quote")[
  #calloutTitle("quote")[Friends and family]

  #emph[“I need your help unlocking a really sensitive file. Before we get started, I just want to ask that you don’t
  make any copies, take screenshots, or save anything from this session. It has deeply personal information, and I’m
  trusting you to keep it completely private. I really appreciate your help.”]

  #calloutTitle("quote")[Professionals]

  #emph["I need help with a very sensitive file decryption. Before we start, I need your agreement that you will not
  make any copies of my files, take screenshots, or retain any information from this session. The file contains
  extremely sensitive personal data, and I need your word that everything stays confidential and nothing gets saved to
  your system."]

  Professionals should understand completely and agree without hesitation.
]

=== Red Flags – When to Walk Away

#callout("danger")[
  *Trust your instincts.* If someone:

  - Asks to take your computer home or work on it remotely
  - Wants to copy your files "for backup purposes"
  - Seems evasive about confidentiality agreements
  - Pressures you to rush through the process
  - Asks too many questions about what's in the encrypted file

  Just politely decline and find someone else.
]

=== A Final Thought

Remember, you're not asking for anything unreasonable. Plenty of people know how to use the command line, and most will
be happy to help you follow written instructions. The key is finding someone trustworthy who respects the sensitive
nature of what you're working with. Take your time, and don't settle for help that doesn't feel right.

#pagebreak()

// ---- Instructions

= Instructions <instructions>

This section assumes familiarity with the terminal and using command line tools. The tools described here run on macOS
and Linux.

== Prerequisites

The private key and the passphrase used to encrypt it are required. Hopefully you have the key in digital form, perhaps
on a USB/thumb drive or in a file (it should have a '.key' file suffix). If you don't, the Paper Key section below has two
forms of backup: a QR code and ("`PEM`" formatted) text, both containing the encrypted private key. Instructions for
recreating the digital key from these are provided.

The passphrase used when the key was created is likely printed on the Passphrase page of this document, but it may be
stored separately. In the latter case, there may be hints on where to find it in the Notes section.

You need one of the following:

- #link("https://nixos.org/download/")[Nix], which can download and run the valt recovery tool for you (recommended).
- `valt`, the tool used to create this document. Source and instructions can be found at
  #link("https://github.com/phoggy/valt")[github.com/phoggy/valt].
- A command line tool that performs #link("https://github.com/C2SP/C2SP/blob/main/age.md")[age file encryption and
  decryption], such as #link("https://github.com/FiloSottile/age")[age 1.3.0+], plus `tar`, which is included with
  macOS and Linux. Another age implementation will work, so long as it supports post-quantum (`-pq`) keys.

== Identifying Your File

The end of the file name tells you what kind of file you have. File browsers often hide it; running `ls` in a terminal
shows full names.

- *`.age`*: a single encrypted file. A file with the same name plus `.minisig` may be next to it; keep the two in the
  same directory so the signature can be checked.
- *`.valt`*: a secure archive, which can contain any number of files and directories. A file with the same name plus
  `.pub` may be next to it; it contains no secrets and can be ignored.

== Decrypting With The Recovery Tool

If you have Nix installed, open a terminal, change to the directory containing the encrypted file or archive, and run:

```
nix run github:phoggy/valt#recover -- decrypt FILE -i KEY_FILE
```

This downloads and runs the recovery tool automatically; no other software needs to be installed. If Nix reports that
flakes are not enabled, add `--extra-experimental-features 'nix-command flakes'` immediately after `nix`.

If you installed `valt`, the equivalent is:

```
valt decrypt FILE -i KEY_FILE
```

Replace `FILE` with the `.age` or `.valt` file and `KEY_FILE` with the private key file. You will be prompted for the
passphrase that protects the private key.

- An encrypted file is decrypted next to the original, without the `.age` suffix. If a signature file is present it is
  checked first, and decryption stops if the file has been tampered with.
- A secure archive is verified and its contents are extracted into the current directory. Use `-o DIRECTORY` to extract
  somewhere else.

== Decrypting Manually

For an encrypted file, using `age`:

```
age -d -i KEY_FILE -o DECRYPTED_FILE FILE.age
```

This skips the signature check, which requires valt.

For a secure archive, first unpack it, which needs no key:

```
tar xJf FILE.valt
```

Then follow the instructions in the `README.txt` file it contains. They use `age` to decrypt, `tar` to unpack, and
optionally `minisign` to confirm nothing has been tampered with.

In all cases you will be prompted to enter the passphrase that protects the private key.

#pagebreak()

// ---- Paper key: the QR code and the armored key each on a page of their own

== Paper Key

#align(center, image(generated.qrCode, width: 100%))

#pagebreak()

// The armored key must fit on one page, since it may be scanned or typed in
#block(breakable: false, {
  set par(leading: 0.45em)
  raw(read(generated.armoredKey), block: true)
})

#pagebreak()

== Convert Paper Key To File

Use one of the following three methods to convert one of the two forms of paper keys to a binary file:

=== Decode QR Code

The QR code contains binary values so the usual phone camera decoding will likely not work. Instead, take a photo and
move it to your computer. Use `qrtool` to convert the image (PNG, JPEG, etc.) to a key file:

+ `nix run github:phoggy/valt#qrtool -- decode IMAGE-FILE > KEY-FILE` or
+ `brew install qrtool; qrtool decode IMAGE-FILE > KEY-FILE`

The result should match the checksum shown in the next method.

=== Scan PEM Text

Scan the PEM text and send/save it as a file. If you don't know how, search the web for "scanning text on phone". Verify
that the result matches the checksum to guard against scanning errors:

```
sha256sum KEY-FILE | head -c 16
```

It should match

#raw(generated.checksum, block: true)

=== Manual PEM Text Entry

If neither of the first two options works, you can always type it in by hand. Yes, this is _extremely_ tedious, but it
_can_ be done. Be sure to include the leading and trailing lines, each of which begins and ends with 5 dashes. Use the
checksum test from the previous method to ensure it was entered correctly!

#pagebreak()

// ---- Passphrase and notes, kept on one page

#block(breakable: false)[
  == Passphrase

  Write the passphrase in the boxes below, one character per box:

  #passphraseGrid(140)

  == Notes

  #{
    set text(font: humanFont)
    for note in data.notes [#note \ ]
  }

  #noteLines(16)
]
