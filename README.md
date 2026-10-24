# Learmux CTF

A capture-the-flag you play in Termux, on your own phone, against files that are
really on your device.

[![Test](https://github.com/apsideslabs/learmux-ctf/actions/workflows/test.yml/badge.svg)](https://github.com/apsideslabs/learmux-ctf/actions/workflows/test.yml)
![Licence](https://img.shields.io/badge/licence-MIT-blue)
![Platform](https://img.shields.io/badge/platform-Termux%20%7C%20Linux-lightgrey)
![Shell](https://img.shields.io/badge/shell-bash-4EAA25)

```
█░░ █▀▀ ▄▀█ █▀█ █▀▄▀█ █░█ ▀▄▀
█▄▄ ██▄ █▀█ █▀▄ █░▀░█ █▄█ █░█     Termux CTF
▀▀▀ ▀▀▀ ▀░▀ ▀░▀ ▀░░░▀ ▀░▀ ▀░▀     real flags, on your own device

  ──────────────────────────────────────────────────────
    CHALLENGES
  ──────────────────────────────────────────────────────
    01   hidden-file          Hidden in plain sight Easy     10 pts  open
    02   owner-only           Owner only            Easy     15 pts  open
    03   two-halves           Two halves            Medium   20 pts  open
    04   read-the-log         Read the log          Medium   20 pts  open
    05   twice-over           Twice over            Hard     30 pts  open
    06   inside-the-archive   Inside the archive    Medium   25 pts  open
  ──────────────────────────────────────────────────────
    0 of 6 captured, 0 of 120 points
```

Six challenges. 120 points. Every flag generated on your device, so a walkthrough
you find online contains someone else's answer, not yours.

---

## Contents

- [What it is](#what-it-is)
- [Install](#install)
- [The commands](#the-commands)
- [The challenges](#the-challenges)
- [How the flags work](#how-the-flags-work)
- [Where things live](#where-things-live)
- [Playing honestly](#playing-honestly)
- [Writing a challenge](#writing-a-challenge)
- [Testing](#testing)
- [Documentation](#documentation)

---

## What it is

Most browser-based CTFs simulate a terminal. This one does not. The challenges
write real files into your real home directory, with real permissions, and the
tools you use to find them are the real ones: `ls`, `grep`, `base64`, `tar`.

Three things follow from that:

- **It works offline.** No server, no account, no network traffic.
- **Your flags are yours.** Each is derived from a random value created on this
  device at install time.
- **You can read the source.** It is on your own machine, and nothing can stop
  you. That is covered in [Playing honestly](#playing-honestly).

Play only on your own device. Everything here touches `$HOME` and nothing else,
and nothing needs root.

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

Run `ctf` on its own for a menu, which is easier than typing on a phone.

### Requirements

Termux from F-Droid, and `coreutils`, which Termux ships. `tar`, `gzip` and
`base64` come with the base install. There is nothing to compile and nothing to
download beyond the repository itself.

---

## The commands

Four you will use constantly:

| Command | What it does |
| --- | --- |
| `ctf list` | What is installed, and what you have captured |
| `ctf start <id>` | Read the briefing and set the challenge up |
| `ctf check <id> <flag>` | Hand in a flag you found |
| `ctf reset <id>` | Put a challenge back to how it started |

Three more for when you need them:

| Command | What it does |
| --- | --- |
| `ctf hint <id>` | Reveal the next hint, one at a time |
| `ctf export` | A receipt of your progress, to paste into the website |
| `ctf doctor` | Check that everything is where it should be |

A session looks like this:

```bash
$ ctf list
  01   hidden-file          Hidden in plain sight Easy     10 pts  open
  0 of 6 captured, 0 of 120 points

$ ctf start 01
  ... the briefing ...

$ ls -a                       # a plain ls shows nothing
$ cat .backup-xxxxxxxx        # read the file you found

$ ctf check 01 LEARMUX{...}
  LEARMUX{3f2a91c4b7e05d18}
  Correct. 01 captured, 10 points.

  10 of 120 points.  ctf list to see what is left.
```

---

## The challenges

| # | Slug | Topic | Difficulty | Points |
| --- | --- | --- | --- | --- |
| 01 | `hidden-file` | Filesystem | Easy | 10 |
| 02 | `owner-only` | Permissions | Easy | 15 |
| 03 | `two-halves` | Filesystem | Medium | 20 |
| 04 | `read-the-log` | Text | Medium | 20 |
| 05 | `twice-over` | Encoding | Hard | 30 |
| 06 | `inside-the-archive` | Archives | Medium | 25 |

Between them they ask you to find a hidden file, read a permission string,
walk a directory tree, search a log, undo two layers of encoding, and read a
file out of a compressed archive.

---

## How the flags work

At install time a random 32-byte value is written to `~/.learmux/seed`, mode 600.
Every flag is derived from it:

```
flag = LEARMUX{ first 16 hex characters of sha256(seed + ":" + challenge id) }
```

The names of the files the challenges hide are derived the same way, from the
same seed. So two people running the same challenge get different flags and
different file names, and an answer posted online is useless to everyone but
the person who posted it.

**Do not share the seed.** It is the only thing that makes your flags yours. If
you post it, you have posted every answer.

`ctf doctor` prints a short public name for your device, which you can share
safely. It reveals nothing about the seed.

---

## Where things live

Two places, and one record of both:

| Path | What it is |
| --- | --- |
| `~/.learmux/` | The tool, your progress, your seed, your hints |
| `$PREFIX/bin/ctf` | The command (falls back to `~/.local/bin`) |
| `~/.learmux/manifest` | Every path above, and every challenge file, in order |

The manifest is the whole trick. The installer and `ctf start` append to it as
they write, and `uninstall.sh` reads it and removes exactly those paths:

```bash
./uninstall.sh
```

It prints what it is about to remove first, and it removes directories only if
they end up empty. Anything you put in there yourself is left alone, and it
says so. Nothing outside the manifest is ever touched.

---

## Playing honestly

This is a CTF on your own machine, which changes what is possible.

You can read `~/.learmux/challenges/*/challenge.sh` and work out how a flag is
built. You have the seed. You could compute every answer in a few lines without
learning anything. Nothing here can prevent that, and a tool that pretended
otherwise would be lying to you.

Two things are true anyway. The paths of least resistance are the intended ones:
finding a file, reading a permission string, decoding a payload. And the score
only means something if you earned it.

The one thing the tool does withhold is the worked solution. Each challenge has
a `solution.sh` in the repository that the test suite runs, and the installer
deliberately does not copy it. You get the briefing, the objective and two
hints, in that order, which is enough to get unstuck without being handed the
answer.

---

## Writing a challenge

A challenge is a directory under `challenges/` holding one `challenge.sh`. It
sets some metadata, and defines four functions:

```bash
CHALLENGE_ID="07"
CHALLENGE_SLUG="read-the-config"
CHALLENGE_TITLE="Read the config"
CHALLENGE_CATEGORY="Text"
CHALLENGE_DIFFICULTY="Medium"
CHALLENGE_POINTS=20
CHALLENGE_OBJECTIVE="Find the flag in a configuration file."

challenge_briefing() { ... }   # what the player reads, in prose
challenge_hints()    { ... }   # two hints, separated by a line of ---
challenge_files()    { ... }   # every absolute path it creates
challenge_setup()    { ... }   # create those files
```

Add a `solution.sh` beside it holding `challenge_solution`, which prints the
commands that solve it. The test suite runs them, which is how the repository
proves every challenge is winnable without shipping the answer.

Two rules matter:

- **`challenge_files` must list exactly what `challenge_setup` creates.** The
  manifest, the reset path and uninstall all depend on it.
- **Never print a path in the briefing.** Finding the file is the challenge.

Full details, including the naming helpers and the seed, are in
[docs/authoring.md](docs/authoring.md).

---

## Testing

The whole thing is testable without a phone. The suite installs into a throwaway
`HOME` and `PREFIX`, plays every challenge the way a learner would, and
uninstalls:

```bash
./tests/run.sh
```

It proves, for each of the six challenges, that the documented solution really
does reveal the flag, that the flag is accepted, that a wrong flag is rejected,
and that a reset restores it. Then it checks the hints, the export, the doctor,
a second device getting different flags, and a clean uninstall.

100 checks. CI runs the suite and shellcheck on every push.

---

## Documentation

| Document | What is in it |
| --- | --- |
| [docs/playing.md](docs/playing.md) | The loop, command by command, with worked examples |
| [docs/authoring.md](docs/authoring.md) | Writing a challenge, and the rules that keep it safe |
| [docs/how-it-works.md](docs/how-it-works.md) | The seed, the manifest, the file layout, the design choices |
| [docs/platform-integration.md](docs/platform-integration.md) | How this connects to the Learmux website |

---

## Licence

MIT. See [LICENSE](LICENSE).

Built by [Apsides Labs](https://github.com/apsideslabs).
