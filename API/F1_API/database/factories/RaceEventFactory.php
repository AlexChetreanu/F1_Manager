<?php

namespace Database\Factories;

use App\Models\RaceEvent;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<RaceEvent>
 */
class RaceEventFactory extends Factory
{
    protected $model = RaceEvent::class;

    public function definition(): array
    {
        $type = $this->faker->randomElement(['overtake', 'race_control']);
        return [
            'session_key' => 1,
            'event_type' => $type,
            'timestamp_ms' => $this->faker->numberBetween(0, 600000),
            'lap' => $this->faker->numberBetween(1, 70),
            'driver_number' => $this->faker->numberBetween(1, 99),
            'driver_number_overtaken' => $type === 'overtake' ? $this->faker->numberBetween(1, 99) : null,
            'message' => $this->faker->sentence(),
            'subtype' => $this->faker->word(),
            'extra' => [],
        ];
    }
}
