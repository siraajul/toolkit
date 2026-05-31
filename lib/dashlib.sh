#!/usr/bin/env bash
# dashlib.sh — shared hacker-dashboard library for CLI tools.
# Source it, register steps, call dash_run.
#
# Usage:
#   source ~/.local/share/dashlib/dashlib.sh
#   dash_init "TOOL.NAME"
#   add_step "PAYLOAD.NAME" function_name
#   add_skip "PAYLOAD.NAME" "reason"
#   dash_run

set -u

# ---------- colors / terminal ----------
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1 && [[ $(tput colors 2>/dev/null || echo 0) -ge 8 ]]; then
  TTY=1
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'
  BLUE=$'\033[34m'; MAGENTA=$'\033[35m'; CYAN=$'\033[36m'
else
  TTY=0
  BOLD=""; DIM=""; RESET=""
  RED=""; GREEN=""; YELLOW=""; BLUE=""; MAGENTA=""; CYAN=""
fi

COLS=80
recalc_cols() { COLS=$(tput cols 2>/dev/null || echo 80); }
recalc_cols
trap recalc_cols WINCH

# ---------- state ----------
FAILED=0
SUCCEEDED=(); SKIPPED=(); FAILED_STEPS=()
START_TIME=$(date +%s)
TOOL_NAME="DASH"
LOG_DIR="${HOME}/.local/state/dashlib"
LOG_FILE=""

# Step registry
STEP_LABELS=()
STEP_FUNCS=()
STEP_KIND=()
STEP_NOTE=()
TOTAL_PLANNED=0

# ---------- helpers ----------
have() { command -v "$1" >/dev/null 2>&1; }

fmt_duration() {
  local s=$1
  if   (( s < 60 ));   then printf "%ds" "$s"
  elif (( s < 3600 )); then printf "%dm%02ds" $((s/60)) $((s%60))
  else                      printf "%dh%02dm" $((s/3600)) $(((s%3600)/60)); fi
}

fmt_bytes() {
  local b=$1
  if   (( b < 1024 ));    then printf '%dB' "$b"
  elif (( b < 1048576 )); then printf '%dK' $(( b / 1024 ))
  else                         printf '%dM' $(( b / 1048576 )); fi
}

rand_hex() { printf '%04X' $(( (RANDOM ^ (RANDOM << 1)) & 0xFFFF )); }

# Strip ANSI escapes and control chars from input.
sanitize() {
  LC_ALL=C perl -pe '
    s/\e\[[0-9;?]*[A-Za-z]//g;
    s/\e\][^\a\e]*(?:\a|\e\\)//g;
    s/\e[\(\)][A-Za-z0-9]//g;
    tr/\x00-\x08\x0B-\x1F\x7F//d;
    s/\r//g;
  ' 2>/dev/null
}

# ---------- animations ----------
typewriter() {
  local text="$1" delay="${2:-0.005}"
  if (( TTY == 0 )); then printf '%s\n' "$text"; return; fi
  local i
  for (( i=0; i<${#text}; i++ )); do
    printf '%s' "${text:$i:1}"
    sleep "$delay"
  done
  printf '\n'
}

glitch_in() {
  (( TTY == 0 )) && { printf '%s\n' "$1"; return; }
  local target="$1" iters=8
  local pool='!@#$%^&*?<>{}[]|\/=+-_~01HXA8FZ'
  local i j out prob r ch
  for (( i=0; i<iters; i++ )); do
    out=""
    prob=$(( (iters - i) * 100 / iters ))
    for (( j=0; j<${#target}; j++ )); do
      ch="${target:$j:1}"
      if [[ "$ch" == " " ]]; then out+=" "; continue; fi
      if (( RANDOM % 100 < prob )); then
        r=$(( RANDOM % ${#pool} ))
        out+="${pool:$r:1}"
      else
        out+="$ch"
      fi
    done
    printf '\r%s%s%s' "$GREEN" "$out" "$RESET"
    sleep 0.04
  done
  printf '\r%s%s%s%s\n' "$BOLD" "$GREEN" "$target" "$RESET"
}

boot_sequence() {
  local pid=$$
  local a1 a2 a3; a1=$(rand_hex); a2=$(rand_hex); a3=$(rand_hex)
  local rows=(
    "0.001|kernel  |control transferred, pid=$pid|OK"
    "0.142|tty     |line discipline established|OK"
    "0.318|crypto  |handshake @ 0x${a1}${a2}|OK"
    "0.491|net     |routing sync · uplink 0x${a3}|OK"
    "0.612|loader  |${TOOL_NAME} payload ready|GO"
  )
  local r ts tag msg flag flagcolor
  for r in "${rows[@]}"; do
    IFS='|' read -r ts tag msg flag <<<"$r"
    if [[ "$flag" == "GO" ]]; then flagcolor="$BOLD$YELLOW"; else flagcolor="$GREEN"; fi
    printf '  %s[%s]%s %s%s%s :: %s %s[%s%s%s]%s\n' \
      "$DIM" "$ts" "$RESET" \
      "$GREEN" "$tag" "$RESET" \
      "$msg" \
      "$DIM" "$flagcolor" "$flag" "$DIM" "$RESET"
    sleep 0.08
  done
}

# 3-row block-letter font (A-Z + space + dot + dash). Each glyph 4 cells wide.
# Returns the row-th line (0..2) of the given char.
big_glyph() {
  local ch="$1" r="$2"
  case "$ch$r" in
    A0) echo "░█▀█" ;; A1) echo "░█▀█" ;; A2) echo "░▀░▀" ;;
    B0) echo "░█▀▄" ;; B1) echo "░█▀▄" ;; B2) echo "░▀▀░" ;;
    C0) echo "░█▀▀" ;; C1) echo "░█░░" ;; C2) echo "░▀▀▀" ;;
    D0) echo "░█▀▄" ;; D1) echo "░█░█" ;; D2) echo "░▀▀░" ;;
    E0) echo "░█▀▀" ;; E1) echo "░█▀▀" ;; E2) echo "░▀▀▀" ;;
    F0) echo "░█▀▀" ;; F1) echo "░█▀▀" ;; F2) echo "░▀░░" ;;
    G0) echo "░█▀▀" ;; G1) echo "░█▄█" ;; G2) echo "░▀▀▀" ;;
    H0) echo "░█░█" ;; H1) echo "░█▀█" ;; H2) echo "░▀░▀" ;;
    I0) echo "░▀█▀" ;; I1) echo "░░█░" ;; I2) echo "░▀▀▀" ;;
    J0) echo "░░░█" ;; J1) echo "░░░█" ;; J2) echo "░▀▀░" ;;
    K0) echo "░█░█" ;; K1) echo "░█▀▄" ;; K2) echo "░▀░▀" ;;
    L0) echo "░█░░" ;; L1) echo "░█░░" ;; L2) echo "░▀▀▀" ;;
    M0) echo "░█▄█" ;; M1) echo "░█▀█" ;; M2) echo "░▀░▀" ;;
    N0) echo "░█▄█" ;; N1) echo "░█░█" ;; N2) echo "░▀░▀" ;;
    O0) echo "░█▀█" ;; O1) echo "░█░█" ;; O2) echo "░▀▀▀" ;;
    P0) echo "░█▀█" ;; P1) echo "░█▀▀" ;; P2) echo "░▀░░" ;;
    Q0) echo "░█▀█" ;; Q1) echo "░█░█" ;; Q2) echo "░▀▀▄" ;;
    R0) echo "░█▀█" ;; R1) echo "░█▀▄" ;; R2) echo "░▀░▀" ;;
    S0) echo "░█▀▀" ;; S1) echo "░▀▀█" ;; S2) echo "░▀▀▀" ;;
    T0) echo "░▀█▀" ;; T1) echo "░░█░" ;; T2) echo "░░▀░" ;;
    U0) echo "░█░█" ;; U1) echo "░█░█" ;; U2) echo "░▀▀▀" ;;
    V0) echo "░█░█" ;; V1) echo "░█░█" ;; V2) echo "░░▀░" ;;
    W0) echo "░█░█" ;; W1) echo "░█▄█" ;; W2) echo "░▀░▀" ;;
    X0) echo "░█░█" ;; X1) echo "░░█░" ;; X2) echo "░▀░▀" ;;
    Y0) echo "░█░█" ;; Y1) echo "░░█░" ;; Y2) echo "░░▀░" ;;
    Z0) echo "░▀▀█" ;; Z1) echo "░░█░" ;; Z2) echo "░█▀▀" ;;
    .0) echo "░░░░" ;; .1) echo "░░░░" ;; .2) echo "░▄░░" ;;
    -0) echo "░░░░" ;; -1) echo "░▀▀▀" ;; -2) echo "░░░░" ;;
    " 0") echo "░░░░" ;; " 1") echo "░░░░" ;; " 2") echo "░░░░" ;;
    *0|*1|*2) echo "░░░░" ;;
  esac
}

# Render arbitrary uppercase text in the 3-row block font.
big_text() {
  local text upper i r row line ch
  text="$1"
  upper=$(printf '%s' "$text" | tr '[:lower:]' '[:upper:]')
  for r in 0 1 2; do
    line=""
    for (( i=0; i<${#upper}; i++ )); do
      ch="${upper:$i:1}"
      line+="$(big_glyph "$ch" "$r")"
    done
    printf '  %s%s%s\n' "$GREEN" "$line" "$RESET"
  done
}

intro_banner() {
  printf '\n'
  big_text "${TOOL_TITLE:-$TOOL_NAME}"
  printf '\n'
  printf '  '
  glitch_in "[ ${TOOL_NAME} :: $(date '+%Y-%m-%d %H:%M:%S') :: pid=$$ ]"
  printf '  %s↪ logstream → %s%s%s\n\n' "$DIM" "$GREEN" "$LOG_FILE" "$RESET"
  boot_sequence
  printf '\n'
}

# ---------- step registry ----------
add_step() { STEP_LABELS+=("$1"); STEP_FUNCS+=("$2"); STEP_KIND+=("run");  STEP_NOTE+=(""); }
add_skip() { STEP_LABELS+=("$1"); STEP_FUNCS+=("");   STEP_KIND+=("skip"); STEP_NOTE+=("$2"); }

# ---------- dashboard rendering ----------
SPINNER=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
COL_WIDTH=40
LEFT_CACHE=""

# Render a single cell. args: idx state icon info
render_cell() {
  local idx=$1 state=$2 icon=$3 info=$4
  local label="${STEP_LABELS[idx]}"
  local lc ic
  case "$state" in
    pending) lc="$DIM";        ic="$DIM" ;;
    running) lc="$BOLD$GREEN"; ic="$BOLD$YELLOW" ;;
    done)    lc="$GREEN";      ic="$GREEN" ;;
    fail)    lc="$RED";        ic="$BOLD$RED" ;;
    skip)    lc="$YELLOW";     ic="$YELLOW" ;;
  esac
  # Dynamic widths: 7 chars overhead (" NN " + " " + " " + " ICON"),
  # split remaining ~62% label / ~38% info.
  local total_inner=$(( COL_WIDTH - 7 ))
  local label_w=$(( total_inner * 62 / 100 ))
  local info_w=$(( total_inner - label_w ))
  (( label_w < 6 ))  && label_w=6
  (( info_w  < 8 ))  && info_w=8

  local short="${label:0:$label_w}"
  local info_trunc="${info:0:$info_w}"

  printf ' %s%02d%s %s%-*s%s %s%-*s%s %s%s%s' \
    "$DIM" "$((idx+1))" "$RESET" \
    "$lc" "$label_w" "$short" "$RESET" \
    "$DIM" "$info_w" "$info_trunc" "$RESET" \
    "$ic" "$icon" "$RESET"
}

# Helper to compute the info-field width from current COL_WIDTH.
info_width() {
  local total_inner=$(( COL_WIDTH - 7 ))
  local label_w=$(( total_inner * 62 / 100 ))
  local w=$(( total_inner - label_w ))
  (( w < 8 )) && w=8
  printf '%d' "$w"
}

info_for_running() { printf '0x%s %s' "$1" "$(fmt_bytes "$2")"; }
info_for_done_blocks() {
  local w; w=$(info_width)
  local s="" i; for ((i=0;i<w;i++)); do s+="█"; done
  printf '%s' "$s"
}
info_for_pending() {
  local w; w=$(info_width)
  local s="" i; for ((i=0;i<w;i++)); do s+="·"; done
  printf '%s' "$s"
}

finalize_cell() {
  local col_pos=$1 cell_text=$2
  if (( col_pos == 0 )); then
    printf '\r\033[2K%s' "$cell_text"
    LEFT_CACHE="$cell_text"
  else
    printf '\r\033[2K%s%s\n' "$LEFT_CACHE" "$cell_text"
    LEFT_CACHE=""
  fi
}

# Step functions call this to set the cell's info text.
# Works across the subshell boundary by writing to a file the parent reads.
set_result() {
  [[ -n "${STEP_RESULT_FILE:-}" ]] && printf '%s' "$1" >"$STEP_RESULT_FILE"
}

# Execute a step (skip or run) and update its cell.
run_step() {
  local idx=$1
  local col_pos=$(( idx % 2 ))
  local kind="${STEP_KIND[idx]}"
  local label="${STEP_LABELS[idx]}"

  if [[ "$kind" == "skip" ]]; then
    local note="${STEP_NOTE[idx]}"
    local cell_text
    cell_text=$(render_cell "$idx" "skip" "∙" "SKIP")
    SKIPPED+=("$label: $note")
    finalize_cell "$col_pos" "$cell_text"
    printf '>>> SKIP %s: %s\n' "$label" "$note" >> "$LOG_FILE"
    return
  fi

  local fn="${STEP_FUNCS[idx]}"
  local tmplog tmpresult
  tmplog=$(mktemp)
  tmpresult=$(mktemp)
  printf '>>> [%s] %s\n' "$label" "$fn" >> "$LOG_FILE"

  export STEP_RESULT_FILE="$tmpresult"
  "$fn" >"$tmplog" 2>&1 &
  local pid=$!

  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    local bytes; bytes=$(wc -c <"$tmplog" 2>/dev/null | tr -d ' '); bytes=${bytes:-0}
    local addr; addr=$(rand_hex)
    local info; info=$(info_for_running "$addr" "$bytes")
    local cell_text
    cell_text=$(render_cell "$idx" "running" "${SPINNER[i]}" "$info")
    if (( col_pos == 0 )); then
      printf '\r\033[2K%s' "$cell_text"
    else
      printf '\r\033[2K%s%s' "$LEFT_CACHE" "$cell_text"
    fi
    i=$(( (i+1) % ${#SPINNER[@]} ))
    sleep 0.1
  done

  wait "$pid"
  local rc=$?
  unset STEP_RESULT_FILE
  cat "$tmplog" >> "$LOG_FILE"

  local custom=""
  [[ -s "$tmpresult" ]] && custom=$(cat "$tmpresult")
  rm -f "$tmplog" "$tmpresult"

  local state icon info
  if (( rc == 0 )); then
    state="done"; icon="✓"
    if [[ -n "$custom" ]]; then info="$custom"; else info=$(info_for_done_blocks); fi
    SUCCEEDED+=("$label")
  elif (( rc == 2 )); then
    # rc=2 → not applicable / not installed / not configured (yellow skip)
    state="skip"; icon="∙"
    if [[ -n "$custom" ]]; then info="$custom"; else info="N/A"; fi
    SKIPPED+=("$label")
  else
    state="fail"; icon="✗"
    if [[ -n "$custom" ]]; then info="$custom"; else info="ERR rc=$rc"; fi
    FAILED=1
    FAILED_STEPS+=("$label")
  fi
  local cell_text
  cell_text=$(render_cell "$idx" "$state" "$icon" "$info")
  finalize_cell "$col_pos" "$cell_text"
}

# ---------- finale ----------
finale() {
  (( TTY == 0 )) && return
  printf '\n  '
  local msg="${1:->> ACCESS GRANTED <<}"
  glitch_in "$msg"
  local i
  for i in 1 2 3; do
    printf '\033[1A\r\033[2K  %s%s%s%s\n' "$BOLD" "$RED" "$msg" "$RESET"
    sleep 0.06
    printf '\033[1A\r\033[2K  %s%s%s%s\n' "$BOLD" "$GREEN" "$msg" "$RESET"
    sleep 0.06
  done
}

cleanup_dashboard() {
  printf '\r\033[2K'
  tput cnorm 2>/dev/null || true
}

# ---------- lifecycle ----------
# dash_init "TECH.TAG" ["DISPLAY TITLE"]
# TECH.TAG goes in boot log/sub-header; DISPLAY TITLE is the big banner text.
dash_init() {
  TOOL_NAME="$1"
  TOOL_TITLE="${2:-$1}"
  mkdir -p "$LOG_DIR"
  local slug; slug=$(echo "$TOOL_NAME" | tr '[:upper:].' '[:lower:]-')
  LOG_FILE="${LOG_DIR}/${slug}-$(date +%Y%m%d-%H%M%S).log"
  trap cleanup_dashboard EXIT INT TERM
}

dash_run() {
  TOTAL_PLANNED=${#STEP_LABELS[@]}
  intro_banner

  # Responsive 2-column layout. No upper cap — use the full terminal width.
  COL_WIDTH=$(( COLS / 2 ))
  (( COL_WIDTH < 30 )) && COL_WIDTH=30
  local grid_width=$(( COL_WIDTH * 2 ))
  local hr=""; local i
  for ((i=0; i<grid_width; i++)); do hr+="─"; done

  printf '%s%s%s\n' "$GREEN" "$hr" "$RESET"
  printf '%s ▸ %s%s     %s%d targets · log → %s%s\n' \
    "$BOLD$GREEN" "$TOOL_NAME" "$RESET" \
    "$DIM" "$TOTAL_PLANNED" "$(basename "$LOG_FILE")" "$RESET"
  printf '%s%s%s\n' "$GREEN" "$hr" "$RESET"

  (( TTY == 1 )) && tput civis 2>/dev/null

  local idx cell_text
  for ((idx=0; idx<TOTAL_PLANNED; idx++)); do
    cell_text=$(render_cell "$idx" "pending" "·" "$(info_for_pending)")
    if (( idx % 2 == 0 )); then printf '%s' "$cell_text"
    else                        printf '%s\n' "$cell_text"; fi
  done
  (( TOTAL_PLANNED % 2 == 1 )) && printf '\n'

  local grid_rows=$(( (TOTAL_PLANNED + 1) / 2 ))
  if (( TTY == 1 && grid_rows > 0 )); then
    printf '\033[%dA' "$grid_rows"
  fi

  for ((idx=0; idx<TOTAL_PLANNED; idx++)); do
    run_step "$idx"
  done
  (( TOTAL_PLANNED % 2 == 1 )) && printf '\n'

  (( TTY == 1 )) && tput cnorm 2>/dev/null

  printf '%s%s%s\n' "$GREEN" "$hr" "$RESET"
}

dash_summary() {
  local end_time; end_time=$(date +%s)
  local duration; duration=$(fmt_duration $((end_time - START_TIME)))

  printf '  %s[ %sok%s : %d ]   [ %sskip%s : %d ]   [ %sfail%s : %d ]     %selapsed %s%s\n' \
    "$DIM" "$GREEN"  "$DIM" "${#SUCCEEDED[@]}" \
    "$YELLOW" "$DIM" "${#SKIPPED[@]}" \
    "$RED"    "$DIM" "${#FAILED_STEPS[@]}" \
    "$DIM" "$duration" "$RESET"

  if (( ${#FAILED_STEPS[@]} > 0 )); then
    printf '  %s!! failed:%s' "$RED" "$RESET"
    local f
    for f in "${FAILED_STEPS[@]}"; do printf ' %s%s%s' "$RED" "$f" "$RESET"; done
    printf '\n'
  fi

  if (( FAILED == 0 )); then
    finale "${1:->> ACCESS GRANTED <<}"
  else
    printf '\n  %s%s>> SESSION TERMINATED — ERRORS DETECTED <<%s\n' "$BOLD" "$RED" "$RESET"
  fi
}
