// Dictation on the on-screen keyboard: speak, check the text, send it.
//
// The empty bar above the keys is GNOME's word-suggestions row (empty
// because nothing here suggests words). This puts a microphone button at
// its left. Tap it and speak: the words appear in the bar as you say them,
// the ones not yet certain dimmed. Tap it again to stop; tap again to add
// more. The send button types the text into the app where your cursor is;
// the cross throws it away. Nothing is typed until you press send.
//
// The listening is done by the dictation service (../../dictation.js), on
// the session bus. It needs a Soniox API key in ~/.config/soniox/api-key;
// without one the bar says so.

import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Pango from 'gi://Pango';
import St from 'gi://St';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as KeyboardUI from 'resource:///org/gnome/shell/ui/keyboard.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

const DictationProxy = Gio.DBusProxy.makeProxyWrapper(`
<node>
  <interface name="org.phoneputer.Dictation">
    <method name="Start"/>
    <method name="Stop"/>
    <method name="Discard"/>
    <signal name="Changed">
      <arg type="s" name="state"/>
      <arg type="s" name="text"/>
      <arg type="s" name="partial"/>
      <arg type="s" name="error"/>
    </signal>
  </interface>
</node>`);

const proto = KeyboardUI.Keyboard.prototype;

export default class OskVoiceExtension extends Extension {
    enable() {
        this._status = {state: 'idle', text: '', partial: '', error: ''};
        this._sendWhenDone = false;

        // The service starts on the first tap of the microphone (D-Bus
        // starts it then), not at login.
        this._proxy = new DictationProxy(Gio.DBus.session,
            'org.phoneputer.Dictation', '/org/phoneputer/Dictation',
            (_proxy, error) => {
                if (error)
                    console.error(`osk-voice: ${error.message}`);
            }, null, Gio.DBusProxyFlags.DO_NOT_AUTO_START_AT_CONSTRUCTION);
        this._changedId = this._proxy.connectSignal('Changed',
            (_proxy, _sender, [state, text, partial, error]) =>
                this._onChanged({state, text, partial, error}));

        // GNOME makes a new keyboard when the keyboard setting changes;
        // the bar goes into every one.
        const ext = this;
        const origSetup = this._origSetup = proto._setupKeyboard;
        proto._setupKeyboard = function (...args) {
            origSetup.apply(this, args);
            ext._addBar(this);
        };
        if (Main.keyboard.keyboardActor)
            this._addBar(Main.keyboard.keyboardActor);

        // Closing the keyboard stops listening; the text stays.
        this._visibilityId = Main.keyboard.connect('visibility-changed', () => {
            if (!Main.keyboard.visible && this._isRecording())
                this._call('Stop');
        });
    }

    disable() {
        Main.keyboard.disconnect(this._visibilityId);
        proto._setupKeyboard = this._origSetup;
        this._removeBar();
        // Don't leave the microphone on.
        if (this._isRecording())
            this._call('Discard');
        this._proxy.disconnectSignal(this._changedId);
        this._proxy = null;
    }

    // The bar: [mic] [suggestions or the text] [discard] [send]. It takes
    // the suggestions row's place and style, and keeps that row inside it,
    // so word suggestions still work if an input method offers them.
    _addBar(keyboard) {
        this._removeBar();
        const suggestions = keyboard._suggestions;
        const index = keyboard.get_children().indexOf(suggestions);
        if (index < 0)
            return;

        const bar = new St.BoxLayout({
            style_class: 'word-suggestions',
            x_expand: true,
        });
        // Big enough for a thumb: a 28 px icon centred in a fixed 56 px wide
        // button that fills the bar's height, so the three line up.
        const button = (iconName, onClick) => {
            const b = new St.Button({
                child: new St.Icon({
                    icon_name: iconName,
                    icon_size: 28,
                    x_align: Clutter.ActorAlign.CENTER,
                    y_align: Clutter.ActorAlign.CENTER,
                }),
                style: 'width: 56px; padding: 0;',
                y_expand: true,
                y_align: Clutter.ActorAlign.FILL,
            });
            b.connect('clicked', onClick);
            return b;
        };
        this._mic = button('audio-input-microphone-symbolic', () => this._onMic());
        this._discard = button('window-close-symbolic', () => this._onDiscard());
        this._send = button('mail-send-symbolic', () => this._onSend());

        this._label = new St.Label({
            x_expand: true,
            y_align: Clutter.ActorAlign.CENTER,
        });
        // Long text: show the end, where the new words come in.
        this._label.clutter_text.ellipsize = Pango.EllipsizeMode.START;

        keyboard.remove_child(suggestions);
        this._suggestionsStyle = suggestions.style;
        suggestions.style = 'padding: 0; min-height: 0;'; // the bar has them
        suggestions.x_expand = true;
        bar.add_child(this._mic);
        bar.add_child(suggestions);
        bar.add_child(this._label);
        bar.add_child(this._discard);
        bar.add_child(this._send);
        keyboard.insert_child_at_index(bar, index);

        this._keyboard = keyboard;
        this._bar = bar;
        this._suggestions = suggestions;
        this._destroyId = keyboard.connect('destroy', () => this._forgetBar());
        this._update();
    }

    _removeBar() {
        if (!this._bar)
            return;
        const {_keyboard: keyboard, _bar: bar, _suggestions: suggestions} = this;
        keyboard.disconnect(this._destroyId);
        bar.remove_child(suggestions);
        suggestions.style = this._suggestionsStyle;
        suggestions.x_expand = false;
        suggestions.show();
        keyboard.insert_child_at_index(suggestions,
            keyboard.get_children().indexOf(bar));
        bar.destroy();
        this._forgetBar();
    }

    _forgetBar() {
        this._keyboard = this._bar = this._suggestions = null;
        this._mic = this._label = this._discard = this._send = null;
    }

    _isRecording() {
        const {state} = this._status;
        return state === 'connecting' || state === 'listening';
    }

    _call(method) {
        this._proxy?.[`${method}Async`]().catch(e => {
            // Most likely the service isn't installed or failed to start.
            Gio.DBusError.strip_remote_error(e);
            this._onChanged({...this._status, error: `Dictation: ${e.message}`});
        });
    }

    _onMic() {
        if (this._isRecording())
            this._call('Stop');
        else if (this._status.state === 'idle')
            this._call('Start');
    }

    _onDiscard() {
        this._sendWhenDone = false;
        this._call('Discard');
        // Clear at once (also an error the service never knew about).
        this._onChanged({state: 'idle', text: '', partial: '', error: ''});
    }

    // Still listening: stop first and send once Soniox has the last words.
    _onSend() {
        if (this._status.state === 'idle') {
            this._type(this._status.text);
            this._onDiscard();
        } else {
            this._sendWhenDone = true;
            this._call('Stop');
        }
    }

    _onChanged(status) {
        this._status = status;
        // An error may have cut the text short: you send it yourself then.
        if (this._sendWhenDone && status.state === 'idle' && !status.error) {
            this._type(status.text);
            this._onDiscard();
            return;
        }
        if (status.state === 'idle')
            this._sendWhenDone = false;
        this._update();
    }

    // Types the text where the cursor is, the way GNOME's keyboard does:
    // KeyboardController.commit() in ui/keyboard.js. Its last step, for an
    // app with a text field (Main.inputMethod.currentFocus), hands the
    // whole string to the app at once. Its other steps send key presses
    // one character at a time, and skip any text with a character that has
    // no key (most accented and non-Latin letters), so whole sentences go
    // that last way. Without a text field (older X11 apps) the keyboard's
    // own commit() sends key presses.
    _type(text) {
        if (!text)
            return;
        if (Main.inputMethod.currentFocus)
            Main.inputMethod.commit(text);
        else
            this._keyboard?._keyboardController.commit(text).catch(console.error);
    }

    _update() {
        if (!this._bar)
            return;
        const {state, text, partial, error} = this._status;
        const recording = this._isRecording();
        const hasText = !!(text || partial);

        this._mic.checked = recording;
        this._mic.child.style = recording ? 'color: #e01b24;' : null;
        this._mic.reactive = state !== 'finishing';

        // After an error the words heard so far stay, so you can still
        // send them; the error follows them.
        let markup = '';
        if (hasText)
            markup = `${esc(text)}<span alpha="55%">${esc(partial)}</span>`;
        if (error)
            markup += `${hasText ? ' ' : ''}<span foreground="#e01b24">${esc(error)}</span>`;
        if (!markup && state === 'connecting')
            markup = '<span alpha="55%">Connecting…</span>';
        else if (!markup && recording)
            markup = '<span alpha="55%">Listening…</span>';
        this._label.clutter_text.set_markup(markup);

        const showLabel = markup !== '';
        this._label.visible = showLabel;
        this._suggestions.visible = !showLabel;
        this._send.visible = hasText;
        this._discard.visible = hasText || !!error;
    }
}

function esc(text) {
    return GLib.markup_escape_text(text, -1);
}
