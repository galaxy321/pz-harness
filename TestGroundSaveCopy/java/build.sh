#!/bin/sh
# Builds TestGroundSaveCopy/42/media/java/tgsavecopy.jar from java/src.
#   GAME_CLASSES: projectzomboid.jar, or a folder of its classes (class-file major version lowered with an older javac)
#   ZB_JAR:       ZombieBuddy.jar
# Fixed file times, so the same source gives the same SHA-256. Signing (zbs-sign-mod.ps1) is done on the PC.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=$(mktemp -d)
javac --release 21 -nowarn -cp "$GAME_CLASSES:$ZB_JAR" -d "$OUT" "$HERE"/src/pzmod/tgsavecopy/*.java
mkdir -p "$HERE/../42/media/java"
(cd "$OUT" && find pzmod -exec touch -d "2026-10-21 00:00:00" {} + && jar --create --date=2026-10-21T00:00:00Z --file "$HERE/../42/media/java/tgsavecopy.jar" pzmod)
rm -rf "$OUT"
echo "built 42/media/java/tgsavecopy.jar"
