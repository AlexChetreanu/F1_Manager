<?php

namespace App\Http\Controllers;

use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpFoundation\StreamedResponse;

class LiveController extends Controller
{
    public function resolveSession(Request $request)
    {
        $year = (int) $request->query('year');
        $meetingKey = $request->query('meeting_key');
        $circuitKey = $request->query('circuit_key');
        $date = $request->query('date');
        $meetingName = $request->query('meeting_name');
        $sessionType = $request->query('session_type', 'Race');

        if (! $year) {
            return response()->json(['error' => 'Missing parameters'], 400);
        }

        $db = DB::connection('openf1');
        $session = null;

        if ($meetingKey) {
            $session = $db->table('sessions')
                ->select('session_key', 'meeting_key', 'session_type', 'date_start', 'date_end')
                ->join('meetings', 'sessions.meeting_key', '=', 'meetings.meeting_key')
                ->where('meetings.year', $year)
                ->where('sessions.session_type', $sessionType)
                ->where('sessions.meeting_key', (int) $meetingKey)
                ->first();
        } elseif ($circuitKey && $date) {
            try {
                $parsedDate = Carbon::parse($date);
            } catch (\Throwable $e) {
                return response()->json(['error' => 'Invalid date'], 400);
            }

            $meeting = $db->table('meetings')
                ->where('year', $year)
                ->where('circuit_key', (int) $circuitKey)
                ->whereDate('date_start', $parsedDate->toDateString())
                ->first();

            if ($meeting) {
                $session = $db->table('sessions')
                    ->select('session_key', 'meeting_key', 'session_type', 'date_start', 'date_end')
                    ->where('meeting_key', $meeting->meeting_key)
                    ->where('session_type', $sessionType)
                    ->first();
            }
        } elseif ($meetingName) {
            $meeting = $db->table('meetings')
                ->where('year', $year)
                ->whereRaw('LOWER(meeting_name) LIKE ?', ['%' . strtolower($meetingName) . '%'])
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

    public function stream(Request $request)
    {
        $sessionKey = (int) $request->query('session_key');
        if (! $sessionKey) {
            return response()->json(['error' => 'Missing session_key'], 400);
        }
        $windowMs = (int) $request->query('window_ms', 2000);
        $fieldsParam = $request->query('fields');
        $allFields = ['drivers', 'position', 'lap', 'car', 'loc', 'weather', 'rc'];
        $fields = $fieldsParam ? array_intersect($allFields, array_map('trim', explode(',', $fieldsParam))) : $allFields;

        $response = new StreamedResponse(function () use ($sessionKey, $windowMs, $fields) {
            while (connection_aborted() === 0) {
                $payload = $this->snapshotInternal($sessionKey, $windowMs, $fields, null);
                echo 'data: ' . json_encode($payload) . "\n\n";
                ob_flush();
                flush();
                sleep(1);
            }
        });

        $response->headers->set('Content-Type', 'text/event-stream');
        $response->headers->set('Cache-Control', 'no-cache');
        $response->headers->set('X-Accel-Buffering', 'no');

        return $response;
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
}

