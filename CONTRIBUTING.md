# Contributing

Thanks for contributing to JimsGarage! This guide covers the automated checks
that run on pull requests and — importantly for this repo — how to handle the
**dummy credentials** that many of these tutorials intentionally ship.

## Linting

A `pre-commit` configuration (`.pre-commit-config.yaml`) and a GitHub Actions
workflow (`.github/workflows/lint.yml`) run a set of checks. CI lints **only the
files changed in your PR**, so you are not responsible for pre-existing issues in
files you do not touch.

To run the checks locally before pushing:

```bash
pip install pre-commit
pre-commit install            # optional: run automatically on every commit
pre-commit run --all-files    # or scope to changed files (CI behavior)
```

The hooks include general hygiene (trailing whitespace, end-of-file newline),
`yamllint`, `shellcheck`, `actionlint`, and `gitleaks` (secret scanning).

## Credentials and secrets

**Never commit a real credential.** If you accidentally commit one, treat it as
compromised: rotate it, then remove it from history.

Many tutorials here include **throwaway / dummy credentials** so a config works
out of the box when copied. That is fine — but because they live next to real
config, the `gitleaks` scanner cannot tell a deliberate dummy from a genuine
leak. You therefore need to mark intentional dummies explicitly. There are two
ways to do this; prefer the first.

### 1. Inline annotation (preferred)

For a dummy value in a **comment-capable file that is already lint-clean**, add a
trailing `# gitleaks:allow` on the offending line:

```yaml
environment:
  - "ADMIN_TOKEN=not-a-real-token-1234567890"  # gitleaks:allow
```

This is self-documenting at the point of use and is the convention for any
**new** dummy credential you add.

### 2. Baseline in `.gitleaksignore`

Some findings cannot or should not be annotated inline. For these, add the
finding's fingerprint to `.gitleaksignore`. Use this when the file is:

- **JSON** — it has no comment syntax (e.g. `Netbird/management.json`).
- A **multi-line PEM private-key block** — an inline marker is unreliable across
  the block (e.g. `Authelia/Authelia/configuration.yml`).
- **Burdened with pre-existing lint debt** — editing it would pull the whole file
  into the changed-files lint scope and fail unrelated `yamllint`/hygiene checks.

To get a fingerprint, scan and copy the `Fingerprint` field for the finding:

```bash
gitleaks dir . --report-format json --report-path /tmp/gitleaks.json
# copy the "Fingerprint" value into .gitleaksignore, with a brief comment
```

### Allowlisted paths

`.gitleaks.toml` already allowlists conventional placeholder locations — tracked
`.env` files and `*example*` / `*sample*` files — since those are dummy by
convention in this repo. Secrets placed there are not scanned, so do not rely on
them to hold anything real.
