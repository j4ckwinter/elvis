#!/bin/sh
set -eu

for tool in claude jq; do
    if ! command -v "$tool" > /dev/null; then
        echo "this check needs $tool" >&2
        exit 2
    fi
done

scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT

mkdir -p "$scratch/plugin/.claude-plugin" "$scratch/plugin/hooks"
cat > "$scratch/plugin/.claude-plugin/plugin.json" <<EOF
{"name": "payload-log", "version": "0.0.0", "description": "Keeps what Claude Code hands a hook after each command."}
EOF
cat > "$scratch/plugin/hooks/hooks.json" <<EOF
{"hooks": {"PostToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": "cat >> '$scratch/payloads'"}]}]}}
EOF

git init -q --bare "$scratch/remote.git"
git init -q "$scratch/work"
cd "$scratch/work"
git remote add origin "$scratch/remote.git"
echo note > note.txt

ELVIS_HOME="$scratch/home" ELVIS_AUTOSTART=0 claude -p \
    'Run these three commands with the Bash tool, one call each, in this order, and do nothing else: `git add note.txt`, then `git commit -m note`, then `git push origin HEAD`.' \
    --plugin-dir "$scratch/plugin" \
    --allowedTools 'Bash(git add:*)' 'Bash(git commit:*)' 'Bash(git push:*)' < /dev/null > /dev/null

if [ -z "$(git ls-remote origin)" ]; then
    echo "the session did not push a commit, so there is nothing to read" >&2
    exit 2
fi
if [ ! -s "$scratch/payloads" ]; then
    echo "Claude Code ran no hook after the commands, so there is nothing to read" >&2
    exit 2
fi

version=$(claude --version)
unmarked=0
for deed in commit push; do
    if jq -es --arg deed "$deed" 'any(.[]; .tool_response.gitOperation[$deed] != null)' "$scratch/payloads" > /dev/null; then
        echo "$version marks a $deed"
    else
        echo "$version did not mark a $deed in tool_response.gitOperation" >&2
        unmarked=1
    fi
done
exit $unmarked
