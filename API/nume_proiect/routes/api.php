<?php

use App\Http\Controllers\NewsController;
use Illuminate\Support\Facades\Route;

Route::get('/news/f1', [NewsController::class, 'f1Autosport']);
Route::get('/news/f1/debug', [NewsController::class, 'debug']);
