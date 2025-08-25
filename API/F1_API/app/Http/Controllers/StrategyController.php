<?php

namespace App\Http\Controllers;

use Illuminate\Support\Facades\Cache;

class StrategyController extends Controller
{
    public function suggestions(int $meetingKey)
    {
        $data = Cache::get("strategy_suggestions_{$meetingKey}");
        if (! $data) {
            return response()->json(['error' => 'No suggestions'], 404);
        }
        return response()->json($data);
    }
}
