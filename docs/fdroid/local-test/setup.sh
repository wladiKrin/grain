#!/bin/bash
# One-time setup, mirrors the before-loop part of fdroiddata's "fdroid build" CI job.
set -ex
export DEBIAN_FRONTEND=noninteractive
CI_PROJECT_DIR=/builds/fdroiddata
mkdir -p /builds; rm -rf $CI_PROJECT_DIR; cp -a /src $CI_PROJECT_DIR; cd $CI_PROJECT_DIR
chown -R $(whoami) .
test -d build || mkdir build
apt-get update -q; apt-get -qy dist-upgrade
source /etc/profile.d/bsenv.sh
sdkmanager "platform-tools" "build-tools;31.0.0"
rm -rf $fdroidserver
git clone -q --shallow-since=2026-07-13 https://gitlab.com/fdroid/fdroidserver.git $fdroidserver
git -C $fdroidserver config transfer.fsckObjects true
git -C $fdroidserver checkout -q -B master a35fdfddd9c66823987a410566a6101186e39c84
git -C $fdroidserver pull -q origin master --ff-only
git -C $home_vagrant/gradlew-fdroid pull
rm -rf /tmp/fdroid-bootstrap-buildserver
git -C /tmp/ clone -q https://gitlab.com/fdroid/fdroid-bootstrap-buildserver.git
BOOTSTRAP_BUILDSERVER=/tmp/fdroid-bootstrap-buildserver
git -C $BOOTSTRAP_BUILDSERVER config transfer.fsckObjects true
git -C $BOOTSTRAP_BUILDSERVER checkout -q -B master b33507043e6750065745dd2d8c35d3bb5c633c11
git -C $BOOTSTRAP_BUILDSERVER pull -q origin master --ff-only
cp $BOOTSTRAP_BUILDSERVER/roles/production_hardening/files/gitconfig $CI_PROJECT_DIR/../.gitconfig
for d in logs tmp unsigned $home_vagrant/.android $home_vagrant/.gradle $home_vagrant/metadata; do
  test -d $d || mkdir $d; chown -R vagrant $d; done
ln -sfn $home_vagrant/.gradle $CI_PROJECT_DIR/.gradle
ln -sfn $CI_PROJECT_DIR/tmp $home_vagrant/tmp
ln -sfn $CI_PROJECT_DIR/srclibs $home_vagrant/srclibs
sysctl fs.inotify.max_user_watches=524288 || true
echo SETUP DONE
