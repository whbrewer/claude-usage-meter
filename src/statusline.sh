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

until_reset() {  # epoch -> "2h14m" / "3d4h"
  local s=$(( $1 - $(date +%s) )) d h m
  [ "$s" -le 0 ] && return
  d=$((s / 86400)); h=$((s % 86400 / 3600)); m=$((s % 3600 / 60))
  if   [ "$d" -gt 0 ]; then printf '%dd%dh' "$d" "$h"
  elif [ "$h" -gt 0 ]; then printf '%dh%02dm' "$h" "$m"
  else printf '%dm' "$m"; fi
}

meter() {  # label percent resets_at
  local c; c=$(color_for "$2")
  local out="${DIM}$1${R} ${c}$(bar "$2") $(printf '%.0f' "$2")%${R}"
  if [ -n "$3" ]; then
    local t; t=$(until_reset "$3")
    [ -n "$t" ] && out+=" ${DIM}($t)${R}"
  fi
  printf '%s' "$out"
}

out="${BOLD}${CYAN}$(j .model.display_name)${R}"

dir=$(j .workspace.current_dir)
[ -n "$dir" ] && out+="${SEP}${DIM}${dir##*/}${R}"

ctx=$(j .context_window.used_percentage)
[ -n "$ctx" ] && out+="${SEP}$(meter ctx "$ctx")"

five=$(j .rate_limits.five_hour.used_percentage)
[ -n "$five" ] && out+="${SEP}$(meter session "$five" "$(j .rate_limits.five_hour.resets_at)")"

week=$(j .rate_limits.seven_day.used_percentage)
[ -n "$week" ] && out+="${SEP}$(meter week "$week" "$(j .rate_limits.seven_day.resets_at)")"

cost=$(j .cost.total_cost_usd)
[ -n "$cost" ] && out+="${SEP}${DIM}\$$(printf '%.2f' "$cost")${R}"

# Clickable "repo" label linking to the project (OSC 8 hyperlink); set USAGE_METER_NO_LINK=1 to hide.
if [ -z "$USAGE_METER_NO_LINK" ]; then
  url="https://github.com/whbrewer/claude-usage-meter"
  out+="${SEP}"$'\e]8;;'"$url"$'\e\\'"${DIM}repo${R}"$'\e]8;;\e\\'
fi

printf '%s\n' "$out"
