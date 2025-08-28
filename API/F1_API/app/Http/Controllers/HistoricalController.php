<?php

namespace App\Http\Controllers;

use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
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

        $response = Http::get($this->openF1.'/sessions', [
            'year' => $year,
            'circuit_key' => $circuitKey,
            'session_type' => $sessionType,
            'limit' => 1,
        ]);

        if ($response->failed() || empty($response->json())) {
            return response()->json(['error' => 'Session not found'], 404);
        }

        $session = $response->json()[0];
        Cache::put('strategy_active_meeting', $session['meeting_key'], 600);

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
        $session = Http::get($this->openF1.'/sessions', ['session_key' => $sessionKey])->json()[0] ?? null;
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
                'sample_rate_hz' => 10,
            ],
            'resources' => [
                'drivers' => "/historical/session/$sessionKey/drivers",
                'track' => "/historical/session/$sessionKey/track",
                'events' => "/historical/session/$sessionKey/events",
                'laps' => "/historical/session/$sessionKey/laps",
                'frames' => [
                    'by_time' => "/historical/session/$sessionKey/frames?t={iso8601}",
                    'window' => "/historical/session/$sessionKey/frames?from={iso}&to={iso}&stride_ms=100&format=ndjson",
                ],
            ],
        ]);
    }

    /**
     * Return driver metadata mapped to a compact DTO.
     */
    public function drivers(int $sessionKey)
    {
        $drivers = Http::get($this->openF1.'/drivers', ['session_key' => $sessionKey])->json();

        $mapped = collect($drivers)->map(function ($d) {
            return [
                'driver_number' => (int) $d['driver_number'],
                'full_name' => trim(($d['first_name'] ?? '').' '.($d['last_name'] ?? '')),
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
        $session = Http::get($this->openF1.'/sessions', ['session_key' => $sessionKey])->json()[0] ?? null;
        if (! $session) {
            return response()->json(['error' => 'Session not found'], 404);
        }

        $bounds = Cache::remember("track_bounds_$sessionKey", 3600, function () use ($sessionKey, $session) {
            $start = Carbon::parse($session['date_start']);
            $end = $start->copy()->addSeconds(30);
            $locations = Http::get($this->openF1.'/location', [
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

            $padX = ($maxX - $minX) * 0.05;
            $padY = ($maxY - $minY) * 0.05;
            $minX -= $padX;
            $maxX += $padX;
            $minY -= $padY;
            $maxY += $padY;

            return [
                'minX' => $minX,
                'minY' => $minY,
                'maxX' => $maxX,
                'maxY' => $maxY,
            ];
        });

        return response()->json([
            'circuit_key' => $session['circuit_key'],
            'name' => $session['circuit_short_name'] ?? $session['circuit_full_name'] ?? 'Unknown',
            'map' => [
                'image_url' => $session['circuit_map'] ?? '',
                'bounds' => $bounds ?: [
                    'minX' => -5000,
                    'minY' => -5000,
                    'maxX' => 5000,
                    'maxY' => 5000,
                ],
            ],
        ]);
    }

    /** Proxy session events. */
    public function events(int $sessionKey)
    {
        $data = Http::get($this->openF1.'/events', ['session_key' => $sessionKey])->json();

        return response()->json($data);
    }

    /** Proxy laps endpoint optionally filtered by driver number. */
    public function laps(Request $request, int $sessionKey)
    {
        $query = ['session_key' => $sessionKey];
        if ($driver = $request->query('driver_number')) {
            $query['driver_number'] = $driver;
        }
        $data = Http::get($this->openF1.'/laps', $query)->json();

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
        $gapMs = (int) $request->query('gap_ms', 1500);

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
                        $prevDrv = collect($prev['drivers'])->firstWhere(fn ($d) => $d[0] === $n);

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
                    echo json_encode($frame)."\n";
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

        $rows = Http::get($this->openF1.'/location', $params)->json();

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

        foreach ($groups as &$samples) {
            $count = count($samples);
            for ($k = 0; $k < $count; $k++) {
                $xPrev = $samples[$k - 1]['x'] ?? null;
                $xCur = $samples[$k]['x'] ?? null;
                $xNext = $samples[$k + 1]['x'] ?? null;
                $yPrev = $samples[$k - 1]['y'] ?? null;
                $yCur = $samples[$k]['y'] ?? null;
                $yNext = $samples[$k + 1]['y'] ?? null;
                if ($xPrev !== null && $xCur !== null && $xNext !== null) {
                    $samples[$k]['x'] = $this->median3($xPrev, $xCur, $xNext);
                }
                if ($yPrev !== null && $yCur !== null && $yNext !== null) {
                    $samples[$k]['y'] = $this->median3($yPrev, $yCur, $yNext);
                }
            }
        }
        unset($samples);

        return $groups;
    }

    /**
     * Interpolate all driver positions for a single timestamp.
     */
    private function interpolateFrame(Carbon $ts, array $groups, array $include, int $gapMs, array &$indices): array
    {
        $tMs = $ts->valueOf();
        $fields = ['n', 'x', 'y'];
        if (in_array('speed', $include, true)) {
            $fields[] = 'v';
        }
        if (in_array('gear', $include, true)) {
            $fields[] = 'gear';
        }

        $drivers = [];
        foreach ($groups as $n => $samples) {
            $idx = $indices[$n] ?? 0;
            while ($idx + 1 < count($samples) && $samples[$idx + 1]['t'] <= $tMs) {
                $idx++;
            }
            $indices[$n] = $idx;
            $prev = $samples[$idx] ?? null;
            $next = $samples[$idx + 1] ?? null;
            $pm1 = $samples[max(0, $idx - 1)] ?? null;
            $pp2 = $samples[min(count($samples) - 1, $idx + 2)] ?? null;

            $x = $prev['x'] ?? $next['x'] ?? null;
            $y = $prev['y'] ?? $next['y'] ?? null;
            $v = $prev['speed'] ?? $next['speed'] ?? null;
            $gear = $prev['gear'] ?? $next['gear'] ?? null;

            if ($prev && $next && $pm1 && $pp2 && ($next['t'] > $prev['t']) && (($next['t'] - $prev['t']) <= $gapMs)) {
                $u = ($tMs - $prev['t']) / max($next['t'] - $prev['t'], 1);
                [$x, $y] = $this->catmull2_centripetal(
                    [$pm1['x'], $pm1['y']], [$prev['x'], $prev['y']],
                    [$next['x'], $next['y']], [$pp2['x'], $pp2['y']], $u
                );
                if (in_array('speed', $include, true)) {
                    $v = $this->lerp($prev['speed'], $next['speed'], $u);
                }
            } elseif ($prev && $next && ($next['t'] > $prev['t']) && (($next['t'] - $prev['t']) <= $gapMs)) {
                $u = ($tMs - $prev['t']) / max($next['t'] - $prev['t'], 1);
                $x = $this->lerp($prev['x'], $next['x'], $u);
                $y = $this->lerp($prev['y'], $next['y'], $u);
                if (in_array('speed', $include, true)) {
                    $v = $this->lerp($prev['speed'], $next['speed'], $u);
                }
            } else {
                // hold/teleport: keep last or next available values
            }

            $row = [(string) $n, $x, $y];
            if (in_array('speed', $include, true)) {
                $row[] = $v;
            }
            if (in_array('gear', $include, true)) {
                $row[] = $gear;
            }
            $drivers[] = $row;
        }

        return [
            't' => $ts->toIso8601String(),
            'drivers' => $drivers,
            'fields' => $fields,
        ];
    }

    private function catmull2_centripetal(array $p0, array $p1, array $p2, array $p3, float $t): array
    {
        $alpha = 0.5; // centripetal
        $d01 = pow(hypot($p1[0] - $p0[0], $p1[1] - $p0[1]), $alpha);
        $d12 = pow(hypot($p2[0] - $p1[0], $p2[1] - $p1[1]), $alpha);
        $d23 = pow(hypot($p3[0] - $p2[0], $p3[1] - $p2[1]), $alpha);
        $t0 = 0.0;
        $t1 = $t0 + $d01 + 1e-9;
        $t2 = $t1 + $d12 + 1e-9;
        $t3 = $t2 + $d23 + 1e-9;
        $s = $t1 + ($t2 - $t1) * max(0.0, min(1.0, $t));

        $A1 = [
            ($t1 - $s) / ($t1 - $t0) * $p0[0] + ($s - $t0) / ($t1 - $t0) * $p1[0],
            ($t1 - $s) / ($t1 - $t0) * $p0[1] + ($s - $t0) / ($t1 - $t0) * $p1[1],
        ];
        $A2 = [
            ($t2 - $s) / ($t2 - $t1) * $p1[0] + ($s - $t1) / ($t2 - $t1) * $p2[0],
            ($t2 - $s) / ($t2 - $t1) * $p1[1] + ($s - $t1) / ($t2 - $t1) * $p2[1],
        ];
        $A3 = [
            ($t3 - $s) / ($t3 - $t2) * $p2[0] + ($s - $t2) / ($t3 - $t2) * $p3[0],
            ($t3 - $s) / ($t3 - $t2) * $p2[1] + ($s - $t2) / ($t3 - $t2) * $p3[1],
        ];
        $B1 = [
            ($t2 - $s) / ($t2 - $t0) * $A1[0] + ($s - $t0) / ($t2 - $t0) * $A2[0],
            ($t2 - $s) / ($t2 - $t0) * $A1[1] + ($s - $t0) / ($t2 - $t0) * $A2[1],
        ];
        $B2 = [
            ($t3 - $s) / ($t3 - $t1) * $A2[0] + ($s - $t1) / ($t3 - $t1) * $A3[0],
            ($t3 - $s) / ($t3 - $t1) * $A2[1] + ($s - $t1) / ($t3 - $t1) * $A3[1],
        ];

        return [
            ($t2 - $s) / ($t2 - $t1) * $B1[0] + ($s - $t1) / ($t2 - $t1) * $B2[0],
            ($t2 - $s) / ($t2 - $t1) * $B1[1] + ($s - $t1) / ($t2 - $t1) * $B2[1],
        ];
    }

    private function catmull2(array $p0, array $p1, array $p2, array $p3, float $t): array
    {
        $t2 = $t * $t;
        $t3 = $t2 * $t;
        $a = -0.5 * $t3 + $t2 - 0.5 * $t;
        $b = 1.5 * $t3 - 2.5 * $t2 + 1.0;
        $c = -1.5 * $t3 + 2.0 * $t2 + 0.5 * $t;
        $d = 0.5 * $t3 - 0.5 * $t2;
        $x = $a * $p0[0] + $b * $p1[0] + $c * $p2[0] + $d * $p3[0];
        $y = $a * $p0[1] + $b * $p1[1] + $c * $p2[1] + $d * $p3[1];

        return [$x, $y];
    }

    private function median3($a, $b, $c)
    {
        return $a > $b ? ($b > $c ? $b : ($a > $c ? $c : $a)) : ($a > $c ? $a : ($b > $c ? $c : $b));
    }

    private function lerp($a, $b, $u)
    {
        if ($a === null || $b === null) {
            return $a ?? $b;
        }

        return $a + ($b - $a) * $u;
    }
}
