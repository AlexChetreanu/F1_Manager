<?php

namespace App\Jobs;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
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
        $script = config('strategy.script_path', base_path('app/Services/StrategyBot/strategy_bot_openf1.py'));

        if (! is_executable($python)) {
            Log::error('strategy bot python not executable', ['python' => $python, 'meeting_key' => $this->meetingKey]);
            Cache::forget("strategy_running_{$this->meetingKey}");
            return;
        }

        if (! file_exists($script)) {
            Log::error('strategy bot script missing', ['script' => $script, 'meeting_key' => $this->meetingKey]);
            Cache::forget("strategy_running_{$this->meetingKey}");
            return;
        }

        $env = [
            'OF1_BASE' => config('strategy.of1_base'),
            'OF1_DEBUG' => '1',
        ];

        $process = new Process([
            $python,
            $script,
            '--meeting-key', (string) $this->meetingKey,
            '--all',
        ], base_path(), $env);

        Log::info('running strategy bot', [
            'meeting_key' => $this->meetingKey,
            'cmd' => [$python, $script, '--meeting-key', (string) $this->meetingKey, '--all'],
            'env' => $env,
        ]);

        $process->run();

        $stdout = Str::limit($process->getOutput(), 200);
        $stderr = Str::limit($process->getErrorOutput(), 200);

        Log::info('strategy bot finished', [
            'meeting_key' => $this->meetingKey,
            'stdout' => $stdout,
            'stderr' => $stderr,
        ]);

        if (! $process->isSuccessful()) {
            Cache::forget("strategy_running_{$this->meetingKey}");
            Log::error('strategy bot failed', [
                'meeting_key' => $this->meetingKey,
                'stderr' => $stderr,
            ]);
            return;
        }

        try {
            $data = json_decode($process->getOutput(), true, flags: JSON_THROW_ON_ERROR);
            Cache::put(
                "strategy_suggestions_{$this->meetingKey}",
                $data,
                now()->addSeconds(config('strategy.cache_ttl'))
            );
            Log::info('strategy bot cached suggestions', ['meeting_key' => $this->meetingKey]);
        } catch (\Throwable $e) {
            Log::error('Invalid JSON from bot', [
                'meeting_key' => $this->meetingKey,
                'payload' => $stdout,
                'exception' => $e->getMessage(),
            ]);
        } finally {
            Cache::forget("strategy_running_{$this->meetingKey}");
        }
    }
}

