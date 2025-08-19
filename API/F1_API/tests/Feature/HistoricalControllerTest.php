<?php

use Illuminate\Support\Facades\Http;
use Illuminate\Http\Request;
use App\Http\Controllers\HistoricalController;

it('punctual frame interpolates', function () {
    Http::fake([
        'https://api.openf1.org/v1/location*' => Http::response([
            ['driver_number' => '1', 'date' => '2024-05-04T16:05:12.000Z', 'x' => 0, 'y' => 0, 'speed' => 0, 'n_gear' => 1],
            ['driver_number' => '1', 'date' => '2024-05-04T16:05:12.400Z', 'x' => 4, 'y' => 4, 'speed' => 100, 'n_gear' => 6],
        ], 200),
    ]);

    $controller = new HistoricalController();
    $req = Request::create('/', 'GET', ['t' => '2024-05-04T16:05:12.200Z', 'include' => 'speed,gear']);
    $resp = $controller->frames(9506, $req);
    $json = $resp->getData(true);
    expect($json[0]['drivers'][0])->toBe(['1', 2, 2, 50, 6]);
});

it('window json and ndjson return frames', function () {
    Http::fake([
        'https://api.openf1.org/v1/location*' => Http::response([
            ['driver_number' => '1', 'date' => '2024-05-04T16:00:00.000Z', 'x' => 0, 'y' => 0],
            ['driver_number' => '2', 'date' => '2024-05-04T16:00:00.000Z', 'x' => 0, 'y' => 1],
            ['driver_number' => '1', 'date' => '2024-05-04T16:00:00.200Z', 'x' => 2, 'y' => 0],
            ['driver_number' => '1', 'date' => '2024-05-04T16:00:00.400Z', 'x' => 4, 'y' => 0],
            ['driver_number' => '2', 'date' => '2024-05-04T16:00:00.400Z', 'x' => 0, 'y' => 1],
        ], 200),
    ]);

    $controller = new HistoricalController();
    $req = Request::create('/', 'GET', [
        'from' => '2024-05-04T16:00:00.000Z',
        'to' => '2024-05-04T16:00:00.400Z',
        'stride_ms' => 200,
    ]);
    $json = $controller->frames(9506, $req)->getData(true);
    expect($json)->toHaveCount(3);

    $reqNd = Request::create('/', 'GET', [
        'from' => '2024-05-04T16:00:00.000Z',
        'to' => '2024-05-04T16:00:00.400Z',
        'stride_ms' => 200,
        'format' => 'ndjson'
    ]);
    $stream = $controller->frames(9506, $reqNd);
    expect($stream)->toBeInstanceOf(\Symfony\Component\HttpFoundation\StreamedResponse::class);
});

it('delta returns only changed drivers', function () {
    Http::fake([
        'https://api.openf1.org/v1/location*' => Http::response([
            ['driver_number' => '1', 'date' => '2024-05-04T16:00:00.000Z', 'x' => 0, 'y' => 0],
            ['driver_number' => '2', 'date' => '2024-05-04T16:00:00.000Z', 'x' => 0, 'y' => 0],
            ['driver_number' => '1', 'date' => '2024-05-04T16:00:00.200Z', 'x' => 2, 'y' => 0],
            ['driver_number' => '2', 'date' => '2024-05-04T16:00:00.200Z', 'x' => 0, 'y' => 0],
        ], 200),
    ]);

    $controller = new HistoricalController();
    $req = Request::create('/', 'GET', [
        'from' => '2024-05-04T16:00:00.000Z',
        'to' => '2024-05-04T16:00:00.200Z',
        'stride_ms' => 200,
        'delta' => '1',
    ]);
    $frames = $controller->frames(9506, $req)->getData(true);
    expect($frames[1]['drivers'])->toHaveCount(1);
    expect($frames[1]['drivers'][0][0])->toBe('1');
});

it('passes driver filters to OpenF1', function () {
    $captured = null;
    Http::fake(function ($request) use (&$captured) {
        $captured = $request;
        return Http::response([], 200);
    });
    $controller = new HistoricalController();
    $req = Request::create('/', 'GET', [
        'from' => '2024-05-04T16:00:00.000Z',
        'to' => '2024-05-04T16:00:01.000Z',
        'stride_ms' => 200,
        'drivers' => '4,1,16'
    ]);
    $controller->frames(9506, $req);

    expect($captured->url())->toContain('driver_number%5B0%5D=4');
    expect($captured->url())->toContain('driver_number%5B1%5D=1');
    expect($captured->url())->toContain('driver_number%5B2%5D=16');
});
