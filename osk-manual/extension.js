// The on-screen keyboard never pops up by itself; swipe up from the bottom
// edge of the screen to open it, like on a desktop with a touchscreen.
//
// GNOME opens its keyboard from several places (an app reporting an active
// text field, focus on one of GNOME Shell's own text fields, ...), all
// through Keyboard.open(). The swipe gesture goes through open() too, but
// while a gesture is in progress. So open() is only let through then;
// closing works as before.

import * as KeyboardUI from 'resource:///org/gnome/shell/ui/keyboard.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

const proto = KeyboardUI.Keyboard.prototype;

export default class OskManualExtension extends Extension {
    enable() {
        const origOpen = this._origOpen = proto.open;
        proto.open = function (...args) {
            if (!this._gestureInProgress)
                return;
            origOpen.apply(this, args);
        };
    }

    disable() {
        proto.open = this._origOpen;
    }
}
