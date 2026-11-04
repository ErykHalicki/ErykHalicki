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
    term.onBell(() => {
      flash.style.background = theme.foreground;
      flash.style.opacity = '0.15';
      setTimeout(() => { flash.style.opacity = '0'; }, 100);
    });
  }

  const wait = setInterval(() => {
    if (window.term) {
      clearInterval(wait);
      setup(window.term);
    }
  }, 20);
})();
