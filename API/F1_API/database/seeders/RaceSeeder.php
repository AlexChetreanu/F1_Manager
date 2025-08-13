<?php
namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class RaceSeeder extends Seeder
{
    public function run(): void
    {
        $races = [
            [
                'name' => 'Bahrain Grand Prix',
                'location' => 'Sakhir',
                'date' => '2025-03-14 15:00:00',
                'status' => 'upcoming',
            ],
            [
                'name' => 'Saudi Arabian Grand Prix',
                'location' => 'Jeddah',
                'date' => '2025-03-23 20:00:00',
                'status' => 'upcoming',
            ],
            [
                'name' => 'Australian Grand Prix',
                'location' => 'Melbourne',
                'date' => '2025-03-30 05:00:00',
                'status' => 'upcoming',
            ],
            [
                'name' => 'Japanese Grand Prix',
                'location' => 'Suzuka',
                'date' => '2025-04-13 07:00:00',
                'status' => 'upcoming',
            ],
            [
                'name' => 'Chinese Grand Prix',
                'location' => 'Shanghai',
                'date' => '2025-04-20 08:00:00',
                'status' => 'upcoming',
            ],
            [
                'name' => 'Miami Grand Prix',
                'location' => 'Miami',
                'date' => '2025-05-04 20:00:00',
                'status' => 'upcoming',
            ],
            [
                'name' => 'Emilia Romagna Grand Prix',
                'location' => 'Imola',
                'date' => '2025-05-18 15:00:00',
                'status' => 'upcoming',
            ],
            [
                'name' => 'Monaco Grand Prix',
                'location' => 'Monte Carlo',
                'date' => '2025-05-25 15:00:00',
                'status' => 'upcoming',
            ],
            [
                'name' => 'Canadian Grand Prix',
                'location' => 'Montreal',
                'date' => '2025-06-08 19:00:00',
                'status' => 'upcoming',
            ],
            [
                'name' => 'Spanish Grand Prix',
                'location' => 'Barcelona',
                'date' => '2025-06-22 15:00:00',
                'status' => 'upcoming',
            ],
            [
                'name' => 'Austrian Grand Prix',
                'location' => 'Spielberg',
                'date' => '2025-06-29 15:00:00',
                'status' => 'upcoming',
            ],
            [
                'name' => 'British Grand Prix',
                'location' => 'Silverstone',
                'date' => '2025-07-06 15:00:00',
                'status' => 'upcoming',
            ],
            [
                'name' => 'Hungarian Grand Prix',
                'location' => 'Budapest',
                'date' => '2025-07-20 15:00:00',
                'status' => 'upcoming',
            ],
            [
                'name' => 'Belgian Grand Prix',
                'location' => 'Spa-Francorchamps',
                'date' => '2025-07-27 15:00:00',
                'status' => 'upcoming',
            ],
            [
                'name' => 'Dutch Grand Prix',
                'location' => 'Zandvoort',
                'date' => '2025-08-24 15:00:00',
                'status' => 'upcoming',
            ],
            [
                'name' => 'Italian Grand Prix',
                'location' => 'Monza',
                'date' => '2025-09-07 15:00:00',
                'status' => 'upcoming',
            ],
            [
                'name' => 'Azerbaijan Grand Prix',
                'location' => 'Baku',
                'date' => '2025-09-21 13:00:00',
                'status' => 'upcoming',
            ],
            [
                'name' => 'Singapore Grand Prix',
                'location' => 'Singapore',
                'date' => '2025-10-05 20:00:00',
                'status' => 'upcoming',
            ],
            [
                'name' => 'United States Grand Prix',
                'location' => 'Austin',
                'date' => '2025-10-19 20:00:00',
                'status' => 'upcoming',
            ],
            [
                'name' => 'Mexico City Grand Prix',
                'location' => 'Mexico City',
                'date' => '2025-10-26 20:00:00',
                'status' => 'upcoming',
            ],
            [
                'name' => 'São Paulo Grand Prix',
                'location' => 'São Paulo',
                'date' => '2025-11-09 17:00:00',
                'status' => 'upcoming',
            ],
            [
                'name' => 'Las Vegas Grand Prix',
                'location' => 'Las Vegas',
                'date' => '2025-11-22 22:00:00',
                'status' => 'upcoming',
            ],
            [
                'name' => 'Qatar Grand Prix',
                'location' => 'Lusail',
                'date' => '2025-11-30 20:00:00',
                'status' => 'upcoming',
            ],
            [
                'name' => 'Abu Dhabi Grand Prix',
                'location' => 'Yas Marina',
                'date' => '2025-12-07 17:00:00',
                'status' => 'upcoming',
            ],
        ];

        foreach ($races as $race) {
            DB::table('races')->updateOrInsert(
                ['name' => $race['name']],
                array_merge($race, [
                    'coordinates' => null,
                    'created_at' => now(),
                    'updated_at' => now(),
                ])
            );
        }
    }
}
