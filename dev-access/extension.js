// Developer access: GNOME Shell's "unsafe mode".
//
// Normally only a few GNOME programs may take screenshots, and Shell
// JavaScript can't be run from outside. In unsafe mode any program in the
// session may (org.gnome.Shell.Screenshot, org.gnome.Shell.Eval). That's
// what lets a coding agent working over SSH see the screen and drive
// GNOME, like adb on Android. Turn it off in gnome-phone.nix (devAccess).

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

export default class DevAccessExtension extends Extension {
    enable() {
        this._previous = global.context.unsafe_mode;
        global.context.unsafe_mode = true;
    }

    disable() {
        global.context.unsafe_mode = this._previous;
    }
}
