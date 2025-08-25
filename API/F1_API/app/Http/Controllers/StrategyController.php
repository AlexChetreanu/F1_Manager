<?php

namespace App\Http\Controllers;

use App\Jobs\RunStrategyBot;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;

class StrategyController extends Controller
{
    public function suggestions(int $meetingKey)
    {
        $key = "strategy_suggestions_{$meetingKey}";
        $data = Cache::get($key);
        if ($data) {
            Log::info('strategy suggestions cache hit', ['meeting_key' => $meetingKey]);
            return response()->json($data);
        }

        Log::info('strategy suggestions cache miss', ['meeting_key' => $meetingKey]);
        if (Cache::add("strategy_running_{$meetingKey}", true, 60)) {
            RunStrategyBot::dispatch($meetingKey);
            Log::info('strategy bot dispatched from controller', ['meeting_key' => $meetingKey]);
        }

        return response()->json([
            'status' => 'queued',
            'message' => 'Suggestions are being prepared. Try again shortly.',
        ], 202);
    }
}
