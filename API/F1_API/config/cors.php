<?php

return [
    'paths' => ['api/*', 'sanctum/csrf-cookie'],
    'allowed_methods' => ['*'],
    'allowed_origins' => ['http://localhost:5173'],
    'allowed_origins_patterns' => [
        '#^http://([0-9]{1,3}\.){3}[0-9]{1,3}:5173$#',
        '#^http://[A-Za-z0-9\\-]+\.local:5173$#',
    ],
    'allowed_headers' => ['*'],
    'exposed_headers' => [],
    'max_age' => 0,
    'supports_credentials' => true,
];

