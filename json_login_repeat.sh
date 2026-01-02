#!/usr/bin/env bash
set -euo pipefail

# ================= CONFIG =================
TARGET_URL="http://10.0.3.161/rest/user/login"
ATTEMPTS=50           # number of requests
DELAY=0.2             # seconds between requests
OUTDIR="repeat_responses_$(date +%Y%m%d_%H%M%S)"
CSV="repeat_results_$(date +%Y%m%d_%H%M%S).csv"
# =========================================

mkdir -p "$OUTDIR"
echo "attempt,http_code,bytes" > "$CSV"

PAYLOAD='{"email":"admin@juice-sh.op","password":"wrongpassword"}'

echo "[*] Target: $TARGET_URL"
echo "[*] Attempts: $ATTEMPTS"
echo "[*] Delay: ${DELAY}s"
echo

for i in $(seq 1 "$ATTEMPTS"); do
  outfile="$OUTDIR/attempt_${i}.txt"

  http_code=$(
    curl -sS -m 10 \
      -H "Content-Type: application/json" \
      -X POST "$TARGET_URL" \
      -d "$PAYLOAD" \
      -o "$outfile" \
      -w "%{http_code}"
  )

  bytes=$(wc -c < "$outfile")
  echo "$i,$http_code,$bytes" >> "$CSV"

  printf "[%02d] HTTP %s\n" "$i" "$http_code"
  sleep "$DELAY"
done

echo
echo "[✓] Done."
echo "[✓] Responses saved in: $OUTDIR"
echo "[✓] CSV: $CSV"
