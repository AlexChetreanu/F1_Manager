<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\Cache;
use Symfony\Component\Process\Process;

class StrategyBotRun extends Command
{
    protected $signature = 'strategy:run {meeting_key}';
    protected $description = 'Run the F1 strategy bot and cache its suggestions';

    public function handle(): int
    {
        $meetingKey = (int)$this->argument('meeting_key');
        $script = base_path('app/Services/StrategyBot/strategy_bot_openf1.py');
        $process = new Process(['python3', $script, '--meeting-key', (string)$meetingKey]);
        $process->run();

        if (! $process->isSuccessful()) {
            $this->error($process->getErrorOutput());
            return self::FAILURE;
        }

        $output = $process->getOutput();
        try {
            $data = json_decode($output, true, flags: JSON_THROW_ON_ERROR);
            Cache::put("strategy_suggestions_{$meetingKey}", $data, now()->addMinutes(10));
            $this->info('Strategy suggestions cached.');
        } catch (\Throwable $e) {
            $this->error('Invalid JSON from bot: '.$e->getMessage());
            return self::FAILURE;
        }

        return self::SUCCESS;
    }
}
