<?php

namespace App\Services;

use Carbon\Carbon;
use GuzzleHttp\Client;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Str;

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
    public function fetch(int $days = 30, int $limit = 20): array
    {
        return Cache::remember("autosport_f1_news_{$days}_{$limit}", 3600, function () use ($days, $limit) {
            $response = $this->client->get($this->url);
            $xml = new \SimpleXMLElement((string) $response->getBody());

            $cutoff = Carbon::now()->subDays($days);

            $items = collect(iterator_to_array($xml->channel->item ?? []))->map(function ($item) {
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
            })->filter(function ($item) use ($cutoff) {
                return Carbon::parse($item['published_at'])->greaterThanOrEqualTo($cutoff);
            })->sortByDesc('published_at')->take($limit)->values()->all();

            return $items;
        });
    }
}
