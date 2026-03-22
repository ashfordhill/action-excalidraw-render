#!/bin/sh
set -e

FORMAT="${INPUT_FORMAT:-svg}"
EXCALIDRAW_URL="${EXCALIDRAW_BRUTE_EXPORT_CLI_URL:-http://excalidraw:80}"
WORKSPACE="${GITHUB_WORKSPACE:-/workspace}"

echo "=== Excalidraw Render ==="
echo "Format:     $FORMAT"
echo "Excalidraw: $EXCALIDRAW_URL"
echo "Workspace:  $WORKSPACE"

echo "Waiting for Excalidraw to be ready..."
for i in $(seq 1 60); do
  if wget -q --spider "${EXCALIDRAW_URL}" 2>/dev/null; then
    echo "Excalidraw ready (attempt $i)"
    break
  fi
  if [ "$i" -eq 60 ]; then
    echo "ERROR: Excalidraw did not become ready in time"
    exit 1
  fi
  echo "  attempt $i/60..."
  sleep 3
done

case "$FORMAT" in
  svg|png|both) ;;
  *)
    echo "ERROR: Invalid format '$FORMAT'. Must be one of: svg, png, both"
    exit 1
    ;;
esac

FIND_LIST=$(mktemp)
trap 'rm -f "$FIND_LIST"' EXIT

find "$WORKSPACE" \
  \( -path "*/.git" -o -path "*/node_modules" -o -path "*/.zenflow" \) -prune -o \
  -name "*.excalidraw" -type f -print \
  > "$FIND_LIST"

if [ ! -s "$FIND_LIST" ]; then
  echo "No .excalidraw files found."
  exit 0
fi

echo ""
echo "Found:"
cat "$FIND_LIST"
echo ""

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
}

while IFS= read -r FILE; do
  echo "Processing: $FILE"
  case "$FORMAT" in
    svg)  do_convert "$FILE" svg ;;
    png)  do_convert "$FILE" png ;;
    both)
      do_convert "$FILE" svg
      do_convert "$FILE" png
      ;;
  esac
done < "$FIND_LIST"

echo "Done."
