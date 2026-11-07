#!/usr/bin/env bash
# Claude Code status line: model, context, session (5h) and weekly (7d) usage, session cost.
input=$(cat)

R=$'\e[0m'; DIM=$'\e[2m'; BOLD=$'\e[1m'
CYAN=$'\e[36m'; GREEN=$'\e[32m'; YELLOW=$'\e[33m'; RED=$'\e[31m'
SEP=" ${DIM}|${R} "

j() { jq -r "$1 // empty" <<<"$input"; }

color_for() {  # percent -> color by severity
  local p=${1%.*}
  if   [ "$p" -ge 90 ]; then printf '%s' "$RED"
  elif [ "$p" -ge 70 ]; then printf '%s' "$YELLOW"
  else printf '%s' "$GREEN"; fi
}

bar() {  # percent -> 8-cell bar
  local p=${1%.*} n i out=""
  n=$(( (p * 8 + 50) / 100 )); [ "$n" -gt 8 ] && n=8
  for ((i = 0; i < 8; i++)); do
    if [ "$i" -lt "$n" ]; then out+="█"; else out+="░"; fi
  done
  printf '%s' "$out"
}

pace_bar() {  # percent ideal_percent color -> 10-cell bar, eighth-block precision, "|" at the ideal position
  awk -v p="$1" -v ideal="$2" -v c="$3" -v R="$R" -v B="$BOLD" 'BEGIN {
    W = 10; if (p > 100) p = 100; if (p < 0) p = 0
    fill = int(p * W * 8 / 100 + 0.5)
    m = int(ideal * W / 100 + 0.5); if (m < 0) m = 0; if (m > W) m = W
    split("▏ ▎ ▍ ▌ ▋ ▊ ▉", part, " ")
    for (i = 0; i < W; i++) {
      if (i == m) printf "%s%s│%s%s", R, B, R, c
      e = fill - i * 8; if (e > 8) e = 8
      if (e <= 0) printf "░"; else if (e >= 8) printf "█"; else printf "%s", part[e]
    }
    if (m == W) printf "%s%s│%s%s", R, B, R, c
  }'
}

ideal_pct() {  # resets_at window_secs -> % of the window elapsed (where usage would be if perfectly even)
  awk -v r="$1" -v w="$2" -v n="$(date +%s)" 'BEGIN {
    e = w - (r - n); if (e < 0 || e > w) exit
    printf "%.1f", e / w * 100 }'
}

until_reset() {  # epoch -> "2h14m" / "3d4h"
  local s=$(( $1 - $(date +%s) )) d h m
  [ "$s" -le 0 ] && return
  d=$((s / 86400)); h=$((s % 86400 / 3600)); m=$((s % 3600 / 60))
  if   [ "$d" -gt 0 ]; then printf '%dd%dh' "$d" "$h"
  elif [ "$h" -gt 0 ]; then printf '%dh%02dm' "$h" "$m"
  else printf '%dm' "$m"; fi
}

pace() {  # used% resets_at window_secs -> burn rate vs even pace (1.00 = on pace); empty if too early
  awk -v u="$1" -v r="$2" -v w="$3" -v n="$(date +%s)" 'BEGIN {
    e = w - (r - n); if (e < 0.10 * w || e > w) exit
    printf "%.2f", (u / 100) / (e / w) }'
}

pace_tag() {  # ratio -> colored "1.3x" (green: under pace, yellow: over, red: well over)
  local c=$GREEN
  awk -v p="$1" 'BEGIN { exit !(p >= 1.25) }' && c=$RED || { awk -v p="$1" 'BEGIN { exit !(p >= 1.0) }' && c=$YELLOW; }
  printf '%s%.1fx%s' "$c" "$1" "$R"
}

meter() {  # label percent resets_at [pace] [ideal_percent]
  local c; c=$(color_for "$2")
  local b; if [ -n "$5" ]; then b=$(pace_bar "$2" "$5" "$c"); else b=$(bar "$2"); fi
  local out="${DIM}$1${R} ${c}${b} $(printf '%.0f' "$2")%${R}"
  if [ -n "$3" ]; then
    local t; t=$(until_reset "$3")
    [ -n "$t" ] && out+=" ${DIM}($t)${R}"
  fi
  [ -n "$4" ] && out+=" $(pace_tag "$4")"
  printf '%s' "$out"
}

recommend() {  # session_used week_used session_pace week_pace session_resets_at -> "level text"
  awk -v su="$1" -v wu="$2" -v sp="$3" -v wp="$4" -v sr="$5" -v n="$(date +%s)" 'BEGIN {
    if (wp != "" && wp >= 1.05) { printf "red ease off →%d%%", wp * 100; exit }
    if (sp != "" && sp > 1.0 && su > 0) {
      left = sr - n; used_s = 18000 - left
      eta = used_s * (100 - su) / su
      if (eta < left && eta < 3600) { printf "yellow cap in %dm", eta / 60 + 1; exit }
    }
    if (wp != "" && wp < 0.7) { printf "green burn more →%d%%", wp * 100; exit }
    if (wp != "") { printf "dim on pace"; exit }
  }'
}

head="${BOLD}${CYAN}$(j .model.display_name)${R}"
out=""; rec=""

ctx=$(j .context_window.used_percentage)
[ -n "$ctx" ] && out+="${SEP}$(meter ctx "$ctx")"

five=$(j .rate_limits.five_hour.used_percentage)
five_r=$(j .rate_limits.five_hour.resets_at)
five_p=""; [ -n "$five" ] && [ -n "$five_r" ] && five_p=$(pace "$five" "$five_r" 18000)
five_i=""; [ -n "$five_r" ] && five_i=$(ideal_pct "$five_r" 18000)
[ -n "$five" ] && out+="${SEP}$(meter session "$five" "$five_r" "$five_p" "$five_i")"

week=$(j .rate_limits.seven_day.used_percentage)
week_r=$(j .rate_limits.seven_day.resets_at)
week_p=""; [ -n "$week" ] && [ -n "$week_r" ] && week_p=$(pace "$week" "$week_r" 604800)
week_i=""; [ -n "$week_r" ] && week_i=$(ideal_pct "$week_r" 604800)
[ -n "$week" ] && out+="${SEP}$(meter week "$week" "$week_r" "$week_p" "$week_i")"

# Recommendation (shown right after the model so narrow terminals never cut it off)
# from burn rate (usage % / elapsed % of window). USAGE_METER_NO_ADVICE=1 hides.
if [ -z "$USAGE_METER_NO_ADVICE" ] && [ -n "$week_p" ]; then
  read -r lvl txt <<<"$(recommend "${five:-0}" "$week" "$five_p" "$week_p" "${five_r:-0}")"
  case $lvl in red) c=$RED;; yellow) c=$YELLOW;; green) c=$GREEN;; *) c=$DIM;; esac
  [ -n "$txt" ] && rec="${SEP}${c}${txt}${R}"
fi

# Log usage samples for burnplan (only when a value changes). USAGE_METER_NO_LOG=1 disables.
if [ -z "$USAGE_METER_NO_LOG" ] && [ -n "$five" ] && [ -n "$week" ]; then
  log=${USAGE_METER_LOG:-$HOME/.claude/usage-meter/samples.jsonl}
  key="$five $week $(j .rate_limits.five_hour.resets_at) $(j .rate_limits.seven_day.resets_at)"
  if [ "$key" != "$(cat "$log.last" 2>/dev/null)" ]; then
    mkdir -p "${log%/*}"
    jq -c --argjson t "$(date +%s)" '{t: $t,
      five: .rate_limits.five_hour.used_percentage, five_reset: .rate_limits.five_hour.resets_at,
      week: .rate_limits.seven_day.used_percentage, week_reset: .rate_limits.seven_day.resets_at}' \
      <<<"$input" >>"$log" && printf '%s' "$key" >"$log.last"
  fi
fi

cost=$(j .cost.total_cost_usd)
[ -n "$cost" ] && out+="${SEP}${DIM}\$$(printf '%.2f' "$cost")${R}"

# Clickable "repo" label linking to the project (OSC 8 hyperlink); set USAGE_METER_NO_LINK=1 to hide.
if [ -z "$USAGE_METER_NO_LINK" ]; then
  url="https://github.com/whbrewer/claude-usage-meter"
  out+="${SEP}"$'\e]8;;'"$url"$'\e\\'"${DIM}repo${R}"$'\e]8;;\e\\'
fi

printf '%s\n' "${head}${rec}${out}"
