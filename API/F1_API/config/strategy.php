<?php

return [
    // Absolute path to the Python interpreter inside the virtual environment
    'python_path' => env('STRATEGY_BOT_PYTHON', base_path('app/Services/StrategyBot/.venv/bin/python')),
];

