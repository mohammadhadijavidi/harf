# Contributing to Harf

Thanks for helping. Harf is a small, dependency-free macOS app; contributions that keep it that way are welcome.

## Setup

```sh
brew install xcodegen
xcodegen generate
open Harf.xcodeproj
```

Run the tests with `xcodebuild -scheme Harf -destination 'platform=macOS' test`.

## Guidelines

- All text logic lives in `HarfCore` and must be covered by unit tests in `HarfCoreTests`, with real Arabic examples.
- Dictionary data is in `HarfCore/Resources/arabizi-*.txt` (`spellings | Arabic candidates | dialects`) and `lexicon-*.txt` (one word per line). Keep entries neutral and everyday.
- Keyboard tables are generated: edit `scripts/gen-layout-tables.py` or regenerate the dump with `scripts/dump-layouts.swift`, never hand-edit `KeyboardLayoutTables.swift`.
- Every user-facing string needs an English and an Arabic entry: add it to `scripts/gen-strings.py` and run `python3 scripts/gen-strings.py`.
- Swift 6 strict concurrency, no new warnings, no network calls, no telemetry, no emojis.

## Reporting a wrong conversion

Open an issue with the input, the output you got and the output you expected, plus the dialect if relevant.
