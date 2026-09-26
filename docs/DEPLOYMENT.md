# Backend deployment

## Server requirements

- PHP 8.2 or newer
- MySQL 8 or compatible MariaDB
- PHP extensions: curl, mbstring, openssl and pdo_mysql
- HTTPS
- Apache with mod_rewrite, or an equivalent Nginx rewrite to `public/index.php`

## cPanel

1. Point the API subdomain document root to `backend/public`.
2. Create `backend/.env` outside the public directory with the database,
   Google Play and admin variables listed below.
3. Import `backend/database/schema.sql` in phpMyAdmin.
4. Store the Google service account JSON outside `public`.
5. Open `/api/v1/health` and confirm it returns `{"status":"ok"}`.
6. Open `/admin/` and use the credentials from `ADMIN_USERNAME` and
   `ADMIN_PASSWORD`.

Required variables are `APP_ENV`, `APP_TIMEZONE`, `ALLOWED_ORIGIN`,
`DB_HOST`, `DB_PORT`, `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD`,
`GOOGLE_PACKAGE_NAME`, `GOOGLE_SUBSCRIPTION_PRODUCT`,
`GOOGLE_SERVICE_ACCOUNT_JSON`, `GOOGLE_RTDN_AUDIENCE`,
`GOOGLE_RTDN_SERVICE_ACCOUNT`, `ADMIN_USERNAME` and `ADMIN_PASSWORD`.

## Flutter build

Run:

```bash
cd mobile
bash tool/bootstrap_android.sh
flutter pub get
flutter build apk --release --dart-define=API_BASE_URL=https://api.example.com/api/v1
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.example.com/api/v1
```

The repository workflow builds a smaller release-mode test APK on each push.
It uses Flutter's generated test signing configuration and is intended for
sideload testing only. Set the repository variable `API_BASE_URL` to the
deployed API base URL before downloading the workflow APK. Configure a private
production keystore before creating the Play Store AAB.
