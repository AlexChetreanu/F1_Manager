<?php

namespace App\Http\Controllers;

use App\Http\Requests\RaceRequest;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class RaceController extends Controller
{
    // API endpoint JSON
    public function apiIndex()
    {
        $races = DB::table('races')->get();
        return response()->json($races);
    }

    // Pagina web cu listarea curselor
    public function index()
    {
        $races = DB::table('races')->get();
        return view('races.index', compact('races'));
    }

    public function show(RaceRequest $id)
    {

        $race = DB::table('races')->find($id);
        if (!$race) abort(404);

        // Decodăm coordonatele circuitului, presupunem că sunt stocate JSON în coloana `coordinates`
        $coordinates = json_decode($race->coordinates);

        return view('races.show', compact('race', 'coordinates'));
    }
}

