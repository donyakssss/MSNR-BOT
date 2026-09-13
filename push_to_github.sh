#!/usr/bin/env bash
set -e
if [ -z "$1" ]; then
  echo "Usage: $0 <git-remote-url> [branch]"
  exit 1
fi
REMOTE_URL=$1
BRANCH=${2:-main}
git remote add origin "$REMOTE_URL" || git remote set-url origin "$REMOTE_URL"
git branch -M "$BRANCH"
git push -u origin "$BRANCH"
echo "Pushed to $REMOTE_URL on branch $BRANCH"
