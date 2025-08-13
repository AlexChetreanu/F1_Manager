<?php
namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\Driver;

class DriverSeeder extends Seeder
{
    public function run(): void
    {
        $drivers = [
            [
                'name' => 'Max Verstappen',
                'team' => 'Red Bull',
                'points' => 195,
                'driver_number' => 1,
                'country_code' => 'NED',
            ],
            [
                'name' => 'Sergio Perez',
                'team' => 'Red Bull',
                'points' => 135,
                'driver_number' => 11,
                'country_code' => 'MEX',
            ],
            [
                'name' => 'Charles Leclerc',
                'team' => 'Ferrari',
                'points' => 112,
                'driver_number' => 16,
                'country_code' => 'MON',
            ],
            [
                'name' => 'Carlos Sainz',
                'team' => 'Ferrari',
                'points' => 98,
                'driver_number' => 55,
                'country_code' => 'ESP',
            ],
            [
                'name' => 'Lando Norris',
                'team' => 'McLaren',
                'points' => 89,
                'driver_number' => 4,
                'country_code' => 'GBR',
            ],
            [
                'name' => 'Oscar Piastri',
                'team' => 'McLaren',
                'points' => 73,
                'driver_number' => 81,
                'country_code' => 'AUS',
            ],
            [
                'name' => 'Lewis Hamilton',
                'team' => 'Mercedes',
                'points' => 65,
                'driver_number' => 44,
                'country_code' => 'GBR',
            ],
            [
                'name' => 'George Russell',
                'team' => 'Mercedes',
                'points' => 60,
                'driver_number' => 63,
                'country_code' => 'GBR',
            ],
            [
                'name' => 'Fernando Alonso',
                'team' => 'Aston Martin',
                'points' => 52,
                'driver_number' => 14,
                'country_code' => 'ESP',
            ],
            [
                'name' => 'Lance Stroll',
                'team' => 'Aston Martin',
                'points' => 40,
                'driver_number' => 18,
                'country_code' => 'CAN',
            ],
            [
                'name' => 'Esteban Ocon',
                'team' => 'Alpine',
                'points' => 0,
                'driver_number' => 31,
                'country_code' => 'FRA',
            ],
            [
                'name' => 'Pierre Gasly',
                'team' => 'Alpine',
                'points' => 0,
                'driver_number' => 10,
                'country_code' => 'FRA',
            ],
            [
                'name' => 'Alex Albon',
                'team' => 'Williams',
                'points' => 0,
                'driver_number' => 23,
                'country_code' => 'THA',
            ],
            [
                'name' => 'Logan Sargeant',
                'team' => 'Williams',
                'points' => 0,
                'driver_number' => 2,
                'country_code' => 'USA',
            ],
            [
                'name' => 'Yuki Tsunoda',
                'team' => 'RB',
                'points' => 0,
                'driver_number' => 22,
                'country_code' => 'JPN',
            ],
            [
                'name' => 'Daniel Ricciardo',
                'team' => 'RB',
                'points' => 0,
                'driver_number' => 3,
                'country_code' => 'AUS',
            ],
            [
                'name' => 'Valtteri Bottas',
                'team' => 'Sauber',
                'points' => 0,
                'driver_number' => 77,
                'country_code' => 'FIN',
            ],
            [
                'name' => 'Zhou Guanyu',
                'team' => 'Sauber',
                'points' => 0,
                'driver_number' => 24,
                'country_code' => 'CHN',
            ],
            [
                'name' => 'Nico Hulkenberg',
                'team' => 'Haas',
                'points' => 0,
                'driver_number' => 27,
                'country_code' => 'GER',
            ],
            [
                'name' => 'Kevin Magnussen',
                'team' => 'Haas',
                'points' => 0,
                'driver_number' => 20,
                'country_code' => 'DEN',
            ],
        ];

        foreach ($drivers as $driver) {
            Driver::updateOrCreate(
                ['driver_number' => $driver['driver_number']],
                $driver
            );
        }
    }
}
