# pha_flutter

A new Flutter project.

## Порядок экранов

1. **Онбординг** (единицы → возраст/рост/вес → опционально давление/глюкоза)
2. **Регистрация / вход**
3. **Dashboard**

Данные онбординга сохраняются локально и подставляются в профиль при sign up.

## Запуск (iPhone Simulator)

Требуется [just](https://github.com/casey/just): `brew install just`

```bash
cd /Users/denisermolaev/develop/pha
just run         # симулятор + запуск
just reset       # сброс app + запуск (без flutter clean)
just reset-full  # + flutter clean (долго)
just --list
```

После `just reset` 1–3 минуты идёт сборка — в терминале появятся логи `flutter run`, потом app на симуляторе.

Другой симулятор: `IOS_DEVICE_ID=<uuid> just run`.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
