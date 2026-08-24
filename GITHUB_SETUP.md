# ASAZU STUDIO — GitHub + Automatic APK Build

Create an empty GitHub repository, then from this project folder run:

```bash
git init
git add .
git commit -m "ASAZU STUDIO Phase 14.1"
git branch -M main
git remote add origin YOUR_GITHUB_REPOSITORY_URL
git push -u origin main
```

GitHub Actions is configured in `.github/workflows/build-apk.yml`.
It runs `flutter pub get`, `flutter analyze`, `flutter test`, builds a release APK, and uploads the APK as an artifact.

To run manually: GitHub → Actions → Build Android APK → Run workflow.
