<?php
namespace App\Http\Controllers;

use App\Models\Driver;

class StandingsController extends Controller
{
    public function index()
    {
        $standings = Driver::orderByDesc('points')->get();

        return view('standings', compact('standings'));
    }
}
