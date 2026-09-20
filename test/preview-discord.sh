#!/usr/bin/env bash
#
# Preview or send a Discord notification locally, without pushing anything to GitHub.
#
# The payload is produced by the real composite action: this script pulls the `run:` body out of
# .github/actions/discord-notify/action.yml and executes it, so what you see here is byte for byte
# what CI would send. There is no second copy of the logic to drift.
#
#   ./test/preview-discord.sh                                  # render only, sends nothing
#   ./test/preview-discord.sh --status failure                 # preview the failure template
#   ./test/preview-discord.sh --file build/libs/app.jar        # preview with an attachment
#   ./test/preview-discord.sh --template .github/discord/success.json   # your own template
#
#   ./test/preview-discord.sh --send "$WEBHOOK"                # actually post it
#   ./test/preview-discord.sh --send "$WEBHOOK" --lifecycle    # post "running", then edit to
#                                                              # "passed" after 5s
#
# Requires: bash, jq, curl and python (with PyYAML).

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ACTION_DIR="$REPO_ROOT/.github/actions/discord-notify"

STATUS="success"
TEMPLATE=""
TEMPLATE_JSON=""
ATTACH=""
WEBHOOK=""
MESSAGE_ID=""
LIFECYCLE=false
SEND=false
TITLE=""
ACCENT=""
USERNAME_IN="zMenu"
# Mirrors build.yml's discord-avatar-url default, so the preview shows the same webhook
# identity CI would post under. Discord falls back to the webhook's own picture when empty.
AVATAR_IN="https://github.com/GroupeZ-dev.png"

while [ $# -gt 0 ]; do
  case "$1" in
    --send)       SEND=true; WEBHOOK="${2:-}"; shift 2 ;;
    --status)     STATUS="${2:-}"; shift 2 ;;
    --template)   TEMPLATE="${2:-}"; shift 2 ;;
    --template-json) TEMPLATE_JSON="${2:-}"; shift 2 ;;
    --file)       ATTACH="${2:-}"; shift 2 ;;
    --edit)       MESSAGE_ID="${2:-}"; shift 2 ;;
    --title)      TITLE="${2:-}"; shift 2 ;;
    --accent)     ACCENT="${2:-}"; shift 2 ;;
    --username)   USERNAME_IN="${2:-}"; shift 2 ;;
    --avatar)     AVATAR_IN="${2:-}"; shift 2 ;;
    --lifecycle)  LIFECYCLE=true; shift ;;
    -h|--help)    sed -n '2,25p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

# On Windows, `python3` can be only a Microsoft Store alias. Select the first
# command that can actually start Python instead of trusting its presence on PATH.
PYTHON=""
for candidate in python3 python py; do
  if command -v "$candidate" > /dev/null 2>&1 \
    && "$candidate" -c 'import sys' > /dev/null 2>&1; then
    PYTHON="$candidate"
    break
  fi
done
[ -n "$PYTHON" ] || { echo "error: python is required but not installed." >&2; exit 1; }
"$PYTHON" -c 'import yaml' > /dev/null 2>&1 \
  || { echo "error: Python needs PyYAML. Install it with: py -3 -m pip install PyYAML" >&2; exit 1; }

for tool in jq curl; do
  command -v "$tool" > /dev/null 2>&1 || { echo "error: '$tool' is required but not installed." >&2; exit 1; }
done

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# Pull the action's script out of the YAML so this harness cannot drift from it.
"$PYTHON" - "$ACTION_DIR/action.yml" "$WORK/notify.sh" <<'PY'
import io, sys, yaml
src, dst = sys.argv[1], sys.argv[2]
with open(src, encoding="utf-8") as fh:
    doc = yaml.safe_load(fh)
body = doc["runs"]["steps"][0]["run"]
io.open(dst, "w", newline="\n", encoding="utf-8").write(body)
PY

# Realistic sample data, so the preview shows what a real build looks like rather than
# placeholder mush.
SAMPLE_VALUES=$(cat <<'JSON'
{
  "project": "zMenu",
  "repo": "GroupeZ-dev/zMenu",
  "repo_name": "zMenu",
  "repo_owner": "GroupeZ-dev",
  "repo_url": "https://github.com/GroupeZ-dev/zMenu",
  "workflow": "Build",
  "event": "push",
  "attempt": "1",
  "run_id": "17420962",
  "run_number": "128",
  "url": "https://github.com/GroupeZ-dev/zMenu/actions/runs/17420962",
  "ref": "main",
  "ref_type": "branch",
  "default_branch": "main",
  "sha": "abc1234",
  "sha_full": "abc1234def5678901234567890abcdef12345678",
  "subject": "fix: correct the inventory click handler",
  "author": "1robie",
  "commit_url": "https://github.com/GroupeZ-dev/zMenu/commit/abc1234",
  "compare_url": "https://github.com/GroupeZ-dev/zMenu/compare/9f2e1a0...abc1234",
  "pr": "",
  "pr_number": "",
  "pr_url": "",
  "actor": "1robie",
  "actor_url": "https://github.com/1robie",
  "avatar": "https://avatars.githubusercontent.com/u/1?size=64",
  "java": "25",
  "build_tool": "gradle",
  "runner_os": "Linux",
  "started_at": "2026-09-15T10:04:00Z",
  "started_epoch": "1789200240",
  "started_at_discord": "<t:1789200240:F>",
  "started_relative": "<t:1789200240:R>",
  "status": "success",
  "tests": "38 tests, all passing",
  "tests_total": "38",
  "tests_failed": "0",
  "tests_errors": "0",
  "tests_skipped": "0",
  "tests_passed": "true",
  "duration": "1m 3s",
  "duration_seconds": "63",
  "finished_at": "2026-09-15T10:05:03Z",
  "finished_epoch": "1789200303",
  "finished_at_discord": "<t:1789200303:F>",
  "finished_relative": "<t:1789200303:R>",
  "artifact": "zMenu-1.0.0.jar",
  "artifact_size": "3.4 MiB",
  "artifact_count": "1",
  "artifact_bytes": "3565158",
  "changelog": "```diff\n+ abc1234: fix: correct the inventory click handler\n+ 9f2e1a0: feat: add /zmenu reload\n+ 3c7b881: docs: document the reload command\n+ 55a0e12: build(deps): bump adventure to 4.17.0\n```",
  "commits": "4",
  "commits_shown": "4",
  "commit_range": "9f2e1a0..HEAD"
}
JSON
)

run_notify() {
  local status="$1" msg_id="$2" capture="$3" attach="${4-$ATTACH}"
  (
    export GITHUB_OUTPUT="$WORK/output.txt"
    export ACTION_PATH="$ACTION_DIR"
    export STATUS="$status"
    export TEMPLATE="$TEMPLATE"
    export TEMPLATE_JSON="$TEMPLATE_JSON"
    export VALUES="$SAMPLE_VALUES"
    export TITLE="$TITLE"
    export ACCENT="$ACCENT"
    export MESSAGE_ID="$msg_id"
    export USERNAME="$USERNAME_IN"
    export AVATAR_URL="$AVATAR_IN"
    export ATTACH_FILE="$attach"
    export FILE_MAX_BYTES=9437184
    export STRIP_UNKNOWN=true
    export FAIL_ON_ERROR=true
    export CAPTURE="$capture"

    if [ "$SEND" = true ]; then
      export WEBHOOK="$WEBHOOK"
    else
      export WEBHOOK="https://discord.invalid/api/webhooks/0/dry-run"
      export PATH="$WORK/stub:$PATH"
    fi

    : > "$GITHUB_OUTPUT"
    bash "$WORK/notify.sh"
  )
}

if [ "$SEND" != true ]; then
  mkdir -p "$WORK/stub"
  cat > "$WORK/stub/curl" <<'STUB'
#!/usr/bin/env bash
prev=""
for a in "$@"; do
  case "$a" in payload_json=*) cp "${a#payload_json=<}" "$CAPTURE" ;; esac
  if [ "$prev" = "--data" ]; then cp "${a#@}" "$CAPTURE"; fi
  prev="$a"
done
echo '{"id":"000000000000000000"}'
STUB
  chmod +x "$WORK/stub/curl"
fi

show_payload() {
  local file="$1"
  echo
  echo "──────────── rendered payload ────────────"
  jq . "$file"
  echo
  echo "──────────── reads as ────────────"
  jq -r '
    def walk_components:
      if type == "array" then .[] | walk_components
      elif type == "object" then
        if .type == 10 then .content
        elif .type == 14 then "────────────────────"
        elif .type == 13 then "[file] " + (.file.url // "")
        elif .type == 1 then ([.components[] | "[ " + .label + " ]"] | join(" "))
        else (.components // empty | walk_components), (.accessory // empty | walk_components)
        end
      else empty end;
    .components | walk_components
  ' "$file"
  echo "──────────────────────────────────"
  local n
  n=$(jq '[.. | objects | select(has("type"))] | length' "$file")
  echo "components: $n / 40 max   payload: $(wc -c < "$file") bytes"
  if jq -e 'has("attachments")' "$file" > /dev/null; then
    echo "attachments: $(jq -c '.attachments' "$file")"
  fi
}

if [ "$SEND" = true ]; then
  if [ -z "$WEBHOOK" ]; then
    echo "error: --send needs a webhook URL" >&2
    exit 2
  fi
  case "$WEBHOOK" in
    https://discord.com/api/webhooks/*|https://*.discord.com/api/webhooks/*|https://discordapp.com/api/webhooks/*|https://*.discordapp.com/api/webhooks/*) ;;
    *) echo "error: that does not look like a Discord webhook URL." >&2; exit 2 ;;
  esac

  if [ "$LIFECYCLE" = true ]; then
    echo "==> posting the 'build running' message"
    run_notify start "" "$WORK/sent.json" ""
    ID=$(grep '^message-id=' "$WORK/output.txt" | tail -1 | cut -d= -f2-)
    if [ -z "$ID" ]; then
      echo "no message id came back; stopping before the edit." >&2
      exit 1
    fi
    echo "==> posted $ID, editing it to '$STATUS' in 5s so you can watch it change"
    sleep 5
    run_notify "$STATUS" "$ID" "$WORK/sent.json"
  else
    run_notify "$STATUS" "$MESSAGE_ID" "$WORK/sent.json"
  fi
  echo
  echo "Sent. message-id: $(grep '^message-id=' "$WORK/output.txt" | tail -1 | cut -d= -f2-)"
else
  echo "DRY RUN - nothing is sent. Add --send \"\$WEBHOOK\" when the preview looks right."
  run_notify "$STATUS" "$MESSAGE_ID" "$WORK/payload.json"
  show_payload "$WORK/payload.json"
fi
