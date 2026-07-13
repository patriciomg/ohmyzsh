#TODAY
TODAY=`date +"%d.%m.%Y"`
YESTERDAY=`date -v-1d +%d.%m.%Y`
TOMMORROW=`date -v+1d +%d.%m.%Y`

# Clear $1 spinner lines (cursor starts on the first), park it back there,
# re-show the cursor. For INT traps of functions that ran a multi-line spinner.
_spinner_clear() {
  local n=$1 i
  printf "\r\033[K"
  for (( i = 1; i < n; i++ )); do printf "\n\033[K"; done
  (( n > 1 )) && printf "\033[%dA" $(( n - 1 ))
  printf "\r\033[?25h"
}

# Reusable spinner: animates on the current line(s) until <pid> exits.
# Run `spinner` with no args (or -h) for usage + how to embed it in a function.
spinner() {
  if [[ -z $1 || $1 == -h || $1 == --help ]]; then
    cat <<'EOF'
Usage: spinner <pid> [style] [message]

Animates until process <pid> exits, then clears its own lines.

Styles:  moon (default), wave, braille, clock    1 line
         wave2, dino                             2 lines
         bigdino                                 5 lines

Use it in your own function:

  work() {
    some_long_command &
    local pid=$!
    local rows=2    # lines the style draws (see table above; 5 for bigdino)
    trap "kill $pid 2>/dev/null; _spinner_clear $rows; printf '✔ done\n'; return" INT
    spinner $pid dino "⏳ crunching "
    printf '✔ done\n'
  }

Notes:
- The spinner hides the terminal cursor. If <pid> ends on its own, the
  spinner restores it; on Ctrl-C YOUR trap must clean up instead —
  _spinner_clear <rows> wipes the spinner lines and re-shows the cursor.
- End the message with a space; the animation is drawn right after it.
EOF
    return 0
  fi
  local pid=$1 style=${2:-moon} msg=$3
  if [[ $style == dino ]]; then   # two-line animation, needs its own renderer
    _spinner_dino $pid "$msg"
    return
  fi
  if [[ $style == wave2 ]]; then  # double-height wave, also two lines
    _spinner_wave2 $pid "$msg"
    return
  fi
  if [[ $style == bigdino ]]; then  # block-art dino scene, five lines
    _spinner_bigdino $pid "$msg"
    return
  fi
  local -a frames
  local delay=0.15
  case $style in
    wave)    frames=(▁▂▃▄ ▂▃▄▅ ▃▄▅▆ ▄▅▆▇ ▅▆▇█ ▆▇█▇ ▇█▇▆ █▇▆▅ ▇▆▅▄ ▆▅▄▃ ▅▄▃▂ ▄▃▂▁ ▃▂▁▂ ▂▁▂▃); delay=0.08 ;;
    braille) frames=(⣾⣾ ⣽⣽ ⣻⣻ ⢿⢿ ⡿⡿ ⣟⣟ ⣯⣯ ⣷⣷); delay=0.1 ;;
    clock)   frames=(🕐 🕑 🕒 🕓 🕔 🕕 🕖 🕗 🕘 🕙 🕚 🕛); delay=0.12 ;;
    moon|*)  frames=(🌑 🌒 🌓 🌔 🌕 🌖 🌗 🌘) ;;
  esac
  local i=1
  printf "\033[?25l"
  while kill -0 $pid 2>/dev/null; do
    printf "\r\033[K%s %s " "$msg" "${frames[i]}"
    (( i = i % $#frames + 1 ))
    sleep $delay
  done
  printf "\r\033[K\033[?25h"
}

# Double-height wave for spinner: 10 columns × 16 height steps drawn across
# TWO rows of block chars — a literally double-sized `wave`. Same two-line
# contract as the dino: INT traps must clear both lines + re-show the cursor.
_spinner_wave2() {
  local pid=$1 msg=$2
  local w=${(m)#msg}
  local -a blk=(▁ ▂ ▃ ▄ ▅ ▆ ▇ █)
  local -a H=(2 4 6 8 10 12 14 16 14 12 10 8 6 4)   # column heights, 1-16
  local -a top bot
  local i j h t b idx
  for (( i = 1; i <= $#H; i++ )); do   # frame i = height pattern shifted by i
    t="" b=""
    for (( j = 0; j < 10; j++ )); do
      (( idx = (i + j) % $#H + 1 ))
      h=$H[idx]
      if (( h > 8 )); then t+=$blk[h-8]; b+="█"
      else                 t+=" ";       b+=$blk[h]
      fi
    done
    top+=("$t"); bot+=("$b")
  done
  local n=$#top k=1
  printf "\033[?25l"
  while kill -0 $pid 2>/dev/null; do
    printf "\r\033[K%*s%s\n\033[K%s%s\033[1A\r" $w "" "${top[k]}" "$msg" "${bot[k]}"
    (( k = k % n + 1 ))
    sleep 0.08
  done
  printf "\r\033[K\n\033[K\033[1A\r\033[?25h"
}

# Chrome-offline dino for spinner: the dino stands MID-FIELD (dots 15-16 of a
# 22-dot ground); cacti — randomly single 🌵 or double 🌵🌵 — scroll in from
# the left at random intervals, pass underneath during the jump (the dino arcs
# 2 columns forward over them) and keep scrolling until they exit on the right.
# Draws TWO lines (the jump uses the line above the ground), cursor parks on
# the top one — so an INT trap must clear both: \r\033[K\n\033[K\033[1A\r
_spinner_dino() {
  local pid=$1 msg=$2
  local w=${(m)#msg}              # display width of msg (counts ☕ etc. as 2)
  local g="․․․․․․․․․․․․․․․․․․․․․․"       # 22-dot field
  local idle="${g[1,14]}🦖${g[17,-1]}"    # dino replaces dots 15-16
  local -a hop
  hop=(13 12 13 14 14)            # airborne top-line indents for p=12..16
  local c s p gap i t
  printf "\033[?25l"
  while kill -0 $pid 2>/dev/null; do
    gap=$(( 2 + RANDOM % 10 ))    # cruise a random while before the next cactus
    for (( i = 0; i < gap; i++ )); do
      kill -0 $pid 2>/dev/null || break
      printf "\r\033[K\n\033[K%s%s\033[1A\r" "$msg" "$idle"
      sleep 0.12
    done
    c="🌵"; (( RANDOM % 3 == 0 )) && c="🌵🌵"   # roughly every 3rd is a double
    for (( p = 1; p <= 23 + $#c; p++ )); do     # scroll left → right, off the view
      kill -0 $pid 2>/dev/null || break
      s="${g[1,p-1]}${c}${g[p+$#c,-1]}"; s="${s[1,22]}"  # cactus at p, clipped field
      if (( p >= 12 && p <= 16 )); then         # airborne, cactus slides underneath
        t=$hop[p-11]
        printf "\r\033[K%*s🦖\n\033[K%s%s\033[1A\r" $(( w + t )) "" "$msg" "$s"
      else
        printf "\r\033[K\n\033[K%s%s\033[1A\r" "$msg" "${s[1,14]}🦖${s[17,-1]}"
      fi
      sleep 0.12
    done
  done
  printf "\r\033[K\n\033[K\033[1A\r\033[?25h"
}

# Overlay sprite $3 onto row string $1 at column $2, clip to $W cols → $REPLY.
# All sprites are single-width block chars, so char index == display column.
_bd_put() {
  local s="${1[1,$2-1]}$3${1[$2+$#3,-1]}"
  REPLY="${s[1,W]}"
}

# Draw one 5-line bigdino frame: $1 dino state (1 apex / 2 hop / 3 ground),
# $2 dino column, $3 cactus column (0 = none), $4/$5 cactus top/bottom sprite.
# Grounded dino is 3 rows (head/body/legs); airborne it tucks the legs and is
# 2 rows (head/body), which keeps the cactus rows (3-4) clear during the jump.
# Uses the caller's locals (w msg W blank ground dhead dbody legsA legsB leg).
_bd_frame() {
  local st=$1 dc=$2 p=$3 ct=$4 cb=$5
  local r1="$blank" r2="$blank" r3="$blank" r4="$blank"
  local legs=$legsA
  (( leg = 1 - leg )); (( leg )) && legs=$legsB
  if (( p >= 1 && p <= W )); then      # cactus stands on the ground, rows 3-4
    _bd_put "$r3" $p "$ct"; r3=$REPLY
    _bd_put "$r4" $p "$cb"; r4=$REPLY
  fi
  case $st in                          # head juts 1 col ahead of the body
    1) _bd_put "$r1" $((dc-1)) "$dhead"; r1=$REPLY
       _bd_put "$r2" $dc       "$dbody"; r2=$REPLY ;;
    2) _bd_put "$r2" $((dc-1)) "$dhead"; r2=$REPLY
       _bd_put "$r3" $dc       "$dbody"; r3=$REPLY ;;
    3) _bd_put "$r2" $((dc-1)) "$dhead"; r2=$REPLY
       _bd_put "$r3" $dc       "$dbody"; r3=$REPLY
       _bd_put "$r4" $((dc+1)) "$legs";  r4=$REPLY ;;
  esac
  printf "\r\033[K%*s%s\n\033[K%*s%s\n\033[K%*s%s\n\033[K%*s%s\n\033[K%s%s\033[4A\r" \
    $w "" "$r1" $w "" "$r2" $w "" "$r3" $w "" "$r4" "$msg" "$ground"
}

# BIG dino for spinner: 5-line scene — block-art T-Rex (2 rows tall, animated
# legs) mid-field, big 2-row cacti (random singles/doubles at random intervals)
# scroll left → right, get jumped with a 2-col forward arc, and exit the view.
# INT traps must clear FIVE lines: use `_spinner_clear 5` before the farewell.
_spinner_bigdino() {
  local pid=$1 msg=$2
  local w=${(m)#msg} W=24
  local ground="${(l:24::․:):-}" blank="${(l:24:: :):-}"
  # sprite: ▟ snout, █ skull, ▘ ear; body with tail tip ▀; both leg pairs
  # animate. No trailing spaces: the overlay must not stomp a cactus behind.
  local dhead="▟█▘" dbody="█████▀" legsA="▐▌ ▐▌" legsB=" █ █"
  local leg=0 gap i p c1 c2 pmax
  # jump choreography: cactus col / dino top row / dino col per air frame,
  # picked per cactus width so a double never touches the dino on the ground
  local -a jp jr jc
  printf "\033[?25l"
  while kill -0 $pid 2>/dev/null; do
    gap=$(( 2 + RANDOM % 7 ))          # cruise a random while (legs keep running)
    for (( i = 0; i < gap; i++ )); do
      kill -0 $pid 2>/dev/null || break
      _bd_frame 3 15 0 "" ""
      sleep 0.1
    done
    if (( RANDOM % 3 == 0 )); then     # ~every 3rd cactus is a double (6 cols)
      c1="▙█▟▙█▟" c2=" █  █ " pmax=7
      jp=(8  10 12 14 16 18 20 22)
      jr=(2  1  1  1  1  1  1  3)
      jc=(15 13 13 13 13 13 13 15)
    else                               # single (3 cols)
      c1="▙█▟" c2=" █ " pmax=10
      jp=(11 13 15 17 19 21 23 25)
      jr=(2  1  1  1  1  1  2  3)
      jc=(15 13 13 13 13 13 15 15)
    fi
    for (( p = 1; p <= pmax; p++ )); do  # cactus rolls in from the left
      kill -0 $pid 2>/dev/null || break
      _bd_frame 3 15 $p "$c1" "$c2"
      sleep 0.1
    done
    for (( i = 1; i <= $#jp; i++ )); do  # hop → apex (cactus whooshes under) → land
      kill -0 $pid 2>/dev/null || break
      _bd_frame $jr[i] $jc[i] $jp[i] "$c1" "$c2"
      sleep 0.1
    done
  done
  _spinner_clear 5
}

caff() {
  # -d display, -i idle, -m disk, -s system, -u user-active
  # Usage: caff [moon|wave|wave2|braille|clock|dino|bigdino]   (default: moon)
  caffeinate -dimsu &
  local pid=$!
  local rows=2; [[ $1 == bigdino ]] && rows=5   # lines the spinner draws
  trap "kill $pid 2>/dev/null; _spinner_clear $rows; printf '☕ off\n'; return" INT
  spinner $pid "${1:-moon}" "☕ caffeinate ON "
}

# Sync my oh-my-zsh fork (origin = patriciomg/ohmyzsh, upstream = ohmyzsh).
# master stays a pristine mirror of upstream; my stuff lives on `custom`.
# Flow: fetch upstream → ff master → push fork → rebase custom → push custom.
omz-sync() {
  (
    set -e
    cd ~/.oh-my-zsh
    git fetch upstream
    git checkout -q master
    git merge --ff-only upstream/master
    git push origin master
    git checkout -q custom
    git -c rebase.autoStash=true rebase master
    git push --force-with-lease origin custom
  ) && echo "✅ oh-my-zsh synced: master = upstream, custom rebased & pushed" \
    || echo "⚠️  sync stopped — check ~/.oh-my-zsh with git status"
}


hh() {
  (( $# )) && hist | rg "$@" || hist
}

ipinfo(){ curl -s "http://ip-api.com/json/$1?fields=status,country,regionName,city,isp,org,as,asname,reverse,proxy,hosting,mobile" | jq; }


showme() {
  if [ -n "$1" ]; then
    tree -P "*.$1" --prune
    return
  fi
  printf "what should i search?   md html py... \n"
}

# Free space at a glance: internal disk + any external volumes under /Volumes.
# Also shows reclaimable ("purgeable") space — mostly Time Machine local
# snapshots that macOS auto-deletes under pressure. Run `tmsnap` for detail.
dff() {
    df -h | rg disk3s1s1 | awk '{print "internal free: " $4}'
    # External volumes mount under /Volumes/ ($NF = mountpoint, $4 = avail).
    df -h | awk '$NF ~ "^/Volumes/" {print "external free: " $4 "  (" $NF ")"}'
    # df "avail" counts purgeable space; the container's real free does not.
    # The gap ≈ reclaimable (TM local snapshots + caches).
    local _vol="/System/Volumes/Data" _free _cfree
    _free=$(diskutil info -plist "$_vol" 2>/dev/null | plutil -extract FreeSpace raw - 2>/dev/null)
    _cfree=$(diskutil info -plist "$_vol" 2>/dev/null | plutil -extract APFSContainerFree raw - 2>/dev/null)
    if [[ -n "$_free" && -n "$_cfree" && "$_free" -gt "$_cfree" ]]; then
        awk -v b=$(( _free - _cfree )) 'BEGIN{printf "reclaimable:   %.1fGi  (purgeable, mostly TM snapshots — see tmsnap)\n", b/1073741824}'
    fi
}

# Time Machine local snapshots: list them + how much space is reclaimable.
# macOS does NOT report per-snapshot sizes, so we show the aggregate purgeable
# space (df-available minus the APFS container's true free). Thin them with:
#   sudo tmutil thinlocalsnapshots / <bytes-to-free> 4    (4 = most urgent)
#   tmutil deletelocalsnapshots <YYYY-MM-DD-HHMMSS>       (delete one)
tmsnap() {
    local vol="/System/Volumes/Data" snaps
    snaps=$(tmutil listlocalsnapshots "$vol" 2>/dev/null | grep 'com.apple.TimeMachine')

    if [[ -z "$snaps" ]]; then
        echo "no Time Machine local snapshots"
    else
        echo "Time Machine local snapshots ($(echo "$snaps" | wc -l | tr -d ' ')):"
        # name: com.apple.TimeMachine.2026-06-14-093000.local -> 2026-06-14-093000
        echo "$snaps" | sed -E 's/.*TimeMachine\.([0-9-]+).*/  \1/'
    fi

    local free cfree
    free=$(diskutil info -plist "$vol" 2>/dev/null | plutil -extract FreeSpace raw - 2>/dev/null)
    cfree=$(diskutil info -plist "$vol" 2>/dev/null | plutil -extract APFSContainerFree raw - 2>/dev/null)
    if [[ -n "$free" && -n "$cfree" ]]; then
        local purge=$(( free - cfree )); (( purge < 0 )) && purge=0
        awk -v b="$purge" 'BEGIN{printf "reclaimable if thinned: %.2fGi\n", b/1073741824}'
    fi
}

# RAM at a glance — pressure %, free+inactive GB, top PhysMem line
ramf() {
    echo "── memory_pressure ──"
    memory_pressure | tail -1
    echo "── vm_stat (free+inactive) ──"
    vm_stat | awk '/page size/{ps=$8} /Pages free/{f=$3} /Pages inactive/{i=$3} END{gsub("\\.","",f); gsub("\\.","",i); printf "free+inactive: %.2f GB\n", (f+i)*ps/1073741824}'
    echo "── top PhysMem ──"
    top -l 1 | grep PhysMem
}
alias ramfree=ramf

alias free='echo "=== dff ===" && dff && echo && echo "=== tmsnap ===" && tmsnap'
alias space=free


watchdir_basic() {
    local dir="${1:-.}"

    fswatch -xr "$dir" | while read -r file events; do
        printf "%-19s | %-12s | %s\n" \
            "$(date '+%F %T')" \
            "$events" \
            "$file"
    done
}
watchdir() {
    local dir="${1:-.}"

    dir=$(realpath "$dir")

    # --- helpers ---

    shorten() {
        echo "$1" | awk -F/ '{
            if (NF <= 3) print $0;
            else print $1 "/.../" $(NF-1) "/" $NF
        }'
    }

    colorize_path() {
        local path="$1"

        # split last segment (filename)
        local base="${path##*/}"
        local dir="${path%/*}"

        # colors
        local CYAN="\033[36m"
        local YELLOW="\033[33m"
        local RESET="\033[0m"

        if [[ "$path" == "$base" ]]; then
            # no directory
            echo -e "${YELLOW}${base}${RESET}"
        else
            echo -e "${dir}/${CYAN}${base}${RESET}"
        fi
    }

    printf "%-19s | %-12s | %s\n" "Time" "Event" "File"
    printf -- "--------------------------------------------------------------------------\n"

    fswatch -0xr "$dir" | while IFS= read -r -d '' fullpath; do

        relpath="${fullpath#$dir/}"

        # normalize .claude paths
        case "$relpath" in
            .claude)
                label="claude"
                ;;
            .claude/settings.local.json)
                label="claude settings"
                ;;
            .claude/worktrees/*)
                label="claude worktree (${relpath##*/})"
                ;;
            .claude/*)
                label="claude ${relpath#.claude/}"
                ;;
            *)
                label="$relpath"
                ;;
        esac

        # shorten long paths
        label=$(shorten "$label")

        # colorize filename (last segment)
        label=$(colorize_path "$label")

        printf "%-19s | %-12s | %b\n" \
            "$(date '+%F %T')" \
            "change" \
            "$label"
    done
}


# watchdir() {
#     local dir="${1:-.}"
# 
#     printf "%-19s | %-10s | %s\n" "Time" "Event" "File"
#     printf -- "---------------------------------------------------------------------\n"
# 
#     fswatch -xr "$dir" | while read -r file events; do
#         for e in $events; do
#             case "$e" in
#                 Created|Updated|Removed|Renamed)
#                     printf "%-19s | %-10s | %s\n" \
#                         "$(date '+%F %T')" \
#                         "$e" \
#                         "$file"
#                     ;;
#             esac
#         done
#     done
# }

# watchdir() {
#     local dir="${1:-.}"
# 
#     printf "%-19s | %-25s | %s\n" "Time" "Events" "File"
#     printf '%*s\n' 80 '' | tr ' ' '-'
# 
#     fswatch -0xr "$dir" |
#     while IFS= read -r -d '' file; do
#         printf "%-19s | %-25s | %s\n" \
#             "$(date '+%F %T')" \
#             "Changed" \
#             "$file"
#     done
# }

#################################
##
##    L L A M A - C P P
##
#################################

fibo_test() {
  curl -s http://127.0.0.1:4000/v1/chat/completions -H "Content-Type: application/json" -d '{"model":"coding","messages":[{"role":"user","content":"Write a Python one-liner that returns the nth Fibonacci using only reduce."}],"temperature":1.0,"top_p":1.0,"max_tokens":1024}' | jq -r '.choices[0].message.content'
}

llm_list() {
  hf cache list --no-truncate
  echo "~/.cache/huggingface/hub"
  echo "--------------------------------------------------------------------------------"
  lms ls
  echo "~/.lmstudio/models"
  echo "--------------------------------------------------------------------------------"
  ll --no-permissions --no-user --no-time ~/.my-llm-models/*.gguf
  echo
}
alias list_models=llm_list


# Set the tmux pane title to "llama-server [<alias>]" so the status bar shows
# which model is loaded. See automatic-rename-format in ~/.tmux.conf.
_llm_announce() { printf '\033]2;llama-server [%s]\033\\' "$1"; }
_llm_announce_mlx() { printf '\033]2;mlx_lm [%s]\033\\' "$1"; }
_llm_announce_lms() { printf '\033]2;lms [%s]\033\\' "$1"; }

lms_server() {
  lms server start --port 1234 --bind 127.0.0.1
  lms load \
      -c 32768 \
      --gpu max \
      --parallel 1 \
      --identifier lms_model
  lms log stream
}

LLAMA_BIN="$HOME/.my-llm-models/llama/llama-server"
LLAMA_TURBO_BIN="$HOME/.my-llm-models/llama-turbo/build/bin/llama-server"
LLAMA_MODELS="$HOME/.my-llm-models"
LLAMA_LOG="$LLAMA_MODELS/logs/llama-server.log"

_llama_kill() {
    pkill -f llama-server 2>/dev/null
    sleep 2
}

# Shared launcher. Logging OFF by default -> /dev/null.
# Pass -l/--log as FIRST arg to any llama-* fn to write $LLAMA_LOG.
# Usage: _llama_run <pretty-name> <model-args...>   (LLAMA_DOLOG set by wrapper)
_llama_run() {
    local name="$1"; shift
    local out="/dev/null"
    if [[ -n "$LLAMA_DOLOG" ]]; then
        mkdir -p "$(dirname "$LLAMA_LOG")"
        out="$LLAMA_LOG"
    fi

    _llm_announce "$name"

    _llama_kill
    nohup "${LLAMA_RUN_BIN:-$LLAMA_TURBO_BIN}" \
        -c "${LLAMA_RUN_CTX:-65536}" -ngl 999 \
        --mlock -fa on \
        --threads 6 -b 2048 -ub 512 \
        --host 127.0.0.1 --port 4000 \
        "$@" \
        >"$out" 2>&1 &

    if [[ "$out" == "/dev/null" ]]; then
        echo "$name started (PID $!) — no log"
    else
        echo "$name started (PID $!) — log: $out"
    fi
}

# Consume leading -l/--log flag -> set LLAMA_DOLOG. Use: _llama_logflag "$@"
_llama_logflag() {
    LLAMA_DOLOG=""
    case "$1" in
        -l|--log) LLAMA_DOLOG=1 ;;
    esac
}

llama-progress() {
  tail -f ~/.my-llm-models/logs/llama-server.log | rg --line-buffered -o -r 'progress = $1%' 'progress = (0\.\d\d)'
}

# ── Qwen3.6-35B-A3B (UD-Q4_K_XL, MTP build) ──────────────────────
# Official sampling (Qwen model card / unsloth):
#   non-thinking  : temp 0.7  top_p 0.80 top_k 20 min_p 0 pres 1.5  repeat 1.0
#   thinking gen  : temp 1.0  top_p 0.95 top_k 20 min_p 0 pres 1.5  repeat 1.0
#   thinking code : temp 0.6  top_p 0.95 top_k 20 min_p 0 pres 0.0  repeat 1.0
# Qwen3.6 is thinking-ON by default; non-thinking via chat-template-kwargs.
#
# ⚠️ MTP NOTE: this GGUF carries multi-token-prediction tensors for ~1.5–2x
# speculative speedup, but the turbo fork's --spec-type has NO `draft-mtp`
# (only ngram-*). So MTP accel is OFF here — model runs fine as normal, just
# no MTP speedup. To get it: rebuild on recent ggml-org llama.cpp and add
#   --spec-type draft-mtp --spec-draft-n-max 2 -np 1
# but that build lacks `--cache-type-v turbo4` (turbo-fork-only) → use q8_0 V.
# ──────────────────────────────────────────────────────────────────

# Daily driver — fast MoE, code-tuned, no thinking
# llama-qwen() {
#     _llama_logflag "$1"
#     _llama_run "Qwen" \
#         -m "$LLAMA_MODELS/Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf" \
#         --n-cpu-moe 0 \
#         --cache-type-k q8_0 --cache-type-v turbo4 \
#         --jinja --chat-template-kwargs '{"enable_thinking": false}' \
#         --temperature 0.7 --top_p 0.8 --top_k 20 --min_p 0.0 \
#         --presence_penalty 1.5 --repeat-penalty 1.0 -np 1 \
#         --alias qwen
# }
# 
# llama-qwen-thinking() {
#     _llama_logflag "$1"
#     _llama_run "Qwen" \
#         -m "$LLAMA_MODELS/Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf" \
#         --n-cpu-moe 0 \
#         --cache-type-k q8_0 --cache-type-v turbo4 \
#         --jinja --chat-template-kwargs '{"enable_thinking": true}' \
#         --temperature 1.0 --top_p 0.95 --top_k 20 --min_p 0 \
#         --presence_penalty 1.5 \
#         --repeat-penalty 1.0 -np 1 \
#         --alias qwen-thinking
# }
# 
# llama-qwen-rethinking() {
#     _llama_logflag "$1"
#     _llama_run "Qwen" \
#         -m "$LLAMA_MODELS/Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf" \
#         --n-cpu-moe 0 \
#         --cache-type-k q8_0 --cache-type-v turbo4 \
#         --jinja --chat-template-kwargs '{"enable_thinking": true}' \
#         --temperature 0.6 --top_p 0.95 --top_k 20 --min_p 0.0 \
#         --presence_penalty 0.0 \
#         --repeat-penalty 1.0 -np 1 \
#         --alias qwen-rethinking
# }

# ── MTP variants: stock binary (build 9470, has draft-mtp), ~1.5–2x via
# speculative decoding. Tradeoff: NO turbo4 KV (stock lacks it) -> q8_0 V.
# `local LLAMA_RUN_BIN` overrides the launcher's binary (dynamic scope).
# A/B these against the turbo4 versions above to see which nets faster.
# llama-qwen-mtp() {            # non-thinking + MTP
#     _llama_logflag "$1"
#     local LLAMA_RUN_BIN="$LLAMA_BIN"
#     local LLAMA_RUN_CTX=32768   # 32k: safe with --mlock'd 23GB model on 32GB
#     local spec=(--spec-type draft-mtp --spec-draft-n-max 2)  # set NO_MTP=1 to A/B without MTP
#     [[ -n "$NO_MTP" ]] && spec=()
#     _llama_run "Qwen-MTP" \
#         -m "$LLAMA_MODELS/Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf" \
#         --n-cpu-moe 0 \
#         --cache-type-k q8_0 --cache-type-v q8_0 \
#         "${spec[@]}" \
#         --jinja --chat-template-kwargs '{"enable_thinking": false}' \
#         --temperature 0.7 --top_p 0.8 --top_k 20 --min_p 0.0 \
#         --presence_penalty 1.5 --repeat-penalty 1.0 -np 1 \
#         --alias qwen
# }
# 
# llama-qwen-thinking-mtp() {   # thinking general + MTP
#     _llama_logflag "$1"
#     local LLAMA_RUN_BIN="$LLAMA_BIN"
#     local LLAMA_RUN_CTX=32768   # 32k: safe with --mlock'd 23GB model on 32GB
#     local spec=(--spec-type draft-mtp --spec-draft-n-max 2)  # set NO_MTP=1 to A/B without MTP
#     [[ -n "$NO_MTP" ]] && spec=()
#     _llama_run "Qwen-MTP" \
#         -m "$LLAMA_MODELS/Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf" \
#         --n-cpu-moe 0 \
#         --cache-type-k q8_0 --cache-type-v q8_0 \
#         "${spec[@]}" \
#         --jinja --chat-template-kwargs '{"enable_thinking": true}' \
#         --temperature 1.0 --top_p 0.95 --top_k 20 --min_p 0 \
#         --presence_penalty 1.5 --repeat-penalty 1.0 -np 1 \
#         --alias qwen-thinking
# }
# 
# ## KEEPER MODEL
# llama-qwen-rethinking-mtp() { # thinking precise-coding + MTP
#     _llama_logflag "$1"
#     local LLAMA_RUN_BIN="$LLAMA_BIN"
#     local LLAMA_RUN_CTX=32768   # 32k: safe with --mlock'd 23GB model on 32GB
#     local spec=(--spec-type draft-mtp --spec-draft-n-max 2)  # set NO_MTP=1 to A/B without MTP
#     [[ -n "$NO_MTP" ]] && spec=()
#     _llama_run "Qwen-MTP" \
#         -m "$LLAMA_MODELS/Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf" \
#         --n-cpu-moe 0 \
#         --cache-type-k q8_0 --cache-type-v q8_0 \
#         "${spec[@]}" \
#         --jinja --chat-template-kwargs '{"enable_thinking": true}' \
#         --temperature 0.6 --top_p 0.95 --top_k 20 --min_p 0.0 \
#         --presence_penalty 0.0 --repeat-penalty 1.0 -np 1 \
#         --alias qwen-rethinking
# }
# 
# Qwen3-Coder-30B-A3B — code-specialized, NON-thinking instruct.
# DISABLED 2026-06-15: gguf deleted (benched; scores in llm-bench/RANKING.md).
# Re-download Qwen3-Coder-30B-A3B-Instruct-1M-UD-Q4_K_XL.gguf to re-enable.
# llama-qwen3coder() {
#     _llama_logflag "$1"
#     local LLAMA_RUN_BIN="$LLAMA_BIN"
#     local LLAMA_RUN_CTX=32768
#     _llama_run "Qwen3-Coder" \
#         -m "$LLAMA_MODELS/Qwen3-Coder-30B-A3B-Instruct-1M-UD-Q4_K_XL.gguf" \
#         --n-cpu-moe 0 \
#         --cache-type-k q8_0 --cache-type-v q8_0 \
#         --jinja \
#         --temperature 0.7 --top_p 0.8 --top_k 20 --min_p 0.0 \
#         --repeat-penalty 1.05 -np 1 \
#         --alias qwen3-coder
# }

# Gemma-4 26B-A4B MoE — 4B active, depth on tap.
# DISABLED 2026-06-15: gguf deleted from disk (benched; scores in llm-bench/RANKING.md).
# Re-download gemma-4-26B-A4B-it-UD-Q5_K_XL.gguf to re-enable.
# llama-gemma-26() {
#     _llama_logflag "$1"
#     _llama_run "Gemma-4-26B-A4B" \
#         -m "$LLAMA_MODELS/gemma-4-26B-A4B-it-UD-Q5_K_XL.gguf" \
#         --n-cpu-moe 0 \
#         --cache-type-k q8_0 --cache-type-v turbo4 \
#         --jinja \
#         --temperature 1.0 --top_p 0.95 --top_k 64 --min_p 0.0 \
#         --repeat-penalty 1.0 -np 1 \
#         --alias coding-gemma-26
# }

# Gemma4-26B-A4B Uncensored (HauhauCS "Balanced") @ Q5_K_M (~19GB) — MoE, 4B active.
# Runs on the TURBO build (Gemma-4 arch predates the Qwen3.6 SSM issue → turbo4 V-cache OK).
# Thinking mode is toggled via the chat template, same as Qwen3.6: set THINK=1 for chain-of-thought
# (default OFF = faster, shorter). Official Gemma-4 sampling: temp 1.0 / top_p 0.95 / top_k 64.
#   llama-gemma-hauhau          → enable_thinking:false (fast)
#   THINK=1 llama-gemma-hauhau  → enable_thinking:true  (CoT)
llama-gemma-hauhau() {
    _llama_logflag "$1"
    local LLAMA_RUN_CTX=32768   # 19GB model + turbo4 V-cache fits 32k on 32GB; prompts are far under
    local think=false
    [[ -n "$THINK" ]] && think=true
    _llama_run "Gemma4-HauhauCS (think=$think)" \
        -m "$LLAMA_MODELS/gemma-4-26b-a4b-q5km-balanced.gguf" \
        --n-cpu-moe 0 \
        --cache-type-k q8_0 --cache-type-v turbo4 \
        --jinja --chat-template-kwargs "{\"enable_thinking\": $think}" \
        --temperature 1.0 --top_p 0.95 --top_k 64 --min_p 0.0 \
        --repeat-penalty 1.0 -np 1 \
        --alias gemma-hauhau
}

llama-gemma-coding() {
    _llama_logflag "$1"
    # local LLAMA_RUN_CTX=65536   # 19GB model + turbo4 V-cache fits 32k on 32GB; prompts are far under
    local LLAMA_RUN_CTX=82000
    _llama_run "gemma - HauhauCS (think=false)" \
        -m "$LLAMA_MODELS/gemma-4-26b-a4b-q5km-balanced.gguf" \
        --n-cpu-moe 0 \
        --cache-type-k q8_0 --cache-type-v turbo4 \
        --jinja --chat-template-kwargs '{"enable_thinking": false}' \
        --temperature 1.0 --top_p 0.95 --top_k 64 --min_p 0.0 \
        --repeat-penalty 1.0 -np 1 \
        --alias gemma
}
llama-gemma-coding-thinking() {
    _llama_logflag "$1"
    local LLAMA_RUN_CTX=65536   # 19GB model + turbo4 V-cache fits 32k on 32GB; prompts are far under
    _llama_run "gemma-thinking - HauhauCS (think=true)" \
        -m "$LLAMA_MODELS/gemma-4-26b-a4b-q5km-balanced.gguf" \
        --n-cpu-moe 0 \
        --cache-type-k q8_0 --cache-type-v turbo4 \
        --jinja --chat-template-kwargs '{"enable_thinking": true}' \
        --temperature 1.0 --top_p 0.95 --top_k 64 --min_p 0.0 \
        --repeat-penalty 1.0 -np 1 \
        --alias gemma-thinking
}

# Gemma4-26B-A4B Uncensored "Heretic" @ i1-Q4_K_M (~17GB) — MoE, 4B active.
# Lineage: Google QAT (quantization-aware-trained, q4_0-targeted) base → "Heretic" abliteration
# (uncensoring) → re-quant to imatrix Q4_K_M. A/B vs the HauhauCS "Balanced" model: does this more
# aggressive uncensoring pay the capability tax that "Balanced" avoided? Same turbo build / KV / sampling.
#   llama-gemma-heretic          → enable_thinking:false (fast)
#   THINK=1 llama-gemma-heretic  → enable_thinking:true  (CoT)
llama-gemma-heretic() {
    _llama_logflag "$1"
    local LLAMA_RUN_CTX=32768   # ~17GB Q4_K_M + turbo4 V-cache, comfortable at 32k on 32GB
    local think=false
    [[ -n "$THINK" ]] && think=true
    _llama_run "Gemma4-Heretic (think=$think)" \
        -m "$LLAMA_MODELS/gemma-4-26b-a4b-q4km-heretic.gguf" \
        --n-cpu-moe 0 \
        --cache-type-k q8_0 --cache-type-v turbo4 \
        --jinja --chat-template-kwargs "{\"enable_thinking\": $think}" \
        --temperature 1.0 --top_p 0.95 --top_k 64 --min_p 0.0 \
        --repeat-penalty 1.0 -np 1 \
        --alias gemma-heretic
}

llama-gemma-coding-2() {
    _llama_logflag "$1"
    local LLAMA_RUN_CTX=65536   # ~17GB Q4_K_M + turbo4 V-cache, comfortable at 32k on 32GB
    _llama_run "gemma-2 - Heretic (think=false)" \
        -m "$LLAMA_MODELS/gemma-4-26b-a4b-q4km-heretic.gguf" \
        --n-cpu-moe 0 \
        --cache-type-k q8_0 --cache-type-v turbo4 \
        --jinja --chat-template-kwargs '{"enable_thinking": false}' \
        --temperature 1.0 --top_p 0.95 --top_k 64 --min_p 0.0 \
        --repeat-penalty 1.0 -np 1 \
        --alias gemma-heretic
}
llama-gemma-coding-thinking-2() {
    _llama_logflag "$1"
    local LLAMA_RUN_CTX=65536   # ~17GB Q4_K_M + turbo4 V-cache, comfortable at 32k on 32GB
    _llama_run "gemma-coding-2 - Heretic (think=true)" \
        -m "$LLAMA_MODELS/gemma-4-26b-a4b-q4km-heretic.gguf" \
        --n-cpu-moe 0 \
        --cache-type-k q8_0 --cache-type-v turbo4 \
        --jinja --chat-template-kwargs '{"enable_thinking": true}' \
        --temperature 1.0 --top_p 0.95 --top_k 64 --min_p 0.0 \
        --repeat-penalty 1.0 -np 1 \
        --alias gemma-heretic-thinking
}


#
##
# Correctness backstop — reasoning at full depth
# llama-gpt() {
#     _llama_logflag "$1"
#     local LLAMA_RUN_BIN="$LLAMA_BIN"
#     local LLAMA_RUN_CTX=16384   # f16 KV is 2x q8_0; 16k keeps mlock'd 22GB safe on 32GB
#     _llama_run "GPT-OSS" \
#         -m "$LLAMA_MODELS/GPT-OSS-20B-Code-BF16.Q8_0.gguf" \
#         --cache-type-k f16 --cache-type-v f16 \
#         --jinja --chat-template-kwargs '{"reasoning_effort": "high"}' \
#         --temperature 1.0 --top_p 1.0 --top_k 0 \
#         --repeat-penalty 1.0 --presence-penalty 0.0 \
#         --alias gpt
# }

# Stock gpt-oss-20b at unsloth F16 (~13GB: experts kept at native MXFP4, rest F16 —
# highest-fidelity build, NOT a 40GB full-F16). 👑 Best coder + bug-fixer in the bench
# (40/40 + 70/70) — see llm-bench/RANKING.md.
# temp 0.7, NOT OpenAI's official 1.0: at 1.0 it rambles in its reasoning channel and
# never commits an answer (p1=0); at 0.7 it commits cleanly (p1=10). Use 0.7 for real work.
llama-gpt-f16() {
    _llama_logflag "$1"
    local LLAMA_RUN_BIN="$LLAMA_BIN"
    # local LLAMA_RUN_CTX=16384   # f16 KV is 2x q8_0; 16k keeps it safe on 32GB
    local LLAMA_RUN_CTX=90000   # f16 KV is 2x q8_0; 16k keeps it safe on 32GB
    _llama_run "GPT-OSS-F16" \
        -m "$LLAMA_MODELS/gpt-oss-20b-F16.gguf" \
        --cache-type-k f16 --cache-type-v f16 \
        --jinja --chat-template-kwargs '{"reasoning_effort": "high"}' \
        --temperature 0.7 --top_p 1.0 --top_k 0 \
        --repeat-penalty 1.0 --presence-penalty 0.0 \
        --alias gpt-f16
}

# Qwopus3.6-27B-Coder-MTP (sdlangshaw/Jackrong) — DENSE 27B, Q5_K_M (~18GB).
# DROPPED 2026-06-17: tested p1/p2 — clean & coherent (~10/10), but ~11 MIN/PROMPT (dense 27B on M1 Max).
# Too slow to be useful: the fast MoE models already max planning (40/40) + reasoning (10/10), so a slow
# dense model has no headroom to win the one role it could ("better planner"). gguf deleted. RANKING appendix.
# (Was: stock 9571, q8 KV @16k, temp 0.6 / top_p 0.95 / top_k 20, MTP off. Re-download to revive.)
# llama-qwopus() {
#     _llama_logflag "$1"
#     local LLAMA_RUN_BIN="$LLAMA_BIN"
#     local LLAMA_RUN_CTX=16384
#     _llama_run "Qwopus-27B" \
#         -m "$LLAMA_MODELS/Qwopus3.6-27B-Coder-MTP-Q5_K_M.gguf" \
#         --cache-type-k q8_0 --cache-type-v q8_0 \
#         --jinja \
#         --temperature 0.6 --top_p 0.95 --top_k 20 --min_p 0.0 \
#         --repeat-penalty 1.0 -np 1 \
#         --alias qwopus
# }

# ── NEW 2026-06-19 ────────────────────────────────────────────────────────────
# HIDra-30B-A3B (SAPSAN-SKLEP) — UNCENSORED/cybersec, abliterated Qwen3-Coder-30B-A3B.
# GGUF says general.architecture=qwen3moe (128 experts, 8 active ≈ 3.3B active) @ Q5_K_M (~22GB).
# Stock binary (9571) loads qwen3moe (same arch family as the old qwen3coder). MoE → --n-cpu-moe 0.
# NO thinking: the embedded template has no enable_thinking ("answers directly, no <think>"), so no
# chat-template-kwargs. Native ctx 256K; we cap at 16k (prompts are tiny, keeps the 22GB model safe on 32GB).
# Card sampling: temp 0.7 / top_p 0.8 / top_k 20 / repeat 1.05 / min_p 0.
#   NOTE: run.sh forces top_k:0 per-request for EVERY model, so top_k is effectively off during the
#   bench; temp/top_p come from the MODELS table, min_p/repeat-penalty from the flags below.
llama-hidra() {
    _llama_logflag "$1"
    local LLAMA_RUN_BIN="$LLAMA_BIN"
    local LLAMA_RUN_CTX=32384
    _llama_run "HIDra-30B-A3B (uncensored)" \
        -m "$LLAMA_MODELS/HIDra-30B-A3B-Q5_K_M.gguf" \
        --n-cpu-moe 0 \
        --cache-type-k q8_0 --cache-type-v q8_0 \
        --jinja \
        --temperature 0.7 --top_p 0.8 --top_k 20 --min_p 0.0 \
        --repeat-penalty 1.05 -np 1 \
        --alias hidra
}

# ───────────────────────────────────────────────────────────────────────────
# DELETED 2026-06-23 — Qwen3-Coder-30B-A3B "480B-Distill-V2" gguf removed from disk. Graded 183/250
# (lowest in the lineup): red-team ✅ (p10 complies, non-abliterated) + best p18 honesty (6), but BOTH core
# keys ❌ — p3 AUTO-FAIL (retries 4xx, classic Qwen3-Coder disqualifier) + p7 fail, and p8 AUTO-FAIL ("no bug").
# HIDra already covers red-team (same Qwen3-Coder-30B MoE). See llm-bench RANKING.md appendix. Launcher kept
# commented as a record of the working params (stock-only, qwen3moe MoE, q8 KV, ctx 16k) for a possible re-pull.
# ───────────────────────────────────────────────────────────────────────────
# Qwen3-Coder-30B-A3B-Instruct "480B-Distill-V2" (mradermacher GGUF, fp32 source) — the OFFICIAL
# Qwen3-Coder-30B-A3B Instruct distilled from the 480B Coder (V2), NOT abliterated (cf. hidra).
# GGUF metadata CONFIRMED: general.architecture=qwen3moe, 128 experts / 8 active (≈3.3B active), 48 blocks,
# Q4_K_M (~17GB). SAME arch as hidra / the deleted qwen3coder → stock binary (9571), MoE → --n-cpu-moe 0.
# NON-thinking (no <think> in the embedded template → no chat-template-kwargs); tool-call template present.
# Native ctx 256K; cap 16k like hidra (prompts are tiny; keeps it comfortable on 32GB — Q4 leaves more room than hidra's Q5).
# Sampling = official Qwen3-Coder Instruct: temp 0.7 / top_p 0.8 / top_k 20 / repeat 1.05 / min_p 0
#   (run.sh forces top_k:0 per-request for the bench; temp/top_p come from the MODELS table, min_p/repeat from here.)
# llama-qwdistill() {
#     _llama_logflag "$1"
#     local LLAMA_RUN_BIN="$LLAMA_BIN"
#     local LLAMA_RUN_CTX=16384
#     _llama_run "Qwen3-Coder-30B-A3B Distill-V2" \
#         -m "$LLAMA_MODELS/Qwen3-Coder-30B-A3B-Instruct-480B-Distill-V2-Fp32.Q4_K_M.gguf" \
#         --n-cpu-moe 0 \
#         --cache-type-k q8_0 --cache-type-v q8_0 \
#         --jinja \
#         --temperature 0.7 --top_p 0.8 --top_k 20 --min_p 0.0 \
#         --repeat-penalty 1.05 -np 1 \
#         --alias qwdistill
# }

# ── NEW 2026-06-23 ────────────────────────────────────────────────────────────
# Mythos-nano (mradermacher i1 GGUF) — TINY 3.1B DENSE. GGUF metadata: general.architecture=qwen2
# (Qwen2 family, NOT Qwen3), ChatML template (<|im_start|>), tools-aware, NON-thinking (no <think>).
# i1-Q6_K (~2.4GB) — trivial on 32GB. Stock binary (9571) loads qwen2; dense → no --n-cpu-moe.
# Native ctx 128K; cap 16k (bench prompts are tiny). No card-specified sampling → standard Qwen2.5 preset:
# temp 0.7 / top_p 0.8 / top_k 20 / repeat 1.05 / min_p 0. (run.sh forces top_k:0 per-request for the bench.)
# ⚠️ Just-for-fun: a 3.1B is an order of magnitude below the keepers — expect coding/bug-fixing to crater;
#    the interesting question is whether anything coherent survives at this size.
llama-mythos-nano() {
    _llama_logflag "$1"
    local LLAMA_RUN_BIN="$LLAMA_BIN"
    local LLAMA_RUN_CTX=16384
    _llama_run "Mythos-nano 3.1B (qwen2)" \
        -m "$LLAMA_MODELS/Mythos-nano.i1-Q6_K.gguf" \
        --cache-type-k q8_0 --cache-type-v q8_0 \
        --jinja \
        --temperature 0.7 --top_p 0.8 --top_k 20 --min_p 0.0 \
        --repeat-penalty 1.05 -np 1 \
        --alias mythos-nano
}

# ── NEW 2026-06-25 — three "fun"/curiosity models to bench (see llm-bench/RANKING.md) ─────────
# Arch CONFIRMED against GGUF metadata via llama-gguf, NOT the HF card prose.
#
# 1) mythos-9b-merged (mradermacher i1 GGUF) — DENSE 9B. GGUF metadata: general.architecture=qwen3
#    (Qwen3 family, dense — NO expert tensors), ChatML template (<|im_start|>), thinking-CAPABLE
#    (template carries <think>/enable_thinking, like recode_mtp). i1-Q6_K (~6.7GB). Stock binary (9571)
#    loads qwen3; dense → NO --n-cpu-moe. Native ctx large; cap 16k (bench prompts are tiny).
#    No card-specified sampling → Qwen3 NON-thinking preset: temp 0.7 / top_p 0.8 / top_k 20 / min_p 0
#    / repeat 1.05. enable_thinking OFF by default for a clean coding run; THINK=1 = CoT (A/B).
#    ⚠️ It's a Mythos *merge* (RP-flavoured), not a code model — expect coding/bugfix to be weak.
llama-mythos9() {
    _llama_logflag "$1"
    local LLAMA_RUN_BIN="$LLAMA_BIN"
    local LLAMA_RUN_CTX=16384
    local think=false
    [[ -n "$THINK" ]] && think=true
    _llama_run "mythos-9b-merged (qwen3 dense, think=$think)" \
        -m "$LLAMA_MODELS/mythos-9b-merged.i1-Q6_K.gguf" \
        --cache-type-k q8_0 --cache-type-v q8_0 \
        --jinja --chat-template-kwargs "{\"enable_thinking\": $think}" \
        --temperature 0.7 --top_p 0.8 --top_k 20 --min_p 0.0 \
        --repeat-penalty 1.05 -np 1 \
        --alias mythos9
}

# ── NEW 2026-07-12 — MiniCPM VLM backbones as text "just-for-fun" probes ─────────
# Two GGUFs (openbmb-family MiniCPM multimodal models). The .gguf holds ONLY the LLM
# backbone ("general.name = Llm"); the vision/audio encoder (mmproj) is NOT loaded, so
# both run as PURE TEXT models here. Arch CONFIRMED against GGUF metadata via the header:
#
# 1) MiniCPM-o-4_5 (omni: vision+audio) — DENSE 8.2B. arch=qwen3, 36 blocks, ctx 40960,
#    ChatML (<|im_start|>, bos 151644/eos 151645), tools + enable_thinking in template.
#    Q8_0 (~8.7GB). Same family/treatment as mythos9 (qwen3 dense): --jinja, thinking OFF
#    by default (THINK=1 to enable), Qwen3 non-think preset t0.7/p0.8/k20/rep1.05.
#    NOT a nano — 8.2B, mythos9 weight-class. Run: ./bench_models.sh minicpm-o
llama-minicpm-o() {
    _llama_logflag "$1"
    local LLAMA_RUN_BIN="$LLAMA_BIN"
    local LLAMA_RUN_CTX=16384
    local think=false
    [[ -n "$THINK" ]] && think=true
    _llama_run "MiniCPM-o-4.5 8.2B backbone (qwen3 dense, think=$think)" \
        -m "$LLAMA_MODELS/MiniCPM-o-4_5-Q8_0.gguf" \
        --cache-type-k q8_0 --cache-type-v q8_0 \
        --jinja --chat-template-kwargs "{\"enable_thinking\": $think}" \
        --temperature 0.7 --top_p 0.8 --top_k 20 --min_p 0.0 \
        --repeat-penalty 1.05 -np 1 \
        --alias minicpm-o
}

# 2) MiniCPM-V-4.6-heretic (vision, abliterated) — DENSE 752M (sub-nano, smaller than
#    mythos-nano 3.1B). arch=qwen35 (Qwen3.5), 24 blocks, ctx 262144, bos 248045/eos 248046,
#    enable_thinking in template. f16 (~1.5GB). Same treatment as ornith/glm qwen35: --jinja
#    + enable_thinking kwarg, thinking OFF by default (THINK=1 to enable). No card sampling →
#    Qwen3.5 non-think preset t0.7/p0.8/k20/rep1.05. Run: ./bench_models.sh minicpm-v
llama-minicpm-v() {
    _llama_logflag "$1"
    local LLAMA_RUN_BIN="$LLAMA_BIN"
    local LLAMA_RUN_CTX=16384
    local think=false
    [[ -n "$THINK" ]] && think=true
    _llama_run "MiniCPM-V-4.6-heretic 752M backbone (qwen35 dense, think=$think)" \
        -m "$LLAMA_MODELS/MiniCPM-V-4.6-heretic.f16.gguf" \
        --cache-type-k q8_0 --cache-type-v q8_0 \
        --jinja --chat-template-kwargs "{\"enable_thinking\": $think}" \
        --temperature 0.7 --top_p 0.8 --top_k 20 --min_p 0.0 \
        --repeat-penalty 1.05 -np 1 \
        --alias minicpm-v
}

# ── NEW 2026-07-12 — Qwen3.5-4B as the A54-realistic general/phone-assistant candidate ─────────
# unsloth Qwen3.5-4B-UD-Q4_K_XL (dynamic 4-bit, ~2.9GB) — DENSE 4B, arch qwen35, thinking-capable
# (enable_thinking in template). This is the "2–4B Q4 that might hold German" target flagged in the
# GENERAL track (RANKING.md): fits an 8GB A54 (~2.9GB + ctx) and is borderline on 6GB. Default
# NON-think for a snappy phone assistant (THINK=1 → CoT); Qwen3.5 non-think preset t0.7/p0.8/k20/
# rep1.05. VERIFIED 2026-07-12 vs GGUF metadata: arch=qwen35 dense, 4B, ctx 262144, Q4 ~2.91GB.
# Run: GENERAL=1 ./bench_models.sh qwen35-4b
llama-qwen35-4b() {
    _llama_logflag "$1"
    local LLAMA_RUN_BIN="$LLAMA_BIN"
    local LLAMA_RUN_CTX=16384
    local think=false
    [[ -n "$THINK" ]] && think=true
    _llama_run "Qwen3.5-4B UD-Q4_K_XL (qwen35 dense, think=$think)" \
        -m "$LLAMA_MODELS/Qwen3.5-4B-UD-Q4_K_XL.gguf" \
        --cache-type-k q8_0 --cache-type-v q8_0 \
        --jinja --chat-template-kwargs "{\"enable_thinking\": $think}" \
        --temperature 0.7 --top_p 0.8 --top_k 20 --min_p 0.0 \
        --repeat-penalty 1.05 -np 1 \
        --alias qwen35-4b
}

# ── NEW 2026-07-12 — Gemma-4 E2B QAT as the STRONG A54 general/phone candidate ─────────
# google/gemma-4-E2B-it-qat-q4_0-gguf → gemma-4-E2B_q4_0-it.gguf (~3.3GB, top-level). GGUF meta:
# general.architecture=gemma4 (SAME arch as gemma-hauhau's 26B-A4B, which loads on this build →
# gemma4 supported), DENSE, size_label 4.6B total / ~2B effective (MatFormer per-layer-embeddings),
# ctx 131072, Q4_0 QAT (near-bf16 quality). Gemma preset t1.0/top_p0.95/top_k64 (per unsloth/Google
# card) — same as gemma-hauhau. --jinja + enable_thinking:false default (THINK=1 → CoT). Text-only
# here: mmproj (gemma-4-E2B-it-mmproj.gguf, vision) NOT loaded. Best A54 fit of the batch — QAT-Q4_0
# quality + Gemma's German strength, ~3.3GB (fits 8GB, tight on 6GB). Run: GENERAL=1 ./bench_models.sh gemma4-e2b
llama-gemma4-e2b() {
    _llama_logflag "$1"
    local LLAMA_RUN_BIN="$LLAMA_BIN"
    local LLAMA_RUN_CTX=16384
    local think=false
    [[ -n "$THINK" ]] && think=true
    _llama_run "Gemma-4 E2B QAT (gemma4 dense, think=$think)" \
        -m "$LLAMA_MODELS/gemma-4-E2B_q4_0-it.gguf" \
        --cache-type-k q8_0 --cache-type-v q8_0 \
        --jinja --chat-template-kwargs "{\"enable_thinking\": $think}" \
        --temperature 1.0 --top_p 0.95 --top_k 64 --min_p 0.0 \
        --repeat-penalty 1.0 -np 1 \
        --alias gemma4-e2b
}

# 2) MythoSnowy-l2-13B — REMOVED 2026-06-25. Llama-2 13B (2023-era) RP merge: ships no chat template, so under
#    a generic --chat-template llama2 it rambled to the 16k token cap every prompt (~5.5 min each) and answered
#    gibberish in the smoke test. Not worth benching against a 2026 coding suite. gguf + partial outputs deleted.

# 3) North-Mini-Code-1.0 (unsloth GGUF) — MoE. GGUF metadata: general.architecture=cohere2moe
#    (Cohere Command-style MoE: expert_count + leading_dense_block_count present), Cohere Command template
#    (<BOS_TOKEN>/<|START_OF_TURN_TOKEN|>/USER_TOKEN/CHATBOT_TOKEN), template carries reasoning tokens.
#    UD-Q5_K_M (~23GB). MoE → --n-cpu-moe 0 (experts on GPU, like hidra). Embedded chat_template → --jinja.
#    cohere2moe support: build 9571 could NOT load it ("unknown model architecture: 'cohere2moe'"), but the
#    UPDATED stock binary build 9789 (b3ce5cedf) DOES — CONFIRMED 2026-06-25: loads in ~14s, generates correctly.
#    ⚠️ 23GB Q5 + KV is tight on 32GB → cap ctx 16k, q8 KV. If Metal OOMs at load
#    (kIOGPUCommandBufferCallbackErrorOutOfMemory in the log), drop LLAMA_RUN_CTX to 8192.
#    Sampling per the user's note / unsloth: temp 1.0 / top_p 0.95 (top_k forced to 0 per-request by run.sh).
llama-north-mini() {
    _llama_logflag "$1"
    local LLAMA_RUN_BIN="$LLAMA_BIN"
    local LLAMA_RUN_CTX=16384
    _llama_run "North-Mini-Code-1.0 (cohere2moe)" \
        -m "$LLAMA_MODELS/North-Mini-Code-1.0-UD-Q5_K_M.gguf" \
        --n-cpu-moe 0 \
        --cache-type-k q8_0 --cache-type-v q8_0 \
        --jinja \
        --temperature 1.0 --top_p 0.95 --top_k 20 --min_p 0.0 \
        --repeat-penalty 1.05 -np 1 \
        --alias north-mini
}

# ── NEW 2026-07-02 — DeepReinforce Ornith-1.0 (RL-trained coding models) ─────────
# Two GGUFs from deepreinforce-ai (HF: Ornith-1.0-35B-GGUF / Ornith-1.0-9B-GGUF).
# BOTH are REASONING models — the embedded template emits <think>...</think> by default
# (qwen3 reasoning parser). Card sampling for BOTH: temp 0.6 / top_p 0.95 / top_k 20
#   (top_k is forced to 0 per-request by run.sh; temp/top_p come from the MODELS table,
#    min_p/repeat from the flags here.) The 9B card notes temp 1.0 "to reproduce benchmark
#   results" — we use 0.6, the generation preset, to match how the rest of the suite runs.
# Reasoning is ON by default here (the model's design + the 0.6/0.95 preset IS the reasoning
# preset); NOTHINK=1 flips enable_thinking off for a CoT-on-vs-off A/B.
#
# 1) Ornith-1.0-35B — HF card: general.architecture=Qwen35MoE (MoE) → --n-cpu-moe 0 (experts
#    on GPU, like hidra/north-mini). Q4_K_M (~21GB) — comparable footprint to hidra (22GB) /
#    north-mini (23GB) on 32GB → cap ctx 16k, q8 KV.
#    ⚠️ ARCH LOAD: qwen35moe is newer than the DENSE qwen35 (openmythos). If the stock binary
#    bails at load with "unknown model architecture: 'qwen35moe'", update the stock build —
#    same class of fix that unblocked north-mini's cohere2moe (stock 9789). CONFIRM the arch
#    string against the actual GGUF metadata (llama-gguf) before trusting the card, as elsewhere.
#    ⚠️ Active-param count isn't on the card — run the p1 smoke test to gauge speed before an
#    unattended full run. If Metal OOMs at load (kIOGPUCommandBufferCallbackErrorOutOfMemory),
#    drop LLAMA_RUN_CTX to 8192.
llama-ornith-35b() {
    _llama_logflag "$1"
    local LLAMA_RUN_BIN="$LLAMA_BIN"
    local LLAMA_RUN_CTX=16384
    local think=true
    [[ -n "$NOTHINK" ]] && think=false
    _llama_run "Ornith-1.0-35B (qwen35moe, think=$think)" \
        -m "$LLAMA_MODELS/ornith-1.0-35b-Q4_K_M.gguf" \
        --n-cpu-moe 0 \
        --cache-type-k q8_0 --cache-type-v q8_0 \
        --jinja --chat-template-kwargs "{\"enable_thinking\": $think}" \
        --temperature 0.6 --top_p 0.95 --top_k 20 --min_p 0.0 \
        --repeat-penalty 1.0 -np 1 \
        --alias ornith-35b
}

# 2) Ornith-1.0-9B — DENSE 9B (card: architecture Qwen3.5), Q8_0 (~9.5GB).
#    DENSE → NO --n-cpu-moe. Same qwen35 family as openmythos → the stock binary should load it.
#    Cap ctx 16k, q8 KV. Q8_0 is near-lossless vs the bf16 (perplexity gap <0.1%, inside bench
#    noise) but ~half the RAM and faster on the long <think> reasoning output — the right pick here.
llama-ornith-9b() {
    _llama_logflag "$1"
    local LLAMA_RUN_BIN="$LLAMA_BIN"
    local LLAMA_RUN_CTX=16384
    local think=true
    [[ -n "$NOTHINK" ]] && think=false
    _llama_run "Ornith-1.0-9B (qwen35 dense Q8_0, think=$think)" \
        -m "$LLAMA_MODELS/ornith-1.0-9b-Q8_0.gguf" \
        --cache-type-k q8_0 --cache-type-v q8_0 \
        --jinja --chat-template-kwargs "{\"enable_thinking\": $think}" \
        --temperature 0.6 --top_p 0.95 --top_k 20 --min_p 0.0 \
        --repeat-penalty 1.0 -np 1 \
        --alias ornith-9b
}

# ── NEW 2026-07-03 — Ornith-1.0-35B HERETIC (uncensored) — the p10 red-team probe ────────────
# C0deGeek's decensored build: **Heretic v1.4.0** abliteration (p-e-w/heretic — the SAME tool that
# kept gemma-heretic at 224/250 with no capability tax) + **APEX** MoE-aware quant (mudler/apex-quant:
# edge layers high-precision, middle experts compressed; full 256 experts RETAINED, NOT pruned) +
# imatrix (code/reasoning/tool calibration). Q6_K-APEX-I-Quality (~22.8GB, ppl 6.96 — near-Q6).
# **No MTP** — trunk-only (block_count=40, converted with --no-mtp); nothing special needed to load.
# Base is qwen35moe (same arch stock benched at 220/250) → --n-cpu-moe 0. Reasoning ON by default
# (NOTHINK=1 to A/B). Repo also ships an mmproj vision projector — IGNORE it, run text-only.
# WHY: stock ornith-35b scored 220 but REFUSED p10 (reverse shell) → no red-team. This tests whether
# Heretic adds red-team (+5 → ~225, ties the Gemmas) WITHOUT the abliteration tax that gutted
# gptoss-cyber (coding 40→16, p18 honesty 9→1). Watch p5/p18 for a honesty regression. See RANKING.md.
# ⚠️ If Metal OOMs at load (kIOGPUCommandBufferCallbackErrorOutOfMemory), drop LLAMA_RUN_CTX to 8192.
# Alt build (fallback A/B if this won't load or honesty regresses): llmfan46 Heretic v1.2.0+MPOA
# (standard K-quant, no imatrix, Q6 28.6GB = too big for 32GB; MMLU 81.71 vs 82.64 → low tax).
llama-ornith-35b-heretic() {
    _llama_logflag "$1"
    local LLAMA_RUN_BIN="$LLAMA_BIN"
    local LLAMA_RUN_CTX=16384
    local think=true
    [[ -n "$NOTHINK" ]] && think=false
    _llama_run "Ornith-1.0-35B heretic APEX (qwen35moe, think=$think)" \
        -m "$LLAMA_MODELS/Ornith-1.0-35B-heretic-Q6_K-APEX-I-Quality.gguf" \
        --n-cpu-moe 0 \
        --cache-type-k q8_0 --cache-type-v q8_0 \
        --jinja --chat-template-kwargs "{\"enable_thinking\": $think}" \
        --temperature 0.6 --top_p 0.95 --top_k 20 --min_p 0.0 \
        --repeat-penalty 1.0 -np 1 \
        --alias ornith-35b-heretic
}

# DeepSeek-R1-Distill-Qwen-32B (mradermacher i1 imatrix) — DENSE 32B, arch=qwen2
# (Qwen2.5-32B base with R1 reasoning distilled in). Reasoning-ON: emits <think>…</think>
# then the answer — GRADE THE POST-</think> TEXT (see p4/p6/p21–23/p25 in RUBRIC.md).
# Quant: i1-Q4_K_M (~20GB), NOT Q5_K_M — on 32GB RAM the 23.4GB Q5 collides with the 32k
# KV cache this reasoner needs; Q4 frees the room (matches the ornith-35b Q4 choice).
# ⚠️ SPEED: DENSE 32B on M1 Max behaves like the dropped qwopus/openmythos (~10–15 min/prompt,
# worse because it reasons) → a full 25-prompt run is HOURS. Plan overnight; smoke first.
# ctx 32768 + q8_0 KV so long reasoning doesn't truncate (20GB weights + ~4GB KV fits 32GB).
#   If RAM pressure shows (swap/ramf), drop LLAMA_RUN_CTX to 24576 or 16384.
# Template: --jinja uses the GGUF's embedded DeepSeek-R1 template, which forces the leading
#   <think>. If a smoke run shows it SKIPPING the think block (old template), that's the
#   known R1-distill degrader — re-quant from an updated source or inject <think>\n.
# Sampling: DeepSeek card — temp 0.6 / top_p 0.95, NO system prompt, no repeat penalty.
#   (top_k forced to 0 per-request by run.sh; temp/top_p come from the MODELS table.)
# Model path overridable: R1QWEN32B_GGUF=/path/to.gguf llama-deepseek-r1-32b
#   ONLY="p1 p3 p5 p8 p10 p12 p18 p25" ./bench_models.sh deepseek-r1-32b   # smoke (reason+loops+honesty)
#   ./bench_models.sh deepseek-r1-32b                                       # full suite (overnight)
llama-deepseek-r1-32b() {
    _llama_logflag "$1"
    local LLAMA_RUN_BIN="$LLAMA_BIN"
    local LLAMA_RUN_CTX="${LLAMA_RUN_CTX:-32768}"
    local gguf="${R1QWEN32B_GGUF:-$LLAMA_MODELS/DeepSeek-R1-Distill-Qwen-32B.i1-Q4_K_M.gguf}"
    [[ -f "$gguf" ]] || { echo "!! gguf not found: $gguf (set R1QWEN32B_GGUF=/path)"; return 1; }
    _llama_run "DeepSeek-R1-Distill-Qwen-32B (dense qwen2, reasoning-ON, i1-Q4_K_M)" \
        -m "$gguf" \
        --cache-type-k q8_0 --cache-type-v q8_0 \
        --jinja \
        --temperature 0.6 --top_p 0.95 --top_k 0 --min_p 0.0 \
        --repeat-penalty 1.0 -np 1 \
        --alias deepseek-r1-32b
}

# OpenMythos-27B (jabbatheduck) — DENSE 27B, GGUF says general.architecture=qwen35 (Qwen3.5),
# NOT a MoE (no expert tensors) and NOT the "Qwen3.6" the HF card text implies. Q6_K (~22GB).
# Stock binary (9571) loads qwen3.x. Template DOES support enable_thinking; card benched it OFF.
# ⚠️ SPEED: a dense 27B on M1 Max behaves like the dropped qwopus (~10 min/prompt) — a full 25-prompt
# run is HOURS, not minutes. Plan an overnight/unattended run.
# Card sampling: temp 0.2 / top_p 0.8 / top_k 20 / min_p 0.05 / repeat 1.02 / presence 0.2.
#   (top_k forced to 0 per-request by run.sh; temp/top_p from the MODELS table; min_p/repeat/presence here.)
# To A/B with thinking on: THINK=1 llama-openmythos.
# ARCHIVED 2026-06-20: gguf moved to an EXTERNAL HDD (blue-team-only — refuses offensive
# tasks even under an authorized system prompt; see llm-bench/RANKING.md "Red-team track").
# The model file is path-overridable: mount the drive and run
#   OPENMYTHOS_GGUF=/Volumes/<drive>/OpenMythos-27B-Q6_K.gguf llama-openmythos
# If neither the override nor the default path exists, the launcher bails with a hint
# instead of failing deep inside llama-server.
llama-openmythos() {
    _llama_logflag "$1"
    local LLAMA_RUN_BIN="$LLAMA_BIN"
    local LLAMA_RUN_CTX=16384
    local think=false
    [[ -n "$THINK" ]] && think=true
    local model="${OPENMYTHOS_GGUF:-$LLAMA_MODELS/OpenMythos-27B-Q6_K.gguf}"
    if [[ ! -f "$model" ]]; then
        echo "llama-openmythos: gguf not found at '$model'." >&2
        echo "  OpenMythos is archived to external HDD — mount it and retry with:" >&2
        echo "  OPENMYTHOS_GGUF=/Volumes/<drive>/OpenMythos-27B-Q6_K.gguf llama-openmythos" >&2
        return 1
    fi
    _llama_run "OpenMythos-27B (qwen35 dense, think=$think)" \
        -m "$model" \
        --cache-type-k q8_0 --cache-type-v q8_0 \
        --jinja --chat-template-kwargs "{\"enable_thinking\": $think}" \
        --temperature 0.2 --top_p 0.8 --top_k 20 --min_p 0.05 \
        --repeat-penalty 1.02 --presence-penalty 0.2 -np 1 \
        --alias openmythos
}

# ── NEW 2026-07-10 — InternScience Agents-A1 (agentic / science / tool-use) ─────
# 35B MoE, arch qwen35moe — the SAME arch/quant class as ornith-35b (Q4_K_M ~21GB),
# which loads on the stock binary (9789) with experts on GPU (--n-cpu-moe 0). So
# this is a straight clone of llama-ornith-35b pointed at the new gguf.
# ⚠️ GET Q4_K_M, NOT the F16 (69GB, won't fit 32GB) or Q8_0 (37GB, won't fit):
#   hf download InternScience/Agents-A1-Q4_K_M-GGUF Agents-A1-Q4_K_M.gguf --local-dir "$LLAMA_MODELS"
# Reasoning model (Qwen3 reasoning parser → emits <think>…</think>): grade the
# POST-</think> answer, like ornith/deepseek. NOTHINK=1 flips reasoning off for an A/B.
# Native ctx 262K; cap 16k here (bench prompts are tiny). Tool-call template present
# → this is the model to drive with tools/agent_harness.py (its GAIA/BrowseComp side).
# Sampling: Qwen3 reasoning preset t0.6/p0.95/k20 (top_k forced to 0 per-request by
# run.sh). ⚠️ VERIFY against the gguf's general.sampling.* once it lands (the ggufread
# trick) and adjust if the card's values differ. Path overridable via AGENTS_A1_GGUF.
# ⚠️ If Metal OOMs at load (kIOGPUCommandBufferCallbackErrorOutOfMemory), drop ctx to 8192.
#   AGENT=1 ./bench_models.sh agents-a1          # single-turn agent/sci suite (RUBRIC-AGENT.md)
#   python3 tools/agent_harness.py --label agents-a1   # real tool-calling loop
llama-agents-a1() {
    _llama_logflag "$1"
    local LLAMA_RUN_BIN="$LLAMA_BIN"
    local LLAMA_RUN_CTX="${LLAMA_RUN_CTX:-16384}"
    local think=true
    [[ -n "$NOTHINK" ]] && think=false
    local gguf="${AGENTS_A1_GGUF:-$LLAMA_MODELS/Agents-A1-Q4_K_M.gguf}"
    [[ -f "$gguf" ]] || { echo "!! gguf not found: $gguf (set AGENTS_A1_GGUF=/path)"; return 1; }
    _llama_run "Agents-A1 (qwen35moe, agentic, think=$think)" \
        -m "$gguf" \
        --n-cpu-moe 0 \
        --cache-type-k q8_0 --cache-type-v q8_0 \
        --jinja --chat-template-kwargs "{\"enable_thinking\": $think}" \
        --temperature 0.6 --top_p 0.95 --top_k 20 --min_p 0.0 \
        --repeat-penalty 1.0 -np 1 \
        --alias agents-a1
}

# ───────────────────────────────────────────────────────────────────────────
# DELETED 2026-06-23 — Qwable-5-27B-Coder gguf removed from disk. Graded 199/250
# (bug-fix 69/70 + blue-team, but refuses p10, fails p7 judgment, ~264s/prompt) →
# dominated by the faster Gemma-26B-A4B. "dense 27B = no headroom." See llm-bench
# RANKING.md appendix. Launcher kept commented as a record of the working params
# (stock-only binary, q8 KV, ctx 32k) in case the gguf is ever re-pulled.
# ───────────────────────────────────────────────────────────────────────────
# Qwable-5-27B-Coder (DJLougen) — DENSE 27B on Qwen3.6-27B (hybrid Gated-DeltaNet/SSM). i1-Q4_K_M (~17GB).
# MUST use the STOCK binary (9571): the TURBO build (9079) predates Qwen3.6's SSM layout and dies at load
# with "missing tensor blk.N.ssm_conv1d.weight" — same as the disabled turbo llama-qwen* launchers above.
# Stock REJECTS turbo4 KV → use q8_0 V (like recode_mtp/hidra). No --n-cpu-moe: dense, has no expert tensors.
# ⚠️ DENSE 27B on M1 Max ≈ ~10 min/prompt (cf. dropped qwopus/openmythos) → a full suite is HOURS, plan overnight.
# CTX: Q5 (20GB) OOM'd Metal at 32k; Q4 (17GB) frees ~3GB → 32k q8 KV now fits (28GB wired - 17GB = ~11GB room).
#   If the smoke test still OOMs (watch log for kIOGPUCommandBufferCallbackErrorOutOfMemory), drop to 24576/16384.
# Qwen3.6 supports thinking; THINK=1 = CoT. Official Qwen3.6 sampling (run.sh overrides temp/top_p per-request):
#   non-thinking  : temp 0.7 top_p 0.80 top_k 20 min_p 0 presence 1.5 repeat 1.0
#   thinking-code : temp 0.6 top_p 0.95 top_k 20 min_p 0 presence 0.0 repeat 1.0
# llama-qwable() {
#     _llama_logflag "$1"
#     local LLAMA_RUN_BIN="$LLAMA_BIN"   # stock 9571 — turbo can't load Qwen3.6 SSM tensors
#     local LLAMA_RUN_CTX=32768          # Q4 (17GB) leaves ~11GB → 32k q8 KV fits; Q5 had OOM'd here
#     local think=false samp
#     if [[ "${THINK:-}" == 1 ]]; then   # ONLY THINK=1 enables CoT; THINK=0/unset = non-thinking
#         think=true;  samp=(--temperature 0.6 --top_p 0.95 --top_k 20 --min_p 0.0 --presence-penalty 0.0)
#     else
#         think=false; samp=(--temperature 0.7 --top_p 0.80 --top_k 20 --min_p 0.0 --presence-penalty 1.5)
#     fi
#     _llama_run "Qwable 27B Coder (think=$think)" \
#         -m "$LLAMA_MODELS/Qwable-5-27B-Coder.i1-Q4_K_M.gguf" \
#         --cache-type-k q8_0 --cache-type-v q8_0 \
#         --jinja --chat-template-kwargs "{\"enable_thinking\": $think}" \
#         "${samp[@]}" \
#         --repeat-penalty 1.0 -np 1 \
#         --alias qwable
# }


# DavidAU NEO-CODE coder merge of gpt-oss-20b.
# DISABLED 2026-06-15: gguf deleted. Rambled to no-commit (p1) + syntax errors (p2);
# does NOT beat stock gptoss-f16. (If ever retried: drop reasoning_effort to "medium".) RANKING.md.
# llama-gpt-neocode() {
#     _llama_logflag "$1"
#     local LLAMA_RUN_BIN="$LLAMA_BIN"
#     local LLAMA_RUN_CTX=16384
#     _llama_run "GPT-OSS-NEO-CODER" \
#         -m "$LLAMA_MODELS/OpenAI-20B-NEO-CODE-DIMAT-MXFP4_MOE4.gguf" \
#         --cache-type-k f16 --cache-type-v f16 \
#         --jinja --chat-template-kwargs '{"reasoning_effort": "high"}' \
#         --temperature 0.6 --top_p 0.95 --top_k 40 --min_p 0.05 \
#         --repeat-penalty 1.1 --presence-penalty 0.0 \
#         --alias gpt-neocode
# }

# gpt-oss-20b-cve-sec — CVE/security-tuned gpt-oss-20b.
# DISABLED 2026-06-15: gguf deleted. Refuses p10 (not red-team), unstable (p5 loop, p9
# meltdown), confidently hallucinates Pimcore. Worse than stock everywhere. RANKING.md.
# llama-gpt-cvesec() {
#     _llama_logflag "$1"
#     local LLAMA_RUN_BIN="$LLAMA_BIN"
#     local LLAMA_RUN_CTX=16384
#     _llama_run "GPT-OSS-CVE-SEC" \
#         -m "$LLAMA_MODELS/gpt-oss-20b-cve-sec.Q5KM.gguf" \
#         --cache-type-k f16 --cache-type-v f16 \
#         --jinja --chat-template-kwargs '{"reasoning_effort": "high"}' \
#         --temperature 0.7 --top_p 1.0 --top_k 0 \
#         --repeat-penalty 1.0 --presence-penalty 0.0 \
#         --alias gpt-cvesec
# }

# GPT-OSS-Cybersecurity-20B abliterated "noref" merge.
# DISABLED 2026-06-15: gguf deleted. Abliteration tax made it bad at coding (16/40) and a
# confident Pimcore hallucinator (p18=1); red-team worked but recode_mtp covers it. See RANKING.md.
# llama-gpt-cyber() {
#     _llama_logflag "$1"
#     local LLAMA_RUN_BIN="$LLAMA_BIN"
#     local LLAMA_RUN_CTX=16384
#     _llama_run "GPT-OSS-Cyber" \
#         -m "$LLAMA_MODELS/gpt-oss-20B-sec-noref-i1-Q5KM.gguf" \
#         --cache-type-k f16 --cache-type-v f16 \
#         --jinja --chat-template-kwargs '{"reasoning_effort": "high"}' \
#         --temperature 0.7 --top_p 1.0 --top_k 0 \
#         --repeat-penalty 1.0 --presence-penalty 0.0 \
#         --alias gpt-cyber
# }

# gpt-oss-coder-20b — community CODE finetune of gpt-oss (mradermacher i1 Q5_K_M).
# DISABLED 2026-06-15: gguf deleted — unreliable (broken template: 7 empty + 2 looping
# outputs at temp 1.0; weak where captured). Stock llama-gpt-f16 covers it, smaller+reliable.
# llama-gpt-coder() {
#     _llama_logflag "$1"
#     local LLAMA_RUN_BIN="$LLAMA_BIN"
#     local LLAMA_RUN_CTX=16384
#     _llama_run "GPT-OSS-Coder" \
#         -m "$LLAMA_MODELS/gpt-oss-coder-20b.i1-Q5_K_M.gguf" \
#         --cache-type-k f16 --cache-type-v f16 \
#         --jinja --chat-template-kwargs '{"reasoning_effort": "high"}' \
#         --temperature 1.0 --top_p 1.0 --top_k 0 \
#         --repeat-penalty 1.0 --presence-penalty 0.0 \
#         --alias gpt-coder
# }

# llama-devstral() {
#     _llama_logflag "$1"
#     _llama_run "Devstral v2" \
#         -m "$LLAMA_MODELS/Devstral-Small-2-24B-Instruct-2512-UD-Q5_K_XL.gguf" \
#         --cache-type-k q8_0 --cache-type-v turbo4 \
#         --jinja \
#         --temperature 0.15 --top_p 0.95 --top_k 40 --min_p 0.05 \
#         --repeat-penalty 1.0 \
#         --alias coding-devstral
# }


llama-stop() {
    _llama_kill
    echo "llama-server stopped"
}

llama-log()    { tail -f "$LLAMA_LOG"; }
llama-status() { pgrep -fl llama-server || echo "no llama-server running"; }
# dont-sleep moved to a standalone script: ~/personal/bin/dont-sleep (symlinked into ~/.local/bin)


qwen-local() {
 OPENAI_BASE_URL="http://localhost:4000/v1" OPENAI_API_KEY="not-needed" qwen --auth-type openai --approval-mode yolo --model $1 
}

claude-local() {
  ANTHROPIC_AUTH_TOKEN=ollama ENABLE_CLAUDEAI_MCP_SERVERS=false ANTHROPIC_BASE_URL=http://127.0.0.1:4000 claudealone --model $1
}

aider-local() {
      local port="${1:-4000}" model="${2:-coding}"
      OPENAI_BASE_URL="http://127.0.0.1:$port/v1" \
      OPENAI_API_BASE="http://127.0.0.1:$port/v1" \
      OPENAI_API_KEY="dummy" \
      aider --model "openai/$model" \
            --chat-language english \
            --no-show-model-warnings \
            --assistant-output-color "#00aaff" \
            --code-theme monokai
}

aider-ollama() {
      local model="${2:-coding}"
      OPENAI_BASE_URL="http://127.0.0.1:11434/v1" \
      OPENAI_API_BASE="http://127.0.0.1:11434/v1" \
      OPENAI_API_KEY="dummy" \
      aider --model "openai/$model" \
            --chat-language english \
            --no-show-model-warnings \
            --assistant-output-color "#00aaff" \
            --code-theme monokai
}


# Change the starship prompt label on the fly
# Usage:
#   prompt-label Am malochen     → sets it for this session
#   prompt-label -s Feierabend   → saves it permanently (updates exports.zsh)
#   prompt-label                 → shows current value
prompt-label() {
  local exports="$HOME/.oh-my-zsh/custom/exports.zsh"

  if [[ $# -eq 0 ]]; then
    echo "Current: ${PROMPT_LABEL:-<unset>}"
    return
  fi

  if [[ "$1" == "-s" ]]; then
    shift
    local new_label="$*"
    export PROMPT_LABEL="$new_label"
    sed -i '' 's/^export PROMPT_LABEL=.*/export PROMPT_LABEL="'"$new_label"'"/' "$exports"
    echo "Saved permanently: $new_label"
  else
    export PROMPT_LABEL="$*"
    echo "Set for this session: $*"
  fi
}

# docker-compose() {
#     docker compose "$@"
# }

# Reload .zshrc in every tmux pane at once
reload-all() {
  if [[ -z "$TMUX" ]]; then
    source ~/.zshrc
    echo "Reloaded (not in tmux, sourced locally)"
    return
  fi
  local count=0
  tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index}' | while IFS= read -r pane; do
    tmux send-keys -t "$pane" "source ~/.zshrc" Enter
    ((count++))
  done
  echo "Reloaded .zshrc in all tmux panes"
}


# Pad <string> with spaces so its visible width (ANSI-stripped) equals <width>.
_vw_pad() {
  emulate -L zsh
  setopt no_xtrace no_verbose
  local s="$1" w="$2"
  local stripped vis pad
  stripped=$(printf '%s' "$s" | sed $'s/\033\\[[0-9;]*m//g')
  vis=${#stripped}
  pad=$(( w - vis ))
  (( pad < 0 )) && pad=0
  printf '%s%*s' "$s" "$pad" ""
}

# Visible width of a string (ANSI escapes stripped).
_vw_width() {
  emulate -L zsh
  setopt no_xtrace no_verbose
  local stripped
  stripped=$(printf '%s' "$1" | sed $'s/\033\\[[0-9;]*m//g')
  print -r -- ${#stripped}
}

# Print two array vars side-by-side. Args: <left_var> <right_var> <left_width>
_print_two_cols() {
  emulate -L zsh
  setopt no_xtrace no_verbose
  local _lv="$1" _rv="$2" _w="$3"
  local -a _l _r
  _l=( "${(@P)_lv}" )
  _r=( "${(@P)_rv}" )
  local _n=${#_l[@]}
  (( ${#_r[@]} > _n )) && _n=${#_r[@]}
  local _i
  for (( _i=1; _i<=_n; _i++ )); do
    printf '%s  %s\n' "$(_vw_pad "${_l[_i]:-}" "$_w")" "${_r[_i]:-}"
  done
}

function _osx_helpers_render() {
  emulate -L zsh
  setopt no_xtrace no_verbose
  # Gruvbox palette — real ESC bytes via $'...'
  local o=$'\033[38;2;214;93;14m'    # orange
  local y=$'\033[38;2;215;153;33m'   # yellow
  local g=$'\033[38;2;104;157;106m'  # aqua/green
  local d=$'\033[38;2;102;92;84m'    # dim
  local w=$'\033[38;2;251;241;199m'  # fg light
  local B=$'\033[1m'                 # bold
  local r=$'\033[0m'                 # reset

  local cmd="${g}${B}"
  local desc="${d}"
  local sep="${d}·${r}"

  print
  print -r -- "  ${o}${B}  OSX Helpers${r}  ${d}─── tools & tricks cheatsheet${r}"
  print

  local -a left right
  left=(
    "  ${y}${B}  Files & Disk${r}"
    "  ${cmd}dust${r}          ${desc}disk usage (visual)${r}"
    "  ${cmd}ncdu${r}          ${desc}disk usage (interactive)${r}"
    "  ${cmd}eza${r}           ${desc}better ls${r}"
    "  ${cmd}bat${r}           ${desc}better cat${r}"
    "  ${cmd}rg${r}            ${desc}better grep${r}"
    "  ${cmd}fd${r}            ${desc}better find${r}"
    "  ${cmd}fzf${r}           ${desc}fuzzy file finder${r}"
    "  ${cmd}zoxide${r}        ${desc}better cd (use ${w}z${r}${desc})${r}"
    "  ${cmd}stow${r}          ${desc}symlink farm manager${r}"
    ""
    "  ${y}${B}  Dev Tools${r}"
    "  ${cmd}lazygit${r}       ${desc}terminal git UI${r}"
    "  ${cmd}lazydocker${r}    ${desc}terminal docker UI${r}"
    "  ${cmd}lazysql${r}       ${desc}terminal SQL client${r}"
    "  ${cmd}posting${r}       ${desc}API REST client${r}"
    "  ${cmd}jq${r}            ${desc}JSON processor${r}"
    "  ${cmd}yq${r}            ${desc}YAML/JSON/XML processor${r}"
    "  ${cmd}grex${r}          ${desc}regex from strings${r}"
    "  ${cmd}git-delta${r}     ${desc}pager for git diff${r}"
    "  ${cmd}tlrc${r}          ${desc}how-to for commands${r}"
    "  ${cmd}gh${r}            ${desc}GitHub CLI (PRs, issues)${r}"
    "  ${cmd}uv${r}            ${desc}fast Python env/pkg mgr${r}"
    ""
    "  ${y}${B}  Notes & Journaling${r}"
    "  ${cmd}jrnl${r}          ${desc}cmdline journal${r}"
    "  ${cmd}obs-help${r}      ${desc}Obsidian skill cheatsheet${r}"
  )

  right=(
    "  ${y}${B}  Kubernetes & Network${r}"
    "  ${cmd}stern${r}         ${desc}multi-pod log tail${r}"
    "  ${cmd}k9s${r}           ${desc}k8s TUI dashboard${r}"
    "  ${cmd}kubetail${r}      ${desc}aggregate logs${r}"
    "  ${cmd}slurm${r}         ${desc}network load monitor${r}"
    "  ${cmd}dog${r}           ${desc}DNS command line${r}"
    "  ${cmd}dnstop${r}        ${desc}DNS traffic analyzer${r}"
    "  ${cmd}http${r}          ${desc}HTTPie API client${r}"
    "  ${cmd}btop${r}          ${desc}system monitor${r}"
    ""
    "  ${y}${B}  Fun & Eye Candy${r}"
    "  ${cmd}figlet${r}        ${desc}big ASCII text${r}"
    "  ${cmd}cbonsai${r}       ${desc}bonsai tree${r}"
    "  ${cmd}cmatrix${r}       ${desc}matrix rain${r}"
    "  ${cmd}nms${r}           ${desc}no more secrets${r}"
    "  ${cmd}sl${r}            ${desc}train${r}"
    "  ${cmd}genact${r}        ${desc}look busy doing stuff${r}"
    "  ${cmd}asciiaquarium${r} ${desc}fish tank${r}"
    "  ${cmd}termsaver${r}     ${desc}terminal screensaver${r}"
    "  ${cmd}tetris${r}        ${desc}you know what it is${r}"
    "  ${cmd}asciinema${r}     ${desc}record/replay sessions${r}"
    ""
    "  ${y}${B}  Shell & Prompt${r}"
    "  ${cmd}omz-sync${r}      ${desc}sync my oh-my-zsh fork from upstream${r}"
    "  ${cmd}prompt-label${r}  ${desc}change starship label${r}"
    "                ${w}prompt-label Hacking${r}"
    "                ${w}prompt-label -s Am malochen${r}"
  )

  # Responsive: size the left column to its widest entry, and stack into a
  # single column when the window is too narrow to fit both side by side
  # (otherwise the right column gets cut off the edge).
  local _lw=0 _rw=0 _ww _item
  for _item in "${left[@]}";  do _ww=$(_vw_width "$_item"); (( _ww > _lw )) && _lw=$_ww; done
  for _item in "${right[@]}"; do _ww=$(_vw_width "$_item"); (( _ww > _rw )) && _rw=$_ww; done

  if (( ${COLUMNS:-80} >= _lw + 2 + _rw )); then
    _print_two_cols left right $_lw
  else
    for _item in "${left[@]}";  do print -r -- "$_item"; done
    for _item in "${right[@]}"; do print -r -- "$_item"; done
  fi

  print
  print -r -- "  ${o}${B}  Everyday:${r}  ${cmd}lazygit${r} ${sep} ${cmd}rg${r} ${sep} ${cmd}eza${r} ${sep} ${cmd}fzf${r} ${sep} ${cmd}zoxide${r} ${sep} ${cmd}stern${r}"
  print
}

function osx_helpers() {
  if [[ -n "$TMUX" ]]; then
    # Running inside tmux — show as a floating popup
    tmux display-popup -w 92 -h 46 -E "zsh -c 'source ~/.oh-my-zsh/custom/functions.zsh; _osx_helpers_render; echo \"  Press any key to close.\"; read -sk1'"
  else
    _osx_helpers_render
  fi
}

function _osx_tools_render() {
  emulate -L zsh
  setopt no_xtrace no_verbose
  # Gruvbox palette (matches _osx_helpers_render)
  local o='\033[38;2;214;93;14m'    # orange
  local y='\033[38;2;215;153;33m'   # yellow
  local g='\033[38;2;104;157;106m'  # aqua/green
  local b='\033[38;2;69;133;136m'   # blue
  local p='\033[38;2;177;98;134m'   # purple
  local d='\033[38;2;102;92;84m'    # dim
  local w='\033[38;2;251;241;199m'  # fg light
  local B='\033[1m'                 # bold
  local r='\033[0m'                 # reset

  local cmd="${g}${B}"
  local desc="${d}"
  local arg="${w}"

  echo
  echo -e "  ${o}${B}  OSX Tools${r}  ${d}─── custom shell helpers${r}"
  echo

  echo -e "  ${y}${B}  Reminders${r}"
  echo -e "  ${cmd}remind${r}        ${desc}macOS Reminders.app entry${r}"
  echo -e "                ${arg}remind \"buy milk\"${r}                  ${desc}14 days, 09:00${r}"
  echo -e "                ${arg}remind \"call mom\" today 18:00${r}      ${desc}today at 18:00${r}"
  echo -e "                ${arg}remind \"review PR\" 3${r}               ${desc}in 3 days, 09:00${r}"
  echo -e "                ${arg}remind \"ship 1.0\" 15.06.2026 14:00${r} ${desc}specific date${r}"
  echo -e "                ${arg}remind \"ship 1.0\" 20260615${r}         ${desc}YYYYMMDD${r}"
  echo -e "                ${d}date forms: today | <days> | DD.MM.YYYY | DD-MM-YYYY | YYYYMMDD${r}"
  echo -e "                ${d}time forms: HH:MM | HHMM${r}"
  echo

  echo -e "  ${y}${B}  Obsidian${r}"
  echo -e "  ${cmd}obs-note${r}      ${desc}append a line to today's daily note${r}"
  echo -e "                ${arg}obs-note \"fixed celery worker bug\"${r}"
  echo -e "                ${d}→ \"- HH:MM <text>\" appended to YYYY-MM-DD.md${r}"
  echo -e "                ${d}via Local REST API at https://127.0.0.1:27124${r}"
  echo
  echo -e "  ${cmd}obs-help${r}      ${desc}Obsidian Claude-skill cheatsheet${r}"
  echo
}

function osx_tools() {
  if [[ -n "$TMUX" ]]; then
    tmux display-popup -w 78 -h 22 -E "zsh -c 'source ~/.oh-my-zsh/custom/functions.zsh; _osx_tools_render; echo \"  Press any key to close.\"; read -sk1'"
  else
    _osx_tools_render
  fi
}

function _tmux_help_render() {
  emulate -L zsh
  setopt no_xtrace no_verbose extendedglob
  local B=$'\033[1m'
  local D=$'\033[2m'
  local C=$'\033[36m'
  local Y=$'\033[33m'
  local G=$'\033[32m'
  local M=$'\033[35m'
  local r=$'\033[0m'

  # --- formatting helpers (one entry / one section header per line) ---
  _tmh_e()  { print -r -- "  ${G}${(r:13:)1}${r}$2"; }   # key padded to 13, then desc
  _tmh_h()  { print -r -- "  ${B}${Y}$1${r}"; }          # yellow section header
  # visible length: strip ANSI SGR escapes, then count
  _tmh_vlen() { local s=${1//$'\033'\[[0-9;]#m/}; print -r -- ${#s}; }
  # print $1 left-padded with spaces to a *visible* width of $2 (ANSI-aware)
  _tmh_pad()  { local p=$(( $2 - $(_tmh_vlen "$1") )); (( p < 0 )) && p=0; printf '%s%*s' "$1" "$p" ''; }

  # --- left column: Panes / Windows / Sessions ---
  local -a L
  L+=( "$(_tmh_h Panes)" )
  L+=( "$(_tmh_e h 'Split horizontal (top/bottom)')" )
  L+=( "$(_tmh_e v 'Split vertical (side by side)')" )
  L+=( "$(_tmh_e z 'Zoom / unzoom pane')" )
  L+=( "$(_tmh_e x 'Kill pane')" )
  L+=( "$(_tmh_e '!' 'Break pane into own window')" )
  L+=( "$(_tmh_e Space 'Cycle pane layouts')" )
  L+=( "$(_tmh_e q 'Show pane numbers -> jump')" )
  L+=( "$(_tmh_e ': swap' 'Show pane numbers')" )
  L+=( "$(_tmh_e ': swap N' 'Swap current pane with N')" )
  L+=( "$(_tmh_e ': swap A B' 'Swap pane A with pane B')" )
  L+=( "" )
  L+=( "$(_tmh_h Windows)" )
  L+=( "$(_tmh_e c 'New window')" )
  L+=( "$(_tmh_e '&' 'Kill window')" )
  L+=( "$(_tmh_e ',' 'Rename window')" )
  L+=( "$(_tmh_e 1-9 'Switch to window N')" )
  L+=( "$(_tmh_e 'n / p' 'Next / previous window')" )
  L+=( "" )
  L+=( "$(_tmh_h Sessions)" )
  L+=( "$(_tmh_e t 'Sesh session picker')" )
  L+=( "$(_tmh_e s 'List sessions (tree view)')" )
  L+=( "$(_tmh_e w 'Tree: sessions + windows')" )
  L+=( "$(_tmh_e '$' 'Rename session')" )
  L+=( "$(_tmh_e d 'Detach')" )

  # --- right column: Save/Restore / Copy Mode / Other / No Prefix ---
  local -a R
  R+=( "$(_tmh_h 'Save / Restore')" )
  R+=( "$(_tmh_e C-s 'Save session (resurrect)')" )
  R+=( "$(_tmh_e C-r 'Restore session (resurrect)')" )
  R+=( "" )
  R+=( "  ${B}${Y}Copy Mode ${D}(vi keys)${r}" )
  R+=( "$(_tmh_e '[' 'Enter copy mode')" )
  R+=( "$(_tmh_e ']' 'Paste buffer')" )
  R+=( "$(_tmh_e / 'Search forward')" )
  R+=( "$(_tmh_e 'n / N' 'Next / previous match')" )
  R+=( "$(_tmh_e v 'Begin selection')" )
  R+=( "$(_tmh_e C-v 'Rectangle selection')" )
  R+=( "$(_tmh_e y 'Yank (copy + exit)')" )
  R+=( "" )
  R+=( "$(_tmh_h Other)" )
  R+=( "$(_tmh_e p 'Floating terminal (floax)')" )
  R+=( "$(_tmh_e r 'Reload config')" )
  R+=( "$(_tmh_e ':' 'Command prompt')" )
  R+=( "$(_tmh_e '?' 'This cheat sheet (tmux)')" )
  R+=( "$(_tmh_e / 'Cheat sheets (helpers)')" )
  R+=( "" )
  R+=( "  ${B}${M}No Prefix Needed${r}" )
  R+=( "$(_tmh_e 'Alt+Arrows' 'Switch panes')" )
  R+=( "$(_tmh_e 'Shift+L/R' 'Prev / next window')" )
  R+=( "$(_tmh_e 'Alt+H / L' 'Prev / next window')" )
  R+=( "$(_tmh_e 'Ctrl+h/j/k/l' 'Switch panes (vim-nav)')" )

  print
  print -r -- "  ${B}${C}Tmux Cheat Sheet ${D}(prefix = Ctrl+Space)${r}"
  print

  local LW=50                       # left-column visible width
  # Two columns only when the popup is wide enough; otherwise stack them.
  if (( ${COLUMNS:-80} >= 94 )); then
    local i n=$(( ${#L} > ${#R} ? ${#L} : ${#R} ))
    for (( i = 1; i <= n; i++ )); do
      _tmh_pad "${L[i]:-}" $LW
      print -r -- "${R[i]:-}"
    done
  else
    local l
    for l in "${L[@]}"; do print -r -- "$l"; done
    print
    for l in "${R[@]}"; do print -r -- "$l"; done
  fi

  print
  print -r -- "  ${D}prefix + : then \"list-keys\" for built-in full key list${r}"

  unfunction _tmh_e _tmh_h _tmh_vlen _tmh_pad 2>/dev/null
}

# Tabbed popup combining tmux help + osx_helpers + osx_tools.
# Bound to `prefix + ?` (tmux tab) and `prefix + /` (helpers tab) in ~/.tmux.conf.
# Tabs: 1 Tmux, 2 Helpers, 3 Tools. Keys: 1/2/3 jump, Tab/h/l cycle, q/Esc close.
_cheatsheets_popup() {
  emulate -L zsh
  setopt no_xtrace no_verbose
  local tab="${1:-1}"
  local key
  local dim=$'\033[2;37m'
  local r=$'\033[0m'

  while true; do
    # Cursor home + erase screen + erase scrollback (xterm/tmux ext).
    printf '\033[H\033[2J\033[3J'

    case "$tab" in
      1) _tmux_help_render ;;
      2) _osx_helpers_render ;;
      3) _osx_tools_render ;;
    esac

    print
    print -r -- "  ${dim}[1] tmux  [2] helpers  [3] tools   [q/Esc] close${r}"

    read -sk1 key
    case "$key" in
      1) tab=1 ;;
      2) tab=2 ;;
      3) tab=3 ;;
      $'\t'|l) tab=$(( tab % 3 + 1 )) ;;
      h)       tab=$(( (tab + 1) % 3 + 1 )) ;;
      q|$'\e'|$'\n') printf '\033[H\033[2J\033[3J'; break ;;
    esac
  done
}

alias bathelp='bat --plain --language=help'
help() {
  "$@" --help 2>&1 | bathelp
}

function echo_yellow() {
    echo -e "${yellow}$1${nocolor}"
}

function validate_input() {
    if [[ -z "$1" ]]; then
        echo_yellow "$2"
        return 1
    fi
    return 0
}

disappointed() { echo -n " ಠ_ಠ " | tee >(pbcopy) > /dev/tty; echo;}

flip() { echo -n "（╯°□°）╯ ┻━┻" | tee >(pbcopy) > /dev/tty; echo;}

shrug() { echo -n "¯\_(ツ)_/¯" | tee >(pbcopy) > /dev/tty; echo;}

# original fpr linux system
# matrix() { echo -e "\e[1;40m" ; clear ; while :; do echo $LINES $COLUMNS $(( $RANDOM % $COLUMNS)) $(( $RANDOM % 72 )) ;sleep 0.05; done|awk '{ letters="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@#$%^&*()"; c=$4;        letter=substr(letters,c,1);a[$3]=0;for (x in a) {o=a[x];a[x]=a[x]+1; printf "\033[%s;%sH\033[2;32m%s",o,x,letter; printf "\033[%s;%sH\033[1;37m%s\033[0;0H",a[x],x,letter;if (a[x] >= $1) { a[x]=0; } }}' }
pmatrix() {
    echo -e "\033[1;40m"
    clear
    while :; do
        echo $LINES $COLUMNS $(( RANDOM % COLUMNS)) $(( RANDOM % 72 ))
        sleep 0.05
    done | awk '
    {
        letters="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@#$%^&*()";
        c=$4;
        letter=substr(letters,c,1);
        a[$3]=0;
        for (x in a) {
            o=a[x];
            a[x]=a[x]+1;
            printf "\033[%s;%sH\033[2;32m%s", o, x, letter;
            printf "\033[%s;%sH\033[1;37m%s\033[0;0H", a[x], x, letter;
            if (a[x] >= $1) {
                a[x]=0;
            }
        }
    }'
}

move_untracked() {
    if [ $# -eq 0 ]; then
        echo "Usage: move_untracked <target_directory>"
        return 1
    fi

    target_dir="$1"
    
    if [ ! -d "$target_dir" ]; then
        echo "Error: $target_dir is not a valid directory"
        return 1
    fi

    untracked_files=$(git status --porcelain | grep '^??' | cut -c4-)
    
    if [ -z "$untracked_files" ]; then
        echo "No untracked files found."
        return 0
    fi

    echo "$untracked_files" | xargs -I {} mv {} "$target_dir"
    echo "Untracked files moved to $target_dir"
}

# copy, keep source
move() {
  if [ "$#" -lt 2 ]; then
    echo "usage: move SRC... DEST" >&2
    echo "  trailing slash on SRC matters: 'dir/' copies contents, 'dir' copies the dir itself" >&2
    return 1
  fi
  rsync -avh --partial --progress "$@"
}

# move = copy then delete source files + empty dirs
movedelete() {
  if [ "$#" -lt 2 ]; then
    echo "usage: movedelete SRC... DEST" >&2
    echo "  trailing slash on SRC matters: 'dir/' copies contents, 'dir' copies the dir itself" >&2
    return 1
  fi
  rsync -avh --partial --progress --remove-source-files "$@" || return 1

  # rsync leaves empty dirs -> prune them from each SRC
  local src
  for src in "${@:1:$#-1}"; do
    [ -d "$src" ] && find "$src" -type d -empty -delete
  done
}

function process_kill() {
    ps aux | fzf --height 40% --layout=reverse --prompt="Select process to kill: " | awk '{print $2}' | xargs -r sudo kill
}
alias kill_process=process_kill

function git_last_branches() {
  # local selected_branch=$(
  #   for k in `git branch | perl -pe s/^..//`; do
  #     echo -e `git show --pretty=format:"%Cgreen%ci %Cblue%cr%Creset" $k -- | head -n 1`\\t$k;
  #   done |
  #   sort -r |
  #   head -20 |
  #   fzf --height 60% --layout=reverse --prompt="Select a branch " |
  #   awk '{print $NF}'
  # )

  local selected_branch=$(
    git for-each-ref --sort=-committerdate --format='%(committerdate:short) %(refname:short)' refs/heads/ |
    sort -r |
    head -100 |
    fzf --height 60% --layout=reverse --prompt="Select a branch " |
    awk '{print $NF}'
  )

  if [[ -n "$selected_branch" ]]; then
    # echo -e "$selected_branch\n"
    git checkout "$selected_branch"
  else
    echo -e "\nno branch selected\n"
  fi
}
alias lastbranches=git_last_branches
alias gitlastbranches=git_last_branches


function glog() {
    git lg | fzf --ansi --no-sort \
        --preview 'echo {} | grep -o "[a-f0-9]\{7\}" | head -1 | xargs -I % git show % --color=always' \
        --preview-window=right:50%:wrap --height 100% \
        --bind 'enter:execute(echo {} | grep -o "[a-f0-9]\{7\}" | head -1 | xargs -I % sh -c "git show % | nvim -c \"setlocal buftype=nofile bufhidden=wipe noswapfile nowrap\" -c \"nnoremap <buffer> q :q!<CR>\" -")' \
        --bind 'ctrl-e:execute(echo {} | grep -o "[a-f0-9]\{7\}" | head -1 | xargs -I % sh -c "gh browse %")' \
}

# Open a debugging shell within a Kubernetes pod
function kcdebug() {
  kubectl run -i --rm --tty debug --image=busybox --restart=Never -- sh
}

function log_file_merger () {

	if [ -z "$1" ]; then
		echo -e "phpsessid?\n"
		return
	fi

	if [ -z "$2" ]; then
		echo -e "prefix for the merged file? eg. kdnr-username\n"
		return
	fi

  grep -hl $1 * | log_merger $2 $1
}

# wrapper example
# peag_k_dev_wrapper() {
#     if is_kk_vpn_active; then
#         kubectl --context m-k8s-dev -n peag-dev "$@"
#     else
#         echo -e "${yellow}Error: VPN is not active. Please connect to the VPN first.${nocolor}\n"
#         return 1
#     fi
# }



# scutil --nc list
# Available network connection services in the current set (*=enabled):
# * (Connected)      288CC86D-B8CD-4A55-A0D9-786F9E1C9B29 VPN (com.fortinet.forticlient.macos.vpn) "VPN"                            [VPN:com.fortinet.forticlient.macos.vpn]
is_kk_vpn_active() {
    # True if scutil shows an enabled (*) Fortinet VPN with status "(Connected)".
    # Pass -v to print status (silent by default for use in `if` conditionals).
    if scutil --nc list 2>/dev/null | grep -qiE '^\*[[:space:]]+\(Connected\).*fortinet'; then
        [ "${1:-}" = "-v" ] && echo "VPN: connected"
        return 0
    fi
    [ "${1:-}" = "-v" ] && echo "VPN: not connected"
    return 1
}


is_kk_vpn_active_old() {
    if get_utun_devices | grep -qE "10.212.134"; then
        return 0
    fi
    return 1
}

get_utun_devices() {
  ifconfig | awk '/^utun/,/^\s*$/' | awk '/^utun/ {dev=$1} /inet / {print dev, $2}' | sed 's/:$//'
}

function how_to_dns() {
cat <<-END
    1. Install dnsmasq:

      brew install dnsmasq

    2. Create a configuration file:

      mkdir -p $(brew --prefix)/etc/
      echo 'address=/.docker/127.0.0.1' >> $(brew --prefix)/etc/dnsmasq.conf

    3. Start dnsmasq:

      sudo brew services start dnsmasq

    4. Configure macOS to use dnsmasq. Create a new DNS resolver:

      sudo mkdir -p /etc/resolver
      echo 'nameserver 127.0.0.1' | sudo tee /etc/resolver/docker

    5. Find your Mac's IP address:

      ifconfig | grep "inet " | grep -v 127.0.0.1

      * Note the IP address (e.g., 192.168.1.10)

    6. Set your Mac's IP address as a secondary DNS server in your router's settings.

       (local, no router) WLAN > Details > DNS > DNS Server
              ex.  192.168.2.1
                   192.168.2.31    <-- yours

    7. Configure Android:

      Go to Wi-Fi settings
      Long-press your connected network
      Modify network
      Change IP settings to "Static"
      Set DNS 1 to your Mac's IP address

    8. In your docker-compose.yml or Docker run command, add under your service:

        extra_hosts:
          - "host.docker.internal:host-gateway"

    9. Test
      
        ping project.docker

END
}

function how_to_notify () {
  cat <<-END
    osascript -e 'display notification "You have a new email" with title "Email Notification"'

    terminal-notifier -message "You have a new email" -title "Email Notification"

END
  echo
}

function how_to_github() {
  cat <<-END

  check if your credentials are set correctly:

  ssh -T git@github.com

     is the user okay? no? check what you have in ~/.ssh/config for github

  update your git configuration if needed:
     git config [--global] user.name "john"
     git config [--global] user.email "john@email.com"

-----------------------------------------------------------

  Set the correct remote for your directory
  Having this in your .ssh/config:

      # Account 1: Default GitHub account
      Host github-account1
        HostName github.com
        User git
        IdentityFile ~/.ssh/id_ed25519_github_account1

      # Account 2: Second GitHub account
      Host github-account2
        HostName github.com
        User git
        IdentityFile ~/.ssh/id_ed25519_github_account2

  set your remote as: 

      git remote set-url origin git@github-account1:username/repository.git

  maybe you will still need to add your add to ssh

      ssh-add ~/.ssh/id_ed25519_github_account_2
END
echo
}

# Switch the active GitHub CLI (gh) account.
#   ghuser            -> toggle to the other configured account
#   ghuser <name>     -> switch to that account
#   ghuser -l|--list  -> list configured accounts
function ghuser() {
  if [[ "$1" == "-l" || "$1" == "--list" ]]; then
    gh auth status 2>&1 | grep -E 'account|Active account'
    return
  fi

  if [[ -n "$1" ]]; then
    gh auth switch --user "$1"
    return
  fi

  # No arg: toggle to the other account.
  local active others target
  active=$(gh auth status --active 2>/dev/null | grep -oE 'account [^ ]+' | awk '{print $2}' | head -1)
  others=$(gh auth status 2>/dev/null | grep -oE 'account [^ ]+' | awk '{print $2}' | grep -v "^${active}$")
  target=$(echo "$others" | head -1)

  if [[ -z "$target" ]]; then
    echo "ghuser: no other account to switch to (active: ${active:-none})" >&2
    return 1
  fi

  gh auth switch --user "$target"
}
alias guser=ghuser
alias switch-user=ghuser
alias gituser=ghuser

# Discover Bonjour/mDNS printers on the LAN and print Name + IPv4 + service.
# dns-sd streams forever, so each call is time-boxed (tune via env vars):
#   BROWSE_SECS=5 find_printers
function find_printers() {
  command -v dns-sd >/dev/null 2>&1 || { echo "dns-sd not found (macOS only)." >&2; return 1; }

  local BROWSE_SECS="${BROWSE_SECS:-3}" RESOLVE_SECS="${RESOLVE_SECS:-2}"
  local SERVICES=(_ipp._tcp _ipps._tcp _pdl-datastream._tcp _printer._tcp)
  # Substring/regex of the printer to highlight (the one you usually use).
  local HIGHLIGHT="${PRINTER_HIGHLIGHT:-M775}"
  local HL='' HLOFF=''
  [[ -t 1 ]] && { HL=$'\e[1;32m'; HLOFF=$'\e[0m'; }   # bold green on a TTY

  # Run a streaming command for N seconds, then stop it.
  local _dsd
  _dsd() {
    local secs="$1"; shift
    "$@" & local pid=$!
    ( sleep "$secs"; kill "$pid" 2>/dev/null ) >/dev/null 2>&1 &
    wait "$pid" 2>/dev/null
  }

  echo "Browsing for printers (~$(( BROWSE_SECS * ${#SERVICES[@]} ))s)…" >&2

  # 1) Collect "service<TAB>instance" pairs.
  local found=() svc line inst
  for svc in "${SERVICES[@]}"; do
    while IFS= read -r line; do
      [[ "$line" == *" Add "* ]] || continue
      inst="${line#*"${svc}". }"
      inst="${inst#"${inst%%[![:space:]]*}"}"
      [[ -n "$inst" ]] && found+=("${svc}	${inst}")
    done < <(_dsd "$BROWSE_SECS" dns-sd -B "$svc" local.)
  done

  if [[ ${#found[@]} -eq 0 ]]; then
    echo "No Bonjour printers found." >&2
    return 0
  fi

  # 2) Resolve instance -> host -> IPv4, dedupe by IP.
  local seen=" " entry host ip l g
  printf "\n%-38s %-16s %s\n" "PRINTER" "IP" "SERVICE"
  printf '%.0s-' $(seq 1 72); echo
  for entry in "${found[@]}"; do
    svc="${entry%%	*}"; inst="${entry#*	}"

    host=""
    while IFS= read -r l; do
      if [[ "$l" == *"can be reached at"* ]]; then
        host="${l#*can be reached at }"; host="${host%%:*}"; host="${host%.}"
        break
      fi
    done < <(_dsd "$RESOLVE_SECS" dns-sd -L "$inst" "$svc" local.)
    [[ -z "$host" ]] && continue

    ip=""
    while IFS= read -r g; do
      if [[ "$g" == *" Add "* ]]; then
        ip="$(printf '%s\n' "$g" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)"
        [[ -n "$ip" ]] && break
      fi
    done < <(_dsd "$RESOLVE_SECS" dns-sd -G v4 "${host}.")
    [[ -z "$ip" ]] && continue

    case "$seen" in *" $ip "*) continue;; esac
    seen="$seen$ip "
    if [[ -n "$HIGHLIGHT" && "$inst" == *"$HIGHLIGHT"* ]]; then
      printf "${HL}%-38s %-16s %s  ◀ preferred${HLOFF}\n" "$inst" "$ip" "$svc"
    else
      printf "%-38s %-16s %s\n" "$inst" "$ip" "$svc"
    fi
  done
}
alias printers=find_printers
alias find:printers=find_printers

function how_to_password_php() {
  cat <<-END
    start an interactive shell in php

    $ php -a

    php > echo password_hash("mySecurePassword123", PASSWORD_BCRYPT, ["cost" => 10]);
    $2y$10$NPcwP6rJ7xV9o38onEzpZO6EOUubRrY345YeUXaLBT/utT87fdS6y

END
  echo
}

function how_to_copy_files_android() {
  cat <<-END

  adb -s 2c63d1970b037ece pull /storage/0000-0000/Diverse/ /Volumes/SamsungS9/Card
      copy the directory Diverse to directory Card of a mounted volume.

END
  echo
}

function how_to_typescript() {
  cat <<-END
  create a projects folder

  npm init -y

  npm install --save-dev typescript

   create a basic tsconfig.json file
   {
      "compilerOptions": {
          "target": "ES6",
          "module": "commonjs",
          "outDir": "dist"
      }
   }

  compile:    npx tsc
  run:        node dist/app.js

END
echo

}

function how_to_rename_multiple_files() {
  cat <<-END
  for multiple files named like: peag-production_962bd674-79b7-408c-86dc-7ec6d8cd5c81_origin.jpeg

  $ for file in peag-production_*; do mv "$file" "${file#peag-production_}"; done

  That line will remove the prefix of the file(s).

END
}

function how_to_rename_multiple_files_2 {
  cat <<-END

  add a prefix to all files in the current folder
  $ for file in *; do [ -e "$file" ] && mv "$file" "prefix_$file"; done

  to rename all files which does not start with 3A and add a prefix to them
  $ for file in *; do [[ "$file" != 3A* ]] && mv "$file" "prefix_$file"; done

  the same but starting with...
  $ for file in *; do [[ "$file" == 3A* ]] && mv "$file" "prefix_$file"; done

END
echo
}

function java_show_env() {
    echo -e "\nJAVA_HOME=$JAVA_HOME"
    echo -e "ANDROID_BUILD_TOOLS=$ANDROID_BUILD_TOOLS"
    echo -e "ANDROID_HOME=$ANDROID_HOME"
    echo -e "ANDROID_SDK_ROOT=$JAVA_HOME"
    echo -e "\nPaths:\n"
    echo -e "$JAVA_HOME/bin"
    echo -e "$ANDROID_HOME/tools/bin"
    echo -e "$ANDROID_HOME/platform-tools"
    echo -e "$ANDROID_HOME/emulator"
    echo -e "$ANDROID_HOME/build-tools/29.0.3\n"
}

function git_not_merged() {
    for branch in `comm -12  <(git branch --no-merged|awk '{print($1)}') <(git branch -r --no-merged|awk '{print($1)}'|awk -F \/ '{print($2)}')`; do echo -e `git show --format="%ci %cr %an" $branch | head -n 1` \\t$branch; done | sort -r
}

function git_commits_by_date() {
    TODAY=0
    case $1 in
        today)
            DATUM=`date +"%Y-%m-%d"`
            echo -e "${yellow}Using Todays's date (given)${nocolor}\n"
            TODAY=1
            ;;
        yesterday)
            DATUM=`date -v-1d +"%Y-%m-%d"`
            echo -e "${yellow}Using YESTERDAY date${nocolor}\n"
            ;;
        -1)
            DATUM=`date -v-1d +"%Y-%m-%d"`
            echo -e "${yellow}Using YESTERDAY date${nocolor}\n"
            ;;
        -2)
            DATUM=`date -v-2d +"%Y-%m-%d"`
            echo -e "${yellow}Using before yesterday's date${nocolor}\n"
            ;;
        *)
            # echo -e "${yellow}checking date${nocolor}: $2\n"
            if [[ $1 =~ ^20[0-9]{2}-(0|1)[0-9]-((0|1|2)[0-9]|3[0-1])$ ]]; then
                DATUM=$1
                echo -e "${yellow}Using given date${nocolor}\n"
            else
                DATUM=`date +"%Y-%m-%d"`
                TODAY=1
                echo -e "${yellow}Using Todays's date (Default)${nocolor}\n"
            fi
            ;;
    esac

    # echo -e "${yellow}$DATUM${nocolor}\n"

    git --no-pager log --oneline --after="${DATUM} 00:00" --before="${DATUM} 23:59" --pretty=format:"%C(yellow)%h %C(cyan)%ad%C(red)%d %C(reset)%s%C(green) [%cn]" --decorate --date=short
}


function get_secured_hash() {
  echo -e "If dont give me a length, the default is 16 bytes which creates a secure hashed string of 32 chars\n"
#	if [ -z "$1" ]; then
#	  BYTES=16
#  else
#    BYTES=$1
#  fi

  local num_bytes=${i:-16}
  python -c "import secrets; print(secrets.token_hex($num_bytes))"
}

get_password() {
  if [ -z "$1" ]; then
    echo "Usage: hash_password <password>"
    return 1
  fi

  hashed_password=$(php -r "echo password_hash('$1', PASSWORD_BCRYPT, ['cost' => 10]);")
  echo "$hashed_password" | tr -d '\n' | pbcopy
  echo "Password hash copied to clipboard: $hashed_password"
}
alias passw=get_password

verify_password() {
  if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: verify_password <password> <hash>"
    return 1
  fi

  result=$(php -r "echo password_verify('$1', '$2') ? 'true' : 'false';")
  if [ "$result" = "true" ]; then
    echo "Password is valid"
  else
    echo "Password is invalid"
  fi
}


function get_password_2() {
  echo -e "create a bcrypt password with php. to verify it use password_vertify yourpasw yourhash\n"
	if [ -z "$1" ]; then
		echo -e "what should I convert to a hashed string.\n"
		return
	fi

  # echo password_hash("Rx34guoAA", PASSWORD_BCRYPT, ["cost" => 10]);

	HASHED=$(php -r 'print password_hash("$1",1);')
	#echo -e "$HASHED\n"
	echo $HASHED | tr -d '\n' | pbcopy
        echo -e "(copied)\n$HASHED\n"
}

function password_verify_2() {

	if [ -z "$1" ]; then
		echo -e "password\n"
		return
	fi

	if [ -z "$2" ]; then
		echo -e "and the hash?\n"
		return
	fi

	PASSWORD=$1
	HASH=$2
	RESULT=$(php -r 'print password_verify("$PASSWORD","$HASH") ? "OK":"FALSE";')
	echo -e "Using $PASSWORD with Hash $HASH\n"
	echo -e "$RESULT\n"

}

function replace_in_files () {
    echo -e "Case sensitive Search and Replace function."
    echo -e "\treplace_in_files ${yellow}StringToSearchFor${nocolor} ${green}StringToReplaceWith${nocolor}"

    if [ -z "$1" ]; then
        echo -e "\nFirst Argument is missing!"
        return
    fi
    SEARCH=$1

    if [ -z "$2" ]; then
        echo -e "\nSecond Argument is missing"
        return
    fi
    REPLACE=$2

    #OSX version. In Linux you just need  sed -i "s/s1/s2/g"
    find . -type f -exec sed -i '' -e "s/$SEARCH/$REPLACE/g" {} \;
}

function grep_accesslog() {
    if [ -z "$1" ]; then
        echo -e "\nwhat is the string to looooooook for?\n"
        return
    fi
    # SORT_AND_FILTER=0
    # if [ -z "$2" ]; then
    #     SORT_AND_FILTER=1
    # fi


    echo -e "\nlooking for filenames containing access_log in their names - Staging files are not included!\n"

    # if [[ "$SORT_AND_FILTER" == 1 ]]; then
    #     echo -e "please wait few seconds, matches are being filtered and sorted\n\n"
    #     grep --color="always"  " $1 " *access_log* | grep -v 'staging' | simple_log | cut -d' ' -f4 | sort -u
    # else
    #     echo -e "please wait few seconds, matches are being sorted\n\n"
    #     grep --color="always"  " $1 " *access_log* | grep -v 'staging' | simple_log | sort
    # fi

    case $1 in
        full)
            echo -e "please wait few seconds, matches are being filtered and sorted\n\n"
            grep --color="always"  " $1 " *access_log* | grep -v 'staging' | simple_log | cut -d' ' -f4 | sort -u
            ;;
        2)
            echo -e "please wait few seconds, matches are being filtered and sorted\n\n"
            grep --color="always"  " $1 " *access_log* | grep -v 'staging' | simple_log | cut -d' ' -f1,4 | sort -u
            ;;
        staging)
            echo -e "please wait few seconds, matches are being filtered and sorted\n\n"
            grep --color="always"  " $1 " *access_log* | grep 'staging' | simple_log | cut -d' ' -f4 | sort -u
            ;;

        *)
            echo -e "please wait few seconds, matches are being sorted\n\n"
            grep --color="always"  " $1 " *access_log* | grep -v 'staging' | simple_log | sort
            ;;
    esac
}

function grep_accesslog_nofilename() {
    if [ -z "$1" ]; then
        echo -e "\nwhat is the string to looooooook for?\n"
        return
    fi
    # SORT_AND_FILTER=0
    # if [ -z "$2" ]; then
    #     SORT_AND_FILTER=1
    # fi

    echo -e "\nlooking for filenames containing access_log in their names - Staging files are not included!\n"
    echo -e "please wait few seconds, matches are being sorted\n\n"
    grep -h --color="always"  " $1 " *access_log* | grep -v 'staging' | simple_log | sort | cut -d ' ' -f1,3,4,5 | uniq -c
}

function grep_accesslog_all() {
    if [ -z "$1" ]; then
        echo -e "\nwhat is the string to looooooook for?\n"
        return
    fi
    SORT_AND_FILTER=0
    if [ -z "$2" ]; then
        SORT_AND_FILTER=1
    fi
    echo -e "\nlooking for filenames containing access_log in their names\n"

    if [[ "$SORT_AND_FILTER" == 1 ]]; then
        echo -e "please wait few seconds, matches are being filtered and sorted\n\n"
        grep --color="always"  " $1 " *access_log* | simple_log | cut -d' ' -f4 | sort -u
    else
        echo -e "please wait few seconds, matches are being sorted\n\n"
        grep --color="always"  " $1 " *access_log* | simple_log | sort
    fi
}

function analyze_this_log() {
    if [ -z "$1" ]; then
        echo -e "\nLog file is missing!"
        return
    fi
    # LANG=$LANG
    cat $1 | docker run --rm -i -e LANG=EN_en allinurl/goaccess -a -o html --log-format COMBINED - > report.html && open report.html
    #echo -e "\n${yellow}report.html${nocolor} has been created\n"
}

function merge_log_files() {
    # set -x
    if [ "$#" -lt 1 ]; then
        echo "Usage: $0 <needle> [result_log_filename]"
        return
    fi

    needle="$1"

    if [ "$#" -ge 2 ]; then
        result_log_file="$2_merged.log"
    else
        # Truncate the needle if it is too long for the file name
        truncated_needle=$(echo "$needle" | cut -c 1-20)  # Adjust the length as needed
        result_log_file="${truncated_needle}_merged.log"
    fi

    # delete zeto bytes files
    find . -type f -size 0 -exec rm {} \;

    # sorted_file_list=$(ls -t *"$needle"* 2>/dev/null)
    # sorted_file_list=$(find . -maxdepth 1 -type f -name "*$needle*" -exec stat -f "%m %N" {} \; | sort -n | cut -d" " -f2-)
    sorted_file_list=$(ls -1 "$needle"* | sed '/access_log$/s/$/a/' | sort -t- -k2,2n -k1,1 | sed 's/a$//')

    if [ -z "$sorted_file_list" ]; then
        echo "No matching files found."
        return
    fi

    echo "$sorted_file_list"
    echo "Preparing to loop list files"
    echo "--------------------------------"
    # sorted_file_list="$sort_file_list\n"

    # Create an empty merged log file
    echo -e "creating log file $result_log_file\n"
    touch "$result_log_file"

    echo "$sorted_file_list" | while IFS= read -r file; do
        echo "Processing file: $file"
        if [ -e "$file" ]; then
            file_size=$(du -h "$file" | cut -f1)
            echo "File size of $file: $file_size."

            # Check if file_size is a valid integer
            if [[ "$file_size" =~ ^[0-9]+$ ]]; then
                echo "File size of $file: $file_size bytes"

                if [ "$file_size" -gt 0 ]; then
                    echo "Merging $file into $result_log_file"
                    cat "$file" >> "$result_log_file"
                    echo "Merged $file into $result_log_file"
                else
                    echo "Warning: $file is empty and was skipped."
                fi
            else
                echo "Warning: Unable to determine the file size of $file. Skipping."
            fi
        else
            echo "Warning: $file does not exist and was skipped."
        fi
    done

    echo -e "\nFiles merged successfully into $result_log_file\n"
}

function concatenate_log_files {
    local needle="$1"
    local combined_file

    if [[ $# -eq 2 ]]; then
        combined_file="$2"
    else
        # Truncate the needle to 15 characters for the combined file name
        combined_file=${needle:0:15}
    fi

    touch "$combined_file"

    echo -e "\nUsing combined file name: $combined_file\n"

    # Find all log files matching the specified format
    local files=$(find . -type f -name "${needle}-access_log*")

    echo -e "files:\n$files"
    echo -e "\n----------------------------------------------------------------\n"
    sorted_file_list=$(ls -1 "$needle"* | sed '/access_log$/s/$/a/' | sort -t- -k2,2n -k1,1 | sed 's/a$//')
    echo "$sorted_file_list"
    echo -e "\n----------------------------------------------------------------\n"
    sorted_files_clean=$(echo -e "$sorted_file_list" | tr '\n' ' ')
    echo "[$sorted_files_clean]"
    echo -e "\n----------------------------------------------------------------\n"
    final_file_list=$(echo "$sorted_files_clean" | sed 's/ *$//')
    echo "[$final_file_list]"
    echo -e "\n----------------------------------------------------------------\n"

    # Concatenate the sorted log files into the combined file
    echo -e "cat $final_file_list > $combined_file\n"
    # cat $final_file_list > "$combined_file"
    # for file in $final_file_list; do
    #     # Concatenate the current file to the combined file
    #     cat "$file" >> "$combined_file"
    # done
}


#
# Zend Framework 2
# ZF2
#

# function zf2addmodule () {
#     if [ -z "$1" ]; then
#         echo -e "${red}Error!${nocolor} need the name of your module"
#         return
#     fi
#     MODULENAME = $1
#     mkdir -pv $MODULENAME/{config,src/$MODULENAME/{Controller,Form,Model},view/${MODULENAME,,}/${MODULENAME,,}}
# }

function zf3_addmodule () {
    if [ -z "$1" ]; then
        echo -e "${red}Error!${nocolor} need the name of your module"
        return
    fi
    MODULENAME=$1
    MODULENAMELOWER=$(echo $1 | tr '[:upper:]' '[:lower:]')

    echo "Creating Module $MODULENAME in current folder\n"
    mkdir -pv $MODULENAME/{.templates,Handler,Rbac,Service}
    echo "Creating empty files\n"
    touch ./$MODULENAME/ConfigProvider.php
    touch ./$MODULENAME/.templates/index.phtml
    touch ./$MODULENAME/Handler/${MODULENAME}Handler.php
    touch ./$MODULENAME/Rbac/Permissions${MODULENAME}.php
    touch ./$MODULENAME/Service/${MODULENAME}Service.php

    echo "<?php

declare(strict_types=1);

namespace PresseGrosso\\${MODULENAME};

use PresseGrosso\App\Rbac\Role;
use PresseGrosso\\${MODULENAME}\Handler\\${MODULENAME}Handler;
use PresseGrosso\\${MODULENAME}\Service\\${MODULENAME}Service;
use Zend\ServiceManager\AbstractFactory\ReflectionBasedAbstractFactory;

final class ConfigProvider
{
    public function __invoke(): array
    {
        return [
            'dependencies'  => \$this->getDependencies(),
            'templates'     => \$this->getTemplates(),
            'authorization' => \$this->getAuthorization(),
        ];
    }

    public function getDependencies(): array
    {
        return [
            'invokables' => [],
            'factories'  => [
                ${MODULENAME}Handler::class => ReflectionBasedAbstractFactory::class,
                ${MODULENAME}Service::class => ReflectionBasedAbstractFactory::class,
            ],
        ];
    }

    public function getTemplates(): array
    {
        return [
            'paths' => [
                '${MODULENAMELOWER}' => [__DIR__ . '/.templates'],
            ],
            'map'   => [
            ]
        ];
    }

    private function getAuthorization(): array
    {
        return [
            'permissions' => [
                Role::KDN => [
                ],
                Role::KD2 => [
                ],
                Role::SHP => [],
                Role::MOD => [],
                Role::VLG => [],
                Role::GSH => [],
            ]
        ];
    }
}" >> ./$MODULENAME/ConfigProvider.php

    echo "<?php

declare(strict_types=1);

namespace PresseGrosso\\${MODULENAME}\Handler;

use PresseGrosso\App\View\Helper\IsGranted;
use PresseGrosso\\${MODULENAME}\Rbac\Permissions${MODULENAME};
use PresseGrosso\\User\Model\Identity;
use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;
use Psr\Http\Server\RequestHandlerInterface;
use Zend\Expressive\Session\SessionMiddleware;
use Zend\Expressive\Template\TemplateRendererInterface;

final class ${MODULENAME}Handler implements RequestHandlerInterface
{
    /**
     * @var TemplateRendererInterface
     */
    private \$renderer;
    /**
     * @var IsGranted
     */
    private \$isGranted;

    public function __construct(TemplateRendererInterface \$renderer, IsGranted \$isGranted)
    {
        \$this->renderer  = \$renderer;
        \$this->isGranted = \$isGranted;
    }

    public function handle(ServerRequestInterface \$request) : ResponseInterface
    {
        \$session  = \$request->getAttribute(SessionMiddleware::SESSION_ATTRIBUTE);
        \$identity = Identity::fromSessionArray(\$session->get(Identity::class));

        return new HtmlResponse(
            \$this->renderer->render(
                '${MODULENAMELOWER}::index', []
            )
        );

    }
}" >> ./$MODULENAME/Handler/${MODULENAME}Handler.php

    echo "<?php

declare(strict_types=1);

namespace PresseGrosso\\${MODULENAME}\Service;

use PresseGrosso\Sentry\Service\SentryService;

final class ${MODULENAME}Service
{
    /** @var SentryService */
    protected \$sentry;

    public function __construct(SentryService \$sentry)
    {
        \$this->sentry = \$sentry;
    }
}" >> ./$MODULENAME/Service/${MODULENAME}Service.php

    echo "<?php

declare(strict_types=1);

namespace PresseGrosso\\${MODULENAME}\Rbac;

final class Permissions${MODULENAME}
{
    public const PERM_${MODULENAME}   = 'pg.${MODULENAMELOWER}';
}" >> ./$MODULENAME/Rbac/Permissions${MODULENAME}.php
    tree $MODULENAME
}

##
## Other goodies
##

function login(){
    if [ -z "$1" ]; then
       	echo -e "${red}Error!${nocolor} container name ismissing!"
       	return
    fi

    docker exec -ti $1 /bin/bash
}

function login_sh(){
    if [ -z "$1" ]; then
       	echo -e "${red}Error!${nocolor} container name ismissing!"
       	return
    fi

    docker exec -ti $1 /bin/sh
}


function login_ash(){
    if [ -z "$1" ]; then
       	echo -e "${red}Error!${nocolor} container name ismissing!"
       	return
    fi

    docker exec -ti $1 ash
}



function get_integrity_hash() {
    if [ -z "$1" ]; then
        echo -e "${red}Error!${nocolor} input file is missing!"
        return
    fi

    if [ -z "$2" ]; then
        echo -e "${yellow}Warning!${nocolor} using ${green}sha256${nocolor} as hashing algorithm!"
        echo -e "You could use, as a second parameter, a differet hash method like sha384 or md5."
        echo -e "for example:\t\$ get_integrity_hash mysuperjsfile.js sha384\n"
        ALG='sha256'
    else
        echo -e "${yellow}Warning!${nocolor} using ${green}$2${nocolor} as hashing algorithm!"
        ALG=$2
    fi

    # echo "cat $1 | openssl dgst -$ALG -binary | openssl enc -base64 -A\n"
    HASH=`cat "$1" | openssl dgst -$ALG -binary | openssl enc -base64 -A`
    echo -e "\n$ALG-$HASH\n"
}

function makepdf() {
    LAST_FILE=`find ~/Documents -type f -name "*.ibresponse" -print0 | xargs -0 stat -f "%m %N" | sort -rn | head -n 1 | cut -f2- -d" "`
    echo -e "using ${yellow}$LAST_FILE${nocolor}\n"
    echo -e "uncomment me out\n"
    # cd ~/kk/ib/ib-main/frontend
    # echo -e "${yellow}building CSS${nocolor}"
    # grunt compass
    # echo -e "Starting PDF Creation process"
    # cd ~/kk/ib/ib-main
    # python manage.py response_handling $LAST_FILE
    # echo -e "${green}It looks like it worked fine....isn't it?${nocolor}\n"
}

# MYSQL
function createdatabase() {
    if [ -z "$1" ]; then
        echo -e "${red}Error!${nocolor} Database name is missing!"
        return
    fi

    mysql -h localhost -u root -p -Bse "CREATE DATABASE IF NOT EXISTS $1 DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_general_ci;"
    echo -e "Database with name ${green}$1${nocolor} has been created!"
}

function syncibistruncate() {

    IBISTABLE=("E_ASSESSMENT" "E_ASSESSMENT_PAPER" "E_ASSESSMENT_ELEMENT" "E_ASSESSMENT_QIG")

    for i in ${IBISTABLE[@]};
    do
       echo -e "${cyan}Truncating table ibis.$i${nocolor}"
       mysql -h localhost -u root -p -Bse "SET FOREIGN_KEY_CHECKS=0;TRUNCATE ibis.$i;SET FOREIGN_KEY_CHECKS=1;"
    done

}

function dbdump() {
    if [ -z "$1" ]; then
        echo -e "${red}Error!${nocolor} Database name is missing!"
        return
    fi

    DBNAME=$1

    if [ "`mysql -uroot -e 'show databases;' | grep -e ^${DBNAME}$`" == "${DBNAME}" ]; then
        DUMPTIME=$(date +%Y%m%d-%H%M)

        mysqldump -hlocalhost -uroot -p --databases --extended-insert --add-drop-table $1 > dump.$1.$DUMPTIME.sql
        echo -e "\nDump includes CREATE DATABASE if not exists, DROP TABLE if exists and extended inserts.\nNow look for ${yellow}dump.$1.$DUMPTIME.sql${nocolor}\n"
    else
        echo -e "\nI cannot find a database named ${yellow}$1${nocolor}!\n"
    fi
}

function makeIbSymlinks() {
    IB_DIR="/Users/patriciomoya/kk/ib/ib-main"
    DATA_DIR="$IB_DIR/data"
    REPO_DIR="$DATA_DIR/repositories"
    MEDIA_SOURCE="/media"
    MEDIA_TARGET="/media-srv"
    IFRAME_SOURCE="/iframe-content"
    IFRAME_TARGET="/iframe-srv"

    #prevent unmatched patters
    #If set, Bash allows filename patterns which match no files to expand to a null string, rather than themselves.
    # shopt -s nullglob
    DIRECTORY=("$REPO_DIR/*")

    cd "$DATA_DIR$MEDIA_TARGET"
    for i in ${DIRECTORY[@]};
    do
        UUID=`basename $i`
        if [ ! -L "$DATA_DIR$MEDIA_TARGET/$UUID" ]; then
            ln -s $i$MEDIA_SOURCE $UUID
        else
            echo -e "$DATA_DIR$MEDIA_TARGET/${cyan}$UUID${nocolor} already exists. Skipping"
        fi
    done

    cd "$DATA_DIR$IFRAME_TARGET"
    for i in ${DIRECTORY[@]};
    do
        UUID=`basename $i`
        if [ ! -L "$DATA_DIR$IFRAME_TARGET/$UUID" ]; then
            ln -s $i$IFRAME_SOURCE $UUID
        else
            echo -e "$DATA_DIR$IFRAME_TARGET/${cyan}$UUID${nocolor} already exists. Skipping"
        fi
    done

    # deactivate
    # shopt -u nullglob

    cd "$IB_DIR"
    echo "$MEDIA_TARGET"
    ls -la $DATA_DIR$MEDIA_TARGET
    echo "$IFRAME_TARGET"
    ls -la $DATA_DIR$IFRAME_TARGET
    echo "Done!"
}

function uuid(){
	  # UUID=˚python -c 'import uuid; print "(uuid4)\n%s\n" % uuid.uuid4()'˚
	  UUID=`python -c 'import uuid; print (uuid.uuid4())'`
    echo $UUID | tr -d '\n' | pbcopy
    echo -e "(uuid4)\n$UUID\n"
}

function json() {
    if [ -z "$1" ]; then
        echo "no filename provided"
        return
    fi

    # cat $1 | python -c "import json,sys;sys.stdout.write(json.dumps(json.load(sys.stdin)$2,indent=4)+'\n')";
    # you need to install Pygments first.    sudo pip install Pygments
    cat $1 | python -mjson.tool | pygmentize -l json
}

function unserialize() {
    if [ -z "$1" ]; then
        echo "no string provided"
        return
    fi
    # php -r 'echo unserialize("addslashes($1)");'
    php -r " echo var_dump(unserialize('"$1"')); echo \"\\n\";"
}

function get_placeholder_image() {
   cat <<-END
   https://placehold.co/
       https://placehold.co/600x400
       https://placehold.co/600x400/png
       https://placehold.co/600x400/000000/FFFFFF/svg
       https://placehold.co/600x400/orange/white
       https://placehold.co/600x400?text=Hello+World
       https://placehold.co/600x400?text=Hello\nWorld
       https://placehold.co/600x400?font=roboto
          Lato(Default) Lora Montserrat Open Sans Oswald Playfair
          Display PT Sans Raleway Roboto Source Sans Pro

END
echo
}

# function lorempixel {
#     if((!$#)); then
#        echo "lorempixel 1 10 name"
#        return
#     fi
#
#     for i in $(seq $1 $2);
#     do
#        curl http://lorempixel.com/640/480/$3/$i/ -o $3$i.jpg
#     done
# }

urlencode() {
    echo -n $1 | python -c "import urllib.parse;print (urllib.parse.quote(input()))"
}

urldecode() {
    echo -n $1 | python -c "import urllib.parse;print (urllib.parse.unquote(input()))"
}

# urlencode() {
#     # urlencode <string>
#     local length="${#1}"
#     for (( i = 0; i < length; i++ )); do
#         local c="${1:i:1}"
#         case $c in
#             [a-zA-Z0-9.~_-]) printf "$c" ;;
#             *) printf '%%%02X' "'$c"
#         esac
#     done
# }

# urldecode() {
#     # urldecode <string>

#     local url_encoded="${1//+/ }"
#     printf '%b' "${url_encoded//%/\\x}"
# }

function ibcreatetestpaper() {

    if [ -z "$1" ]; then
        echo -e "PAPERCODE is missing!"
        return
    fi

    if [ -z "$2" ]; then
        echo -e "YEAR is missing!"
        return
    fi

    if [ -z "$3" ]; then
        echo -e "SCHOOLCODE is missing!"
        return
    fi

    echo -e "\nPer default this eAssesment will be created for session ${green}$2${nocolor} for school ${green}$3${nocolor}."
    echo -e "Papercode is ${yellow}$1${nocolor}, the examination's time is ${yellow}10${nocolor} minutes"
    echo -e "Creating access codes for ${yellow}10${nocolor} candidates and ${yellow}10${nocolor} pirates"
    echo -e "Candidate code: ${yellow}800000${nocolor} - ${yellow}800009${nocolor}"
    echo -e "Pirate code: ${yellow}400000${nocolor} - ${yellow}400009${nocolor}"
    echo -e "Invigilator code: ${cyan}900001${nocolor}"
    echo -e "Invigilator Console code: ${cyan}A0000001${nocolor}"
    echo -e "Unlock code: ${cyan}1111${nocolor}"

    echo -e "\nExample:\n\t./manage.py create_testpaper --papercode visuaMINENGTZ0XXXX --year 2017 --school 888888 --num-cands 10 --exam-length 10"

    echo -e "\nYour line is:\n\t${orange}./manage.py create_testpaper --papercode $1 --year $2 --school $3 --num-cands 10 --exam-length 10${nocolor}\n"

}

function iblogin() {
    if [ -z "$1" ]; then
        echo "username is missing!"
        return
    fi

    COOKIEFILENAME='/var/tmp/ibcookies.txt'

    curl --header "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" --data "username=$1&password=$1" --cookie "csrftoken=FTfEOefDEiRwxMmH8YprO3nbPw60tooh" -H "X-CSRFToken: FTfEOefDEiRwxMmH8YprO3nbPw60tooh" --cookie-jar $COOKIEFILENAME -X POST http://localhost:8000/authentication/api_login/

    echo ""
}

#
# CONTROLLING
#
function control() {
    if [ -z "$1" ]; then
        echo "date is missing! <dd.mm.yyyy>"
        return
    fi
    if [ -z "$2" ]; then
        echo "task minutes are missing! <99> E.g.: 15"
        return
    fi
    if [ -z "$3" ]; then
        echo "and what task? "
        return
    fi

	case $1 in
		today)
			TARGETDATE=`date +"%d.%m.%Y"`
			;;
		yesterday)
			TARGETDATE=`date -v-1d +%d.%m.%Y`
			;;
		*)
			TARGETDATE=$1
	esac

}


function standup() {
    if [ -z "$1" ]; then
        echo "date is missing! <dd.mm.yyyy>"
        return
    fi
    if [ -z "$2" ]; then
        echo "task minutes are missing! <99> E.g.: 15"
        return
    fi

	case $1 in
		today)
			TARGETDATE=`date +"%d.%m.%Y"`
			;;
		yesterday)
			TARGETDATE=`date -v-1d +%d.%m.%Y`
			;;
		*)
			TARGETDATE=$1
	esac

	USERID=1216
	PROJID=194
	SUBPROJID=1979
	ACTIVITY=5

    curl -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" -X POST http://controlling.krankikom.de/submit.php --data "user_id=$USERID&datum=$TARGETDATE&dauer=$2&beschreibung=Stand+Up&projekt=$PROJID&subprojekt=$SUBPROJID&taetigkeit=$ACTIVITY"
	#echo "user_id=$USERID&datum=$TARGETDATE&dauer=$2&beschreibung=Stand+Up&projekt=$PROJID&subprojekt=$SUBPROJID&taetigkeit=$ACTIVITY"

}

function ibisexport() {
    // TODO
    if [ -z "$1" ]; then
        echo "date is missing! <dd.mm.yyyy>"
        return
    fi
    if [ -z "$2" ]; then
        echo "task minutes are missing! <99> E.g.: 15"
        return
    fi

	case $1 in
		today)
			TARGETDATE=`date +"%d.%m.%Y"`
			;;
		yesterday)
			TARGETDATE=`date -v-1d +%d.%m.%Y`
			;;
		*)
			TARGETDATE=$1
	esac

	USERID=1216
	PROJID=194
	SUBPROJID=1989
	ACTIVITY=3
	DESCRIPTION=Ibis+export
    if [[ $3 ]]; then
        DESCRIPTION=Ibis+Export+FE
    fi


    curl -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" -X POST http://controlling.krankikom.de/submit.php --data "user_id=$USERID&datum=$TARGETDATE&dauer=$2&beschreibung=$DESCRIPTION&projekt=$PROJID&subprojekt=$SUBPROJID&taetigkeit=$ACTIVITY"
	#echo "user_id=$USERID&datum=$TARGETDATE&dauer=$2&beschreibung=$DESCRIPTION&projekt=$PROJID&subprojekt=$SUBPROJID&taetigkeit=$ACTIVITY"
}


function pressegrosso() {
    if [ -z "$1" ]; then
        echo "date is missing! <dd.mm.yyyy>"
        return
    fi
    if [ -z "$2" ]; then
        echo "task minutes are missing! <99> E.g.: 15"
        return
    fi

	case $1 in
		today)
			TARGETDATE=`date +"%d.%m.%Y"`
			;;
		yesterday)
			TARGETDATE=`date -v-1d +%d.%m.%Y`
			;;
		*)
			TARGETDATE=$1
	esac

	USERID=1216
	PROJID=259
	SUBPROJID=2668
	ACTIVITY=3

    curl -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" -X POST http://controlling.krankikom.de/submit.php --data "user_id=$USERID&datum=$TARGETDATE&dauer=$2&beschreibung=&projekt=$PROJID&subprojekt=$SUBPROJID&taetigkeit=$ACTIVITY"
	#echo "user_id=$USERID&datum=$TARGETDATE&dauer=$2&beschreibung=Stand+Up&projekt=$PROJID&subprojekt=$SUBPROJID&taetigkeit=$ACTIVITY"
}

function controlling_peag() {
    if [ -z "$1" ]; then
        echo "date is missing! <dd.mm.yyyy>"
        return
    fi
    if [ -z "$2" ]; then
        echo "task minutes are missing! <99> E.g.: 15"
        return
    fi

	case $1 in
		today)
			TARGETDATE=`date +"%d.%m.%Y"`
			;;
		yesterday)
			TARGETDATE=`date -v-1d +%d.%m.%Y`
			;;
		*)
			TARGETDATE=$1
	esac

	USERID=1216
	PROJID=294
	SUBPROJID=3244
	ACTIVITY=1
    DESCRIPTION='PEAG'

curl -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" -X POST http://controlling.krankikom.de/submit.php --data "user_id=$USERID&datum=$TARGETDATE&dauer=$2&beschreibung=$DESCRIPTION&projekt=$PROJID&subprojekt=$SUBPROJID&taetigkeit=$ACTIVITY"
	#echo "user_id=$USERID&datum=$TARGETDATE&dauer=$2&beschreibung=Stand+Up&projekt=$PROJID&subprojekt=$SUBPROJID&taetigkeit=$ACTIVITY"
}

function controlling_qa() {
    if [ -z "$1" ]; then
        echo "date is missing! <dd.mm.yyyy>"
        return
    fi
    if [ -z "$2" ]; then
        echo "task minutes are missing! <99> E.g.: 15"
        return
    fi

	case $1 in
		today)
			TARGETDATE=`date +"%d.%m.%Y"`
			;;
		yesterday)
			TARGETDATE=`date -v-1d +%d.%m.%Y`
			;;
		*)
			TARGETDATE=$1
	esac

	USERID=1216
	PROJID=282
	SUBPROJID=3189
	ACTIVITY=3
    DESCRIPTION='QA-15'

curl -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" -X POST http://controlling.krankikom.de/submit.php --data "user_id=$USERID&datum=$TARGETDATE&dauer=$2&beschreibung=$DESCRIPTION&projekt=$PROJID&subprojekt=$SUBPROJID&taetigkeit=$ACTIVITY"
	#echo "user_id=$USERID&datum=$TARGETDATE&dauer=$2&beschreibung=Stand+Up&projekt=$PROJID&subprojekt=$SUBPROJID&taetigkeit=$ACTIVITY"
}

function einarbeitung() {
    if [ -z "$1" ]; then
        echo "date is missing! <dd.mm.yyyy>"
        return
    fi
    if [ -z "$2" ]; then
        echo "task minutes are missing! <99> E.g.: 15"
        return
    fi

    if [ -z "$3" ]; then
        echo "description"
        return
    fi

	case $1 in
		today)
			TARGETDATE=`date +"%d.%m.%Y"`
			;;
		yesterday)
			TARGETDATE=`date -v-1d +%d.%m.%Y`
			;;
		*)
			TARGETDATE=$1
	esac

    DESCRIPTION=$(urlencode "$3")

	USERID=1216
	PROJID=1
	SUBPROJID=135
	ACTIVITY=11

    curl -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" -X POST http://controlling.krankikom.de/submit.php --data "user_id=$USERID&datum=$TARGETDATE&dauer=$2&beschreibung=$DESCRIPTION&projekt=$PROJID&subprojekt=$SUBPROJID&taetigkeit=$ACTIVITY"
}


# OTHERS

# Returns a string in which the sequences with percent (%) signs followed by
# two hex digits have been replaced with literal characters.
function rawurldecode() {

  # This is perhaps a risky gambit, but since all escape characters must be
  # encoded, we can replace %NN with \xNN and pass the lot to printf -b, which
  # will decode hex for us

  printf -v REPLY '%b' "${1//%/\\x}" # You can either set a return variable (FASTER)

  echo "${REPLY}"  #+or echo the result (EASIER)... or both... :p
}

function hash_mac_openssl() {
    DIGEST=$1
    DATA=$2
    KEY=$3

    if [ -z "$1" ]; then
        DIGEST='sha256'
    fi
    if [ -z "$2" ]; then
        DATA='/2632bff7-be1a-4755-bf33-8308eadd1ea8/4081bf88-1785-403b-9616-ffff0f287f5b_thumb.jpg'
    fi
    if [ -z "$3" ]; then
        KEY='fwdkjh624fjwh32....'
    fi
    shift 3

    echo -e "using\n DIGEST:${yellow}$DIGEST${nocolor}\n   DATA:${yellow}$DATA${nocolor}\n    KEY:${yellow}$KEY${nocolor}\n"

    echo "Openssl:"

    echo -n "$DATA" | openssl dgst "-$DIGEST" -hmac "$KEY" "$@"
    echo -e "\nOpenssl Binary base64" && echo -n "$DATA" | openssl dgst "-$DIGEST" -hmac "$KEY" -binary | base64

    echo -e "\nPython:\n"
    # python -c "import hashlib, hmac; print 'digest(): %s' % hmac.new('$KEY', '$DATA'.encode('utf-8'), digestmod=hashlib.$DIGEST).digest()"
    python -c "import hashlib, hmac, base64; print '   digest() base64: %s' % base64.b64encode(hmac.new('$KEY', '$DATA'.encode('utf-8'), digestmod=hashlib.$DIGEST).digest())"
    # echo -e "\n"
    python -c "import hashlib, hmac; print '       hexdigest(): %s' %  hmac.new('$KEY', '$DATA'.encode('utf-8'), digestmod=hashlib.$DIGEST).hexdigest()"
    python -c "import hashlib, hmac, base64; print 'hexdigest() base64: %s' %  base64.b64encode(hmac.new('$KEY', '$DATA'.encode('utf-8'), digestmod=hashlib.$DIGEST).hexdigest())"

}


function dirsize() {
    echo "find . -type f -exec ls -l {} \; | awk '{sum += $5} END {print sum}'"
    S
    IZE=`find . -type f -exec ls -l {} \; | awk '{sum += $5} END {print sum}'`
    echo "$SIZE bytes"
}

function controlling_post() {
	USERID=1216
}

function ib-login-local() {
    curl --header "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" --data "password=12345" -X POST http://localhost:8000/response-upload/api/login/
	echo -e "login using password 12345\n"

}

function uploader() {
	URL='http://localhost:8000/response-upload/api/v1/specimenresponseuploader/'
	DATA='{username: "pato", school_code: 321, email: "pato@krankikom.de"}'
	HEADER="Content-Type: application/x-www-form-urlencoded; charset=UTF-8"
    TOKEN="VHQmYzQexI22k88dQijp8kkOvh7oCtSb"
    COOKIE="csrftoken=$TOKEN"
    CSRFTOKEN="X-CSRFToken: $TOKEN"
    XTOKEN="X-Token: something"

    echo -e "curl --header $HEADER --cookie $COOKIE -H $CSRFTOKEN -H $XTOKEN --data $DATA -X POST $URL"
    curl --header "$HEADER" --cookie "$COOKIE" -H "$CSRFTOKEN" -H "$XTOKEN" --data "$DATA" -X POST $URL --verbose
}

# function poster() {
#     URL='http://localhost:8000/response-upload/api/v1/specimenresponseuploader/'
#
#     BASETOKEN="5XOAZ0UK8lLbSlmZKEUGpvLaam1Uq5EN"
#     BASESESSIONID=".eJxVi0kKwyAUQO_iuojW6Ztl9zmD_DhU22AgmkIpvXsbyCbbN3zIjK079L28Sn-TgUslmWbCMipAWmkvxOHWs9taXF3GlslAjLaQFKAHa8AggklgUQgRefAGEudBqWsw5DSX8F_1mU3on7HuIjyw3hfql9rXMtE9oYdtdFxCnG9H-_0B7TQ6rA:1aP5Ww:bFW3fDR_2n80LBi9iJ0R9wg6ddY"
#
#     echo -e "\ndoing ${red}POST${nocolor} to ${cyan}$URL${nocolor}\n"
#
#     if [ -z "$1" ]; then
#         echo -e "CSRF Token is missing!\nusing: ${yellow}$BASETOKEN${nocolor}"
#         TOKEN=$BASETOKEN
#     else
#         echo -e "Setting CSRFToken as ${green}$1${nocolor}"
#         TOKEN=$1
#     fi
#
#
#     if [ -z "$2" ]; then
#         echo -e "SessionID is missing!\nusing: ${yellow}$BASESESSIONID${nocolor}"
#         SESSIONID=$BASESESSIONID
#     else
#         echo -e "Setting SessionID as ${green}$2${nocolor}"
#         SESSIONID=$2
#     fi
#     echo -e "\n"
#
#     HOST='Host: localhost:8000'
#     AGENT='User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.10; rv:43.0) Gecko/20100101 Firefox/43.0'
#     ACCEPT='Accept: application/json, text/plain, */*'
#     LANGUAGE='Accept-Language: de,en-US;q=0.7,en;q=0.3'
#     DNT='DNT: 1'
#     REFERER='Referer: http://localhost:8000/response-upload/'
#     CONTENTLENGHT='Content-Length: 68'
#     CONTENTTYPE="Content-Type: application/json; charset=utf-8"
#
#     DATA='{username: "pato", school_code: 999, email: "pato@krankikom.de"}'
#
#
#     COOKIE="Cookie: csrftoken=$TOKEN; sessionid=$SESSIONID"
#     CSRFTOKEN="X-CSRFToken: $TOKEN"
#     XTOKEN="X-Token: something"
#
#     curl -H "$HOST" -H "$AGENT" -H "$ACCEPT" -H "$LANGUAGE" --compressed -H "$CONTENTTYPE" -H "$CSRFTOKEN" -H "$XTOKEN" -H "$REFERER" -H "$COOKIE" --data "$DATA" -X POST $URL --verbose
# }

# function getter() {
#     URL='http://localhost:8000/response-upload/api/v1/specimenresponseuploader/'
#
#     BASETOKEN="5XOAZ0UK8lLbSlmZKEUGpvLaam1Uq5EN"
#     BASESESSIONID=".eJxVi0kKwyAUQO_iuojW6Ztl9zmD_DhU22AgmkIpvXsbyCbbN3zIjK079L28Sn-TgUslmWbCMipAWmkvxOHWs9taXF3GlslAjLaQFKAHa8AggklgUQgRefAGEudBqWsw5DSX8F_1mU3on7HuIjyw3hfql9rXMtE9oYdtdFxCnG9H-_0B7TQ6rA:1aP5Ww:bFW3fDR_2n80LBi9iJ0R9wg6ddY"
#
#     echo -e "\ndoing ${red}GET${nocolor} to ${cyan}$URL${nocolor}\n"
#
#
#     if [ -z "$1" ]; then
#         echo -e "CSRF Token is missing!\nusing: ${yellow}$BASETOKEN${nocolor}"
#         TOKEN=$BASETOKEN
#     else
#         echo -e "Setting CSRFToken as ${green}$1${nocolor}"
#         TOKEN=$1
#     fi
#
#
#     if [ -z "$2" ]; then
#         echo -e "SessionID is missing!\nusing: ${yellow}$BASESESSIONID${nocolor}"
#         SESSIONID=$BASESESSIONID
#     else
#         echo -e "Setting SessionID as ${green}$2${nocolor}"
#         SESSIONID=$2
#     fi
#     echo -e "\n"
#
#     HOST='Host: localhost:8000'
#     AGENT='User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.10; rv:43.0) Gecko/20100101 Firefox/43.0'
#     ACCEPT='Accept: application/json, text/plain, */*'
#     LANGUAGE='Accept-Language: de,en-US;q=0.7,en;q=0.3'
#     DNT='DNT: 1'
#     REFERER='Referer: http://localhost:8000/response-upload/'
#     CONTENTLENGHT='Content-Length: 68'
#     CONTENTTYPE="Content-Type: application/json; charset=utf-8"
#
#     DATA='{username: "pato", school_code: 999, email: "pato@krankikom.de"}'
#
#     COOKIE="Cookie: csrftoken=$TOKEN; sessionid=$SESSIONID"
#     CSRFTOKEN="X-CSRFToken: $TOKEN"
#     XTOKEN="X-Token: something"
#
#     curl -H "$HOST" -H "$AGENT" -H "$ACCEPT" -H "$LANGUAGE" --compressed -H "$CONTENTTYPE" -H "$CSRFTOKEN" -H "$XTOKEN" -H "$REFERER" -H "$COOKIE" --data "$DATA" -X GET $URL --verbose
# }


alias unanilloparagobernarlosatodos='echo -e "BZC5Q-CJBD7-KBHNJ-DWSXA-4G64TF-3PCNJV-3A\n"'
alias unanilloparagobernarlosatodos_dos='echo -e "EVAN en guitar miau lota gato poleposition excl\n"'

function git_check_local_branches() {
	LOCALBRANCHES=$(git branch | cut -c3-)
	REMOTEBRANCHES=$(git branch -r | cut -c3- | grep "^origin")

	echo -e "\n${orange}Looking whether some Local Branches are missing on Remote${nocolor}\n\n"

	for branch in ${LOCALBRANCHES[@]}; do
        found=''
		for remote in ${REMOTEBRANCHES[@]}; do
			if [[ "$remote" =~ "$branch" ]]; then
				found=$branch
                break
			fi
		done

		if [[ -z "$found" ]]; then
			echo "[NOT FOUND] $branch"
		fi

	done
    echo "";
}

function git_remove_untracked_files()
{
    echo -e "\nJust run:\n\t${yellow}git clean -f -n${nocolor}\n\nto see which files will be removed.."
    echo -e "\nand if it does look good, run the same command without -n\n"
    git clean -f -n;
}

function removeFolderOlderThan()
{

    if [ -z "$1" ]; then
        echo -e "\neeeh how many days back should i look for....\n"
        return
    fi
    echo -e "\nTo remove folders older than ${yellow}$1${nocolor} days in the current path\n"
    echo -e "\tfind . -type d -ctime +$1 -exec rm -rf {} \;\n";
}

function ibdecrypt()
{
    FORMAT="\n\t\$ ibdecrypt <${yellow}source file${nocolor}> <${yellow}target file${nocolor}> <${yellow}pass${nocolor}>\n"

    if [ -z "$1" ]; then
        echo -e "\n${yellow}...aaaand the source file is?${nocolor}\n$FORMAT"
        return
    fi

    if [ ! -f ./$1 ]; then
        echo -e "\n${red}file ${yellow}$1${red} does not exist!${nocolor}\n"
        return
    fi

    if [ -z "$2" ]; then
        echo -e "\n${yellow}a target file for decrypting would be great!${nocolor}\n$FORMAT"
        return
    fi
    if [ -z "$3" ]; then
        echo -e "\n${yellow}of course, a password is more than a nice to have, you know${nocolor}\n$FORMAT"
        return
    fi

    RESULT=$(openssl aes-256-cbc -d -in $1 -out $2 -p -pass pass:$3 -md md5 -nosalt)
    echo -e "\n$RESULT\n"
}

# function ib_update_localhost()
# {
#     IP=$(for i in {0..5}; do ipconfig getifaddr en$i; done)
#     echo -e "\nucurrent IP ${yellow}$IP${nocolor}\n"
#     echo -e "editing ~/kk/ib/ib-main/ib_cms/settings_local.py\n"
#     RESULT=$(sed -E -i '' "s/10.22.(1|2).[0-9]{1,3}/$IP/g" ~/kk/ib/ib-main/ib_cms/settings_local.py)
#     echo -e "$RESULT"
# }

# Use `docker-cleanup --dry-run` to see what would be deleted.
# function docker-cleanup {
#   EXITED=$(docker ps -q -f status=exited)
#   DANGLING=$(docker images -q -f "dangling=true")
#
#   if [ "$1" == "--dry-run" ]; then
#     echo "==> Would stop containers:"
#     echo $EXITED
#     echo "==> And images:"
#     echo $DANGLING
#   else
#     if [ -n "$EXITED" ]; then
#       docker rm $EXITED
#     else
#       echo "No containers to remove."
#     fi
#     if [ -n "$DANGLING" ]; then
#       docker rmi $DANGLING
#     else
#       echo "No images to remove."
#     fi
#   fi
# }

function ib_docker_production() {
    echo -e "Downloading and load in a mysql docker instance container"
    echo -e "changing to datadir folder ~/.docker/datadir"
    # cd ~/.docker/datadir || exit
    #
    # echo -e "\nproduction:"
    # echo -e "mysqldump --host=ib-iload1.krankikom.de -uib-cms -p --databases --extended-insert --insert-ignore --add-drop-table --single-transaction ib > ib.prod.sql"
    # echo -e ""
    # echo -e "mysql --host=0.0.0.0 --port=6033 < ib.prod.sql"
    # echo -e ""
    # echo -e "mysqldump --host=ib-mysql1.krankikom.de -uib-prod -p --databases --extended-insert --insert-ignore --add-drop-table --single-transaction ibis-interface-prod > ibis.prod.sql"
    # echo -e "mysql --host=0.0.0.0 --port=6033 < ibis.prod.sql"
    # echo -e ""
}

# mysqldump -hib-iload1.krankikom.de -uib-cms -p --databases --extended-insert --insert-ignore --add-drop-table ib > ib.prod.sql
# mysqldump --host=ib-mysql1.krankikom.de -uib-prod -p --databases --extended-insert --insert-ignore --add-drop-table ibis-interface-prod > ibis.prod.sql

# function passw()
# {
#     if [ -z "$1" ]; then
#         echo -e "\n${yellow}give me the password to be bcrypt hashed!${nocolor}\n"
#         return
#     fi
#
#     PASS=$1
#     php -r 'print "\n".password_hash("'$PASS'",PASSWORD_BCRYPT)."\n\n";'
# }
#
# function verify_password_2()
# {
#     if [ -z "$1" ]; then
#         echo -e "\n${yellow}..and the password is?${nocolor}\n"
#         return
#     fi
#
#     if [ -z "$2" ]; then
#         echo -e "\n${yellow}..and the Hash is?${nocolor}\n"
#         return
#     fi
#
#     echo -e "not working fine yet\n\n"
#     PASS=$1
#     HASH=$2
#     php -r 'print "\n\n" . password_verify("'$PASS'","'$HASH'") ? "VERIFIED\n\n" : "Wrong!!!\n\n";'
# }
#

function ts() {
    if [ -z "$1" ]; then
        echo -e "\n${yellow}...give me a timestamp!${nocolor}\n"
        return
    fi

    TS=$1

    re='^[0-9]+$'
    if ! [[ $TS =~ $re ]] ; then
        echo -e "${red}Error${nocolor}: Not a number" >&2
        return
    fi

    # Check if the timestamp is in milliseconds (13 digits), and convert if needed
    if [ ${#TS} -eq 13 ]; then
        echo -n "\nRemoving last 3 digits as here we dont use the js format\nTS:${TS}\n"
        TS=${TS:0:10}  # Truncate to the first 10 digits
        echo -n "New TS: ${TS}\n"
    fi

    CEST=$(date -r $TS)
    UTC=$(TZ=UTC0 date -r $TS)
    
    echo -e "\n${green}$CEST${nocolor}"
    echo -e "$UTC\n"
}


# function ts()
# {
#     if [ -z "$1" ]; then
#         echo -e "\n${yellow}...give me a timestamp!${nocolor}\n"
#         return
#     fi
#
#     TS=$1
#
#     re='^[0-9]+$'
#     if ! [[ $TS =~ $re ]] ; then
#        echo -e "${red}Error${nocolor}: Not a number" >&2;
#        return
#     fi
#
#     CEST=$(date -r $TS)
#     UTC=$(TZ=UTC0 date -r $TS)
#     echo -e "\n$CEST"
#     echo -e "$UTC\n"
# }
#


function ts2()
{
    if [ -z "$1" ]; then
        echo -e "\n... you are missing something, don’t you?\n"
        return
    fi

    TS=$1

    re='^[0-9]+$'
    if ! [[ $TS =~ $re ]] ; then
       echo -e "Error: Not a number" >&2;
       return
    fi

    CEST=$(date -r $TS)
    UTC=$(TZ=UTC0 date -r $TS)
    echo -e "\n$CEST"
    echo -e "$UTC\n"
}

function ib_yosemite()
{
    echo -e "Setting 1920x1080 to YosemiteBox"
    VBoxManage setextradata "YosemiteVagrantByBenni" VBoxInternal2/EfiGopMode 3
}

function ib_tools()
{
    echo -e "\nList of IB functions and helpers\n"

    echo -e "\t${green}ibdecrypt${nocolor} decrypt ib files in the current folder, params: src tgt rdk"
    echo -e "\t${green}json${nocolor} pretty print version"
    echo -e "\t${green}uuid${nocolor} return an UUID-4 compliant UUID"
    echo -e "\t${green}ib_update_localhost${nocolor} Updates local IP in settings_local.py"
    echo -e "\t${green}git_check_local_branches${nocolor} Check if there are missing local branches in the remote server"
    echo -e "\t${green}makeIbSymlinks${nocolor} Adds missing symlinks to existing repositories"
    # echo -e "\t${green}${nocolor}"
    echo -e "\n"
}

function githelp() {
    help=$(cat <<-END
    revert added but not yet commited files:
        ${yellow}git reset <file>${nocolor}
        or
        ${yellow}git reset${nocolor}
        to un-add all files at once

    revert commited but not yet pushed:
        ${yellow}git reset HEAD~${nocolor}"

    revert to commit:
        ${yellow}git reset --hard 123sdfs2234${nocolor}

    edit last commit message (before push):
        ${yellow}git commit --amend${nocolor}

    show a file from another branch:
        ${yellow}git show branch:path/to/file${nocolor}
        ${yellow}git show branch:path/to/file > anotherfilename${nocolor}

    grab a file from another branch: (no git cherry-pick to not deal with commits)
        ${yellow}git checkout branch path/to/file${nocolor}

    restores a specific stash: (using 'pop' instead of 'apply' it also removes the stash from the stack)
        ${yellow}git stash apply stash@{N}${nocolor}
        where N is the stash number

    Temporary ignore a file:
        ${yellow}git update-index --assume-unchanged </path/to/filename>${nocolor}

        Track again a temporary ignored afile:
        ${yellow}git update-index --no-assume-unchanged </path/to/filename>${nocolor}

    to take commits from one branch to another:  ${yellow}git merge a --squash${nocolor}   in a new feature branch
        ${yellow}git checkout master${nocolor}
        ${yellow}git checkout -b clean-feauture${nocolor}
        ${yellow}git merge ugly-feautre --squash${nocolor}

        I would create a new feature branch from master
        then git cherry-pick <hash> as many as i need
        git push new branch


    to compare current branch with master:
        ${yellow}git diff master...${nocolor}

    to delete old stashes (adds --dry-run to check first):
        ${yellow}git reflog expire --expire-unreachable=40.days refs/stash${nocolor}

    to tag your branch:
        ${yellow}git tag -a v0.7.0-rc3 <commithash> -m 'release candidate 3'${nocolor}
    to push your tags:
        ${yellow}git push --tags ${nocolor}

    to remove a file in repo that must be ignored:
        ${yellow}git rm --cached <path/filename>${nocolor}
        After this
            ${yellow}git commit -m 'message'${nocolor}
        and git push.

    # https://stackoverflow.com/a/35487209
    ${green}[alias]${nocolor}set-upstream = !git branch --set-upstream-to=origin/\`git symbolic-ref --short HEAD\`

    to find out when a branch was created:
        ${yellow}git show --summary \`git merge-base feature/QA-135-adm-orig master-version-2\`${nocolor}

END
)
    echo -e $help
}

function githelp2() {
    echo -e "\nrevert added but not yet commited files:\n\t${yellow}git reset <file>${nocolor} or ${yellow}git reset${nocolor} to un-add all files at once"
    echo -e "\nrevert commited but not yet pushed:\n\t${yellow}git reset HEAD~${nocolor}"
    echo -e "\nrevert to commit: \n\t${yellow}git reset --hard 123sdfs2234${nocolor}\n"
    echo -e "\nedit last commit message (before push):\n\t${yellow}git commit --amend${nocolor}\n"
    echo -e "\nshow a file from another branch:\n\t${yellow}git show branch:path/to/file${nocolor}\n\n\t${yellow}git show branch:path/to/file > anotherfilename${nocolor}\n"
    echo -e "\ngrab a file from another branch: (no git cherry-pick to not deal with commits)\n\t${yellow}git checkout branch path/to/file${nocolor}\n"

    echo -e "\nrestores a specific stash: (using 'pop' instead of 'apply' it also removes the stash from the stack)\n\t${yellow}git stash apply stash@{N}${nocolor} where N is the stash number\n"

    echo -e "\nTemporary ignore a file:\n\t${yellow}git update-index --assume-unchanged </path/to/filename>${nocolor}\n"
    echo -e "\nTrack again a temporary ignored afile:\n\t${yellow}git update-index --no-assume-unchanged </path/to/filename>${nocolor}\n"

    echo -e "\nto take commits from one branch to another: ${yellow}git merge a --squash${nocolor} in a new feature branch\n\t${yellow}git checkout master${nocolor}\n\t${yellow}git checkout -b clean-feauture${nocolor}\n\t${yellow}git merge ugly-feautre --squash${nocolor}\n"

    echo -e "\nto compare current branch with master:\n\t${yellow}git diff master...${nocolor}\n"

    echo -e "\nto delete old stashes (adds --dry-run to check first):\n\t${yellow}git reflog expire --expire-unreachable=40.days refs/stash${nocolor}\n"

    echo -e "\nto tag your branch:\t${yellow}git tag -a v0.7.0-rc3 <commithash> -m 'release candidate 3'${nocolor}\nto push your tags:\t${yellow}git push --tags ${nocolor}\n"

    echo -e "\nto remove a file in repo that must be ignored:${yellow}git rm --cached <path/filename>${nocolor}\nAfter this ${yellow}git commit -m 'message'${nocolor} and git push."

    # https://stackoverflow.com/a/35487209
    echo -e "\n${green}[alias]${nocolor}\nset-upstream = !git branch --set-upstream-to=origin/\`git symbolic-ref --short HEAD\`\n"

    echo -e "\nto find out when a branch was created:${yellow}git show --summary \`git merge-base feature/QA-135-adm-orig master-version-2\`${nocolor}\n"

    echo -e "\n"
}

function hilfe () {
# Using a here doc with standard out.
    cat <<-END

    sshfs
        mounts a remote server per SSH, then in the mount point you can call your fav editor, eg. $ atom .

        \$ sshfs git@caseintake2.krankikom.de:/cbx/htdocs/caseintake2 /Volumes/remote-ci/


    mtr
        A mix of trace and ping (brew)

            Packets               Pings
            Host                                     Loss%   Snt   Last   Avg  Best  Wrst StDev
            1. 217.70.191.253                         0.0%    32    0.5   1.7   0.3  17.6   3.8
            2. p252-core4-d.paris.gandi.net           0.0%    32    0.5   1.1   0.3  17.8   3.1
            ...

    ack
        grep replacement written in Perl5...  (brew)
            doc: https://beyondgrep.com/documentation/

            \$ ack [OPTION]... PATTERN [FILES OR DIRECTORIES]

            Searching for "javascript" in a file
                \$ grep javascript foo.txt
                \$ ack javascript foo.txt

            Searching every file in the current directory for "javascript"
                \$ grep -r javascript .
                \$ ack javascript

            Searching every file in the current directory for "javascript", excluding a .git directory
                \$ grep -r javascript . \$(find . -type f | grep -v "\.git")
                \$ ack javascript

            Searching every HTML file in the current directory for "javascript", excluding a .git directory
                \$ grep -r javascript . \$(find . -name '*.html' -or -name '*.htm'| grep -v '\.git')
                \$ ack --html javascript


END
}

function console_help () {
    cat <<-END

    ctrl+A: moves to the start of the line

    ctrl+E: moves to the end of the line

    ctrl+B: move back one character

    ctrl+F: move forward one character

    esc+B: move back one word

    esc+F: move forward one word

    ctrl+U: delete from the cursor to the beginning of the line

    ctrl+K: delete from the cursor to the end of the line

    ctrl+W: delete from the cursor to the beginning of the current word

END
}

function server_help() {
  cat <<-END

	$ http-server
		Starts a inode server in the current folder. port 8080

	$ python3 -m http.server 8080

	$ php -S localhost:8080

END
}


function serverhere () {
    PORT=8000
    if [ -z "$1" ]; then
        PORT=$1
    fi

    # python 2
    # python -m SimpleHTTPServer $PORT
    python3 -m http.server $PORT
}

function remove_vscode () {
    echo -e "\nRemoving VSCode\n"
    echo -e "rm -fr ~/Library/Preferences/com.microsoft.VSCode.helper.plist\n"
    echo -e "rm -fr ~/Library/Preferences/com.microsoft.VSCode.plist\n"
    echo -e "rm -fr ~/Library/Caches/com.microsoft.VSCode\n"
    echo -e "rm -fr ~/Library/Caches/com.microsoft.VSCode.ShipIt/\n"
    echo -e "rm -fr ~/Library/Application\ Support/Code/\n"
    echo -e "rm -fr ~/Library/Saved\ Application\ State/com.microsoft.VSCode.savedState/\n"
    echo -e "rm -fr ~/.vscode/\n"
    echo -e "\n"
}

# function getmp4 () {
#     if [ -z "$1" ]; then
#         echo "path is missing"
#         return
#     fi
#
#     SCP_CMD="git@ib-cms1.krankikom.de:/srv/exports/response/prod/$1/*.mp4 ./"
#
#     echo "scp $SCP_CMD"
#     echo
#     cd ~/Desktop/maengMOEENGTZ0XXXX
#     scp $SCP_CMD
#     echo
# }
#
# function getscreenshots () {
#     if [ -z "$1" ]; then
#         echo "path is missing"
#         return
#     fi
#
#     SCP_CMD="git@ib-cms1.krankikom.de:/srv/exports/response/prod/$1/*.scr ./"
#
#     echo "scp $SCP_CMD"
#     echo
#     cd ~/Desktop/maengMOEENGTZ0XXXX
#     scp $SCP_CMD
#     echo
# }


# ucb_dirs=(dagobert daisy donald gundula tick track trick donald gundula); for dir in "${ucb_dirs[@]}"; do cd /cbx/htdocs/$dir/ucb-web; branch=`git branch | grep \* | cut -d ' ' -f2`; echo -e "$dir: $branch\n"; done;


function openport () {
    cat <<-END

    netstat -ap tcp | grep -i 'listen'

    lsof -PiTCP -sTCP:LISTEN

    lsof -t -i tcp:8000 | xargs kill -9

    lsof -Pn -i4         # -i4 means only show ipv4 address and ports -P and -n fast output

    netstat -Watnlv | grep LISTEN | awk '{"ps -o comm= -p " $9 | getline procname;colred="\033[01;31m";colclr="\033[0m"; print cred "proto: " colclr $1 colred " | addr.port: " colclr $4 colred " | pid: " colclr $9 colred " | name: " colclr procname;  }' | column -t -s "|"

END
}

openports (){
    netstat -Watnlv | grep LISTEN | awk '{"ps -o comm= -p " $9 | getline procname;colred="\033[01;31m";colclr="\033[0m"; print colred "proto: " colclr $1 colred " | addr.port: " colclr $4 colred " | pid: " colclr $9 colred " | name: " colclr procname;  }' | column -t -s "|"
}

viewMarkDown () {
    pandoc $1 | lynx -stdin
}

function ib_decode_specimen() {
    # "RDK-%s-%s-%s" % (registration.dummy_school_code, registration.dummy_candidate_code, registration.dummy_unlock_code)

    # openssl aes-256-cbc -d -p -pass pass:RDK-123456-123456-1234 -md md5 -nosalt -in ResponseData.2019-12-04T11-54-17Z.json.rdk -out ResponseData.2019-12-04T11-54-17Z.json

    if [ -z "$1" ]; then
        echo -e "\n$ ib_decode_specimen <file.rdk> <school_code> <candidate_code> <unlock_code>"
        echo -e "\n the file.RDK is missing!"
        return
    fi

    if [ -z "$2" ]; then
        echo -e "\n$ ib_decode_specimen <file.rdk> <school_code> <candidate_code> <unlock_code>"
        echo -e "\n$ <school_code> is missing!"
        return
    fi

    if [ -z "$3" ]; then
        echo -e "\n$ ib_decode_specimen <file.rdk> <school_code> <candidate_code> <unlock_code>"
        echo -e "\n$ <candidate_code> is missing!"
        return
    fi

    if [ -z "$4" ]; then
        echo -e "\n$ ib_decode_specimen <file.rdk> <school_code> <candidate_code> <unlock_code>"
        echo -e "\n$ <unlock_code> is missing!"
        return
    fi

    FILE_RDK=$1

    if [[ ! "$FILE_RDK" =~ .*".rdk"i ]]; then
        echo "$1 does not match"
        return
    fi

    SCHOOL_CODE=$2
    CANDIDATE_CODE=$3
    UNLOCK_CODE=$4

    echo -e "\n\nUsing:\n\tsource: $FILE_RDK\n\tschool:$SCHOOL_CODE\n\tcandidate:$CANDIDATE_CODE\n\tUNLOCK:$UNLOCK_CODE"

    #openssl aes-256-cbc -d -in $FILE_RDK -out ResponseData.2019-12-04T11-54-17Z.json -p -pass pass:RDK-123456-123456-1234 -md md5 -nosalt
}


function projects_list_and_shortnames_for_aliases () {
    cat <<-END

    aqa
    cin         Cineplex
    drw         Dr Wolff
    ib          Internaltional Baccalaureate
    iot
    obi
    bo          Böhse Onkelz
    peag        Personalvermittlung
    pg          Pressegrosso
    pwa         UCB Pwa
    r2          Ruhr2NorthSeaChallenge r2nsc
    r2d         r2nsc donator
    ruhr        Ruhronline
    rr          Ruhrtal Radweg
    ucb
    uci

END
}

function find_and_cat () {
    if [ -z "$1" ]; then
        echo -e "\n$ find_and_cat <filename string>"
        return
    fi

    find . -type f -name "*$1*" -exec cat {} \;
}


function timemachine_list_local()
{
    tmutil listlocalsnapshots /Volumes
}

function timemachine_delete_locals()
{
    for d in $(tmutil listlocalsnapshotdates /Volumes | grep "-"); do tmutil deletelocalsnapshots $d; done
}

function pg_search_in_filetype_2() {
    if [ -z "$1" ]; then
        echo -e "Parameter 1 is missing:\n$ search_in_filetype <filetype:php|html|js> <string> <string2>"
        return
    fi

    if [ -z "$2" ]; then
        echo -e "Parameter 2 is missing:\n$ search_in_filetype <file extension:php|html|js> <string> <string2>"
        return
    fi

    # if [ -z "$3" ]; then
    #     echo -e "Parameter 3 is missing:\n$ search_in_filetype <file extension:php|html|js> <string> <string2>"
    #     return
    # fi


    cd ~/kk/pg/docker/pressegrosso-website
    echo -e "Searching for ${yellow}$2${nocolor} in ${yellow}*.$1${nocolor} files\n"

    # find . -type f -name "*.$1" ! -path "./public/node_modules/*" ! -path "./vendor/*" -exec grep -l $2 {} \;

    echo -e "\n\n"

    IFS=$'\n'
    FILES=($(find . -type f -name "*.$1" ! -path "./public/node_modules/*" ! -path "./vendor/*" -exec grep -l $2 {} \; | sort --unique))
    unset IFS

    echo ${FILES[@]}

    RESULTS=()
    for i in ${FILES[@]}; do
        echo -e "searching in $i\n"
    #     RESULTS+=($(grep -o $3 $i))
        RESULTS+=$(cat $i | grep -Eo "$3\.[a-zA-Z0-9]+")
    done

    # echo $RESULTS

    # $(find ~/kk/pg/docker/pressegrosso-website -type f ~/kk/pg/docker/pressegrosso-website/public/node_modules -prune -o ~/kk/pg/docker/pressegrosso-website/vendor -prune -o -name "*.$1" -exec grep -Eo "$2\.[a-zA-Z0-9]+" {} \; | sort --unique)

}

function pg_search_fields() {
    if [ -z "$1" ]; then
        echo -e "Look for fields with the given 'alias'. Eg: 'FROM cs_objaus AS aus (...)', use 'aus' without period.\n"
        echo -e "$ pg_search_fields aus\n\n"
        return
    fi

    cd ~/kk/pg/docker/pressegrosso-website
    echo -e "Searching for ${yellow}$1.<fieldname>${nocolor} files\n"

    find . -type f \( -name "*.php" -or -name "*.sql" \) ! -path "./public/node_modules/*" ! -path "./vendor/*" -exec grep -Eo "$1\.[a-zA-Z0-9]+" {} \; | sort --unique
}

function pg_search() {
    if [ -z "$1" ]; then
        echo -e "Parameter 1 is missing:\n$ pg_search <string>\nLook for string in <php phtml sql> files"
        return
    fi

    cd ~/kk/pg/docker/pressegrosso-website
    echo -e "Searching for ${yellow}$1${nocolor} in Project files\n"

    find . -type f \( -name "*.php" -o -name '*.phtml' -o -name '*.sql' \) ! -path "./public/node_modules/*" ! -path "./vendor/*" -exec grep -li "$1" {} \; | sort --unique
}

function pg_get_all_tables() {
    cd ~/kk/pg/docker/pressegrosso-website/src
    echo -e "List all tables under /src with prefixes: ${yellow}cs_ csweb_ ws_ kk_ qt_ qtweb_ user_${nocolor} in Project files\n"

    find . -type f \( -name "*.php" -o -name '*.sql' \) -exec grep -Eo "\b(?:sf_|(cs_|csweb_|ws_|kk_|qt_|qtweb_|user_)[a-zA-Z0-9_-]+)\b" {} \; | sort --unique

}

function git_is_merged() {
    if [ -z "$1" ]; then
        echo -e "source branch name is missing.   Eg.  origin/feature/QA-999"
        return
    fi

    if [ -z "$2" ]; then
        echo -e "target branch name is missing.  Eg:  origin/master"
        return
    fi

    git merge-base --is-ancestor $1 $2 && echo -e "${yellow}merged${nocolor} \n" || echo -e "${yellow}not merged${nocolor} \n"
}

function git_local_branches_merged_into_remote_master_version_2() {
    if [ -z "$1" ]; then
        echo -e "local source branch name is missing.  Eg:  feature/QA-999"
        return
    fi

    git for-each-ref --merged=origin/master-version-2 --format="%(refname:short)" refs/heads/
}

function git_local_branches_merged_into_remote_staging() {
    if [ -z "$1" ]; then
        echo -e "current remote branch name in STAGING is missing.  Eg:  origin/release/kw-01-2022"
        return
    fi

    git for-each-ref --merged=$1 --format="%(refname:short)" refs/heads/
}

function git_local_branches_not_merged_into_remote_master_version_2() {
    git for-each-ref --no-merged=origin/master-version-2 --format="%(committerdate:short) %(refname:short)" --sort=committerdate refs/heads
}

function git_local_branches_not_merged_into_remote_staging() {
    if [ -z "$1" ]; then
        echo -e "current remote branch name in STAGING is missing.  Eg:  origin/release/kw-01-2022"
        return
    fi

    git for-each-ref --no-merged=$1 --format="%(committerdate:short) %(refname:short)" --sort=committerdate refs/heads
}


function krankikom_controlling_parser() {
  YEAR=$(date +%Y)
  RELOAD=0

  while [ $# -gt 0 ]; do
    case "$1" in
      -year) # If -year is given, check the next argument
        if [ -n "$2" ]; then # If the next argument is not empty
          if [[ "$2" =~ ^-year=([0-9]{4})$ ]]; then # If the next argument is in the form -year=2023
            YEAR=${BASH_REMATCH[1]} # Set YEAR to the matched group
          elif [[ "$2" =~ ^[0-9]{4}$ ]]; then # If the next argument is in the form 2023
            YEAR=$2 # Set YEAR to the next argument
          else # If the next argument is not a valid year
            echo "Invalid year: $2" # Print an error message
            return 1 # Exit the function with an error code
          fi
          shift # Shift the arguments
        else # If the next argument is empty
          echo "Missing year value" # Print an error message
          return 1 # Exit the function with an error code
        fi
        ;;
      -reload) # If -reload is given, set RELOAD to 1
        RELOAD=1
        ;;
      *) # If any other argument is given, print an error message and exit the function
        echo "Invalid argument: $1"
        return 1
        ;;
    esac
    shift # Shift the arguments
  done

  # echo "YEAR: $YEAR"
  # echo "RELOAD: $RELOAD"

    cd ~/personal/krankikom/controlling-report-parser
    if [ $RELOAD -eq 1 ]; then
        python parser_1.py -year $YEAR -reload
    else
        python parser_1.py -year $YEAR
    fi
    cd -
}

function roland_golla() {
    cd /Users/pato/personal/goodies/testify-pg

    cat <<-END

nvm use stable
npm install
npx cypress run
npx cypress open

END
}

function django_search() {
    if [ -z "$1" ]; then
        echo -e "search needle is missing"
        return
    fi
    grep -Hn "$1" $(find . -type f -name "*.py" -o -name "*.txt")
}

function show_grep_filters() {
cat <<-END
    grep_for_non_ascii ='pcregrep --color="always" -n "[\x80-\xFF]" '
    grep_clean         ='grep -Ev --color=never "(.png|.jpg|.css|.js|.svg|.ico|server-status|robots)"'
    no_assets          ="grep_clean"
    only_backend_urls  ='grep_clean'
    no_backend_urls    ='grep -Ev "(magazin|remission|paketverfolgung|pressesortiment|reklamation|belege)"'
    simple_log         ='awk '\''{print $1, $4, $6, $7, "("$9")"}'\'''
    simple_log_referer ='awk '\''{print $1, $4, $6, $7, "("$9")", $11}'\'''
    only_devices       ='awk '\''{print $1,$12,$13,$14,$15,$16,$17,$18,$19}'\'''
    last_2_words       ='awk '\''END {print $(NF-1), $NF}'\'''
    last_two_words     =last_2_words
    only_sessions      ='grep -oE "[0-9a-z]{32}" | sort -u's
    only_ip            ='grep -oE "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}"'
    only_promotion     ='grep -oE "(zum-objekt|neues-feature)"'
END
echo
}

alias how_to_goaccess=goaccess_howto
function goaccess_howto() {
  cat <<-END

  To create a html report of a log file.

  cat access.log | docker run --rm -i -e LANG=$LANG allinurl/goaccess -a -o html --log-format COMBINED - > report.html

END
echo
}

function who_is_ipfo() {
    # patoded ipinfo.io
    # 97cc8769398821
    if [ -z "$1" ]; then
        echo -e "IP is missing"
        return
    fi
    echo -e "running: curl \"ipinfo.io/$1?token=97cc8769398821\"\n"
    curl "ipinfo.io/$1?token=97cc8769398821"
    echo



}


function how_to_sed() {
  cat <<-END

$ sed -i '' 's/REFERENCES \`event-management\`/REFERENCES \`event-dev\`/g' your_file.sql

END
echo
}

function how_to_tcf_uncheck() {
    LINE1="document.querySelectorAll('input.fc-preference-legitimate-interest').forEach(el => { el.checked = false; }); })();"
    LINE2="document.querySelector('.fc-button.fc-confirm-choices.fc-primary-button').click();"
    LINE3="CNBOX.cancel();"
    cat <<-END
in the console run this

${LINE1}
${LINE2}
${LINE3}

END
  echo "${LINE1}${LINE2}${LINE3}" | pbcopy
  echo
  echo "$($('.fc-button.fc-confirm-choices.fc-primary-button')[0]).trigger('click');"
  echo
}


view_keybindings_1() {
    local cols=$(tput cols)
    local key_width=20
    local cmd_width=30
    local columns=$((cols / (key_width + cmd_width + 1)))

    bindkey | sed 's/"//g' | awk -v cols="$cols" -v key_width="$key_width" -v cmd_width="$cmd_width" -v columns="$columns" '
    BEGIN {
        count = 0;
    }
    {
        key = sprintf("%-*s", key_width, substr($1, 1, key_width));
        cmd = sprintf("%-*s", cmd_width, substr($2, 1, cmd_width));
        line[count] = key cmd;
        count++;
    }
    END {
        for (i = 0; i < count; i += columns) {
            for (j = 0; j < columns && i+j < count; j++) {
                printf "%s", line[i+j];
            }
            printf "\n";
        }
    }'
}

view_keybindings() {
    local cols=$(tput cols)
    local key_width=12
    local cmd_width=30
    local gap_width=8
    local pair_width=$((key_width + cmd_width))
    local total_pair_width=$((pair_width + gap_width))
    local columns=$((cols / total_pair_width))

    bindkey | sed 's/"//g' | awk -v cols="$cols" -v key_width="$key_width" -v cmd_width="$cmd_width" -v gap_width="$gap_width" -v columns="$columns" '
    BEGIN {
        count = 0;
        gap = sprintf("%*s", gap_width, "");
    }
    {
        key = sprintf("%-*s", key_width, substr($1, 1, key_width));
        cmd = sprintf("%-*s", cmd_width, substr($2, 1, cmd_width));
        line[count] = key cmd gap;
        count++;
    }
    END {
        for (i = 0; i < count; i += columns) {
            for (j = 0; j < columns && i+j < count; j++) {
                printf "%s", line[i+j];
            }
            printf "\n";
        }
    }'
}

function how_to_video() {
  cat <<-END
  Shift+Cmd+5
  choose the video option...
    whole screen and then click on it 
    selected area.


  how to compress:
   use handrbrake software

END
  echo
}


# function colorize() {
#   if [ -z "$1" ]; then
#     return 
#   fi
#
#   # if echo "$1" | grep -q '\[ERROR\]'; then
#   #   printf "\033[31m%s\033[0m\n" "$1"
#   # elif echo "$1" | grep -q '\[WARNING\]'; then
#   #   printf "\033[33m%s\033[0m\n" "$1"
#   # elif echo "$1" | grep -q '\[DEBUG\]'; then
#   #   printf "\033[36m%s\033[0m\n" "$1"
#   # fi
#
#   # Colorize date
#   if echo "$1" | grep -E -q '\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\]'; then
#     printf "\033[32m%s\033[0m\n" "$1"
#   fi
#
#   # Colorize logger
#   if echo "$1" | grep -E -q '\s[a-z]{2,4}\.[a-z]{2,4}\.(DEBUG|INFO)\s'; then
#     printf "\033[34m%s\033[0m\n" "$1"
#   fi
#
#   # Colorize phpsessid and identity
#   if echo "$1" | grep -E -q '[a-f0-9]{32}'; then
#     printf "\033[35m%s\033[0m\n" "$1"
#   fi
#
#   # Colorize JSON structure
#   if echo "$1" | grep -q '{.*}'; then
#     printf "\033[37m%s\033[0m\n" "$1"
#   fi
#
#   # if [[ $1 =~ \[ERROR\] ]]; then
#   #   printf "\033[31m$1\033[0m\n"
#   # elif [[ $1 =~ \[WARNING\] ]]; then
#   #   printf "\033[33m$1\033[0m\n"
#   # elif [[ $1 =~ \[DEBUG\] ]]; then
#   #   printf "\033[36m$1\033[0m\n"
#   # fi
#   #
#   # # Colorize date
#   # if [[ $1 =~ \[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\] ]]; then
#   #   printf "\033[32m%s\033[0m"
#   # fi
#   #
#   # # Colorize logger
#   # # if [[ $1 =~ rsc\.srv\. ]]; then
#   # #   printf "\033[34m%s\033[0m"
#   # # fi
#   # if [[ $1 =~ \[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\] \s+ ([a-z]+\.[a-z]+\.[a-z]+) ]]; then
#   #   printf "\033[34m%s\033[0m"
#   # fi
#   #
#   # # Colorize phpsessid and identity
#   # if [[ $1 =~ [a-f0-9]{32} ]]; then
#   #   printf "\033[35m%s\033[0m"
#   # fi
#   #
#   # # Colorize JSON structure
#   # if [[ $1 =~ \{ ]]; then
#   #   printf "\033[37m%s\033[0m"
#   # fi
#   #
#   printf "\n"
# }
#
# # Function to tail a log file and colorize the output
# function ctail() {
#   if [[ -n "$1" ]]; then
#     tail -f "$1" | while read line; do
#       colorize "$line"
#     done
#   else
#     echo -e "Usage: ctail <logfile>\n"
#     echo -e "it colorizes log files with the format [date] logger [phpsessid] message [array|json]"
#   fi
# }

colorize_log() {
    # Color codes
    local date_color='\033[32m'    # Green
    local logger_color='\033[34m'  # Blue
    local level_color='\033[33m'   # Yellow
    local session_color='\033[35m' # Magenta
    local message_color='\033[37m' # White
    local json_color='\033[36m'    # Cyan
    local reset_color='\033[0m'    # Reset

    # Read the input line
    local line="$1"

    # Extract and colorize parts
    local date=$(echo "$line" | rg -o '^\[.*?\]' | tr -d '[]')
    local logger=$(echo "$line" | sed -E 's/.*] ([a-z]+\.[a-z]+\.[a-z]+).*/\1/')
    local level=$(echo "$line" | rg -o '(DEBUG|INFO)')
    local session=$(echo "$line" | rg -o '\[[a-f0-9]{32}\]')
    local message=$(echo "$line" | sed -E 's/.*\] ([^[]+).*/\1/' | sed -E 's/\[.*\]$//')
    # local json=$(echo "$line" | rg -o '\[.*\]$')
    local json=$(echo "$line" | sed -E 's/.*(\[.*\]|\{.*\})$/\1/')

    # Print colorized parts
    printf "${date_color}[${date}]${reset_color} "
    printf "${logger_color}${logger}${reset_color} "
    printf "${level_color}${level}${reset_color} "
    printf "${session_color}${session}${reset_color} "
    printf "${message_color}${message}${reset_color}"

    # Format and colorize JSON if present
    if [ ! -z "$json" ]; then
        echo -n " "
        echo "$json" | jq -C '.'
    else
        echo  # New line if no JSON
    fi
}

# Function to tail a log file and colorize each line
# ctail() {
#     if [ -z "$1" ]; then
#         echo "Usage: ctail <logfile>"
#         return 1
#     fi
#     tail -f "$1" | while IFS= read -r line; do
#         colorize_log "$line"
#     done
# }

ctail() {
    if [ -z "$1" ]; then
        echo "Usage: ctail <logfile>"
        return 1
    fi
    tail -f "$1" | bat --paging=never --style=plain --language=MyCustomLogViewer --theme="MyCustomLogViewer"
}


function php_syntax_check_2() {
    local exclude_dirs=("vendor" "node_modules")
    local exclude_pattern=""
    for dir in "${exclude_dirs[@]}"; do
        exclude_pattern="$exclude_pattern -o -name $dir"
    done
    exclude_pattern=${exclude_pattern#" -o "}

    echo "Counting PHP files..."
    local total_files=$(find . \( -type d \( $exclude_pattern \) -prune \) -o -type f -name "*.php" -print | wc -l)
    echo "Found $total_files PHP files to check."

    local current_file=0
    local errors=0

    echo "Checking PHP syntax..."
    find . \( -type d \( $exclude_pattern \) -prune \) -o -type f -name "*.php" -print0 | 
    while IFS= read -r -d '' file; do
        ((current_file++))
        result=$(php -l "$file" 2>&1)
        if [[ $result != *"No syntax errors detected"* ]]; then
            echo "$result"
            ((errors++))
        fi
        printf "\rProgress: %d/%d files checked" $current_file $total_files
    done

    echo "\nPHP syntax check complete."
    echo "Files with errors: $errors"
}


rename_files_in_folder() {
    # Check if a base name was provided
    if [[ -z "$1" ]]; then
        echo "Error: Please provide a base name."
        echo "Usage: rename_files_in_folder <base_name> [sort_by]"
        echo ""
        echo "Usage examples:"
        echo "rename_files_in_folder "new_base_name"        # Sorts by name (default)"
        echo "rename_files_in_folder "new_base_name" "time" # Sorts by creation time"
        echo ""
        return 1
    fi

    # Set the base name and sorting order
    local base_name="$1"
    local sort_by="${2:-name}"  # Default to "name" if no second argument is provided
    local counter=1

    # Determine sorting method and get the sorted list of files
    if [[ "$sort_by" == "time" ]]; then
        # Sort by creation time (oldest to newest)
        files=($(/bin/ls -1t --time=creation))
    else
        # Sort by name (alphabetical)
        files=($(/bin/ls -1))
    fi

    # for file in "${files[@]}"; do
    #   echo "$file"
    # done

    Loop over each file in the sorted list
    for file in "${files[@]}"; do
        # Check if it's a regular file (not a directory or symlink)
        if [[ -f "$file" ]]; then
            # Get the file extension
            local ext="${file##*.}"
            local formatted_counter=$(printf "%03d" "$counter")
            # Define the new file name with the base name and formatted counter
            local new_name="${base_name}_${formatted_counter}.${ext}"
            # Rename the file
            mv "$file" "$new_name"
            echo "Renamed '$file' to '$new_name'"
            # Increment the counter
            ((counter++))
        fi
    done
}

function how_to_vim_profiling () {
  cat <<-END

  You can use built-in profiling support: after launching vim do

  :profile start profile.log
  :profile func *
  :profile file *

  At this point do slow actions

  :profile pause
  :noautocmd qall!
  

  (unlike quitting noautocmd is not really required, it just makes vim quit faster).

  Note: you won’t get information about functions there were deleted before vim quit.


  https://stackoverflow.com/a/12216578/2864517

END
echo
}



function how_to_ka() {
  cat <<-END
  KA ab den Sprint # 157
  https://capacity.krankikom.de/projects/intern/admin-allg/sprint/157


END
echo
}


function how_to_php () {
  cat <<-END
  php_versions or show_php_versions  shows the current available versions


  to change version:

     $ brew unlink php@8.1 && brew link --overwrite --force php@7.2

  current installed versions:

  php
  php-cs-fixer
  php@7.0
  php@7.2
  php@7.4
  php@8.1

END
echo
}


function docker_clean_up() {
  cat <<-END
  Docker's disk is full. Clean up unused images, containers and build cache:

  $ docker system prune -a

  That removes stopped containers, unused images, and build cache. If you want to be more targeted:

  $ docker builder prune        # build cache only
  $ docker image prune -a       # unused images only

  Check how much space was freed:

  $ docker system df
END
echo
}

git_add_tag() {
    local VERSION=$1

    if [[ -z "$VERSION" ]]; then
        echo "Usage: gt v<major>.<minor>.<patch>"
        echo "Example: gt v1.5.28"
        return 1
    fi

    if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Error: version must match format v99.99.99 (e.g. v1.5.28)"
        return 1
    fi

    local LAST_COMMIT=$(git log -1 --pretty=format:"%h %s")
    echo ""
    echo "Last commit: $LAST_COMMIT"
    echo ""
    read "INPUT_MSG?Tag message [$VERSION]: "

    local MESSAGE="${INPUT_MSG:-$VERSION}"
    if [[ "$MESSAGE" != $VERSION* ]]; then
        MESSAGE="$VERSION: $MESSAGE"
    fi

    echo ""
    echo "Creating tag: $VERSION"
    echo "Message:      $MESSAGE"
    echo "Commit:       $LAST_COMMIT"
    echo ""
    read "CONFIRM?Push to origin? [Y/n]: "
    CONFIRM=${CONFIRM:-Y}

    git tag -a "$VERSION" -m "$MESSAGE"

    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
        git push origin "$VERSION"
        echo "Tag $VERSION pushed to origin."
    else
        echo "Tag $VERSION created locally. Run 'git push origin $VERSION' to push."
    fi
}
