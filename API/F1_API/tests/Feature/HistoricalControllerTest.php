<?php

use Illuminate\Support\Facades\Http;
use Carbon\Carbon;

it('resolves session by year and circuit', function () {
    Http::fake([
        'https://api.openf1.org/v1/sessions*' => Http::response([
            [
                'session_key' => 9506,
                'meeting_key' => 123,
                'date_start' => '2024-05-04T15:00:00Z',
                'date_end' => '2024-05-04T17:00:00Z',
                'circuit_key' => 1,
            ]
        ], 200),
    ]);

    $response = $this->getJson('/api/historical/resolve?year=2024&circuit_key=1&session_type=Race');
    $response->assertStatus(200)
        ->assertJson([
            'session_key' => 9506,
            'meeting_key' => 123,
            'circuit_key' => 1,
        ]);
});

it('returns punctual frame', function () {
    Http::fake([
        'https://api.openf1.org/v1/location*' => Http::response([
            ['driver_number' => '1', 'x' => 10, 'y' => 20, 'speed' => 250, 'n_gear' => 6],
            ['driver_number' => '4', 'x' => 15, 'y' => 24, 'speed' => 240, 'n_gear' => 5],
        ], 200),
    ]);

    $t = urlencode('2024-05-04T16:05:12Z');
    $response = $this->getJson("/api/historical/session/9506/frames?t={$t}&include=speed,gear");
    $response->assertStatus(200);
    $json = $response->json();
    expect($json)->toHaveCount(1);
    expect($json[0]['drivers'][0])->toBe(['1', 10, 20, 250, 6]);
    expect($json[0]['fields'])->toBe(['n','x','y','v','gear']);
});

it('returns window frames in json and ndjson', function () {
    Http::fake([
        'https://api.openf1.org/v1/location*' => Http::sequence()
            ->push([
                ['driver_number' => '1', 'x' => 1, 'y' => 1],
                ['driver_number' => '2', 'x' => 2, 'y' => 2],
            ], 200)
            ->push([
                ['driver_number' => '1', 'x' => 2, 'y' => 1],
                ['driver_number' => '2', 'x' => 2, 'y' => 2],
            ], 200)
            ->push([
                ['driver_number' => '1', 'x' => 3, 'y' => 1],
                ['driver_number' => '2', 'x' => 2, 'y' => 2],
            ], 200),
    ]);

    $from = urlencode('2024-05-04T16:00:00Z');
    $to = urlencode('2024-05-04T16:00:00.400Z');

    $jsonResp = $this->getJson("/api/historical/session/9506/frames?from={$from}&to={$to}&stride_ms=200");
    $jsonResp->assertStatus(200);
    expect($jsonResp->json())->toHaveCount(3);

    $ndjson = $this->get("/api/historical/session/9506/frames?from={$from}&to={$to}&stride_ms=200&format=ndjson&delta=1");
    $ndjson->assertStatus(200);
    $lines = array_filter(explode("\n", trim($ndjson->getContent())));
    expect($lines)->toHaveCount(3);
});

it('returns drivers and track info', function () {
    Http::fake([
        'https://api.openf1.org/v1/drivers*' => Http::response([
            ['driver_number' => 1, 'first_name' => 'Max', 'last_name' => 'Verstappen', 'team_name' => 'Red Bull', 'team_colour' => '#3671C6', 'headshot_url' => 'http://example.com/img.jpg'],
        ], 200),
        'https://api.openf1.org/v1/sessions*' => Http::response([
            ['circuit_key' => 1, 'circuit_short_name' => 'Test', 'circuit_map' => 'http://example.com/map.png'],
        ], 200),
    ]);

    $drivers = $this->getJson('/api/historical/session/9506/drivers');
    $drivers->assertStatus(200)
        ->assertJson([
            ['driver_number' => '1', 'full_name' => 'Max Verstappen'],
        ]);

    $track = $this->getJson('/api/historical/session/9506/track');
    $track->assertStatus(200)
        ->assertJson([
            'circuit_key' => 1,
            'map' => ['bounds' => ['minX' => -5000]],
        ]);
});
