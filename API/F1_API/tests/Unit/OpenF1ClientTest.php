<?php

use App\Services\OpenF1Client;
use Illuminate\Support\Facades\Http;

it('fetches drivers from OpenF1 API', function () {
    Http::fake([
        'api.openf1.org/v1/drivers*' => Http::response([
            ['full_name' => 'Test Driver'],
        ], 200),
    ]);

    $client = new OpenF1Client('https://api.openf1.org/v1');
    $drivers = $client->fetchDrivers(['meeting_key' => 123]);

    expect($drivers)->toBe([
        ['full_name' => 'Test Driver'],
    ]);
});
