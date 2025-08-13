<?php

use App\Http\Controllers\ProfileController;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\StandingsController;
use App\Http\Controllers\RaceController;

Route::get('/', function () {
    return view('welcome');
});

Route::get('/dashboard', function () {
    return view('dashboard');
})->middleware(['auth', 'verified'])->name('dashboard');

Route::middleware('auth')->group(function () {
    Route::get('/profile', [ProfileController::class, 'edit'])->name('profile.edit');
    Route::patch('/profile', [ProfileController::class, 'update'])->name('profile.update');
    Route::delete('/profile', [ProfileController::class, 'destroy'])->name('profile.destroy');
});



Route::middleware(['auth'])->get('/standings', [StandingsController::class, 'index'])->name('standings');

Route::get('/races', [RaceController::class, 'index'])->name('races.index');
Route::get('/races/{race}', [RaceController::class, 'show'])->name('races.show');

require __DIR__.'/auth.php';
