<?php

return [
    // Absolute path to the Python interpreter inside the virtual environment
    'python_path' => env('STRATEGY_BOT_PYTHON', base_path('app/Services/StrategyBot/.venv/bin/python')),

    // Absolute path to the strategy bot script
    'script_path' => env('STRATEGY_BOT_SCRIPT', base_path('app/Services/StrategyBot/strategy_bot_openf1.py')),

    // Base URL for OpenF1-compatible API
    'of1_base' => env('OF1_BASE', 'https://api.openf1.org/v1'),

    // Cache TTL for strategy suggestions (seconds)
    'cache_ttl' => env('STRATEGY_CACHE_TTL', 600),
];

