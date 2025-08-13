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
        Schema::create('races', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('circuit');
            $table->dateTime('date');
            $table->enum('status', ['live', 'finished', 'upcoming']);
            $table->timestamps();
        });
    }

};
