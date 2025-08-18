<?php


use Illuminate\Support\Facades\Route;
use App\Http\Controllers\AuthController;
use Illuminate\Http\Request;
use App\Http\Controllers\Auth\PasswordController;
use App\Http\Controllers\DriverController;
use App\Http\Controllers\RaceController;
use App\Http\Controllers\OpenF1Controller;
use App\Http\Controllers\LiveController;
use App\Http\Controllers\HealthController;

Route::post('/login', [AuthController::class, 'login']);
Route::post('/register', [AuthController::class, 'register']);
Route::middleware('auth:sanctum')->post('/logout', function (Request $request) {
    $request->user()->currentAccessToken()->delete();

    return response()->json(['message' => 'Logged out']);
});
Route::middleware('auth:sanctum')->put('/password', [PasswordController::class, 'update_app']);
Route::get('/drivers', [DriverController::class, 'index']);

Route::get('/races', [RaceController::class, 'apiIndex'])->name('races.api');

Route::get('/openf1/sessions/{session_key}/drivers', [OpenF1Controller::class, 'sessionDrivers']);
Route::get('/openf1/sessions/{session_key}/laps', [OpenF1Controller::class, 'sessionLaps']);
Route::get('/openf1/sessions/{session_key}/car_data', [OpenF1Controller::class, 'sessionCarData']);
Route::get('/openf1/meetings/{meeting_key}/starting_grid', [OpenF1Controller::class, 'meetingGrid']);
Route::get('/openf1/{table}', [OpenF1Controller::class, 'query']);

Route::get('/live/resolve', [LiveController::class, 'resolveSession']);
Route::get('/live/snapshot', [LiveController::class, 'snapshot']);
Route::get('/live/stream', [LiveController::class, 'stream']);
Route::get('/health', [HealthController::class, 'index']);

