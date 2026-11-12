#!/bin/sh
set -eu

tag=$1
remote=${2:-origin}
branch=release

version=$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' plugin/.claude-plugin/plugin.json)
if [ "v$version" != "$tag" ]; then
    echo "tag $tag does not match plugin version $version" >&2
    exit 1
fi
if [ ! -x plugin/bin/elvis ]; then
    echo "plugin/bin/elvis is not built" >&2
    exit 1
fi

GIT_INDEX_FILE=$(mktemp -u)
export GIT_INDEX_FILE
git read-tree --empty
git add -f .claude-plugin/marketplace.json plugin/.claude-plugin/plugin.json plugin/hooks/hooks.json plugin/bin/elvis
tree=$(git write-tree)
rm -f "$GIT_INDEX_FILE"
unset GIT_INDEX_FILE

parent=$(git ls-remote "$remote" "refs/heads/$branch" | cut -f1)
if [ -n "$parent" ]; then
    git fetch -q "$remote" "$branch"
fi
commit=$(git commit-tree "$tree" ${parent:+-p "$parent"} -m "release: $tag")
git push "$remote" "$commit:refs/heads/$branch"
