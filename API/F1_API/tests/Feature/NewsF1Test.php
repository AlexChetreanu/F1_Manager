<?php

use App\Http\Controllers\NewsController;
use App\Services\AutosportRss;
use Carbon\Carbon;
use GuzzleHttp\Client;
use GuzzleHttp\Handler\MockHandler;
use GuzzleHttp\HandlerStack;
use GuzzleHttp\Psr7\Response;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;

it('returns filtered and sorted news items', function () {
    Carbon::setTestNow('2025-08-20T15:00:00Z');

    $xml = file_get_contents(base_path('tests/Fixtures/autosport_f1.xml'));
    $mock = new MockHandler([new Response(200, [], $xml)]);
    $client = new Client(['handler' => HandlerStack::create($mock)]);
    $service = new AutosportRss($client);

    Cache::shouldReceive('remember')->andReturnUsing(function ($key, $ttl, $callback) {
        return $callback();
    });

    $controller = new NewsController();
    $request = Request::create('/api/news/f1', 'GET', ['year' => 2025, 'limit' => 2]);
    $response = $controller->f1Autosport($request, $service);

    $data = $response->getData(true);
    expect($data)->toHaveCount(2);
    expect($data[0]['title'])->toBe('First article');
    expect($data[1]['title'])->toBe('Second article');
    expect($data[0]['published_at'])->toBe('2025-08-20T12:00:00+00:00');
    expect($data[1]['image_url'])->toBe('https://example.com/second.jpg');
});
