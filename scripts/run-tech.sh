#!/usr/bin/env bash
# 현장. 기본 40000. TECH_PORT가 있으면 그 포트만. 없으면 40000–49999.
# HQ_API 없으면 http://127.0.0.1:30000 을 확인하고, 없으면 종료한다.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cli_tech="${TECH_PORT:-}"
unset PORT
if [[ -n "$cli_tech" ]]; then
  TECH_PORT="$cli_tech"
fi

port_free() {
  python3 -c 'import socket,sys
p=int(sys.argv[1])
s=socket.socket()
try:
    s.bind(("0.0.0.0", p))
except OSError:
    sys.exit(1)
s.close()' "$1"
}

if [[ -n "${TECH_PORT:-}" ]]; then
  if ! port_free "$TECH_PORT"; then
    echo "[bigwash-tech] bind failed :${TECH_PORT} in use" >&2
    exit 1
  fi
  chosen="$TECH_PORT"
else
  chosen=""
  busy=""
  for p in $(seq 40000 49999); do
    if port_free "$p"; then
      chosen="$p"
      break
    fi
    busy="${busy} ${p}"
  done
  if [[ -z "$chosen" ]]; then
    echo "[bigwash-tech] no free port in 40000-49999. in use:${busy}" >&2
    exit 1
  fi
fi

export TECH_PORT="$chosen"
export PORT="$chosen"
export HQ_API="${HQ_API:-http://127.0.0.1:30000}"

if ! curl -fsS -m 3 "${HQ_API}/health" >/dev/null; then
  echo "[bigwash-tech] HQ에 연결하지 못했습니다: ${HQ_API}" >&2
  echo "[bigwash-tech] 본사를 먼저 띄우거나 HQ_API를 실제 주소로 지정하세요." >&2
  exit 1
fi

cd "$ROOT"
exec node server.js
