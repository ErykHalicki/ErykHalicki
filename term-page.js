// Injected into ttyd's page by `term`: the parts of the iTerm2 profile ttyd's options can't express.
(() => {
  const ansi = ['#14191e', '#b43c2a', '#00c200', '#c7c400', '#2744c7', '#c040be', '#00c5c7', '#c7c7c7',
    '#686868', '#dd7975', '#58e790', '#ece100', '#a7abf2', '#e17ee1', '#60fdff', '#ffffff'];
  const names = ['black', 'red', 'green', 'yellow', 'blue', 'magenta', 'cyan', 'white'];
  const themes = {
    dark: { background: '#15191f', foreground: '#ff9824', cursor: '#ffffff', cursorAccent: '#000000',
      selectionBackground: '#adcced', selectionForeground: '#000000' },
    light: { background: '#fafafa', foreground: '#101010', cursor: '#000000', cursorAccent: '#ffffff',
      selectionBackground: '#b3d7ff', selectionForeground: '#000000' },
  };
  ansi.forEach((c, i) => {
    const n = i < 8 ? names[i] : 'bright' + names[i - 8][0].toUpperCase() + names[i - 8].slice(1);
    themes.dark[n] = themes.light[n] = c;
  });

  // iTerm2 profile key mappings; M = Cmd (Super on Linux), A = Option/Alt
  const keys = {
    'M:Backspace': '\x15', 'A:Backspace': '\x1b\x7f',
    'M:ArrowLeft': '\x01', 'M:ArrowRight': '\x05',
    'A:ArrowLeft': '\x1bb', 'A:ArrowRight': '\x1bf',
    ':Delete': '\x04', 'A:Delete': '\x1bd',
  };

  const dark = matchMedia('(prefers-color-scheme: dark)');

  function setup(term) {
    let theme;
    const apply = () => {
      theme = dark.matches ? themes.dark : themes.light;
      term.options.theme = theme;
      document.body.style.background = theme.background;
    };
    apply();
    dark.addEventListener('change', apply);

    // the icon font loads only once something asks for it, and glyphs drawn before then stay cached
    // as boxes, so load it up front and redraw
    document.fonts.load('12px TermSymbols', '\uf07b').then(() => {
      term.clearTextureAtlas();
      term.refresh(0, term.rows - 1);
    });

    term.attachCustomKeyEventHandler(ev => {
      const mods = (ev.metaKey ? 'M' : '') + (ev.altKey ? 'A' : '') + (ev.ctrlKey ? 'C' : '') + (ev.shiftKey ? 'S' : '');
      const seq = keys[mods + ':' + ev.key];
      if (!seq) return true;
      if (ev.type === 'keydown') {
        ev.preventDefault();
        term.input(seq);
      }
      return false;
    });

    const flash = document.createElement('div');
    flash.style.cssText = 'position:fixed;inset:0;pointer-events:none;opacity:0;transition:opacity .15s;z-index:10';
    document.body.appendChild(flash);
    // a bell while you're looking only flashes; a bell in a tab you've left, or an explicit
    // notification (OSC 9 or OSC 777;notify, e.g. `long_job; printf '\e]9;done\a'`), also chimes and
    // pops a desktop notification. Browsers allow sound and the permission prompt only after a user
    // gesture, so both are set up on the first key press or click
    let audio = null;
    const unlock = () => {
      if (!audio) audio = new AudioContext();
      audio.resume();
      if (window.Notification && Notification.permission === 'default') Notification.requestPermission();
    };
    window.addEventListener('keydown', unlock, true);
    window.addEventListener('mousedown', unlock, true);

    const chime = () => {
      if (!audio || audio.state !== 'running') return;
      const t = audio.currentTime;
      [880, 1318.5].forEach((f, i) => {
        const o = audio.createOscillator(), g = audio.createGain();
        o.frequency.value = f;
        g.gain.setValueAtTime(0, t + i * 0.12);
        g.gain.linearRampToValueAtTime(0.25, t + i * 0.12 + 0.01);
        g.gain.exponentialRampToValueAtTime(0.001, t + i * 0.12 + 0.4);
        o.connect(g).connect(audio.destination);
        o.start(t + i * 0.12);
        o.stop(t + i * 0.12 + 0.45);
      });
    };

    const away = () => document.hidden || !document.hasFocus();
    const notify = body => {
      chime();
      if (away() && window.Notification && Notification.permission === 'granted') {
        const n = new Notification(document.title, { body, silent: true });
        n.onclick = () => { window.focus(); n.close(); };
      }
    };

    term.onBell(() => {
      flash.style.background = theme.foreground;
      flash.style.opacity = '0.15';
      setTimeout(() => { flash.style.opacity = '0'; }, 100);
      if (away()) notify('bell');
    });
    term.parser.registerOscHandler(9, data => {
      // OSC 9;4 is ConEmu's progress bar, not a message
      if (!/^4;/.test(data)) notify(data || 'done');
      return true;
    });
    term.parser.registerOscHandler(777, data => {
      const [kind, title, ...body] = data.split(';');
      if (kind === 'notify') notify([title, body.join(';')].filter(Boolean).join(': ') || 'done');
      return true;
    });
  }

  const wait = setInterval(() => {
    if (window.term) {
      clearInterval(wait);
      setup(window.term);
    }
  }, 20);
})();
