(() => {
  const key = 'elaina-glass-settings-v1';
  const defaults = { dim: 38, glass: 52, blur: 3, compact: false, accent: '#c4a5f5' };
  let settings = { ...defaults };
  try { settings = { ...defaults, ...JSON.parse(localStorage.getItem(key) || '{}') }; } catch {}
  const clamp = (value, min, max, fallback) => Number.isFinite(Number(value)) ? Math.min(max, Math.max(min, Number(value))) : fallback;
  function apply() {
    settings.dim = clamp(settings.dim, 20, 75, defaults.dim);
    settings.glass = clamp(settings.glass, 32, 80, defaults.glass);
    settings.blur = clamp(settings.blur, 0, 14, defaults.blur);
    if (!/^#[0-9a-f]{6}$/i.test(settings.accent)) settings.accent = defaults.accent;
    document.documentElement.style.setProperty('--elaina-dim', settings.dim / 100);
    document.documentElement.style.setProperty('--elaina-glass', settings.glass / 100);
    document.documentElement.style.setProperty('--elaina-blur', `${settings.blur}px`);
    document.documentElement.style.setProperty('--elaina-accent', settings.accent);
    document.documentElement.classList.toggle('elaina-compact', !!settings.compact);
    try { localStorage.setItem(key, JSON.stringify(settings)); } catch {}
  }
  apply();
  function openSettings() {
    const panel = document.createElement('div');
    panel.className = 'elaina-settings';
    panel.innerHTML = `
      <p class="elaina-intro">Foto favoritmu, dengan suasana yang pas untuk musikmu.<br>Perubahan langsung tersimpan di perangkat ini.</p>
      <div class="elaina-presets" aria-label="Preset suasana">
        <button data-preset="portrait">Portrait</button>
        <button data-preset="balanced">Balanced</button>
        <button data-preset="focus">Focus</button>
      </div>
      <label>Gelapkan foto <output id="elaina-dim-value"></output><input id="elaina-dim" type="range" min="20" max="75"></label>
      <label>Kepekatan panel <output id="elaina-glass-value"></output><input id="elaina-glass" type="range" min="32" max="80"></label>
      <label>Blur panel <output id="elaina-blur-value"></output><input id="elaina-blur" type="range" min="0" max="14"></label>
      <div class="elaina-presets" aria-label="Warna aksen">
        <button data-accent="#c4a5f5">Lavender</button><button data-accent="#a9caff">Moonlight</button><button data-accent="#efb4d0">Rose</button>
      </div>
      <label style="display:flex;align-items:center"><input id="elaina-compact" type="checkbox"> Daftar lagu lebih rapat</label>
      <button id="elaina-reset">Reset tampilan</button>
      <p class="elaina-footer">Elaina Glass · Foto tersimpan lokal · Tidak perlu restart</p>`;
    function sync() {
      for (const name of ['dim', 'glass', 'blur']) {
        panel.querySelector(`#elaina-${name}`).value = settings[name];
        panel.querySelector(`#elaina-${name}-value`).textContent = `${settings[name]}${name === 'blur' ? ' px' : '%'}`;
      }
      panel.querySelector('#elaina-compact').checked = !!settings.compact;
      panel.querySelectorAll('[data-accent]').forEach(el => el.setAttribute('aria-pressed', String(el.dataset.accent === settings.accent)));
    }
    panel.addEventListener('input', event => {
      const name = event.target.id.replace('elaina-', '');
      if (['dim', 'glass', 'blur'].includes(name)) settings[name] = Number(event.target.value);
      if (name === 'compact') settings.compact = event.target.checked;
      apply(); sync();
    });
    panel.addEventListener('click', event => {
      const button = event.target.closest('button');
      if (!button) return;
      const presets = {
        portrait: { dim: 28, glass: 36, blur: 0 },
        balanced: { dim: 38, glass: 52, blur: 3 },
        focus: { dim: 58, glass: 72, blur: 8 }
      };
      if (button.dataset.preset) settings = { ...settings, ...presets[button.dataset.preset] };
      if (button.dataset.accent) settings.accent = button.dataset.accent;
      if (button.id === 'elaina-reset') settings = { ...defaults };
      apply(); sync();
    });
    sync();
    Spicetify.PopupModal.display({ title: 'Elaina Glass', content: panel });
  }
  function mount(attempt = 0) {
    if (!window.Spicetify?.Topbar?.Button || !window.Spicetify?.PopupModal) {
      if (attempt < 60) setTimeout(() => mount(attempt + 1), 500);
      return;
    }
    if (document.getElementById('elaina-studio-button')) return;
    const icon = '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="1.5"><path d="m12 2 2.5 7.5L22 12l-7.5 2.5L12 22l-2.5-7.5L2 12l7.5-2.5Z"/><path d="m19 2 .7 2.3L22 5l-2.3.7L19 8l-.7-2.3L16 5l2.3-.7Z"/></svg>';
    const button = new Spicetify.Topbar.Button('Elaina Glass', icon, openSettings);
    button.element.id = 'elaina-studio-button';
    button.element.setAttribute('aria-label', 'Pengaturan Elaina Glass');
  }
  mount();
})();
