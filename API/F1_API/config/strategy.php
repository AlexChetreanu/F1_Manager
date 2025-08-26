<?php

return [
    'python_path' => env('STRATEGY_BOT_PYTHON', base_path('.venv/bin/python')),
    'script_path' => env('STRATEGY_BOT_SCRIPT', base_path('app/Services/StrategyBot/strategy_bot_openf1.py')),
    'cache_ttl'   => (int) env('STRATEGY_CACHE_TTL', 600),
];

