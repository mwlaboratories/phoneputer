// A long press on a key of the on-screen keyboard ends when you lift your
// finger.
//
// GNOME Shell 51's keyboard (ui/keyboard.js) gives a long press a meaning
// on two keys: holding backspace deletes until you let go, holding shift
// turns caps lock on. Both are wound down in the key's 'released' handler,
// and GNOME sends 'released' only after a click. A long press swallows
// that click, so after a long press:
//
// - backspace's delete mode stays on: everything that later lands in the
//   text field (typed, pasted, dictated) is deleted again at once, word
//   by word, until you tap backspace once more;
// - the flag that keeps the shift key's own release from undoing caps
//   lock (Keyboard._longPressed) stays set, so the next tap on shift is
//   ignored.
//
// This ends exactly those two, and nothing else: no key's tap action runs.
//
// - Delete mode goes off when a key's long-press gesture ends (finger up)
//   or is cancelled (keyboard closed). It has to stop right at the lift,
//   or text arriving afterwards would still be deleted.
// - The shift flag is cleared when the next finger lands on the keyboard:
//   the flag only means "ignore the release of the key that was held",
//   and a new press is never that release. Not tied to the gesture,
//   because holding shift switches the keyboard to its upper-case layer,
//   which hides the held key and can cancel its gesture before this code
//   even hears that the long press began (seen on the first caps lock
//   after GNOME Shell starts).
//
// Both run after GNOME's own handling: delete mode on the next idle tick,
// so if GNOME ever does send 'released' after a long press it goes first.

import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as KeyboardUI from 'resource:///org/gnome/shell/ui/keyboard.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

const proto = KeyboardUI.Keyboard.prototype;

export default class OskLongPressExtension extends Extension {
    enable() {
        // Gesture -> its handler ids, to undo on disable.
        this._gestures = new Map();
        this._idleId = 0;

        // Keys are made row by row in _addRowKeys(), for every keyboard
        // GNOME builds (a new one comes with every layout change).
        const ext = this;
        const origAddRowKeys = this._origAddRowKeys = proto._addRowKeys;
        proto._addRowKeys = function (keys, layout, ...rest) {
            origAddRowKeys.call(this, keys, layout, ...rest);
            ext._watchKeys(this, layout);
        };
        // The keyboard that already exists.
        const keyboard = Main.keyboard.keyboardActor;
        if (keyboard)
            this._watchKeys(keyboard, keyboard);

        // 'captured-event' runs before the keys see the event.
        const box = Main.layoutManager.keyboardBox;
        this._pressId = box.connect('captured-event', (_actor, event) => {
            if (this._isPress(event) && Main.keyboard.keyboardActor)
                Main.keyboard.keyboardActor._longPressed = false;
            return Clutter.EVENT_PROPAGATE;
        });
    }

    disable() {
        proto._addRowKeys = this._origAddRowKeys;
        Main.layoutManager.keyboardBox.disconnect(this._pressId);
        for (const [gesture, ids] of this._gestures)
            ids.forEach(id => gesture.disconnect(id));
        this._gestures = null;
        if (this._idleId)
            GLib.source_remove(this._idleId);
        this._idleId = 0;
    }

    // A finger or the mouse going down (not the mouse press GNOME fakes
    // from a touch).
    _isPress(event) {
        switch (event.type()) {
        case Clutter.EventType.TOUCH_BEGIN:
            return true;
        case Clutter.EventType.BUTTON_PRESS:
            return !(event.get_flags() & Clutter.EventFlags.FLAG_POINTER_EMULATED);
        default:
            return false;
        }
    }

    // A key (Key in ui/keyboard.js, not exported) is the actor with a
    // keyButton; its long-press gesture sits on that button.
    _watchKeys(keyboard, actor) {
        for (const child of actor.get_children()) {
            if (child.keyButton)
                this._watchKey(keyboard, child);
            this._watchKeys(keyboard, child);
        }
    }

    _watchKey(keyboard, key) {
        const gesture = key.keyButton.get_actions()
            .find(a => a instanceof Clutter.LongPressGesture);
        if (!gesture || this._gestures.has(gesture))
            return;
        const ended = () => this._endDelete(keyboard);
        this._gestures.set(gesture, [
            gesture.connect('end', ended),
            gesture.connect('cancel', ended),
        ]);
        key.connect('destroy', () => this._gestures?.delete(gesture));
    }

    // Delete mode is only ever left on by a held backspace.
    _endDelete(keyboard) {
        if (this._idleId)
            return;
        this._idleId = GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
            this._idleId = 0;
            const controller = keyboard._keyboardController;
            if (controller?._deleteEnabled)
                controller.toggleDelete(false);
            return GLib.SOURCE_REMOVE;
        });
    }
}
