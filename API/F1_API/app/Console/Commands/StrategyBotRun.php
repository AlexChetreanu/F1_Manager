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
        $this->info("Strategy bot job dispatched for meeting {$meetingKey}.");

        return self::SUCCESS;
    }
}
