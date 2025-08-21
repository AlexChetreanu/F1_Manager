<?php

namespace App\Http\Controllers;

use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class RaceControlController extends Controller
{
    private const MAX_LIMIT = 1000;
    private const DEFAULT_LIMIT = 50;

    public function index(Request $request)
    {
        $query = DB::connection('openf1')->table('race_control as rc')
            ->join('sessions as s', 's.session_key', '=', 'rc.session_key')
            ->select(
                'rc.id',
                'rc.meeting_key',
                'rc.session_key',
                'rc.category',
                'rc.flag',
                'rc.message',
                'rc.scope',
                'rc.sector',
                'rc.lap_number',
                'rc.driver_number',
                'rc.driver_number_overtaken',
                'rc.date'
            )
            ->selectRaw(
                "DATE_FORMAT(CONVERT_TZ(rc.`date`, '+00:00', '+00:00'), '%Y-%m-%dT%H:%i:%s.%fZ') as date_iso"
            )
            ->selectRaw(
                "TIMESTAMPDIFF(MICROSECOND, s.`date_start`, rc.`date`) / 1000 as timestamp_ms"
            );

        if ($sessionKey = $request->query('session_key')) {
            $query->where('rc.session_key', (int) $sessionKey);
        }
        if ($gt = $request->query('date__gt')) {
            try { $gt = Carbon::parse($gt); } catch (\Throwable) {}
            $query->where('rc.date', '>', $gt);
        }
        if ($lt = $request->query('date__lt')) {
            try { $lt = Carbon::parse($lt); } catch (\Throwable) {}
            $query->where('rc.date', '<', $lt);
        }

        $limit = min((int) $request->query('limit', self::DEFAULT_LIMIT), self::MAX_LIMIT);
        $offset = (int) $request->query('offset', 0);

        $rows = $query->orderBy('rc.date')
            ->limit($limit)
            ->offset($offset)
            ->get();

        return response()->json([
            'data' => $rows,
            'limit' => $limit,
            'offset' => $offset,
        ]);
    }
}
