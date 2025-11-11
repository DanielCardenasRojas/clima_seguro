# Lab 1 · Consumo seguro de API REST (OpenWeather + Flutter)

## Objetivo
Consumir clima desde OpenWeatherMap mostrando UI con estados (**vacío / cargando / datos / error**) y manejo de secretos con `.env`.

## Requisitos
- Flutter 3.x
- API key de OpenWeatherMap

## Configuración
```bash
flutter pub get
# Copia el ejemplo y edita tu key
cp .env.example .env
# En Windows puedes crearlo manualmente y pegar la key
# Ejecuta:
flutter run -d windows
