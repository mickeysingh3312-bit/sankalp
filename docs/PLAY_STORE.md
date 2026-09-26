# Google Play subscription setup

1. Create the Android app in Play Console using package name
   `com.techezer.sankalp`.
2. Create subscription product `sankalp_premium_monthly`.
3. Add a monthly auto renewing base plan and set the India price to ₹21.
4. Create a Google Cloud service account, enable the Android Publisher API,
   and give the account access to this Play Console app.
5. Download its JSON key to the PHP server outside the public directory and
   set `GOOGLE_SERVICE_ACCOUNT_JSON` in `backend/.env`.
6. Set `GOOGLE_PACKAGE_NAME=com.techezer.sankalp` and
   `GOOGLE_SUBSCRIPTION_PRODUCT=sankalp_premium_monthly`.
7. Configure Real time developer notifications in Play Console. Create an
   authenticated Pub/Sub push subscription to
   `https://your-api.example.com/api/v1/google/rtdn`. Enable OIDC
   authentication, select a dedicated push service account, and use the same
   endpoint URL as the audience.
8. Set `GOOGLE_RTDN_AUDIENCE` to that endpoint URL and set
   `GOOGLE_RTDN_SERVICE_ACCOUNT` to the dedicated service account email.
9. Add licensed testers and release an Android App Bundle to the internal
   testing track. Google Play purchases cannot be fully tested from a
   sideloaded debug APK.

The app sends the Google purchase token to the PHP API. Premium activates only
after the API validates the token against the Google Android Publisher API.
