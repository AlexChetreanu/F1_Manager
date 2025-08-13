<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;

class OpenF1Client
{
    protected string $baseUrl;

    public function __construct(?string $baseUrl = null)
    {
        $this->baseUrl = $baseUrl ?? config('services.openf1.base_url');
    }

    public function get(string $endpoint, array $params = []): array
    {
        $url = rtrim($this->baseUrl, '/').'/'.ltrim($endpoint, '/');
        return Http::get($url, $params)->json();
    }

    public function fetchDrivers(array $params = []): array
    {
        return $this->get('drivers', $params);
    }
}
