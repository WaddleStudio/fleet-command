# Fleet-command kernel rebuild — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure `fleet-command/` into a workspace kernel that reproduces `cardsense-workspace` on any new machine via `git clone + bootstrap`, then absorb the salvageable subset of `WaddleStudio/agent-toolkit` and delete that repo.

**Architecture:** Six sequential PRs (PR1→PR2→PR3→PR4→PR5→PR6). PR1 lays the directory skeleton without demolishing anything. PR2 evolves the manifest to v2 and adds a SHA-pinned `skills.lock.json`. PR3 lands the cross-platform bootstrap/teardown/update-skill-lock scripts — this is the portability milestone and pauses for second-machine validation. PR4 and PR5 migrate per-project material under `projects/<name>/`. PR6 absorbs the usable agent-toolkit content, then deletes the source repo and the local clone.

**Tech Stack:** Python 3.13 + `uv` (renderer, tests), PowerShell 5.1 (Windows-first scripts), Bash (macOS/Linux parity), `git`, `gh` CLI, `winget` / `brew` for OS dependencies, `unittest` for tests.

**Spec:** `fleet-command/docs/superpowers/specs/2026-05-12-fleet-command-kernel-rebuild-design.md` (§1–§13).

**Conventions binding every PR:**

- All commits made by the agent use `[agent] {type}: {description}` (e.g. `[agent] chore: scaffold kernel directory skeleton`).
- Python invocations use `uv run python …` exclusively. Never `pip`, `python -m venv`, raw `python`, or raw `pytest`.
- Branches follow `chore/…` / `feat/…` per the spec's PR table.
- Each PR is opened against `main`, reviewed by the owner, and merged before the next PR begins. Do **not** stack branches.
- Verification commands run from `fleet-command/` (repo root) unless stated.

---

## File Structure

Final shape after all 6 PRs land (see spec §5 for the full tree). Files touched in this plan:

**New top-level dirs (PR1):**
- `bootstrap/` — installer / teardown / codex-safe scripts.
- `bootstrap/lib/` — shared shell helpers (`common.ps1`, `common.sh`).
- `claude-config/` — Claude Code template files (`settings.json`, `CLAUDE.md`, `hooks/`).
- `codex-config/` — Codex CLI template files (`config.toml`, `AGENTS.md`).
- `projects/` — per-project containers (`cardsense/`, `rent-radar/`, `techtrend/`, `seedcraft/`, `godine/`, `fridgemanager/`, `knoty/`).
- `docs/arch/`, `docs/refs/`, `docs/prompts/`, `docs/policies/` — cross-project content (alongside the already-existing `docs/plans/` and `docs/superpowers/`).

**Modified single-file paths (PR2, PR4, PR5, PR6):**
- `workspace/workspace.manifest.json` — bump to v2 (add `cloneUrl`/`ref`, `agents`, `osDeps`).
- `workspace/skills.lock.json` — new file (auto-generated, committed).
- `scripts/render_workspace_assets.py` — handle v2 manifest.
- `scripts/update-skill-lock.ps1`, `scripts/update-skill-lock.sh` — new.
- `tests/test_render_workspace_assets.py` — extend for v2.
- `tests/test_bootstrap.py`, `tests/test_teardown.py`, `tests/test_update_skill_lock.py`, `tests/test_skills_lock.py` — new.
- `tests/test_dashboard_data.py` — update paths after PR4.
- `AGENTS.md` — absorb uv-enforcement and public-pc-mode sections in PR6.
- `per-repo-templates/AGENTS.md`, `per-repo-templates/CLAUDE.md`, `per-repo-templates/PROJECT_HANDOFF.md` — uv sections + first-line cross-repo reference; PROJECT_HANDOFF is new.
- `README.md` — update intro and file index after migrations.
- `WORKSPACE_CONTEXT.generated.md` — re-rendered whenever manifest changes.
- `.gitleaks.toml`, `.github/` — already untracked, formalize in PR1 via `git add`.

**Files moved or removed (PR4 + PR5):**
- `CardSense-Status.md` → `projects/cardsense/status.md`
- `CardSense-Bank-Promo-Review-Workflow.md` → `projects/cardsense/docs/bank-promo-review-workflow.md`
- `dashboard/` → `projects/cardsense/dashboard/`
- `spec-rent-radar.md` → `projects/rent-radar/spec.md`
- `techtrend/` → `projects/techtrend/`
- `arch-agent-blueprint.md` → `docs/arch/agent-blueprint.md`
- `arch-portfolio-master.md` → `docs/arch/portfolio-master.md`
- `ref-agent-cron.md` → `docs/refs/agent-cron.md`
- `ref-agent-workflow.md` → `docs/refs/agent-workflow.md`
- `prompt-agent-tasks.md` → `docs/prompts/agent-tasks.md`

**External actions (PR6 only, after push to origin/main is confirmed):**
- `gh repo delete WaddleStudio/agent-toolkit --yes`
- `Remove-Item -Recurse -Force D:\Projects\cardsense-workspace\agent-toolkit\`

---

## Pre-flight (run once before PR1)

- [ ] **P0.1: Confirm spec commit landed on a branch the owner can cherry-pick from**

Run from `fleet-command/`:

```powershell
git log --oneline -1 -- docs/superpowers/specs/2026-05-12-fleet-command-kernel-rebuild-design.md
git status -sb
```

Expected: the spec commit (`7aa9f3b [agent] docs: add fleet-command kernel rebuild design spec`) is present. The current branch is `feat/merchant-search-category-facet` with the spec already committed but unpushed.

Decide with the owner whether to:

1. Cherry-pick the spec commit onto a fresh `chore/kernel-spec` branch, push, and PR it (so the spec lives on `main` before PR1).
2. Or, branch each PR off the existing branch tip after the spec commit, accepting that the spec ships as part of PR1.

Default (recommended): option 1 — keep the spec landing isolated from any structural change, so PR1 only adds dirs.

- [ ] **P0.2: Confirm the active feature branch's working tree is clean OR the owner has agreed to set those changes aside**

Run:

```powershell
git status -sb
```

Expected: no `modified:` or `Untracked files:` other than what the owner expects (currently `CardSense-Status.md`, `dashboard/data/checks.json`, `.github/`, `.gitleaks.toml`, `agent-log/2026-05-11.md`). Do not touch these — they belong to the merchant-search-category-facet work. Stash, commit, or branch them per owner's instruction before starting PR1.

- [ ] **P0.3: Resolve upstream skill SHAs (used in PR2)**

Run from anywhere on PATH-with-git:

```powershell
git ls-remote https://github.com/obra/superpowers.git refs/tags/v5.0.7
git ls-remote https://github.com/garrytan/gstack.git HEAD
git ls-remote https://github.com/nextlevelbuilder/ui-ux-pro-max-skill.git refs/tags/v2.5.0
```

Record the three resulting 40-character SHAs. They land in `workspace/skills.lock.json` in PR2. If any URL has changed, ask the owner before substituting.

---

## PR1 — Kernel skeleton

**Branch:** `chore/kernel-skeleton`
**Scope:** Empty directories + stub `README.md` placeholders so git tracks them. Zero file demolition. Renderer and existing tests pass unchanged. Reference: spec §4–§5, §10 (PR1 entry).

### Task PR1.1: Create the feature branch from `main`

**Files:** none

- [ ] **Step 1: Cut the branch**

```powershell
git fetch origin
git switch -c chore/kernel-skeleton origin/main
```

- [ ] **Step 2: Confirm clean tree**

```powershell
git status -sb
```

Expected: `## chore/kernel-skeleton`, nothing else.

### Task PR1.2: Add the bootstrap directory skeleton

**Files:**
- Create: `bootstrap/README.md`
- Create: `bootstrap/lib/README.md`

- [ ] **Step 1: Write `bootstrap/README.md`**

```markdown
# bootstrap/

Cross-platform installer and teardown scripts. Populated in PR3.

Entry points:

- `bootstrap.ps1` / `bootstrap.sh` — first-run setup (osDeps → repos → skills → agents).
- `teardown.ps1` / `teardown.sh` — clean removal of workspace artifacts (dry-run by default).
- `codex-safe.ps1` / `codex-safe.sh` — sandboxed Codex CLI launcher.

Shared helpers live in `lib/`.
```

- [ ] **Step 2: Write `bootstrap/lib/README.md`**

```markdown
# bootstrap/lib/

Shell helpers shared between bootstrap and teardown scripts. Populated in PR3.
```

- [ ] **Step 3: Stage and confirm**

```powershell
git add bootstrap/README.md bootstrap/lib/README.md
git status -sb
```

Expected: two new files under `bootstrap/`.

### Task PR1.3: Add the claude-config and codex-config skeletons

**Files:**
- Create: `claude-config/README.md`
- Create: `claude-config/hooks/.gitkeep`
- Create: `codex-config/README.md`

- [ ] **Step 1: Write `claude-config/README.md`**

```markdown
# claude-config/

Template `.claude/` deployed to the workspace root by `bootstrap`. Owned, versioned.

- `settings.json` — base Claude Code settings (no secrets).
- `CLAUDE.md` — workspace-wide context.
- `hooks/` — shared hook scripts (currently empty).

Live `.claude/` may drift from these templates after `claude login` and local edits;
`bootstrap` never overwrites existing files. See `docs/policies/skill-portability.md`
once PR6 lands.
```

- [ ] **Step 2: Write `claude-config/hooks/.gitkeep`** (empty file)

- [ ] **Step 3: Write `codex-config/README.md`**

```markdown
# codex-config/

Template `.codex/` deployed to the workspace root by `bootstrap`. Owned, versioned.

- `config.toml` — Codex CLI settings (`sandbox = workspace-write`, `approval = always`).
- `AGENTS.md` — content-aligned with `claude-config/CLAUDE.md`.
```

- [ ] **Step 4: Stage**

```powershell
git add claude-config codex-config
```

### Task PR1.4: Add the projects/ skeleton with per-project placeholder directories

**Files:**
- Create: `projects/README.md`
- Create: `projects/{cardsense,rent-radar,techtrend,seedcraft,godine,fridgemanager,knoty}/.gitkeep`

- [ ] **Step 1: Write `projects/README.md`**

```markdown
# projects/

Per-project material that does not belong in the project's own code repo:
spec excerpts, status notes, dashboards, project-private docs.

One subdirectory per project. CardSense is a peer of the others — there are no
top-level CardSense files in `fleet-command/`.

Cross-project content (architecture, refs, prompts, policies) lives in `../docs/`.
```

- [ ] **Step 2: Create placeholder files**

```powershell
"cardsense","rent-radar","techtrend","seedcraft","godine","fridgemanager","knoty" | ForEach-Object {
  New-Item -ItemType Directory -Path "projects/$_" -Force | Out-Null
  New-Item -ItemType File -Path "projects/$_/.gitkeep" -Force | Out-Null
}
```

- [ ] **Step 3: Stage**

```powershell
git add projects/
git status -sb
```

Expected: `projects/README.md` and seven `.gitkeep` files.

### Task PR1.5: Add the docs/ subdirectory skeleton

**Files:**
- Create: `docs/arch/.gitkeep`
- Create: `docs/refs/.gitkeep`
- Create: `docs/prompts/.gitkeep`
- Create: `docs/policies/.gitkeep`
- Modify (read-only check): `docs/superpowers/specs/` already exists; do not touch.

- [ ] **Step 1: Create directories**

```powershell
"arch","refs","prompts","policies" | ForEach-Object {
  New-Item -ItemType Directory -Path "docs/$_" -Force | Out-Null
  New-Item -ItemType File -Path "docs/$_/.gitkeep" -Force | Out-Null
}
```

- [ ] **Step 2: Stage**

```powershell
git add docs/arch docs/refs docs/prompts docs/policies
```

### Task PR1.6: Verify existing tests still pass

**Files:** none (verification only)

- [ ] **Step 1: Run the renderer in check mode**

```powershell
uv run python scripts/render_workspace_assets.py --check
```

Expected: exit 0 with `workspace assets are up to date` (no manifest changes yet).

- [ ] **Step 2: Run unit tests**

```powershell
uv run python -m unittest discover tests
```

Expected: all tests pass (5 tests in `test_dashboard_data.py`, 2 in `test_render_workspace_assets.py`).

### Task PR1.7: Commit and push PR1

**Files:** none (git only)

- [ ] **Step 1: Stage anything not yet added**

```powershell
git add bootstrap claude-config codex-config projects docs/arch docs/refs docs/prompts docs/policies
git status -sb
```

- [ ] **Step 2: Commit**

```powershell
git commit -m "[agent] chore: scaffold kernel directory skeleton"
```

- [ ] **Step 3: Push**

```powershell
git push -u origin chore/kernel-skeleton
```

- [ ] **Step 4: Open PR**

```powershell
gh pr create --title "[PR1] Scaffold kernel directory skeleton" --body @'
Scope: empty top-level directories with stub READMEs / .gitkeep so the kernel
layout exists in git. No file moves, no demolition, no behavior change.

Tracks: docs/superpowers/specs/2026-05-12-fleet-command-kernel-rebuild-design.md
PR breakdown §10, PR1.

Verification:
- `uv run python scripts/render_workspace_assets.py --check` clean
- `uv run python -m unittest discover tests` all pass
'@
```

- [ ] **Step 5: Pause for owner review and merge to `main`** before continuing to PR2.

---

## PR2 — Manifest schema v2 + skills.lock + renderer

**Branch:** `chore/manifest-schema-v2`
**Scope:** Bump `workspace.manifest.json` to v2 (add `cloneUrl`/`ref` per repo, `agents`, `osDeps`). Add `workspace/skills.lock.json`. Extend renderer for v2. Extend tests. Reference: spec §6, §10 (PR2 entry).

### Task PR2.1: Cut the branch from updated `main`

**Files:** none

- [ ] **Step 1: Pull latest main**

```powershell
git switch main
git pull origin main
git switch -c chore/manifest-schema-v2
```

### Task PR2.2: Write failing renderer tests for v2 manifest

**Files:**
- Modify: `tests/test_render_workspace_assets.py`

- [ ] **Step 1: Append a new test method to `RenderWorkspaceAssetsTest` reading a v2 manifest**

After the existing `test_check_mode_reports_drift_without_writing_files` method, add:

```python
    def _write_manifest_v2(self, workspace: Path) -> Path:
        fleet_command = workspace / "fleet-command"
        manifest_dir = fleet_command / "workspace"
        manifest_dir.mkdir(parents=True)
        (workspace / "cardsense-api").mkdir()

        manifest = {
            "version": 2,
            "workspace": {"name": "cardsense-workspace", "rootRgignorePath": ".rgignore"},
            "policies": [],
            "branchTypes": [{"id": "feat", "description": "x"}],
            "completionFlow": {"sourceDoc": "fleet-command/AGENTS.md", "summary": []},
            "ignore": {"patterns": ["**/.git/"]},
            "repos": [
                {
                    "name": "cardsense-api",
                    "path": "cardsense-api",
                    "cloneUrl": "https://github.com/WaddleStudio/cardsense-api.git",
                    "ref": "main",
                    "purpose": "Recommendation API",
                    "role": "runtime",
                    "generatedContextPath": "WORKSPACE_CONTEXT.generated.md",
                    "keyFiles": ["README.md"],
                    "commands": {"verify": ["mvn test"]},
                },
            ],
            "agents": {
                "claude": {
                    "target": ".claude",
                    "templateSource": "fleet-command/claude-config",
                    "skillsTarget": ".claude/skills",
                    "files": ["settings.json", "CLAUDE.md"],
                },
            },
            "osDeps": {
                "windows": {
                    "manager": "winget",
                    "packages": [{"id": "Git.Git", "verifyCmd": "git --version"}],
                },
            },
        }
        manifest_path = manifest_dir / "workspace.manifest.json"
        manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
        return manifest_path

    def test_v2_manifest_renders_repo_context_with_clone_url(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            workspace = Path(tmp)
            manifest_path = self._write_manifest_v2(workspace)

            render_workspace_assets(manifest_path)

            api_context = (workspace / "cardsense-api" / "WORKSPACE_CONTEXT.generated.md").read_text(encoding="utf-8")
            self.assertIn("Recommendation API", api_context)
            self.assertIn("mvn test", api_context)
```

- [ ] **Step 2: Run and confirm it passes already (the new fields are additive)**

```powershell
uv run python -m unittest tests.test_render_workspace_assets -v
```

Expected: 3 tests pass. The renderer currently ignores unknown keys, so v2 should work out of the box. If it fails, the renderer needs adjustment in a later task.

### Task PR2.3: Write failing test for v2-only required fields

**Files:**
- Modify: `tests/test_render_workspace_assets.py`

- [ ] **Step 1: Add a strict-validation test that v2 manifests must declare `cloneUrl` and `ref` per repo**

Append to the test class:

```python
    def test_v2_manifest_rejects_repo_without_clone_url(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            workspace = Path(tmp)
            manifest_path = self._write_manifest_v2(workspace)
            # Strip cloneUrl from the single repo
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            del manifest["repos"][0]["cloneUrl"]
            manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")

            with self.assertRaises(ValueError) as ctx:
                render_workspace_assets(manifest_path)
            self.assertIn("cloneUrl", str(ctx.exception))
```

- [ ] **Step 2: Run — must FAIL**

```powershell
uv run python -m unittest tests.test_render_workspace_assets.RenderWorkspaceAssetsTest.test_v2_manifest_rejects_repo_without_clone_url -v
```

Expected: FAIL — no validation yet. Capture the failure message.

### Task PR2.4: Implement minimal v2 validation in the renderer

**Files:**
- Modify: `scripts/render_workspace_assets.py`

- [ ] **Step 1: Add a validation function before `render_workspace_assets`**

Insert after `_write_or_check`:

```python
def _validate_manifest(manifest: dict[str, Any]) -> None:
    version = manifest.get("version", 1)
    if version < 2:
        return
    for repo in manifest.get("repos", []):
        if "cloneUrl" not in repo:
            raise ValueError(
                f"v2 manifest repo '{repo.get('name', '<unnamed>')}' is missing required field 'cloneUrl'"
            )
        if "ref" not in repo:
            raise ValueError(
                f"v2 manifest repo '{repo.get('name', '<unnamed>')}' is missing required field 'ref'"
            )
```

- [ ] **Step 2: Call validator from `render_workspace_assets`**

Replace the body of `render_workspace_assets` with:

```python
def render_workspace_assets(manifest_path: Path, check: bool = False) -> bool:
    manifest_path = manifest_path.resolve()
    manifest = load_manifest(manifest_path)
    _validate_manifest(manifest)
    workspace_root = manifest_path.parents[2]
    is_clean = True

    for repo in manifest["repos"]:
        repo_root = workspace_root / repo["path"]
        context_path = repo_root / repo["generatedContextPath"]
        expected = render_repo_context(manifest, repo)
        is_clean = _write_or_check(context_path, expected, check) and is_clean

    rgignore_path = workspace_root / manifest["workspace"]["rootRgignorePath"]
    rgignore = render_rgignore(manifest["ignore"]["patterns"])
    is_clean = _write_or_check(rgignore_path, rgignore, check) and is_clean
    return is_clean
```

- [ ] **Step 3: Re-run the failing test — must PASS**

```powershell
uv run python -m unittest tests.test_render_workspace_assets -v
```

Expected: 4 tests pass.

### Task PR2.5: Bump the live `workspace/workspace.manifest.json` to v2

**Files:**
- Modify: `workspace/workspace.manifest.json`

- [ ] **Step 1: Edit the file to v2**

The new file content (replace the existing 176-line file):

```json
{
  "version": 2,
  "workspace": {
    "name": "cardsense-workspace",
    "sourceOfTruthRepo": "fleet-command",
    "rootRgignorePath": ".rgignore",
    "notes": [
      "Read generated repo context before scanning long status documents.",
      "Use fleet-command as the control plane for cross-repo workflow and conventions."
    ]
  },
  "policies": [
    { "id": "python-package-management", "title": "Python package management", "rule": "Use uv for Python dependency management and Python command execution across the workspace." },
    { "id": "browser-verification", "title": "Browser verification", "rule": "Use installed Google Chrome via gstack/browser for browser smoke tests; only fall back to another browser when Chrome is unavailable and report the fallback." },
    { "id": "git-pr-closeout", "title": "Git and PR closeout", "rule": "Do implementation work on a task branch, verify before commit, commit by repo, push the branch, and create or update the PR when remote access is available." },
    { "id": "development-cli-checks", "title": "Development CLI checks", "rule": "Use cardsense-dev-checks during development for targeted tests, curl API smoke checks, Chrome/gstack browser checks, gh PR/CI inspection, and read-only deployment inspection." }
  ],
  "branchTypes": [
    { "id": "feat", "description": "New feature or user-visible capability increase." },
    { "id": "fix", "description": "Bug fix or regression repair." },
    { "id": "chore", "description": "Docs, config, generated files, workflow, maintenance, or non-behavior refactor." },
    { "id": "wip", "description": "Exploratory or intentionally incomplete work that should stay isolated." }
  ],
  "completionFlow": {
    "sourceDoc": "fleet-command/AGENTS.md",
    "summary": [
      "Run verification first.",
      "Run cardsense-workspace-completion before ending every CardSense workspace task; use fleet-dashboard-closeout for dashboard-specific details.",
      "Use cardsense-dev-checks during development for frequent CLI/API test and confirmation flows.",
      "Use uv for Python commands and Chrome via gstack/browser for browser checks.",
      "Confirm the task branch, commit verified changes, push, and create or update the PR when remote access is available.",
      "Update fleet-command when workflow, architecture, or workspace rules changed.",
      "Re-render workspace assets when the manifest or generated context changed.",
      "Organize branches by repo + branch type + shared slug.",
      "Batch commit by repo.",
      "Batch push by repo."
    ]
  },
  "ignore": {
    "patterns": [
      "**/.git/",
      "**/.worktrees/",
      "**/node_modules/",
      "**/dist/",
      "**/.superpowers/brainstorm/",
      "**/.claude/skills/gstack/",
      "**/.uv-cache/",
      "**/.vite-*.log",
      "**/outputs/*.jsonl",
      "**/.github/java-upgrade/"
    ]
  },
  "repos": [
    {
      "name": "fleet-command",
      "path": "fleet-command",
      "cloneUrl": "https://github.com/WaddleStudio/fleet-command.git",
      "ref": "main",
      "purpose": "Workspace control plane, specs, agent rules, and shared skills",
      "role": "control-plane",
      "generatedContextPath": "WORKSPACE_CONTEXT.generated.md",
      "keyFiles": ["README.md", "AGENTS.md", "projects/cardsense/status.md"],
      "commands": {
        "verify": [
          "uv run python scripts/render_workspace_assets.py --check",
          "uv run python -m unittest tests.test_dashboard_data",
          "uv run python -m unittest tests.test_render_workspace_assets"
        ]
      }
    },
    {
      "name": "cardsense-contracts",
      "path": "cardsense-contracts",
      "cloneUrl": "https://github.com/WaddleStudio/cardsense-contracts.git",
      "ref": "main",
      "purpose": "Shared contracts, schemas, and taxonomies for CardSense repos",
      "role": "contracts",
      "generatedContextPath": "WORKSPACE_CONTEXT.generated.md",
      "keyFiles": ["README.md", "VIBE_SPEC.md", "promotion/promotion-normalized.schema.json", "recommendation/recommendation-request.schema.json", "recommendation/recommendation-response.schema.json"],
      "commands": { "verify": ["rg -n \"TRAVEL\" promotion recommendation taxonomy"] }
    },
    {
      "name": "cardsense-extractor",
      "path": "cardsense-extractor",
      "cloneUrl": "https://github.com/WaddleStudio/cardsense-extractor.git",
      "ref": "main",
      "purpose": "Promotion extraction, normalization, import, and sync pipeline",
      "role": "data-pipeline",
      "generatedContextPath": "WORKSPACE_CONTEXT.generated.md",
      "keyFiles": ["README.md", "VIBE_SPEC.md", "skills/cardsense-bank-promo-review/SKILL.md", "extractor/promotion_rules.py", "jobs/refresh_and_deploy.py"],
      "commands": { "verify": ["uv run pytest", "uv run python jobs/refresh_and_deploy.py --help"] }
    },
    {
      "name": "cardsense-api",
      "path": "cardsense-api",
      "cloneUrl": "https://github.com/WaddleStudio/cardsense-api.git",
      "ref": "main",
      "purpose": "Deterministic recommendation API runtime and repository adapters",
      "role": "runtime",
      "generatedContextPath": "WORKSPACE_CONTEXT.generated.md",
      "keyFiles": ["README.md", "VIBE_SPEC.md", "src/main/java/com/cardsense/api/service/DecisionEngine.java"],
      "commands": { "verify": ["mvn test"] }
    },
    {
      "name": "cardsense-web",
      "path": "cardsense-web",
      "cloneUrl": "https://github.com/WaddleStudio/cardsense-web.git",
      "ref": "main",
      "purpose": "Frontend recommendation UX and calc surface",
      "role": "frontend",
      "generatedContextPath": "WORKSPACE_CONTEXT.generated.md",
      "keyFiles": ["README.md", "src/lib/taxonomy.ts", "src/types/enums.ts"],
      "commands": { "verify": ["npm run build"] }
    }
  ],
  "agents": {
    "claude": {
      "target": ".claude",
      "templateSource": "fleet-command/claude-config",
      "skillsTarget": ".claude/skills",
      "files": ["settings.json", "CLAUDE.md"]
    },
    "codex": {
      "target": ".codex",
      "templateSource": "fleet-command/codex-config",
      "files": ["config.toml", "AGENTS.md"]
    }
  },
  "osDeps": {
    "windows": {
      "manager": "winget",
      "packages": [
        { "id": "Git.Git", "verifyCmd": "git --version" },
        { "id": "OpenJS.NodeJS.LTS", "verifyCmd": "node --version", "minVersion": "20" },
        { "id": "Oven-sh.Bun", "verifyCmd": "bun --version" },
        { "id": "Python.Python.3.13", "verifyCmd": "python --version" },
        { "id": "astral-sh.uv", "verifyCmd": "uv --version" },
        { "id": "Anthropic.Claude", "verifyCmd": "claude --version", "optional": true }
      ]
    },
    "macos": {
      "manager": "brew",
      "packages": [
        { "id": "git", "verifyCmd": "git --version" },
        { "id": "node", "verifyCmd": "node --version" },
        { "id": "bun", "verifyCmd": "bun --version" },
        { "id": "python@3.13", "verifyCmd": "python3 --version" },
        { "id": "uv", "verifyCmd": "uv --version" }
      ]
    },
    "linux": {
      "manager": "manual",
      "note": "Verify commands only; install via distro PM / mise / asdf."
    }
  }
}
```

> Note: `keyFiles[]` for fleet-command references `projects/cardsense/status.md` even though PR4 has not migrated it yet. This is intentional — by the time bootstrap reads the manifest in PR3 the file still lives at `CardSense-Status.md`, but `keyFiles` is only used by `render_repo_context()`, which lists the path as text without verifying existence. PR4 will create the file at the new path.

- [ ] **Step 2: Re-render the workspace context to absorb the v2 manifest**

```powershell
uv run python scripts/render_workspace_assets.py
```

Expected: `workspace assets rendered`. Inspect `WORKSPACE_CONTEXT.generated.md` for a diff and confirm it still makes sense.

- [ ] **Step 3: Confirm check mode is clean**

```powershell
uv run python scripts/render_workspace_assets.py --check
```

Expected: `workspace assets are up to date`.

### Task PR2.6: Add `workspace/skills.lock.json` with three resolved SHAs

**Files:**
- Create: `workspace/skills.lock.json`

- [ ] **Step 1: Write the lock file using SHAs gathered in P0.3**

Replace `<SUPERPOWERS_SHA>`, `<GSTACK_SHA>`, `<UI_UX_PRO_MAX_SHA>` with the 40-char SHAs from P0.3.

```json
{
  "version": 1,
  "generatedAt": "2026-05-12",
  "skills": [
    {
      "id": "superpowers",
      "cloneUrl": "https://github.com/obra/superpowers.git",
      "target": ".claude/skills/superpowers",
      "host": "claude",
      "role": "engineering_workflow",
      "ref": { "sha": "<SUPERPOWERS_SHA>", "tag": "v5.0.7", "resolvedAt": "2026-05-12" }
    },
    {
      "id": "gstack",
      "cloneUrl": "https://github.com/garrytan/gstack.git",
      "target": ".claude/skills/gstack",
      "host": "claude",
      "role": "planning_review_browser_qa",
      "ref": { "sha": "<GSTACK_SHA>", "tag": null, "resolvedAt": "2026-05-12" },
      "postClone": [{ "cmd": "./setup", "cwd": ".claude/skills/gstack" }]
    },
    {
      "id": "ui-ux-pro-max",
      "cloneUrl": "https://github.com/nextlevelbuilder/ui-ux-pro-max-skill.git",
      "target": ".claude/skills/ui-ux-pro-max",
      "host": "claude",
      "role": "product_design",
      "ref": { "sha": "<UI_UX_PRO_MAX_SHA>", "tag": "v2.5.0", "resolvedAt": "2026-05-12" }
    }
  ]
}
```

- [ ] **Step 2: Stage**

```powershell
git add workspace/skills.lock.json
```

### Task PR2.7: Add a schema test for skills.lock.json

**Files:**
- Create: `tests/test_skills_lock.py`

- [ ] **Step 1: Write the test**

```python
import json
import re
import unittest
from pathlib import Path


LOCK_PATH = Path(__file__).resolve().parents[1] / "workspace" / "skills.lock.json"
SHA_RE = re.compile(r"^[0-9a-f]{40}$")


class SkillsLockTest(unittest.TestCase):
    def setUp(self) -> None:
        self.lock = json.loads(LOCK_PATH.read_text(encoding="utf-8"))

    def test_lock_version_is_one(self) -> None:
        self.assertEqual(self.lock["version"], 1)

    def test_each_skill_has_required_fields(self) -> None:
        required = {"id", "cloneUrl", "target", "host", "role", "ref"}
        for skill in self.lock["skills"]:
            self.assertTrue(required.issubset(skill), skill)

    def test_each_ref_has_40_char_sha(self) -> None:
        for skill in self.lock["skills"]:
            sha = skill["ref"]["sha"]
            self.assertTrue(SHA_RE.match(sha), f"{skill['id']} sha invalid: {sha!r}")

    def test_three_known_skills_present(self) -> None:
        ids = {skill["id"] for skill in self.lock["skills"]}
        self.assertEqual(ids, {"superpowers", "gstack", "ui-ux-pro-max"})


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the new test — must PASS**

```powershell
uv run python -m unittest tests.test_skills_lock -v
```

Expected: 4 tests pass. If SHA regex fails, the placeholders in step PR2.6 were not replaced — go back and fix.

### Task PR2.8: Full PR2 verification

**Files:** none

- [ ] **Step 1: Renderer check**

```powershell
uv run python scripts/render_workspace_assets.py --check
```

Expected: clean.

- [ ] **Step 2: Full test discovery**

```powershell
uv run python -m unittest discover tests
```

Expected: all tests pass (existing dashboard + render + new skills.lock + new v2 cases).

### Task PR2.9: Commit and push PR2

- [ ] **Step 1: Inspect diff**

```powershell
git status -sb
git diff --stat origin/main..HEAD
```

- [ ] **Step 2: Commit**

```powershell
git add tests/test_skills_lock.py tests/test_render_workspace_assets.py scripts/render_workspace_assets.py workspace/workspace.manifest.json workspace/skills.lock.json WORKSPACE_CONTEXT.generated.md .rgignore
git commit -m "[agent] chore: manifest schema v2 + skills.lock + renderer validation"
```

- [ ] **Step 3: Push**

```powershell
git push -u origin chore/manifest-schema-v2
```

- [ ] **Step 4: Open PR and pause for owner review/merge.**

```powershell
gh pr create --title "[PR2] Manifest schema v2 + skills.lock" --body @'
Scope:
- Bump workspace.manifest.json to version 2; add cloneUrl/ref per repo, agents, osDeps.
- Add workspace/skills.lock.json with three SHA-pinned upstream skills.
- Extend renderer to validate v2 required fields.
- Extend tests; add test_skills_lock.py.

Verification:
- `uv run python scripts/render_workspace_assets.py --check` clean
- `uv run python -m unittest discover tests` all pass
'@
```

---

## PR3 — Bootstrap / teardown / update-skill-lock implementation

**Branch:** `feat/bootstrap-teardown`
**Scope:** Replace stub READMEs with working scripts. Add tests that exercise each script as a subprocess. Reference: spec §7, §10 (PR3 entry).

> **MILESTONE — PORTABILITY GATE**
>
> After PR3 merges to `main`, **STOP**. The owner will clone the repo on a second
> machine and run bootstrap end-to-end. Do **not** start PR4 until the owner
> reports back that PR3 worked on the second machine (or until they explicitly
> tell you to proceed despite a failure).

### Task PR3.1: Cut the branch

- [ ] **Step 1**

```powershell
git switch main
git pull origin main
git switch -c feat/bootstrap-teardown
```

### Task PR3.2: Write failing test for `bootstrap/lib/common.ps1` resolve-workspace helper

**Files:**
- Create: `tests/test_bootstrap.py`

- [ ] **Step 1: Write the first subprocess test**

```python
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
BOOTSTRAP_PS1 = REPO_ROOT / "bootstrap" / "bootstrap.ps1"
BOOTSTRAP_SH = REPO_ROOT / "bootstrap" / "bootstrap.sh"


def _has_pwsh() -> bool:
    return shutil.which("pwsh") is not None or shutil.which("powershell") is not None


def _has_bash() -> bool:
    return shutil.which("bash") is not None


def _run_ps(args: list[str], cwd: Path) -> subprocess.CompletedProcess:
    pwsh = shutil.which("pwsh") or shutil.which("powershell")
    return subprocess.run(
        [pwsh, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(BOOTSTRAP_PS1), *args],
        cwd=str(cwd),
        capture_output=True,
        text=True,
    )


def _run_sh(args: list[str], cwd: Path) -> subprocess.CompletedProcess:
    bash = shutil.which("bash")
    return subprocess.run(
        [bash, str(BOOTSTRAP_SH), *args],
        cwd=str(cwd),
        capture_output=True,
        text=True,
    )


class BootstrapDryRunTest(unittest.TestCase):
    @unittest.skipUnless(_has_pwsh(), "PowerShell not on PATH")
    def test_ps1_dry_run_lists_intended_repo_clones_and_skill_clones(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            workspace = Path(tmp)
            fc = workspace / "fleet-command"
            shutil.copytree(REPO_ROOT, fc, ignore=shutil.ignore_patterns(".git", ".worktrees", ".uv-cache"))

            result = _run_ps(["--dry-run", "--workspace", str(workspace), "--verbose"], cwd=fc)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("cardsense-api", result.stdout)
            self.assertIn("superpowers", result.stdout)
            self.assertIn("dry-run", result.stdout.lower())


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run — must FAIL because bootstrap.ps1 does not exist**

```powershell
uv run python -m unittest tests.test_bootstrap -v
```

Expected: FAIL with file-not-found / missing script.

### Task PR3.3: Implement `bootstrap/lib/common.ps1` (shared PowerShell helpers)

**Files:**
- Create: `bootstrap/lib/common.ps1`
- Delete: `bootstrap/lib/README.md` (no longer placeholder)

- [ ] **Step 1: Write common.ps1**

```powershell
# bootstrap/lib/common.ps1 — shared helpers for bootstrap / teardown / update-skill-lock.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-WorkspaceRoot {
    param(
        [Parameter(Mandatory = $false)] [string] $Override
    )
    if ($Override) {
        $resolved = (Resolve-Path -LiteralPath $Override).Path
    } else {
        $scriptDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $resolved = (Resolve-Path -LiteralPath (Join-Path $scriptDir '..')).Path
    }
    if (-not (Test-Path -LiteralPath $resolved -PathType Container)) {
        throw "Workspace path does not exist or is not a directory: $resolved"
    }
    return $resolved
}

function Read-Manifest {
    param([Parameter(Mandatory = $true)] [string] $WorkspaceRoot)
    $path = Join-Path $WorkspaceRoot 'fleet-command/workspace/workspace.manifest.json'
    if (-not (Test-Path -LiteralPath $path)) {
        throw "workspace.manifest.json not found at $path"
    }
    return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
}

function Read-SkillsLock {
    param([Parameter(Mandatory = $true)] [string] $WorkspaceRoot)
    $path = Join-Path $WorkspaceRoot 'fleet-command/workspace/skills.lock.json'
    if (-not (Test-Path -LiteralPath $path)) {
        throw "skills.lock.json not found at $path"
    }
    return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
}

function Write-Stage {
    param([Parameter(Mandatory = $true)] [string] $Name)
    Write-Host ""
    Write-Host "=== $Name ===" -ForegroundColor Cyan
}

function Write-DryRun {
    param([Parameter(Mandatory = $true)] [string] $Message)
    Write-Host "[dry-run] $Message" -ForegroundColor Yellow
}

function Test-CommandRuns {
    param([Parameter(Mandatory = $true)] [string] $Command)
    try {
        $null = Invoke-Expression $Command 2>&1
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

function Get-OSKey {
    if ($IsWindows -or ($PSVersionTable.PSEdition -eq 'Desktop')) { return 'windows' }
    if ($IsMacOS) { return 'macos' }
    return 'linux'
}
```

- [ ] **Step 2: Remove the placeholder README**

```powershell
git rm bootstrap/lib/README.md
```

### Task PR3.4: Implement `bootstrap/lib/common.sh` (shared bash helpers)

**Files:**
- Create: `bootstrap/lib/common.sh`

- [ ] **Step 1: Write common.sh**

```bash
#!/usr/bin/env bash
# bootstrap/lib/common.sh — shared helpers for bootstrap / teardown / update-skill-lock.

set -euo pipefail

resolve_workspace_root() {
  local override="${1:-}"
  local resolved
  if [[ -n "$override" ]]; then
    resolved="$(cd "$override" && pwd -P)"
  else
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
    resolved="$(cd "$script_dir/.." && pwd -P)"
  fi
  if [[ ! -d "$resolved" ]]; then
    echo "Workspace path does not exist: $resolved" >&2
    return 1
  fi
  printf '%s' "$resolved"
}

read_manifest() {
  local ws="$1"
  local path="$ws/fleet-command/workspace/workspace.manifest.json"
  if [[ ! -f "$path" ]]; then
    echo "workspace.manifest.json not found at $path" >&2
    return 1
  fi
  cat "$path"
}

read_skills_lock() {
  local ws="$1"
  local path="$ws/fleet-command/workspace/skills.lock.json"
  if [[ ! -f "$path" ]]; then
    echo "skills.lock.json not found at $path" >&2
    return 1
  fi
  cat "$path"
}

write_stage() {
  printf '\n=== %s ===\n' "$1"
}

write_dry_run() {
  printf '[dry-run] %s\n' "$1"
}

get_os_key() {
  case "$(uname -s)" in
    Darwin*) echo macos ;;
    Linux*)  echo linux ;;
    MINGW*|MSYS*|CYGWIN*) echo windows ;;
    *) echo unknown ;;
  esac
}

require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required by bootstrap/teardown scripts on Unix." >&2
    echo "Install via:  brew install jq  (macOS)  or  apt-get install jq  (Linux)" >&2
    return 1
  fi
}
```

### Task PR3.5: Implement `bootstrap/bootstrap.ps1` (Windows-first installer)

**Files:**
- Create: `bootstrap/bootstrap.ps1`
- Delete: `bootstrap/README.md` (replaced by inline help)

- [ ] **Step 1: Write bootstrap.ps1**

```powershell
# bootstrap/bootstrap.ps1 — workspace installer for Windows / macOS / Linux (PowerShell 7+).
[CmdletBinding()]
param(
    [switch] $InstallDeps,
    [switch] $SkipDeps,
    [switch] $SkipSkills,
    [switch] $SkipRepos,
    [switch] $SkipAgents,
    [switch] $Update,
    [switch] $DryRun,
    [string] $Workspace,
    [switch] $Verbose
)

. (Join-Path $PSScriptRoot 'lib/common.ps1')

$workspaceRoot = Resolve-WorkspaceRoot -Override $Workspace
$manifest = Read-Manifest -WorkspaceRoot $workspaceRoot
$skillsLock = Read-SkillsLock -WorkspaceRoot $workspaceRoot
$osKey = Get-OSKey

Write-Host "Workspace: $workspaceRoot"
Write-Host "OS:        $osKey"
Write-Host "Mode:      $(if ($DryRun) { 'dry-run' } else { 'apply' })"

# --- Stage 1: osDeps ---------------------------------------------------------
function Invoke-OsDepsStage {
    Write-Stage 'Stage 1: OS dependencies'
    $osDeps = $manifest.osDeps.$osKey
    if (-not $osDeps) {
        Write-Host "No osDeps declared for $osKey; skipping."
        return
    }
    $missing = @()
    foreach ($pkg in $osDeps.packages) {
        $ok = Test-CommandRuns $pkg.verifyCmd
        if ($ok) {
            Write-Host "[ok]   $($pkg.id)"
        } else {
            if ($pkg.optional) {
                Write-Host "[skip] $($pkg.id) (optional, not installed)"
            } else {
                Write-Host "[miss] $($pkg.id)" -ForegroundColor Yellow
                $missing += $pkg
            }
        }
    }
    if ($missing.Count -eq 0) { return }
    if (-not $InstallDeps) {
        Write-Host ""
        Write-Host "Missing packages above. Re-run with -InstallDeps to install via $($osDeps.manager)." -ForegroundColor Yellow
        return
    }
    foreach ($pkg in $missing) {
        if ($DryRun) {
            Write-DryRun "$($osDeps.manager) install $($pkg.id)"
        } else {
            switch ($osDeps.manager) {
                'winget' { winget install --id $pkg.id --silent --accept-package-agreements --accept-source-agreements }
                'brew'   { brew install $pkg.id }
                default  { Write-Host "Manager '$($osDeps.manager)' not yet supported; install manually: $($pkg.id)" }
            }
        }
    }
}

# --- Stage 2: Repos ----------------------------------------------------------
function Invoke-ReposStage {
    Write-Stage 'Stage 2: Sub-repositories'
    foreach ($repo in $manifest.repos) {
        if ($repo.name -eq 'fleet-command') {
            Write-Host "[self] fleet-command (already cloned)"
            continue
        }
        $target = Join-Path $workspaceRoot $repo.path
        if (-not (Test-Path -LiteralPath $target)) {
            if ($DryRun) {
                Write-DryRun "git clone --branch $($repo.ref) $($repo.cloneUrl) $target"
            } else {
                git clone --branch $repo.ref $repo.cloneUrl $target
            }
            continue
        }
        Push-Location $target
        try {
            $current = (git rev-parse --abbrev-ref HEAD).Trim()
            if ($current -ne $repo.ref) {
                Write-Host "[drift] $($repo.name): on '$current', manifest says '$($repo.ref)'" -ForegroundColor Yellow
                if ($Update -and -not $DryRun) {
                    git fetch origin
                    git switch $repo.ref
                    git pull --ff-only
                } elseif ($Update -and $DryRun) {
                    Write-DryRun "git switch $($repo.ref) && git pull --ff-only ($target)"
                }
            } else {
                Write-Host "[ok]    $($repo.name) on $current"
            }
        } finally {
            Pop-Location
        }
    }
}

# --- Stage 3: Skills ---------------------------------------------------------
function Invoke-SkillsStage {
    Write-Stage 'Stage 3: Upstream skills'
    foreach ($skill in $skillsLock.skills) {
        $target = Join-Path $workspaceRoot $skill.target
        $expectedSha = $skill.ref.sha
        if (-not (Test-Path -LiteralPath $target)) {
            if ($DryRun) {
                Write-DryRun "git clone $($skill.cloneUrl) $target && git checkout $expectedSha"
                continue
            }
            git clone $skill.cloneUrl $target
            Push-Location $target
            try { git checkout --quiet $expectedSha } finally { Pop-Location }
        } else {
            Push-Location $target
            try {
                $actualSha = (git rev-parse HEAD).Trim()
                if ($actualSha -ne $expectedSha) {
                    Write-Host "[drift] $($skill.id): HEAD $actualSha, expected $expectedSha" -ForegroundColor Yellow
                    if ($Update -and -not $DryRun) {
                        git fetch origin
                        git checkout --quiet $expectedSha
                    } elseif ($Update -and $DryRun) {
                        Write-DryRun "git checkout $expectedSha ($target)"
                    }
                } else {
                    Write-Host "[ok]    $($skill.id) @ $($expectedSha.Substring(0,7))"
                }
            } finally {
                Pop-Location
            }
        }
        if ($skill.postClone) {
            foreach ($post in $skill.postClone) {
                $postCwd = Join-Path $workspaceRoot $post.cwd
                if ($DryRun) {
                    Write-DryRun "($postCwd) $($post.cmd)"
                } else {
                    Push-Location $postCwd
                    try { Invoke-Expression $post.cmd } finally { Pop-Location }
                }
            }
        }
    }
}

# --- Stage 4: Agent host configs ---------------------------------------------
function Invoke-AgentsStage {
    Write-Stage 'Stage 4: Agent host configuration'
    foreach ($prop in $manifest.agents.PSObject.Properties) {
        $name = $prop.Name
        $agent = $prop.Value
        $sourceDir = Join-Path $workspaceRoot $agent.templateSource
        $targetDir = Join-Path $workspaceRoot $agent.target
        if (-not (Test-Path -LiteralPath $sourceDir)) {
            Write-Host "[skip] $name: template source missing at $sourceDir"
            continue
        }
        if (-not (Test-Path -LiteralPath $targetDir)) {
            if ($DryRun) { Write-DryRun "mkdir $targetDir" } else { New-Item -ItemType Directory -Path $targetDir | Out-Null }
        }
        foreach ($file in $agent.files) {
            $src = Join-Path $sourceDir $file
            $dst = Join-Path $targetDir $file
            if (-not (Test-Path -LiteralPath $src)) {
                Write-Host "[warn] $name: template missing $src"
                continue
            }
            if (Test-Path -LiteralPath $dst) {
                Write-Host "[keep] $name/$file (exists; use sync-config to overwrite — deferred)" -ForegroundColor Yellow
                continue
            }
            if ($DryRun) {
                Write-DryRun "copy $src -> $dst"
            } else {
                Copy-Item -LiteralPath $src -Destination $dst -Force
                Write-Host "[copy] $name/$file"
            }
        }
    }
}

# --- Stage 5: Final checks ---------------------------------------------------
function Invoke-FinalChecks {
    Write-Stage 'Stage 5: Final checks'
    Write-Host "- Run 'claude login' if you have not authenticated Claude Code on this machine."
    Write-Host "- Run 'codex login' if you have not authenticated Codex CLI."
    Write-Host "- Re-run with -Update to fast-forward repos and skills to manifest refs."
    Write-Host ""
    Write-Host "Bootstrap finished."
}

if (-not $SkipDeps)    { Invoke-OsDepsStage }
if (-not $SkipRepos)   { Invoke-ReposStage }
if (-not $SkipSkills)  { Invoke-SkillsStage }
if (-not $SkipAgents)  { Invoke-AgentsStage }
Invoke-FinalChecks
```

- [ ] **Step 2: Delete the placeholder README**

```powershell
git rm bootstrap/README.md
```

### Task PR3.6: Re-run the PR3.2 test — must PASS

- [ ] **Step 1**

```powershell
uv run python -m unittest tests.test_bootstrap.BootstrapDryRunTest.test_ps1_dry_run_lists_intended_repo_clones_and_skill_clones -v
```

Expected: PASS. If PASS only with skip (no pwsh on PATH), install PowerShell 7 with `winget install Microsoft.PowerShell` before retrying.

### Task PR3.7: Implement `bootstrap/bootstrap.sh` (POSIX parity)

**Files:**
- Create: `bootstrap/bootstrap.sh`

- [ ] **Step 1: Write bootstrap.sh**

> Same stage structure as the PowerShell version. Uses `jq` for JSON parsing.
> If `jq` is missing, the script exits with the install hint from `require_jq`.

```bash
#!/usr/bin/env bash
# bootstrap/bootstrap.sh — workspace installer (macOS / Linux).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

INSTALL_DEPS=false
SKIP_DEPS=false
SKIP_SKILLS=false
SKIP_REPOS=false
SKIP_AGENTS=false
UPDATE=false
DRY_RUN=false
WORKSPACE_OVERRIDE=""
VERBOSE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install-deps)  INSTALL_DEPS=true; shift ;;
    --skip-deps)     SKIP_DEPS=true; shift ;;
    --skip-skills)   SKIP_SKILLS=true; shift ;;
    --skip-repos)    SKIP_REPOS=true; shift ;;
    --skip-agents)   SKIP_AGENTS=true; shift ;;
    --update)        UPDATE=true; shift ;;
    --dry-run)       DRY_RUN=true; shift ;;
    --workspace)     WORKSPACE_OVERRIDE="$2"; shift 2 ;;
    --verbose)       VERBOSE=true; shift ;;
    -h|--help)       sed -n '2,4p' "$0"; exit 0 ;;
    *) echo "Unknown flag: $1" >&2; exit 2 ;;
  esac
done

require_jq
WS="$(resolve_workspace_root "$WORKSPACE_OVERRIDE")"
MANIFEST_JSON="$(read_manifest "$WS")"
SKILLS_JSON="$(read_skills_lock "$WS")"
OS_KEY="$(get_os_key)"

echo "Workspace: $WS"
echo "OS:        $OS_KEY"
echo "Mode:      $($DRY_RUN && echo dry-run || echo apply)"

stage_osdeps() {
  write_stage 'Stage 1: OS dependencies'
  local manager
  manager="$(printf '%s' "$MANIFEST_JSON" | jq -r --arg os "$OS_KEY" '.osDeps[$os].manager // empty')"
  if [[ -z "$manager" ]]; then echo "No osDeps for $OS_KEY"; return; fi
  local missing=()
  while IFS=$'\t' read -r id verify optional; do
    if eval "$verify" >/dev/null 2>&1; then
      echo "[ok]   $id"
    elif [[ "$optional" == "true" ]]; then
      echo "[skip] $id (optional)"
    else
      echo "[miss] $id"
      missing+=("$id")
    fi
  done < <(printf '%s' "$MANIFEST_JSON" | jq -r --arg os "$OS_KEY" '.osDeps[$os].packages[] | [.id, (.verifyCmd // (.id+" --version")), (.optional // false | tostring)] | @tsv')
  if (( ${#missing[@]} == 0 )); then return; fi
  if ! $INSTALL_DEPS; then
    echo
    echo "Re-run with --install-deps to install via $manager."
    return
  fi
  for id in "${missing[@]}"; do
    if $DRY_RUN; then
      write_dry_run "$manager install $id"
    else
      case "$manager" in
        brew)   brew install "$id" ;;
        winget) winget install --id "$id" --silent --accept-package-agreements --accept-source-agreements ;;
        *) echo "Manager $manager not supported in shell; install $id manually." ;;
      esac
    fi
  done
}

stage_repos() {
  write_stage 'Stage 2: Sub-repositories'
  while IFS=$'\t' read -r name path cloneUrl ref; do
    if [[ "$name" == "fleet-command" ]]; then echo "[self] fleet-command"; continue; fi
    local target="$WS/$path"
    if [[ ! -d "$target" ]]; then
      if $DRY_RUN; then
        write_dry_run "git clone --branch $ref $cloneUrl $target"
      else
        git clone --branch "$ref" "$cloneUrl" "$target"
      fi
      continue
    fi
    local current
    current="$(git -C "$target" rev-parse --abbrev-ref HEAD)"
    if [[ "$current" != "$ref" ]]; then
      echo "[drift] $name: on '$current', manifest '$ref'"
      if $UPDATE && ! $DRY_RUN; then
        git -C "$target" fetch origin
        git -C "$target" switch "$ref"
        git -C "$target" pull --ff-only
      elif $UPDATE; then
        write_dry_run "git -C $target switch $ref && git pull --ff-only"
      fi
    else
      echo "[ok]    $name on $current"
    fi
  done < <(printf '%s' "$MANIFEST_JSON" | jq -r '.repos[] | [.name, .path, .cloneUrl, .ref] | @tsv')
}

stage_skills() {
  write_stage 'Stage 3: Upstream skills'
  while IFS=$'\t' read -r id cloneUrl target sha; do
    local target_abs="$WS/$target"
    if [[ ! -d "$target_abs" ]]; then
      if $DRY_RUN; then
        write_dry_run "git clone $cloneUrl $target_abs && git checkout $sha"
      else
        git clone "$cloneUrl" "$target_abs"
        git -C "$target_abs" checkout --quiet "$sha"
      fi
    else
      local actual
      actual="$(git -C "$target_abs" rev-parse HEAD)"
      if [[ "$actual" != "$sha" ]]; then
        echo "[drift] $id: HEAD $actual, expected $sha"
        if $UPDATE && ! $DRY_RUN; then
          git -C "$target_abs" fetch origin
          git -C "$target_abs" checkout --quiet "$sha"
        elif $UPDATE; then
          write_dry_run "git -C $target_abs checkout $sha"
        fi
      else
        echo "[ok]    $id @ ${sha:0:7}"
      fi
    fi
  done < <(printf '%s' "$SKILLS_JSON" | jq -r '.skills[] | [.id, .cloneUrl, .target, .ref.sha] | @tsv')
}

stage_agents() {
  write_stage 'Stage 4: Agent host configuration'
  while IFS=$'\t' read -r name templateSource target file; do
    local src="$WS/$templateSource/$file"
    local dst="$WS/$target/$file"
    if [[ ! -f "$src" ]]; then echo "[warn] $name: template missing $src"; continue; fi
    mkdir -p "$WS/$target"
    if [[ -e "$dst" ]]; then
      echo "[keep] $name/$file (exists)"
      continue
    fi
    if $DRY_RUN; then
      write_dry_run "copy $src -> $dst"
    else
      cp "$src" "$dst"
      echo "[copy] $name/$file"
    fi
  done < <(printf '%s' "$MANIFEST_JSON" | jq -r '.agents | to_entries[] | .key as $k | .value as $v | $v.files[] | [$k, $v.templateSource, $v.target, .] | @tsv')
}

stage_final() {
  write_stage 'Stage 5: Final checks'
  cat <<'EOM'
- Run 'claude login' to authenticate Claude Code.
- Run 'codex login' to authenticate Codex CLI.
- Re-run with --update to fast-forward refs.

Bootstrap finished.
EOM
}

$SKIP_DEPS   || stage_osdeps
$SKIP_REPOS  || stage_repos
$SKIP_SKILLS || stage_skills
$SKIP_AGENTS || stage_agents
stage_final
```

- [ ] **Step 2: Make executable on Unix**

> Git on Windows preserves the `+x` bit when `core.fileMode = false` is the default, but we set it explicitly on Unix machines. On Windows nothing happens. The execute bit travels with the commit.

```powershell
git update-index --chmod=+x bootstrap/bootstrap.sh
```

### Task PR3.8: Add bash dry-run test

**Files:**
- Modify: `tests/test_bootstrap.py`

- [ ] **Step 1: Add a second test method**

After the existing test, add:

```python
    @unittest.skipUnless(_has_bash(), "bash not on PATH")
    def test_sh_dry_run_lists_intended_repo_clones_and_skill_clones(self) -> None:
        if shutil.which("jq") is None:
            self.skipTest("jq required for bootstrap.sh")
        with tempfile.TemporaryDirectory() as tmp:
            workspace = Path(tmp)
            fc = workspace / "fleet-command"
            shutil.copytree(REPO_ROOT, fc, ignore=shutil.ignore_patterns(".git", ".worktrees", ".uv-cache"))
            result = _run_sh(["--dry-run", "--workspace", str(workspace), "--verbose"], cwd=fc)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("cardsense-api", result.stdout)
            self.assertIn("superpowers", result.stdout)
            self.assertIn("dry-run", result.stdout.lower())
```

- [ ] **Step 2: Run — must PASS (or skip cleanly if bash/jq absent)**

```powershell
uv run python -m unittest tests.test_bootstrap -v
```

Expected: 2 tests, both pass or skip (no fail).

### Task PR3.9: Write failing test for teardown.ps1 dry-run

**Files:**
- Create: `tests/test_teardown.py`

- [ ] **Step 1: Write the test**

```python
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
TEARDOWN_PS1 = REPO_ROOT / "bootstrap" / "teardown.ps1"
TEARDOWN_SH = REPO_ROOT / "bootstrap" / "teardown.sh"


def _has_pwsh() -> bool:
    return shutil.which("pwsh") is not None or shutil.which("powershell") is not None


def _has_bash() -> bool:
    return shutil.which("bash") is not None


def _make_workspace_with_artifacts(tmp: str) -> Path:
    ws = Path(tmp)
    fc = ws / "fleet-command"
    shutil.copytree(REPO_ROOT, fc, ignore=shutil.ignore_patterns(".git", ".worktrees", ".uv-cache"))
    (ws / "cardsense-api").mkdir()
    (ws / ".claude").mkdir()
    (ws / ".uv-cache").mkdir()
    return ws


class TeardownDryRunTest(unittest.TestCase):
    @unittest.skipUnless(_has_pwsh(), "PowerShell not on PATH")
    def test_ps1_dry_run_lists_artifacts_without_deleting(self) -> None:
        pwsh = shutil.which("pwsh") or shutil.which("powershell")
        with tempfile.TemporaryDirectory() as tmp:
            ws = _make_workspace_with_artifacts(tmp)
            result = subprocess.run(
                [pwsh, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(TEARDOWN_PS1),
                 "--workspace", str(ws)],
                capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn(".uv-cache", result.stdout)
            self.assertIn("cardsense-api", result.stdout)
            self.assertIn("dry-run", result.stdout.lower())
            # Nothing actually deleted
            self.assertTrue((ws / "cardsense-api").exists())
            self.assertTrue((ws / ".uv-cache").exists())

    @unittest.skipUnless(_has_pwsh(), "PowerShell not on PATH")
    def test_ps1_refuses_home_directory(self) -> None:
        pwsh = shutil.which("pwsh") or shutil.which("powershell")
        result = subprocess.run(
            [pwsh, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(TEARDOWN_PS1),
             "--workspace", str(Path.home())],
            capture_output=True, text=True,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("HOME", result.stderr + result.stdout)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run — must FAIL (no teardown.ps1 yet)**

```powershell
uv run python -m unittest tests.test_teardown -v
```

### Task PR3.10: Implement `bootstrap/teardown.ps1`

**Files:**
- Create: `bootstrap/teardown.ps1`

- [ ] **Step 1: Write teardown.ps1**

```powershell
# bootstrap/teardown.ps1 — workspace cleanup (dry-run by default).
[CmdletBinding()]
param(
    [switch] $Apply,
    [string] $Workspace,
    [switch] $Nuke,
    [string[]] $Keep,
    [switch] $Verbose
)

. (Join-Path $PSScriptRoot 'lib/common.ps1')

function Assert-WorkspaceSafe {
    param([string] $Path)
    if (-not [System.IO.Path]::IsPathRooted($Path)) {
        throw "Workspace must be an absolute path: $Path"
    }
    $resolved = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path.TrimEnd('\','/')
    if ($resolved -eq '' -or $resolved -eq '/' -or $resolved -match '^[A-Za-z]:[\\/]?$') {
        throw "Refusing to target filesystem root: $resolved"
    }
    $home = (Resolve-Path -LiteralPath $HOME).Path.TrimEnd('\','/')
    if ($resolved -ieq $home) { throw "Refusing to target HOME: $resolved" }
    foreach ($p in @('.ssh','.aws','.config','.claude','.codex')) {
        $protected = Join-Path $home $p
        if ($resolved -ieq (Resolve-Path -LiteralPath $protected -ErrorAction SilentlyContinue)) {
            throw "Refusing protected directory: $resolved"
        }
    }
    if (-not (Test-Path -LiteralPath $resolved -PathType Container)) {
        throw "Workspace does not exist: $resolved"
    }
    $children = Get-ChildItem -LiteralPath $resolved -Force -ErrorAction SilentlyContinue
    if (-not $children) {
        throw "Refusing to clean empty workspace: $resolved"
    }
    return $resolved
}

$wsArg = if ($Workspace) { $Workspace } else { (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path }
$workspaceRoot = Assert-WorkspaceSafe -Path $wsArg
$manifest = Read-Manifest -WorkspaceRoot $workspaceRoot
$skillsLock = Read-SkillsLock -WorkspaceRoot $workspaceRoot

$targets = New-Object System.Collections.Generic.List[string]
foreach ($repo in $manifest.repos) {
    if ($repo.name -eq 'fleet-command' -and -not $Nuke) { continue }
    $targets.Add((Join-Path $workspaceRoot $repo.path))
}
foreach ($prop in $manifest.agents.PSObject.Properties) {
    $targets.Add((Join-Path $workspaceRoot $prop.Value.target))
}
foreach ($skill in $skillsLock.skills) {
    $targets.Add((Join-Path $workspaceRoot $skill.target))
}
foreach ($cache in @('.uv-cache','.gstack','.superpowers','.worktrees','.pytest_cache')) {
    $targets.Add((Join-Path $workspaceRoot $cache))
}

# Filter --keep patterns
if ($Keep) {
    $targets = $targets | Where-Object {
        $path = $_
        -not ($Keep | Where-Object { $path -like "*$_*" })
    }
}

$existing = $targets | Where-Object { Test-Path -LiteralPath $_ } | Sort-Object -Unique

Write-Host "Workspace: $workspaceRoot"
Write-Host "Mode:      $(if ($Apply) { 'apply' } else { 'dry-run' })"
Write-Host ""

if ($existing.Count -eq 0) {
    Write-Host "Nothing to remove."
    return
}

Write-Host "Targets:"
foreach ($t in $existing) { Write-Host "  $t" }

if (-not $Apply) {
    Write-Host ""
    Write-Host "Dry-run only. Re-run with -Apply to delete the listed paths."
    return
}

if ($Nuke) {
    # Verify every managed repo is clean and pushed
    foreach ($repo in $manifest.repos) {
        $repoPath = Join-Path $workspaceRoot $repo.path
        if (-not (Test-Path -LiteralPath $repoPath)) { continue }
        Push-Location $repoPath
        try {
            $dirty = (git status --porcelain).Trim()
            $unpushed = (git log "@{upstream}..").Trim()
            if ($dirty -or $unpushed) {
                throw "Refusing --nuke: $($repo.name) has uncommitted or unpushed work."
            }
        } finally {
            Pop-Location
        }
    }
    Write-Host ""
    $confirm = Read-Host "Type NUKE to confirm deletion (including fleet-command)"
    if ($confirm -ne 'NUKE') { throw "Confirmation did not match. Aborting." }
} else {
    Write-Host ""
    $confirm = Read-Host "Type DELETE to confirm removal of the listed paths"
    if ($confirm -ne 'DELETE') { throw "Confirmation did not match. Aborting." }
}

foreach ($t in $existing) {
    Remove-Item -LiteralPath $t -Recurse -Force
    Write-Host "[gone] $t"
}
Write-Host "Done."
```

### Task PR3.11: Re-run teardown tests — must PASS

- [ ] **Step 1**

```powershell
uv run python -m unittest tests.test_teardown -v
```

Expected: 2 tests pass.

### Task PR3.12: Implement `bootstrap/teardown.sh` and add bash dry-run test

**Files:**
- Create: `bootstrap/teardown.sh`
- Modify: `tests/test_teardown.py`

- [ ] **Step 1: Write teardown.sh** (POSIX parity, structure mirrors teardown.ps1)

```bash
#!/usr/bin/env bash
# bootstrap/teardown.sh — workspace cleanup (dry-run by default).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
. "$SCRIPT_DIR/lib/common.sh"

APPLY=false
NUKE=false
WORKSPACE_OVERRIDE=""
KEEP_PATTERNS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=true; shift ;;
    --nuke)  NUKE=true; shift ;;
    --workspace) WORKSPACE_OVERRIDE="$2"; shift 2 ;;
    --keep) KEEP_PATTERNS+=("$2"); shift 2 ;;
    --verbose) shift ;;
    -h|--help) sed -n '2,4p' "$0"; exit 0 ;;
    *) echo "Unknown flag: $1" >&2; exit 2 ;;
  esac
done

require_jq

assert_safe() {
  local ws="$1"
  [[ "$ws" = /* ]] || { echo "Workspace must be absolute: $ws" >&2; exit 1; }
  local resolved; resolved="$(cd "$ws" && pwd -P)"
  [[ "$resolved" != "/" ]] || { echo "Refusing /." >&2; exit 1; }
  local home; home="$(cd "$HOME" && pwd -P)"
  [[ "$resolved" != "$home" ]] || { echo "Refusing HOME." >&2; exit 1; }
  for p in .ssh .aws .config .claude .codex; do
    [[ "$resolved" != "$home/$p" ]] || { echo "Refusing $home/$p." >&2; exit 1; }
  done
  [[ -d "$resolved" ]] || { echo "Not a directory: $resolved" >&2; exit 1; }
  [[ -n "$(ls -A "$resolved" 2>/dev/null)" ]] || { echo "Workspace empty; refusing." >&2; exit 1; }
  printf '%s' "$resolved"
}

if [[ -n "$WORKSPACE_OVERRIDE" ]]; then
  WS="$(assert_safe "$WORKSPACE_OVERRIDE")"
else
  WS="$(assert_safe "$(cd "$SCRIPT_DIR/../.." && pwd -P)")"
fi

MANIFEST_JSON="$(read_manifest "$WS")"
SKILLS_JSON="$(read_skills_lock "$WS")"

targets=()
while IFS=$'\t' read -r name path; do
  if [[ "$name" == "fleet-command" && "$NUKE" != true ]]; then continue; fi
  targets+=("$WS/$path")
done < <(printf '%s' "$MANIFEST_JSON" | jq -r '.repos[] | [.name, .path] | @tsv')

while read -r target; do targets+=("$WS/$target"); done < <(printf '%s' "$MANIFEST_JSON" | jq -r '.agents | to_entries[] | .value.target')
while read -r target; do targets+=("$WS/$target"); done < <(printf '%s' "$SKILLS_JSON" | jq -r '.skills[].target')

for cache in .uv-cache .gstack .superpowers .worktrees .pytest_cache; do
  targets+=("$WS/$cache")
done

filtered=()
for t in "${targets[@]}"; do
  skip=false
  for pat in "${KEEP_PATTERNS[@]:-}"; do
    [[ "$t" == *"$pat"* ]] && { skip=true; break; }
  done
  $skip || { [[ -e "$t" ]] && filtered+=("$t"); }
done

printf 'Workspace: %s\n' "$WS"
printf 'Mode:      %s\n\n' "$($APPLY && echo apply || echo dry-run)"

if (( ${#filtered[@]} == 0 )); then echo "Nothing to remove."; exit 0; fi

printf 'Targets:\n'
printf '  %s\n' "${filtered[@]}" | sort -u

$APPLY || { echo; echo "Dry-run only. Re-run with --apply to delete."; exit 0; }

if $NUKE; then
  while IFS=$'\t' read -r name path; do
    [[ -d "$WS/$path" ]] || continue
    if [[ -n "$(git -C "$WS/$path" status --porcelain)" || -n "$(git -C "$WS/$path" log '@{upstream}..' 2>/dev/null)" ]]; then
      echo "Refusing --nuke: $name has uncommitted or unpushed work." >&2
      exit 1
    fi
  done < <(printf '%s' "$MANIFEST_JSON" | jq -r '.repos[] | [.name, .path] | @tsv')
  printf '\nType NUKE to confirm deletion (including fleet-command): '
else
  printf '\nType DELETE to confirm removal: '
fi
read -r confirm
expected="$($NUKE && echo NUKE || echo DELETE)"
[[ "$confirm" == "$expected" ]] || { echo "Confirmation did not match. Aborting." >&2; exit 1; }

for t in "${filtered[@]}"; do
  rm -rf "$t"
  printf '[gone] %s\n' "$t"
done
echo Done.
```

- [ ] **Step 2: Mark executable**

```powershell
git update-index --chmod=+x bootstrap/teardown.sh
```

- [ ] **Step 3: Add bash test method** to `tests/test_teardown.py`:

```python
    @unittest.skipUnless(_has_bash(), "bash not on PATH")
    def test_sh_dry_run_lists_artifacts_without_deleting(self) -> None:
        if shutil.which("jq") is None:
            self.skipTest("jq required")
        bash = shutil.which("bash")
        with tempfile.TemporaryDirectory() as tmp:
            ws = _make_workspace_with_artifacts(tmp)
            result = subprocess.run(
                [bash, str(TEARDOWN_SH), "--workspace", str(ws)],
                capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn(".uv-cache", result.stdout)
            self.assertIn("dry-run", result.stdout.lower())
            self.assertTrue((ws / "cardsense-api").exists())
```

- [ ] **Step 4: Run all teardown tests**

```powershell
uv run python -m unittest tests.test_teardown -v
```

### Task PR3.13: Port `codex-safe` from agent-toolkit

**Files:**
- Create: `bootstrap/codex-safe.ps1`
- Create: `bootstrap/codex-safe.sh`

- [ ] **Step 1: Write codex-safe.ps1**

```powershell
# bootstrap/codex-safe.ps1 — launch Codex CLI with workspace-write sandbox + approval=always.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    $repoRoot = (git rev-parse --show-toplevel) 2>$null
} catch {
    Write-Error "codex-safe.ps1 must run inside a Git repository."
    exit 1
}
Set-Location -LiteralPath $repoRoot

Write-Host @"
Detected workspace: $repoRoot

Safety warnings before launching Codex:
- Codex will be launched with sandbox: workspace-write
- Codex will be launched with approval: always
- Do not approve commands that touch:
  - `$HOME, ~/.ssh, ~/.aws, ~/.config, ~/.claude, ~/.codex
  - browser profiles, Desktop, Downloads, credential stores
- Do not approve sudo, global installs, credential-helper changes, or commands that persist tokens.

Launching: codex --sandbox workspace-write --ask-for-approval always
"@

codex --sandbox workspace-write --ask-for-approval always @args
```

- [ ] **Step 2: Write codex-safe.sh** — copy verbatim from `D:\Projects\cardsense-workspace\agent-toolkit\scripts\codex-safe.sh`

(The agent-toolkit file is identical to the spec target. Re-read it from `agent-toolkit/scripts/codex-safe.sh` and copy.)

- [ ] **Step 3: Make executable**

```powershell
git update-index --chmod=+x bootstrap/codex-safe.sh
```

### Task PR3.14: Write failing test for `scripts/update-skill-lock.ps1`

**Files:**
- Create: `tests/test_update_skill_lock.py`

- [ ] **Step 1: Write the test**

```python
import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT_PS1 = REPO_ROOT / "scripts" / "update-skill-lock.ps1"
SCRIPT_SH = REPO_ROOT / "scripts" / "update-skill-lock.sh"


def _has_pwsh() -> bool:
    return shutil.which("pwsh") is not None or shutil.which("powershell") is not None


def _has_bash() -> bool:
    return shutil.which("bash") is not None


class UpdateSkillLockTest(unittest.TestCase):
    @unittest.skipUnless(_has_pwsh(), "PowerShell not on PATH")
    def test_ps1_prints_diff_and_does_not_write_when_no_change(self) -> None:
        pwsh = shutil.which("pwsh") or shutil.which("powershell")
        result = subprocess.run(
            [pwsh, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(SCRIPT_PS1),
             "--tool", "ui-ux-pro-max", "--to", "v2.5.0", "--dry-run"],
            cwd=str(REPO_ROOT), capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        # Output mentions the tool and either "no change" or shows a diff header
        self.assertIn("ui-ux-pro-max", result.stdout)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run — must FAIL**

```powershell
uv run python -m unittest tests.test_update_skill_lock -v
```

### Task PR3.15: Implement `scripts/update-skill-lock.ps1`

**Files:**
- Create: `scripts/update-skill-lock.ps1`

- [ ] **Step 1: Write the script**

```powershell
# scripts/update-skill-lock.ps1 — resolve a tag/SHA for one upstream skill, print diff, do not commit.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string] $Tool,
    [Parameter(Mandatory = $true)] [string] $To,
    [switch] $DryRun
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$lockPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../workspace/skills.lock.json')).Path
$lock = Get-Content -LiteralPath $lockPath -Raw | ConvertFrom-Json

$skill = $lock.skills | Where-Object { $_.id -eq $Tool }
if (-not $skill) { throw "Tool '$Tool' not found in skills.lock.json." }

# Resolve SHA from $To: if 40-char hex, use as-is; otherwise treat as tag/branch and ls-remote.
$sha = $null
if ($To -match '^[0-9a-f]{40}$') {
    $sha = $To
    $tag = $null
} else {
    $ref = "refs/tags/$To"
    $line = git ls-remote $skill.cloneUrl $ref 2>$null | Select-Object -First 1
    if (-not $line) {
        $line = git ls-remote $skill.cloneUrl "refs/heads/$To" 2>$null | Select-Object -First 1
        if (-not $line) { throw "Could not resolve $To against $($skill.cloneUrl)" }
        $tag = $null
    } else {
        $tag = $To
    }
    $sha = ($line -split '\s+')[0]
}

$today = (Get-Date -Format 'yyyy-MM-dd')
$old = $skill.ref.sha
$skill.ref = [PSCustomObject]@{ sha = $sha; tag = $tag; resolvedAt = $today }

if ($old -eq $sha) {
    Write-Host "$Tool already pinned at $sha; no change."
    exit 0
}

$json = ($lock | ConvertTo-Json -Depth 10) + "`n"

Write-Host "--- skills.lock.json ($Tool)"
Write-Host "-  sha: $old"
Write-Host "+  sha: $sha"
if ($tag) { Write-Host "+  tag: $tag" }
Write-Host "+  resolvedAt: $today"

if ($DryRun) {
    Write-Host ""
    Write-Host "Dry-run: re-run without --dry-run to write the file. The change is not auto-committed."
    exit 0
}

Set-Content -LiteralPath $lockPath -Value $json -Encoding utf8
Write-Host ""
Write-Host "Wrote $lockPath. Review the diff and commit manually."
```

- [ ] **Step 2: Re-run the test — must PASS**

```powershell
uv run python -m unittest tests.test_update_skill_lock -v
```

### Task PR3.16: Implement `scripts/update-skill-lock.sh` and a parallel bash test

**Files:**
- Create: `scripts/update-skill-lock.sh`
- Modify: `tests/test_update_skill_lock.py`

- [ ] **Step 1: Write update-skill-lock.sh**

```bash
#!/usr/bin/env bash
# scripts/update-skill-lock.sh — resolve tag/SHA for one upstream skill, print diff, no commit.

set -euo pipefail

TOOL=""
TO=""
DRY=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tool) TOOL="$2"; shift 2 ;;
    --to)   TO="$2"; shift 2 ;;
    --dry-run) DRY=true; shift ;;
    *) echo "Unknown flag: $1" >&2; exit 2 ;;
  esac
done
[[ -n "$TOOL" && -n "$TO" ]] || { echo "Usage: $0 --tool <id> --to <tag|sha> [--dry-run]" >&2; exit 2; }

command -v jq >/dev/null 2>&1 || { echo "jq required." >&2; exit 1; }

LOCK="$(cd "$(dirname "$0")/.." && pwd -P)/workspace/skills.lock.json"
[[ -f "$LOCK" ]] || { echo "skills.lock.json missing: $LOCK" >&2; exit 1; }

clone_url=$(jq -r --arg id "$TOOL" '.skills[] | select(.id==$id) | .cloneUrl' "$LOCK")
old_sha=$(jq -r --arg id "$TOOL" '.skills[] | select(.id==$id) | .ref.sha' "$LOCK")
[[ -n "$clone_url" ]] || { echo "Tool '$TOOL' not in lock." >&2; exit 1; }

if [[ "$TO" =~ ^[0-9a-f]{40}$ ]]; then
  sha="$TO"; tag="null"
else
  line=$(git ls-remote "$clone_url" "refs/tags/$TO" | head -n1 || true)
  if [[ -n "$line" ]]; then tag="\"$TO\""; else
    line=$(git ls-remote "$clone_url" "refs/heads/$TO" | head -n1 || true)
    [[ -n "$line" ]] || { echo "Cannot resolve $TO against $clone_url" >&2; exit 1; }
    tag="null"
  fi
  sha=$(printf '%s' "$line" | awk '{print $1}')
fi

today=$(date +%F)

if [[ "$old_sha" == "$sha" ]]; then
  echo "$TOOL already pinned at $sha; no change."
  exit 0
fi

echo "--- skills.lock.json ($TOOL)"
echo "-  sha: $old_sha"
echo "+  sha: $sha"
echo "+  tag: $tag"
echo "+  resolvedAt: $today"

if $DRY; then
  echo
  echo "Dry-run: re-run without --dry-run to write."
  exit 0
fi

tmp=$(mktemp)
jq --arg id "$TOOL" --arg sha "$sha" --argjson tag "$tag" --arg at "$today" \
   '(.skills[] | select(.id==$id) | .ref) = {sha:$sha, tag:$tag, resolvedAt:$at}' \
   "$LOCK" > "$tmp"
mv "$tmp" "$LOCK"
echo
echo "Wrote $LOCK. Review and commit manually."
```

- [ ] **Step 2: Mark executable**

```powershell
git update-index --chmod=+x scripts/update-skill-lock.sh
```

- [ ] **Step 3: Add bash test**

Append to `tests/test_update_skill_lock.py`:

```python
    @unittest.skipUnless(_has_bash(), "bash not on PATH")
    def test_sh_no_change_when_to_matches_current_sha(self) -> None:
        if shutil.which("jq") is None:
            self.skipTest("jq required")
        bash = shutil.which("bash")
        lock = json.loads((REPO_ROOT / "workspace" / "skills.lock.json").read_text(encoding="utf-8"))
        sha = next(s["ref"]["sha"] for s in lock["skills"] if s["id"] == "ui-ux-pro-max")
        result = subprocess.run(
            [bash, str(SCRIPT_SH), "--tool", "ui-ux-pro-max", "--to", sha, "--dry-run"],
            cwd=str(REPO_ROOT), capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("no change", result.stdout.lower())
```

- [ ] **Step 4: Run all update-skill-lock tests**

```powershell
uv run python -m unittest tests.test_update_skill_lock -v
```

### Task PR3.17: Local end-to-end smoke

**Files:** none

- [ ] **Step 1: Dry-run bootstrap from the live workspace**

```powershell
.\bootstrap\bootstrap.ps1 -DryRun -Verbose
```

Expected: stages 1–5 listed, no real clones, mention of `superpowers`, `gstack`, `ui-ux-pro-max`, all five repos, both agents.

- [ ] **Step 2: Dry-run teardown**

```powershell
.\bootstrap\teardown.ps1 -Workspace D:\Projects\cardsense-workspace
```

Expected: lists `.uv-cache`, sub-repos, `.claude`, `.codex`, etc. Refuses without `-Apply`.

- [ ] **Step 3: Confirm scripts refuse unsafe targets**

```powershell
.\bootstrap\teardown.ps1 -Workspace $HOME
```

Expected: non-zero exit with `Refusing to target HOME`.

### Task PR3.18: Full test discovery + renderer check

- [ ] **Step 1**

```powershell
uv run python scripts/render_workspace_assets.py --check
uv run python -m unittest discover tests
```

Expected: all clean / pass.

### Task PR3.19: Commit and push PR3

- [ ] **Step 1**

```powershell
git status -sb
git add bootstrap scripts/update-skill-lock.ps1 scripts/update-skill-lock.sh tests/test_bootstrap.py tests/test_teardown.py tests/test_update_skill_lock.py
git rm bootstrap/README.md bootstrap/lib/README.md 2>$null
git commit -m "[agent] feat: bootstrap, teardown, update-skill-lock cross-platform implementation"
git push -u origin feat/bootstrap-teardown
```

- [ ] **Step 2: Open PR with portability-milestone callout**

```powershell
gh pr create --title "[PR3] Bootstrap / teardown / update-skill-lock" --body @'
Scope:
- bootstrap.{ps1,sh}: osDeps -> repos -> skills -> agents -> final checks. Dry-run default for sensitive flags.
- teardown.{ps1,sh}: dry-run default, --apply requires DELETE, --nuke requires NUKE and clean+pushed repos.
- codex-safe.{ps1,sh}: ported from agent-toolkit.
- update-skill-lock.{ps1,sh}: resolve tag/SHA, print diff, never auto-commit.
- New tests/test_bootstrap.py, tests/test_teardown.py, tests/test_update_skill_lock.py.

>>> PORTABILITY MILESTONE <<<
After this PR merges, the owner will validate end-to-end on a second machine
(git clone fleet-command -> ./bootstrap/bootstrap.ps1 -> teardown dry-run).
Do not start PR4 until that validation succeeds (or owner explicitly waives it).

Verification:
- `uv run python scripts/render_workspace_assets.py --check` clean
- `uv run python -m unittest discover tests` all pass / skip cleanly
- Local dry-run of bootstrap + teardown reports expected stages
'@
```

- [ ] **Step 3: STOP. Wait for owner's "PR3 verified on second machine" before continuing.**

---

## PR4 — Migrate CardSense to `projects/cardsense/`

**Branch:** `chore/migrate-cardsense`
**Scope:** Move top-level CardSense docs and `dashboard/` under `projects/cardsense/`. Update all path references. Reference: spec §5, §10 (PR4 entry).

### Task PR4.1: Cut the branch

- [ ] **Step 1**

```powershell
git switch main
git pull origin main
git switch -c chore/migrate-cardsense
```

### Task PR4.2: Inventory references that will need updating

**Files:** none (read-only)

- [ ] **Step 1: Sweep**

```powershell
$patterns = @("CardSense-Status", "CardSense-Bank", "CardSense-Overview", "dashboard/data", "dashboard/index", "dashboard/app", "dashboard/styles")
foreach ($p in $patterns) {
  Write-Host "=== $p ==="
  git grep -nI $p
}
```

Record every hit. Expected hit locations (from current state):

- `README.md`
- `AGENTS.md`
- `workspace/workspace.manifest.json` (already fixed in PR2 — verify)
- `tests/test_dashboard_data.py`
- `skills/fleet-dashboard-closeout/SKILL.md`
- `WORKSPACE_CONTEXT.generated.md`
- `dashboard/app.js`, `dashboard/index.html` (if they use relative paths to `data/`, those stay relative so no edit needed)

### Task PR4.3: `git mv` the CardSense top-level docs

**Files:**
- Move: `CardSense-Status.md` → `projects/cardsense/status.md`
- Move: `CardSense-Bank-Promo-Review-Workflow.md` → `projects/cardsense/docs/bank-promo-review-workflow.md`
- Create: `projects/cardsense/overview.md` (placeholder for the dangling `CardSense-Overview.md` reference)

- [ ] **Step 1: Move**

```powershell
git mv CardSense-Status.md projects/cardsense/status.md
New-Item -ItemType Directory -Path projects/cardsense/docs -Force | Out-Null
git mv CardSense-Bank-Promo-Review-Workflow.md projects/cardsense/docs/bank-promo-review-workflow.md
Remove-Item projects/cardsense/.gitkeep -ErrorAction SilentlyContinue
```

- [ ] **Step 2: Create a minimal `projects/cardsense/overview.md`**

```markdown
# CardSense — Overview

CardSense is the deterministic credit-card recommendation system: an extraction
pipeline (`cardsense-extractor`), a runtime API (`cardsense-api`), a frontend
calculator and catalog (`cardsense-web`), and a shared contracts repo
(`cardsense-contracts`).

Current product status lives in `status.md`. Cross-project architecture and
references live in `../../docs/`. Dashboards and project-private docs live
under this directory.

For repo-level rules see each repo's `CLAUDE.md` / `AGENTS.md`.
```

```powershell
git add projects/cardsense/overview.md
```

### Task PR4.4: `git mv` the dashboard directory

**Files:**
- Move: `dashboard/` → `projects/cardsense/dashboard/`

- [ ] **Step 1: Move (preserves git history for every file)**

```powershell
git mv dashboard projects/cardsense/dashboard
```

- [ ] **Step 2: Confirm tracked moves**

```powershell
git status -sb
```

Expected: ~10 `renamed:` lines under `projects/cardsense/dashboard/`.

### Task PR4.5: Update `tests/test_dashboard_data.py` for the new path

**Files:**
- Modify: `tests/test_dashboard_data.py`

- [ ] **Step 1: Edit lines 6–8**

Replace:

```python
ROOT = Path(__file__).resolve().parents[1]
DASHBOARD = ROOT / "dashboard"
DATA = DASHBOARD / "data"
```

with:

```python
ROOT = Path(__file__).resolve().parents[1]
DASHBOARD = ROOT / "projects" / "cardsense" / "dashboard"
DATA = DASHBOARD / "data"
```

- [ ] **Step 2: Run the dashboard tests — must PASS**

```powershell
uv run python -m unittest tests.test_dashboard_data -v
```

Expected: all 5 tests pass.

### Task PR4.6: Update the manifest `keyFiles` for fleet-command

**Files:**
- Modify: `workspace/workspace.manifest.json`

- [ ] **Step 1: Confirm the manifest already references `projects/cardsense/status.md`**

(PR2 already wrote this. Run `uv run python scripts/render_workspace_assets.py --check`; expected: clean. If not, sync.)

- [ ] **Step 2: Re-render**

```powershell
uv run python scripts/render_workspace_assets.py
```

The newly rendered `WORKSPACE_CONTEXT.generated.md` should now reference `projects/cardsense/status.md` which exists.

### Task PR4.7: Update `README.md`

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Edit the "重點文件索引" section**

Replace lines 73–84:

```markdown
## 重點文件索引

- [CardSense-Status.md](./CardSense-Status.md) — CardSense text source of truth: product direction, current capability, roadmap, and open follow-ups.
- [dashboard/index.html](./dashboard/index.html) — CardSense fleet dashboard: repo health, roadmap progress, open action queue, latest checks, and release evidence links.

Run the dashboard over HTTP so the browser can read JSON data:

```bash
cd dashboard
python -m http.server 5177
```
```

with:

```markdown
## 重點文件索引

- [projects/cardsense/status.md](./projects/cardsense/status.md) — CardSense text source of truth: product direction, current capability, roadmap, and open follow-ups.
- [projects/cardsense/dashboard/index.html](./projects/cardsense/dashboard/index.html) — CardSense fleet dashboard: repo health, roadmap progress, open action queue, latest checks, and release evidence links.

Run the dashboard over HTTP so the browser can read JSON data:

```bash
cd projects/cardsense/dashboard
uv run python -m http.server 5177
```
```

### Task PR4.8: Update `AGENTS.md` dashboard references

**Files:**
- Modify: `AGENTS.md`

- [ ] **Step 1: Edit the CardSense Workspace Completion section**

Replace `fleet-command/dashboard` with `fleet-command/projects/cardsense/dashboard` everywhere in `AGENTS.md` (specifically line 178). Also update `dashboard/data/*.json` to `projects/cardsense/dashboard/data/*.json` in line 176.

```powershell
(Get-Content AGENTS.md -Raw) `
  -replace 'fleet-command/dashboard', 'fleet-command/projects/cardsense/dashboard' `
  -replace 'dashboard/data/\*\.json', 'projects/cardsense/dashboard/data/*.json' `
  -replace '`dashboard/data/checks\.json`', '`projects/cardsense/dashboard/data/checks.json`' `
  -replace '`dashboard/data/releases\.json`', '`projects/cardsense/dashboard/data/releases.json`' `
  -replace '`dashboard/data/roadmap\.json`', '`projects/cardsense/dashboard/data/roadmap.json`' `
  -replace '`dashboard/data/projects\.json`', '`projects/cardsense/dashboard/data/projects.json`' `
  | Set-Content AGENTS.md -Encoding utf8
```

- [ ] **Step 2: Verify the edit by reading lines 176–180**

```powershell
Select-String -Path AGENTS.md -Pattern 'projects/cardsense/dashboard' | Select-Object -First 10
```

Expected: every former `dashboard/...` now reads `projects/cardsense/dashboard/...`.

### Task PR4.9: Update `skills/fleet-dashboard-closeout/SKILL.md`

**Files:**
- Modify: `skills/fleet-dashboard-closeout/SKILL.md`

- [ ] **Step 1: Read current references**

```powershell
Select-String -Path skills/fleet-dashboard-closeout/SKILL.md -Pattern 'dashboard'
```

- [ ] **Step 2: For each line that uses `dashboard/` or `dashboard/data/`, replace with `projects/cardsense/dashboard/` etc.**

Apply the same regex substitution as PR4.8 to that file:

```powershell
(Get-Content skills/fleet-dashboard-closeout/SKILL.md -Raw) `
  -replace 'fleet-command/dashboard', 'fleet-command/projects/cardsense/dashboard' `
  -replace '(?<!projects/cardsense/)dashboard/', 'projects/cardsense/dashboard/' `
  | Set-Content skills/fleet-dashboard-closeout/SKILL.md -Encoding utf8
```

Read back the file and verify the result looks coherent — the lookbehind avoids double-prefixing.

### Task PR4.10: Final cross-reference sweep

**Files:** none

- [ ] **Step 1**

```powershell
$patterns = @("CardSense-Status", "CardSense-Bank", "CardSense-Overview", "(?<!projects/cardsense/)dashboard/")
foreach ($p in $patterns) {
  Write-Host "=== $p ==="
  git grep -nIE $p
}
```

Expected: zero hits except inside `WORKSPACE_CONTEXT.generated.md` if it lags — re-render to fix:

```powershell
uv run python scripts/render_workspace_assets.py
```

### Task PR4.11: Smoke-test the dashboard

**Files:** none

- [ ] **Step 1: Serve and verify the page loads**

```powershell
Push-Location projects/cardsense/dashboard
Start-Process pwsh -ArgumentList '-NoProfile','-Command','uv run python -m http.server 5177' -PassThru | ForEach-Object { Start-Sleep -Seconds 2; Invoke-WebRequest http://127.0.0.1:5177/index.html -UseBasicParsing | Select-Object -Expand StatusCode; Stop-Process -Id $_.Id }
Pop-Location
```

Expected: `200`.

### Task PR4.12: Run full verification

- [ ] **Step 1**

```powershell
uv run python scripts/render_workspace_assets.py --check
uv run python -m unittest discover tests
```

Expected: clean / all pass.

### Task PR4.13: Commit and push PR4

- [ ] **Step 1**

```powershell
git status -sb
git add -A
git commit -m "[agent] chore: migrate CardSense top-level material to projects/cardsense/"
git push -u origin chore/migrate-cardsense
gh pr create --title "[PR4] Migrate CardSense to projects/cardsense/" --body @'
Scope:
- git mv CardSense-Status.md, CardSense-Bank-Promo-Review-Workflow.md, dashboard/ to projects/cardsense/.
- Add projects/cardsense/overview.md as the home for the previously dangling CardSense-Overview reference.
- Update tests/test_dashboard_data.py path constants.
- Update README.md, AGENTS.md, skills/fleet-dashboard-closeout/SKILL.md cross-references.
- Re-render WORKSPACE_CONTEXT.generated.md.

Verification:
- `uv run python scripts/render_workspace_assets.py --check` clean
- `uv run python -m unittest discover tests` all pass
- Dashboard served from new path returns HTTP 200
'@
```

- [ ] **Step 2: Pause for owner review/merge.**

---

## PR5 — Migrate other projects + docs reorganization

**Branch:** `chore/migrate-projects-docs`
**Scope:** Move per-project material under `projects/<name>/` and shared docs under `docs/<category>/`. Reference: spec §5, §10 (PR5 entry).

### Task PR5.1: Cut the branch

- [ ] **Step 1**

```powershell
git switch main; git pull origin main; git switch -c chore/migrate-projects-docs
```

### Task PR5.2: Move per-project content

**Files:**
- Move: `spec-rent-radar.md` → `projects/rent-radar/spec.md`
- Move: `techtrend/` → `projects/techtrend/` (with .gitkeep removed)
- Move: `specs/spec-rta.md` → `projects/rta/spec.md` (creates new dir; not in spec but currently dangling — confirm with owner whether to keep at `specs/` or move; if uncertain, leave under `specs/`)

- [ ] **Step 1: Move rent-radar spec**

```powershell
Remove-Item projects/rent-radar/.gitkeep -ErrorAction SilentlyContinue
git mv spec-rent-radar.md projects/rent-radar/spec.md
```

- [ ] **Step 2: Move techtrend material**

```powershell
Remove-Item projects/techtrend/.gitkeep -ErrorAction SilentlyContinue
git mv techtrend/* projects/techtrend/
Remove-Item techtrend -Force
```

Verify the move:

```powershell
git status -sb | Select-String 'techtrend'
```

- [ ] **Step 3: For seedcraft/godine/fridgemanager/knoty — leave only `.gitkeep`** (no top-level files to move; placeholders already exist from PR1).

### Task PR5.3: Move shared docs into `docs/`

**Files:**
- Move: `arch-agent-blueprint.md` → `docs/arch/agent-blueprint.md`
- Move: `arch-portfolio-master.md` → `docs/arch/portfolio-master.md`
- Move: `ref-agent-cron.md` → `docs/refs/agent-cron.md`
- Move: `ref-agent-workflow.md` → `docs/refs/agent-workflow.md`
- Move: `prompt-agent-tasks.md` → `docs/prompts/agent-tasks.md`

- [ ] **Step 1: Move and delete placeholders**

```powershell
Remove-Item docs/arch/.gitkeep, docs/refs/.gitkeep, docs/prompts/.gitkeep -ErrorAction SilentlyContinue
git mv arch-agent-blueprint.md docs/arch/agent-blueprint.md
git mv arch-portfolio-master.md docs/arch/portfolio-master.md
git mv ref-agent-cron.md docs/refs/agent-cron.md
git mv ref-agent-workflow.md docs/refs/agent-workflow.md
git mv prompt-agent-tasks.md docs/prompts/agent-tasks.md
```

### Task PR5.4: Update README's "命名規則" section

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Remove the obsolete naming convention block**

The README's "命名規則" block (lines 11–24 originally) describes the old `spec-`, `arch-`, `ref-`, `prompt-` flat prefix scheme. After PR5 that scheme no longer applies. Replace with:

```markdown
## File layout

```
projects/<name>/        Per-project specs, status notes, dashboards.
docs/arch/              Cross-project architecture.
docs/refs/              Cross-project reference material.
docs/prompts/           Prompt templates.
docs/policies/          Cross-project policies (uv enforcement, public-pc mode, skill portability).
docs/superpowers/       superpowers plans and specs.
specs/                  Inline design specs for in-flight work (kept flat for now).
skills/                 Recipe skills used in this workspace.
claude-config/          Template `.claude/` deployed by bootstrap.
codex-config/           Template `.codex/` deployed by bootstrap.
per-repo-templates/     Starter AGENTS.md / CLAUDE.md / PROJECT_HANDOFF.md for downstream repos.
bootstrap/              Cross-platform installer + teardown scripts.
workspace/              workspace.manifest.json + skills.lock.json.
scripts/                Renderer and update-skill-lock helpers.
```
```

### Task PR5.5: Update README's links to the new doc paths

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Replace any remaining `arch-*`, `ref-*`, `prompt-*`, `spec-rent-radar` references**

```powershell
(Get-Content README.md -Raw) `
  -replace 'arch-agent-blueprint\.md', 'docs/arch/agent-blueprint.md' `
  -replace 'arch-portfolio-master\.md', 'docs/arch/portfolio-master.md' `
  -replace 'ref-agent-cron\.md', 'docs/refs/agent-cron.md' `
  -replace 'ref-agent-workflow\.md', 'docs/refs/agent-workflow.md' `
  -replace 'prompt-agent-tasks\.md', 'docs/prompts/agent-tasks.md' `
  -replace 'spec-rent-radar', 'projects/rent-radar/spec' `
  | Set-Content README.md -Encoding utf8
```

### Task PR5.6: Update the manifest if any `keyFiles` referenced moved files

**Files:**
- Modify: `workspace/workspace.manifest.json` (only if a `keyFiles[]` entry pointed at a moved file)

- [ ] **Step 1**

```powershell
git grep -nIE 'arch-|ref-|prompt-|spec-rent-radar' workspace/workspace.manifest.json
```

Expected: no hits (these were not in keyFiles). If hits found, edit accordingly.

### Task PR5.7: Cross-reference sweep

- [ ] **Step 1**

```powershell
$patterns = @('^arch-', '^ref-', '^prompt-', 'spec-rent-radar', 'techtrend/')
foreach ($p in $patterns) {
  Write-Host "=== $p ==="
  git grep -nIE $p
}
```

Expected: zero non-historical hits (matches only inside agent-log/, reviews/, or docs/superpowers/plans/ are OK — those are point-in-time records).

### Task PR5.8: Re-render and verify

- [ ] **Step 1**

```powershell
uv run python scripts/render_workspace_assets.py
uv run python scripts/render_workspace_assets.py --check
uv run python -m unittest discover tests
```

Expected: rendered, clean, all tests pass.

### Task PR5.9: Commit and push PR5

- [ ] **Step 1**

```powershell
git status -sb
git add -A
git commit -m "[agent] chore: migrate per-project material to projects/ and shared docs to docs/"
git push -u origin chore/migrate-projects-docs
gh pr create --title "[PR5] Migrate other projects + docs reorganization" --body @'
Scope:
- spec-rent-radar.md -> projects/rent-radar/spec.md.
- techtrend/ -> projects/techtrend/.
- arch-*, ref-*, prompt-* -> docs/arch/, docs/refs/, docs/prompts/.
- README updated: replace flat-prefix naming convention with directory layout.

Verification:
- Renderer check clean
- All tests pass
- Cross-reference sweep zero non-historical hits
'@
```

- [ ] **Step 2: Pause for owner review/merge.**

---

## PR6 — Integrate agent-toolkit + cleanup

**Branch:** `chore/integrate-agent-toolkit`
**Scope:** Absorb the salvageable subset of `WaddleStudio/agent-toolkit` into `fleet-command`, then delete the local clone and the remote repo. Reference: spec §8, §9, §10 (PR6 entry).

> **CRITICAL ORDERING**
>
> 1. Land the integration content in `fleet-command/main` first.
> 2. Push to `origin/main` and confirm the commit SHA is present on GitHub.
> 3. **Only then** run `gh repo delete WaddleStudio/agent-toolkit --yes`.
> 4. **Only then** remove `D:\Projects\cardsense-workspace\agent-toolkit\`.
>
> Reversing this order risks losing the integration trace if anything fails.

### Task PR6.1: Cut the branch

- [ ] **Step 1**

```powershell
git switch main; git pull origin main; git switch -c chore/integrate-agent-toolkit
```

### Task PR6.2: Add `docs/policies/uv-enforcement.md`

**Files:**
- Create: `docs/policies/uv-enforcement.md`

- [ ] **Step 1: Copy verbatim from agent-toolkit**

Read `D:\Projects\cardsense-workspace\agent-toolkit\docs\UV_ENFORCEMENT.md` and write its content to `fleet-command/docs/policies/uv-enforcement.md` unchanged (no rewording — the spec says "copy").

- [ ] **Step 2: Remove the docs/policies/.gitkeep**

```powershell
Remove-Item docs/policies/.gitkeep -ErrorAction SilentlyContinue
git add docs/policies/uv-enforcement.md
```

### Task PR6.3: Add `docs/policies/public-pc-mode.md` (slim version)

**Files:**
- Create: `docs/policies/public-pc-mode.md`

- [ ] **Step 1: Write the 1-page checklist**

```markdown
# Public-PC mode

When working from a public, shared, hotel, or otherwise untrusted computer,
treat the workspace as disposable.

## Checklist

1. Prefer Codex Cloud, GitHub Codespaces, devcontainer, or a browser-only workflow.
2. If a local clone is unavoidable, place it in a dedicated disposable directory.
3. Do not place API keys, tokens, cookies, SSH keys, or cloud credentials in the workspace.
4. Do not run global package installs (`npm install -g`, `pip install --user`, etc.).
5. Do not approve commands that touch `$HOME`, `~/.ssh`, `~/.aws`, `~/.config`,
   `~/.claude`, `~/.codex`, browser profiles, Desktop, Downloads, or credential stores.
6. Do not modify Git credential helpers.
7. Use `fleet-command/bootstrap/codex-safe.ps1` (or `.sh`) to launch Codex with
   `--sandbox workspace-write --ask-for-approval always`.
8. Dry-run cleanup before deleting (`fleet-command/bootstrap/teardown.ps1`),
   then `--apply` after reviewing the target list.

## What sandboxing does and does not buy

Local sandboxing reduces accidental file access but does not make an untrusted
machine trustworthy. A public computer's OS, browser sessions, and history may
still observe everything. Prefer cloud workflows when you can.

Original source: absorbed from `agent-toolkit/docs/PUBLIC_PC_SAFETY.md`.
```

```powershell
git add docs/policies/public-pc-mode.md
```

### Task PR6.4: Add `docs/policies/skill-portability.md` (short note)

**Files:**
- Create: `docs/policies/skill-portability.md`

- [ ] **Step 1: Write**

```markdown
# Skill portability

`fleet-command` keeps upstream skill source code out of the repository. Each
machine clones the three upstream skills (`superpowers`, `gstack`,
`ui-ux-pro-max`) at the SHA pinned in `workspace/skills.lock.json`, into
`<workspace>/.claude/skills/<id>/`.

## Rules

- Treat third-party skills as optional capabilities. If a skill is missing in
  the current environment, state that it is unavailable and follow the routing
  manually — do not auto-install on a public computer.
- Update an upstream skill's pin via `scripts/update-skill-lock.ps1 --tool <id> --to <tag-or-sha>`.
  The script resolves the SHA, prints a unified diff, and does not auto-commit.
- Do not vendor upstream skill source into `fleet-command`.
- Do not write to `~/.claude`, `~/.codex`, `~/.gstack`, `~/.config`, `~/.npm`,
  or credential stores from bootstrap/teardown scripts.

Original source: absorbed from `agent-toolkit/docs/SKILL_PORTABILITY.md`.
```

```powershell
git add docs/policies/skill-portability.md
```

### Task PR6.5: Add `per-repo-templates/PROJECT_HANDOFF.md`

**Files:**
- Create: `per-repo-templates/PROJECT_HANDOFF.md`

- [ ] **Step 1: Copy verbatim from agent-toolkit**

Read `D:\Projects\cardsense-workspace\agent-toolkit\templates\PROJECT_HANDOFF.md` and write it to `fleet-command/per-repo-templates/PROJECT_HANDOFF.md` unchanged.

```powershell
git add per-repo-templates/PROJECT_HANDOFF.md
```

### Task PR6.6: Update `per-repo-templates/CLAUDE.md` (first-line reference + uv section)

**Files:**
- Modify: `per-repo-templates/CLAUDE.md`

- [ ] **Step 1: Read the current file** — it's a long template (Read tool).

- [ ] **Step 2: Replace the existing header (title + three `>` lines) with the new first-line reference**

The current file's first 5 lines are:

```
# CLAUDE.md — Claude Code 專案指引

> 本檔案供 Claude Code CLI 讀取，幫助 Claude 理解專案 context。
> 放在各 code repo 的根目錄。
> 請根據各專案實際情況填入 {變數} 區塊。
```

Replace those 5 lines with:

```markdown
> Cross-repo rules and skill routing: see `../fleet-command/AGENTS.md`
> and `../fleet-command/claude-config/CLAUDE.md`. This file covers only
> <repo-name>-specific rules.

# CLAUDE.md — Claude Code 專案指引
```

- [ ] **Step 3: Append the uv enforcement section** (insert after the existing "開發規範" block, before "重要的架構決策")

```markdown
## Python workflows (uv enforcement)

Python projects MUST use `uv` by default unless this file documents a legacy
exception with reason, scope, and migration plan.

Default commands:

```bash
uv sync
uv run python path/to/script.py
uv run pytest
uv add <package>
uv remove <package>
uv run uvicorn app.main:app --reload
```

Forbidden by default: `pip install ...`, `python -m venv`, direct `python`, direct `pytest`,
manual virtualenv activation. See `../fleet-command/docs/policies/uv-enforcement.md`.
```

### Task PR6.7: Update `per-repo-templates/AGENTS.md` (uv section)

**Files:**
- Modify: `per-repo-templates/AGENTS.md`

- [ ] **Step 1: Append a "Python uv enforcement" section before the "開發 Context" section**

Use the same content as PR6.6 step 3 (the uv block). Keep the existing fleet-command reference at the top of the file.

### Task PR6.8: Create `claude-config/settings.json`

**Files:**
- Create: `claude-config/settings.json`

- [ ] **Step 1: Write a minimal settings.json (no secrets, sibling-dir allowance, deny rules)**

```json
{
  "$schema": "https://schemas.claude.com/code/settings.schema.json",
  "additionalDirectories": [
    "../cardsense-api",
    "../cardsense-contracts",
    "../cardsense-extractor",
    "../cardsense-web"
  ],
  "permissions": {
    "deny": [
      "Bash(rm -rf /*)",
      "Bash(git push --force origin main)",
      "Bash(git reset --hard origin/main)"
    ]
  },
  "skills": {
    "discoveryPaths": [
      ".claude/skills",
      "fleet-command/skills"
    ]
  }
}
```

### Task PR6.9: Create `claude-config/CLAUDE.md`

**Files:**
- Create: `claude-config/CLAUDE.md`

- [ ] **Step 1: Write the workspace-wide Claude context**

```markdown
# CLAUDE.md — cardsense-workspace context (deployed to .claude/CLAUDE.md)

## Workspace layout

- Control plane: `fleet-command/` (only versioned repo at workspace root).
- Sub-repos at workspace root (each independently versioned):
  cardsense-contracts, cardsense-extractor, cardsense-api, cardsense-web,
  plus per-project repos cloned per `fleet-command/workspace/workspace.manifest.json`.
- Per-project material (specs, status, dashboards): `fleet-command/projects/<name>/`.
- Cross-project docs: `fleet-command/docs/` (arch, refs, prompts, policies, superpowers).

## Tool defaults

- Python: `uv` only. Forbidden by default: `pip`, `python -m venv`, raw `python`, raw `pytest`.
  Full policy: `fleet-command/docs/policies/uv-enforcement.md`.
- Browser checks: installed Google Chrome via gstack/browser. Fall back only if Chrome unavailable, and report the fallback.
- Skill portability: skills are pinned by SHA in `fleet-command/workspace/skills.lock.json`.
  Update via `fleet-command/scripts/update-skill-lock.ps1`.

## Recipe skills (read in place from fleet-command/skills/)

- `cardsense-contract-evolution` — evolve shared contracts.
- `cardsense-dev-checks` — CLI verification (tests, curl, gh, Chrome smoke).
- `cardsense-pipeline-verify` — verify extraction pipeline outputs.
- `fleet-dashboard-closeout` — finalize the CardSense fleet dashboard.

## Upstream skill routing

- `superpowers` — engineering workflow: TDD, debugging, plans, code review, finishing branches.
- `gstack` — planning + design review + browser QA + ship workflows.
- `ui-ux-pro-max` — UI/UX generation and design-system reasoning.

## Branch and commit conventions

- Branch: `{feat|fix|chore|wip}/<slug>`. Agents use `agent/<slug>`.
- Commit: `[agent] {type}: {description}` for agent-authored commits.
- One PR per repo. Do not stack branches.

## Public-PC mode

If on an untrusted machine, read `fleet-command/docs/policies/public-pc-mode.md` first.
```

### Task PR6.10: Create `codex-config/config.toml` and `codex-config/AGENTS.md`

**Files:**
- Create: `codex-config/config.toml`
- Create: `codex-config/AGENTS.md`

- [ ] **Step 1: Write config.toml**

```toml
# codex-config/config.toml — deployed to .codex/config.toml
sandbox = "workspace-write"
approval = "always"
model = "claude-opus-4-7"

[skills]
discoveryPaths = [".claude/skills", "fleet-command/skills"]
```

- [ ] **Step 2: Write AGENTS.md (content-aligned with claude-config/CLAUDE.md)**

Hand-write a Codex-flavored version of `claude-config/CLAUDE.md`. The content sections are the same — workspace layout, tool defaults, recipe skills, upstream skill routing, branch conventions, public-PC mode. Differences from claude-config/CLAUDE.md:

- Title: `# AGENTS.md — cardsense-workspace Codex context (deployed to .codex/AGENTS.md)`
- Replace any "Claude Code"-specific phrasing with neutral language.
- Mention `codex --sandbox workspace-write --ask-for-approval always` (or use `fleet-command/bootstrap/codex-safe.ps1`).

### Task PR6.11: Update top-level `AGENTS.md` — add uv + public-PC sections

**Files:**
- Modify: `AGENTS.md`

- [ ] **Step 1: Add a new section after the "工作流程" block, before "Branch 類型字典"**

```markdown
## Python uv enforcement

Workspace Python work MUST use `uv` unless a downstream repo documents a legacy
exception in its own `AGENTS.md`/`CLAUDE.md` with reason, scope, and migration plan.

Required: `uv sync`, `uv run python …`, `uv run pytest`, `uv add`, `uv remove`,
`uv run uvicorn …`.

Forbidden by default: `pip install …`, `python -m venv`, direct `python`,
direct `pytest`, manual virtualenv activation.

Full policy: `docs/policies/uv-enforcement.md`.

## Public-PC mode

On a public or untrusted computer, prefer Codex Cloud / Codespaces / devcontainer.
For local work, follow `docs/policies/public-pc-mode.md`. Do not approve commands
that touch `$HOME`, `~/.ssh`, `~/.aws`, `~/.config`, `~/.claude`, `~/.codex`,
browser profiles, Desktop, Downloads, or credential stores. Use
`bootstrap/codex-safe.ps1` to launch Codex with the safety sandbox.
```

### Task PR6.12: Render and run all checks

- [ ] **Step 1**

```powershell
uv run python scripts/render_workspace_assets.py
uv run python scripts/render_workspace_assets.py --check
uv run python -m unittest discover tests
```

Expected: clean / all pass.

- [ ] **Step 2: Dry-run bootstrap to confirm stage 4 finds the new template files**

```powershell
.\bootstrap\bootstrap.ps1 -DryRun -SkipDeps -SkipRepos -SkipSkills -Verbose
```

Expected: stage 4 lists `[copy] claude/settings.json`, `[copy] claude/CLAUDE.md`, `[copy] codex/config.toml`, `[copy] codex/AGENTS.md` (or `[keep]` if those targets already exist).

### Task PR6.13: Commit and push PR6 — but do NOT delete agent-toolkit yet

**Files:** none

- [ ] **Step 1: Capture the source SHA for traceability**

```powershell
$AT_SHA = (git -C ../agent-toolkit rev-parse HEAD).Trim()
"agent-toolkit absorbed at $AT_SHA" | Out-Host
```

Expected: `20b16afb92b0019a0433e93c087d742b13636d01` (or whatever the current HEAD is).

- [ ] **Step 2: Stage and commit**

```powershell
git status -sb
git add -A
git commit -m @"
[agent] chore: integrate agent-toolkit content into fleet-command kernel

Absorbs uv-enforcement, public-pc-mode, skill-portability docs;
PROJECT_HANDOFF template; uv sections in per-repo templates; AGENTS.md uv +
public-PC sections; claude-config/ and codex-config/ template files.

Integrated from WaddleStudio/agent-toolkit @ $AT_SHA
"@
```

- [ ] **Step 3: Push**

```powershell
git push -u origin chore/integrate-agent-toolkit
```

- [ ] **Step 4: Open PR**

```powershell
gh pr create --title "[PR6] Integrate agent-toolkit + cleanup" --body @'
Scope:
- Add docs/policies/uv-enforcement.md, public-pc-mode.md, skill-portability.md.
- Add per-repo-templates/PROJECT_HANDOFF.md.
- Update per-repo-templates/{AGENTS,CLAUDE}.md (uv enforcement + first-line cross-repo reference).
- Add claude-config/{settings.json,CLAUDE.md} and codex-config/{config.toml,AGENTS.md}.
- Update fleet-command/AGENTS.md with uv and public-PC sections.

Integrated from WaddleStudio/agent-toolkit @ <sha>; the source repo will be
deleted after this PR merges and the integration commit is confirmed on origin/main.

Verification:
- Renderer check clean
- All tests pass
- bootstrap -DryRun stage 4 lists the new template files
'@
```

### Task PR6.14: After PR6 merges to main, push confirmation, then delete the source repo

**Files:** none (external/destructive actions)

> Owner runs these manually after the PR is merged. The agent may prepare the
> commands but must not execute them until the owner confirms the merge is on
> `origin/main`.

- [ ] **Step 1: Owner confirms the integration commit is on `origin/main`**

```powershell
git fetch origin
$MERGE_SHA = (git log origin/main --grep "agent-toolkit absorbed at" --format='%H' -1)
"Integration commit on origin/main: $MERGE_SHA" | Out-Host
```

Expected: a non-empty 40-char SHA. If empty, the merge has not landed yet — stop.

- [ ] **Step 2: Delete the GitHub repo**

```powershell
gh repo delete WaddleStudio/agent-toolkit --yes
```

> This is irreversible. The integration commit message records the source SHA
> for forensic git-pack recovery if ever needed.

- [ ] **Step 3: Delete the local clone**

```powershell
Remove-Item -Recurse -Force D:\Projects\cardsense-workspace\agent-toolkit
```

- [ ] **Step 4: Verify teardown does not try to clean a path that no longer exists**

```powershell
.\bootstrap\teardown.ps1 -Workspace D:\Projects\cardsense-workspace
```

Expected: lists `.uv-cache`, sub-repos, `.claude`, `.codex` etc. Does **not** list `agent-toolkit` (it was never in the manifest by design).

---

## Acceptance verification (after PR6 merges)

Reference: spec §13.

- [ ] **A1: Fresh-machine bootstrap (owner-only)**

On a machine with only `git` installed:

```bash
mkdir ws && cd ws
git clone https://github.com/WaddleStudio/fleet-command.git
./fleet-command/bootstrap/bootstrap.ps1   # or .sh on Unix
```

Expected: all five sub-repos cloned, three skills at pinned SHAs, `.claude/` and `.codex/` deployed. End-to-end ≤10 min if OS deps already present (≤20 min with `--install-deps`).

- [ ] **A2: Idempotent rerun**

```powershell
./fleet-command/bootstrap/bootstrap.ps1
```

Expected: every stage prints `[ok]` or `[keep]`, nothing changes on disk.

- [ ] **A3: Teardown dry-run vs apply**

```powershell
./fleet-command/bootstrap/teardown.ps1 --workspace <ws>
```

Expected: dry-run lists exactly the set of paths the manifest owns. `--apply` requires typed `DELETE`.

- [ ] **A4: `--nuke` refuses dirty work**

Create a stray uncommitted file in any sub-repo. `--nuke` must refuse.

- [ ] **A5: Tests**

```powershell
uv run python -m unittest discover tests
```

Expected: all pass.

- [ ] **A6: Renderer**

```powershell
uv run python scripts/render_workspace_assets.py --check
```

Expected: clean.

- [ ] **A7: Source repo deleted**

```powershell
gh repo view WaddleStudio/agent-toolkit
```

Expected: `GraphQL: Could not resolve to a Repository …` (404). Integration trace exists in `fleet-command` git history.

---

## Self-review notes

- Spec §1–§7 mapped to PR1–PR3; §8 mapped to PR6 (template/configs); §9 disposition table mapped to PR6 task-by-task; §10 dependency order is the PR ordering of this plan; §11 risks acknowledged via the explicit PR3 portability pause and the PR6 push-before-delete ordering; §12 explicitly out of scope; §13 acceptance lifted into the final checklist.
- PR2 step PR2.5 writes `keyFiles: ["projects/cardsense/status.md"]` before PR4 actually creates that file. This is intentional — `render_repo_context()` lists `keyFiles` as text without filesystem checks, so the dangling reference is benign for one PR's window.
- PR4 inventories all `dashboard/`, `CardSense-Status`, `CardSense-Bank`, `CardSense-Overview` references before moving anything; no hidden cross-refs.
- PR6 task PR6.14 (gh repo delete + rm local) sits **after** PR6 merges. The agent may not execute these steps before the owner confirms the integration commit is on origin/main.
- Agent-authored commits use `[agent] {type}: {desc}` per repo-wide convention.
- Python invocations use `uv run python …` exclusively across every PR.
