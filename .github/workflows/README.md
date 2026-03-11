# GitHub Actions Deploy Setup

This repo uses `.github/workflows/deploy.yml` for branch-based deployment:

- `develop` → Firebase project `giggo-staging`
- `main` → Firebase project `giggo-8a302`

## Required GitHub Secret (Recommended)

Create this repository secret (preferred):

- `FIREBASE_SERVICE_ACCOUNT`

Value should be the full JSON key content for a Google service account with Firebase Hosting deploy permissions.

## Optional Fallback Secret

If you still use token-based auth, the workflow also supports:

- `FIREBASE_TOKEN`

Generate token locally with:

```bash
firebase login:ci
```

Then add it in GitHub:

- Repo → Settings → Secrets and variables → Actions → New repository secret

## What the workflow does

1. Runs `flutter pub get`
2. Runs `flutter analyze`
3. Builds Flutter web (`client/build/web`)
4. Deploys Firebase Hosting to the branch-mapped project ID
