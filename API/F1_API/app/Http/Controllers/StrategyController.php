<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Symfony\Component\Process\Process;

class StrategyController extends Controller
{
    public function strategy(Request $req)
    {
        $validated = $req->validate([
            'meeting_key' => ['nullable','integer','min:1'],
            'session_key' => ['nullable','string'],
            'year'        => ['nullable','integer','between:2022,2025'],
            'minute'      => ['nullable','string'],            // ex. 2024-05-05T20:30:00Z
            'tplus'       => ['nullable','regex:/^\d{2}:\d{2}(:\d{2})?$/'],
            'lap'         => ['nullable','integer','min:1'],
            'all'         => ['nullable','boolean'],
        ]);

        // cache ușor (20s) pe query
        $cacheKey = 'strategy:' . md5(json_encode($validated));
        $data = Cache::remember($cacheKey, now()->addSeconds(20), function () use ($validated) {
            $python = env('PYTHON_BIN', 'python3');
            $script = base_path('scripts/strategy_bot_openf1.py');

            $args = [$python, $script];

            if (!empty($validated['meeting_key'])) { $args[]='--meeting-key'; $args[]=(string)$validated['meeting_key']; }
            if (!empty($validated['session_key'])) { $args[]='--session-key'; $args[]=(string)$validated['session_key']; }
            if (!empty($validated['year']))        { $args[]='--year';        $args[]=(string)$validated['year']; }
            if (!empty($validated['minute']))      { $args[]='--minute';      $args[]=(string)$validated['minute']; }
            if (!empty($validated['tplus']))       { $args[]='--tplus';       $args[]=(string)$validated['tplus']; }
            if (!empty($validated['lap']))         { $args[]='--lap';         $args[]=(string)$validated['lap']; }

            // implicit dorim toți piloții
            if (!array_key_exists('all', $validated) || $validated['all']) {
                $args[] = '--all';
            }

            $process = new Process($args, base_path('scripts'), null, null, 120);
            $process->run();

            if (!$process->isSuccessful()) {
                return [
                    'error'   => 'python_failed',
                    'details' => $process->getErrorOutput() ?: $process->getOutput(),
                    '_status' => 500,
                ];
            }

            $stdout = $process->getOutput();
            $payload = json_decode($stdout, true);

            if ($payload === null) {
                return [
                    'error' => 'invalid_json',
                    'raw'   => $stdout,
                    '_status' => 500,
                ];
            }

            // Construiește mesajele pentru UI (Section 2)
            $messages = [];
            if (isset($payload['suggestions']) && is_array($payload['suggestions'])) {
                foreach ($payload['suggestions'] as $s) {
                    $label = $s['driver_name'] ?? (isset($s['driver_number']) ? ('#'.$s['driver_number']) : '#?');
                    $advice = $s['advice'] ?? 'N/A';
                    $why = $s['why'] ?? '';
                    $messages[] = trim($label.' — '.$advice.': '.$why);
                }
            } elseif (isset($payload['suggestion']) && is_array($payload['suggestion'])) {
                $s = $payload['suggestion'];
                $label = $s['driver_name'] ?? (isset($s['driver_number']) ? ('#'.$s['driver_number']) : '#?');
                $advice = $s['advice'] ?? 'N/A';
                $why = $s['why'] ?? '';
                $messages[] = trim($label.' — '.$advice.': '.$why);
            }

            $payload['messages'] = $messages; // iOS Section 2 va consuma acest câmp
            return $payload;
        });

        if (isset($data['error']) && isset($data['_status'])) {
            $status = $data['_status'];
            unset($data['_status']);
            return response()->json($data, $status);
        }

        return response()->json($data);
    }
}
