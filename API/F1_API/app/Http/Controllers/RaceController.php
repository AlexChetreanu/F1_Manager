<?php

namespace App\Http\Controllers;

use App\Http\Requests\RaceRequest;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Carbon\Carbon;

class RaceController extends Controller
{
    // API endpoint JSON
    public function apiIndex(Request $request)
    {
        $query = DB::table('races');

        if ($request->has('year')) {
            $query->whereYear('date', $request->query('year'));
        }

        if ($request->has('circuit_id')) {
            $query->where('circuit_id', $request->query('circuit_id'));
        }

        $races = $query->get()->map(fn($race) => $this->applyDynamicStatus($race));
        return response()->json($races);
    }

    // Pagina web cu listarea curselor
    public function index()
    {
        $races = DB::table('races')->get()->map(fn($race) => $this->applyDynamicStatus($race));
        return view('races.index', compact('races'));
    }

    public function show(RaceRequest $id)
    {
        $race = DB::table('races')->find($id);
        if (!$race) abort(404);

        $this->applyDynamicStatus($race);

        // Decodăm coordonatele circuitului, presupunem că sunt stocate JSON în coloana `coordinates`
        $coordinates = json_decode($race->coordinates);

        return view('races.show', compact('race', 'coordinates'));
    }

    private function applyDynamicStatus($race)
    {
        $now = Carbon::now();
        $raceStart = Carbon::parse($race->date);

        if (!in_array(strtolower($race->status), ['finished', 'cancelled']) &&
            $now->between($raceStart, $raceStart->copy()->addHours(4))) {
            $race->status = 'In Progress';
        }

        return $race;
    }
}

