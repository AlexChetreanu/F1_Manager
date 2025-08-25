<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Jobs\RunStrategyBot;

class StrategyBotRun extends Command
{
    protected $signature = 'strategy:run {meeting_key}';
    protected $description = 'Dispatch the F1 strategy bot job';

    public function handle(): int
    {
        $meetingKey = (int) $this->argument('meeting_key');
        RunStrategyBot::dispatch($meetingKey);

        $python = config('strategy.python_path');
        $script = config('strategy.script_path', base_path('app/Services/StrategyBot/strategy_bot_openf1.py'));
        $this->info("Dispatched meeting {$meetingKey} using {$python} -> {$script}");

        return self::SUCCESS;
    }
}
