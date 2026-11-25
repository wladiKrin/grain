#!/usr/bin/env bash
# Downloads the Natural Earth layers the offline basemap is built from into
# the directory given (default: build/natural-earth). Natural Earth is in the
# public domain; the files come from its GitHub mirror, pinned to a release.
set -euo pipefail
out="${1:-build/natural-earth}"
tag="v5.1.2"
base="https://raw.githubusercontent.com/nvkelso/natural-earth-vector/$tag/geojson"
mkdir -p "$out"
for f in ne_50m_land ne_50m_lakes ne_50m_admin_0_boundary_lines_land \
  ne_10m_populated_places_simple; do
  [ -s "$out/$f.geojson" ] || curl -sSfL -o "$out/$f.geojson" "$base/$f.geojson"
done
ls -l "$out"
