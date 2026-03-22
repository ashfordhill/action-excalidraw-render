#!/bin/sh
set -e

FORMAT="${INPUT_FORMAT:-svg}"
GITHUB_TOKEN="${INPUT_GITHUB_TOKEN:-}"
COMMIT_MESSAGE="${INPUT_COMMIT_MESSAGE:-chore: render excalidraw files [skip ci]}"
COMMITTER_NAME="${INPUT_COMMITTER_NAME:-github-actions[bot]}"
COMMITTER_EMAIL="${INPUT_COMMITTER_EMAIL:-github-actions[bot]@users.noreply.github.com}"
EXCALIDRAW_URL="${EXCALIDRAW_BRUTE_EXPORT_CLI_URL:-http://excalidraw:80}"
WORKSPACE="${GITHUB_WORKSPACE:-/workspace}"
REPO="${GITHUB_REPOSITORY:-}"

echo "=== Excalidraw Render ==="
echo "Format:     $FORMAT"
echo "Excalidraw: $EXCALIDRAW_URL"
echo "Workspace:  $WORKSPACE"

case "$FORMAT" in
  svg|png|both) ;;
  *)
    echo "ERROR: Invalid format '$FORMAT'. Must be one of: svg, png, both"
    exit 1
    ;;
esac

FILES=$(find "$WORKSPACE" \
  \( -path "*/.git" -o -path "*/node_modules" -o -path "*/.zenflow" \) -prune -o \
  -name "*.excalidraw" -type f -print)

if [ -z "$FILES" ]; then
  echo "No .excalidraw files found."
  exit 0
fi

echo ""
echo "Found:"
echo "$FILES"
echo ""

CHANGED_FILES_LIST=""

do_convert() {
  INPUT="$1"
  FMT="$2"
  OUTPUT="${INPUT%.excalidraw}.${FMT}"
  echo "  [$FMT] $(basename "$INPUT") -> $(basename "$OUTPUT")"
  excalidraw-brute-export-cli \
    -i "$INPUT" \
    --background true \
    --dark-mode false \
    --embed-scene false \
    --scale 1 \
    --format "$FMT" \
    -o "$OUTPUT" \
    --url "$EXCALIDRAW_URL"
  CHANGED_FILES_LIST="${CHANGED_FILES_LIST}${OUTPUT}
"
}

for FILE in $FILES; do
  echo "Processing: $FILE"
  case "$FORMAT" in
    svg)  do_convert "$FILE" svg ;;
    png)  do_convert "$FILE" png ;;
    both)
      do_convert "$FILE" svg
      do_convert "$FILE" png
      ;;
  esac
done

if [ -z "$(printf '%s' "$CHANGED_FILES_LIST" | tr -d '[:space:]')" ]; then
  echo "No files generated."
  exit 0
fi

cd "$WORKSPACE"
git config user.email "$COMMITTER_EMAIL"
git config user.name "$COMMITTER_NAME"

printf '%s\n' "$CHANGED_FILES_LIST" | while IFS= read -r F; do
  [ -n "$F" ] && git add "$F"
done

if git diff --staged --exit-code > /dev/null 2>&1; then
  echo "Nothing to commit (rendered files are already up to date)."
else
  git commit -m "$COMMIT_MESSAGE"
  if [ -n "$GITHUB_TOKEN" ] && [ -n "$REPO" ]; then
    git remote set-url origin "https://x-access-token:${GITHUB_TOKEN}@github.com/${REPO}.git"
    git push
    echo "Committed and pushed rendered files."
  else
    echo "No GITHUB_TOKEN/GITHUB_REPOSITORY set — skipping push (local mode)."
  fi
fi
