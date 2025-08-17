<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Carbon\Carbon;

class ImportRaces extends Command
{
    protected $signature = 'import:races';
    protected $description = 'Import F1 races with details and coordinates from local JSON files';

    public function handle()
    {
        $this->info('Start importing races...');

        $jsonPath = storage_path('app/data/championships/f1-locations-2025.json');
        $races = json_decode(file_get_contents($jsonPath), true);

        foreach ($races as $race) {
            $circuitId = $race['id']; // ex: it-1922
            $geoJsonPath = storage_path("app/data/circuits/{$circuitId}.geojson");

            $coordinates = null;
            if (file_exists($geoJsonPath)) {
                try {
                    $geoData = json_decode(file_get_contents($geoJsonPath), true);
                    $coordinates = json_encode($geoData['features'][0]['geometry']['coordinates']);
                } catch (\Exception $e) {
                    $this->warn("Eroare la procesarea coordonatelor pentru {$circuitId}");
                }
            } else {
                $this->warn("Fișierul GEOJSON lipsește pentru {$circuitId}");
            }
            $this->info('Număr curse în JSON: ' . count($races));

            $date = isset($race['date'])
                ? Carbon::parse($race['date'])
                : now();
            $status = $date->isFuture() ? 'upcoming' : 'finished';
            $meetingKey = DB::connection('openf1')
                ->table('meetings')
                ->where('year', $date->year)
                ->whereRaw('LOWER(meeting_name) LIKE ?', ['%' . strtolower($race['name']) . '%'])
                ->value('meeting_key');

            if (! $meetingKey) {
                $this->warn("Meeting key not found for {$race['name']}.");
            }

            $this->info("Saving race: " . $race['name']);

            DB::table('races')->updateOrInsert(
                ['circuit_id' => $circuitId],
                [
                    'name' => $race['name'],
                    'location' => $race['location'],
                    'date' => $date,
                    'status' => $status,
                    'coordinates' => $coordinates,
                    'meeting_key' => $meetingKey,
                    'updated_at' => now(),
                    'created_at' => now(),
                ]
            );

            $this->info("Importat: {$race['name']} ({$circuitId})");
        }

        $this->info('Import complet!');
    }
}
