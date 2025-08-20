<?php

namespace App\Services;

class AutosportRss
{
    private string $url = 'https://www.autosport.com/rss/f1/news/';

    public function fetch(): array
    {
        $client = new \GuzzleHttp\Client(['timeout' => 10]);
        $xmlStr = $client->get($this->url)->getBody()->getContents();
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
            $published = \Carbon\Carbon::parse((string) $item->pubDate)->utc()->toIso8601String();
            $desc = \Illuminate\Support\Str::of((string) $item->description)->stripTags()->squish();

            $out[] = [
                'id'           => sha1($link),
                'title'        => (string) $item->title,
                'link'         => $link,
                'published_at' => $published,
                'image_url'    => $img ?: null,
                'source'       => 'Autosport',
                'excerpt'      => \Illuminate\Support\Str::limit($desc, 240),
            ];
        }
        return $out;
    }
}
