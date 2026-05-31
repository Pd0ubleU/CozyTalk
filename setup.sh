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
fail() { printf "  ${RED}✗${RESET}  %b\n" "$*"; exit 1; }
step() { printf "\n${BOLD}${CYAN}  ▸ %b${RESET}\n" "$*"; }
info() { printf "  ${GRAY}  %b${RESET}\n" "$*"; }
warn() { printf "  ${YELLOW}⚠${RESET}  %b\n" "$*"; }

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

# ── Header ────────────────────────────────────────────────────────────────────
printf "\n"
printf "  ${MAGENTA}${BOLD}CozyTalk${RESET}  ${GRAY}·  project setup${RESET}\n"
printf "$HR\n"
printf "\n"

# ── Prerequisites ─────────────────────────────────────────────────────────────
step "Checking prerequisites"

require() {
  local cmd="$1" label="${2:-$1}" hint="${3:-}"
  if command -v "$cmd" &>/dev/null; then
    local ver
    ver="$("$cmd" --version 2>&1 | head -1)"
    ok "${label}  ${DIM}${ver}${RESET}"
  else
    fail "${label} not found${hint:+ — ${hint}}"
  fi
}

require flutter  "flutter"  "https://docs.flutter.dev/get-started/install"
DART_VER=$(dart --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
DART_MAJOR=$(printf '%s' "$DART_VER" | cut -d. -f1)
DART_MINOR=$(printf '%s' "$DART_VER" | cut -d. -f2)
if [[ "$DART_MAJOR" -lt 3 ]] || { [[ "$DART_MAJOR" -eq 3 ]] && [[ "$DART_MINOR" -lt 9 ]]; }; then
  fail "Dart $DART_VER is too old — sdk: ^3.9.0 required  ${DIM}(run: flutter upgrade)${RESET}"
fi

require node     "node"     "Install Node.js 23+ from https://nodejs.org"
NODE_MAJOR=$(node --version | grep -oE '^v[0-9]+' | tr -d 'v')
if [[ "$NODE_MAJOR" -lt 23 ]]; then
  warn "Node $NODE_MAJOR detected — project targets Node 23+ (package.json engines)"
  info "Upgrade: https://nodejs.org"
fi

require npm      "npm"

if command -v java &>/dev/null; then
  JAVA_VER_LINE=$(java -version 2>&1 | head -1)
  ok "java  ${DIM}${JAVA_VER_LINE}${RESET}"
  JAVA_MAJOR=$(printf '%s' "$JAVA_VER_LINE" | grep -oE '"[0-9]+' | tr -d '"' | head -1)
  [[ "$JAVA_MAJOR" -eq 1 ]] && JAVA_MAJOR=$(printf '%s' "$JAVA_VER_LINE" | grep -oE '"1\.[0-9]+' | cut -d. -f2)
  if [[ "$JAVA_MAJOR" -lt 21 ]]; then
    warn "Java $JAVA_MAJOR detected — Java 21+ required for Firebase emulators and Android builds"
    info "Install JDK 21+ from https://adoptium.net"
  fi
else
  warn "java not found — needed for Android builds and Firebase emulators"
  info "Install JDK 21+ from https://adoptium.net"
fi

if command -v firebase &>/dev/null; then
  ok "firebase  ${DIM}$(firebase --version 2>&1 | head -1)${RESET}"
else
  warn "firebase-tools not installed globally"
  info "Run:  npm install -g firebase-tools"
  info "(or the emulator will fall back to npx, which is slower)"
fi

# ── Flutter dependencies ──────────────────────────────────────────────────────
step "Flutter dependencies"
info "flutter pub get  →  apps/mobile"
(cd apps/mobile && flutter pub get)
ok "Flutter packages ready"

# ── Code generation ───────────────────────────────────────────────────────────
step "Code generation  ${DIM}(Freezed + Riverpod)${RESET}"
info "build_runner build  →  apps/mobile"
(cd apps/mobile && dart run build_runner build)
ok "Generated code up to date"

# ── Cloud Functions ───────────────────────────────────────────────────────────
step "Cloud Functions dependencies"
info "npm install  →  functions/"
(cd functions && npm install --silent)
ok "Node packages ready"

# ── .env ──────────────────────────────────────────────────────────────────────
step ".env"
if [[ ! -f apps/mobile/.env ]]; then
  cp apps/mobile/.env.example apps/mobile/.env
  ok "Created apps/mobile/.env  ${DIM}(USE_EMULATOR=true)${RESET}"
else
  ok "apps/mobile/.env already exists"
fi

# ── Git hooks ─────────────────────────────────────────────────────────────────
step "Git hooks"
git config core.hooksPath .githooks
ok "pre-commit hook active  ${DIM}(dart format + prettier auto-fix; dart analyze + eslint gate)${RESET}"
ok "pre-push hook active    ${DIM}(flutter test + functions lint + tsc)${RESET}"

# ── Done ──────────────────────────────────────────────────────────────────────
printf "\n$HR\n\n"
printf "  ${GREEN}${BOLD}Setup complete.${RESET}\n\n"
printf "  ${WHITE}${BOLD}What to do next${RESET}\n\n"
printf "  ${CYAN}▸${RESET}  ${BOLD}./dev.sh${RESET}              Emulators + Flutter on Android\n"
printf "  ${CYAN}▸${RESET}  ${BOLD}./dev.sh --web${RESET}        Emulators + Flutter on Chrome\n"
printf "  ${CYAN}▸${RESET}  ${BOLD}./dev.sh --prod${RESET}       Flutter → ${YELLOW}live${RESET} Firebase (Android)\n"
printf "  ${CYAN}▸${RESET}  ${BOLD}./dev.sh --prod --web${RESET} Flutter → ${YELLOW}live${RESET} Firebase (Chrome)\n"
printf "\n"
printf "  ${GRAY}Emulator UI  →  http://127.0.0.1:4000${RESET}\n"
printf "  ${GRAY}Auth :9099   Firestore :8080   Database :9000   Functions :5001${RESET}\n"
printf "\n"
