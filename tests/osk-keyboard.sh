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
# hold and shift checks should FAIL, which shows the test can see the bug.
#
# Prints PASS or FAIL per check; exits non-zero if anything failed.

set -euo pipefail

control=false
if [[ ${1:-} == --control ]]; then control=true; shift; fi
phone=${1:-root@192.168.0.237}
here=$(dirname "$0")

eval_js() {
    # gdbus reads its argument as GVariant text: no \n escapes in the JS.
    ssh "$phone" "runuser -u nix -- env DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus \
        gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell \
        --method org.gnome.Shell.Eval \"\$(cat)\"" <<<"$1"
}

eval_js "$(sed "s/__CONTROL__/$control/" "$here/osk-keyboard.js")" >/dev/null

# One "PASS|FAIL  name  (detail)" per check, joined by " ## " (Eval's
# answer can't hold newlines), or "running" while the test is busy.
report='const r = global.__oskTest;
!r?.done ? "running" : r.checks.map(c =>
    `${c.ok ? "PASS" : "FAIL"}  ${c.name}${c.detail ? `  (${c.detail})` : ""}`).join(" ## ")'

out=running
for _ in $(seq 60); do
    sleep 0.5
    out=$(eval_js "$report")
    [[ $out == *running* ]] || break
done
if [[ $out == *running* ]]; then
    echo 'FAIL  the test did not finish (screen off? logged out?)'
    exit 1
fi

# Eval answers (true, '<text>'): unwrap and put each check on its own line.
out=${out#\(true, \'}
out=${out%\'\)}
sed 's/ ## /\n/g' <<<"$out"
[[ $out != *FAIL* ]]
