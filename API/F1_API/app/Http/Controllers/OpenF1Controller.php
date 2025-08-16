<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

class OpenF1Controller extends Controller
{
    public function query(Request $request, string $table)
    {
        if (! Schema::connection('openf1')->hasTable($table)) {
            return response()->json(['error' => 'Table not found'], 404);
        }

        $columnsParam = $request->query('columns');
        $columns = ['*'];
        if ($columnsParam) {
            $columns = array_map('trim', explode(',', $columnsParam));
            $invalid = array_filter($columns, function ($column) use ($table) {
                return ! Schema::connection('openf1')->hasColumn($table, $column);
            });

            if ($invalid) {
                return response()->json([
                    'error' => 'Column not found',
                    'columns' => array_values($invalid),
                ], 400);
            }
        }

        $data = DB::connection('openf1')->table($table)->select($columns)->get();

        return response()->json($data);
    }
}

