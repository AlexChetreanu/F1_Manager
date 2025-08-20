<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Services\AutosportRss;
use Illuminate\Support\Facades\Log;

class NewsController extends Controller
{
    public function f1Autosport(Request $request, AutosportRss $rss)
    {
        $days    = max(1, min((int)$request->query('days', 30), 365));
        $limit   = max(1, min((int)$request->query('limit', 20), 50));
        $year    = $request->query('year');
        $nocache = $request->boolean('nocache', false);

        $yearInt = $year !== null ? (int)$year : null;
        Log::info('news.f1 params', ['days'=>$days,'limit'=>$limit,'year'=>$yearInt,'nocache'=>$nocache]);

        $items = $rss->fetch($days, $limit, $yearInt, $nocache);

        $etag = '"' . md5(json_encode($items)) . '"';
        $ifNoneMatch = $request->headers->get('If-None-Match');
        $maxAge = 300; // 5 min

        if ($ifNoneMatch === $etag && !$nocache) {
            Log::info('news.f1 not_modified');
            return response('', 304)
                ->header('ETag', $etag)
                ->header('Cache-Control', "public, max-age={$maxAge}")
                ->header('Vary', 'Accept');
        }

        Log::info('news.f1 final_count', ['count'=>count($items)]);
        return response()->json($items, 200, [], JSON_UNESCAPED_UNICODE)
            ->header('ETag', $etag)
            ->header('Cache-Control', "public, max-age={$maxAge}")
            ->header('Vary', 'Accept');
    }
}
