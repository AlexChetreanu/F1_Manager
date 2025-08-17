<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration {
    public function up(): void
    {
        $statements = [
            'CREATE INDEX IF NOT EXISTS idx_position_sk_dn_date ON position(session_key, driver_number, date)',
            'CREATE INDEX IF NOT EXISTS idx_intervals_sk_dn_date ON intervals(session_key, driver_number, date)',
            'CREATE INDEX IF NOT EXISTS idx_car_data_sk_dn_date ON car_data(session_key, driver_number, date)',
            'CREATE INDEX IF NOT EXISTS idx_location_sk_dn_date ON location(session_key, driver_number, date)',
            'CREATE INDEX IF NOT EXISTS idx_laps_sk_dn_ln      ON laps(session_key, driver_number, lap_number)',
            'CREATE INDEX IF NOT EXISTS idx_weather_sk_date    ON weather(session_key, date)',
            'CREATE INDEX IF NOT EXISTS idx_rc_sk_date         ON race_control(session_key, date)',
        ];
        foreach ($statements as $sql) {
            DB::connection('openf1')->statement($sql);
        }
    }

    public function down(): void
    {
        $statements = [
            'DROP INDEX IF EXISTS idx_position_sk_dn_date',
            'DROP INDEX IF EXISTS idx_intervals_sk_dn_date',
            'DROP INDEX IF EXISTS idx_car_data_sk_dn_date',
            'DROP INDEX IF EXISTS idx_location_sk_dn_date',
            'DROP INDEX IF EXISTS idx_laps_sk_dn_ln',
            'DROP INDEX IF EXISTS idx_weather_sk_date',
            'DROP INDEX IF EXISTS idx_rc_sk_date',
        ];
        foreach ($statements as $sql) {
            DB::connection('openf1')->statement($sql);
        }
    }
};

