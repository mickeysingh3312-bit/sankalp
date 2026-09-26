# Sankalp Naam Jap

Sankalp is a Flutter Android app with a PHP and MySQL backend. It preserves the
provided saffron design, works offline for daily counting, synchronizes progress
after sign in, and uses Google Play Billing for the ₹21 monthly Premium plan.

## Free plan

- Jai Shri Ram, Om Namah Shivay, Radhe Radhe, Shri Krishna and Hanuman
- Custom mantra
- Tap mode
- Daily targets: 108, 216, 501 and 1,100
- Daily streak, lifetime count, 30 day history and progress blocks
- Vibration, light/dark/auto theme, reminders and sharing

## Premium plan

- Interactive 108 bead Mala mode
- Naam writing with an explicit Done +1 action
- 2,108, custom and 1 lakh monthly targets
- Daily target suggestion for the remaining monthly Sankalp
- Separate tap, Mala and writing statistics
- Google Play purchase, restore and server verification

## Repository

- `mobile/` Flutter application
- `backend/` dependency free PHP 8 API and admin dashboard
- `docs/` deployment and Play Store setup
- `.github/workflows/validate.yml` analysis, tests, PHP lint and APK build

## Local start

Create `backend/.env` using the variables listed in the deployment guide,
update the MySQL and Google Play values, and import
`backend/database/schema.sql`. The backend web root is `backend/public`.

For the Android app:

```bash
cd mobile
bash tool/bootstrap_android.sh
flutter pub get
flutter run --dart-define=API_BASE_URL=https://your-api.example.com/api/v1
```

See [deployment](docs/DEPLOYMENT.md) and
[Google Play subscription setup](docs/PLAY_STORE.md) for production steps.
