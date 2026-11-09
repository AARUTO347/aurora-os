#!/bin/sh
# Static checks that do not need root or a build. Used by `make check` and CI.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
fail=0
list=$(mktemp)
trap 'rm -f "$list"' EXIT

echo "== script syntax (shell and python) =="
find "$ROOT/build" "$ROOT/scripts" "$ROOT/tests" -type f \
	\( -name '*.sh' -o -name '*.chroot' -o -name 'aurora-*' \) > "$list"
while IFS= read -r f; do
	first=$(head -n 1 "$f")
	case "$first" in
		'#!'*python*)
			# Python files need a Python syntax check, not sh -n.
			if command -v python3 >/dev/null 2>&1; then
				if python3 -c 'import ast, sys
with open(sys.argv[1], encoding="utf-8") as h:
    ast.parse(h.read(), sys.argv[1])' "$f"; then
					printf 'ok   %s (python syntax)\n' "${f#"$ROOT"/}"
				else
					printf 'FAIL %s (python syntax)\n' "${f#"$ROOT"/}"
					fail=1
				fi
			else
				printf 'skip %s (python3 not installed)\n' "${f#"$ROOT"/}"
			fi
			;;
		'#!'*sh*|'#!'*bash*|'#!'*dash*)
			if sh -n "$f"; then
				printf 'ok   %s\n' "${f#"$ROOT"/}"
			else
				printf 'FAIL %s\n' "${f#"$ROOT"/}"
				fail=1
			fi
			;;
		*)
			# Not a script (assets, .desktop, .service, .svg, ...): skip.
			printf 'skip %s (not a script)\n' "${f#"$ROOT"/}"
			;;
	esac
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
	build/live-build/config/includes.chroot/usr/share/aurora/credits.txt \
	scripts/release-gate.sh \
	tests/test-auth-gate.sh; do
	if [ -e "$ROOT/$f" ]; then
		printf 'ok   %s\n' "$f"
	else
		printf 'FAIL missing %s\n' "$f"
		fail=1
	fi
done

echo "== production auth gate regression =="
if [ -f "$ROOT/tests/test-auth-gate.sh" ]; then
	if sh "$ROOT/tests/test-auth-gate.sh"; then
		printf 'ok   release-gate regression\n'
	else
		printf 'FAIL release-gate regression\n'
		fail=1
	fi
else
	printf 'skip tests/test-auth-gate.sh not present\n'
fi

if [ "$fail" -eq 0 ]; then
	echo "RESULT: PASS"
else
	echo "RESULT: FAIL"
	exit 1
fi
