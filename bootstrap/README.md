# bootstrap/

Cross-platform installer and teardown scripts. Populated in PR3.

Entry points:

- `bootstrap.ps1` / `bootstrap.sh` — first-run setup (osDeps → repos → skills → agents).
- `teardown.ps1` / `teardown.sh` — clean removal of workspace artifacts (dry-run by default).
- `codex-safe.ps1` / `codex-safe.sh` — sandboxed Codex CLI launcher.

Shared helpers live in `lib/`.
