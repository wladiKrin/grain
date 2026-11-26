#!/bin/bash
# Mirrors fdroiddata CI jobs: fdroid lint / rewritemeta / checkupdates (debian:trixie-slim)
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get --allow-releaseinfo-change update -q >/dev/null
apt-get -qy dist-upgrade >/dev/null
echo "locales locales/locales_to_be_generated multiselect en_US.UTF-8 UTF-8" | debconf-set-selections
apt-get install -qy --no-install-recommends fdroidserver apksigner mercurial git git-svn brz python3-launchpadlib locales curl >/dev/null
cp -a /src /work; cd /work; chown -R $(whoami) .
export fdroidserver=/fdroidserver
git clone -q --shallow-since=2026-07-13 https://gitlab.com/fdroid/fdroidserver.git $fdroidserver
git -C $fdroidserver config transfer.fsckObjects true
git -C $fdroidserver checkout -q -B master a35fdfddd9c66823987a410566a6101186e39c84
git -C $fdroidserver pull -q origin master --ff-only
git -C $fdroidserver log --oneline -1
export PATH="$fdroidserver:$PATH" PYTHONPATH="$fdroidserver:$fdroidserver/examples" PYTHONUNBUFFERED=true serverwebroot=/tmp
chmod 0600 config.yml config/*.yml config/*/*.yml
git config --global user.email x@example.org; git config --global user.name x
git add -A metadata/io.github.wladikrin.grain.yml && git commit -qm wip
echo "=== readmeta"; fdroid readmeta && echo readmeta OK
echo "=== lint"; fdroid lint io.github.wladikrin.grain && echo lint OK || echo LINT FAILED
echo "=== rewritemeta"; fdroid rewritemeta io.github.wladikrin.grain
git diff --exit-code && echo "rewritemeta: no changes" || echo "rewritemeta CHANGED"
cp metadata/io.github.wladikrin.grain.yml /out/rewritten.yml
git checkout metadata/
echo "=== checkupdates"; fdroid checkupdates --allow-dirty -v io.github.wladikrin.grain || echo CHECKUPDATES FAILED
git --no-pager diff
