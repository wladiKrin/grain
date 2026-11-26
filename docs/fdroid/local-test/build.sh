#!/bin/bash
# Mirrors the per-build loop of fdroiddata's "fdroid build" CI job. Usage: build.sh appid:vercode...
set -e
export DEBIAN_FRONTEND=noninteractive
source /etc/profile.d/bsenv.sh
CI_PROJECT_DIR=/builds/fdroiddata; cd $CI_PROJECT_DIR
cp /src/metadata/io.github.wladikrin.grain.yml metadata/   # pick up recipe edits
apt-get install -qy sudo >/dev/null
export GRADLE_USER_HOME=$home_vagrant/.gradle
fdroid="sudo --preserve-env --user vagrant env PATH=$fdroidserver:$(sudo --user vagrant -i printenv PATH) env PYTHONPATH=$fdroidserver:$fdroidserver/examples env PYTHONUNBUFFERED=true env TERM=$TERM env HOME=$home_vagrant fdroid"
for build in "$@"; do
  set -x
  apt-get install -qy sudo
  apt-get install -qy openjdk-21-jdk-headless
  update-alternatives --set java /usr/lib/jvm/java-21-openjdk-amd64/bin/java
  cp -R $CI_PROJECT_DIR/build $home_vagrant/build
  appid=${build%:*}
  [ -d metadata/$appid ] && cp -R metadata/$appid $home_vagrant/metadata
  cp -R metadata/$appid.yml $home_vagrant/metadata
  chown -R vagrant $home_vagrant $CI_PROJECT_DIR
  pushd $home_vagrant
  ln -sfn $CI_PROJECT_DIR $home_vagrant/fdroiddata
  ln -sfn $CI_PROJECT_DIR/../.gitconfig $home_vagrant/.gitconfig
  $fdroid fetchsrclibs $build --verbose
  rm $home_vagrant/fdroiddata $home_vagrant/.gitconfig
  (unset CI; $fdroid build --verbose --test --refresh-scanner --on-server --no-tarball $build) && echo "BUILD OK $build" || { echo "BUILD FAILED $build"; popd; exit 1; }
  apt-get install -qy sudo
  popd
  [ -n "$KEEP" ] || rm -rf $home_vagrant/build || true
  set +x
done
