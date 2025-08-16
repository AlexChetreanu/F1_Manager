<?php

namespace App\Console\Commands;

use Carbon\CarbonImmutable;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;

class OpenF1Pull extends Command
{
    protected $signature = 'openf1:pull 
        {year=2024} 
        {--hours=3} 
        {--chunk=15 : minutes per request window} 
        {--sleep=350 : ms between requests}
        {--endpoints=laps,pit,stints,position,intervals,race_control,team_radio : comma list; add car_data,location if you want}';

    protected $description = 'Trage datele OpenF1 pentru cursele (Race) din anul dat, doar in fereastra [start, start+H]';

    protected string $base = 'https://api.openf1.org/v1';

    public function handle(): int
    {
        $year      = (int)$this->argument('year');
        $hours     = (int)$this->option('hours');
        $chunkMins = (int)$this->option('chunk');
        $sleepMs   = (int)$this->option('sleep');
        $endpoints = array_map('trim', explode(',', $this->option('endpoints')));

        $sessions = Http::timeout(30)->get("{$this->base}/sessions", [
            'year' => $year,
            'session_name' => 'Race',
        ])->throw()->json();

        $this->info('Found '.count($sessions).' race sessions in '.$year);

        foreach ($sessions as $s) {
            $sk   = $s['session_key']   ?? null;
            $name = $s['meeting_official_name'] ?? ($s['meeting_name'] ?? 'Unknown GP');
            $ds   = $s['date_start']    ?? null;
            $de   = $s['date_end']      ?? null;
            if (!$sk || !$ds) {
                continue;
            }

            $start = CarbonImmutable::parse($ds);
            $end   = $de ? CarbonImmutable::parse($de) : $start->addHours($hours);
            $windowEnd = min($start->addHours($hours), $end);

            $this->newLine();
            $this->line("▶ {$name} (session_key={$sk})");
            $this->line("   Window: {$start} → {$windowEnd}");

            $timeField = [
                'laps'         => 'date_start',
                'pit'          => 'date',
                'stints'       => 'date',
                'position'     => 'date',
                'intervals'    => 'date',
                'race_control' => 'date',
                'team_radio'   => 'date',
                'car_data'     => 'date',
                'location'     => 'date',
                'weather'      => 'date',
            ];

            foreach ($endpoints as $ep) {
                if (!isset($timeField[$ep])) {
                    $this->warn("   [skip] endpoint necunoscut: {$ep}");
                    continue;
                }
                $tf = $timeField[$ep];

                for ($wStart = $start; $wStart < $windowEnd; $wStart = $wStart->addMinutes($chunkMins)) {
                    $wEnd = $wStart->addMinutes($chunkMins);
                    if ($wEnd > $windowEnd) {
                        $wEnd = $windowEnd;
                    }

                    $params = [
                        'session_key' => $sk,
                        "{$tf}>=" => $wStart->toIso8601String(),
                        "{$tf}<=" => $wEnd->toIso8601String(),
                    ];

                    try {
                        $resp = Http::timeout(30)->get("{$this->base}/{$ep}", $params)->throw();
                        $items = $resp->json() ?? [];

                        if (!is_array($items)) {
                            $items = [];
                        }

                        if ($items) {
                            $rows = [];
                            $now = now();
                            foreach ($items as $obj) {
                                $timeVal = $obj[$tf] ?? ($obj['date'] ?? null);
                                $rows[] = [
                                    'endpoint'    => $ep,
                                    'session_key' => $sk,
                                    'time_field'  => $tf,
                                    'time_value'  => $timeVal ? date('Y-m-d H:i:s.u', strtotime($timeVal)) : null,
                                    'payload'     => json_encode($obj, JSON_UNESCAPED_UNICODE),
                                    'created_at'  => $now,
                                    'updated_at'  => $now,
                                ];
                            }
                            DB::connection('openf1')->table('raw_events')->insert($rows);
                        }

                        $this->info(sprintf("   %-12s %s → %s  +%d",
                            $ep, $wStart->format('H:i:s'), $wEnd->format('H:i:s'), count($items)
                        ));
                    } catch (\Throwable $e) {
                        $this->warn("   [warn] {$ep} {$wStart}→{$wEnd} : ".$e->getMessage());
                    }

                    usleep($sleepMs * 1000);
                }
            }
        }

        $this->info('Done.');
        return self::SUCCESS;
    }
}
