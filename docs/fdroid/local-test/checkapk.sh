#!/bin/bash
# Mirrors fdroiddata's "check apk" CI job (scanner + manifest), plus a gms/signature check.
source /etc/profile.d/bsenv.sh
export PATH=$fdroidserver:$PATH PYTHONPATH=$fdroidserver:$fdroidserver/examples
cd /builds/fdroiddata
for apk in tmp/*.apk; do
  echo "=== $apk"
  fdroid scanner --verbose --exit-code $apk 2>&1 | grep -v 'DEBUG: Checking\|DEBUG: Ignoring' | tail -5; echo "scanner exit: ${PIPESTATUS[0]}"
  androguard axml $apk -o /tmp/AndroidManifest.xml 2>/dev/null
  echo "-- permissions:"; sed 's/>/>\n/g' /tmp/AndroidManifest.xml | sed -n 's|.*<uses-permission\S* android:name="\([^"]\+\)".*|\1|p'
  echo "-- manifest:"; grep -o 'android:versionCode="[^"]*"\|android:versionName="[^"]*"\|package="[^"]*"\|android:debuggable="[^"]*"' /tmp/AndroidManifest.xml | sort -u
  rm -rf /tmp/x; mkdir /tmp/x; unzip -q -o $apk -d /tmp/x
  echo "-- META-INF:"; ls /tmp/x/META-INF | grep -iE '\.(rsa|dsa|ec|sf)$' || echo "(no v1 signature files)"
  $ANDROID_HOME/build-tools/36.0.0/apksigner verify $apk 2>&1 | head -2
  echo "-- gms classes in dex: $(for d in /tmp/x/classes*.dex; do strings $d; done | grep -c 'Lcom/google/android/gms/')"
  echo "-- firebase/gms strings: $(for d in /tmp/x/classes*.dex; do strings $d; done | grep -ciE 'com/google/firebase|com\.google\.android\.gms')"
  echo "-- native libs:"; unzip -lv $apk | grep '\.so$' | awk '{print $1, $2, $8}'
done
