#!/usr/bin/env bash
set -euo pipefail

# ================= CONFIG =================
TARGET_URL="${1:-http://10.0.3.161/rest/user/login}"
OUTDIR="responses_$(date +%Y%m%d_%H%M%S)"
CSV="results_$(date +%Y%m%d_%H%M%S).csv"
TIMEOUT_SECONDS=10
# ==========================================

mkdir -p "$OUTDIR"
echo "case_id,case_name,http_code,bytes,url" > "$CSV"

# Generate long password safely
LONG_PW=$(python3 - <<'PY'
print("A"*129)
PY
)

# Test cases: name | JSON payload
cases=(
  "valid_string_pw|{\"email\":\"admin@juice-sh.op\",\"password\":\"123\"}"
  "invalid_pw_number|{\"email\":\"admin@juice-sh.op\",\"password\":123}"
  "invalid_pw_object|{\"email\":\"admin@juice-sh.op\",\"password\":{}}"
  "missing_password|{\"email\":\"admin@juice-sh.op\"}"
  "missing_email|{\"password\":\"123\"}"
  "empty_body|{}"
  "extra_field|{\"email\":\"admin@juice-sh.op\",\"password\":\"123\",\"extra\":\"x\"}"
  "email_too_short|{\"email\":\"a@\",\"password\":\"123\"}"
  "pw_empty_string|{\"email\":\"admin@juice-sh.op\",\"password\":\"\"}"
  "pw_too_long|{\"email\":\"admin@juice-sh.op\",\"password\":\"$LONG_PW\"}"
)

echo "[*] Target: $TARGET_URL"
echo "[*] Output dir: $OUTDIR"
echo "[*] CSV: $CSV"
echo

i=1
for entry in "${cases[@]}"; do
  case_name="${entry%%|*}"
  payload="${entry#*|}"
  outfile="$OUTDIR/case_${i}_${case_name}.txt"

  http_code=$(
    curl -i -sS -m "$TIMEOUT_SECONDS" \
      -H "Content-Type: application/json" \
      -X POST "$TARGET_URL" \
      -d "$payload" \
      -o "$outfile" \
      -w "%{http_code}"
  )

  bytes=$(wc -c < "$outfile")
  echo "$i,$case_name,$http_code,$bytes,$TARGET_URL" >> "$CSV"

  printf "[%02d] %-20s -> HTTP %s\n" "$i" "$case_name" "$http_code"
  ((i++))
done

echo
echo "[✓] Done. Evidence saved in $OUTDIR"
