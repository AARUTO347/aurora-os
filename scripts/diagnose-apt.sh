#!/bin/sh
# Read-only APT/network diagnostic for AURORA builds.
#
# Usage: scripts/diagnose-apt.sh [--quick] [suite]
#   --quick   skip the isolated `apt-get update` (connectivity probes only)
#
# Prints no credentials and never changes system configuration. Exits nonzero
# if a required check fails, so build-iso.sh can refuse to start a long build
# when the archive is unreachable.
set -u

quick=false
if [ "${1:-}" = "--quick" ]; then
    quick=true
    shift
fi
suite=${1:-resolute}
fail=0

pass() { printf 'PASS  %s\n' "$*"; }
bad()  { printf 'FAIL  %s\n' "$*"; fail=1; }
info() { printf '%s\n' "$*"; }

info "== environment =="
info "date:   $(date -Is 2>/dev/null || date)"
info "user:   $(id -un 2>/dev/null) (uid $(id -u 2>/dev/null))"
info "host:   $(hostname 2>/dev/null)"
info "kernel: $(uname -r 2>/dev/null)"
[ -f /etc/aurora-release ] && info "image:  $(head -1 /etc/aurora-release)"
if [ -d /home/aaruto/aurora-build/work/chroot ]; then
    info "context: WSL build host (live-build work dir present)"
elif [ -f /etc/live/config/functions.sh ] || [ -d /root/config ]; then
    info "context: inside a live-build chroot"
else
    info "context: neither WSL build host nor live-build chroot"
fi

info ""
info "== proxy environment (values hidden) =="
env | grep -i proxy | sed 's/=.*/=<set>/' || info "none"

info ""
info "== apt user-agent configuration =="
ua=$(apt-config dump 2>/dev/null | sed -n 's/^Acquire::http::User-Agent "\(.*\)";$/\1/p')
info "effective http UA: ${ua:-<apt default>}"
for f in /etc/apt/apt.conf.d/99local-useragent \
         /etc/apt/apt.conf.d/99aurora-useragent \
         /etc/apt/apt.conf; do
    [ -f "$f" ] && info "present: $f"
done

info ""
info "== repositories =="
repo_lines=$(grep -rhE '^(deb |URIs:|Suites:)' \
    /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null) || repo_lines=""
if [ -z "$repo_lines" ]; then
    bad "no repository definitions found"
else
    printf '%s\n' "$repo_lines"
fi

uris=$(printf '%s\n' "$repo_lines" | sed -n 's/^URIs:[[:space:]]*//p' | tr ' ' '\n' | sort -u)
if [ -z "$uris" ]; then
    uris=$(printf '%s\n' "$repo_lines" | awk '/^deb /{print $2}' | sort -u)
fi
suites=$(printf '%s\n' "$repo_lines" | sed -n 's/^Suites:[[:space:]]*//p' | tr ' ' '\n' | sort -u)
[ -n "$suites" ] || suites=$suite

http_status() {
    url=$1
    if command -v wget >/dev/null 2>&1; then
        out=$(wget --spider --server-response --timeout=20 --tries=1 \
            --user-agent="${ua:-Wget}" "$url" 2>&1) || true
        printf '%s\n' "$out" | sed -n 's/^  HTTP\/[0-9.]* \([0-9][0-9][0-9]\).*/\1/p' | tail -1
    elif command -v curl >/dev/null 2>&1; then
        curl -sS -o /dev/null -w '%{http_code}' --max-time 20 \
            -A "${ua:-curl}" "$url" 2>/dev/null
    else
        printf 'no-http-client'
    fi
}

info ""
info "== archive connectivity (suite: $(printf '%s ' $suites)) =="
if [ -z "$uris" ]; then
    bad "cannot derive archive URIs"
else
    probes=0
    for uri in $uris; do
        for s in $suites; do
            [ "$probes" -ge 8 ] && break
            url="${uri%/}/dists/$s/InRelease"
            code=$(http_status "$url")
            case "$code" in
                2*|3*) pass "HTTP $code  $url" ;;
                *)     bad  "HTTP ${code:-000}  $url" ;;
            esac
            probes=$((probes + 1))
        done
    done
fi

if [ "$quick" = false ]; then
    info ""
    info "== isolated apt-get update =="
    tmp=$(mktemp -d)
    mkdir -p "$tmp/lists/partial" "$tmp/cache/archives/partial"
    if apt-get update \
        -o Dir::State::lists="$tmp/lists" \
        -o Dir::Cache="$tmp/cache" >"$tmp/update.log" 2>&1; then
        pass "apt-get update completed with isolated lists"
    else
        bad "apt-get update failed; errors:"
        grep -E '^(E:|Err:)' "$tmp/update.log" | tail -8
    fi
    rm -rf "$tmp"
fi

info ""
if [ "$fail" -eq 0 ]; then
    info "RESULT: PASS"
else
    info "RESULT: FAIL"
fi
exit "$fail"
