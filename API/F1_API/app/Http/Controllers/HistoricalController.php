<?php

namespace App\Http\Controllers;

use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Cache;

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
     * Return basic track information including bounds. Bounds are fetched once
     * from a short sample of location data and cached. Falls back to a wide
     * rectangle if no data is available.
     */
    public function track(int $sessionKey)
    {
        $session = Http::get($this->openF1 . '/sessions', ['session_key' => $sessionKey])->json()[0] ?? null;
        if (! $session) {
            return response()->json(['error' => 'Session not found'], 404);
        }

        $bounds = Cache::remember("track_bounds_$sessionKey", 3600, function () use ($sessionKey, $session) {
            $start = Carbon::parse($session['date_start']);
            $end = $start->copy()->addSeconds(30);
            $locations = Http::get($this->openF1 . '/location', [
                'session_key' => $sessionKey,
                'date>=' => $start->toIso8601String(),
                'date<=' => $end->toIso8601String(),
                'limit' => 100000,
            ])->json();

            if (empty($locations)) {
                return null;
            }

            $minX = $maxX = $locations[0]['x'] ?? 0;
            $minY = $maxY = $locations[0]['y'] ?? 0;
            foreach ($locations as $loc) {
                if (isset($loc['x'])) {
                    $minX = min($minX, $loc['x']);
                    $maxX = max($maxX, $loc['x']);
                }
                if (isset($loc['y'])) {
                    $minY = min($minY, $loc['y']);
                    $maxY = max($maxY, $loc['y']);
                }
            }
            return [
                'minX' => $minX,
                'minY' => $minY,
                'maxX' => $maxX,
                'maxY' => $maxY,
            ];
        });

        if (! $bounds) {
            $bounds = [
                'minX' => -5000,
                'minY' => -5000,
                'maxX' =>  5000,
                'maxY' =>  5000,
            ];
        }

        $track = [
            'circuit_key' => $session['circuit_key'],
            'name' => $session['circuit_short_name'] ?? $session['circuit_full_name'] ?? 'Unknown',
            'map' => [
                'image_url' => $session['circuit_map'] ?? '',
                'bounds' => $bounds,
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
     * Provide frames either for a punctual timestamp or a window. Location data
     * is fetched in a single window and then linearly interpolated for each
     * driver. Supports optional NDJSON streaming and delta encoding.
     */
    public function frames(int $sessionKey, Request $request)
    {
        $t = $request->query('t');
        $from = $request->query('from');
        $to = $request->query('to');
        $strideMs = (int) $request->query('stride_ms', 200);
        $include = array_filter(explode(',', $request->query('include', '')));
        $drivers = array_filter(explode(',', $request->query('drivers', '')));
        $format = $request->query('format', 'json');
        $delta = filter_var($request->query('delta'), FILTER_VALIDATE_BOOLEAN);
        $gapMs = (int) $request->query('gap_ms', 1000);

        if ($t) {
            $ts = Carbon::parse($t);
            $windowStart = $ts->copy()->subMilliseconds(300);
            $windowEnd = $ts->copy()->addMilliseconds(300);
            $groups = $this->fetchLocationWindow($sessionKey, $windowStart, $windowEnd, $drivers, $include);
            $indices = [];
            $frame = $this->interpolateFrame($ts, $groups, $include, $gapMs, $indices);
            return response()->json([$frame]);
        }

        if (! $from || ! $to) {
            return response()->json(['error' => 'Missing time window'], 400);
        }

        $start = Carbon::parse($from);
        $end = Carbon::parse($to);
        $groups = $this->fetchLocationWindow(
            $sessionKey,
            $start->copy()->subMilliseconds(500),
            $end->copy()->addMilliseconds(500),
            $drivers,
            $include
        );

        $timestamps = [];
        for ($ts = $start->copy(); $ts->lte($end); $ts->addMilliseconds($strideMs)) {
            $timestamps[] = $ts->copy();
        }

        $indices = [];
        $build = function () use ($timestamps, $groups, $include, $delta, $gapMs, &$indices) {
            $prev = null;
            foreach ($timestamps as $ts) {
                $frame = $this->interpolateFrame($ts, $groups, $include, $gapMs, $indices);
                if ($delta && $prev) {
                    $frame['drivers'] = array_values(array_filter($frame['drivers'], function ($drv) use ($prev) {
                        $n = $drv[0];
                        $prevDrv = collect($prev['drivers'])->firstWhere(fn($d) => $d[0] === $n);
                        return $prevDrv != $drv;
                    }));
                }
                $prev = $frame;
                yield $frame;
            }
        };

        if ($format === 'ndjson') {
            $headers = ['Content-Type' => 'application/x-ndjson'];
            return response()->stream(function () use ($build) {
                foreach ($build() as $frame) {
                    echo json_encode($frame) . "\n";
                    @ob_flush();
                    @flush();
                }
            }, 200, $headers);
        }

        $frames = iterator_to_array($build());
        return response()->json($frames);
    }

    /**
     * Fetch location samples for the given window and group them by driver.
     */
    private function fetchLocationWindow(int $sessionKey, Carbon $from, Carbon $to, array $drivers, array $include): array
    {
        $params = [
            'session_key' => $sessionKey,
            'date>=' => $from->toIso8601String(),
            'date<=' => $to->toIso8601String(),
            'order_by' => 'driver_number,date',
            'limit' => 100000,
        ];
        if ($drivers) {
            $params['driver_number'] = $drivers;
        }

        $rows = Http::get($this->openF1 . '/location', $params)->json();

        $groups = [];
        foreach ($rows as $row) {
            $n = (string) $row['driver_number'];
            $groups[$n][] = [
                't' => Carbon::parse($row['date'])->valueOf(),
                'x' => $row['x'] ?? null,
                'y' => $row['y'] ?? null,
                'speed' => $row['speed'] ?? null,
                'gear' => $row['n_gear'] ?? null,
            ];
        }

        ksort($groups, SORT_NATURAL);
        return $groups;
    }

    /**
     * Interpolate all driver positions for a single timestamp.
     */
    private function interpolateFrame(Carbon $ts, array $groups, array $include, int $gapMs, array &$indices): array
    {
        $tMs = $ts->valueOf();
        $fields = ['n', 'x', 'y'];
        if (in_array('speed', $include, true)) { $fields[] = 'v'; }
        if (in_array('gear', $include, true)) { $fields[] = 'gear'; }

        $drivers = [];
        foreach ($groups as $n => $samples) {
            $idx = $indices[$n] ?? 0;
            while ($idx + 1 < count($samples) && $samples[$idx + 1]['t'] <= $tMs) {
                $idx++;
            }
            $indices[$n] = $idx;
            $prev = $samples[$idx] ?? null;
            $next = $samples[$idx + 1] ?? null;

            $x = $prev['x'] ?? $next['x'] ?? null;
            $y = $prev['y'] ?? $next['y'] ?? null;
            $v = $prev['speed'] ?? $next['speed'] ?? null;
            $gear = $prev['gear'] ?? $next['gear'] ?? null;

            if ($prev && $next && $next['t'] > $prev['t'] && ($next['t'] - $prev['t']) <= $gapMs) {
                $u = ($tMs - $prev['t']) / max($next['t'] - $prev['t'], 1);
                $x = $this->lerp($prev['x'], $next['x'], $u);
                $y = $this->lerp($prev['y'], $next['y'], $u);
                if (in_array('speed', $include, true)) {
                    $v = $this->lerp($prev['speed'], $next['speed'], $u);
                }
                if (in_array('gear', $include, true)) {
                    $gear = $next['gear'] ?? $prev['gear'];
                }
            }

            $row = [(string) $n, $x, $y];
            if (in_array('speed', $include, true)) { $row[] = $v; }
            if (in_array('gear', $include, true)) { $row[] = $gear; }
            $drivers[] = $row;
        }

        return [
            't' => $ts->toIso8601String(),
            'drivers' => $drivers,
            'fields' => $fields,
        ];
    }

    private function lerp($a, $b, $u)
    {
        if ($a === null || $b === null) {
            return $a ?? $b;
        }
        return $a + ($b - $a) * $u;
    }
}
