<x-app-layout>
    <x-slot name="header">
        <h2 class="font-semibold text-xl text-gray-800 dark:text-gray-200 leading-tight">
            {{ $race->location }}
        </h2>
    </x-slot>

    <div class="container py-6">
        <canvas id="circuitCanvas" width="800" height="400" style="border:1px solid #ccc;"></canvas>
    </div>

    @stack('scripts')
    <script>
        document.addEventListener('DOMContentLoaded', function () {
            const canvas = document.getElementById('circuitCanvas');
            const ctx = canvas.getContext('2d');

            const coordinates = @json($coordinates ?? []);

            if (!coordinates.length) {
                ctx.font = "20px Arial";
                ctx.fillText("No coordinates available", 10, 50);
                return;
            }

            const lons = coordinates.map(p => p[0]);
            const lats = coordinates.map(p => p[1]);

            const minLon = Math.min(...lons);
            const maxLon = Math.max(...lons);
            const minLat = Math.min(...lats);
            const maxLat = Math.max(...lats);

            function normalize(point) {
                return {
                    x: ((point[0] - minLon) / (maxLon - minLon)) * canvas.width,
                    y: canvas.height - ((point[1] - minLat) / (maxLat - minLat)) * canvas.height
                };
            }

            ctx.beginPath();
            let first = normalize(coordinates[0]);
            ctx.moveTo(first.x, first.y);

            for(let i = 1; i < coordinates.length; i++) {
                let p = normalize(coordinates[i]);
                ctx.lineTo(p.x, p.y);
            }
            ctx.closePath();

            ctx.strokeStyle = "#007bff";
            ctx.lineWidth = 3;
            ctx.stroke();
        });
    </script>
</x-app-layout>
