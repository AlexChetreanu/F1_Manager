<?php

namespace App\Http\Controllers;

use Illuminate\Support\Facades\Cache;

class StrategyController extends Controller
{
    public function suggestions(int $sessionKey)
    {
        $data = Cache::get("strategy_suggestions_{$sessionKey}");
        if (! $data) {
            return response()->json(['error' => 'No suggestions'], 404);
        }
        return response()->json($data);
    }
}
