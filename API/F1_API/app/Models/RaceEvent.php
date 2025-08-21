<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class RaceEvent extends Model
{
    use HasFactory;

    protected $fillable = [
        'session_key',
        'event_type',
        'timestamp_ms',
        'lap',
        'driver_number',
        'driver_number_overtaken',
        'message',
        'subtype',
        'extra',
    ];

    protected $casts = [
        'extra' => 'array',
    ];
}
