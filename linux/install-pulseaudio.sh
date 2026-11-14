#!/usr/bin/env bash
set -Eeuo pipefail
name=wfs-linux-webtop
case "${WFS_DISTRO:-debian}" in
  debian|ubuntu)
    docker exec -u 0 "$name" bash -lc 'apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends pulseaudio pulseaudio-utils'
    ;;
  fedora)
    docker exec -u 0 "$name" bash -lc 'dnf install -y pulseaudio pulseaudio-utils'
    ;;
  arch)
    docker exec -u 0 "$name" bash -lc 'pacman -Sy --needed --noconfirm pulseaudio'
    ;;
  alpine)
    docker exec -u 0 "$name" sh -lc 'apk add --no-cache pulseaudio pulseaudio-utils'
    ;;
  *) echo "::error::Unsupported distro for PulseAudio."; exit 1 ;;
esac

# The Webtop desktop user is abc; keep the PulseAudio socket inside the container.
docker exec -u 0 "$name" bash -lc 'mkdir -p /tmp/pulse-runtime && chown abc:abc /tmp/pulse-runtime && chmod 700 /tmp/pulse-runtime'
docker exec -u abc "$name" bash -lc '
  export XDG_RUNTIME_DIR=/tmp/pulse-runtime
  export PULSE_RUNTIME_PATH=/tmp/pulse-runtime
  pulseaudio --kill >/dev/null 2>&1 || true
  pulseaudio --daemonize=yes --exit-idle-time=-1 \
    --load="module-native-protocol-unix socket=/tmp/pulse-runtime/native auth-anonymous=1" \
    --load="module-null-sink sink_name=remote_audio sink_properties=device.description=RemoteAudio"
'
docker exec -u abc "$name" bash -lc '
  export PULSE_SERVER=unix:/tmp/pulse-runtime/native
  for n in 1 2 3 4 5; do
    pactl info >/dev/null 2>&1 && exit 0
    sleep 2
  done
  pactl info
'
echo "[PulseAudio] Virtual output and native socket verified."
