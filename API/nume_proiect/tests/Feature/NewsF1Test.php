<?php

namespace Tests\Feature;

use App\Services\AutosportRss;
use Carbon\Carbon;
use Illuminate\Support\Facades\Cache;
use Illuminate\Testing\Fluent\AssertableJson;
use Tests\TestCase;

class NewsF1Test extends TestCase
{
    private function stubService(): AutosportRss
    {
        return new class extends AutosportRss {
            private array $items;
            public function __construct()
            {
                $this->items = [
                    [
                        'id' => '1',
                        'title' => 'Recent 1',
                        'link' => 'https://example.com/1',
                        'published_at' => '2024-01-09T10:00:00Z',
                        'image_url' => 'https://example.com/img1.jpg',
                        'source' => 'Autosport',
                        'excerpt' => 'Desc1',
                    ],
                    [
                        'id' => '2',
                        'title' => 'Recent 2',
                        'link' => 'https://example.com/2',
                        'published_at' => '2024-01-08T09:00:00Z',
                        'image_url' => 'https://example.com/img2.jpg',
                        'source' => 'Autosport',
                        'excerpt' => 'Desc2',
                    ],
                    [
                        'id' => '3',
                        'title' => 'Recent 3 no image',
                        'link' => 'https://example.com/3',
                        'published_at' => '2024-01-07T08:00:00Z',
                        'image_url' => null,
                        'source' => 'Autosport',
                        'excerpt' => 'Desc3',
                    ],
                    [
                        'id' => '4',
                        'title' => 'Recent 4',
                        'link' => 'https://example.com/4',
                        'published_at' => '2024-01-06T07:00:00Z',
                        'image_url' => 'https://example.com/img4.jpg',
                        'source' => 'Autosport',
                        'excerpt' => 'Desc4',
                    ],
                ];
            }

            public function fetch(int $days = 30, int $limit = 20, ?int $year = null): array
            {
                $key = $year ? "stub_year_{$year}_limit_{$limit}" : "stub_days_{$days}_limit_{$limit}";
                return Cache::remember($key, 3600, function () use ($limit) {
                    return array_slice($this->items, 0, $limit);
                });
            }
        };
    }

    public function test_f1_news_endpoint_returns_items()
    {
        Carbon::setTestNow('2024-01-10T00:00:00Z');
        Cache::flush();
        $this->app->instance(AutosportRss::class, $this->stubService());

        $response = $this->getJson('/api/news/f1?days=30&limit=3');

        $response->assertStatus(200)
            ->assertJsonCount(3)
            ->assertJson(fn(AssertableJson $json) =>
                $json->each(fn(AssertableJson $item) =>
                    $item->hasAll(['id','title','link','published_at','image_url','source','excerpt'])
                )
            );

        $data = $response->json();
        $this->assertNotNull(Carbon::parse($data[0]['published_at']));
        $this->assertTrue(collect($data)->contains(fn($it) => $it['image_url'] === null));
    }

    public function test_f1_news_endpoint_defaults_return_multiple_items()
    {
        Carbon::setTestNow('2024-01-10T00:00:00Z');
        Cache::flush();
        $this->app->instance(AutosportRss::class, $this->stubService());

        $response = $this->getJson('/api/news/f1');
        $response->assertStatus(200);
        $this->assertGreaterThanOrEqual(2, count($response->json()));
    }

    public function test_cache_key_includes_limit()
    {
        Carbon::setTestNow('2024-01-10T00:00:00Z');
        Cache::flush();
        $this->app->instance(AutosportRss::class, $this->stubService());

        $first = $this->getJson('/api/news/f1?days=30&limit=1');
        $first->assertStatus(200)->assertJsonCount(1);

        $second = $this->getJson('/api/news/f1?days=30&limit=20');
        $second->assertStatus(200);
        $this->assertTrue(count($second->json()) > 1);
    }
}
