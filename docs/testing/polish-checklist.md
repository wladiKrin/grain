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
| Click sound on, turn the aperture dial | a soft click per detent, louder on full stops | |
| Click sound on, swipe fast | haptics stay crisp, no lag (compare with click off) | |
| Enable click sound, turn a dial at once | the first detent right after enabling may be silent (the sound loads asynchronously) | |
| Ringer on silent, click sound on | note whether the click follows (expected: system-sound volume rules) | |
| Click sound off, `adb shell dumpsys media.audio_flinger \| grep -i soundpool` | no Grain track | |

## Plan 4 Task 6: parked fixes
- [ ] Manual mode with the viewfinder on, tap a spot: the ring and ticks are clearly visible, not a dot.
- [ ] Tap in the dimmed area: the spot lands on the crop edge.
- [ ] Import a backup containing an active roll and start a roll in the seconds the import runs: one active roll afterwards.
- [ ] On a phone that reports no aperture, the EV line reads "EV ≈..." (f/1.8 assumed).
