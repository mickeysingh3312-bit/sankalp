<?php

declare(strict_types=1);

use Sankalp\Database;
use Sankalp\Env;

require dirname(__DIR__, 2) . '/src/Env.php';
require dirname(__DIR__, 2) . '/src/Database.php';
Env::load(dirname(__DIR__, 2) . '/.env');

$username = $_SERVER['PHP_AUTH_USER'] ?? '';
$password = $_SERVER['PHP_AUTH_PW'] ?? '';
$configuredPassword = (string) Env::get('ADMIN_PASSWORD', '');
if ($configuredPassword === '') {
    http_response_code(503);
    exit('Set ADMIN_PASSWORD before using the admin dashboard.');
}
if (
    !hash_equals((string) Env::get('ADMIN_USERNAME', 'admin'), $username) ||
    !hash_equals($configuredPassword, $password)
) {
    header('WWW-Authenticate: Basic realm="Sankalp Admin"');
    http_response_code(401);
    exit('Authentication required.');
}

$db = Database::connection();
$metrics = [
    'Users' => (int) $db->query('SELECT COUNT(*) FROM users')->fetchColumn(),
    'Premium' => (int) $db->query(
        'SELECT COUNT(*) FROM users WHERE premium_until > UTC_TIMESTAMP()'
    )->fetchColumn(),
    'Naam today' => (int) $db->query(
        'SELECT COALESCE(SUM(total_count), 0) FROM daily_progress
         WHERE progress_date = UTC_DATE()'
    )->fetchColumn(),
    'Active today' => (int) $db->query(
        'SELECT COUNT(*) FROM daily_progress WHERE progress_date = UTC_DATE()'
    )->fetchColumn(),
];
$users = $db->query(
    'SELECT u.name, u.email, u.premium_until, u.created_at,
            COALESCE(SUM(p.total_count), 0) AS lifetime
     FROM users u
     LEFT JOIN daily_progress p ON p.user_id = u.id
     GROUP BY u.id
     ORDER BY u.created_at DESC
     LIMIT 100'
)->fetchAll();
?>
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Sankalp Admin</title>
  <style>
    body{margin:0;background:#fff8ee;color:#3a2b1d;font:15px system-ui,sans-serif}
    main{max-width:1100px;margin:auto;padding:28px 18px}
    h1{color:#e85d04}.cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:14px}
    .card{background:#fff;border-radius:18px;padding:18px;box-shadow:0 2px 14px #4c2d1114}
    .value{font-size:30px;font-weight:800;color:#e85d04}table{width:100%;border-collapse:collapse}
    th,td{text-align:left;padding:12px;border-bottom:1px solid #eadbc7}th{color:#8a7660}
    .table{overflow:auto;margin-top:20px}.active{color:#2e7d32;font-weight:700}
  </style>
</head>
<body><main>
  <h1>ॐ Sankalp Admin</h1>
  <div class="cards">
    <?php foreach ($metrics as $label => $value): ?>
      <div class="card"><div class="value"><?= number_format($value) ?></div><div><?= htmlspecialchars($label) ?></div></div>
    <?php endforeach ?>
  </div>
  <div class="card table">
    <h2>Latest users</h2>
    <table><thead><tr><th>Name</th><th>Email</th><th>Lifetime Naam</th><th>Premium</th><th>Joined</th></tr></thead>
    <tbody>
    <?php foreach ($users as $user): ?>
      <?php $active = $user['premium_until'] && strtotime($user['premium_until'] . ' UTC') > time(); ?>
      <tr>
        <td><?= htmlspecialchars($user['name']) ?></td>
        <td><?= htmlspecialchars($user['email']) ?></td>
        <td><?= number_format((int) $user['lifetime']) ?></td>
        <td class="<?= $active ? 'active' : '' ?>"><?= $active ? 'Active' : 'Free' ?></td>
        <td><?= htmlspecialchars($user['created_at']) ?></td>
      </tr>
    <?php endforeach ?>
    </tbody></table>
  </div>
</main></body></html>
