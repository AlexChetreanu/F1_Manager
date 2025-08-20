<?php

namespace App\Http\Controllers;

use App\Services\AutosportRss;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;

class NewsController extends Controller
{
    public function f1Autosport(Request $r, AutosportRss $rss)
    {
        $days  = (int) $r->integer('days', 30);
        $limit = max(1, (int) $r->integer('limit', 20));
        $cacheKey = "autosport_f1_{$days}_{$limit}";

        return Cache::remember($cacheKey, 3600, function () use ($rss, $days, $limit) {
            $items = collect($rss->fetch());
            $raw = $items->count();
            $cutoff = now()->subDays($days);

            $items = $items->filter(fn($it) =>
                !empty($it['title']) &&
                !empty($it['link']) &&
                !empty($it['published_at']) &&
                \Carbon\Carbon::parse($it['published_at'])->gte($cutoff)
            )->sortByDesc('published_at');

            $final = $items->take($limit)->values()->all();

            \Log::info('news.f1_autosport', [
                'raw_count' => $raw,
                'filtered_count_time' => $items->count(),
                'final_count' => count($final),
                'days' => $days,
                'limit' => $limit,
            ]);

            return $final;
        });
    }

    public function debug(Request $r, AutosportRss $rss)
    {
        // TODO: remove before release
        $days  = (int) $r->integer('days', 30);
        $limit = max(1, (int) $r->integer('limit', 20));
        $items = collect($rss->fetch());
        $raw = $items->count();
        $cutoff = now()->subDays($days);

        $items = $items->filter(fn($it) =>
            !empty($it['title']) &&
            !empty($it['link']) &&
            !empty($it['published_at']) &&
            \Carbon\Carbon::parse($it['published_at'])->gte($cutoff)
        )->sortByDesc('published_at');

        $final = $items->take($limit)->values()->all();

        return [
            'raw_count' => $raw,
            'filtered_count_time' => $items->count(),
            'final_count' => count($final),
            'sample_titles' => collect($final)->pluck('title')->take(5),
        ];
    }
}
