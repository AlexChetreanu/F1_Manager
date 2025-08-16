<?php

namespace App\Http\Controllers;

use App\Jobs\FetchDriversJob;
use Illuminate\Http\Request;

class DataController extends Controller
{
    public function fetchData(Request $request)
    {
        FetchDriversJob::dispatch();

        return response()->json(['message' => 'Driver fetch job dispatched']);
    }
}
