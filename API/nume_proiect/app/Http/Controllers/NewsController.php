<?php

namespace App\Http\Controllers;

use App\Services\AutosportRss;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

class NewsController extends Controller
{
    public function f1Autosport(Request $request, AutosportRss $rss)
    {
        $days  = (int) $request->query('days', 30);
        $limit = (int) $request->query('limit', 20);
        $year  = $request->query('year');

        // Clamping defensiv
        $days  = $days > 0 ? min($days, 365) : 30;
        $limit = $limit > 0 ? min($limit, 50) : 20;
        $year  = $year !== null ? (int) $year : null;

        Log::info('news.f1 params', ['days' => $days, 'limit' => $limit, 'year' => $year]); // TODO: remove verbose logs before release

        $items = $rss->fetch($days, $limit, $year);

        Log::info('news.f1 final_count', ['count' => count($items)]); // TODO: remove verbose logs before release

        return response()->json($items, 200, [], JSON_UNESCAPED_UNICODE);
    }

}
