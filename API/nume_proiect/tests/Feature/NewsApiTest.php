<?php

namespace Tests\Feature;

use App\Services\AutosportRss;
use Carbon\Carbon;
use Illuminate\Testing\Fluent\AssertableJson;
use Tests\TestCase;

class NewsApiTest extends TestCase
{
    public function test_f1_news_endpoint_returns_items()
    {
        Carbon::setTestNow('2024-01-10T00:00:00Z');

        $stub = new class extends AutosportRss {
            public function fetch(): array
            {
                $xmlStr = file_get_contents(base_path('tests/fixtures/autosport_f1.xml'));
                $xml = simplexml_load_string($xmlStr);
                $xml->registerXPathNamespace('media', 'http://search.yahoo.com/mrss/');

                $out = [];
                foreach ($xml->channel->item as $item) {
                    $media = $item->children('media', true);
                    $img = null;
                    if ($media && isset($media->content)) {
                        $attrs = $media->content->attributes();
                        if (isset($attrs['url'])) {
                            $img = (string) $attrs['url'];
                        }
                    }
                    if (!$img && isset($item->enclosure)) {
                        $attrs = $item->enclosure->attributes();
                        if (isset($attrs['url'])) {
                            $img = (string) $attrs['url'];
                        }
                    }
                    $link = (string) $item->link;
                    $published = Carbon::parse((string) $item->pubDate)->utc()->toIso8601String();
                    $desc = \Illuminate\Support\Str::of((string) $item->description)->stripTags()->squish();
                    $out[] = [
                        'id' => sha1($link),
                        'title' => (string) $item->title,
                        'link' => $link,
                        'published_at' => $published,
                        'image_url' => $img ?: null,
                        'source' => 'Autosport',
                        'excerpt' => \Illuminate\Support\Str::limit($desc, 240),
                    ];
                }
                return $out;
            }
        };

        $this->app->instance(AutosportRss::class, $stub);

        $response = $this->getJson('/api/news/f1?days=30&limit=3');

        $response->assertStatus(200)
            ->assertJsonCount(3)
            ->assertJson(fn(AssertableJson $json) =>
                $json->each(fn(AssertableJson $item) =>
                    $item->hasAll(['id','title','link','published_at','image_url','source','excerpt'])
                )
            );

        $data = $response->json();
        $this->assertEquals(3, count($data));
        $this->assertEquals($data[0]['published_at'], Carbon::parse($data[0]['published_at'])->toIso8601String());
        $this->assertTrue(collect($data)->contains(fn($it) => $it['image_url'] === null));
    }
}
