#!/usr/bin/env bash
set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[38;5;82m'
CYAN='\033[38;5;39m'
YELLOW='\033[38;5;220m'
RED='\033[38;5;196m'
MAGENTA='\033[38;5;171m'
GRAY='\033[38;5;245m'
WHITE='\033[38;5;255m'

HR="${GRAY}$(printf '─%.0s' $(seq 1 60))${RESET}"

ok()   { printf "  ${GREEN}✓${RESET}  %b\n" "$*"; }
fail() { printf "  ${RED}✗${RESET}  %b\n" "$*" >&2; exit 1; }
info() { printf "  ${GRAY}  %b${RESET}\n" "$*"; }
log()  { printf "  ${CYAN}▸${RESET}  %b\n" "$*"; }
warn() { printf "  ${YELLOW}⚠${RESET}  %b\n" "$*"; }

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

# ── Args ──────────────────────────────────────────────────────────────────────
USE_PROD=false
USE_WEB=false
EMULATOR_ONLY=false

for arg in "$@"; do
  case "$arg" in
    --prod)          USE_PROD=true ;;
    --web)           USE_WEB=true ;;
    --emulator-only) EMULATOR_ONLY=true ;;
    --help|-h)
      printf "\n${BOLD}Usage:${RESET} ./dev.sh [--prod] [--web] [--emulator-only]\n\n"
      printf "  ${BOLD}--prod${RESET}           Connect to live Firebase instead of local emulators\n"
      printf "  ${BOLD}--web${RESET}            Run on Chrome instead of Android\n"
      printf "  ${BOLD}--emulator-only${RESET}  Start Firebase emulators only — no Flutter (for integration tests)\n\n"
      printf "  ${GRAY}Without flags: emulator mode, Flutter will ask which device${RESET}\n\n"
      exit 0
      ;;
    *)
      fail "Unknown argument: ${arg}  (try --help)"
      ;;
  esac
done

if $EMULATOR_ONLY && $USE_PROD; then
  fail "--emulator-only and --prod are mutually exclusive"
fi

# ── Header ────────────────────────────────────────────────────────────────────
printf "\n"
printf "  ${MAGENTA}${BOLD}CozyTalk${RESET}  ${GRAY}·  dev runner${RESET}\n"
printf "$HR\n\n"

# ── Mode summary ──────────────────────────────────────────────────────────────
if $EMULATOR_ONLY; then
  PLATFORM="none (emulator-only)"
elif $USE_WEB; then
  PLATFORM="Chrome"
else
  PLATFORM="auto-detect"
fi

if $USE_PROD; then
  BACKEND="${YELLOW}Production Firebase${RESET}"
else
  BACKEND="${CYAN}Local emulators${RESET}"
fi

printf "  ${GRAY}Platform${RESET}  ${BOLD}${PLATFORM}${RESET}\n"
printf "  ${GRAY}Backend ${RESET}  ${BACKEND}\n"
printf "\n"

if $USE_PROD; then
  warn "You are connecting to ${YELLOW}${BOLD}live Firebase${RESET} — real data, real users."
  printf "\n"
fi

# ── Vertex AI credentials check ───────────────────────────────────────────────
if ! $USE_PROD; then
  ADC_FILE="${HOME}/.config/gcloud/application_default_credentials.json"
  if ! command -v gcloud &>/dev/null || [[ ! -f "$ADC_FILE" ]]; then
    warn "Vertex AI ADC not found — interest matching degrades to random matching."
    info "Run once: ${BOLD}gcloud auth application-default login${RESET}"
    printf "\n"
  else
    ok "Vertex AI ADC ready — interest matching enabled"
    printf "\n"
  fi
fi

# ── Load .env from apps/mobile ────────────────────────────────────────────────
ENV_FILE="$ROOT_DIR/apps/mobile/.env"
ENV_EXAMPLE="$ROOT_DIR/apps/mobile/.env.example"

if [[ ! -f "$ENV_FILE" ]]; then
  if [[ -f "$ENV_EXAMPLE" ]]; then
    cp "$ENV_EXAMPLE" "$ENV_FILE"
    warn "apps/mobile/.env not found — created from .env.example"
    info "Open ${BOLD}apps/mobile/.env${RESET} and set your ${BOLD}GIPHY_API_KEY${RESET}, then re-run."
    printf "\n"
  fi
fi

if [[ -f "$ENV_FILE" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^\s*# ]] && continue
    [[ "$line" =~ ^\s*$ ]] && continue
    if [[ "$line" =~ ^([A-Z_]+)=(.*)$ ]]; then
      k="${BASH_REMATCH[1]}"
      v="${BASH_REMATCH[2]}"
      [[ -z "${!k:-}" ]] && export "$k=$v"
    fi
  done < "$ENV_FILE"
fi

if [[ -z "${GIPHY_API_KEY:-}" ]]; then
  warn "GIPHY_API_KEY is not set — GIF picker will be disabled."
  info "Get a key at ${BOLD}https://developers.giphy.com/${RESET} and add it to ${BOLD}apps/mobile/.env${RESET}"
  printf "\n"
fi

# ── Build Flutter args ────────────────────────────────────────────────────────
FLUTTER_ARGS=()
$USE_WEB  && FLUTTER_ARGS+=("-d" "chrome")
$USE_PROD && FLUTTER_ARGS+=("--dart-define=USE_EMULATOR=false")
[[ -n "${GIPHY_API_KEY:-}" ]] && FLUTTER_ARGS+=("--dart-define=GIPHY_API_KEY=$GIPHY_API_KEY")

# ── Emulator startup ──────────────────────────────────────────────────────────
EMULATOR_PID=""
LOG_FILE=""

cleanup() {
  local code=$?
  if [[ -n "$EMULATOR_PID" ]]; then
    printf "\n\n  ${GRAY}Stopping emulators…${RESET}\n"
    kill "$EMULATOR_PID" 2>/dev/null || true
    wait "$EMULATOR_PID" 2>/dev/null || true
  elif $EMULATOR_ONLY; then
    printf "\n\n  ${GRAY}Stopping emulators…${RESET}\n"
    for port in 9099 8080 9000 5001 8085 4000 4400 4500; do
      pids=$(lsof -ti:$port 2>/dev/null) && kill $pids 2>/dev/null || true
    done
  fi
  if [[ -n "$LOG_FILE" ]]; then
    printf "  ${GRAY}Session log saved → ${BOLD}${LOG_FILE}${RESET}\n"
    printf "  ${GRAY}Run ${BOLD}./logs.sh${RESET}${GRAY} to view.${RESET}\n"
  fi
  printf "  ${GRAY}Done.${RESET}\n\n"
  exit "$code"
}

# Returns 0 if all four emulator ports are already accepting connections.
emulators_already_up() {
  for port in 9099 8080 9000 5001 8085; do
    (echo > /dev/tcp/localhost/$port) 2>/dev/null || return 1
  done
  return 0
}

if ! $USE_PROD; then
  trap cleanup EXIT INT TERM

  MAX_WAIT=90

  wait_for_port() {
    local name="$1" port="$2" elapsed=0
    printf "  ${GRAY}Waiting for ${name} emulator on :${port}${RESET}"
    while ! (echo > /dev/tcp/localhost/$port) 2>/dev/null; do
      printf "${GRAY}.${RESET}"
      sleep 1
      elapsed=$((elapsed + 1))
      if [[ $elapsed -ge $MAX_WAIT ]]; then
        printf "\n\n"
        printf "  ${RED}✗${RESET}  ${name} emulator didn't respond after ${MAX_WAIT}s.\n"
        if [[ -n "$LOG_FILE" ]]; then
          printf "  ${GRAY}  Last log lines:${RESET}\n\n"
          tail -20 "$LOG_FILE" | sed 's/^/    /'
        fi
        printf "\n"
        exit 1
      fi
      # Only check for process death when this terminal owns the emulators.
      if [[ -n "$EMULATOR_PID" ]] && ! kill -0 "$EMULATOR_PID" 2>/dev/null; then
        printf "\n\n"
        printf "  ${RED}✗${RESET}  Emulator process exited unexpectedly.\n"
        printf "  ${GRAY}  Last log lines:${RESET}\n\n"
        tail -20 "$LOG_FILE" | sed 's/^/    /'
        printf "\n"
        exit 1
      fi
    done
    printf " ${GREEN}ready${RESET}\n"
  }

  if emulators_already_up; then
    # ── Attach mode ────────────────────────────────────────────────────────
    # Another terminal already owns the emulators — just connect to them.
    # Do NOT kill ports or restart anything.
    ok "Emulators already running — attaching"
    info "Emulator UI → ${BOLD}http://127.0.0.1:4000${RESET}"
    printf "\n$HR\n"
  else
    # ── Owner mode ─────────────────────────────────────────────────────────
    # No emulators detected — this terminal will start and own them.

    # Kill any stale emulator processes left over from a previous crashed run.
    for port in 9099 8080 9000 5001 8085 4000 4400 4500; do
      pids=$(lsof -ti:$port 2>/dev/null) && kill $pids 2>/dev/null || true
    done

    # Set up persistent log directory and timestamped session file.
    mkdir -p "$ROOT_DIR/logs"
    LOG_FILE="$ROOT_DIR/logs/emulator-$(date +%Y-%m-%d_%H-%M-%S).log"

    # Rotate: keep last 10 emulator session logs.
    ls -t "$ROOT_DIR/logs"/emulator-20*.log 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true

    # Build functions before starting emulators.
    log "Building Cloud Functions…"
    if ! (cd "$ROOT_DIR/functions" && npm run build) >> "$LOG_FILE" 2>&1; then
      printf "\n  ${RED}✗${RESET}  Build failed. Last log:\n\n"
      tail -20 "$LOG_FILE" | sed 's/^/    /'
      printf "\n"
      exit 1
    fi
    ok "Functions built"

    log "Starting Firebase emulators…"
    info "Session log → ${BOLD}${LOG_FILE}${RESET}"
    info "Emulator UI → ${BOLD}http://127.0.0.1:4000${RESET}  (Logs tab = real-time function output)"
    info "Tip         → ${BOLD}./logs.sh -f${RESET}  to follow logs in another terminal"
    printf "\n"

    # Run emulators from project root (firebase.json is here; debug logs land here too).
    firebase emulators:start --only functions,auth,firestore,database,pubsub >> "$LOG_FILE" 2>&1 &
    EMULATOR_PID=$!

    # Keep a stable "latest" symlink for scripts and editors.
    (cd "$ROOT_DIR/logs" && ln -sf "$(basename "$LOG_FILE")" emulator-latest.log)

    wait_for_port "auth"      9099
    wait_for_port "database"  9000
    wait_for_port "firestore" 8080
    wait_for_port "functions" 5001
    wait_for_port "pubsub"    8085
    ok "Emulator UI → http://127.0.0.1:4000"
    printf "\n$HR\n"
  fi
fi

# ── Java compatibility guard (Android/Gradle only) ───────────────────────────
# Kotlin 2.1.0 (bundled in Gradle 8.x) can't parse Java 22+ version strings.
# If the active JDK is too new, find the highest installed version that's ≤ 21.
if ! $USE_WEB && ! $EMULATOR_ONLY && command -v java &>/dev/null; then
  _ver=$(java -version 2>&1 | awk -F '"' 'NR==1 {split($2,a,"."); print (a[1]=="1"?a[2]:a[1])}')
  if [[ "$_ver" =~ ^[0-9]+$ ]] && (( _ver > 21 )); then
    _candidate=""
    if [[ "$(uname)" == "Darwin" ]]; then
      for _v in 21 20 19 18 17 16 15 14 13 12 11; do
        _candidate=$(/usr/libexec/java_home -v "$_v" 2>/dev/null) && break
      done
    fi
    if [[ -z "$_candidate" ]]; then
      # Try explicit versioned paths in descending order (portable — no sort -V needed)
      for _v in 21 20 19 18 17 16 15 14 13 12 11; do
        for _dir in \
          "/usr/lib/jvm/java-${_v}-openjdk" \
          "/usr/lib/jvm/java-${_v}-openjdk-amd64" \
          "/usr/lib/jvm/java-${_v}-openjdk-arm64" \
          "/usr/lib/jvm/java-${_v}" \
          "/usr/lib/jvm/temurin-${_v}" \
          "/usr/local/lib/jvm/java-${_v}"; do
          [[ -x "${_dir}/bin/java" ]] && _candidate="$_dir" && break 2
        done
      done
    fi
    if [[ -z "$_candidate" ]]; then
      fail "Java ${_ver} is not supported by the Kotlin Gradle plugin (max: 21).\nInstall any JDK between 11 and 21 and re-run, or set JAVA_HOME manually."
    fi
    export JAVA_HOME="$_candidate"
    warn "Java ${_ver} detected — using ${_candidate} for Gradle"
    printf "\n"
  fi
fi

# ── Flutter ───────────────────────────────────────────────────────────────────
if $EMULATOR_ONLY; then
  printf "\n"
  ok "Emulators ready"
  info "Example: cd functions && npm test"
  printf "\n$HR\n\n"
  printf "  ${GRAY}Press Ctrl+C to stop emulators.${RESET}\n\n"
  if [[ -n "$EMULATOR_PID" ]]; then
    wait "$EMULATOR_PID"
  else
    # Emulators were already running before this session; just sleep until Ctrl+C.
    sleep infinity
  fi
else
  printf "\n"
  log "Starting Flutter${USE_WEB:+ on Chrome}…"
  printf "\n$HR\n\n"

  (cd apps/mobile && flutter run "${FLUTTER_ARGS[@]}")
fi
