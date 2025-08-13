<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up()
    {
        Schema::create('car_positions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('driver_id')->constrained()->onDelete('cascade');
            $table->foreignId('race_id')->constrained()->onDelete('cascade');
            $table->integer('position'); // 1, 2, 3 etc.
            $table->float('x_coord');
            $table->float('y_coord');
            $table->string('tyre_type'); // soft, medium, hard etc.
            $table->timestamp('timestamp');
            $table->timestamps();
        });
    }

};
