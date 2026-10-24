# How it works

The design, the invariants, and why some things are the way they are.

---

## The problem this solves

A CTF normally runs on someone else's server. You connect, you attack, the server
tells you whether you got it. The challenge files and the answer key are on a
machine you do not control.

This runs on your own phone. That is the whole point: the files are real, the
permissions are real, and the tools you learn are the ones you will actually use.
But it takes away the two things the server was providing, and both have to be
replaced:

| The server did | Replaced by |
| --- | --- |
| Held the answer key | A seed generated on the device, and flags derived from it |
| Verified a submission | `ctf check`, on the device |

---

## The seed

At install time, 32 random bytes are written to `~/.learmux/seed`, mode 600.

```
$ ctf doctor
  install          ok   /data/data/com.termux/files/home/.learmux
  version          0.2.0
  seed             ok   64 hex characters, mode 600
  sha256           sha256sum
  challenges       6 installed, 2 captured
  manifest         ok   37 paths, all present
  command          /data/data/com.termux/files/usr/bin/ctf
```

Every secret in the whole system is derived from it:

```
flag_for(id)        = LEARMUX{ sha256(seed + ":" + id)[0..16] }
derived_name(id, p) = sha256(seed + ":" + id + ":" + p)[0..n]
device_id           = sha256("device:" + seed)[0..8]
```

Three consequences:

**Flags are unique per device.** A flag posted in a walkthrough is wrong for
everyone else, by construction rather than by policy.

**File names are unique per device.** The file holding the flag in challenge 01
is `.backup-52b09ac4` here and `.backup-74ce0486` there. A solution that says
"read `.backup-52b09ac4`" is not a solution.

**Nothing needs to be generated ahead of time.** There is no answer key file,
because the key is the seed and the derivation is the function.

`device_id` is deliberately one-way. It lets you show a consistent name for your
device on the website without revealing anything that could produce a flag.

---

## The manifest

`~/.learmux/manifest` holds every path the tool has created, one per line, in the
order it created them. The installer writes to it, and so does `ctf start`.

This is the invariant the whole install and uninstall design rests on:

> **Everything this tool writes is recorded in the manifest.**

Uninstall reads the manifest and removes exactly those paths, files first, then
directories. It never searches for anything it did not make, and it removes a
directory only if it ends up empty. So:

- Your own files in your home directory are safe, because they were never
  recorded.
- Anything you leave in `~/.learmux` is safe, and uninstall will tell you it
  found something it did not create.
- A pre-existing directory is never claimed. The installer checks whether
  `$PREFIX/bin` already exists before recording it, because on a normal Termux
  install it does.

Directory removal does not rely on the order things were recorded. It sweeps
repeatedly, each pass removing every directory that is currently empty, and stops
when a pass removes nothing. A challenge is free to declare its paths in any
order, which matters because one of them declares a child before its parent.

---

## File layout

```
Repository                                Installed
─────────────────────────────────────     ─────────────────────────────────
install.sh                                ~/.learmux/
uninstall.sh                                seed            mode 600
bin/ctf                                     solved          one slug per line
lib/common.sh                               hints/          one counter per slug
challenges/NN-slug/                         manifest        every path we wrote
  challenge.sh        ──────────────────>   version
  solution.sh         (stays in the repo)   lib/common.sh
tests/run.sh                                challenges/NN-slug/challenge.sh
docs/                                       $PREFIX/bin/ctf
```

The installer copies rather than links, so the clone can be deleted afterwards
and the tool keeps working.

`solution.sh` is the one thing deliberately left behind. It is what the test
suite runs, and the player is not handed it.

`$PREFIX/bin/ctf` is a copy with one line rewritten: the default `LEARMUX_HOME`,
so a custom install location still resolves. `LEARMUX_HOME` in the environment
overrides it, which is how the test suite installs into a throwaway home.

---

## Why bash

The tool is about 1,300 lines of bash across the installer, the CLI and the
shared library, with no dependency beyond `coreutils`. Add the challenges and
the test suite and it is about 2,000.

That is a deliberate choice, not a limitation. The audience is a phone with
Termux on it. Requiring Python or Node would mean an install step that can fail,
and a version to keep in step with. Bash, `sha256sum`, `tar`, `base64`, `grep`
and `find` are all present in a base Termux install.

It also means the tool is readable. A learner who wonders how `ctf check` works
can read it in a minute, and that is a feature of a teaching tool.

---

## Animation and the terminal

Output is checked, not assumed:

- **Colour** only when stdout is a terminal and `NO_COLOR` is unset.
- **Animation** only when stdout is a terminal, `NO_COLOR` is unset, and `sleep`
  accepts fractions. The decision is made once, when the library is sourced.
- **The menu** only when both stdin and stdout are terminals. Piped, the CLI
  prints the how-to-play text instead, so nothing ever blocks waiting for input
  it will not get.
- **Table width** follows `COLUMNS`. On a narrow phone the title column is
  dropped rather than allowed to wrap.

That is why the test suite runs with `NO_COLOR=1` and sees none of the animation:
the non-interactive path is the default, and it is the one that has to be right.

---

## Testing

`tests/run.sh` installs into a throwaway `HOME` and `PREFIX` and plays every
challenge for real. It does not check that files exist; it checks that the game
works.

For each challenge it:

1. runs `ctf start`, and asserts the briefing does not name the files
2. runs the commands in `solution.sh`, and asserts the flag appears in the output
3. hands the flag to `ctf check`, and asserts it is accepted
4. hands it a wrong flag, and asserts it is rejected
5. runs `ctf reset`, and asserts the flag is unchanged

Then it checks the hints advance and stop, that the export is valid JSON and
carries no real flag, that `ctf doctor` is happy, that a second device produces
different flags and different file names, and that uninstall leaves the home
directory exactly as it found it.

The suite found four real bugs during development, including one where `ctf hint`
created a directory the manifest did not know about, which broke uninstall.

---

## What this deliberately does not do

**It does not try to stop you reading the source.** You own the machine. A tool
that obscured its own logic would be worse to learn from and would not work
anyway. See [Playing honestly](../README.md#playing-honestly).

**It does not phone home.** There is no network code anywhere in the tool.

**It does not verify anything centrally.** There is no server, so there is no
leaderboard and no way to check a claim made on the website. That is a real
limitation and it is covered honestly in
[platform-integration.md](platform-integration.md).

**It does not need root.** Every path it touches is under `$HOME` or in
`$PREFIX/bin`, both of which the Termux user owns.
