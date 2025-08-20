<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Services\AutosportRss;

class NewsController extends Controller
{
    public function f1Autosport(Request $request, AutosportRss $rss)
    {
        $days = (int) $request->query('days', 30);
        $limit = (int) $request->query('limit', 20);

        $items = $rss->fetch($days, $limit);

        return response()->json($items);
    }
}
