# claude-config/

Template `.claude/` deployed to the workspace root by `bootstrap`. Owned, versioned.

- `settings.json` — base Claude Code settings (no secrets).
- `CLAUDE.md` — workspace-wide context.
- `hooks/` — shared hook scripts (currently empty).

Live `.claude/` may drift from these templates after `claude login` and local edits;
`bootstrap` never overwrites existing files. See `docs/policies/skill-portability.md`
once PR6 lands.
