import Foundation

enum GatewayDashboard {
  static let html = """
  <!DOCTYPE html>
  <html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>CodexBar Dashboard</title>
    <style>
      :root { color-scheme: dark; }
      * { box-sizing: border-box; }
      body {
        font-family: -apple-system, BlinkMacSystemFont, sans-serif;
        background: #0d0926;
        color: #f3f4f6;
        margin: 0;
        padding: 2rem 1.25rem 3rem;
      }
      .wrap { max-width: 920px; margin: 0 auto; }
      h1 { color: #06b6d4; margin: 0 0 0.25rem; font-size: 1.75rem; }
      .sub { color: #9ca3af; margin: 0 0 1.5rem; }
      .card {
        background: rgba(255,255,255,.04);
        border: 1px solid rgba(255,255,255,.08);
        border-radius: 16px;
        padding: 1.25rem 1.5rem;
        margin: 1rem 0;
      }
      h2 { margin: 0 0 1rem; font-size: 1.1rem; }
      label { display: block; font-size: 0.85rem; color: #cbd5e1; margin: 0.75rem 0 0.35rem; }
      input, select {
        width: 100%;
        padding: 0.55rem 0.7rem;
        border-radius: 10px;
        border: 1px solid rgba(255,255,255,.12);
        background: rgba(0,0,0,.25);
        color: #f9fafb;
        font: inherit;
      }
      input:focus, select:focus { outline: 2px solid rgba(6,182,212,.45); border-color: #06b6d4; }
      .row { display: grid; grid-template-columns: 1fr 1fr; gap: 0.75rem; }
      @media (max-width: 700px) { .row { grid-template-columns: 1fr; } }
      button, .btn {
        appearance: none;
        border: 0;
        border-radius: 10px;
        padding: 0.55rem 0.9rem;
        font: inherit;
        cursor: pointer;
      }
      .btn-primary { background: #06b6d4; color: #041018; font-weight: 600; }
      .btn-secondary { background: rgba(255,255,255,.08); color: #f3f4f6; }
      .btn-danger { background: rgba(239,68,68,.15); color: #fca5a5; }
      .actions { display: flex; gap: 0.5rem; flex-wrap: wrap; margin-top: 1rem; }
      table { width: 100%; border-collapse: collapse; font-size: 0.92rem; }
      th, td { text-align: left; padding: 0.55rem 0.35rem; border-bottom: 1px solid rgba(255,255,255,.06); vertical-align: top; }
      th { color: #9ca3af; font-weight: 600; font-size: 0.8rem; text-transform: uppercase; letter-spacing: 0.04em; }
      .muted { color: #9ca3af; font-size: 0.85rem; }
      .pill { display: inline-block; padding: 0.15rem 0.45rem; border-radius: 999px; background: rgba(6,182,212,.15); color: #67e8f9; font-size: 0.75rem; }
      #toast {
        position: fixed; right: 1rem; bottom: 1rem; max-width: 360px;
        background: #111827; border: 1px solid rgba(255,255,255,.1); border-radius: 12px;
        padding: 0.75rem 1rem; display: none; z-index: 10;
      }
      #toast.ok { border-color: rgba(34,197,94,.35); }
      #toast.err { border-color: rgba(239,68,68,.35); }
      pre { margin: 0; white-space: pre-wrap; word-break: break-word; font-size: 0.85rem; }
      .preset { margin-top: 0.5rem; }
      .preset button { margin: 0.25rem 0.35rem 0 0; padding: 0.35rem 0.55rem; font-size: 0.8rem; }
    </style>
  </head>
  <body>
    <div class="wrap">
      <h1>CodexBar Dashboard</h1>
      <p class="sub">Manage providers and models for the local gateway at <code>http://127.0.0.1:8765</code></p>

      <div class="card">
        <h2>Status</h2>
        <pre id="status">Loading…</pre>
        <div class="actions">
          <button class="btn-secondary" id="refreshBtn">Refresh</button>
          <button class="btn-secondary" id="restartBtn">Restart Codex</button>
        </div>
      </div>

      <div class="card">
        <h2>Providers</h2>
        <p class="muted">OpenAI-compatible API endpoints and API keys.</p>
        <div class="preset" id="presetButtons">
          <span class="muted">Install preset:</span>
        </div>
        <p class="muted" style="margin-top:0.75rem">Or add a custom provider manually:</p>
        <form id="providerForm">
          <div class="row">
            <div>
              <label for="providerName">Name (id)</label>
              <input id="providerName" name="name" placeholder="minimax" required>
            </div>
            <div>
              <label for="providerBaseUrl">Base URL</label>
              <input id="providerBaseUrl" name="base_url" placeholder="https://api.minimax.io/v1" required>
            </div>
          </div>
          <label for="providerApiKey">API key <span class="muted">(leave blank to keep existing)</span></label>
          <input id="providerApiKey" name="api_key" type="password" placeholder="sk-…" autocomplete="off">
          <div class="actions">
            <button class="btn-primary" type="submit">Save provider</button>
            <button class="btn-secondary" type="button" id="clearProviderForm">Clear</button>
          </div>
        </form>
        <table id="providersTable" style="margin-top:1rem">
          <thead><tr><th>Name</th><th>Base URL</th><th>Key</th><th></th></tr></thead>
          <tbody></tbody>
        </table>
      </div>

      <div class="card">
        <h2>Models</h2>
        <p class="muted">Catalog entries shown in Codex when <span class="pill">visibility=list</span>.</p>
        <form id="modelForm">
          <div class="row">
            <div>
              <label for="modelSlug">Slug (Codex id)</label>
              <input id="modelSlug" name="slug" placeholder="minimax/minimax-m2.5" required>
            </div>
            <div>
              <label for="modelProvider">Provider</label>
              <select id="modelProvider" name="provider" required></select>
            </div>
          </div>
          <div class="row">
            <div>
              <label for="modelUpstream">Upstream model name</label>
              <input id="modelUpstream" name="model" placeholder="MiniMax-M2.5">
            </div>
            <div>
              <label for="modelDisplayName">Display name</label>
              <input id="modelDisplayName" name="display_name" placeholder="MiniMax M2.5">
            </div>
          </div>
          <div class="actions">
            <button class="btn-primary" type="submit">Save model</button>
            <button class="btn-secondary" type="button" id="clearModelForm">Clear</button>
          </div>
        </form>
        <table id="modelsTable" style="margin-top:1rem">
          <thead><tr><th>Slug</th><th>Model</th><th>Provider</th><th>Display</th><th></th></tr></thead>
          <tbody></tbody>
        </table>
      </div>
    </div>

    <div id="toast"></div>

    <script>
      let presetCatalog = [];

      function toast(msg, ok = true) {
        const el = document.getElementById('toast');
        el.textContent = msg;
        el.className = ok ? 'ok' : 'err';
        el.style.display = 'block';
        clearTimeout(el._t);
        el._t = setTimeout(() => { el.style.display = 'none'; }, 3500);
      }

      async function api(path, opts = {}) {
        const res = await fetch(path, {
          headers: { 'Content-Type': 'application/json', ...(opts.headers || {}) },
          ...opts
        });
        const data = await res.json().catch(() => ({}));
        if (!res.ok) throw new Error(data.error || res.statusText);
        return data;
      }

      function renderProviders(providers, models) {
        const tbody = document.querySelector('#providersTable tbody');
        const select = document.getElementById('modelProvider');
        const usable = providers.filter(p => p.name);
        tbody.innerHTML = usable.map(p => {
          const inUse = models.filter(m => (m.provider || m.backend_provider || '') === p.name).length;
          const deleteDisabled = inUse > 0;
          const deleteTitle = deleteDisabled
            ? `Remove its ${inUse} model${inUse === 1 ? '' : 's'} first`
            : 'Delete provider';
          return `
          <tr>
            <td><code>${esc(p.name)}</code></td>
            <td class="muted">${esc(p.base_url)}</td>
            <td>${p.api_key_set ? '<span class="pill">set</span>' : '<span class="muted">none</span>'}</td>
            <td>
              <button class="btn-secondary" data-edit-provider='${esc(JSON.stringify(p))}'>Edit</button>
              <button class="btn-danger" data-del-provider="${esc(p.name)}" ${deleteDisabled ? 'disabled' : ''} title="${esc(deleteTitle)}">Delete</button>
            </td>
          </tr>`;
        }).join('') || '<tr><td colspan="4" class="muted">No providers yet.</td></tr>';

        select.innerHTML = usable.map(p => `<option value="${esc(p.name)}">${esc(p.name)}</option>`).join('')
          || '<option value="">Add a provider first</option>';
      }

      function renderModels(models) {
        const tbody = document.querySelector('#modelsTable tbody');
        tbody.innerHTML = models.map(m => `
          <tr>
            <td><code>${esc(m.slug)}</code></td>
            <td>${esc(m.model || m.slug)}</td>
            <td>${esc(m.provider || m.backend_provider || '')}</td>
            <td>${esc(m.display_name || m.slug)}</td>
            <td>
              <button class="btn-secondary" data-edit-model='${esc(JSON.stringify(m))}'>Edit</button>
              <button class="btn-danger" data-del-model="${esc(m.slug)}">Delete</button>
            </td>
          </tr>`).join('') || '<tr><td colspan="5" class="muted">No models yet.</td></tr>';
      }

      function esc(s) {
        return String(s)
          .replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;')
          .replace(/"/g,'&quot;').replace(/'/g,'&#39;');
      }

      function renderPresetButtons(presets) {
        presetCatalog = presets;
        const host = document.getElementById('presetButtons');
        const buttons = presets.map(p => `
          <button type="button" class="btn-secondary" data-install-preset="${esc(p.id)}"
            title="${esc(p.base_url)} · ${p.model_count} available model(s)">
            ${esc(p.display_name)}
          </button>`).join('');
        host.innerHTML = '<span class="muted">Install preset:</span> ' + buttons;
      }

      async function installPreset(presetId) {
        const preset = presetCatalog.find(p => p.id === presetId);
        if (!preset) return;
        let apiKey = '';
        if (preset.requires_api_key) {
          apiKey = window.prompt(`API key for ${preset.display_name}:`, '');
          if (apiKey === null) return;
          if (!apiKey.trim()) { toast('API key required', false); return; }
        }
        try {
          const result = await api('/api/presets/install', {
            method: 'POST',
            body: JSON.stringify({ preset: presetId, api_key: apiKey })
          });
          toast(`Installed ${preset.display_name} provider — add models separately`);
          await loadDashboard();
        } catch (err) { toast(err.message, false); }
      }

      async function loadDashboard() {
        const [health, dashboard, presetsResp] = await Promise.all([
          api('/health'),
          api('/api/dashboard'),
          api('/api/presets')
        ]);
        document.getElementById('status').textContent = JSON.stringify(health, null, 2);
        renderPresetButtons(presetsResp.presets || []);
        renderProviders(dashboard.providers || [], dashboard.models || []);
        renderModels(dashboard.models || []);
      }

      document.getElementById('providerForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        const fd = new FormData(e.target);
        const body = Object.fromEntries(fd.entries());
        try {
          await api('/api/providers', { method: 'POST', body: JSON.stringify(body) });
          toast('Provider saved');
          e.target.reset();
          await loadDashboard();
        } catch (err) { toast(err.message, false); }
      });

      document.getElementById('modelForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        const fd = new FormData(e.target);
        const body = Object.fromEntries(fd.entries());
        if (!body.model) body.model = body.slug;
        if (!body.display_name) body.display_name = body.slug;
        body.visibility = 'list';
        try {
          await api('/api/catalog', { method: 'POST', body: JSON.stringify(body) });
          toast('Model saved — restart Codex to refresh picker');
          e.target.reset();
          await loadDashboard();
        } catch (err) { toast(err.message, false); }
      });

      document.getElementById('clearProviderForm').onclick = () => providerForm.reset();
      document.getElementById('clearModelForm').onclick = () => modelForm.reset();
      document.getElementById('refreshBtn').onclick = () => loadDashboard().catch(e => toast(e.message, false));
      document.getElementById('restartBtn').onclick = async () => {
        try {
          await api('/api/restart-codex', { method: 'POST', body: '{}' });
          toast('Codex restart requested');
        } catch (err) { toast(err.message, false); }
      };

      document.body.addEventListener('click', async (e) => {
        const installBtn = e.target.closest('[data-install-preset]');
        if (installBtn) {
          await installPreset(installBtn.dataset.installPreset);
          return;
        }
        const editProvider = e.target.closest('[data-edit-provider]');
        if (editProvider) {
          const p = JSON.parse(editProvider.dataset.editProvider);
          providerName.value = p.name;
          providerBaseUrl.value = p.base_url;
          providerApiKey.value = '';
          providerApiKey.placeholder = p.api_key_set ? 'Leave blank to keep existing key' : 'sk-…';
          return;
        }
        const delProvider = e.target.closest('[data-del-provider]');
        if (delProvider) {
          if (delProvider.disabled) return;
          const name = delProvider.dataset.delProvider;
          if (!confirm(`Delete provider "${name}"?`)) return;
          try {
            await api('/api/providers?name=' + encodeURIComponent(name), { method: 'DELETE' });
            toast('Provider deleted');
            await loadDashboard();
          } catch (err) { toast(err.message, false); }
          return;
        }
        const editModel = e.target.closest('[data-edit-model]');
        if (editModel) {
          const m = JSON.parse(editModel.dataset.editModel);
          modelSlug.value = m.slug;
          modelProvider.value = m.provider || m.backend_provider || '';
          modelUpstream.value = m.model || m.slug;
          modelDisplayName.value = m.display_name || m.slug;
          return;
        }
        const delModel = e.target.closest('[data-del-model]');
        if (delModel) {
          const slug = delModel.dataset.delModel;
          if (!confirm(`Delete model "${slug}"?`)) return;
          try {
            await api('/api/catalog?slug=' + encodeURIComponent(slug), { method: 'DELETE' });
            toast('Model deleted');
            await loadDashboard();
          } catch (err) { toast(err.message, false); }
        }
      });

      loadDashboard().catch(err => {
        document.getElementById('status').textContent = 'Failed to load: ' + err.message;
        toast(err.message, false);
      });
    </script>
  </body>
  </html>
  """
}
