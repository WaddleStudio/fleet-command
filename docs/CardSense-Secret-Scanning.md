# CardSense Secret Scanning

CardSense uses Gitleaks as the repo-level guardrail for committed secrets.

## Coverage

The following repositories include a `.gitleaks.toml` config and a GitHub Actions workflow at `.github/workflows/secret-scan.yml`:

- `cardsense-web`
- `cardsense-api`
- `cardsense-extractor`
- `cardsense-contracts`
- `fleet-command`

The workflow runs on pull requests, pushes to `main` or `master`, and manual dispatch. It invokes the open-source Gitleaks CLI through the official container image instead of `gitleaks/gitleaks-action`, because the hosted action requires a license for organization repositories. The CI command uses `--no-git` to scan the current checkout and prevent new secrets from entering the repository without failing on historical findings that must be handled through a separate rotation/history-cleanup task.

## Local Check

Install Gitleaks locally and run this from the repository you are changing:

```bash
gitleaks detect --source . --config .gitleaks.toml --redact --verbose
```

If Docker is preferred:

```bash
docker run --rm -v "$PWD:/repo" zricethezav/gitleaks:latest detect --source /repo --config /repo/.gitleaks.toml --redact --verbose
```

## Policy

- Keep real Supabase, Cloudflare, Vercel, Railway, Stripe, and API keys out of git.
- Keep real values in vendor secret managers or untracked local `.env` files.
- Placeholder values may appear in docs and tests only when clearly synthetic.
- A detected real secret is treated as compromised: rotate it in the vendor console and update deployment secrets before merging.

## Remaining Manual Step

This guardrail prevents new leaks. It does not rotate credentials that may already have existed locally or in vendor consoles. Supabase and Cloudflare rotation remains a vendor-console task.
