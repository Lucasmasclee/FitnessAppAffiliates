# Affiliate download tracking (automatisch) TEST

## Wat er gebeurt

- **Android:** Als iemand via `https://liftbetter.cloud/join2` naar de Play Store gaat, voegen we `referrer=affiliate_code%3Djoin2` toe aan de store-URL. De app leest bij eerste open de Install Referrer en stuurt één keer een download-registratie naar Supabase. Geen invoer van de gebruiker.
- **iOS:** Apple biedt geen install referrer. De app probeert optioneel de **clipboard** (als die iets als `join2` of een link met `/join2` bevat). Anders wordt op iOS geen download automatisch geteld.

## In je Flutter-app

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

4. **Backend:** Zorg dat de Edge Function `affiliate-redirect` opnieuw is gedeployed (zodat de Play Store-URL de `referrer`-parameter meekrijgt), en dat `affiliate-download` live staat.
