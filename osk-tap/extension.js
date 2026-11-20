// Opens the on-screen keyboard when a text field is tapped.
//
// GNOME shows its keyboard when an app turns on text input in response to
// a tap. Chromium-based apps (Signal Desktop, Brave, other Electron apps)
// turn text input on once, when a field gets focus, and never ask again,
// so the keyboard never comes up. This watches for taps: shortly after a
// finger lifts, if a text field has the input focus and the keyboard is
// hidden, it opens the keyboard. Firefox and GTK apps already work and
// aren't affected (their keyboard is already up by then).

import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

const DELAY_MS = 150; // let the app move its text focus first

export default class OskTapExtension extends Extension {
    enable() {
        this._handler = global.stage.connect('captured-event', (_stage, event) => {
            if (event.type() === Clutter.EventType.TOUCH_END)
                this._schedule();
            return Clutter.EVENT_PROPAGATE;
        });
    }

    _schedule() {
        if (this._timeout)
            GLib.source_remove(this._timeout);
        this._timeout = GLib.timeout_add(GLib.PRIORITY_DEFAULT, DELAY_MS, () => {
            this._timeout = 0;
            if (Main.inputMethod._currentFocus && !Main.keyboard.visible)
                Main.keyboard.open(Main.layoutManager.bottomIndex);
            return GLib.SOURCE_REMOVE;
        });
    }

    disable() {
        global.stage.disconnect(this._handler);
        if (this._timeout)
            GLib.source_remove(this._timeout);
        this._timeout = 0;
    }
}
