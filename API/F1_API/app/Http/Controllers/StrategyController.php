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

        if (! $data) {
            Log::info('strategy suggestions cache miss', ['meeting_key' => $meeting]);
            RunStrategyBot::dispatch($meeting);

            if (config('queue.default') === 'sync') {
                $data = Cache::get($key);
                if ($data) {
                    $data = $this->normalize($data);
                    return response()->json($data);
                }
            }

            return response()->json([
                'status' => 'queued',
                'message' => 'Suggestions are being prepared. Try again shortly.',
            ], 202);
        }

        Log::info('strategy suggestions cache hit', ['meeting_key' => $meeting]);
        $data = $this->normalize($data);

        return response()->json($data);
    }

    private function normalize(array $data): array
    {
        if (isset($data['suggestion']) && ! isset($data['suggestions'])) {
            $data['suggestions'] = $data['suggestion'] ? [$data['suggestion']] : [];
            unset($data['suggestion']);
        }

        $data['suggestions'] = $data['suggestions'] ?? [];

        return $data;
    }
}
