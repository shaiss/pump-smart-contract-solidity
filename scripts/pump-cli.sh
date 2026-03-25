#!/usr/bin/env bash
# Menu-driven Pump CLI using charmbracelet/gum, or direct commands.
# Install: https://github.com/charmbracelet/gum  (brew install gum, etc.)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# First match for KEY in .env; strip quotes; skip comments. (Gum defaults used to ignore .env.)
dotenv_get() {
  local key="$1" f="$ROOT/.env" line k v
  [[ -f "$f" ]] || return 1
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" || "$line" == \#* ]] && continue
    [[ "$line" == *"="* ]] || continue
    k="${line%%=*}"
    v="${line#*=}"
    k="${k#"${k%%[![:space:]]*}"}"
    k="${k%"${k##*[![:space:]]}"}"
    v="${v#"${v%%[![:space:]]*}"}"
    v="${v%"${v##*[![:space:]]}"}"
    [[ "$k" == "$key" ]] || continue
    if [[ ${#v} -ge 2 ]]; then
      if [[ "${v:0:1}" == '"' && "${v: -1}" == '"' ]]; then v="${v:1:-1}"; fi
      if [[ "${v:0:1}" == "'" && "${v: -1}" == "'" ]]; then v="${v:1:-1}"; fi
    fi
    printf '%s' "$v"
    return 0
  done <"$f"
  return 1
}

launch_default() {
  local evar="$1" dkey="$2" fallback="$3" cur dv
  cur="${!evar-}"
  if [[ -n "$cur" ]]; then printf '%s' "$cur"; return; fi
  dv="$(dotenv_get "$dkey" 2>/dev/null)" || true
  if [[ -n "$dv" ]]; then printf '%s' "$dv"; return; fi
  printf '%s' "$fallback"
}

# 4-char ticker (ASCII A–Z / 0–9) from name; pad with X. No extra libs.
symbol_from_name() {
  local n="$1" u pad i
  u=$(printf '%s' "$n" | LC_ALL=C tr -cd 'A-Za-z0-9' | tr '[:lower:]' '[:upper:]')
  if [[ -z "$u" ]]; then printf '%s' 'TKN0'; return; fi
  if [[ ${#u} -ge 4 ]]; then printf '%s' "${u:0:4}"; return; fi
  pad=$((4 - ${#u}))
  printf '%s' "$u"
  for ((i = 0; i < pad; i++)); do printf X; done
}

require_gum() {
  command -v gum >/dev/null 2>&1 || {
    echo "Install gum: https://github.com/charmbracelet/gum" >&2
    exit 1
  }
}

RUNNER="$ROOT/scripts/run-hardhat.cjs"

hh_run() {
  local script="$1"
  shift
  if [[ $# -gt 0 ]]; then
    node "$RUNNER" run "$script" --network "${NETWORK:-leo}" -- "$@"
  else
    node "$RUNNER" run "$script" --network "${NETWORK:-leo}"
  fi
}

list_tokens_gum() {
  local tmp e o
  tmp="$(mktemp)"
  e="$(mktemp)"
  if ! PUMP_LIST_FORMAT=csv node "$RUNNER" run scripts/listTokens.ts --network "${NETWORK:-leo}" 1>"$tmp" 2>"$e"; then
    [[ -s "$e" ]] && cat "$e" >&2
    rm -f "$tmp" "$e"
    return 1
  fi
  [[ -s "$e" ]] && cat "$e" >&2
  o="$(tr -d '\r' <"$tmp")"
  rm -f "$tmp" "$e"
  o="${o#"${o%%[![:space:]]*}"}"
  o="${o%"${o##*[![:space:]]}"}"
  if [[ -z "$o" || "$o" == "token,name,symbol,creator" ]]; then
    gum style --foreground 240 "No TokenLaunched events for this factory."
    return 0
  fi
  # Without --print, gum table is an interactive picker ("1/2 navigate…"), not a static table.
  csvtmp="$(mktemp)"
  printf '%s\n' "$o" >"$csvtmp"
  if ! gum table --print --border rounded -f "$csvtmp"; then
    gum table --print -f "$csvtmp" || printf '%s\n' "$o"
  fi
  rm -f "$csvtmp"
}

show_help() {
  cat <<'EOF'
pump-cli.sh [command] [options]

  (no args)     Interactive gum menu
  deploy        Deploy factory
  launch        -n NAME -s SYMBOL [-b BUY_ETH]
  list          List TokenLaunched events
  sell          -t TOKEN -a AMOUNT_WEI

  NETWORK=leo   Override network (default leo)

Examples:
  ./scripts/pump-cli.sh launch -n "Meme" -s MEME -b 0
  node scripts/run-hardhat.cjs run scripts/launchToken.ts --network leo -- --name Meme --symbol MEME --buy 0.01
EOF
}

NETWORK="${NETWORK:-leo}"
CMD="${1:-menu}"
if [[ "$CMD" == "help" || "$CMD" == "-h" ]]; then
  show_help
  exit 0
fi

if [[ "$CMD" == "deploy" ]]; then
  hh_run scripts/deployLeo.ts
  exit 0
fi

if [[ "$CMD" == "list" ]]; then
  if command -v gum >/dev/null 2>&1; then
    list_tokens_gum || exit $?
  else
    hh_run scripts/listTokens.ts
  fi
  exit 0
fi

if [[ "$CMD" == "launch" ]]; then
  shift
  NAME=""
  SYMBOL=""
  BUY="0"
  BUY_FROM_FLAG=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -n|--name) NAME="$2"; shift 2 ;;
      -s|--symbol) SYMBOL="$2"; shift 2 ;;
      -b|--buy) BUY="$2"; BUY_FROM_FLAG=1; shift 2 ;;
      *) echo "Unknown arg: $1"; exit 1 ;;
    esac
  done
  PROMPTED=0
  if [[ -z "$NAME" ]]; then
    require_gum
    PROMPTED=1
    defn="$(launch_default TOKEN_NAME TOKEN_NAME 'My Meme')"
    NAME="$(gum input --placeholder 'Token name' --value "$defn")"
  fi
  if [[ -z "$SYMBOL" ]]; then
    sym="$(symbol_from_name "$NAME")"
    if [[ "$PROMPTED" -eq 1 ]]; then
      SYMBOL="$(gum input --placeholder 'Symbol (4 chars; from name)' --value "$sym")"
    else
      SYMBOL="$sym"
    fi
  fi
  if [[ "$PROMPTED" -eq 1 ]]; then
    defb="$(launch_default INITIAL_BUY_ETH INITIAL_BUY_ETH '0')"
    BUY="$(gum input --placeholder 'First buy: ETH decimal (0=none), not wei' --value "$defb")"
  elif [[ "$BUY_FROM_FLAG" -eq 0 ]]; then
    if [[ -n "${INITIAL_BUY_ETH:-}" ]]; then
      BUY="$INITIAL_BUY_ETH"
    else
      dv="$(dotenv_get INITIAL_BUY_ETH 2>/dev/null)" || true
      [[ -n "$dv" ]] && BUY="$dv"
    fi
  fi
  export TOKEN_NAME="$NAME"
  export TOKEN_SYMBOL="$SYMBOL"
  export INITIAL_BUY_ETH="$BUY"
  hh_run scripts/launchToken.ts
  exit 0
fi

if [[ "$CMD" == "sell" ]]; then
  shift
  TOKEN=""
  AMT=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -t|--token) TOKEN="$2"; shift 2 ;;
      -a|--amount) AMT="$2"; shift 2 ;;
      *) echo "Unknown arg: $1"; exit 1 ;;
    esac
  done
  if [[ -z "$TOKEN" || -z "$AMT" ]]; then
    require_gum
    [[ -n "$TOKEN" ]] || TOKEN="$(gum input --placeholder 'PumpToken address (0x...)')"
    [[ -n "$AMT" ]] || AMT="$(gum input --placeholder 'Amount (wei)' --value '1000000000000000000')"
  fi
  hh_run scripts/sellToken.ts --token "$TOKEN" --amount "$AMT"
  exit 0
fi

# menu
require_gum
while true; do
  gum style --foreground 212 --border double --padding "0 2" --margin "1" "Pump CLI (${NETWORK})"
  sel="$(gum choose --header "Choose an action" \
    "Deploy factory" \
    "Launch token" \
    "List tokens" \
    "Sell tokens" \
    "Help" \
    "Exit")"

  case "$sel" in
    "Deploy factory")
      hh_run scripts/deployLeo.ts
      ;;
    "Launch token")
      defn="$(launch_default TOKEN_NAME TOKEN_NAME 'My Meme')"
      defb="$(launch_default INITIAL_BUY_ETH INITIAL_BUY_ETH '0')"
      n="$(gum input --placeholder "Token name" --value "$defn")"
      s="$(gum input --placeholder "Symbol (4 chars; from name)" --value "$(symbol_from_name "$n")")"
      b="$(gum input --placeholder "First buy: ETH decimal (0=none), not wei" --value "$defb")"
      export TOKEN_NAME="$n" TOKEN_SYMBOL="$s" INITIAL_BUY_ETH="$b"
      hh_run scripts/launchToken.ts
      ;;
    "List tokens")
      list_tokens_gum
      ;;
    "Sell tokens")
      tok="$(gum input --placeholder "PumpToken address (0x...)")"
      amt="$(gum input --placeholder "Amount (wei)" --value "1000000000000000000")"
      hh_run scripts/sellToken.ts --token "$tok" --amount "$amt"
      ;;
    "Help")
      show_help
      ;;
    "Exit"|"")
      break
      ;;
  esac

  if [[ "$sel" != "Exit" && -n "$sel" ]]; then
    gum confirm "Back to menu?" || break
  fi
done
