# 1차 잠금

- 날짜: 2026-09-28
- HQ SHA: `c2e79ca` (kimjindol2025/bigwash-hq)
- tech SHA: `3febedf` (kimjindol2025/bigwash-tech)
- 기동 예: `[bigwash-hq] :30000`
- 기동 예: `[bigwash-tech] :30100 hq=http://127.0.0.1:30000`
- 30000이 사용 중이면 다음 빈 포트(`:30001` …). `HQ_PORT`를 지정했는데 사용 중이면 stderr `bind failed` 후 종료.
- 스위트: hq19 10 PASS, hq20 10 PASS, hq-money 14 PASS, tech accept 16 PASS. 기준 주소 `http://127.0.0.1:30000` / `http://127.0.0.1:30100`.

1차 잠금. 이후 기능 금지. 포트 3000 폐기.

빅워시 본사 1차 + 현장 1차는 잠긴다.
기본 포트 HQ 30000대, 현장 30100대.
3000은 쓰지 않는다.
다음 커밋은 버그·문서만. 기능 PR은 새 지시서가 있기 전 반려.
