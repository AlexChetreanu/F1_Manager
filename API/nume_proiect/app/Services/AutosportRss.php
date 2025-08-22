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
        $this->client = $client ?: new Client([
            'timeout' => (int) env('AUTOSPORT_RSS_TIMEOUT', 10),
        ]);
    }

    /**
     * @param int $days  Ferestră relativă (dacă $year e null)
     * @param int $limit Numărul maxim de item-uri returnate
     * @param int|null $year  Dacă setat, filtrează tot anul calendaristic
     */
    public function fetch(int $days = 30, int $limit = 20, ?int $year = null): array
    {
        // Window de timp în UTC
        $now   = Carbon::now('UTC');
        $start = $year ? Carbon::create($year, 1, 1, 0, 0, 0, 'UTC') : $now->copy()->subDays($days);
        $end   = $year ? Carbon::create($year, 12, 31, 23, 59, 59, 'UTC') : $now;

        // Cheie de cache trebuie să includă toți parametrii care afectează rezultatul
        $key = $year
            ? "autosport_f1_news_year_{$year}_limit_{$limit}"
            : "autosport_f1_news_days_{$days}_limit_{$limit}";

        return Cache::remember($key, 3600, function () use ($start, $end, $limit) {
            $response = $this->client->get($this->url);
            $xmlStr   = (string) $response->getBody();

            $xml = @simplexml_load_string($xmlStr);
            if (!$xml || !isset($xml->channel->item)) {
                Log::warning('autosport.fetch xml_invalid'); // TODO: remove verbose logs before release
                return [];
            }

            $itemsXml = $xml->channel->item;
            Log::info('autosport.fetch.before', ['raw' => count($itemsXml)]); // TODO: remove verbose logs before release

            $items = collect($itemsXml)->map(function ($item) {
                // Extract media image
                $image = null;
                $media = $item->children('media', true);
                if ($media && isset($media->content) && $media->content->attributes()->url) {
                    $image = (string) $media->content->attributes()->url;
                } elseif (isset($item->enclosure) && $item->enclosure['url']) {
                    $image = (string) $item->enclosure['url'];
                }

                $link = (string) $item->link;
                $desc = Str::of((string) $item->description)->stripTags()->squish();
                $excerpt = Str::limit($desc, 240);

                return [
                    'id'           => md5($link),
                    'title'        => (string) $item->title,
                    'link'         => $link,
                    'published_at' => Carbon::parse((string) $item->pubDate)->utc()->toIso8601String(),
                    'image_url'    => $image ?: null, // imagini opționale
                    'source'       => 'Autosport',
                    'excerpt'      => $excerpt,
                ];
            })->filter(function ($it) use ($start, $end) {
                $pub = Carbon::parse($it['published_at']);
                return $pub->betweenIncluded($start, $end);
            })->sortByDesc('published_at')
              ->take($limit) // limita finală
              ->values()
              ->all();

            Log::info('autosport.fetch.after', ['final_count' => count($items)]); // TODO: remove verbose logs before release
            return $items;
        });
    }
}
