<?php

namespace App\Http\Controllers;

use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class LiveController extends Controller
{
    public function resolveSession(Request $request)
    {
        $year = (int) $request->query('year');
        $meetingKey = $request->query('meeting_key');
        $circuitKey = $request->query('circuit_key');
        $meetingName = $request->query('meeting_name');
        $sessionType = $request->query('session_type', 'Race');

        if (! $year && ! $meetingKey) {
            return response()->json(['error' => 'Missing year'], 400);
        }

        $db = DB::connection('openf1');
        $session = null;

        if ($meetingKey) {
            // meeting_key are prioritate; year devine opțional aici
            $session = $db->table('sessions')
                ->select('session_key', 'meeting_key', 'session_type', 'date_start', 'date_end')
                ->where('meeting_key', (int) $meetingKey)
                ->where('session_type', $sessionType)
                ->first();

        } elseif ($circuitKey) {
            // IGNORĂ 'date' dacă e trimis; caută meeting-ul pentru anul ALES + circuit
            if (! $year) {
                return response()->json(['error' => 'Missing year'], 400);
            }

            $meeting = $db->table('meetings')
                ->where('year', (int) $year)
                ->where('circuit_key', (int) $circuitKey)
                ->orderBy('date_start')
                ->first();

            if ($meeting) {
                $session = $db->table('sessions')
                    ->select('session_key', 'meeting_key', 'session_type', 'date_start', 'date_end')
                    ->where('meeting_key', $meeting->meeting_key)
                    ->where('session_type', $sessionType)
                    ->first();
            }

        } elseif ($meetingName) {
            // fallback pe nume dacă nu există circuit_key/meeting_key
            $meeting = $db->table('meetings')
                ->where('year', (int) $year)
                ->whereRaw('LOWER(meeting_name) LIKE ?', ['%' . strtolower($meetingName) . '%'])
                ->orderBy('date_start')
                ->first();

            if ($meeting) {
                $session = $db->table('sessions')
                    ->select('session_key', 'meeting_key', 'session_type', 'date_start', 'date_end')
                    ->where('meeting_key', $meeting->meeting_key)
                    ->where('session_type', $sessionType)
                    ->first();
            }
        }

        if (! $session) {
            return response()->json(['error' => 'Session not found'], 404);
        }

        return response()->json([
            'session_key' => $session->session_key,
            'meeting_key' => $session->meeting_key,
            'session_type' => $session->session_type,
            'date_start' => $session->date_start,
            'date_end' => $session->date_end,
        ]);
    }

    public function snapshot(Request $request)
    {
        $sessionKey = (int) $request->query('session_key');
        if (! $sessionKey) {
            return response()->json(['error' => 'Missing session_key'], 400);
        }

        $windowMs = (int) $request->query('window_ms', 2000);
        $fieldsParam = $request->query('fields');
        $sinceParam = $request->query('since');
        $since = $sinceParam ? Carbon::parse($sinceParam) : null;

        $allFields = ['drivers', 'position', 'lap', 'car', 'loc', 'weather', 'rc'];
        $fields = $fieldsParam ? array_intersect($allFields, array_map('trim', explode(',', $fieldsParam))) : $allFields;
        $data = $this->snapshotInternal($sessionKey, $windowMs, $fields, $since);
        if ($data === null) {
            return response()->json(['error' => 'Session not found'], 404);
        }

        return response()->json($data);
    }

    private function snapshotInternal(int $sessionKey, int $windowMs, array $fields, ?Carbon $since): ?array
    {
        $includeDrivers = in_array('drivers', $fields, true);
        $includePosition = in_array('position', $fields, true);
        $includeLap = in_array('lap', $fields, true);
        $includeCar = in_array('car', $fields, true);
        $includeLoc = in_array('loc', $fields, true);
        $includeWeather = in_array('weather', $fields, true);
        $includeRc = in_array('rc', $fields, true);

        $cutoff = Carbon::now()->subMilliseconds($windowMs);
        $cutoffStr = $cutoff->format('Y-m-d H:i:s.u');

        $session = DB::connection('openf1')->table('sessions')
            ->select('session_key', 'meeting_key', 'status')
            ->where('session_key', $sessionKey)
            ->first();
        if (! $session) {
            return null;
        }

        $drivers = collect();
        if ($includeDrivers || $includePosition || $includeLap || $includeCar || $includeLoc) {
            $drivers = DB::connection('openf1')->table('drivers')
                ->where('session_key', $sessionKey)
                ->get()
                ->keyBy('driver_number');
        }

        $pos = collect();
        $int = collect();
        if ($includePosition) {
            $pos = DB::connection('openf1')->table('position as p')
                ->join(DB::raw("(SELECT driver_number, MAX(date) md FROM position WHERE session_key = $sessionKey AND date >= '$cutoffStr' GROUP BY driver_number) m"), function ($j) {
                    $j->on('p.driver_number', '=', 'm.driver_number')->on('p.date', '=', 'm.md');
                })
                ->where('p.session_key', $sessionKey)
                ->get()
                ->keyBy('driver_number');

            $int = DB::connection('openf1')->table('intervals as i')
                ->join(DB::raw("(SELECT driver_number, MAX(date) md FROM intervals WHERE session_key = $sessionKey AND date >= '$cutoffStr' GROUP BY driver_number) m"), function ($j) {
                    $j->on('i.driver_number', '=', 'm.driver_number')->on('i.date', '=', 'm.md');
                })
                ->where('i.session_key', $sessionKey)
                ->get()
                ->keyBy('driver_number');
        }

        $laps = collect();
        if ($includeLap) {
            $laps = DB::connection('openf1')->table('laps as l')
                ->join(DB::raw("(SELECT driver_number, MAX(lap_number) ml FROM laps WHERE session_key = $sessionKey GROUP BY driver_number) mx"), function ($j) {
                    $j->on('l.driver_number', '=', 'mx.driver_number')->on('l.lap_number', '=', 'mx.ml');
                })
                ->where('l.session_key', $sessionKey)
                ->get()
                ->keyBy('driver_number');
        }

        $car = collect();
        if ($includeCar) {
            $car = DB::connection('openf1')->table('car_data as c')
                ->join(DB::raw("(SELECT driver_number, MAX(date) md FROM car_data WHERE session_key = $sessionKey AND date >= '$cutoffStr' GROUP BY driver_number) m"), function ($j) {
                    $j->on('c.driver_number', '=', 'm.driver_number')->on('c.date', '=', 'm.md');
                })
                ->where('c.session_key', $sessionKey)
                ->get()
                ->keyBy('driver_number');
        }

        $loc = collect();
        if ($includeLoc) {
            $loc = DB::connection('openf1')->table('location as t')
                ->join(DB::raw("(SELECT driver_number, MAX(date) md FROM location WHERE session_key = $sessionKey AND date >= '$cutoffStr' GROUP BY driver_number) m"), function ($j) {
                    $j->on('t.driver_number', '=', 'm.driver_number')->on('t.date', '=', 'm.md');
                })
                ->where('t.session_key', $sessionKey)
                ->get()
                ->keyBy('driver_number');
        }

        $weather = null;
        if ($includeWeather) {
            $wQuery = DB::connection('openf1')->table('weather')
                ->where('session_key', $sessionKey);
            if ($since) {
                $wQuery->where('date', '>', $since);
            }
            $weather = $wQuery->orderByDesc('date')->limit(1)->first();
        }

        $rc = collect();
        if ($includeRc) {
            $rcQuery = DB::connection('openf1')->table('race_control')
                ->where('session_key', $sessionKey);
            if ($since) {
                $rcQuery->where('date', '>', $since);
            }
            $rc = $rcQuery->orderByDesc('date')->limit(5)->get();
        }

        $out = [
            'session' => [
                'session_key' => $session->session_key,
                'meeting_key' => $session->meeting_key,
                'status' => $session->status,
                'server_time' => Carbon::now()->toIso8601String(),
            ],
        ];

        if ($drivers->isNotEmpty()) {
            $out['drivers'] = [];
            foreach ($drivers as $dn => $d) {
                $driverOut = [];
                if ($includeDrivers) {
                    $driverOut['identity'] = [
                        'full_name' => $d->full_name,
                        'team_name' => $d->team_name,
                        'team_colour' => $d->team_colour,
                    ];
                }
                if ($includePosition) {
                    $p = $pos->get($dn);
                    $i = $int->get($dn);
                    $driverOut['position'] = $p || $i ? [
                        'position' => $p->position ?? null,
                        'gap_to_leader' => $i->gap_to_leader ?? null,
                        'interval' => $i->interval ?? null,
                        'date' => $p->date ?? $i->date ?? null,
                    ] : null;
                }
                if ($includeLap) {
                    $l = $laps->get($dn);
                    $driverOut['lap'] = $l ? [
                        'lap_number' => $l->lap_number,
                        'lap_duration' => $l->lap_duration,
                        'date_start' => $l->date_start,
                    ] : null;
                }
                if ($includeCar) {
                    $c = $car->get($dn);
                    $driverOut['car'] = $c ? [
                        'speed' => $c->speed,
                        'rpm' => $c->rpm,
                        'throttle' => $c->throttle,
                        'brake' => $c->brake,
                        'n_gear' => $c->n_gear,
                        'drs' => $c->drs,
                        'date' => $c->date,
                    ] : null;
                }
                if ($includeLoc) {
                    $t = $loc->get($dn);
                    $driverOut['loc'] = $t ? [
                        'x' => $t->x,
                        'y' => $t->y,
                        'z' => $t->z,
                        'date' => $t->date,
                    ] : null;
                }
                $out['drivers'][(string) $dn] = $driverOut;
            }
        }

        if ($includeWeather) {
            $out['weather'] = $weather;
        }
        if ($includeRc) {
            $out['rc'] = $rc;
        }

        $out['since'] = Carbon::now()->toIso8601String();

        return $out;
    }

    private function buildDriverState(int $sessionKey, ?string $sinceIso, array $fields, bool $onlyChanged): array
    {
        $includeLoc = in_array('loc', $fields, true);
        $includePos = in_array('pos', $fields, true);
        $includeSpeed = in_array('speed', $fields, true);
        $includeEngine = in_array('engine', $fields, true);

        $db = DB::connection('openf1');

        $drivers = $db->table('drivers')
            ->where('session_key', $sessionKey)
            ->select('driver_number', 'full_name', 'name_acronym', 'team_name', 'team_colour')
            ->get()
            ->keyBy('driver_number');

        $sinceFilter = ($onlyChanged && $sinceIso) ? $sinceIso : null;

        $latestLoc = collect();
        if ($includeLoc) {
            $baseLoc = $db->table('location')->where('session_key', $sessionKey);
            if ($sinceFilter) {
                $baseLoc->where('date', '>', $sinceFilter);
            }
            $latestLocSub = $baseLoc
                ->select('driver_number', DB::raw('MAX(date) as max_date'))
                ->groupBy('driver_number');
            $latestLoc = $db->table('location as l')
                ->joinSub($latestLocSub, 't', function ($j) {
                    $j->on('l.driver_number', '=', 't.driver_number')
                      ->on('l.date', '=', 't.max_date');
                })
                ->where('l.session_key', $sessionKey)
                ->select('l.driver_number', 'l.date', 'l.x', 'l.y', 'l.z')
                ->get()
                ->keyBy('driver_number');
        }

        $latestPos = collect();
        if ($includePos) {
            $basePos = $db->table('position')->where('session_key', $sessionKey);
            if ($sinceFilter) {
                $basePos->where('date', '>', $sinceFilter);
            }
            $latestPosSub = $basePos
                ->select('driver_number', DB::raw('MAX(date) as max_date'))
                ->groupBy('driver_number');
            $latestPos = $db->table('position as p')
                ->joinSub($latestPosSub, 't', function ($j) {
                    $j->on('p.driver_number', '=', 't.driver_number')
                      ->on('p.date', '=', 't.max_date');
                })
                ->where('p.session_key', $sessionKey)
                ->select('p.driver_number', 'p.date', 'p.position')
                ->get()
                ->keyBy('driver_number');
        }

        $latestCar = collect();
        if ($includeSpeed || $includeEngine) {
            $baseCar = $db->table('car_data')->where('session_key', $sessionKey);
            if ($sinceFilter) {
                $baseCar->where('date', '>', $sinceFilter);
            }
            $latestCarSub = $baseCar
                ->select('driver_number', DB::raw('MAX(date) as max_date'))
                ->groupBy('driver_number');
            $columns = ['c.driver_number', 'c.date'];
            if ($includeSpeed) {
                $columns[] = 'c.speed';
            }
            if ($includeEngine) {
                $columns = array_merge($columns, ['c.rpm', 'c.throttle', 'c.brake', 'c.n_gear', 'c.drs']);
            }
            $latestCar = $db->table('car_data as c')
                ->joinSub($latestCarSub, 't', function ($j) {
                    $j->on('c.driver_number', '=', 't.driver_number')
                      ->on('c.date', '=', 't.max_date');
                })
                ->where('c.session_key', $sessionKey)
                ->select($columns)
                ->get()
                ->keyBy('driver_number');
        }

        $sinceCarbon = $sinceIso ? Carbon::parse($sinceIso) : null;

        $outDrivers = [];
        foreach ($drivers as $dn => $meta) {
            $state = [
                'driver_number' => $dn,
                'name' => $meta->full_name ?? $meta->name ?? null,
                'acronym' => $meta->name_acronym ?? null,
                'team_name' => $meta->team_name ?? null,
                'team_colour' => $meta->team_colour ?? null,
            ];

            $lastDates = collect();

            if ($includePos && ($p = $latestPos->get($dn))) {
                $state['pos'] = $p->position;
                $lastDates->push(Carbon::parse($p->date));
            }

            if ($includeLoc && ($l = $latestLoc->get($dn))) {
                $state['x'] = $l->x;
                $state['y'] = $l->y;
                $state['z'] = $l->z;
                $lastDates->push(Carbon::parse($l->date));
            }

            if (($includeSpeed || $includeEngine) && ($c = $latestCar->get($dn))) {
                if ($includeSpeed) {
                    $state['speed'] = $c->speed;
                }
                if ($includeEngine) {
                    $state['rpm'] = $c->rpm;
                    $state['throttle'] = $c->throttle;
                    $state['brake'] = $c->brake;
                    $state['n_gear'] = $c->n_gear;
                    $state['drs'] = $c->drs;
                }
                $lastDates->push(Carbon::parse($c->date));
            }

            $last = $lastDates->max();
            if ($onlyChanged && $sinceCarbon && $last && $last->lte($sinceCarbon)) {
                continue;
            }

            $state['last'] = $last ? $last->toIso8601String() : null;
            $outDrivers[] = $state;
        }

        return [
            'ts' => Carbon::now()->toIso8601String(),
            'session_key' => $sessionKey,
            'drivers' => $outDrivers,
        ];
    }

    public function snapshotAll(Request $request)
    {
        $sessionKey = (int) $request->query('session_key');
        if (! $sessionKey) {
            return response()->json(['error' => 'Missing session_key'], 400);
        }

        $since = $request->query('since');
        $fieldsCsv = $request->query('fields', 'loc,pos,speed');
        $fields = array_filter(array_map('trim', explode(',', $fieldsCsv)));

        try {
            $payload = $this->buildDriverState($sessionKey, $since, $fields, false);
        } catch (\Throwable $e) {
            \Log::error($e);
            return response()->json(['error' => 'Server error'], 500);
        }

        return response()->json($payload);
    }

    public function stream(Request $request)
    {
        @ini_set('zlib.output_compression', '0');
        @ini_set('implicit_flush', '1');
        while (ob_get_level() > 0) { @ob_end_flush(); }
        @set_time_limit(0);

        $sessionKey = (int) $request->query('session_key');
        if (! $sessionKey) {
            $year = (int) $request->query('year');
            $circuitKey = (int) $request->query('circuit_key');
            if ($year && $circuitKey) {
                $meeting = DB::connection('openf1')->table('meetings')
                    ->where('year', $year)
                    ->where('circuit_key', $circuitKey)
                    ->orderBy('date_start')
                    ->first();
                if ($meeting) {
                    $session = DB::connection('openf1')->table('sessions')
                        ->where('meeting_key', $meeting->meeting_key)
                        ->where('session_type', 'Race')
                        ->orderBy('date_start')
                        ->first();
                    $sessionKey = $session->session_key ?? 0;
                }
            }
            if (! $sessionKey) {
                return response('Missing session_key', 400);
            }
        }

        $tickMs = max(200, (int) $request->query('tick_ms', 200));
        $durationSec = min(300, max(5, (int) $request->query('duration_sec', 30)));
        $mode = strtolower($request->query('mode', 'full'));
        $onlyChanged = $mode !== 'full';
        $fieldsCsv = $request->query('fields', 'loc,pos,speed');
        $fields = array_filter(array_map('trim', explode(',', $fieldsCsv)));
        $since = $request->query('since');

        $headers = [
            'Content-Type' => 'text/event-stream',
            'Cache-Control' => 'no-cache',
            'Connection' => 'keep-alive',
            'X-Accel-Buffering' => 'no',
        ];

        $start = microtime(true);
        $callback = function () use ($sessionKey, $fields, $onlyChanged, $tickMs, $durationSec, $start, &$since) {
            while (microtime(true) - $start < $durationSec) {
                try {
                    $payload = $this->buildDriverState($sessionKey, $since, $fields, $onlyChanged);
                } catch (\Throwable $e) {
                    \Log::error($e);
                    $payload = ['ts' => Carbon::now()->toIso8601String(), 'session_key' => $sessionKey, 'drivers' => []];
                }

                echo "event: tick\n";
                echo 'data: ' . json_encode($payload) . "\n\n";
                @ob_flush();
                @flush();

                $since = $payload['ts'];
                usleep($tickMs * 1000);
            }
        };

        return response()->stream($callback, 200, $headers);
    }
}

