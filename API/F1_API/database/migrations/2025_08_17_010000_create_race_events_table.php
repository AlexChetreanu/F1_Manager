<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('race_events', function (Blueprint $table) {
            $table->id();
            $table->integer('session_key')->index();
            $table->enum('event_type', ['overtake', 'race_control'])->index();
            $table->unsignedBigInteger('timestamp_ms')->index();
            $table->integer('lap')->nullable();
            $table->integer('driver_number')->nullable();
            $table->integer('driver_number_overtaken')->nullable();
            $table->text('message')->nullable();
            $table->string('subtype', 64)->nullable();
            $table->json('extra')->nullable();
            $table->timestamps();

            $table->index(['session_key', 'timestamp_ms']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('race_events');
    }
};
