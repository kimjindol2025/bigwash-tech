#!/usr/bin/env bash
# 직원 앱 1차 수락. HQ API + 화면 표식.
set -euo pipefail
HQ="${HQ_API:-http://127.0.0.1:3000}"
APP="${APP_URL:-http://127.0.0.1:3010}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0; FAIL=0
pass(){ echo "PASS  $1"; PASS=$((PASS+1)); }
fail(){ echo "FAIL  $1 — $2"; FAIL=$((FAIL+1)); }
j(){ python3 -c 'import json,sys; d=json.load(sys.stdin); '"$1"; }

echo "[tech] hq=$HQ app=$APP"
ADMIN=$(curl -sS -X POST "$HQ/hq/login" -H 'content-type: application/json' -d '{"login":"admin","password":"admin123"}')
ATOK=$(echo "$ADMIN" | j 'print(d["token"])')
AA="Authorization: Bearer $ATOK"

LOGIN="techapp_$RANDOM"
curl -sS -X POST "$HQ/hq/users" -H "$AA" -H 'content-type: application/json' \
  -d "{\"login\":\"$LOGIN\",\"name\":\"기사현장\",\"password\":\"field123\",\"role\":\"technician\"}" >/dev/null
TECH=$(curl -sS -X POST "$HQ/hq/login" -H 'content-type: application/json' -d "{\"login\":\"$LOGIN\",\"password\":\"field123\"}")
TTOK=$(echo "$TECH" | j 'print(d["token"])')
TUID=$(echo "$TECH" | j 'print(d["user"]["user_id"])')
TA="Authorization: Bearer $TTOK"

OTHER=$(curl -sS -X POST "$HQ/hq/users" -H "$AA" -H 'content-type: application/json' \
  -d "{\"login\":\"other_$RANDOM\",\"name\":\"다른기사\",\"password\":\"x\",\"role\":\"technician\"}" | j 'print(d["user_id"])')

PHONE="010-$(printf '%04d' $RANDOM)-$(printf '%04d' $RANDOM)"
CID=$(curl -sS -X POST "$HQ/hq/customers" -H "$AA" -H 'content-type: application/json' \
  -d "{\"type\":\"shop\",\"display_name\":\"현장고객\",\"primary_phone\":\"$PHONE\",\"address\":\"서울 송파\",\"visit_note\":\"지하주차\",\"hours_note\":\"9-6\"}" | j 'print(d["customer_id"])')
EID=$(curl -sS -X POST "$HQ/hq/equipment" -H "$AA" -H 'content-type: application/json' \
  -d "{\"customer_id\":\"$CID\",\"name\":\"세차기A\",\"location_note\":\"베이2\"}" | j 'print(d["equipment_id"])')
DAY=$(date +%F)
TID=$(curl -sS -X POST "$HQ/hq/tickets" -H "$AA" -H 'content-type: application/json' \
  -d "{\"customer_id\":\"$CID\",\"equipment_id\":\"$EID\",\"symptom\":\"물안나옴\",\"region_id\":\"reg-seoul-gangnam\",\"scheduled_at\":\"${DAY}T10:30\"}" | j 'print(d["ticket_id"])')
curl -sS -X POST "$HQ/hq/tickets/$TID/assignees" -H "$AA" -H 'content-type: application/json' \
  -d "{\"assignees\":[{\"kind\":\"staff\",\"user_id\":\"$TUID\",\"is_primary\":\"true\"}]}" >/dev/null
# 남의 건
TID2=$(curl -sS -X POST "$HQ/hq/tickets" -H "$AA" -H 'content-type: application/json' \
  -d "{\"customer_id\":\"$CID\",\"equipment_id\":\"$EID\",\"symptom\":\"남의건\",\"region_id\":\"reg-seoul-gangnam\",\"scheduled_at\":\"${DAY}T15:00\",\"assignee_id\":\"$OTHER\"}" | j 'print(d["ticket_id"])')

MINE=$(curl -sS "$HQ/hq/tickets?mine=1" -H "$TA")
echo "$MINE" | j "ids=[t['ticket_id'] for t in d]; assert '$TID' in ids and '$TID2' not in ids"
pass "1 tech sees only own today assignment"

# 화면 표식
HTML=$(curl -sS "$APP/")
printf '%s' "$HTML" > /tmp/tech-app.html
grep -F -q '용병' /tmp/tech-app.html && fail "2 no mercenary ui" "용병 문구" || pass "2 no mercenary signup"
grep -F -q '+ 출장' /tmp/tech-app.html && fail "11 no add trip" "button" || pass "11 no add-trip button"
grep -F -q 'id="dock"' /tmp/tech-app.html && grep -F -q 'position:fixed' /tmp/tech-app.html && pass "12 dock fixed" || fail "12 dock" "missing"
grep -F -q '방문메모' /tmp/tech-app.html && grep -F -q 'tel:' /tmp/tech-app.html && pass "3 detail fields in ui" || fail "3 detail" "missing"

# 동행 포함: 다른 주담당 + 나를 동행
curl -sS -X POST "$HQ/hq/tickets/$TID2/assignees" -H "$AA" -H 'content-type: application/json' \
  -d "{\"assignees\":[{\"kind\":\"staff\",\"user_id\":\"$OTHER\",\"is_primary\":\"true\"},{\"kind\":\"staff\",\"user_id\":\"$TUID\",\"is_primary\":\"false\"}]}" >/dev/null
MINE2=$(curl -sS "$HQ/hq/tickets?mine=1" -H "$TA")
echo "$MINE2" | j "assert any(t['ticket_id']=='$TID2' for t in d)"
pass "1b companion included"

B=$(curl -sS "$HQ/hq/tickets/$TID/bundle" -H "$TA")
echo "$B" | j "c=d['customer']; e=d['equipment']; assert c['address'] and c['primary_phone'] and '지하' in (c.get('visit_note') or '') and e['name']=='세차기A'"
pass "3 bundle address phone visit equipment"

# 남의 티켓 쓰기 403
CODE=$(curl -sS -o /dev/null -w "%{http_code}" -X POST "$HQ/hq/tickets/$TID2/log" -H "$TA" -H 'content-type: application/json' -d '{"memo":"훔치기"}')
# TID2 now includes tech as companion so write is allowed. Use a third ticket.
TID3=$(curl -sS -X POST "$HQ/hq/tickets" -H "$AA" -H 'content-type: application/json' \
  -d "{\"customer_id\":\"$CID\",\"equipment_id\":\"$EID\",\"symptom\":\"제3\",\"assignee_id\":\"$OTHER\"}" | j 'print(d["ticket_id"])')
CODE=$(curl -sS -o /dev/null -w "%{http_code}" -X POST "$HQ/hq/tickets/$TID3/log" -H "$TA" -H 'content-type: application/json' -d '{"memo":"훔치기"}')
test "$CODE" = "403" && pass "write other ticket 403" || fail "write other" "http $CODE"

P1=$(curl -sS -X POST "$HQ/hq/products" -H "$AA" -H 'content-type: application/json' -d '{"name":"노즐A","sale_price":5000,"category":"부품"}' | j 'print(d["product_id"])')
P2=$(curl -sS -X POST "$HQ/hq/products" -H "$AA" -H 'content-type: application/json' -d '{"name":"호스B","sale_price":7000,"category":"부품"}' | j 'print(d["product_id"])')
curl -sS -X POST "$HQ/hq/tickets/$TID/cart" -H "$TA" -H 'content-type: application/json' -d "{\"kind\":\"part\",\"product_id\":\"$P1\",\"qty\":1}" >/dev/null
curl -sS -X POST "$HQ/hq/tickets/$TID/cart" -H "$TA" -H 'content-type: application/json' -d "{\"kind\":\"part\",\"product_id\":\"$P2\",\"qty\":2}" >/dev/null
CART=$(curl -sS -X POST "$HQ/hq/tickets/$TID/cart/sync-travel" -H "$TA" -H 'content-type: application/json' -d '{}')
echo "$CART" | j 'parts=[x for x in d if x["kind"]=="part"]; trav=[x for x in d if x["kind"]=="travel"]; assert len(parts)>=2 and len(trav)==1'
# 기사가 출장비를 직접 담지 못함
CODET=$(curl -sS -o /dev/null -w "%{http_code}" -X POST "$HQ/hq/tickets/$TID/cart" -H "$TA" -H 'content-type: application/json' -d '{"kind":"travel","name":"가짜","price":1,"qty":1}')
test "$CODET" = "403" && pass "4 parts + auto travel, tech cannot set travel" || fail "4 travel guard" "http $CODET"

DOC=$(curl -sS -X POST "$HQ/hq/documents" -H "$TA" -H 'content-type: application/json' \
  -d "{\"ticket_id\":\"$TID\",\"doc_type\":\"invoice\",\"lines\":[{\"name\":\"노즐A\",\"qty\":1,\"price\":5000},{\"name\":\"호스B\",\"qty\":2,\"price\":7000}],\"labor_fee\":0,\"bill_type\":\"paid\"}")
DID=$(echo "$DOC" | j 'print(d["doc_id"])')
DL=$(curl -sS "$HQ/hq/documents/$DID/download" -H "$TA")
echo "$DL" | j 'assert d.get("pdf_base64","").startswith("JVBER") or len(d.get("pdf_base64") or "")>20; assert len(d.get("image_png_base64") or "")>20'
pass "5 pdf and png"

PNG="iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
for s in 1 2 3; do
  curl -sS -X POST "$HQ/hq/tickets/$TID/photos" -H "$TA" -H 'content-type: application/json' \
    -d "{\"side\":\"before\",\"slot\":$s,\"image_base64\":\"$PNG\",\"mime\":\"image/png\"}" >/dev/null
  curl -sS -X POST "$HQ/hq/tickets/$TID/photos" -H "$TA" -H 'content-type: application/json' \
    -d "{\"side\":\"after\",\"slot\":$s,\"image_base64\":\"$PNG\",\"mime\":\"image/png\"}" >/dev/null
done
curl -sS -X POST "$HQ/hq/tickets/$TID/log" -H "$TA" -H 'content-type: application/json' -d '{"memo":"필터 교체"}' >/dev/null
curl -sS -X POST "$HQ/hq/tickets/$TID/transition" -H "$TA" -H 'content-type: application/json' -d '{"to":"en_route","memo":"방문"}' >/dev/null
DONE=$(curl -sS -X POST "$HQ/hq/tickets/$TID/transition" -H "$TA" -H 'content-type: application/json' -d '{"to":"done","memo":"완료"}')
echo "$DONE" | j 'assert d["status"]=="done"'
pass "6 photos and done"

curl -sS -X POST "$HQ/hq/tickets/$TID/finance" -H "$TA" -H 'content-type: application/json' \
  -d '{"settlement_status":"미수","settlement_paid":0}' >/dev/null
UN=$(curl -sS "$HQ/hq/settlements?tab=unpaid" -H "$AA")
echo "$UN" | j "assert any(r.get('ticket_id')=='$TID' and r.get('settlement_status')=='미수' for r in d.get('rows',[]))"
pass "7 unpaid badge"

curl -sS -X POST "$HQ/hq/tickets/$TID/finance" -H "$TA" -H 'content-type: application/json' \
  -d '{"settlement_status":"카드완납","settlement_paid":19000,"settlement_method":"카드"}' >/dev/null
UN2=$(curl -sS "$HQ/hq/settlements?tab=unpaid" -H "$AA")
echo "$UN2" | j "assert not any(r.get('ticket_id')=='$TID' for r in d.get('rows',[]))"
pass "8 card paid leaves unpaid"

EXP=$(curl -sS -X POST "$HQ/hq/expenses" -H "$TA" -H 'content-type: application/json' \
  -d '{"amount":8000,"category":"식대","memo":"현장","receipt_note":"영수증"}')
EIDEXP=$(echo "$EXP" | j 'print(d["expense_id"])')
rm -f /tmp/bigwash-hq-dash-*.json
PEND=$(curl -sS "$HQ/hq/expenses" -H "$AA")
echo "$PEND" | j "assert any(e.get('expense_id')=='$EIDEXP' and e.get('status')=='pending' for e in d)"
pass "9 expense pending"

curl -sS -X POST "$HQ/hq/me/day-close" -H "$TA" -H 'content-type: application/json' \
  -d "{\"kind\":\"clock_out\",\"day\":\"$DAY\",\"note\":\"오늘 끝\"}" >/dev/null
DC=$(curl -sS "$HQ/hq/me/day-close" -H "$TA")
echo "$DC" | j "assert d['kind']=='clock_out' and d['user_id']=='$TUID'"
pass "10 clock_out received"

# 좁은 폭: 고정 하단이 문서에 있음
python3 - <<'PY'
from pathlib import Path
html=Path("/tmp/tech-app.html").read_text()
assert "position:fixed" in html and 'id="dock"' in html and "env(safe-area-inset-bottom)" in html
print("viewport dock css ok")
PY
pass "12b safe-area dock"

echo "---- $PASS passed, $FAIL failed ----"
test "$FAIL" = "0"
