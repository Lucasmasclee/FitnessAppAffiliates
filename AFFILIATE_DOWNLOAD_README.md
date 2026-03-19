# Affiliate download tracking (automatisch) TEST

## Wat er gebeurt (nieuwe definitie)

- **Download:** Een download wordt geregistreerd wanneer een gebruiker in de **paywall** de affiliate code invult (zonder iets te kopen).
- **Subscription:** Een subscription wordt geregistreerd wanneer een gebruiker met een affiliate code een aankoop doet.

## In je Flutter-app (high level)

1. **Dependencies** in `pubspec.yaml`:
   ```yaml
   dependencies:
     http: ^1.2.0
     shared_preferences: ^2.3.0
     android_play_install_referrer: ^0.4.0
   ```
   Daarna: `flutter pub get`.

2. **Bestanden** in je app kopiëren:
   - `start_screen.dart` (vervang je bestaande)
   - `referrer_stub.dart` (nieuw, naast start_screen)
   - `referrer_android.dart` (nieuw, naast start_screen)

3. **iOS-build:** De package `android_play_install_referrer` is Android-specifiek. Als de iOS-build faalt door die import, gebruik dan alleen de stub op iOS:
   - Hernoem `referrer_android.dart` tijdelijk en pas in `start_screen.dart` de import aan tot alleen `referrer_stub.dart` (zonder conditional), of
   - Gebruik een wrapper-package die op iOS een no-op heeft.

4. **Backend:** Zorg dat `affiliate-download` live staat en dat je paywall bij het invullen van de code de download-call uitvoert.
