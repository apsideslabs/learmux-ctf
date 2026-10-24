# Writing a challenge

A challenge is a directory under `challenges/` holding a `challenge.sh`. The CLI
sources that file, reads its metadata, and calls its functions.

---

## The shape

```
challenges/
  07-read-the-config/
    challenge.sh     installed, and read by the CLI
    solution.sh      never installed, run by the test suite
```

The directory name is for humans. The identity of the challenge is
`CHALLENGE_ID`, and the URL-safe name is `CHALLENGE_SLUG`.

---

## Metadata

Every one of these is required. The CLI reads them by sourcing the file in a
subshell, so they must be plain assignments with no side effects.

| Variable | Notes |
| --- | --- |
| `CHALLENGE_ID` | Two digits, unique. Sets the order in `ctf list`. |
| `CHALLENGE_SLUG` | Unique, kebab-case. Used by `ctf check` and in progress. |
| `CHALLENGE_TITLE` | Shown in `ctf list` and as the heading of `ctf start`. |
| `CHALLENGE_CATEGORY` | Free text. Appears in the website's catalogue. |
| `CHALLENGE_DIFFICULTY` | `Easy`, `Medium` or `Hard`. |
| `CHALLENGE_POINTS` | Integer. 10 to 15 for Easy, 20 to 25 for Medium, 30 for Hard. |
| `CHALLENGE_OBJECTIVE` | One line. Printed under the briefing. |

---

## The four functions

### `challenge_briefing`

The prose the player reads. This is teaching material, not a puzzle statement.
Explain the concept, name the tools that matter, and do not name the file.

```bash
challenge_briefing() {
  printf '%s\n' \
    "Every file carries a permission string, and a long listing prints it in" \
    "the first column. Nine characters, in three groups of three:" \
    "" \
    "    rwx   rwx   rwx" \
    "" \
    "A dash means that permission is not granted." \
    "" \
    "Three files were written into your home directory. One of them is yours" \
    "alone."
}
```

`$HOME` expands, because the briefing is printed by the CLI with the
environment already set.

### `challenge_hints`

Two hints, separated by a line holding only three dashes. The first should name
the approach, the second the specific step. Neither should be a command you can
copy and run without understanding it.

```bash
challenge_hints() {
  cat <<'HINTS'
A long listing shows the permissions for every file at once. That is the
long flag with a lower case L, not a one.
---
Look for the file whose group and other permissions are all dashes.
HINTS
}
```

The separator matters: it is how the CLI counts hints rather than lines, so a
hint can run to several lines and still be one hint.

### `challenge_files`

Every absolute path the challenge creates, one per line. Directories count.

```bash
challenge_files() {
  challenge_key_file
  challenge_notes_file
  printf '%s\n' "$HOME/notes"
}
```

This list is load-bearing. The CLI records it in the manifest, so uninstall can
remove exactly those paths, and `ctf reset` knows what to delete before building
again. **If you create a file and do not list it here, uninstall will leave it
behind.**

### `challenge_setup`

Creates the files. It runs with `$HOME` set and the working directory wherever
the player happened to be, so use absolute paths throughout.

```bash
challenge_setup() {
  local key flag
  key="$(challenge_key_file)"
  flag="$(flag_for "$CHALLENGE_ID")"

  {
    printf '%s\n' "# device signing key"
    printf '%s\n' "flag: $flag"
  } > "$key"
  chmod 600 "$key"
}
```

Setup must be idempotent. It will be run again by `ctf reset` and by a second
`ctf start`, and it should produce the same files with the same flag every time.
Start by removing anything you are about to write, so a half-finished previous
run cannot confuse the result.

---

## The solution file

`solution.sh` holds `challenge_solution`, which prints the commands that solve
the challenge, one per line:

```bash
challenge_solution() {
  printf '%s\n' 'ls -l "$HOME"'
  printf '%s\n' 'cat "$HOME"/private-*.key'
}
```

The test suite runs these and asserts the flag appears. That is how the
repository proves a challenge is winnable without the installer ever shipping
the answer.

Write it as a player would solve it, using the tools the briefing teaches. If
your solution needs a command the briefing does not mention, either mention it
or simplify the solution.

---

## Naming things from the seed

Never hardcode a file name or a flag. Derive both from the device seed, so the
challenge differs on every machine.

| Helper | Use |
| --- | --- |
| `flag_for <id>` | The flag for this device: `LEARMUX{16 hex}` |
| `derived_name <id> <purpose> [len]` | A stable, device-specific name fragment |
| `device_id` | A short public name for the device, safe to share |

```bash
challenge_key_file() {
  printf '%s\n' "$HOME/private-$(derived_name "$CHALLENGE_ID" key 8).key"
}
```

`derived_name` is deterministic: the same challenge and purpose give the same
fragment on the same device, and a different one anywhere else. Call it as often
as you like; it does not consume anything.

Wrap every path helper in its own function and call that function from both
`challenge_files` and `challenge_setup`. If the two compute the name separately
they will drift, and the manifest will list paths that do not exist.

---

## Splitting a flag

Some challenges want the flag in pieces. Split the inner part, not the wrapper:

```bash
flag="$(flag_for "$CHALLENGE_ID")"
first="$(printf '%s' "$flag" | cut -c1-16)"    # LEARMUX{ + 8 hex
second="$(printf '%s' "$flag" | cut -c17-)"    # 8 hex + }
```

`cut -c1-16` keeps `LEARMUX{` and eight characters; `cut -c17-` gives the last
eight and the closing brace. Putting the two halves back together has to produce
exactly `flag_for`.

---

## Checking your work

```bash
# rebuild the JSON the website reads, if you changed anything
./tests/run.sh
```

The suite picks up any new challenge directory automatically. It will tell you
if the solution does not reveal the flag, if the flag is not accepted, if a
wrong flag is, or if reset does not restore things.

Two things it cannot check, so check them yourself:

- **That the briefing does not name the file.** Read it as a player would.
- **That the hint does not hand over the command.** A hint should make you think
  of the command, not give it to you.

---

## Checklist

- [ ] `CHALLENGE_ID` is unique, and `CHALLENGE_SLUG` is kebab-case and unique
- [ ] `challenge_files` lists every path `challenge_setup` creates, including directories
- [ ] every path helper is a single function called from both
- [ ] names and the flag both come from the seed, never hardcoded
- [ ] `challenge_setup` is idempotent, and clears what it is about to write
- [ ] the briefing teaches the concept and does not name the file
- [ ] there are two hints, separated by `---`, and neither is a copy-pasteable command
- [ ] `solution.sh` solves it using only tools the briefing mentions
- [ ] `./tests/run.sh` passes
