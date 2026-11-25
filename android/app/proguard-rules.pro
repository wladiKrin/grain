# Flutter's Gradle plugin adds the rules the engine needs.
# Add keep rules here only if R8 breaks the Camera2 bridge or a plugin.
# MapLibre needs nothing here: its AAR and maplibre_gl bring their own
# consumer rules, and every class libmaplibre.so names (JNI) survives R8
# (checked against the release dex when MapLibre came in, 2026-11-25).
