<?php

namespace App\Jobs;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;
use Symfony\Component\Process\Process;

class RunStrategyBot implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public function __construct(public int $meetingKey)
    {
    }

    public function handle(): void
    {
        $python = config('strategy.python_path');
        $script = base_path('app/Services/StrategyBot/strategy_bot_openf1.py');

        $process = new Process([$python, $script, '--meeting-key', (string) $this->meetingKey]);
        $process->run();

        Log::info('strategy bot stdout', [
            'meeting_key' => $this->meetingKey,
            'stdout' => $process->getOutput(),
        ]);

        if (! $process->isSuccessful()) {
            Log::error('strategy bot failed', [
                'meeting_key' => $this->meetingKey,
                'stderr' => $process->getErrorOutput(),
            ]);
            return;
        }

        try {
            $data = json_decode($process->getOutput(), true, flags: JSON_THROW_ON_ERROR);
            Cache::put("strategy_suggestions_{$this->meetingKey}", $data, now()->addMinutes(10));
        } catch (\Throwable $e) {
            Log::error('Invalid JSON from bot', [
                'meeting_key' => $this->meetingKey,
                'exception' => $e->getMessage(),
            ]);
        }
    }
}

