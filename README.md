# Open Matchday -- app

Shared Open Matchday application: role shells and event management.

Part of the [OpenMatchday](https://github.com/OpenMatchday) organization.

## D1 status

Provisional framework: **Flutter** + native media modules (see sibling `docs` spike `spikes/d1-application-framework.md` and root `ARCHITECTURE.md` decision D1).

## D5 OCR (Scoreboard Reader)

Provisional engine lives in sibling `media` (Tesseract 5 + tessdata_fast eng, Apache-2.0). The Flutter app consumes OCR readings (value, confidence, timestamp, staleness) through the media native bridge — it does not embed an OCR engine in Dart. Spike record: `docs/spikes/d5-ocr-engine.md` and `ARCHITECTURE.md` decision D5.

## Develop

Requires Flutter stable (spike verified on 3.47.9).

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d windows
flutter build apk
```

## License

MIT. See [LICENSE](LICENSE). Flutter SDK is BSD 3-Clause (upstream).
