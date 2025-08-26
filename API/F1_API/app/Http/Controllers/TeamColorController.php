<?php

namespace App\Http\Controllers;

use Illuminate\Support\Facades\DB;

class TeamColorController extends Controller
{
    public function index()
    {
        $teams = DB::table('teams')
            ->select('id', 'name', 'primary_color as primary', 'secondary_color as secondary')
            ->get();

        return response()->json(['teams' => $teams]);
    }
}
