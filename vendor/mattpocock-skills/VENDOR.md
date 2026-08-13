# mattpocock/skills — vendored copy

Agent skills from [mattpocock/skills](https://github.com/mattpocock/skills)
("Skills for Real Engineers"), vendored here so every config in this repo can
symlink to a single shared source.

## Scope

Only the **promoted** buckets are vendored:

- `skills/engineering/` (18 skills) — daily code work: tdd, code-review,
  diagnosing-bugs, grill-with-docs, implement, triage, wayfinder, ...
- `skills/productivity/` (7 skills) — non-code workflow: grill-me, grilling,
  handoff, teach, writing-for-agents, ...

`misc/`, `personal/`, `in-progress/`, `deprecated/` are intentionally excluded.

## Provenance

| Field    | Value                                                       |
|----------|-------------------------------------------------------------|
| Upstream | https://github.com/mattpocock/skills                         |
| Commit   | `84fdeffd12f2` (2026-08-06)                                  |
| License  | MIT (see `LICENSE`)                                          |
| Install  | upstream recommends `npx skills@latest add mattpocock/skills` or the Claude Code plugin `mattpocock-skills` |

## Wiring

Each config (`single/skills/`, `multi/<profile>/skills/`) symlinks the skill
directories here, e.g.:

```
single/skills/tdd -> ../../vendor/mattpocock-skills/skills/engineering/tdd
multi/work/skills/tdd -> ../../../vendor/mattpocock-skills/skills/engineering/tdd
```

Opencode (and opencode-multi profiles) discover skills by scanning
`<config-dir>/skills/*/SKILL.md`; symlinked dirs are followed.

## Updating

```bash
# re-download upstream tarball into this directory
curl -sL https://codeload.github.com/mattpocock/skills/tar.gz/refs/heads/main \
  | tar xz --strip-components=1 -C vendor/mattpocock-skills --exclude='skills/misc' \
                                           --exclude='skills/personal' \
                                           --exclude='skills/in-progress' \
                                           --exclude='skills/deprecated'
# or run: bash scripts/oc-install.sh  (section [11f] does the same)
```

Then commit the update. Symlinks in the configs keep working as long as skill
directory names are unchanged (upstream renames break links — check with
`find single multi -name SKILL.md -xtype l` after upgrading).

## Notes

- The upstream repo is actively evolving; skills are periodically moved to
  `deprecated/`. Re-run the link check after every update.
- `/setup-matt-pocock-skills` is the one-time per-repo bootstrap for the
  engineering skills (issue tracker, triage labels, docs path) — run it once
  per project before using the other engineering skills.
