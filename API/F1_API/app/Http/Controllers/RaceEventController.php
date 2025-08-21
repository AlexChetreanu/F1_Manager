<?php

namespace App\Http\Controllers;

use App\Models\RaceEvent;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class RaceEventController extends Controller
{
    /**
     * Display a listing of the events for a session.
     */
    public function index(Request $request, int $sessionKey)
    {
        $from = (int) $request->query('from_ms', 0);
        $to = (int) $request->query('to_ms', $from + 60000);
        $types = array_filter(explode(',', $request->query('types', 'overtake,race_control')));
        $limit = min((int) $request->query('limit', 500), 2000);

        if (!RaceEvent::where('session_key', $sessionKey)->exists()) {
            return response()->json(['message' => 'Session not found'], 404);
        }

        $query = RaceEvent::where('session_key', $sessionKey)
            ->whereBetween('timestamp_ms', [$from, $to])
            ->orderBy('timestamp_ms');

        if (!empty($types)) {
            $query->whereIn('event_type', $types);
        }

        return response()->json([
            'session_key' => $sessionKey,
            'from_ms' => $from,
            'to_ms' => $to,
            'events' => $query->limit($limit)->get(),
        ]);
    }
}
