<?php

namespace App\Console;

use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Console\Kernel as ConsoleKernel;

class Kernel extends ConsoleKernel
{
    protected function schedule(Schedule $schedule): void
    {
        $schedule->command('strategy:run', [cache('strategy_active_session')])
            ->everyThirtySeconds()
            ->when(fn () => cache()->has('strategy_active_session'));
    }

    protected function commands(): void
    {
        $this->load(__DIR__.'/Commands');
    }
}
