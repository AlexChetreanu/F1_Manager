<?php


use Illuminate\Support\Facades\Route;
use App\Http\Controllers\AuthController;
use Illuminate\Http\Request;
use App\Http\Controllers\Auth\PasswordController;
use App\Http\Controllers\DriverController;
use App\Http\Controllers\RaceController;

Route::post('/login', [AuthController::class, 'login']);
Route::post('/register', [AuthController::class, 'register']);
Route::middleware('auth:sanctum')->post('/logout', function (Request $request) {
    $request->user()->currentAccessToken()->delete();

    return response()->json(['message' => 'Logged out']);
});
Route::middleware('auth:sanctum')->put('/password', [PasswordController::class, 'update_app']);
Route::get('/drivers', [DriverController::class, 'index']);

Route::get('/races', [RaceController::class, 'apiIndex'])->name('races.api');

