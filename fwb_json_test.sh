#!/usr/bin/env bash
set -euo pipefail

# ========= CONFIG =========
TARGET_URL="${1:-http://10.0.3.161/rest/user/login}"
OUTDIR="responses_$(date +%Y%m%d_%H%M%S)"
CSV="results_$(date +%Y%m%d_%H%M%S).csv"
TIMEOUT_SECONDS=10
# ==========================

mkdir -p "$OUTDIR"
echo "case_id,case_name,http_code,bytes,url" > "$CSV"

# Each test case: name | JSON payload
# Note: keep JSON in single line to avoid quoting headaches.
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
  "pw_too_long|{\"email\":\"admin@juice-sh.op\",\"password\":\"$(python3 - <<'PY'\nprint('A'*129)\nPY)\"}"
)

echo "[*] Target: $TARGET_URL"
echo "[*] Output dir: $OUTDIR"
echo "[*] CSV: $CSV"
echo

i=1
for entry in "${cases[@]}"; do
  case_name="${entry%%|*}"
  payload="${entry#*|}"

  outfile="$OUTDIR/case${i}_${case_name}.txt"

  # -i includes headers, -s silent, -S show errors, -m max time
  # We capture HTTP code and bytes reliably.
  # We write full response (headers+body) to outfile for evidence.
  http_code="$(
    curl -i -sS -m "$TIMEOUT_SECONDS" \
      -H "Content-Type: application/json" \
      -X POST "$TARGET_URL" \
      -d "$payload" \
      -o "$outfile" \
      -w "%{http_code}"
  )"

  bytes="$(wc -c < "$outfile" | tr -d ' ')"

  # Print compact live status line
  printf "[%02d] %-18s -> HTTP %s (%s bytes)\n" "$i" "$case_name" "$http_code" "$bytes"

  # Append CSV row
  echo "${i},${case_name},${http_code},${bytes},${TARGET_URL}" >> "$CSV"

  i=$((i+1))
done

echo
echo "[+] Done."
echo "[+] Summary CSV: $CSV"
echo "[+] Full responses saved in: $OUTDIR"
echo
echo "Tip: grep FortiWeb block keywords quickly:"
echo "  grep -R \"Web Page Blocked\\|Attack ID\\|The URL you requested has been blocked\" -n \"$OUTDIR\" || true"
