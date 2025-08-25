<?php

namespace App\Http\Controllers;

use App\Jobs\RunStrategyBot;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;

class StrategyController extends Controller
{
    public function show(int $meeting)
    {
        $key = "strategy_suggestions_{$meeting}";
        $data = Cache::get($key);
        if ($data) {
            if (isset($data['suggestion']) && ! isset($data['suggestions'])) {
                $data['suggestions'] = $data['suggestion'] ? [$data['suggestion']] : [];
            }
            Log::info('strategy suggestions cache hit', ['meeting_key' => $meeting]);
            return response()->json($data);
        }

        Log::info('strategy suggestions cache miss', ['meeting_key' => $meeting]);
        $lock = Cache::lock("strategy_running_{$meeting}", 30);
        if ($lock->get()) {
            RunStrategyBot::dispatch($meeting);
            Log::info('strategy bot dispatched from controller', ['meeting_key' => $meeting]);
        }

        return response()->json([
            'status' => 'queued',
            'message' => 'Suggestions are being prepared. Try again shortly.',
        ], 202);
    }
}
