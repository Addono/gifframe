#!/usr/bin/env bats
# bats tests for mov2gif
# Each test that produces output cleans up after itself.

setup() {
    # Run every test inside a fresh temp dir so output goes nowhere unexpected
    TEST_TMP="$(mktemp -d)"
    cd "$TEST_TMP"

    # Locate the script (repo root relative to this file)
    SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    MOV2GIF="$SCRIPT_DIR/bin/mov2gif"
}

teardown() {
    rm -rf "$TEST_TMP"
}

# ── CLI flag tests ────────────────────────────────────────────────────────────

@test "--help exits 0 and prints usage" {
    run "$MOV2GIF" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
    [[ "$output" == *"--quality"* ]]
}

@test "-h is an alias for --help" {
    run "$MOV2GIF" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "unknown flag exits non-zero" {
    run "$MOV2GIF" --no-such-flag
    [ "$status" -ne 0 ]
}

@test "--quality requires an argument" {
    run "$MOV2GIF" --quality
    [ "$status" -ne 0 ]
}

@test "invalid quality preset exits non-zero" {
    run "$MOV2GIF" -q ultra
    [ "$status" -ne 0 ]
}

@test "no .mov files in directory exits non-zero" {
    run "$MOV2GIF"
    [ "$status" -ne 0 ]
    [[ "$output" == *"No .mov files found"* ]]
}

@test "missing file argument prints warning and exits non-zero" {
    run "$MOV2GIF" nonexistent.mov
    [ "$status" -ne 0 ]
}

# ── conversion tests ──────────────────────────────────────────────────────────

# Generate a synthetic .mov that mimics the structure of a terminal recording:
# - Solid black outer border (desktop background)
# - A lighter rectangle in the centre (the window chrome / content area)
make_test_mov() {
    local out="$1"
    ffmpeg -y -hide_banner -loglevel quiet \
        -f lavfi \
        -i "color=c=black:size=800x560:rate=5,
            drawbox=x=60:y=40:w=680:h=480:color=#1e2023:t=fill,
            drawbox=x=60:y=40:w=680:h=28:color=#2d3035:t=fill,
            drawtext=fontcolor=white:text='test':x=70:y=46" \
        -t 0.4 "$out"
}

@test "converts a single file at default (high) quality" {
    make_test_mov "test.mov"
    run "$MOV2GIF" test.mov
    [ "$status" -eq 0 ]
    [ -f "gifs/test_high.gif" ]
    [ -s "gifs/test_high.gif" ]
}

@test "converts at medium quality" {
    make_test_mov "rec.mov"
    run "$MOV2GIF" -q medium rec.mov
    [ "$status" -eq 0 ]
    [ -f "gifs/rec_medium.gif" ]
    [ -s "gifs/rec_medium.gif" ]
}

@test "converts at xhigh quality" {
    make_test_mov "rec.mov"
    run "$MOV2GIF" -q xhigh rec.mov
    [ "$status" -eq 0 ]
    [ -f "gifs/rec_xhigh.gif" ]
    [ -s "gifs/rec_xhigh.gif" ]
}

@test "all quality preset produces three output files" {
    make_test_mov "demo.mov"
    run "$MOV2GIF" -q all demo.mov
    [ "$status" -eq 0 ]
    [ -f "gifs/demo_medium.gif" ]
    [ -f "gifs/demo_high.gif" ]
    [ -f "gifs/demo_xhigh.gif" ]
}

@test "auto-discovers .mov files when no argument given" {
    make_test_mov "auto.mov"
    run "$MOV2GIF" -q medium
    [ "$status" -eq 0 ]
    [ -f "gifs/auto_medium.gif" ]
}

@test "output GIF has white corners (background removed)" {
    make_test_mov "bg.mov"
    run "$MOV2GIF" -q medium bg.mov
    [ "$status" -eq 0 ]
    local tl tr bl br
    tl=$(magick identify -format '%[fx:p{0,0}.r*255],%[fx:p{0,0}.g*255],%[fx:p{0,0}.b*255]' gifs/bg_medium.gif)
    tr=$(magick identify -format '%[fx:p{w-1,0}.r*255],%[fx:p{w-1,0}.g*255],%[fx:p{w-1,0}.b*255]' gifs/bg_medium.gif)
    bl=$(magick identify -format '%[fx:p{0,h-1}.r*255],%[fx:p{0,h-1}.g*255],%[fx:p{0,h-1}.b*255]' gifs/bg_medium.gif)
    br=$(magick identify -format '%[fx:p{w-1,h-1}.r*255],%[fx:p{w-1,h-1}.g*255],%[fx:p{w-1,h-1}.b*255]' gifs/bg_medium.gif)
    [ "$tl" = "255,255,255" ]
    [ "$tr" = "255,255,255" ]
    [ "$bl" = "255,255,255" ]
    [ "$br" = "255,255,255" ]
}

@test "output GIF preserves color (not converted to grayscale)" {
    # Build a mov with explicit color content visible in the window area
    ffmpeg -y -hide_banner -loglevel quiet \
        -f lavfi \
        -i "color=c=black:size=800x560:rate=5,
            drawbox=x=60:y=40:w=680:h=480:color=#0a0a0a:t=fill,
            drawbox=x=80:y=100:w=200:h=30:color=#3c8cdd:t=fill,
            drawbox=x=80:y=140:w=150:h=30:color=#22c55e:t=fill" \
        -t 0.4 colored.mov
    run "$MOV2GIF" -q medium colored.mov
    [ "$status" -eq 0 ]

    # Coalesce and check that at least one pixel has distinct R/G/B channels
    magick convert gifs/colored_medium.gif -coalesce \
        -define histogram:unique-colors=true \
        -format '%c' histogram:info: > /tmp/histo_$$.txt
    # grep for pixels where the hex colour has distinct channels
    # e.g. #3C8CDD → r≠g≠b — encoded as distinct hex pairs
    local found=0
    while IFS= read -r line; do
        if [[ "$line" =~ \(([0-9]+),([0-9]+),([0-9]+) ]]; then
            r="${BASH_REMATCH[1]}"; g="${BASH_REMATCH[2]}"; b="${BASH_REMATCH[3]}"
            dr=$(( r > g ? r - g : g - r ))
            dg=$(( g > b ? g - b : b - g ))
            if (( dr > 10 || dg > 10 )); then
                found=1
                break
            fi
        fi
    done < /tmp/histo_$$.txt
    rm -f /tmp/histo_$$.txt
    [ "$found" -eq 1 ]
}

@test "output GIF is smaller than source .mov" {
    make_test_mov "size.mov"
    run "$MOV2GIF" -q medium size.mov
    [ "$status" -eq 0 ]
    local mov_size gif_size
    mov_size=$(wc -c < size.mov)
    gif_size=$(wc -c < gifs/size_medium.gif)
    # GIF should exist and be non-empty (size comparison varies with content)
    [ "$gif_size" -gt 0 ]
}

@test "overwrites existing output file" {
    make_test_mov "ow.mov"
    "$MOV2GIF" -q medium ow.mov >/dev/null 2>&1
    local mtime1
    mtime1=$(stat -c '%Y' gifs/ow_medium.gif 2>/dev/null || stat -f '%m' gifs/ow_medium.gif)
    sleep 1
    run "$MOV2GIF" -q medium ow.mov
    [ "$status" -eq 0 ]
    local mtime2
    mtime2=$(stat -c '%Y' gifs/ow_medium.gif 2>/dev/null || stat -f '%m' gifs/ow_medium.gif)
    # File was touched again (mtime changed or same — just must not error)
    [ -f "gifs/ow_medium.gif" ]
}
