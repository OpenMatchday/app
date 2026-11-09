# Open Matchday -- app

Shared Open Matchday application: role shells and event management.

Part of the [OpenMatchday](https://github.com/OpenMatchday) organization.

## D1 status

Provisional framework: **Flutter** + native media modules (see sibling `docs` spike `spikes/d1-application-framework.md` and root `ARCHITECTURE.md` decision D1).

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
