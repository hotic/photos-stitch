#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_EXECUTABLE="$HOME/Applications/拼成长图.app/Contents/MacOS/PhotosStitch"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/photos-stitch-smoke.XXXXXX")"
SAMPLES_DIR="$WORK_DIR/samples"
OUTPUT_DIR="$WORK_DIR/output"

"$ROOT_DIR/scripts/build.sh" >/dev/null
mkdir -p "$SAMPLES_DIR" "$OUTPUT_DIR"

swift "$ROOT_DIR/scripts/generate_samples.swift" "$SAMPLES_DIR"

SIPS_DIMENSIONS() {
  sips -g pixelWidth -g pixelHeight "$1" \
    | awk '
        /pixelWidth:/ { width = $2 }
        /pixelHeight:/ { height = $2 }
        END { print width " " height }
      '
}

EXPECTED_HEIGHT() {
  awk -v target_width="$1" -v width="$2" -v height="$3" 'BEGIN { printf "%d", int((height * target_width / width) + 0.5) }'
}

sips -s format jpeg "$SAMPLES_DIR/sample-02.png" --out "$SAMPLES_DIR/sample-02.jpg" >/dev/null
sips -s format heic "$SAMPLES_DIR/sample-03.png" --out "$SAMPLES_DIR/sample-03.heic" >/dev/null
touch -mt 202401020304 "$SAMPLES_DIR/sample-01.png"

RUN_OUTPUT="$(
  PHOTOS_STITCH_SKIP_IMPORT=1 \
  PHOTOS_STITCH_OUTPUT_DIR="$OUTPUT_DIR" \
  "$APP_EXECUTABLE" \
    "$SAMPLES_DIR/sample-01.png" \
    "$SAMPLES_DIR/sample-02.jpg" \
    "$SAMPLES_DIR/sample-03.heic" \
    "$SAMPLES_DIR/sample-04.png"
)"

printf '%s\n' "$RUN_OUTPUT"

OUTPUT_FILE="$(find "$OUTPUT_DIR" -maxdepth 1 -type f | head -n 1)"
CREATION_DATE="$(printf '%s\n' "$RUN_OUTPUT" | awk -F= '/^PHOTOS_STITCH_CREATION_DATE=/{print $2; exit}')"

if [[ -z "$OUTPUT_FILE" ]]; then
  echo "No stitched image produced" >&2
  exit 1
fi

read -r FIRST_WIDTH FIRST_HEIGHT <<<"$(SIPS_DIMENSIONS "$SAMPLES_DIR/sample-01.png")"
read -r SECOND_WIDTH SECOND_HEIGHT <<<"$(SIPS_DIMENSIONS "$SAMPLES_DIR/sample-02.jpg")"
read -r THIRD_WIDTH THIRD_HEIGHT <<<"$(SIPS_DIMENSIONS "$SAMPLES_DIR/sample-03.heic")"
read -r FOURTH_WIDTH FOURTH_HEIGHT <<<"$(SIPS_DIMENSIONS "$SAMPLES_DIR/sample-04.png")"
read -r OUTPUT_WIDTH OUTPUT_HEIGHT <<<"$(SIPS_DIMENSIONS "$OUTPUT_FILE")"

EXPECTED_TOTAL_HEIGHT=$(
  awk \
    -v h1="$FIRST_HEIGHT" \
    -v h2="$(EXPECTED_HEIGHT "$FIRST_WIDTH" "$SECOND_WIDTH" "$SECOND_HEIGHT")" \
    -v h3="$(EXPECTED_HEIGHT "$FIRST_WIDTH" "$THIRD_WIDTH" "$THIRD_HEIGHT")" \
    -v h4="$(EXPECTED_HEIGHT "$FIRST_WIDTH" "$FOURTH_WIDTH" "$FOURTH_HEIGHT")" \
    'BEGIN { print h1 + h2 + h3 + h4 }'
)

if [[ "$OUTPUT_WIDTH" != "$FIRST_WIDTH" ]]; then
  echo "Unexpected output width: got $OUTPUT_WIDTH expected $FIRST_WIDTH" >&2
  exit 1
fi

if [[ "$OUTPUT_HEIGHT" != "$EXPECTED_TOTAL_HEIGHT" ]]; then
  echo "Unexpected output height: got $OUTPUT_HEIGHT expected $EXPECTED_TOTAL_HEIGHT" >&2
  exit 1
fi

if [[ "$CREATION_DATE" != "2024-01-01T19:04:00Z" ]]; then
  echo "Unexpected propagated creation date: $CREATION_DATE" >&2
  exit 1
fi

PIXEL_OUTPUT="$(
  swift - "$OUTPUT_FILE" "$(( FIRST_HEIGHT / 4 ))" "$(( (FIRST_HEIGHT * 3) / 4 ))" <<'SWIFT'
import CoreGraphics
import Foundation
import ImageIO

let imageURL = URL(fileURLWithPath: CommandLine.arguments[1])
let topY = Int(CommandLine.arguments[2])!
let bottomY = Int(CommandLine.arguments[3])!

guard let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
      let data = image.dataProvider?.data,
      let ptr = CFDataGetBytePtr(data) else {
    fatalError("failed to inspect output image")
}

func pixel(atX x: Int, yFromTop: Int) -> String {
    let offset = yFromTop * image.bytesPerRow + x * 4
    let r = ptr[offset]
    let g = ptr[offset + 1]
    let b = ptr[offset + 2]
    return "\(r) \(g) \(b)"
}

print(pixel(atX: 10, yFromTop: topY))
print(pixel(atX: 10, yFromTop: bottomY))
SWIFT
)"

TOP_PIXEL="$(printf '%s\n' "$PIXEL_OUTPUT" | sed -n '1p')"
BOTTOM_PIXEL="$(printf '%s\n' "$PIXEL_OUTPUT" | sed -n '2p')"

read -r TOP_R TOP_G TOP_B <<<"$TOP_PIXEL"
read -r BOTTOM_R BOTTOM_G BOTTOM_B <<<"$BOTTOM_PIXEL"

if (( TOP_R <= TOP_B )); then
  echo "Top of the first stitched panel is not warm-toned as expected: $TOP_PIXEL" >&2
  exit 1
fi

if (( BOTTOM_B <= BOTTOM_R )); then
  echo "Bottom of the first stitched panel is not cool-toned as expected: $BOTTOM_PIXEL" >&2
  exit 1
fi

echo "Output file: $OUTPUT_FILE"
sips -g pixelWidth -g pixelHeight "$OUTPUT_FILE"
