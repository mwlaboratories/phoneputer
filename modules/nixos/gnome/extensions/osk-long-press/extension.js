// Letting go of a key you held down on the on-screen keyboard counts as
// letting go.
//
// GNOME Shell 51's keyboard (ui/keyboard.js) learns that a key was let go
// only from a click on it. A long press swallows that click, so after you
// hold a key GNOME never hears you lift your finger. For backspace that
// means its "delete while held" mode stays on: everything that later lands
// in the text field (typed, pasted, dictated) is deleted again at once,
// word by word, until you tap backspace once more. A long press on shift
// leaves the next tap on shift ignored, for the same reason.
//
// Every key has a long-press gesture; when that gesture ends (finger up)
// or is cancelled (the keyboard closes), this sends the key's 'released'
// signal that GNOME waits for. Measured on the phone over SSH: with this,
// backspace's delete mode is off 0.5 s after lifting; without it, it stays
// on. A short tap doesn't trigger the gesture, so taps work as before.

import Clutter from 'gi://Clutter';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as KeyboardUI from 'resource:///org/gnome/shell/ui/keyboard.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

const proto = KeyboardUI.Keyboard.prototype;

export default class OskLongPressExtension extends Extension {
    enable() {
        // Gesture -> its handler ids, to undo on disable.
        this._gestures = new Map();

        // Keys are made row by row in _addRowKeys(), for every keyboard
        // GNOME builds (a new one comes with every layout change).
        const ext = this;
        const origAddRowKeys = this._origAddRowKeys = proto._addRowKeys;
        proto._addRowKeys = function (keys, layout, ...rest) {
            origAddRowKeys.call(this, keys, layout, ...rest);
            ext._fixKeys(layout);
        };
        // The keyboard that already exists.
        if (Main.keyboard.keyboardActor)
            this._fixKeys(Main.keyboard.keyboardActor);
    }

    disable() {
        proto._addRowKeys = this._origAddRowKeys;
        for (const [gesture, ids] of this._gestures)
            ids.forEach(id => gesture.disconnect(id));
        this._gestures = null;
    }

    // A key (Key in ui/keyboard.js, not exported) is the actor with a
    // keyButton; the long-press gesture sits on that button.
    _fixKeys(actor) {
        for (const child of actor.get_children()) {
            if (child.keyButton)
                this._fixKey(child);
            this._fixKeys(child);
        }
    }

    _fixKey(key) {
        const gesture = key.keyButton.get_actions()
            .find(a => a instanceof Clutter.LongPressGesture);
        if (!gesture || this._gestures.has(gesture))
            return;

        let held = false;
        const letGo = () => {
            if (held) {
                held = false;
                key.emit('released');
            }
        };
        this._gestures.set(gesture, [
            gesture.connect('recognize', () => (held = true)),
            gesture.connect('end', letGo),
            gesture.connect('cancel', letGo),
        ]);
        key.connect('destroy', () => this._gestures?.delete(gesture));
    }
}
