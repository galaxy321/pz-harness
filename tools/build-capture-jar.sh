#!/bin/sh
# same steps as java/build.sh, into a new dir, no deletion; $1 = output jar
set -e
P=/tmp/claude-0/-home-claude/91392442-91f3-5555-956d-ce09558093cb/scratchpad/work/test-ground/TestGroundCapture
OUT=$(mktemp -d -p /tmp/claude-0/-home-claude/91392442-91f3-5555-956d-ce09558093cb/scratchpad/b105)
javac --release 21 -nowarn -cp "$GAME_CLASSES:$ZB_JAR" -d "$OUT" "$P"/java/src/pzmod/tgcapture/*.java
(cd "$OUT" && find pzmod -exec touch -d "2026-10-18 00:00:00" {} + && jar --create --date=2026-10-18T00:00:00Z --file "$1" pzmod)
sha256sum "$1"
