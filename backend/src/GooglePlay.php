<?php

declare(strict_types=1);

namespace Sankalp;

use RuntimeException;

final class GooglePlay
{
    private array $credentials;

    public function __construct()
    {
        $path = Env::get('GOOGLE_SERVICE_ACCOUNT_JSON');
        if (!$path || !is_file($path)) {
            throw new RuntimeException('Google Play service account is not configured.');
        }
        $decoded = json_decode((string) file_get_contents($path), true);
        if (!is_array($decoded) || empty($decoded['client_email']) || empty($decoded['private_key'])) {
            throw new RuntimeException('Google Play service account file is invalid.');
        }
        $this->credentials = $decoded;
    }

    public function verifySubscription(string $purchaseToken): array
    {
        $package = rawurlencode((string) Env::get('GOOGLE_PACKAGE_NAME'));
        $token = rawurlencode($purchaseToken);
        return $this->request(
            'GET',
            "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{$package}/purchases/subscriptionsv2/tokens/{$token}",
        );
    }

    public static function premiumExpiry(array $payload): ?string
    {
        $allowed = [
            'SUBSCRIPTION_STATE_ACTIVE',
            'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
        ];
        if (!in_array($payload['subscriptionState'] ?? '', $allowed, true)) {
            return null;
        }
        $expiry = null;
        foreach ($payload['lineItems'] ?? [] as $item) {
            $candidate = $item['expiryTime'] ?? null;
            if ($candidate && ($expiry === null || strtotime($candidate) > strtotime($expiry))) {
                $expiry = $candidate;
            }
        }
        return $expiry;
    }

    private function accessToken(): string
    {
        $now = time();
        $header = $this->base64Url(json_encode(['alg' => 'RS256', 'typ' => 'JWT']));
        $payload = $this->base64Url(json_encode([
            'iss' => $this->credentials['client_email'],
            'scope' => 'https://www.googleapis.com/auth/androidpublisher',
            'aud' => $this->credentials['token_uri'] ?? 'https://oauth2.googleapis.com/token',
            'iat' => $now,
            'exp' => $now + 3600,
        ]));
        $unsigned = $header . '.' . $payload;
        if (!openssl_sign($unsigned, $signature, $this->credentials['private_key'], OPENSSL_ALGO_SHA256)) {
            throw new RuntimeException('Unable to sign Google access token.');
        }
        $jwt = $unsigned . '.' . $this->base64Url($signature);
        $response = $this->requestForm(
            $this->credentials['token_uri'] ?? 'https://oauth2.googleapis.com/token',
            [
                'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion' => $jwt,
            ],
        );
        if (empty($response['access_token'])) {
            throw new RuntimeException('Google access token was not returned.');
        }
        return $response['access_token'];
    }

    private function request(string $method, string $url): array
    {
        return $this->curl($method, $url, [
            'Authorization: Bearer ' . $this->accessToken(),
            'Accept: application/json',
        ]);
    }

    private function requestForm(string $url, array $fields): array
    {
        return $this->curl('POST', $url, ['Content-Type: application/x-www-form-urlencoded'], http_build_query($fields));
    }

    private function curl(string $method, string $url, array $headers, ?string $body = null): array
    {
        $handle = curl_init($url);
        curl_setopt_array($handle, [
            CURLOPT_CUSTOMREQUEST => $method,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_HTTPHEADER => $headers,
            CURLOPT_TIMEOUT => 20,
            CURLOPT_POSTFIELDS => $body,
        ]);
        $raw = curl_exec($handle);
        $status = (int) curl_getinfo($handle, CURLINFO_RESPONSE_CODE);
        $error = curl_error($handle);
        curl_close($handle);
        if ($raw === false || $error !== '') {
            throw new RuntimeException('Google request failed: ' . $error);
        }
        $decoded = json_decode($raw, true);
        if ($status < 200 || $status >= 300 || !is_array($decoded)) {
            throw new RuntimeException('Google rejected the subscription verification.');
        }
        return $decoded;
    }

    private function base64Url(string $value): string
    {
        return rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
    }
}

