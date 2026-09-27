#!/usr/bin/env bash
# 2차 현장: 오늘 목록, 출장 추가 버튼 없음, 뱃지, 하단 고정, 사진 경고
set -euo pipefail
HQ="${HQ_API:-${HQ_BASE:-http://127.0.0.1:30000}}"
APP="${TECH_BASE:-${APP_URL:-http://127.0.0.1:40000}}"
PASS=0; FAIL=0
pass(){ echo "PASS  $1"; PASS=$((PASS+1)); }
fail(){ echo "FAIL  $1 — $2"; FAIL=$((FAIL+1)); }
j(){ python3 -c 'import json,sys; d=json.load(sys.stdin); '"$1"; }

echo "[tech-phase2] hq=$HQ app=$APP"
TOK=$(curl -sS -X POST "$HQ/hq/login" -H 'content-type: application/json' -d '{"login":"admin","password":"admin123"}' | j 'print(d["token"])')
CODE=$(curl -sS -o /tmp/tech-mine.json -w "%{http_code}" "$HQ/hq/tickets?mine=1" -H "Authorization: Bearer $TOK")
test "$CODE" = "200" && pass "4 today mine list 200" || fail "4 mine" "http $CODE"

HTML=$(curl -sS "$APP/")
printf '%s' "$HTML" > /tmp/tech-phase2.html
grep -F -q '+출장' /tmp/tech-phase2.html && fail "4 no add trip" "found" || pass "4 no +출장"
grep -F -q 'id="dock"' /tmp/tech-phase2.html && grep -F -q 'position:fixed' /tmp/tech-phase2.html && pass "5 dock stays fixed" || fail "5 dock" "missing"
grep -F -q 'id="photoWarn"' /tmp/tech-phase2.html && pass "photo warning is on screen" || fail "photo warning" "missing"
grep -F -q 'slice(0, 20)' /tmp/tech-phase2.html && pass "address 20 chars" || fail "address" "missing"
grep -F -q '>동행<' /tmp/tech-phase2.html && pass "companion label" || fail "companion" "missing"
for s in 카드완납 계좌완납 현금완납 부분수금 미수 해당없음; do
  grep -F -q "$s" /tmp/tech-phase2.html || { fail "5 badge $s" "missing"; exit 1; }
done
pass "5 six settlement labels"

echo "---- $PASS passed, $FAIL failed ----"
test "$FAIL" = "0"
