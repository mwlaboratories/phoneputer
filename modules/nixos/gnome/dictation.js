// Voice dictation: microphone in, text out (run by dictation.nix).
//
// A small service on the session bus, org.phoneputer.Dictation. On Start
// it records the microphone with pw-record and streams the sound to
// Soniox, a speech-to-text service on the internet, which sends back the
// words as you speak. The text only collects here; nothing is typed. A
// client shows it and decides what to do with it: the on-screen keyboard's
// microphone button (extensions/osk-voice) types it into the app when you
// press send. That way you always see the text before it goes anywhere.
//
// Soniox needs an API key (https://console.soniox.com). It is read from
// ~/.config/soniox/api-key at every Start, so it never ends up in the Nix
// store or in this repository:
//
//   mkdir -p ~/.config/soniox
//   install -m 600 /dev/stdin ~/.config/soniox/api-key   # paste, Enter, Ctrl+D
//
// The Soniox protocol is the same as in Faceclaw (app/native/soniox-stt.ts):
// a websocket; the first message is JSON with the key and the audio format,
// then raw 16 kHz 16-bit mono audio; an empty text message means "no more
// audio". Soniox answers with tokens, pieces of words. A final token is
// sent once and never changes; the non-final ones are its current guess
// and come again, maybe changed, in every answer.

import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Soup from 'gi://Soup?version=3.0';

const BUS_NAME = 'org.phoneputer.Dictation';
const OBJECT_PATH = '/org/phoneputer/Dictation';

const SONIOX_URL = 'wss://stt-rt.soniox.com/transcribe-websocket';
const SONIOX_MODEL = 'stt-rt-v5';
const SAMPLE_RATE = 16000;
const CHUNK_BYTES = SAMPLE_RATE * 2 / 10; // 100 ms of audio

// How long to wait for Soniox's last words after Stop.
const FINISH_TIMEOUT_MS = 5000;

const KEY_FILE = GLib.build_filenamev([GLib.get_user_config_dir(), 'soniox', 'api-key']);

// The languages you speak, as a hint (dictation.nix sets them). Soniox
// still recognises others.
const LANGUAGE_HINTS = (GLib.getenv('SONIOX_LANGUAGE_HINTS') ?? '')
    .split(',').map(s => s.trim()).filter(s => s);

// state is idle, connecting, listening or finishing. text is the final
// text so far, kept across Start/Stop until Discard. partial is Soniox's
// current guess at the words after it. error is the last problem, shown
// to you; the next Start clears it.
const INTERFACE = `
<node>
  <interface name="org.phoneputer.Dictation">
    <method name="Start"/>
    <method name="Stop"/>
    <method name="Discard"/>
    <method name="GetStatus">
      <arg type="s" name="state" direction="out"/>
      <arg type="s" name="text" direction="out"/>
      <arg type="s" name="partial" direction="out"/>
      <arg type="s" name="error" direction="out"/>
    </method>
    <signal name="Changed">
      <arg type="s" name="state"/>
      <arg type="s" name="text"/>
      <arg type="s" name="partial"/>
      <arg type="s" name="error"/>
    </signal>
  </interface>
</node>`;

const decoder = new TextDecoder();

// Words from a new recording start a new word, unless Soniox already put
// a space in front of them.
function join(text, more) {
    if (!text || !more || /\s$/.test(text) || /^\s/.test(more))
        return text + more;
    return `${text} ${more}`;
}

class Dictation {
    constructor() {
        this._state = 'idle';
        this._text = '';
        this._partial = '';
        this._error = '';
        this._session = new Soup.Session();
    }

    // D-Bus methods.

    Start() {
        if (this._state !== 'idle')
            return;
        this._error = '';

        const key = this._readKey();
        if (!key) {
            this._fail('No Soniox API key: put it in ~/.config/soniox/api-key');
            return;
        }

        this._recordingText = this._text; // what this recording adds to
        this._recordingFinal = '';
        this._pending = []; // audio recorded before the websocket is open
        this._open = false;
        this._audioDone = false;
        this._cancellable = new Gio.Cancellable();
        this._setState('connecting');

        // Record and connect at the same time, so the first words aren't
        // lost while the connection is set up.
        try {
            this._recorder = Gio.Subprocess.new([
                'pw-record', '--raw', '--format', 's16', '--rate', `${SAMPLE_RATE}`,
                '--channels', '1', '--media-category', 'Capture', '-',
            ], Gio.SubprocessFlags.STDOUT_PIPE);
        } catch (e) {
            this._fail(`Can't record: ${e.message}`);
            return;
        }
        this._readAudio(this._recorder.get_stdout_pipe(), this._cancellable);
        this._connect(key, this._cancellable);
    }

    Stop() {
        if (this._state !== 'connecting' && this._state !== 'listening')
            return;
        this._setState('finishing');
        // pw-record stops on SIGTERM; the audio still in its pipe is read
        // and sent, then _readAudio tells Soniox that's all.
        this._recorder?.send_signal(15);
        this._finishTimeout = GLib.timeout_add(GLib.PRIORITY_DEFAULT,
            FINISH_TIMEOUT_MS, () => {
                this._finishTimeout = 0;
                // Keep the words you saw, even if Soniox never confirmed them.
                this._endRecording(true);
                return GLib.SOURCE_REMOVE;
            });
    }

    Discard() {
        this._endRecording(false);
        this._text = '';
        this._partial = '';
        this._error = '';
        this._emit();
    }

    GetStatus() {
        return [this._state, this._text, this._partial, this._error];
    }

    // Recording and streaming.

    _readKey() {
        try {
            const [, bytes] = GLib.file_get_contents(KEY_FILE);
            return decoder.decode(bytes).trim();
        } catch {
            return '';
        }
    }

    _readAudio(stream, cancellable) {
        stream.read_bytes_async(CHUNK_BYTES, GLib.PRIORITY_DEFAULT, cancellable,
            (_stream, result) => {
                let bytes;
                try {
                    bytes = stream.read_bytes_finish(result);
                } catch {
                    return; // cancelled: the recording was ended
                }
                if (bytes.get_size() === 0) {
                    // pw-record has stopped: no more audio.
                    this._audioDone = true;
                    if (this._open)
                        this._conn.send_text('');
                    else if (this._state === 'listening' || this._state === 'connecting')
                        this._fail('The microphone stopped');
                    return;
                }
                const data = bytes.toArray();
                if (this._open)
                    this._conn.send_binary(data);
                else
                    this._pending.push(data);
                this._readAudio(stream, cancellable);
            });
    }

    _connect(key, cancellable) {
        const message = Soup.Message.new('GET', SONIOX_URL);
        this._session.websocket_connect_async(message, null, null,
            GLib.PRIORITY_DEFAULT, cancellable, (session, result) => {
                try {
                    this._conn = session.websocket_connect_finish(result);
                } catch (e) {
                    if (!cancellable.is_cancelled())
                        this._fail(`Can't reach Soniox: ${e.message}`);
                    return;
                }
                // Answers still arriving after the recording ended are
                // ignored (conn is no longer this._conn).
                this._conn.connect('message', (conn, type, bytes) => {
                    if (conn === this._conn && type === Soup.WebsocketDataType.TEXT)
                        this._onMessage(decoder.decode(bytes.toArray()));
                });
                this._conn.connect('closed', conn => {
                    if (conn === this._conn)
                        this._fail('Soniox closed the connection');
                });

                // The key rides in the first message; Soniox has no
                // login header.
                const config = {
                    api_key: key,
                    model: SONIOX_MODEL,
                    audio_format: 'pcm_s16le',
                    sample_rate: SAMPLE_RATE,
                    num_channels: 1,
                };
                if (LANGUAGE_HINTS.length > 0)
                    config.language_hints = LANGUAGE_HINTS;
                this._conn.send_text(JSON.stringify(config));

                this._open = true;
                for (const data of this._pending.splice(0))
                    this._conn.send_binary(data);
                if (this._audioDone)
                    this._conn.send_text('');
                if (this._state === 'connecting')
                    this._setState('listening');
            });
    }

    _onMessage(text) {
        let message;
        try {
            message = JSON.parse(text);
        } catch {
            return;
        }
        if (message.error_code != null) {
            this._fail(`Soniox: ${message.error_message ?? message.error_code}`);
            return;
        }

        let partial = '';
        for (const token of message.tokens ?? []) {
            // <end> and <fin> mark where Soniox finalised; they aren't words.
            if (token.text === '<end>' || token.text === '<fin>')
                continue;
            if (token.is_final)
                this._recordingFinal += token.text;
            else
                partial += token.text;
        }
        this._text = join(this._recordingText, this._recordingFinal);
        // Shown right after the text, so with a space between if needed.
        this._partial = this._text
            ? join(this._text, partial).slice(this._text.length)
            : partial.trimStart();

        if (message.finished)
            this._endRecording(false); // all words are final now
        else
            this._emit();
    }

    // Ends a recording and its connection. keepPartial keeps the words
    // Soniox hadn't confirmed yet (when Soniox went away mid-sentence).
    _endRecording(keepPartial) {
        if (this._finishTimeout) {
            GLib.source_remove(this._finishTimeout);
            this._finishTimeout = 0;
        }
        this._cancellable?.cancel();
        this._cancellable = null;
        this._recorder?.force_exit();
        this._recorder = null;
        const conn = this._conn;
        this._conn = null;
        this._open = false;
        if (conn && conn.get_state() === Soup.WebsocketState.OPEN)
            conn.close(Soup.WebsocketCloseCode.NORMAL, null);

        if (keepPartial)
            this._text += this._partial;
        this._partial = '';
        this._setState('idle');
    }

    _fail(error) {
        this._error = error;
        printerr(error);
        this._endRecording(true);
    }

    _setState(state) {
        this._state = state;
        this._emit();
    }

    _emit() {
        this._dbus?.emit_signal('Changed', new GLib.Variant('(ssss)',
            [this._state, this._text, this._partial, this._error]));
    }
}

const dictation = new Dictation();
dictation._dbus = Gio.DBusExportedObject.wrapJSObject(INTERFACE, dictation);
dictation._dbus.export(Gio.DBus.session, OBJECT_PATH);

const loop = new GLib.MainLoop(null, false);
Gio.bus_own_name_on_connection(Gio.DBus.session, BUS_NAME,
    Gio.BusNameOwnerFlags.NONE, null, () => loop.quit());
loop.run();
