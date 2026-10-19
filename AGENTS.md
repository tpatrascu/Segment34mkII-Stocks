# Segment34 MkII Stocks — AGENTS.md

Garmin Connect IQ watchface written in Monkey C. ~60 watch models supported (MIP + AMOLED, round + square).

## Build / toolchain

- Requires the **Garmin Connect IQ SDK** (`monkeyc`, `monkeydo`). It is not installed in this environment; download from developer.garmin.com and add `bin` to PATH.
- Project config is `monkey.jungle`: `project.typecheck = 1`, `project.optimization = 3p`.
- `manifest.xml` is **generated** (edited via VS Code "Monkey C: Edit Application") — do not hand-edit the products/languages list.
- Build one device at a time:

```
monkeyc -f monkey.jungle -o bin/Segment34mkIIStocks.prg -d fenix6 -y developer_key
```


## Device-specific quirks (read before changing resources or annotations)

- `monkey.jungle` lists each device with its own `excludeAnnotations` and `resourcePath`:
  - 96 KB low-memory devices (fenix6s, fr245, …) exclude `WeatherCache` — weather caching is disabled on them.
  - All other devices exclude `NoWeatherCache`.
  - MIP devices pull `resources;disp-resources/mip`; AMOLED devices pull `resources;disp-resources/amoled`.
- Layout/screen-size annotations used in code: `Round240/260/280/360/390/416/454`, `AMOLED`, `MIP`, `Square`, `InstinctCrossover`, `LowMem`, `HighMem`, `DefaultLayout`, `WeatherCache`, `NoWeatherCache`.
- Background process runs in 32–64 KB: Trading212 positions parsing must stay memory-light (see README Trading212 section).

## Entrypoints

- `source/Segment34App.mc` — `Application.AppBase` with `(:background)`; schedules stonks updates, handles settings/cache.
- `source/Segment34View.mc` — `WatchUi.WatchFace`; all rendering/layout.
- `source/StonksService.mc` — `System.ServiceDelegate` (`:background`); fetches Trading212 + Yahoo Finance.

## Localization

Languages: eng, deu, fre, ita, pol, spa, swe. Base strings in `resources/strings/strings.xml`; translations in `resources-<lang>/`. Font glyph widths matter — see `analyze_label_widths.py` (uses `resources/fonts/storre.fnt`) before adding long labels.

## Verification

- **No test suite, no CI, no lint/formatter config** in this repo.
- No `opencode.json` and no existing instruction files (this `AGENTS.md` is the first).
- To test on a device/simulator: `monkeydo bin/Segment34mkIIStocks.prg <device>` (requires SDK + paired device/simulator).
