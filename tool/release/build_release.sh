#!/usr/bin/env bash
# Builds Grain's release APKs as F-Droid builds them, then signs them on the host.
#
#   tool/release/build_release.sh [<git ref>] [<abi>...]
#
# 1. Starts F-Droid's buildserver image and builds every build entry of
#    docs/fdroid/io.github.wladikrin.grain.yml (as that file is at <ref>) for
#    <ref> (default HEAD; a tag for a release), with the recipe's own commands,
#    at F-Droid's paths (tool/release/container_build.sh). Only committed
#    files are built.
# 2. Checks each unsigned APK is zipaligned (zipalign must not change it) and
#    signs a copy with apksigner (v2 + v3, alignment preserved) using
#    android/key.properties, then checks that the signed APK is the unsigned
#    one plus an APK Signing Block and nothing else: F-Droid copies that block
#    onto its own unsigned build, which must then verify. The unsigned APKs are kept.
#
# Output: build/release/v<version>/grain-<version>-<abi>.apk (signed, upload
# these to the GitHub release v<version>) and build/release/v<version>/unsigned/.
#
# Environment:
#   GRAIN_FDROID_IMAGE    image (default registry.gitlab.com/fdroid/fdroidserver:buildserver-trixie)
#   GRAIN_KEY_PROPERTIES  signing properties (default android/key.properties):
#                         storeFile, storePassword, keyAlias, keyPassword, as
#                         for Gradle; a relative storeFile is relative to android/app
#   GRAIN_RELEASE_OUT     output directory (default build/release/v<version>)
#   GRAIN_NO_SIGN=1       build only
# Needs docker, git, and ANDROID_HOME with build-tools (zipalign, apksigner).
set -euo pipefail

repo=$(git rev-parse --show-toplevel)
cd "$repo"
ref=${1:-HEAD}
[ $# -gt 0 ] && shift
commit=$(git rev-parse --verify "$ref^{commit}")
if [ "$ref" = HEAD ] && [ -n "$(git status --porcelain --untracked-files=no)" ]; then
  echo "warning: uncommitted changes are not part of the build (building $commit)" >&2
fi

version_line=$(git show "$commit:pubspec.yaml" | sed -n 's/^version: *//p')
version=${version_line%+*}
[ -n "$version" ] && [ "$version" != "$version_line" ] ||
  { echo "pubspec.yaml at $commit: cannot read version: X.Y.Z+N" >&2; exit 1; }
image=${GRAIN_FDROID_IMAGE:-registry.gitlab.com/fdroid/fdroidserver:buildserver-trixie}
out=${GRAIN_RELEASE_OUT:-$repo/build/release/v$version}
mkdir -p "$out"
out=$(cd "$out" && pwd)
rm -rf "$out/unsigned"
mkdir "$out/unsigned"

if [ "${GRAIN_NO_SIGN:-}" != 1 ]; then
  # Fail before the long build if signing cannot work.
  bt=$(ls -d "${ANDROID_HOME:?set ANDROID_HOME}"/build-tools/* | sort -V | tail -n1)
  [ -x "$bt/apksigner" ] && [ -x "$bt/zipalign" ] || { echo "no apksigner/zipalign in $bt" >&2; exit 1; }
  props=${GRAIN_KEY_PROPERTIES:-$repo/android/key.properties}
  [ -f "$props" ] || { echo "$props does not exist (or set GRAIN_NO_SIGN=1)" >&2; exit 1; }
fi

echo "Building $version ($commit) in $image"
# Clone the source into the container through a mount of this repository.
docker run --rm --name "grain-fdroid-release-$$" \
  -v "$repo:/grain-repo:ro" -v "$out:/out" -e GRAIN_OWNER="$(id -u):$(id -g)" \
  "$image" bash /grain-repo/tool/release/container_build.sh "$commit" "$@"

shopt -s nullglob
apks=("$out"/unsigned/*.apk)
[ ${#apks[@]} -gt 0 ] || { echo "no APKs were built" >&2; exit 1; }
for apk in "${apks[@]}"; do
  abi=$(basename "$apk" .apk)
  mv "$apk" "$out/unsigned/grain-$version-$abi.apk"
done
(cd "$out/unsigned" && sha256sum grain-*.apk)
[ "${GRAIN_NO_SIGN:-}" = 1 ] && exit 0

prop() {
  local v
  v=$(sed -n "s/^[[:space:]]*$1[[:space:]]*[=:][[:space:]]*//p" "$props" | tail -n1)
  [ -n "$v" ] || { echo "$props lacks $1" >&2; exit 1; }
  printf '%s' "$v"
}
store=$(prop storeFile)
case $store in /*) ;; *) store=$repo/android/app/$store ;; esac
[ -f "$store" ] || { echo "storeFile $store does not exist" >&2; exit 1; }
alias=$(prop keyAlias)
GRAIN_KS_PASS=$(prop storePassword)
GRAIN_KEY_PASS=$(prop keyPassword)
export GRAIN_KS_PASS GRAIN_KEY_PASS

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
for apk in "$out"/unsigned/grain-*.apk; do
  name=$(basename "$apk")
  "$bt/zipalign" -f -p 4 "$apk" "$tmp/$name"
  cmp -s "$apk" "$tmp/$name" ||
    { echo "$name: zipalign changed the APK; F-Droid's build would not match the signed one" >&2; exit 1; }
  # Keep the APK as it is (apksigner re-aligns entries by default) and add
  # only an APK Signing Block: v2 and v3, no v1 (minSdk 29). F-Droid copies
  # that block onto its own unsigned build, which must then verify.
  "$bt/apksigner" sign --ks "$store" --ks-key-alias "$alias" \
    --ks-pass env:GRAIN_KS_PASS --key-pass env:GRAIN_KEY_PASS \
    --alignment-preserved true --v1-signing-enabled false \
    --v2-signing-enabled true --v3-signing-enabled true \
    --in "$tmp/$name" --out "$out/$name"
  rm -f "$out/$name.idsig"
  python3 -I - "$apk" "$out/$name" <<'PY' ||
import struct, sys
u, s = (open(f, 'rb').read() for f in sys.argv[1:])
def cd(b):  # offset of the central directory, from the end of central directory record
    e = b.rindex(b'PK\x05\x06')
    return e, struct.unpack_from('<I', b, e + 16)[0]
ue, uc = cd(u); se, sc = cd(s)
# Same entries and central directory; between them only the signing block,
# which ends with its magic; in the end record only the offset moves.
ok = (s[:uc] == u[:uc] and s[sc - 16:sc] == b'APK Sig Block 42'
      and s[sc:se] == u[uc:ue] and s[se:se + 16] == u[ue:ue + 16]
      and s[se + 20:] == u[ue + 20:])
sys.exit(0 if ok else 1)
PY
    { echo "$name: the signed APK is not the unsigned one plus a signing block" >&2; exit 1; }
done
unset GRAIN_KS_PASS GRAIN_KEY_PASS

recipe_keys=$(git show "$commit:docs/fdroid/io.github.wladikrin.grain.yml" |
  sed -n 's/^AllowedAPKSigningKeys: *//p')
for apk in "$out"/grain-*.apk; do
  cert=$("$bt/apksigner" verify --print-certs "$apk" |
    sed -n 's/^Signer #1 certificate SHA-256 digest: //p')
  echo "$(basename "$apk"): signed, certificate SHA-256 $cert"
  [ "$cert" = "$recipe_keys" ] ||
    echo "  warning: the recipe's AllowedAPKSigningKeys is $recipe_keys" >&2
done
(cd "$out" && sha256sum grain-*.apk)
