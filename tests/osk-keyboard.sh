#!/usr/bin/env bash
# Tests the on-screen keyboard on the phone, from your PC over SSH.
#
#   tests/osk-keyboard.sh [--control] [root@PHONE]
#
# It needs dev-access (GNOME Shell's Eval) and you logged in on the phone
# with the screen on. It makes its own text field at the top of the
# screen, opens the keyboard, presses keys with a virtual finger and
# removes it all again; leave the phone alone for the ~10 s it takes.
#
# --control turns the osk-long-press extension off for the run: then the
# hold and shift checks should FAIL, which shows the test can see the bug;
# the long-press-on-?123/hide checks pass either way (stock behaviour).
#
# OSK_TEST_BUS=<address> talks to another GNOME Shell than your session's,
# e.g. a headless one started for testing while nobody is logged in.
#
# Prints PASS or FAIL per check; exits non-zero if anything failed.

set -euo pipefail

control=false
if [[ ${1:-} == --control ]]; then control=true; shift; fi
phone=${1:-root@192.168.0.237}
bus=${OSK_TEST_BUS:-unix:path=/run/user/1001/bus}
here=$(dirname "$0")

eval_js() {
    # gdbus reads its argument as GVariant text: no \n escapes in the JS.
    ssh "$phone" "runuser -u nix -- env DBUS_SESSION_BUS_ADDRESS=$bus \
        gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell \
        --method org.gnome.Shell.Eval \"\$(cat)\"" <<<"$1"
}

eval_js "$(sed "s/__CONTROL__/$control/" "$here/osk-keyboard.js")" >/dev/null

# One "PASS|FAIL  name  (detail)" line per check, or "running" while the
# test is busy. Base64, so no quoting on the way (JSON inside GVariant
# inside SSH) can mangle it.
report='const r = global.__oskTest;
const lines = r?.done ? r.checks.map(c =>
    `${c.ok ? "PASS" : "FAIL"}  ${c.name}${c.detail ? `  (${c.detail})` : ""}`) : ["running"];
imports.gi.GLib.base64_encode(new TextEncoder().encode(lines.join(String.fromCharCode(10))))'

out=running
for _ in $(seq 60); do
    sleep 0.5
    # Eval answers (true, '"<base64>"'): keep the base64.
    out=$(eval_js "$report" | sed -E 's/^\(true, .."?([A-Za-z0-9+/=]*).*$/\1/' | base64 -d)
    [[ $out == running ]] || break
done
if [[ $out == running || -z $out ]]; then
    echo 'FAIL  the test did not finish (screen off? logged out?)'
    exit 1
fi
echo "$out"
[[ $out != *FAIL* ]]
