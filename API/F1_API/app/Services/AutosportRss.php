<?php

namespace App\Services;

use Carbon\Carbon;
use GuzzleHttp\Client;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;
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
    public function fetch(int $days = 30, int $limit = 20, ?int $year = null, bool $nocache = false): array
    {
        // Fereastră de timp în UTC (robustă la TZ)
        $now   = Carbon::now('UTC');
        $start = $year ? Carbon::create($year, 1, 1, 0, 0, 0, 'UTC') : $now->copy()->subDays($days);
        $end   = $year ? Carbon::create($year,12,31,23,59,59,'UTC')   : $now;

        // Cheie de cache care include toți parametrii
        $cacheKey = $year
            ? "autosport_f1:year={$year}:limit={$limit}"
            : "autosport_f1:days={$days}:limit={$limit}";

        $fetchFn = function () use ($start, $end, $limit) {
            // User-Agent explicit — unele servere tratează diferit clienții fără UA
            $response = $this->client->get($this->url, [
                'headers' => ['User-Agent' => 'F1App/1.0 (+dev)']
            ]);
            $xmlStr = (string) $response->getBody();
            $xml = @simplexml_load_string($xmlStr);

            if (!$xml || !isset($xml->channel->item)) {
                Log::warning('autosport.fetch xml_invalid');
                return [];
            }

            // ✅ Normalizează lista de <item> (evită iterator_to_array capricios)
            $list = [];
            foreach ($xml->channel->item as $it) { $list[] = $it; }
            Log::info('autosport.fetch.before', ['raw' => count($list)]);

            $items = collect($list)->map(function ($item) {
                // Imagine din <media:content> sau <enclosure>, opțională
                $image = null;
                $media = $item->children('media', true);
                if ($media && $media->content && $media->content->attributes()->url) {
                    $image = (string) $media->content->attributes()->url;
                } elseif (isset($item->enclosure) && $item->enclosure['url']) {
                    $image = (string) $item->enclosure['url'];
                }

                $link = (string) $item->link;
                $desc = Str::of((string)$item->description)->stripTags()->squish();

                return [
                    'id'           => md5($link),
                    'title'        => (string) $item->title,
                    'link'         => $link,
                    'published_at' => Carbon::parse((string)$item->pubDate)->utc()->toIso8601String(),
                    'image_url'    => $image ?: null,
                    'source'       => 'Autosport',
                    'excerpt'      => Str::limit($desc, 240),
                ];
            })->filter(function ($it) use ($start, $end) {
                $pub = Carbon::parse($it['published_at']);
                return $pub->betweenIncluded($start, $end);
            })->sortByDesc('published_at')
              ->take($limit)
              ->values()
              ->all();

            Log::info('autosport.fetch.after', ['final_count' => count($items)]);
            return $items;
        };

        // Bypass cache pentru depanare: ?nocache=1
        if ($nocache) {
            return $fetchFn();
        }
        return Cache::remember($cacheKey, 3600, $fetchFn);
    }
}
