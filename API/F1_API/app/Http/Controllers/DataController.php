<?php

namespace App\Http\Controllers;

use App\Models\Driver;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\RateLimiter;

class DataController extends Controller
{
    public function fetchData(Request $request)
    {
        // Limităm endpoint-ul la maximum 10 cereri la fiecare 10 secunde per IP
        $response = RateLimiter::attempt(
            'fetch-data:' . $request->ip(),
            10,
            function () {
                $response = Http::get('https://api.openf1.org/v1/drivers', [
                    'meeting_key' => 1262,
                ]);

                if ($response->successful()) {
                    $data = $response->json();

                    foreach ($data as $driver) {
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

                    return response()->json(['status' => 'ok']);
                }

                return response()->json(['error' => 'Nu s-a putut obține datele'], 500);
            },
            10
        );

        if ($response === false) {
            return response()->json(['error' => 'Too many requests'], 429);
        }

        return $response;
    }
}
