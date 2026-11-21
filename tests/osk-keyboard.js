// On-screen keyboard test, run inside GNOME Shell on the phone by
// osk-keyboard.sh (read that first). It makes its own text field, opens
// the keyboard with a swipe and presses keys with a virtual finger, then
// leaves its verdicts in global.__oskTest.
//
// The placeholder CONTROL is replaced by osk-keyboard.sh: true turns the
// osk-long-press extension off for the run, to see the bugs come back.

(async () => {
    const CONTROL = __CONTROL__;
    const UUID = 'osk-long-press@phoneputer';

    const {default: Clutter} = await import('gi://Clutter');
    const {default: GLib} = await import('gi://GLib');
    const {default: St} = await import('gi://St');
    const Main = await import('resource:///org/gnome/shell/ui/main.js');

    const res = global.__oskTest = {done: false, checks: [], log: []};
    const check = (name, ok, detail = '') => res.checks.push({name, ok: !!ok, detail});
    const sleep = ms => new Promise(r => GLib.timeout_add(GLib.PRIORITY_DEFAULT, ms, () => {
        r();
        return GLib.SOURCE_REMOVE;
    }));

    // A virtual finger and keyboard. Coordinates are GNOME's (logical)
    // pixels. Made once per GNOME Shell and never disposed: mutter handles
    // their events later, in its input thread, and disposing a device with
    // events still on the way crashes GNOME Shell (SEGV in
    // notify_keyval_in_impl; it logged the phone out once).
    const seat = global.stage.context.get_backend().get_default_seat();
    const finger = global.__oskTestFinger ??=
        seat.create_virtual_device(Clutter.InputDeviceType.TOUCHSCREEN_DEVICE);
    const keys = global.__oskTestKeys ??=
        seat.create_virtual_device(Clutter.InputDeviceType.KEYBOARD_DEVICE);
    const now = () => GLib.get_monotonic_time();
    const press = async (x, y, ms) => {
        finger.notify_touch_down(now(), 0, x, y);
        await sleep(ms);
        finger.notify_touch_up(now(), 0);
    };
    const swipeUp = async () => {
        const x = global.stage.width / 2;
        let y = global.stage.height - 1;
        finger.notify_touch_down(now(), 0, x, y);
        for (let i = 0; i < 20; i++) {
            await sleep(16);
            y -= 30;
            finger.notify_touch_motion(now(), 0, x, y);
        }
        finger.notify_touch_up(now(), 0);
    };

    // The visible key with this icon (each layer has its own copy), as
    // the point in its middle; the leftmost one if there are two.
    const keyboard = () => Main.keyboard.keyboardActor;
    const controller = () => keyboard()._keyboardController;
    const findKey = iconName => {
        const found = [];
        const walk = a => {
            for (const c of a.get_children()) {
                if (c.keyButton?.mapped && c._icon?.icon_name === iconName) {
                    const [x, y] = c.keyButton.get_transformed_position();
                    const [w, h] = c.keyButton.get_transformed_size();
                    found.push([x + w / 2, y + h / 2]);
                }
                walk(c);
            }
        };
        walk(keyboard());
        return found.sort((a, b) => a[0] - b[0])[0];
    };

    let entry = null;
    try {
        // Wake the screen if it went blank: a tap on shift.
        keys.notify_keyval(now(), Clutter.KEY_Shift_L, Clutter.KeyState.PRESSED);
        keys.notify_keyval(now(), Clutter.KEY_Shift_L, Clutter.KeyState.RELEASED);
        await sleep(500);

        const ext = Main.extensionManager.lookup(UUID);
        check('osk-long-press is installed', ext, ext ? `state ${ext.state}` : 'not found');
        if (CONTROL && ext)
            await Main.extensionManager.disableExtension(UUID);

        // Our own text field at the top of the screen.
        entry = new St.Entry({
            style: 'background-color: white; color: black; font-size: 20px; padding: 8px;',
            x: 20, y: 80, width: global.stage.width - 40,
        });
        Main.layoutManager.addTopChrome(entry);
        await sleep(100);
        entry.clutter_text.grab_key_focus();
        await sleep(300);
        check('the test field has input-method focus', Main.inputMethod.currentFocus);

        if (!Main.keyboard.visible)
            await swipeUp();
        await sleep(800);
        check('the keyboard is open', Main.keyboard.visible);

        // An earlier test copy (live patch from Eval) would hide the bug.
        let patched = false;
        const walk = a => a.get_children().forEach(c => {
            patched ||= !!c.__lpFix;
            walk(c);
        });
        walk(keyboard());
        check('no live test patch on the keys', !patched,
            patched ? 'log out and back in first' : '');

        const backspace = findKey('osk-delete-symbolic');
        const text = () => entry.get_text();
        const setText = t => {
            entry.set_text(t);
            entry.clutter_text.set_cursor_position(-1);
        };

        // 1. A tap deletes one character and leaves no delete mode on.
        setText('abc');
        await sleep(300);
        await press(...backspace, 100);
        await sleep(500);
        check('tap: one character deleted', text() === 'ab', `text "${text()}"`);
        check('tap: delete mode off afterwards', !controller()._deleteEnabled);

        // 2. Holding deletes while held, and stops when the finger lifts.
        setText('een twee drie vier vijf zes zeven acht negen tien');
        await sleep(300);
        const before = text().length;
        let duringHold = null, lenDuringHold = null;
        const held = press(...backspace, 1500);
        await sleep(1400);
        duringHold = controller()._deleteEnabled;
        lenDuringHold = text().length;
        await held;
        await sleep(500);
        check('hold: deletes while held', duringHold && lenDuringHold < before,
            `${before} -> ${lenDuringHold} characters`);
        check('hold: delete mode off after lifting', !controller()._deleteEnabled);

        // 3. What comes in after that stays (this was the dictation bug).
        Main.inputMethod.commit(' blijft staan');
        await sleep(1000);
        check('hold: text typed afterwards stays', text().endsWith(' blijft staan'),
            `text "${text()}"`);
        if (controller()._deleteEnabled)
            controller().toggleDelete(false); // clean up after a failure

        // 4. After a long press on shift (caps lock), a tap on shift counts.
        const kb = keyboard();
        await press(...findKey('osk-shift-symbolic'), 1000);
        await sleep(400);
        const capsOn = kb._currentPage === kb._layers.shift && kb._latched;
        await press(...findKey('osk-shift-symbolic'), 100);
        await sleep(400);
        check('shift: long press turns caps lock on', capsOn);
        check('shift: the next tap turns it off', kb._currentPage === kb._layers.default,
            kb._currentPage === kb._layers.default ? '' : 'still upper case');
    } catch (e) {
        check('test ran without errors', false, `${e} at ${e.stack?.split(String.fromCharCode(10))[0]}`);
    } finally {
        const kb = keyboard();
        if (kb?._layers && kb._currentPage !== kb._layers.default) {
            kb._setActiveLevel('default');
            kb._setLatched(false);
        }
        entry?.destroy();
        Main.keyboard.close(true);
        if (CONTROL && Main.extensionManager.lookup(UUID))
            await Main.extensionManager.enableExtension(UUID);
        res.done = true;
    }
})();
1;
