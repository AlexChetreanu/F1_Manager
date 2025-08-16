<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::connection('openf1')->create('raw_events', function (Blueprint $table) {
            $table->id();
            $table->string('endpoint', 40)->index();
            $table->unsignedBigInteger('session_key')->index();
            $table->string('time_field', 20)->nullable();
            $table->dateTime('time_value', 6)->nullable();
            $table->json('payload');
            $table->timestamps();
        });
    }

    public function down(): void {
        Schema::connection('openf1')->dropIfExists('raw_events');
    }
};
