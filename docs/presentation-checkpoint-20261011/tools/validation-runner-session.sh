#!/usr/bin/env bash
set -Eeuo pipefail
mode=${1:?mode}
checkout=${2:?checkout}
run=${3:?fresh-run-name}
case "$checkout" in /home/otp/Projects/hex-latest|/home/otp/Projects/hex-improvements-20261011) ;; *) exit 2;; esac
[[ "$run" =~ ^[a-z0-9-]+$ ]] || exit 2
run_root="/tmp/hex-probe-$run"
mkdir -p "$run_root"
exec 9>"$checkout/.godot/hex-screen-validation.lock"
flock -n 9 || exit 3
export XDG_DATA_HOME="$run_root/data" XDG_CONFIG_HOME="$run_root/config" XDG_CACHE_HOME="$run_root/cache"
unset FLUX2_TEST_MODE FLUX2_TEST_SUITES
args=(--path "$checkout")
native=0
engine=godot
case "$mode" in
  import) args+=(--headless --editor --import);;
  focused) args+=(--headless --script res://tests/run_all.gd -- --suite=hex-render-polygon-cache,hex-render-frame,paid-field-rendering,large-world-rendering,projectile-surface-depth,wellspring-environment-details,element-audio,hex-projectile-facets,element-delivery-presentation,sight-occlusion,player-camera-rig,pov-terrain-context,pov-presentation,bootstrap-catch-up,performance-presentation,solo-duel-world-tell);;
  polygon) args+=(--headless --audio-driver Dummy --script res://tests/performance/profile_hex_polygon_cache.gd);;
  full) args+=(--headless --script res://tests/run_all.gd);;
  boot) args+=(--headless --quit-after 60 -- --no-lan-discovery --fullbody-art --pixel-cast);;
  export)
    mkdir -p "$checkout/exports/$run"
    args+=(--headless --export-release 'Linux x86_64' "$checkout/exports/$run/hex.x86_64");;
  portable)
    native=1
    engine="$checkout/exports/hex-screen-smoothness-20261011/hex.x86_64"
    args=(-- --no-lan-discovery --fullbody-art --pixel-cast --safe-quit-smoke);;
  profile)
    native=1
    script=res://scripts/profile-gameplay.gd
    if [[ "$checkout" == /home/otp/Projects/hex-latest ]]; then script=res://.godot/hex-screen-profile.gd; fi
    args+=(--script "$script" -- --no-lan-discovery --fullbody-art --pixel-cast "--profile-user-data=$XDG_DATA_HOME/Godot/app_userdata/FLUX 2" "--profile-output=$run_root/measurements.json" --profile-seconds=10 --profile-profiles=low --profile-cases=hearth_idle,garden_middle,paid_all_six_mantle,movement_boundary,paid_fire_bolt_close --profile-screenshots);;
  backdrop) native=1; args+=(--script res://tests/visual/test_pov_backdrop_transition.gd -- "--output=$run_root/native");;
  effects) native=1; args+=(--script res://tests/visual/capture_projectile_surface_depth.gd -- "--output=res://.godot/projectile-depth-native-$run");;
  world-audio) native=1; args+=(--audio-driver Dummy --script res://tests/visual/capture_world_audio_details.gd -- "--output=$run_root/native");;
  *) exit 2;;
esac
printf 'RUN %s %s\n' "$mode" "$run_root"
timeout 1800 "$engine" "${args[@]}" >"$run_root/engine.log" 2>&1 &
supervisor=$!
if (( native )); then
  # Float only this test process on the existing desktop. It neither edits the
  # compositor configuration nor changes another application's window rules.
  for attempt in {1..100}; do
    child=$(pgrep -P "$supervisor" -x Godot_v4.7.1-st 2>/dev/null || pgrep -P "$supervisor" 2>/dev/null || true)
    if [[ "$child" =~ ^[0-9]+$ ]] && command -v swaymsg >/dev/null; then
      reply=$(swaymsg "[pid=$child] floating enable, resize set width 1280 px height 720 px, focus" 2>/dev/null || true)
      if [[ "$reply" == *'"success": true'* && "$reply" != *'"success": false'* ]]; then
        printf '%s\n' "$reply" > "$run_root/window-setup.json"
        break
      fi
    fi
    kill -0 "$supervisor" 2>/dev/null || break
    sleep 0.1
  done
fi
status=0
wait "$supervisor" || status=$?
python - "$run_root/engine.log" <<'PY'
import pathlib,sys
lines=pathlib.Path(sys.argv[1]).read_text(errors='replace').splitlines()
for line in lines:
    if any(tag in line for tag in ('SCRIPT ERROR','Parse Error','Compile Error','ERROR:','FAIL:','PASS:','PROFILE_COMPLETE')):
        print(line[:600])
print('\n'.join(lines[-5:])[:1200])
if any(any(tag in line for tag in ('SCRIPT ERROR','Parse Error','Compile Error','ERROR:','FAIL:')) for line in lines):
    sys.exit(1)
PY
exit "$status"
