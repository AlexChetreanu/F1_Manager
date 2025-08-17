<?php

namespace App\Http\Controllers;

use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

class OpenF1Controller extends Controller
{
    private const ALLOWED_RESOURCES = [
        'sessions', 'meetings', 'drivers', 'car_data', 'intervals', 'laps',
        'location', 'overtakes', 'pit', 'position', 'race_control',
        'session_result', 'starting_grid', 'stints', 'team_radio', 'weather',
    ];

    private const OPERATORS = ['__gte', '__lte', '__gt', '__lt', '__ne', '__in'];
    private const MAX_LIMIT = 1000;
    private const DEFAULT_LIMIT = 200;

    public function query(Request $request, string $table)
    {
        if (! in_array($table, self::ALLOWED_RESOURCES, true)) {
            return response()->json(['error' => 'Resource not allowed'], 404);
        }

        if (! Schema::connection('openf1')->hasTable($table)) {
            return response()->json(['error' => 'Table not found'], 404);
        }

        $schema = Schema::connection('openf1.db');
        $columnsListing = $schema->getColumnListing($table);

        // Columns selection
        $columnsParam = $request->query('columns');
        $columns = ['*'];
        if ($columnsParam) {
            $columns = array_filter(array_map('trim', explode(',', $columnsParam)));
            $invalid = array_diff($columns, $columnsListing);
            if ($invalid) {
                return response()->json([
                    'error' => 'Column not found',
                    'columns' => array_values($invalid),
                ], 400);
            }
        }

        $query = DB::connection('openf1')->table($table);

        // Filters
        $reserved = ['limit', 'offset', 'order_by', 'format', 'columns', 'include_total'];
        foreach ($request->query() as $key => $value) {
            if (in_array($key, $reserved, true)) {
                continue;
            }
            $op = null;
            $base = $key;
            foreach (self::OPERATORS as $suffix) {
                if (str_ends_with($key, $suffix)) {
                    $op = $suffix;
                    $base = substr($key, 0, -strlen($suffix));
                    break;
                }
            }
            if (! in_array($base, $columnsListing, true)) {
                continue;
            }
            $type = $schema->getColumnType($table, $base);
            if ($op === '__in') {
                $vals = array_filter(array_map(function ($v) use ($type) {
                    return $this->parseValue($type, $v);
                }, explode(',', $value)));
                $query->whereIn($base, $vals);
            } else {
                $parsed = $this->parseValue($type, $value);
                match ($op) {
                    '__gte' => $query->where($base, '>=', $parsed),
                    '__lte' => $query->where($base, '<=', $parsed),
                    '__gt'  => $query->where($base, '>', $parsed),
                    '__lt'  => $query->where($base, '<', $parsed),
                    '__ne'  => $query->where($base, '!=', $parsed),
                    default => $query->where($base, '=', $parsed),
                };
            }
        }

        $countQuery = clone $query;

        // Ordering
        $orderBy = $request->query('order_by');
        if ($orderBy) {
            foreach (explode(',', $orderBy) as $part) {
                $part = trim($part);
                if ($part === '') {
                    continue;
                }
                $desc = str_starts_with($part, '-');
                $col = $desc ? substr($part, 1) : $part;
                if (in_array($col, $columnsListing, true)) {
                    $query->orderBy($col, $desc ? 'desc' : 'asc');
                }
            }
        }

        $limit = min((int) $request->query('limit', self::DEFAULT_LIMIT), self::MAX_LIMIT);
        $offset = (int) $request->query('offset', 0);
        $query->select($columns)->limit($limit)->offset($offset);

        $rows = $query->get();
        $format = strtolower($request->query('format', 'json'));
        $includeTotal = filter_var($request->query('include_total', 'false'), FILTER_VALIDATE_BOOLEAN);

        if ($format === 'csv') {
            $filename = $table . '.csv';
            return response()->streamDownload(function () use ($rows) {
                $handle = fopen('php://output', 'w');
                if ($rows->isNotEmpty()) {
                    fputcsv($handle, array_keys((array) $rows->first()));
                    foreach ($rows as $row) {
                        $data = array_map(function ($v) {
                            return $v instanceof Carbon ? $v->toIso8601String() : $v;
                        }, (array) $row);
                        fputcsv($handle, $data);
                    }
                }
                fclose($handle);
            }, $filename, ['Content-Type' => 'text/csv']);
        }

        $payload = [
            'data' => $rows,
            'limit' => $limit,
            'offset' => $offset,
        ];
        if ($includeTotal) {
            $payload['total'] = $countQuery->count();
        }

        return response()->json($payload);
    }

    private function parseValue(string $type, string $value)
    {
        $v = trim($value);
        return match ($type) {
            'integer', 'bigint', 'smallint', 'mediumint', 'tinyint' => (int) $v,
            'float', 'double', 'real', 'decimal' => (float) $v,
            'boolean', 'bool' => filter_var($v, FILTER_VALIDATE_BOOL, FILTER_NULL_ON_FAILURE),
            'date', 'datetime', 'datetimetz', 'time', 'timestamp' => Carbon::parse($v),
            default => $v,
        };
    }

    public function sessionDrivers(Request $request, int $sessionKey)
    {
        $request->merge(['session_key' => $sessionKey]);
        return $this->query($request, 'drivers');
    }

    public function sessionLaps(Request $request, int $sessionKey)
    {
        $request->merge(['session_key' => $sessionKey]);
        return $this->query($request, 'laps');
    }

    public function sessionCarData(Request $request, int $sessionKey)
    {
        $request->merge(['session_key' => $sessionKey]);
        return $this->query($request, 'car_data');
    }

    public function meetingGrid(Request $request, int $meetingKey)
    {
        $request->merge(['meeting_key' => $meetingKey]);
        return $this->query($request, 'starting_grid');
    }
}
