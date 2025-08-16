<?php

namespace App\Jobs;

use App\Models\Driver;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Http;

class FetchDriversJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    /**
     * Execute the job.
     */
    public function handle(): void
    {
        $meetingsResponse = Http::get('https://api.openf1.org/v1/meetings', [
            'year' => 2024,
        ]);

        if (! $meetingsResponse->successful()) {
            return;
        }

        foreach ($meetingsResponse->json() as $meeting) {
            $meetingKey = $meeting['meeting_key'] ?? null;

            if (! $meetingKey) {
                continue;
            }

            $driversResponse = Http::get('https://api.openf1.org/v1/drivers', [
                'meeting_key' => $meetingKey,
            ]);

            if ($driversResponse->successful()) {
                foreach ($driversResponse->json() as $driver) {
                    $fullName = trim($driver['full_name'] ?? 'Unknown');

                    Driver::updateOrCreate(
                        ['name' => $fullName],
                        [
                            'team' => $driver['team_name'] ?? 'N/A',
                            'points' => 0,
                            'driver_number' => $driver['driver_number'] ?? 0,
                            'country_code' => $driver['country_code'] ?? 'N/A',
                        ]
                    );
                }
            }
        }
    }
}
