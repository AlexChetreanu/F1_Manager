<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class HealthController extends Controller
{
    public function index(Request $r)
    {
        $okDb = false; $err = null;
        try {
            DB::connection('openf1')->select('SELECT 1');
            $okDb = true;
        } catch (\Throwable $e) {
            $err = $e->getMessage();
        }

        $sessionKey = $r->query('session_key');
        $counts = null;
        if ($okDb && $sessionKey) {
            $c = fn($t) => DB::connection('openf1')->table($t)->where('session_key', (int)$sessionKey)->count();
            $counts = [
                'drivers'   => $c('drivers'),
                'position'  => $c('position'),
                'intervals' => $c('intervals'),
                'car_data'  => $c('car_data'),
                'location'  => $c('location'),
                'weather'   => $c('weather'),
                'race_ctrl' => $c('race_control'),
                'laps'      => $c('laps'),
            ];
        }
        return response()->json([
            'status'   => 'ok',
            'php'      => PHP_VERSION,
            'db_openf1'=> $okDb ? 'ok' : 'fail',
            'error'    => $err,
            'counts'   => $counts,
        ]);
    }
}
