# GitHub Actions Deploy Setup

This repo uses `.github/workflows/deploy.yml` for branch-based deployment:

- `develop` → Firebase alias `staging` (`giggo-staging`)
- `main` → Firebase alias `prod` (`giggo-8a302`)

## Required GitHub Secret

Create this repository secret:

- `FIREBASE_TOKEN`

Generate it locally with:

```bash
firebase login:ci
```

Then add it in GitHub:

- Repo → Settings → Secrets and variables → Actions → New repository secret

## What the workflow does

1. Runs `flutter pub get`
2. Runs `flutter analyze`
3. Builds Flutter web (`client/build/web`)
4. Deploys Firebase using `.firebaserc` alias mapping
