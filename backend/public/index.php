<?php

declare(strict_types=1);

use Sankalp\Auth;
use Sankalp\Database;
use Sankalp\Env;
use Sankalp\GooglePlay;
use Sankalp\Response;

require dirname(__DIR__) . '/src/Env.php';
require dirname(__DIR__) . '/src/Database.php';
require dirname(__DIR__) . '/src/Response.php';
require dirname(__DIR__) . '/src/Auth.php';
require dirname(__DIR__) . '/src/GooglePlay.php';

Env::load(dirname(__DIR__) . '/.env');
date_default_timezone_set(Env::get('APP_TIMEZONE', 'Asia/Kolkata'));

$origin = Env::get('ALLOWED_ORIGIN', '*');
header('Access-Control-Allow-Origin: ' . $origin);
header('Access-Control-Allow-Headers: Authorization, Content-Type, X-Google-RTDN-Secret');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('X-Content-Type-Options: nosniff');
header('Cache-Control: no-store');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

$path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';
$path = preg_replace('#^/api/v1#', '', $path) ?: '/';
$method = strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET');

if ($method === 'GET' && $path === '/health') {
    Response::json(['status' => 'ok', 'time' => gmdate(DATE_ATOM)]);
}

if ($method !== 'POST') {
    Response::error('Route not found.', 404);
}

$raw = file_get_contents('php://input');
if (strlen((string) $raw) > 1_000_000) {
    Response::error('Request is too large.', 413);
}
$input = json_decode($raw ?: '{}', true);
if (!is_array($input)) {
    Response::error('Request body must be valid JSON.');
}

try {
    $db = Database::connection();

    if ($path === '/auth/register') {
        $name = trim((string) ($input['name'] ?? ''));
        $email = strtolower(trim((string) ($input['email'] ?? '')));
        $password = (string) ($input['password'] ?? '');
        if ($name === '' || mb_strlen($name) > 100) {
            Response::error('Please enter your name.');
        }
        if (!filter_var($email, FILTER_VALIDATE_EMAIL) || mb_strlen($email) > 190) {
            Response::error('Please enter a valid email address.');
        }
        if (strlen($password) < 8 || strlen($password) > 200) {
            Response::error('Password must contain at least 8 characters.');
        }
        $exists = $db->prepare('SELECT id FROM users WHERE email = ? LIMIT 1');
        $exists->execute([$email]);
        if ($exists->fetch()) {
            Response::error('An account already exists for this email.', 409);
        }
        $statement = $db->prepare(
            'INSERT INTO users (name, email, password_hash) VALUES (?, ?, ?)'
        );
        $statement->execute([$name, $email, password_hash($password, PASSWORD_DEFAULT)]);
        $userId = (int) $db->lastInsertId();
        $user = ['id' => $userId, 'name' => $name, 'email' => $email, 'premium_until' => null];
        Response::json([
            'token' => Auth::issueToken($db, $userId),
            'user' => Auth::publicUser($user),
        ], 201);
    }

    if ($path === '/auth/login') {
        $email = strtolower(trim((string) ($input['email'] ?? '')));
        $password = (string) ($input['password'] ?? '');
        $statement = $db->prepare(
            'SELECT id, name, email, password_hash, premium_until FROM users WHERE email = ? LIMIT 1'
        );
        $statement->execute([$email]);
        $user = $statement->fetch();
        if (!$user || !password_verify($password, $user['password_hash'])) {
            Response::error('Email or password is incorrect.', 401);
        }
        Response::json([
            'token' => Auth::issueToken($db, (int) $user['id']),
            'user' => Auth::publicUser($user),
        ]);
    }

    if ($path === '/google/rtdn') {
        handleRtdn($db, $input);
    }

    $user = Auth::user($db);
    $userId = (int) $user['id'];

    if ($path === '/me') {
        Response::json(['user' => Auth::publicUser($user)]);
    }

    if ($path === '/progress/sync') {
        $records = $input['records'] ?? [];
        if (!is_array($records) || count($records) > 400) {
            Response::error('Progress records are invalid.');
        }
        $db->beginTransaction();
        $upsert = $db->prepare(
            'INSERT INTO daily_progress
                (user_id, progress_date, goal, total_count, tap_count, mala_count, write_count)
             VALUES (?, ?, ?, ?, ?, ?, ?)
             ON DUPLICATE KEY UPDATE
                goal = VALUES(goal),
                total_count = GREATEST(total_count, VALUES(total_count)),
                tap_count = GREATEST(tap_count, VALUES(tap_count)),
                mala_count = GREATEST(mala_count, VALUES(mala_count)),
                write_count = GREATEST(write_count, VALUES(write_count))'
        );
        foreach ($records as $record) {
            if (!is_array($record)) {
                continue;
            }
            $date = (string) ($record['date'] ?? '');
            $goal = max(1, min(10_000_000, (int) ($record['goal'] ?? 108)));
            if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $date)) {
                continue;
            }
            $upsert->execute([
                $userId,
                $date,
                $goal,
                clampCount($record['total'] ?? 0),
                clampCount($record['tap'] ?? 0),
                clampCount($record['mala'] ?? 0),
                clampCount($record['write'] ?? 0),
            ]);
        }
        $settings = $input['settings'] ?? [];
        if (is_array($settings)) {
            $settingsJson = json_encode($settings, JSON_UNESCAPED_UNICODE);
            if ($settingsJson !== false && strlen($settingsJson) <= 20_000) {
                $saveSettings = $db->prepare(
                    'INSERT INTO user_settings (user_id, settings_json) VALUES (?, ?)
                     ON DUPLICATE KEY UPDATE settings_json = VALUES(settings_json)'
                );
                $saveSettings->execute([$userId, $settingsJson]);
            }
        }
        $db->commit();
        Response::json(['message' => 'Progress synced.']);
    }

    if ($path === '/subscriptions/google/verify') {
        $productId = trim((string) ($input['product_id'] ?? ''));
        $purchaseToken = trim((string) ($input['purchase_token'] ?? ''));
        $expectedProduct = (string) Env::get(
            'GOOGLE_SUBSCRIPTION_PRODUCT',
            'sankalp_premium_monthly',
        );
        if ($productId !== $expectedProduct || strlen($purchaseToken) < 20) {
            Response::error('The Google Play purchase information is invalid.');
        }

        $google = new GooglePlay();
        $payload = $google->verifySubscription($purchaseToken);
        $lineProducts = array_column($payload['lineItems'] ?? [], 'productId');
        if (!in_array($expectedProduct, $lineProducts, true)) {
            Response::error('The purchase does not match Sankalp Premium.', 422);
        }
        $expiry = GooglePlay::premiumExpiry($payload);
        $status = (string) ($payload['subscriptionState'] ?? 'UNKNOWN');
        $expirySql = $expiry ? gmdate('Y-m-d H:i:s', strtotime($expiry)) : null;
        $tokenHash = hash('sha256', $purchaseToken);

        $owner = $db->prepare(
            'SELECT user_id FROM subscriptions WHERE purchase_token_hash = ? LIMIT 1'
        );
        $owner->execute([$tokenHash]);
        $existingOwner = $owner->fetchColumn();
        if ($existingOwner !== false && (int) $existingOwner !== $userId) {
            Response::error('This subscription is already linked to another account.', 409);
        }

        $statement = $db->prepare(
            'INSERT INTO subscriptions
                (user_id, product_id, purchase_token_hash, purchase_id, status, expires_at,
                 provider_payload, last_verified_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, UTC_TIMESTAMP())
             ON DUPLICATE KEY UPDATE
                status = VALUES(status),
                expires_at = VALUES(expires_at),
                provider_payload = VALUES(provider_payload),
                last_verified_at = UTC_TIMESTAMP()'
        );
        $statement->execute([
            $userId,
            $productId,
            $tokenHash,
            substr((string) ($input['purchase_id'] ?? ''), 0, 190) ?: null,
            $status,
            $expirySql,
            json_encode($payload, JSON_UNESCAPED_SLASHES),
        ]);
        updatePremiumUntil($db, $userId);
        Response::json([
            'premium_until' => $expiry
                ? gmdate(DATE_ATOM, strtotime($expiry))
                : null,
            'status' => $status,
        ]);
    }

    Response::error('Route not found.', 404);
} catch (Throwable $error) {
    if (isset($db) && $db->inTransaction()) {
        $db->rollBack();
    }
    error_log($error->__toString());
    Response::error(
        Env::get('APP_ENV', 'production') === 'local'
            ? $error->getMessage()
            : 'The server could not complete this request.',
        500,
    );
}

function clampCount(mixed $value): int
{
    return max(0, min(10_000_000, (int) $value));
}

function updatePremiumUntil(PDO $db, int $userId): void
{
    $statement = $db->prepare(
        "UPDATE users
         SET premium_until = (
             SELECT MAX(expires_at)
             FROM subscriptions
             WHERE user_id = ?
               AND status IN (
                   'SUBSCRIPTION_STATE_ACTIVE',
                   'SUBSCRIPTION_STATE_IN_GRACE_PERIOD'
               )
         )
         WHERE id = ?"
    );
    $statement->execute([$userId, $userId]);
}

function handleRtdn(PDO $db, array $input): never
{
    verifyGooglePushIdentity();
    $encoded = $input['message']['data'] ?? '';
    $notification = json_decode(base64_decode((string) $encoded, true) ?: '', true);
    $subscription = $notification['subscriptionNotification'] ?? null;
    if (!is_array($subscription) || empty($subscription['purchaseToken'])) {
        Response::json(['message' => 'No subscription change to process.']);
    }
    $tokenHash = hash('sha256', (string) $subscription['purchaseToken']);
    $owner = $db->prepare(
        'SELECT user_id FROM subscriptions WHERE purchase_token_hash = ? LIMIT 1'
    );
    $owner->execute([$tokenHash]);
    $userId = $owner->fetchColumn();
    if ($userId === false) {
        Response::json(['message' => 'Purchase is not linked to an account.']);
    }
    $google = new GooglePlay();
    $payload = $google->verifySubscription((string) $subscription['purchaseToken']);
    $expiry = GooglePlay::premiumExpiry($payload);
    $update = $db->prepare(
        'UPDATE subscriptions
         SET status = ?, expires_at = ?, provider_payload = ?, last_verified_at = UTC_TIMESTAMP()
         WHERE purchase_token_hash = ?'
    );
    $update->execute([
        (string) ($payload['subscriptionState'] ?? 'UNKNOWN'),
        $expiry ? gmdate('Y-m-d H:i:s', strtotime($expiry)) : null,
        json_encode($payload, JSON_UNESCAPED_SLASHES),
        $tokenHash,
    ]);
    updatePremiumUntil($db, (int) $userId);
    Response::json(['message' => 'Subscription updated.']);
}

function verifyGooglePushIdentity(): void
{
    $authorization = (string) ($_SERVER['HTTP_AUTHORIZATION'] ?? '');
    if (!preg_match('/^Bearer\s+([A-Za-z0-9._-]+)$/', $authorization, $matches)) {
        Response::error('Authenticated Google Pub/Sub push required.', 401);
    }
    $parts = explode('.', $matches[1]);
    if (count($parts) !== 3) {
        Response::error('Invalid Google identity token.', 401);
    }
    $header = json_decode(base64UrlDecode($parts[0]), true);
    $claims = json_decode(base64UrlDecode($parts[1]), true);
    $signature = base64UrlDecode($parts[2]);
    if (!is_array($header) || !is_array($claims) || empty($header['kid'])) {
        Response::error('Invalid Google identity token.', 401);
    }

    $cache = sys_get_temp_dir() . '/sankalp-google-certs.json';
    $certs = null;
    if (is_file($cache) && filemtime($cache) > time() - 3600) {
        $certs = json_decode((string) file_get_contents($cache), true);
    }
    if (!is_array($certs) || empty($certs[$header['kid']])) {
        $handle = curl_init('https://www.googleapis.com/oauth2/v1/certs');
        curl_setopt_array($handle, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT => 10,
        ]);
        $raw = curl_exec($handle);
        $status = (int) curl_getinfo($handle, CURLINFO_RESPONSE_CODE);
        curl_close($handle);
        $certs = json_decode($raw ?: '', true);
        if ($status !== 200 || !is_array($certs)) {
            Response::error('Unable to verify Google push identity.', 503);
        }
        file_put_contents($cache, json_encode($certs), LOCK_EX);
    }

    $certificate = $certs[$header['kid']] ?? null;
    $verified = $certificate && openssl_verify(
        $parts[0] . '.' . $parts[1],
        $signature,
        $certificate,
        OPENSSL_ALGO_SHA256,
    ) === 1;
    $expectedAudience = (string) Env::get('GOOGLE_RTDN_AUDIENCE', '');
    $expectedEmail = (string) Env::get('GOOGLE_RTDN_SERVICE_ACCOUNT', '');
    $issuer = (string) ($claims['iss'] ?? '');
    if (
        !$verified ||
        $expectedAudience === '' ||
        $expectedEmail === '' ||
        !hash_equals($expectedAudience, (string) ($claims['aud'] ?? '')) ||
        !hash_equals($expectedEmail, (string) ($claims['email'] ?? '')) ||
        !in_array($issuer, ['accounts.google.com', 'https://accounts.google.com'], true) ||
        (int) ($claims['exp'] ?? 0) < time() ||
        (int) ($claims['iat'] ?? 0) > time() + 60
    ) {
        Response::error('Google push identity was not accepted.', 401);
    }
}

function base64UrlDecode(string $value): string
{
    $padding = (4 - strlen($value) % 4) % 4;
    return base64_decode(
        strtr($value, '-_', '+/') . str_repeat('=', $padding),
        true,
    ) ?: '';
}
