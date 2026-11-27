#!/bin/bash
# Runs as root inside registry.gitlab.com/fdroid/fdroidserver:buildserver-trixie;
# tool/release/build_release.sh starts it. Builds each build entry of the F-Droid
# recipe the way `fdroid build --on-server` does, so that the unsigned APKs are
# byte-identical to F-Droid's:
#   - the source is a clean checkout of the commit at F-Droid's build path,
#     /home/vagrant/build/io.github.wladikrin.grain, fresh for every build;
#   - the srclib (Flutter) is a clone of its tag at /home/vagrant/build/srclib/flutter,
#     and $$flutter$$ in the recipe becomes that path;
#   - sudo (as root), prebuild and build run as user vagrant, with the recipe's
#     own commands, through `bash -e -u -o pipefail -x -c` in the source
#     directory, with the environment variables fdroid sets (SOURCE_DATE_EPOCH
#     from the commit, ANDROID_HOME, LC_ALL, GRADLE_USER_HOME, ...);
#   - fdroid's own source edits are repeated (root local.properties, the
#     cleanup of Gradle build directories after prebuild).
# F-Droid's scanner (`scandelete: .pub-cache`) deletes binaries it flags in
# .pub-cache before the build; none of them is used by the build, and the
# output matches without repeating that (docs/release.md, "Reproducibility").
#
# Usage: container_build.sh <commit> <abi>...   (from /grain-repo, output to /out)
set -euo pipefail

commit=$1; shift
want_abis=("$@")
appid=io.github.wladikrin.grain
home=/home/vagrant
build_root=$home/build
src=$build_root/$appid
recipe_rel=docs/fdroid/$appid.yml

git config --system --add safe.directory '*'
mkdir -p "$build_root/srclib" /out/unsigned
trap '[ -z "${GRAIN_OWNER:-}" ] || chown -R "$GRAIN_OWNER" /out/unsigned' EXIT
chown -R vagrant:vagrant "$build_root"

as_vagrant() { runuser -u vagrant -- "$@"; }

# A fresh clean checkout, as fdroid's vcs.gotorevision leaves it.
checkout() {
  rm -rf "$src"
  as_vagrant git clone -q --no-checkout /grain-repo "$src"
  as_vagrant git -C "$src" checkout -q -f "$commit"
  as_vagrant git -C "$src" clean -q -dffx
}

checkout
recipe=$src/$recipe_rel
[ -f "$recipe" ] || { echo "$recipe_rel is not in $commit" >&2; exit 1; }

# One line per build entry: output|srclibs|sudo|prebuild|build,
# commands joined with "; " as fdroid joins them, base64 so quotes survive (an empty field
# stays a field with a non-whitespace separator).
mapfile -t entries < <(python3 - "$recipe" <<'PY'
import base64, sys, yaml
r = yaml.safe_load(open(sys.argv[1]))
b64 = lambda s: base64.b64encode(s.encode()).decode()
for b in r['Builds']:
    print('|'.join([b['output'], ','.join(b.get('srclibs') or []),
                     b64('; '.join(b.get('sudo') or [])),
                     b64('; '.join(b.get('prebuild') or [])),
                     b64('; '.join(b.get('build') or []))]))
PY
)

flutter_ready=
for entry in "${entries[@]}"; do
  IFS='|' read -r output srclibs sudo_b64 prebuild_b64 build_b64 <<<"$entry"
  abi=$(basename "$output" | sed -n 's/^app-\(.*\)-release\.apk$/\1/p')
  [ -n "$abi" ] || { echo "cannot tell the ABI of output $output" >&2; exit 1; }
  if [ ${#want_abis[@]} -gt 0 ] && [[ " ${want_abis[*]} " != *" $abi "* ]]; then continue; fi
  echo "=== $abi"

  [ "$srclibs" = "${srclibs#*,}" ] && [ "${srclibs%@*}" = flutter ] ||
    { echo "only the flutter srclib is supported, got '$srclibs'" >&2; exit 1; }
  if [ -z "$flutter_ready" ]; then
    rm -rf "$build_root/srclib/flutter"
    as_vagrant git clone -q --depth 1 --branch "${srclibs#*@}" \
      https://github.com/flutter/flutter.git "$build_root/srclib/flutter"
    flutter_ready=1
  fi

  checkout
  printf 'sdk.dir=%s\nsdk-location=%s\n' /opt/android-sdk /opt/android-sdk >"$src/local.properties"
  chown vagrant:vagrant "$src/local.properties"

  # fdroid's environment for the commands (common.set_FDroidPopen_env).
  sde=$(as_vagrant git -C "$src" log -n1 --pretty=%ct)
  run_env=(env -i HOME=$home USER=vagrant LOGNAME=vagrant SHELL=/bin/bash TERM=dumb
    PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games:/opt/android-sdk/tools:/opt/android-sdk/platform-tools
    LC_ALL=C.UTF-8 DEBIAN_FRONTEND=noninteractive
    ANDROID_HOME=/opt/android-sdk ANDROID_SDK=/opt/android-sdk ANDROID_SDK_ROOT=/opt/android-sdk
    ANDROID_NDK= NDK= ANDROID_NDK_HOME= JAVA21_HOME=/usr/lib/jvm/java-21-openjdk-amd64
    GRADLE_USER_HOME=$home/.gradle SOURCE_DATE_EPOCH=$sde)
  cmd() { local s; s=$(base64 -d <<<"$1"); printf '%s' "${s//'$$flutter$$'/$build_root/srclib/flutter}"; }
  for c in "$sudo_b64" "$prebuild_b64" "$build_b64"; do
    if cmd "$c" | grep -q '\$\$'; then echo "unsupported \$\$...\$\$ variable in the recipe" >&2; exit 1; fi
  done

  sudo_cmd=$(cmd "$sudo_b64")
  if [ -n "$sudo_cmd" ]; then
    (cd "$home" && "${run_env[@]}" bash -e -u -o pipefail -x -c "$sudo_cmd")
  fi
  (cd "$src" && runuser -u vagrant -- "${run_env[@]}" bash -e -u -o pipefail -x -c "$(cmd "$prebuild_b64")")

  # fdroid deletes Gradle's build state next to every Gradle build file
  # before scanning (build.py, build_local).
  while IFS= read -r -d '' f; do
    d=$(dirname "$f")
    rm -rf "$d"/build/{android-profile,generated,intermediates,outputs,reports,tmp} \
      "$d/buildSrc/build" "$d/.gradle" "$d/gradlew" "$d/gradlew.bat"
  done < <(find "$src" \( -name build.gradle -o -name build.gradle.kts -o -name settings.gradle \
    -o -name settings.gradle.kts \) -print0)

  (cd "$src" && runuser -u vagrant -- "${run_env[@]}" bash -e -u -o pipefail -x -c "$(cmd "$build_b64")")
  cp "$src/$output" "/out/unsigned/$abi.apk"
  pkill -u vagrant -f GradleDaemon || true
done
