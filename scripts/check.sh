#!/bin/sh
# Static checks that do not need root or a build. Used by `make check` and CI.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
fail=0
list=$(mktemp)
trap 'rm -f "$list"' EXIT

echo "== POSIX shell syntax =="
find "$ROOT/build" "$ROOT/scripts" -type f \
	\( -name '*.sh' -o -name '*.chroot' -o -name 'aurora-*' \) > "$list"
while IFS= read -r f; do
	if sh -n "$f"; then
		printf 'ok   %s\n' "${f#"$ROOT"/}"
	else
		printf 'FAIL %s\n' "${f#"$ROOT"/}"
		fail=1
	fi
done < "$list"

echo "== desktop entries =="
if command -v desktop-file-validate >/dev/null 2>&1; then
	find "$ROOT/build" -name '*.desktop' > "$list"
	while IFS= read -r f; do
		if ! desktop-file-validate "$f"; then
			fail=1
		fi
	done < "$list"
else
	echo "SKIP desktop-file-validate not installed"
fi

echo "== required files =="
for f in \
	README.md VERSION LICENSE NOTICE CHANGELOG.md \
	build/live-build/auto/config \
	build/live-build/config/package-lists/aurora.list.chroot \
	build/live-build/config/includes.chroot/etc/lightdm/lightdm.conf.d/50-aurora.conf \
	build/live-build/config/includes.chroot/usr/share/aurora/login-logo.svg \
	build/live-build/config/includes.chroot/usr/share/aurora/credits.txt; do
	if [ -e "$ROOT/$f" ]; then
		printf 'ok   %s\n' "$f"
	else
		printf 'FAIL missing %s\n' "$f"
		fail=1
	fi
done

if [ "$fail" -eq 0 ]; then
	echo "RESULT: PASS"
else
	echo "RESULT: FAIL"
	exit 1
fi
