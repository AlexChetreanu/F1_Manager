<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Http\Controllers\DataController;
use Illuminate\Http\Request;

class FetchOpenF1Data extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'fetch:openf1-data';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Fetch driver data from the OpenF1 API';

    /**
     * Execute the console command.
     */
    public function handle()
    {
        $this->info('Fetching driver data from OpenF1...');

        $controller = app(DataController::class);
        $response = $controller->fetchData(new Request());

        $this->info($response->getContent());

        return Command::SUCCESS;
    }
}
