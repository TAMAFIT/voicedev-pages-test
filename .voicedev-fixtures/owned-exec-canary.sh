#!/bin/sh
set -eu

if [ "${VOICEDEV_OWNED_EXEC_CANARY:-}" != "1" ]; then
  echo 'missing-canary-gate' >&2
  exit 20
fi

uid="$(id -u)"
if [ "$uid" != "65534" ]; then
  echo 'unexpected-uid' >&2
  exit 21
fi

if [ -e /var/run/docker.sock ]; then
  echo 'docker-socket-exposed' >&2
  exit 22
fi

network_names="$(ls -1 /sys/class/net 2>/dev/null | sort | tr '\n' ' ' | sed 's/ $//')"
if [ "$network_names" != "lo" ]; then
  echo 'unexpected-network' >&2
  exit 23
fi

cap_eff="$(awk '/^CapEff:/ {print $2}' /proc/self/status)"
if [ "$cap_eff" != "0000000000000000" ]; then
  echo 'capabilities-not-dropped' >&2
  exit 24
fi

no_new_privs="$(awk '/^NoNewPrivs:/ {print $2}' /proc/self/status)"
if [ "$no_new_privs" != "1" ]; then
  echo 'no-new-privileges-disabled' >&2
  exit 25
fi

seccomp="$(awk '/^Seccomp:/ {print $2}' /proc/self/status)"
if [ "$seccomp" != "2" ]; then
  echo 'seccomp-not-filtering' >&2
  exit 26
fi

if touch /candidate/.voicedev-write-probe 2>/dev/null; then
  rm -f /candidate/.voicedev-write-probe 2>/dev/null || true
  echo 'candidate-source-writable' >&2
  exit 27
fi

printf '%s\n' '{"ok":true,"fixture":"voicedev-owned-exec-v1","uid":65534,"network":"loopback-only","capEff":"0000000000000000","noNewPrivs":1,"seccomp":2,"sourceReadOnly":true}'
