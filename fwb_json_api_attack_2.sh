#!/usr/bin/env bash
set -euo pipefail

# ================= CONFIG =================
TARGET_URL="${1:-http://10.0.3.161/rest/user/login}"
OUTDIR="responses_$(date +%Y%m%d_%H%M%S)"
CSV="results_$(date +%Y%m%d_%H%M%S).csv"
TIMEOUT_SECONDS=10
# =========================================

mkdir -p "$OUTDIR"
echo "case_id,case_name,http_code,bytes,url" > "$CSV"

# Generate long password safely (boundary test)
LONG_PW=$(python3 - <<'PY'
print("A"*129)
PY
)

# Test cases: name | JSON payload
cases=(
  # ---- Baseline / original ----
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

  # ---- Type confusion (advanced) ----
  "pw_null|{\"email\":\"admin@juice-sh.op\",\"password\":null}"
  "pw_boolean|{\"email\":\"admin@juice-sh.op\",\"password\":true}"
  "pw_array|{\"email\":\"admin@juice-sh.op\",\"password\":[\"123\"]}"
  "pw_nested_object|{\"email\":\"admin@juice-sh.op\",\"password\":{\"value\":\"123\"}}"

  # ---- Unicode / control characters ----
  "pw_zero_width|{\"email\":\"admin@juice-sh.op\",\"password\":\"123\u200b\"}"
  "pw_control_char|{\"email\":\"admin@juice-sh.op\",\"password\":\"123\n\"}"

  # ---- Mass assignment / extra property guessing ----
  "role_injection|{\"email\":\"admin@juice-sh.op\",\"password\":\"123\",\"role\":\"admin\"}"
  "isadmin_injection|{\"email\":\"admin@juice-sh.op\",\"password\":\"123\",\"isAdmin\":true}"

  # ---- Email edge cases ----
  "email_null|{\"email\":null,\"password\":\"123\"}"
  "email_empty|{\"email\":\"\",\"password\":\"123\"}"
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

  printf "[%02d] %-22s -> HTTP %s\n" "$i" "$case_name" "$http_code"
  ((i++))
done

echo
echo "[✓] Done. Evidence saved in $OUTDIR"
echo "[✓] Results CSV: $CSV"
