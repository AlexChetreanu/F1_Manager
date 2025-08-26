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

        $cmd = [
            $python,
            $script,
            '--meeting-key',
            (string) $this->meetingKey,
            '--all',
        ];

        $env = [
            'OF1_BASE' => env('OF1_BASE', 'https://api.openf1.org/v1'),
            'OF1_DEBUG' => '0',
        ];

        $process = new Process($cmd, base_path(), $env);
        $process->setTimeout(180);
        $process->run();

        $stdout = $process->getOutput();
        $stderr = $process->getErrorOutput();

        if (! $process->isSuccessful()) {
            Log::error('Strategy bot failed', [
                'meeting' => $this->meetingKey,
                'exit_code' => $process->getExitCode(),
                'stderr' => Str::limit($stderr, 200),
            ]);
            return;
        }

        $start = strpos($stdout, '{');
        $end = strrpos($stdout, '}');
        if ($start === false || $end === false || $end < $start) {
            Log::error('Invalid JSON from bot', [
                'meeting' => $this->meetingKey,
                'payload' => Str::limit($stdout, 200),
                'stderr' => Str::limit($stderr, 200),
            ]);
            return;
        }

        $json = substr($stdout, $start, $end - $start + 1);
        $data = json_decode($json, true);

        if (! is_array($data)) {
            Log::error('Invalid JSON from bot', [
                'meeting' => $this->meetingKey,
                'payload' => Str::limit($json, 200),
                'stderr' => Str::limit($stderr, 200),
            ]);
            return;
        }

        if (isset($data['suggestion']) && ! isset($data['suggestions'])) {
            $data['suggestions'] = $data['suggestion'] ? [$data['suggestion']] : [];
            unset($data['suggestion']);
        }

        $data['suggestions'] = $data['suggestions'] ?? [];

        Cache::put(
            "strategy_suggestions_{$this->meetingKey}",
            $data,
            now()->addSeconds(config('strategy.cache_ttl'))
        );

        Log::info('Strategy cached', [
            'meeting' => $this->meetingKey,
            'count' => count($data['suggestions']),
        ]);
    }
}

