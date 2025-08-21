<?php

namespace App\Http\Controllers;

use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class OvertakesController extends Controller
{
    private const MAX_LIMIT = 1000;
    private const DEFAULT_LIMIT = 50;

    public function index(Request $request)
    {
        $query = DB::connection('openf1')->table('overtakes as o')
            ->join('sessions as s', 's.session_key', '=', 'o.session_key')
            ->select(
                'o.id',
                'o.meeting_key',
                'o.session_key',
                'o.driver_number',
                'o.driver_number_overtaken',
                'o.lap_number',
                'o.date as date'
            )
            ->selectRaw(
                "DATE_FORMAT(CONVERT_TZ(o.`date`, '+00:00', '+00:00'), '%Y-%m-%dT%H:%i:%s.%fZ') as date_iso"
            )
            ->selectRaw(
                "GREATEST(0, TIMESTAMPDIFF(MICROSECOND, s.`date_start`, o.`date`) / 1000) as timestamp_ms"
            );

        if ($sessionKey = $request->query('session_key')) {
            $query->where('o.session_key', (int) $sessionKey);
        }
        if ($gt = $request->query('date__gt')) {
            try { $gt = Carbon::parse($gt); } catch (\Throwable) {}
            $query->where('o.date', '>', $gt);
        }
        if ($lt = $request->query('date__lt')) {
            try { $lt = Carbon::parse($lt); } catch (\Throwable) {}
            $query->where('o.date', '<', $lt);
        }

        $limit = min((int) $request->query('limit', self::DEFAULT_LIMIT), self::MAX_LIMIT);
        $offset = (int) $request->query('offset', 0);

        $rows = $query->orderBy('o.date', 'asc')
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
