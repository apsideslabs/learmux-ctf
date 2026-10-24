# Playing

Everything you need, command by command. If you only read one section, read
[The loop](#the-loop).

---

## The loop

Every challenge follows the same four steps.

**1. Look at what is on offer.**

```bash
$ ctf list
  ──────────────────────────────────────────────────────
    CHALLENGES
  ──────────────────────────────────────────────────────
    01   hidden-file          Hidden in plain sight Easy     10 pts  open
    02   owner-only           Owner only            Easy     15 pts  open
    ...
  ──────────────────────────────────────────────────────
    0 of 6 captured, 0 of 120 points
```

On a narrow terminal the title column is dropped so the table fits. On a wide
one you get the titles too.

**2. Read the briefing and set the challenge up.**

```bash
$ ctf start 01
```

This prints the scenario, the objective, and then writes the challenge files
into your home directory. It tells you how many files it wrote. It does not
tell you their names, because finding them is the challenge.

**3. Find the flag and read it.**

This is the part that is up to you. Use `ls`, `grep`, `cat`, `find`, `tar`, and
whatever else the briefing points at. The briefing teaches the concept; the
hints narrow the search.

**4. Hand it in.**

```bash
$ ctf check 01 LEARMUX{3f2a91c4b7e05d18}
```

If it is right, the flag is revealed character by character and the challenge is
marked captured. If it is wrong, you get a nudge and nothing is recorded.

---

## The commands

### `ctf list`

Shows every challenge with its difficulty, its points, and whether you have
captured it. Also shows your total.

Aliases: `ctf ls`.

### `ctf start <id>`

`<id>` is the number or the slug, so `ctf start 01` and `ctf start hidden-file`
both work.

Prints the briefing, the objective, and then creates the files. Running it again
is safe: it removes anything it made last time and starts over, and it does not
clear a capture you have already earned.

### `ctf check <id> <flag>`

Hands in a flag. Quotes around the flag are optional, and so is whitespace, so
all of these work:

```bash
ctf check 01 LEARMUX{3f2a91c4b7e05d18}
ctf check 01 "LEARMUX{3f2a91c4b7e05d18}"
ctf check hidden-file LEARMUX{3f2a91c4b7e05d18}
```

If you get it wrong, the command exits with a non-zero status, which means you
can use it in a script if you want to.

### `ctf reset <id>`

Deletes the challenge's files and builds them again from scratch, with the same
flag. Useful when you have deleted something you need, or edited a file past
the point where it makes sense.

A reset does not take away a capture you have already earned.

### `ctf hint <id>`

Reveals one hint at a time. Each challenge has two. The first points at the
approach, the second at the specific step. Asking again gives you the next one,
never the previous one again, and once you have seen them all the command says
so and stops.

The count is remembered per challenge, so you can leave and come back.

### `ctf export`

Prints a receipt of your progress as JSON: your device name, how many challenges
you have captured, your points, and which ones. Paste it into the Learmux
website to see your progress there.

The website cannot verify it, and it says so. See
[platform-integration.md](platform-integration.md) for why.

```bash
ctf export              # your progress
ctf export --challenges # the challenge catalogue, with no flags in it
```

### `ctf doctor`

Checks the install and reports what it finds: whether the seed is intact, which
hashing tool is available, how many challenges are installed, whether the files
the manifest lists are still present, and whether `ctf` is on your `PATH`.

Run it first if something behaves oddly.

---

## The menu

Run `ctf` with no arguments on a terminal and you get a menu instead of a wall of
text. It is the same seven commands, numbered, and it stays open until you quit.

Piped output, or a non-interactive shell, gets the how-to-play text instead, so
scripts and tests are never blocked waiting for input.

---

## When you get stuck

In order:

1. **Re-read the briefing.** It teaches the concept the challenge tests. The
   answer is usually a step you skipped.
2. **`ctf start <id>` again.** It re-prints everything without touching your
   progress.
3. **`ctf hint <id>`.** Once, then go and try. Then again if you need it.
4. **`ctf reset <id>`.** If you deleted or mangled something.

If a flag looks right and is rejected, check that you copied all of it. Flags
are exactly 25 characters: `LEARMUX{`, sixteen characters, `}`.

---

## Worked example: challenge 01

```bash
$ ctf list
    01   hidden-file          Hidden in plain sight Easy     10 pts  open

$ ctf start 01
  ──────────────────────────────────────────────────────
    01  Hidden in plain sight
    Easy, 10 points
  ──────────────────────────────────────────────────────

  Two files were written into your home directory before you started.

  Both have names that begin with a dot. A plain listing leaves those out,
  which is why a directory can look emptier than it is.

  One of the two holds your flag. The other is noise.

  Your home directory is /data/data/com.termux/files/home.

    Objective
    Find the file in your home directory that holds the flag, and read it.

    Ready. 2 file(s) are in place in your home directory.

$ ls
$ ls -a
.  ..  .backup-52b09ac4  .cache-f1c28788  .learmux

$ cat .backup-52b09ac4
# learmux device manifest
# written at install time, do not edit
host: localhost
flag: LEARMUX{3f2a91c4b7e05d18}

$ ctf check 01 LEARMUX{3f2a91c4b7e05d18}
  LEARMUX{3f2a91c4b7e05d18}
  Correct. 01 captured, 10 points.

  10 of 120 points.  ctf list to see what is left.
```

Note the `ls` that printed nothing. That is the whole first half of the
challenge: a directory can look empty without being empty.
