<?php

namespace App\Http\Controllers;

use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;

/**
 * Endpoints used for historical session playback.
 * Provides metadata, driver info and timed frames that can be consumed by
 * clients for smooth race replays.
 */
class HistoricalController extends Controller
{
    /** Base URL for the public OpenF1 API. */
    private string $openF1 = 'https://api.openf1.org/v1';

    /**
     * Resolve a session by year and circuit.
     * Returns session_key, meeting_key and time bounds.
     */
    public function resolve(Request $request)
    {
        $year = (int) $request->query('year');
        $circuitKey = (int) $request->query('circuit_key');
        $sessionType = $request->query('session_type', 'Race');

        if (! $year || ! $circuitKey) {
            return response()->json(['error' => 'Missing parameters'], 400);
        }

        $response = Http::get($this->openF1 . '/sessions', [
            'year' => $year,
            'circuit_key' => $circuitKey,
            'session_type' => $sessionType,
            'limit' => 1,
        ]);

        if ($response->failed() || empty($response->json())) {
            return response()->json(['error' => 'Session not found'], 404);
        }

        $session = $response->json()[0];

        return response()->json([
            'session_key' => $session['session_key'],
            'meeting_key' => $session['meeting_key'],
            'date_start' => $session['date_start'],
            'date_end' => $session['date_end'],
            'circuit_key' => $session['circuit_key'],
        ]);
    }

    /**
     * Provide a manifest describing all resources for the session.
     */
    public function manifest(int $sessionKey)
    {
        $session = Http::get($this->openF1 . '/sessions', ['session_key' => $sessionKey])->json()[0] ?? null;
        if (! $session) {
            return response()->json(['error' => 'Session not found'], 404);
        }

        $start = $session['date_start'];
        $end = $session['date_end'];
        $durationMs = Carbon::parse($start)->diffInMilliseconds(Carbon::parse($end));

        return response()->json([
            'session_key' => $sessionKey,
            'time' => [
                'start' => $start,
                'end' => $end,
                'duration_ms' => $durationMs,
                'sample_rate_hz' => 5,
            ],
            'resources' => [
                'drivers' => "/historical/session/$sessionKey/drivers",
                'track'   => "/historical/session/$sessionKey/track",
                'events'  => "/historical/session/$sessionKey/events",
                'laps'    => "/historical/session/$sessionKey/laps",
                'frames'  => [
                    'by_time' => "/historical/session/$sessionKey/frames?t={iso8601}",
                    'window'  => "/historical/session/$sessionKey/frames?from={iso}&to={iso}&stride_ms=200&format=ndjson",
                ],
            ],
        ]);
    }

    /**
     * Return driver metadata mapped to a compact DTO.
     */
    public function drivers(int $sessionKey)
    {
        $drivers = Http::get($this->openF1 . '/drivers', ['session_key' => $sessionKey])->json();

        $mapped = collect($drivers)->map(function ($d) {
            return [
                'driver_number' => (string) $d['driver_number'],
                'full_name' => trim(($d['first_name'] ?? '') . ' ' . ($d['last_name'] ?? '')),
                'team_name' => $d['team_name'] ?? null,
                'team_colour' => $d['team_colour'] ?? null,
                'headshot_url' => $d['headshot_url'] ?? null,
            ];
        });

        return response()->json($mapped);
    }

    /**
     * Return basic track information including fixed bounds.
     */
    public function track(int $sessionKey)
    {
        $session = Http::get($this->openF1 . '/sessions', ['session_key' => $sessionKey])->json()[0] ?? null;
        if (! $session) {
            return response()->json(['error' => 'Session not found'], 404);
        }

        $track = [
            'circuit_key' => $session['circuit_key'],
            'name' => $session['circuit_short_name'] ?? $session['circuit_full_name'] ?? 'Unknown',
            'map' => [
                'image_url' => $session['circuit_map'] ?? '',
                'bounds' => [
                    'minX' => -5000,
                    'minY' => -5000,
                    'maxX' =>  5000,
                    'maxY' =>  5000,
                ],
            ],
        ];
        return response()->json($track);
    }

    /** Proxy session events. */
    public function events(int $sessionKey)
    {
        $data = Http::get($this->openF1 . '/events', ['session_key' => $sessionKey])->json();
        return response()->json($data);
    }

    /** Proxy laps endpoint optionally filtered by driver number. */
    public function laps(Request $request, int $sessionKey)
    {
        $query = ['session_key' => $sessionKey];
        if ($driver = $request->query('driver_number')) {
            $query['driver_number'] = $driver;
        }
        $data = Http::get($this->openF1 . '/laps', $query)->json();
        return response()->json($data);
    }

    /**
     * Provide frames either for a punctual timestamp or a window.
     * Supports optional delta encoding and NDJSON streaming.
     */
    public function frames(int $sessionKey, Request $request)
    {
        $t = $request->query('t');
        $from = $request->query('from');
        $to = $request->query('to');
        $strideMs = (int) $request->query('stride_ms', 200);
        $include = array_filter(explode(',', $request->query('include', '')));
        $format = $request->query('format', 'json');
        $delta = filter_var($request->query('delta'), FILTER_VALIDATE_BOOLEAN);

        if ($t) {
            $frame = $this->buildFrame($sessionKey, Carbon::parse($t), $include);
            return response()->json([$frame]);
        }

        if (! $from || ! $to) {
            return response()->json(['error' => 'Missing time window'], 400);
        }

        $start = Carbon::parse($from);
        $end = Carbon::parse($to);
        $frames = [];
        $prev = null;
        for ($ts = $start->copy(); $ts->lte($end); $ts->addMilliseconds($strideMs)) {
            $frame = $this->buildFrame($sessionKey, $ts, $include);
            if ($delta && $prev) {
                $frame['drivers'] = array_values(array_filter($frame['drivers'], function ($drv) use ($prev) {
                    $n = $drv[0];
                    $prevDrv = collect($prev['drivers'])->firstWhere(fn($d) => $d[0] === $n);
                    return $prevDrv !== $drv;
                }));
            }
            $frames[] = $frame;
            $prev = $frame;
        }

        if ($format === 'ndjson') {
            $headers = ['Content-Type' => 'application/x-ndjson'];
            return response()->stream(function () use ($frames) {
                foreach ($frames as $frame) {
                    echo json_encode($frame) . "\n";
                    @ob_flush();
                    @flush();
                }
            }, 200, $headers);
        }

        return response()->json($frames);
    }

    /**
     * Build a single frame for the given timestamp.
     * Performs a simple nearest lookup on the OpenF1 location endpoint.
     */
    private function buildFrame(int $sessionKey, Carbon $ts, array $include): array
    {
        $params = [
            'session_key' => $sessionKey,
            'date' => $ts->toIso8601String(),
        ];
        $locations = Http::get($this->openF1 . '/location', $params)->json();

        $drivers = [];
        foreach ($locations as $loc) {
            $entry = [
                (string) $loc['driver_number'],
                $loc['x'] ?? null,
                $loc['y'] ?? null,
            ];
            if (in_array('speed', $include, true)) {
                $entry[] = $loc['speed'] ?? null;
            }
            if (in_array('gear', $include, true)) {
                $entry[] = $loc['n_gear'] ?? null;
            }
            $drivers[] = $entry;
        }

        $fields = ['n', 'x', 'y'];
        if (in_array('speed', $include, true)) {
            $fields[] = 'v';
        }
        if (in_array('gear', $include, true)) {
            $fields[] = 'gear';
        }

        return [
            't' => $ts->toIso8601String(),
            'drivers' => $drivers,
            'fields' => $fields,
        ];
    }
}
