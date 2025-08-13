<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 dark:text-gray-200 leading-tight">
            {{ __('F1 Circuits') }}
        </h2>
    </x-slot>

    <div class="container py-6 space-y-4">
        @foreach ($races as $race)
            <a href="{{ route('races.show', $race->id) }}"
               class="block p-4 bg-white dark:bg-gray-800 rounded-lg shadow hover:shadow-lg transition-shadow duration-300">
                <h3 class="text-lg font-semibold text-indigo-600 dark:text-indigo-400">{{ $race->location }}</h3>
                <p class="text-sm text-gray-600 dark:text-gray-400">Date: <span class="font-medium">{{ $race->date }}</span></p>
                <p class="text-sm text-gray-600 dark:text-gray-400">Status:
                    <span class="font-semibold
                        {{ $race->status === 'Finished' ? 'text-green-600 dark:text-green-400' : '' }}
                        {{ $race->status === 'Cancelled' ? 'text-red-600 dark:text-red-400' : '' }}
                        {{ $race->status !== 'Finished' && $race->status !== 'Cancelled' ? 'text-yellow-600 dark:text-yellow-400' : '' }}">
                        {{ $race->status }}
                    </span>
                </p>
            </a>
        @endforeach
    </div>
</x-app-layout>
