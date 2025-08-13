<?php
namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\Http;
use App\Models\Driver;

class ImportDrivers extends Command
{
    protected $signature = 'import:drivers';
    protected $description = 'Import drivers with meeting_key 1262 from OpenF1 API';

    public function handle()
    {
        $this->info('Importăm piloții cu meeting_key 1262...');

        $response = Http::get('https://api.openf1.org/v1/drivers', [
            'meeting_key' => 1262,
        ]);

        $drivers = $response->json();

        // Puncte manuale (exemplu)
        $manualPoints = [
            'Max Verstappen' => 195,
            'Sergio Perez' => 135,
            'Charles Leclerc' => 112,
            'Carlos Sainz' => 98,
            'Lando Norris' => 89,
            'Oscar Piastri' => 73,
            'Lewis Hamilton' => 65,
            'George Russell' => 60,
            'Fernando Alonso' => 52,
            'Lance Stroll' => 40,
        ];

        foreach ($drivers as $driver) {
            $fullName = trim($driver['full_name'] ?? 'Unknown');
            $teamName = $driver['team_name'] ?? 'N/A';
            $driverNumber = $driver['driver_number'] ?? 0;
            $countryCode = $driver['country_code'] ?? 'N/A';

            $existing = Driver::where('name', $fullName)->first();
            if ($existing) {
                $this->info("Pilotul {$fullName} există deja în baza de date.");
                continue;
            }

            Driver::create([
                'name' => $fullName,
                'team' => $teamName,
                'points' => $manualPoints[$fullName] ?? 0,
                'country_code' => $countryCode,
                'driver_number' => $driverNumber,

            ]);

            $this->info("Pilotul {$fullName} a fost adăugat.");
        }


        $this->info('Import finalizat!');
    }
}
