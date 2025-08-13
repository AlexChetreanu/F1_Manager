<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 dark:text-gray-200 leading-tight">
            {{ __('Clasament Piloți') }}
        </h2>
    </x-slot>

    <div class="py-6">
        <div class="max-w-7xl mx-auto sm:px-6 lg:px-8">
            <div class="bg-white dark:bg-gray-800 overflow-hidden shadow-sm sm:rounded-lg">
                <ul class="divide-y divide-gray-200 dark:divide-gray-700">
                    @foreach ($standings as $driver)
                        <li class="p-4 flex justify-between items-center hover:bg-gray-100 dark:hover:bg-gray-700 transition rounded">
                            <div>
                                <div class="text-lg font-semibold text-gray-900 dark:text-gray-100">{{ $driver->name }}</div>
                                <div class="text-sm text-gray-500 dark:text-gray-400">{{ $driver->team }}</div>
                            </div>
                            <div class="text-xl font-bold text-gray-800 dark:text-gray-200">
                                {{ $driver->points }} pts
                            </div>
                        </li>
                    @endforeach
                </ul>
            </div>
        </div>
    </div>
</x-app-layout>
