<?php

declare(strict_types=1);

namespace Sankalp;

use PDO;

final class Auth
{
    public static function issueToken(PDO $db, int $userId): string
    {
        $plain = bin2hex(random_bytes(32));
        $statement = $db->prepare(
            'INSERT INTO api_tokens (user_id, token_hash, expires_at)
             VALUES (?, ?, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 365 DAY))'
        );
        $statement->execute([$userId, hash('sha256', $plain)]);
        return $plain;
    }

    public static function user(PDO $db): array
    {
        $header = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
        if (!preg_match('/^Bearer\s+(.+)$/i', $header, $matches)) {
            Response::error('Authentication required.', 401);
        }

        $statement = $db->prepare(
            'SELECT u.id, u.name, u.email, u.premium_until
             FROM api_tokens t
             INNER JOIN users u ON u.id = t.user_id
             WHERE t.token_hash = ? AND t.expires_at > UTC_TIMESTAMP()
             LIMIT 1'
        );
        $statement->execute([hash('sha256', trim($matches[1]))]);
        $user = $statement->fetch();
        if (!$user) {
            Response::error('Your session has expired. Please sign in again.', 401);
        }

        $db->prepare(
            'UPDATE api_tokens SET last_used_at = UTC_TIMESTAMP() WHERE token_hash = ?'
        )->execute([hash('sha256', trim($matches[1]))]);
        return $user;
    }

    public static function publicUser(array $user): array
    {
        return [
            'id' => (int) $user['id'],
            'name' => $user['name'],
            'email' => $user['email'],
            'premium_until' => $user['premium_until']
                ? gmdate(DATE_ATOM, strtotime($user['premium_until'] . ' UTC'))
                : null,
        ];
    }
}

