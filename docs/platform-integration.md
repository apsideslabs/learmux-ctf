# Connecting to the Learmux website

The tool and the site are separate on purpose. This document is the contract
between them.

---

## The division of labour

| | Website | This tool |
| --- | --- | --- |
| Teaches the concept | Yes | Briefly, in the briefing |
| Holds the catalogue | Yes, generated from here | Yes, it is the source |
| Sets up a challenge | No | Yes |
| Runs real commands | No, it cannot | Yes |
| Verifies a flag | **No, and it cannot** | Yes |
| Remembers progress | Only what you paste in | Yes, on the device |

The site is the guide and the catalogue. The tool is the game and the authority.

---

## Why the website cannot check a flag

This is worth being precise about, because the obvious design does not work.

Every flag is `sha256(seed + ":" + id)`. To check a submitted flag, the site
would need the seed. Asking a learner to paste their seed means asking them to
paste the thing that generates every answer on their device, which is worse than
useless.

Could the tool sign a receipt instead? It could, and the site could verify the
signature. But the learner controls the device that holds the signing key. They
could generate a fresh seed, mark every challenge solved, sign it, and the
signature would verify perfectly. A signature proves the receipt came from *a*
device. It does not prove anything about skill, and dressing it up as
verification would be dishonest.

So the website does not verify. The honest design is:

- The **tool** decides whether a flag is correct. It has the seed, and it is
  running on the machine the files are on.
- The **website** accepts an export and displays it, clearly labelled as
  something you told it about yourself.

A leaderboard, or a certificate worth anything, needs a backend. That is a real
decision with real costs and it is deliberately deferred.

---

## The two flows

### Browsing, on the site

A learner on `/ctf/` reads what the tool is and why it is different, then copies
the install command:

```bash
pkg install git
git clone https://github.com/apsideslabs/learmux-ctf
cd learmux-ctf
./install.sh
```

On `/ctf/challenges/` they see the six challenges, generated from this
repository. Each one has its own page with the briefing, the objective, the
difficulty and the points. Hints are there too, revealed one at a time, so the
site never spoils a challenge for someone who is about to play it.

Each page ends with the command to start that challenge:

```bash
ctf start 04
```

The site never shows a flag, and never shows a solution.

### Playing, in Termux

The learner plays in Termux. `ctf check` decides. The site is not involved.

### Reporting back, on the site

When they want to see their progress on the site, they run:

```bash
ctf export
```

and paste the JSON into `/ctf/progress/`. The page parses it, stores it in the
browser, and renders captured challenges, points and badges. The page states
plainly that this is a record of what the tool reported, not something the site
checked.

This is worth building anyway. It gives a learner somewhere to see the whole
picture, and it is the honest version of the feature.

---

## Keeping the catalogue in step

The site's challenge pages are generated from this repository, not written by
hand. The mechanism:

```bash
ctf export --challenges
```

prints the catalogue as JSON: id, slug, title, category, difficulty, points,
objective, briefing and hints, with no flags in it. That output is committed to
the website as a data file, and the site's pages are built from it.

When a challenge changes here, the catalogue is regenerated and the site follows.
The site's content validator fails the build if the file is missing, malformed,
or has drifted from the shape it expects.

`--challenges` deliberately carries no flag. The export that does carry your
progress is a separate command, and it is the one you paste into the site.

---

## The export format

`ctf export`, one object:

```json
{
  "format": "learmux-ctf/progress/1",
  "version": "0.2.0",
  "device": "a3f2c1d4",
  "exported": "2026-10-24T16:00:00Z",
  "solved": 4,
  "total": 6,
  "points": 70,
  "pointsTotal": 120,
  "hintsUsed": 3,
  "challenges": [
    {
      "id": "01",
      "slug": "hidden-file",
      "title": "Hidden in plain sight",
      "difficulty": "Easy",
      "points": 10,
      "solved": true,
      "hintsUsed": 1
    }
  ]
}
```

`ctf export --challenges`, the catalogue:

```json
{
  "format": "learmux-ctf/challenges/1",
  "version": "0.2.0",
  "challenges": [
    {
      "id": "01",
      "slug": "hidden-file",
      "title": "Hidden in plain sight",
      "category": "Filesystem",
      "difficulty": "Easy",
      "points": 10,
      "objective": "Find the file in your home directory that holds the flag, and read it.",
      "briefing": "Two files were written into your home directory ...",
      "hints": ["...", "..."]
    }
  ]
}
```

Both are versioned under `format`. If the shape ever changes, the version
changes with it, and the site can tell the difference between an old export and
a corrupt one.

`device` is `sha256("device:" + seed)[0..8]`. It is one-way, so a learner can
share it, and two exports from the same device carry the same value, which is
what makes it useful as a label.

---

## What a backend would add

Not now, but worth writing down so the decision is a decision:

| Feature | What it needs |
| --- | --- |
| Accounts, progress that follows you between devices | A database, and auth |
| A leaderboard | Accounts, and a way to trust a submission |
| A certificate worth anything | Accounts, evidence, and an issuer identity |

The last one is the interesting one. A credential that anyone can earn by
clicking through is worth less than nothing, because it dilutes the ones that
were earned. Any certificate this project issues should be gated on evidence:
a solved set, a submitted write-up, a finished project. That is a product
decision before it is a technical one.

---

## Summary

- The site teaches, catalogues and links. The tool plays and verifies.
- The site never shows a flag or a solution.
- The site never claims to have verified anything.
- The catalogue is generated from this repository, so the two cannot drift.
- Progress reporting is a paste, and it is labelled as a paste.
