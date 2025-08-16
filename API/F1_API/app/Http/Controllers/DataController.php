<?php

namespace App\Http\Controllers;

use App\Models\Driver;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;

class DataController extends Controller
{
    public function fetchData(Request $request)
    {
        $meetingsResponse = Http::get('https://api.openf1.org/v1/meetings', [
            'year' => 2024,
        ]);

        if (!$meetingsResponse->successful()) {
            return response()->json(['error' => 'Nu s-au putut obține meeting-urile'], 500);
        }

        $meetings = $meetingsResponse->json();

        foreach ($meetings as $meeting) {
            $meetingKey = $meeting['meeting_key'] ?? null;

            if (!$meetingKey) {
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

            sleep(1);
        }

        return response()->json(['message' => 'Piloții au fost salvați']);
    }
}
