<?php

namespace App\Services;

use Carbon\Carbon;
use GuzzleHttp\Client;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\Storage;

class AutosportRss
{
    protected Client $client;
    protected string $url = 'https://www.autosport.com/rss/f1/news/';

    public function __construct(Client $client = null)
    {
        $this->client = $client ?? new Client([
            'timeout' => (int) env('AUTOSPORT_RSS_TIMEOUT', 10),
        ]);
    }

    /**
     * Fetch and parse Autosport F1 news RSS feed.
     *
     * @return array<int, array<string, mixed>>
     */
    /**
     * Fetch and cache Autosport F1 news, persisting yearly archives to disk so
     * past articles remain accessible even after they disappear from the live
     * RSS feed.
     */
    public function fetch(int $days = 30, int $limit = 20, ?int $year = null): array
    {
        $cacheKey = $year
            ? "autosport_f1_news_{$year}_{$limit}"
            : "autosport_f1_news_{$days}_{$limit}";

        return Cache::remember($cacheKey, 3600, function () use ($days, $limit, $year) {
            $response = $this->client->get($this->url);
            $xml = new \SimpleXMLElement((string) $response->getBody());

            if ($year) {
                $start = Carbon::create($year, 1, 1)->startOfDay();
                $end = Carbon::create($year, 12, 31)->endOfDay();
            } else {
                $start = Carbon::now()->subDays($days);
                $end = Carbon::now();
            }

            $items = collect(iterator_to_array($xml->channel->item ?? [], false))->map(function ($item) {
                $link = (string) $item->link;
                $image = null;
                $media = $item->children('media', true);
                if ($media && $media->content) {
                    $image = (string) $media->content->attributes()->url;
                } elseif ($item->enclosure) {
                    $image = (string) $item->enclosure['url'];
                }
                $description = trim(strip_tags((string) $item->description));
                $excerpt = Str::limit($description, 280, '');

                return [
                    'id' => md5($link),
                    'title' => (string) $item->title,
                    'link' => $link,
                    'published_at' => Carbon::parse((string) $item->pubDate)->utc()->toIso8601String(),
                    'image_url' => $image ?: null,
                    'source' => 'Autosport',
                    'excerpt' => $excerpt,
                ];
            })->filter(function ($item) use ($start, $end) {
                $published = Carbon::parse($item['published_at']);
                return $published->betweenIncluded($start, $end);
            });

            if ($year && !app()->runningUnitTests()) {
                $file = "autosport_f1_news_{$year}.json";
                $stored = [];
                if (Storage::exists($file)) {
                    $stored = json_decode(Storage::get($file), true) ?: [];
                }
                $merged = collect($stored)
                    ->keyBy('id')
                    ->merge($items->keyBy('id'))
                    ->filter(function ($item) use ($start, $end) {
                        $published = Carbon::parse($item['published_at']);
                        return $published->betweenIncluded($start, $end);
                    })
                    ->values();
                Storage::put($file, json_encode($merged->all()));
                return $merged->sortByDesc('published_at')->take($limit)->values()->all();
            }

            return $items->sortByDesc('published_at')->take($limit)->values()->all();
        });
    }
}
