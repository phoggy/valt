// The valt paper key document, compiled to PDF by typst (https://typst.app).
//
// Values come from data.json, written by valt: every value in the key info file (e.g. data.author, and data.contacts,
// each with a name and ways, each with a type and value), plus data.generated, set by valt (date, checksum, and the logo, QR code and armored key file names). Style overrides
// (valt keys/paper --css) are applied by the style function in style.typ, after the rules below.

#import "style.typ": style

#let data = json("data.json")
#let generated = data.generated

// The author's name after the first mention: the key info's authorShortName if set (e.g. a nickname, or where the
// family name comes first), otherwise the first word of their name
#let authorShortName = {
  let short = data.at("authorShortName", default: "").trim()
  if short == "" { data.author.split(" ").first() } else { short }
}

// ---- Theme

#let bodyFont = "Google Sans Flex"
#let humanFont = "Shantell Sans" // the letter's closing line and the notes: handwritten in feel, but easy to read
#let signatureFont = "Yellowtail" // the letter's signature
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

// An optional watermark stamped in the top right corner of each page, in the margin, from the key info's watermark
// value (e.g. SAMPLE, for the sample paper key on valt's web site)
#let watermark = data.at("watermark", default: "")

#set page(
  paper: "us-letter",
  margin: (x: 0.75in, top: 0.7in, bottom: 0.9in),
  foreground: if watermark != "" { context {
    // Level with the top of the first page's image, on every page; in front, so that a shaded block cannot hide it
    let red = rgb(220, 38, 38, 75%)
    let dy = 0.62in
    place(top + right, dx: -0.75in, dy: dy, rotate(6deg, box( // the right edge at the text margin
      stroke: 1.5pt + red, radius: 3pt, inset: (x: 8pt, y: 4pt),
      text(size: 13pt, weight: "bold", tracking: 0.15em, fill: red, watermark),
    )))
  } },
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

// Sizes and spacing follow the HTML version: 15px body text (1px is 0.75pt), 1em between paragraphs and 0.5em
// between list items (typst spacing runs from a line's baseline to the next block's cap height, so it adds the line
// leading). Browsers set the optical size to the size in pixels, typst to the size in points, which sets the text
// wider, so it is set explicitly.

#let fontSize(px) = (size: px * 0.75pt, variations: (opsz: px))

#set text(font: bodyFont, fill: textColor, ..fontSize(15))
#set par(leading: 0.6em, spacing: 1.6em)
// A disc in the text's color, the size browsers draw (the font's own bullet is much smaller)
#set list(spacing: 1em, indent: 1em, marker: context box(height: 0.7em, align(horizon, circle(radius: 0.18em, fill: text.fill))))
#set enum(spacing: 1em, indent: 1em)

#show heading: set text(fill: headingColor)
#show heading: set block(above: 1.9em, below: 1.1em)
#show heading.where(level: 1): set text(..fontSize(30))
#show heading.where(level: 2): set text(..fontSize(22.5))
#show heading.where(level: 3): set text(..fontSize(17.55))

// Don't start a section near the bottom of a page, leaving its heading and a line or two there with the rest on the
// next page. An empty, unbreakable block of the space a section needs goes before each heading, then the same space is
// taken back: if it fits, nothing moves; if not, the block, and so the heading, go to the next page. (Unlike checking
// the heading's position, this cannot flip back and forth between layouts.) A heading also stays with what follows it.
#let needSpace(height) = {
  block(height: height, width: 100%, breakable: false, above: 0pt, below: 0pt)[]
  v(-height)
}
#show heading: set block(sticky: true)
#show heading.where(level: 2): it => { needSpace(2.3in); it }
#show heading.where(level: 3): it => { needSpace(1.5in); it }

#show link: set text(fill: linkColor)
// No ligatures in code: Fira Code would otherwise join e.g. the dashes in '--option' and the armored key's '-----'
#show raw: set text(font: codeFont, size: 9pt, ligatures: false, features: (calt: 0))
#show raw.where(block: true): it => block(width: 100%, fill: rgb("#f9f9f9"), inset: 1em, breakable: false, it)

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

Know that the key _itself_ is encrypted, so it *cannot* be used without the passphrase used to create it. The
passphrase may be written on the last page. If it is not, the Notes on that page say where to find it. If you don't
have or can't get the passphrase, so sorry but there is nothing you can do but stop here.

Welcome to the modern world of digital security.

If all of this has you thinking _"uh… what?"_, please see #link(<getting-help>)[Getting Help].

#v(2.5em)
#text(font: humanFont, size: 13.5pt, style: "italic", data.closing)
#v(1.5em)
#text(font: signatureFont, size: 22pt, data.author)

#pagebreak()

// ---- Getting help

= Getting Help <getting-help>

The following are contacts that I trust and who have agreed to help if needed:

// Each person: their name, then the ways to reach them, a label for each type (always in the order of wayLabels) with
// its values beside it, the preferred way marked. Emails, phone numbers and web addresses are links, for reading on
// screen, but look the same as the text around them when printed. With three or more people, they are set two to a row.
#let wayLabels = (phone: "Phone", email: "Email", social: "Social", address: "Address")
#let wayValue(type, value) = {
  let plain = text(fill: textColor, value)
  if type == "email" { link("mailto:" + value, plain) }
  else if type == "phone" { link("tel:" + value.replace(regex("[^+0-9]"), ""), plain) }
  else if value.starts-with("http://") or value.starts-with("https://") { link(value, plain) }
  else { value }
}
#let groupedWays(ways) = {
  let types = wayLabels.keys().filter(type => ways.any(way => way.type == type))
  types += ways.map(way => way.type).dedup().filter(type => type not in types) // any unknown type, last
  types.map(type => (type, ways.filter(way => way.type == type)))
}
#let preferredMark = text(fill: luma(115), style: "italic", [ (preferred)])
#let person(number, contact) = grid(
  columns: (1.1em, 1fr), column-gutter: 0.5em, // fixed widths, so that every person's values line up
  align(right)[#number.],
  block[
    #strong(contact.name)
    #v(1.3em, weak: true) // a little space between the name and the ways
    #grid(
      columns: (4.2em, 1fr), column-gutter: 0.8em, row-gutter: 0.7em,
      ..groupedWays(contact.ways).map(((type, values)) => (
        text(fill: luma(115), wayLabels.at(type, default: type)),
        values.map(way => [#wayValue(type, way.value)#if way.at("preferred", default: false) { preferredMark }])
              .join(linebreak()),
      )).flatten(),
    )
  ],
)
#let people = data.contacts.enumerate().map(((index, contact)) => person(index + 1, contact))
#pad(left: 1em, if people.len() >= 3 {
  grid(columns: (1fr, 1fr), column-gutter: 2em, row-gutter: 1.4em, ..people)
} else {
  stack(spacing: 1.4em, ..people)
})

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
and Linux, and on Windows in its Linux environment, WSL (see #link(<installing-nix>)[Installing Nix]).

#callout("warning")[
  #calloutTitle("warning")[If _you_ are helping]

  These are #data.author's files, and they may be extremely sensitive. Anyone holding this document can try to decrypt
  them, so before you start, make sure that the person asking should have access:

  - They are someone #authorShortName would want to have it, such as family or the executor of their estate.
  - They need it now. If #authorShortName can be reached, check with them first, using contact details you already
    have rather than any the person asking gives you.
  - Their story holds up. If they are a stranger to you, or anything seems wrong, stop; pressure to hurry is a warning
    sign in itself.
]

== Prerequisites

The private key and the passphrase used to encrypt it are required. Hopefully you have the key in digital form, perhaps
on a USB/thumb drive or in a file (it should have a '.key' file suffix). If you don't, this document's Paper Key pages
hold two forms of backup: a QR code and ("`PEM`" formatted) text, both containing the encrypted private key. See
#link(<getting-the-key-file>)[Getting the Key File] for how to make the key file from either.

The passphrase used when the key was created is either written on the Passphrase page of this document, or kept
separately, in which case the Notes section says where to find it.

You need *one* of the following:

// Each link shows its address, since a printed copy has no links to follow

- Nix (recommended), which downloads and runs the valt recovery tool for you, with one command. It always uses the
  versions of age and the other tools that valt has tested with (not whatever the computer happens to have), installs
  nothing else, and can be removed afterwards. See #link(<installing-nix>)[Installing Nix], below.
- `valt`, the tool used to create this document. Source and instructions can be found at
  #link("https://github.com/phoggy/valt")[github.com/phoggy/valt].
- A command line tool that performs age file encryption and decryption (the format is described at
  #link("https://c2sp.org/age")[c2sp.org/age]), such as age 1.3.0 or later, from
  #link("https://github.com/FiloSottile/age")[github.com/FiloSottile/age], plus `tar`, which is included with macOS and
  Linux, and optionally `minisign`, to check signatures, from
  #link("https://github.com/jedisct1/minisign")[github.com/jedisct1/minisign]. Another age implementation will work, so
  long as it supports post-quantum (`-pq`) keys.

== Identifying Your File

The end of the file name tells you what kind of file you have. File browsers often hide it; running `ls` in a terminal
shows full names.

- *`.age`*: a single encrypted file. A file with the same name plus `.minisig` may be next to it; keep the two in the
  same directory so the signature can be checked.
- *`.valt`*: a secure archive, which can contain any number of files and directories. A file with the same name plus
  `.pub` may be next to it; it contains no secrets and can be ignored.

== Getting the Key File <getting-the-key-file>

The commands below need the private key as a file: `KEY_FILE` in them. If you have it already (a file ending in `.key`,
perhaps on a USB drive), use that. Otherwise, make it from this document's #link(<paper-key>)[Paper Key] pages near the
end, which hold the same encrypted key as a QR code and as text, in one of these three ways:

=== Decode QR Code

The QR code contains binary values so the usual phone camera decoding will likely not work. Instead, take a photo and
move it to your computer. Use `qrtool` to convert the image (PNG, JPEG, etc.) to a key file:

+ `nix run github:phoggy/valt#qrtool -- decode IMAGE_FILE > KEY_FILE` or
+ `brew install qrtool; qrtool decode IMAGE_FILE > KEY_FILE`

The result should match the checksum shown in the next method.

=== Scan PEM Text

Scan the PEM text and send/save it as a file. If you don't know how, search the web for "scanning text on phone". Verify
that the result matches the checksum to guard against scanning errors:

```
sha256sum KEY_FILE | head -c 16
```

It should match

#raw(generated.checksum, block: true)

=== Manual PEM Text Entry

If neither of the first two options works, you can always type it in by hand. Yes, this is _extremely_ tedious, but it
_can_ be done. Be sure to include the leading and trailing lines, each of which begins and ends with 5 dashes. Use the
checksum test from the previous method to ensure it was entered correctly!

== Installing Nix <installing-nix>

Nix fetches software and runs it, without changing anything else on the computer. Install it with the installer for
your computer:

- *Mac with Apple silicon* (Apple menu, About This Mac, shows a chip such as Apple M1): download and run the installer
  from #link("https://dtr.mn/determinate-nix")[dtr.mn/determinate-nix].
- *Linux*: in a terminal, run:
  ```
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
  ```
- *Intel Mac*: in a terminal, run:
  ```
  curl -L https://nixos.org/nix/install | sh
  ```
  With this installer, each `nix` command in this document needs this option right after `nix`:
  ```
  --extra-experimental-features 'nix-command flakes'
  ```
- *Windows*: Nix runs in Windows' own Linux environment, WSL. Open PowerShell as administrator, run `wsl --install`,
  restart, open Ubuntu from the Start menu, and follow the Linux step above inside it (see
  #link("https://learn.microsoft.com/windows/wsl/install")[learn.microsoft.com/windows/wsl/install]). Your Windows files
  are under `/mnt/c` there, e.g. `/mnt/c/Users/NAME/Downloads`.

Installing asks for an administrator password and takes a few minutes; on a Mac it creates a separate volume for Nix.
Answer yes to its questions and allow any system dialogs that appear. When it is done, *open a new terminal window*:
one that was already open does not know about Nix yet.

The first time the recovery tool runs, it downloads what it needs, about 1 GB, so it needs an internet connection and
may take several minutes. Later runs start at once.

To remove Nix afterwards, run `/nix/nix-installer uninstall` if you used the first two installers; after the Intel Mac
one, follow
#link("https://nix.dev/manual/nix/latest/installation/uninstall")[nix.dev/manual/nix/latest/installation/uninstall].

#pagebreak()

== Decrypting With The Recovery Tool

With Nix installed (see #link(<installing-nix>)[Installing Nix], above), open a terminal, change to the directory
containing the encrypted file or archive, and run:

```
nix run github:phoggy/valt#recover -- decrypt FILE -i KEY_FILE
```

Replace `FILE` with the `.age` or `.valt` file and `KEY_FILE` with the private key file (see
#link(<getting-the-key-file>)[Getting the Key File]). You will be prompted for the passphrase that protects the private
key.

- An encrypted file is decrypted next to the original, without the `.age` suffix. If a signature file is present it is
  checked first, and decryption stops if the file has been tampered with.
- A secure archive is verified and its contents are extracted into the current directory. Use `-o DIRECTORY` to extract
  somewhere else.

This downloads and runs the recovery tool automatically; no other software needs to be installed. If you used the
Intel Mac installer (or Nix reports that flakes are not enabled), add this right after `nix`:

```
--extra-experimental-features 'nix-command flakes'
```

#if generated.at("releaseTag", default: "") != "" [
  If that fails, which a later change to valt could cause, try the valt release current when this document was made:

  #raw("nix run github:phoggy/valt/" + generated.releaseTag + "#recover -- decrypt FILE -i KEY_FILE", block: true)

  An archive's `README.txt` gives the same command for the release current when it was made.
]

== Decrypting Using valt

If you installed `valt`, the equivalent is:

```
valt decrypt FILE -i KEY_FILE
```

`FILE` and `KEY_FILE` are as above, and so are the results.

== Decrypting Manually

For an encrypted file, using `age`, and `minisign` to check its signature:

+ If a signature file (`FILE.age.minisig`) is next to it, check that the file has not been tampered with. The public
  key that checks the signature is inside the private key file; this extracts it (asking for the passphrase), then
  checks the signature:
  ```
  age -d KEY_FILE | sed -n 's/^# \[minisign\.pub\] //p' > minisign.pub
  minisign -V -p minisign.pub -m FILE.age
  ```
  You should see `Signature and comment signature verified`. If not, stop: the file has been changed.
+ Decrypt it:
  ```
  age -d -i KEY_FILE -o DECRYPTED_FILE FILE.age
  ```

For a secure archive, first unpack it, which needs no key:

```
tar xJf FILE.valt
```

Then follow the instructions in the `README.txt` file it contains: they use `age` to decrypt, `tar` to unpack, and
optionally `minisign` to confirm nothing has been tampered with.

In all cases you will be prompted to enter the passphrase that protects the private key.

#pagebreak()

// ---- Paper key: the QR code and the armored key each on a page of their own

== Paper Key <paper-key>

#align(center, image(generated.qrCode, width: 100%))

#pagebreak()

// The armored key must fit on one page, since it may be scanned or typed in
#block(breakable: false, {
  set par(leading: 0.45em)
  raw(read(generated.armoredKey), block: true)
})

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
