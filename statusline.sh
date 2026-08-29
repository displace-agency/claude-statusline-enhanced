#!/usr/bin/env bash
# Claude Code statusline v3 — usage-mindful.
# Shows: where · model · effort · thinking | context · 5h · week · this session's slice of week.
# Deliberately omits API $ cost (meaningless on Max), msg count, duration, lines changed.

input=$(cat)
[ -n "$STATUSLINE_DEBUG" ] && printf '%s' "$input" > /tmp/statusline-payload.json 2>/dev/null

_jq=$(printf '%s' "$input" | jq -r '
  (.workspace.current_dir // .cwd // ""),
  (.model.display_name // "?"),
  (.effort.level // ""),
  (if .thinking.enabled then "1" else "0" end),
  (.context_window.used_percentage // 0 | floor),
  (.context_window.context_window_size // 0 | floor),
  (.rate_limits.five_hour.used_percentage // -1 | floor),
  (.rate_limits.five_hour.resets_at // 0 | floor),
  (.rate_limits.seven_day.used_percentage // -1 | floor),
  (.rate_limits.seven_day.resets_at // 0 | floor),
  (.session_id // "")
' 2>/dev/null)
[ -z "$_jq" ] && exit 0
_i=0; while IFS= read -r _l; do _v[$_i]="$_l"; _i=$((_i+1)); done <<< "$_jq"
dir="${_v[0]}"; model="${_v[1]}"; effort="${_v[2]}"; think="${_v[3]}"
ctx="${_v[4]}"; ctxsize="${_v[5]}"
h5="${_v[6]}"; h5r="${_v[7]}"; wk="${_v[8]}"; wkr="${_v[9]}"; sid="${_v[10]}"

R=$'\033[0m'; D=$'\033[90m'; W=$'\033[37m'; G=$'\033[32m'; Y=$'\033[33m'; RD=$'\033[31m'; B=$'\033[1m'; C=$'\033[36m'
SEP="${D} · ${R}"

# colour by how used something is
hue() { [ "$1" -ge 85 ] 2>/dev/null && printf '%s' "$RD" && return; [ "$1" -ge 60 ] 2>/dev/null && printf '%s' "$Y" && return; printf '%s' "$G"; }
# 10-cell bar
FULL="▓▓▓▓▓▓▓▓▓▓"; EMPTY="░░░░░░░░░░"
bar() { local f=$(( ($1+5)/10 )); [ $f -gt 10 ] && f=10; [ $f -lt 0 ] && f=0
        printf '%s%s' "${FULL:0:$f}" "${EMPTY:0:$((10-f))}"; }
# "4d6h" / "2h14m" / "8m" until epoch $1
until_ts() { local s=$(( $1 - $(date +%s) )); [ $s -le 0 ] && printf 'now' && return
             local d=$((s/86400)) h=$((s%86400/3600)) m=$((s%3600/60))
             if [ $d -gt 0 ]; then printf '%dd%dh' $d $h; elif [ $h -gt 0 ]; then printf '%dh%02dm' $h $m; else printf '%dm' $m; fi; }

# ── line 1: place + engine ──────────────────────────────────────────────────
short="${dir/#$HOME/~}"
case "$model" in *"1M"*) mshort="${model%% (*} 1M";; *) mshort="$model";; esac
L1="${C}${short}${R}${SEP}${B}${W}${mshort}${R}"
[ -n "$effort" ] && L1="${L1}${SEP}${W}${effort}${R}"
[ "$think" = "1" ] && L1="${L1}${SEP}${D}think${R}"

# ── line 2: the four numbers that decide behaviour ──────────────────────────
# effective ceiling = autoCompactWindow if set, else the model window
acw=$(jq -r '.autoCompactWindow // empty' "$HOME/.claude/settings.json" 2>/dev/null)
case "$acw" in ''|*[!0-9]*) acw="";; esac
if [ -n "$acw" ] && [ "$ctxsize" -gt 0 ] 2>/dev/null; then
  used_tok=$(( ctx * ctxsize / 100 ))
  ctx=$(( used_tok * 100 / acw )); [ $ctx -gt 100 ] && ctx=100
  ctxsize="$acw"
fi
cc=$(hue "$ctx")
case "$ctxsize" in 0) cw="";; *) if [ "$ctxsize" -ge 1000000 ]; then cw=" ${D}of $((ctxsize/1000000))M${R}"; else cw=" ${D}of $((ctxsize/1000))K${R}"; fi;; esac
L2="${D}ctx${R} ${cc}$(bar $ctx) ${ctx}%${R}${cw}"

if [ "$h5" -ge 0 ] 2>/dev/null; then
  L2="${L2}${SEP}${D}5h${R} $(hue $h5)${h5}%${R}"
  [ "$h5r" -gt 0 ] 2>/dev/null && L2="${L2} ${D}↻$(until_ts $h5r)${R}"
fi
if [ "$wk" -ge 0 ] 2>/dev/null; then
  L2="${L2}${SEP}${D}week${R} $(hue $wk)${B}${wk}%${R}"
  [ "$wkr" -gt 0 ] 2>/dev/null && L2="${L2} ${D}↻$(until_ts $wkr)${R}"
fi

# ── this session's slice: weekly % burned since this session opened ─────────
if [ "$wk" -ge 0 ] 2>/dev/null && [ -n "$sid" ]; then
  sd="$HOME/.claude/.statusline-sessions"; mkdir -p "$sd" 2>/dev/null
  sf="$sd/$sid"
  if [ -f "$sf" ]; then start=$(cat "$sf" 2>/dev/null); else start="$wk"; printf '%s' "$wk" > "$sf" 2>/dev/null; fi
  case "$start" in ''|*[!0-9]*) start="$wk";; esac
  # weekly counter reset mid-session: re-baseline instead of pinning at 0
  if [ "$wk" -lt "$start" ]; then start="$wk"; printf '%s' "$wk" > "$sf" 2>/dev/null; fi
  delta=$(( wk - start ))
  dc=$G; [ $delta -ge 5 ] && dc=$Y; [ $delta -ge 10 ] && dc=$RD
  L2="${L2}${SEP}${D}here${R} ${dc}+${delta}%${R}"
  # prune state files older than 14d so this never grows
  find "$sd" -type f -mtime +14 -delete 2>/dev/null
fi

printf '%s\n%s\n' "$L1" "$L2"
