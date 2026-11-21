# Grain polish: on-device checklist

Device: Pixel 10, release build

| check | expected | result |
|---|---|---|
| Histogram on, pan from a window to a dark room | the bars move ~15×/s, no dial jank | |
| Histogram with an active slide roll, mid-grey subject | the band is narrow, about a third of the panel | |
| Histogram on, tap Hold, pan away | the histogram freezes with the held reading | |
| `adb shell top -H`: GrainCamera CPU with histogram on vs off | the same | |
| Stats rate (`debugPrint` count over 10 s or the DevTools timeline), 30 and 60 fps | ≤ 15/s | |
| Shake warning on, 50 mm, shutter priority 1/30 | a quiet hand mark (secondary grey, not accent) beside SHUTTER | |
| Same at 1/60 | the mark is gone | |
| 6x7 body with a 90 mm lens | the mark appears at 1/60 | |
