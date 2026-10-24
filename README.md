# Learmux CTF

A capture-the-flag you play on your own phone, in your own Termux, against files
that are really on your device.

No browser sandbox. No server. No account. The challenges write real files into
your home directory, with real permissions, and your flags are generated from a
random value created on this device at install time. That last part matters: a
flag someone posts online is worthless to you, because yours is different.

**Play only on your own device.** Everything here touches `$HOME` and nothing
else. There is no network activity, and nothing needs root.

---

## Requirements

- Termux on Android, from F-Droid
- `coreutils` (Termux ships it), and a SHA-256 tool

That is it. No Python, no Node, no compiler.

---

## Install

```bash
pkg install git
git clone https://github.com/apsideslabs/learmux-ctf
cd learmux-ctf
./install.sh
```

The installer checks for Termux, prints exactly what it is going to write, and
waits for you to say yes. Nothing is written before that.

Then:

```bash
ctf list
```

---

## The four commands

```
ctf list                what is installed, and what you have captured
ctf start <id>          read the briefing and set the challenge up
ctf check <id> <flag>   hand in a flag you found
ctf reset <id>          put a challenge back to how it started
```

A session looks like this:

```bash
$ ctf list
  01   hidden-file      Hidden in plain sight      Easy     10 pts  open
  0 of 1 captured, 0 of 10 points

$ ctf start 01
  ... the briefing ...

$ ls -a                       # a plain ls shows nothing
$ cat .backup-xxxxxxxx        # read the file you found
$ ctf check 01 LEARMUX{...}
Correct. 01 captured, 10 points.
```

---

## How the flags work

At install time a random 32-byte value is written to `~/.learmux/seed`, mode 600.
Every flag is derived from it:

```
flag = LEARMUX{ first 16 hex characters of sha256(seed + ":" + challenge id) }
```

Two consequences worth knowing:

- **Your flags are yours.** Nothing is hardcoded, so a walkthrough you find
  online will not contain your flag.
- **Do not share the seed.** It is the only thing that makes your flags yours.
  If you post it, you have posted every answer.

The same derivation names the files the challenges hide, so the file names differ
from device to device too.

---

## What gets written, and how to remove it

The installer keeps a record of every path it creates in `~/.learmux/manifest`,
in the order it created them. `ctf start` adds the challenge files to the same
manifest. Uninstall reads that list and removes exactly those paths:

```bash
./uninstall.sh
```

It prints what it is about to remove first, and it removes directories only if
they end up empty. Anything you put in there yourself is left alone. Nothing
outside the manifest is ever touched.

The tool itself lives in two places:

| Path | What it is |
| --- | --- |
| `~/.learmux/` | the tool, your progress, the seed, and the manifest |
| `$PREFIX/bin/ctf` | the command (falls back to `~/.local/bin`) |

---

## Writing a challenge

A challenge is a directory under `challenges/` holding one `challenge.sh`. It
sets some metadata and defines three functions:

```bash
CHALLENGE_ID="02"
CHALLENGE_SLUG="read-the-log"
CHALLENGE_TITLE="Read the log"
CHALLENGE_CATEGORY="Text"
CHALLENGE_DIFFICULTY="Easy"
CHALLENGE_POINTS=15
CHALLENGE_OBJECTIVE="Find the flag in the log file."

challenge_briefing() { ... }   # what the learner reads, in prose
challenge_files()    { ... }   # every absolute path it creates
challenge_setup()    { ... }   # create those files
```

Two rules that matter:

- **`challenge_files` must list exactly what `challenge_setup` creates.** The
  manifest and the reset path both depend on it.
- **Never print a path in the briefing.** Finding the file is the challenge.

Derive names and contents from the seed with `derived_name` and `flag_for`, both
in `lib/common.sh`, so the challenge is different on every device.

---

## Testing

The whole thing is testable without a phone. The suite installs into a throwaway
`HOME` and `PREFIX`, plays the challenge the way a learner would, and uninstalls:

```bash
./tests/run.sh
```

It covers the install, the seed, the flag derivation, a wrong flag, a right flag,
a reset, re-installing over an existing install, two devices getting different
flags, and a clean uninstall. 52 checks, no phone required.

---

## Status

One challenge, working end to end, on purpose. The scaffolding is the point of
this version: the seed, the manifest, the four commands, and a test that proves
the loop closes.

Next, in rough order:

1. Hints, revealed one at a time, and a `ctf hint <id>` command
2. Challenges that are not just files: a running process, a cron entry, a local
   web server on a randomised port
3. State-based checking, so a challenge can be solved by fixing something rather
   than by pasting a string
4. A `ctf doctor` command that reports what is installed and what is missing

---

## Licence

MIT. See [LICENSE](LICENSE).

Built by [Apsides Labs](https://apsideslabs.github.io/grapheme/).
