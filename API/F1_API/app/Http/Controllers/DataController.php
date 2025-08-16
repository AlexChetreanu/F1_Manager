<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;

class DataController extends Controller
{
    public function fetchData()
    {
        // Înlocuiește cu URL-ul tău propriu dacă nu vrei să folosești JSONPlaceholder
        $response = Http::get('https://jsonplaceholder.typicode.com/posts');

        // Verifică dacă răspunsul a fost cu succes (200 OK)
        if ($response->successful()) {
            $data = $response->json();
            return response()->json($data);
        }

        // Dacă API-ul returnează o eroare, afișează mesajul de eroare
        return response()->json(['error' => 'Nu s-a putut obține datele'], 500);
    }
}
