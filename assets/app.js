// assets/app.js — the behaviour.
//
// Five things are interactive and each one is a real control: the composer
// posts a run, the gate approves or refuses it, the page editor saves with a
// revision check, the library filters and switches view, and the computer
// panel plays the run back as it happened.

(() => {
  const $ = (sel, root = document) => root.querySelector(sel);
  const $$ = (sel, root = document) => Array.from(root.querySelectorAll(sel));

  const post = async (url, body) => {
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(body || {})
    });
    return { ok: res.ok, status: res.status, data: await res.json().catch(() => ({})) };
  };

  /* --------------------------------------------------------------- composer */

  const composer = $('[data-composer]');
  if (composer) {
    const input = $('textarea', composer);
    const button = $('button[type="submit"]', composer);
    const grow = () => {
      input.style.height = 'auto';
      input.style.height = Math.min(input.scrollHeight, 180) + 'px';
    };
    input.addEventListener('input', grow);
    input.addEventListener('keydown', (event) => {
      if (event.key === 'Enter' && !event.shiftKey) {
        event.preventDefault();
        composer.requestSubmit();
      }
    });
    composer.addEventListener('submit', async (event) => {
      event.preventDefault();
      const text = input.value.trim();
      if (!text) {
        input.focus();
        return;
      }
      button.disabled = true;
      const label = button.innerHTML;
      button.innerHTML = 'Working…';
      try {
        const { ok, data } = await post('/api/messages', {
          dot: composer.dataset.dot,
          thread: composer.dataset.thread,
          text
        });
        if (!ok) throw new Error(data.error || 'The run did not start.');
        location.href = `/buns/${composer.dataset.dot}?run=${encodeURIComponent(data.run)}&from=0`;
      } catch (error) {
        button.disabled = false;
        button.innerHTML = label;
        let note = $('[data-composer-note]', composer);
        if (!note) {
          note = document.createElement('p');
          note.dataset.composerNote = '';
          note.className = 'composer-hint';
          note.style.color = 'var(--accent)';
          composer.appendChild(note);
        }
        note.textContent = error.message + ' Try again.';
        input.focus();
      }
    });
    if (input.value) grow();
  }

  /* ------------------------------------------------------------------ gates */

  $$('[data-approve], [data-refuse]').forEach((button) => {
    button.addEventListener('click', async () => {
      const approve = button.hasAttribute('data-approve');
      const runId = approve ? button.dataset.approve : button.dataset.refuse;
      const card = button.closest('[data-run]');
      const steps = card ? $$('.step', card) : [];
      const index = steps.findIndex((step) => step.classList.contains('is-waiting'));
      const dot = $('.view-dot');
      button.disabled = true;
      const label = button.textContent;
      button.textContent = approve ? 'Approving…' : 'Refusing…';
      try {
        const { ok, data } = await post(`/api/runs/${runId}/decide`, { approve });
        if (!ok) throw new Error(data.error || 'That decision was not accepted.');
        if (dot) {
          location.href = `/buns/${dot.dataset.dot}?run=${encodeURIComponent(runId)}&from=${index < 0 ? 0 : index}`;
        } else {
          location.reload();
        }
      } catch (error) {
        button.disabled = false;
        button.textContent = label;
        const gate = card && $('.gate', card);
        if (gate) {
          const p = document.createElement('p');
          p.className = 'gate-detail';
          p.style.color = 'var(--accent)';
          p.textContent = error.message;
          gate.appendChild(p);
        }
      }
    });
  });

  /* --------------------------------------------------------------- playback */

  const rig = $('[data-rig]');
  const rigBody = $('[data-screen-body]');
  const rigUrl = $('[data-url]');
  const rigTool = $('[data-tool]');
  const rigCaption = $('[data-caption]');

  const showScreen = (scr) => {
    if (!scr || !rigBody) return;
    rigBody.innerHTML = scr.innerHTML;
    if (rigUrl) rigUrl.textContent = scr.dataset.url || '';
    if (rigTool) rigTool.textContent = scr.dataset.tool || '';
  };

  const runs = $$('.run[data-play="1"]');
  runs.forEach((run) => {
    const steps = $$('.step', run);
    const screens = $$('.scr', run);
    const log = rig ? $$('.rl-item', rig) : [];
    const start = Number(run.dataset.from || 0);
    let i = Math.max(0, Math.min(start, steps.length - 1));

    const reveal = () => {
      if (i >= steps.length) {
        run.classList.add('is-finished');
        return;
      }
      const step = steps[i];
      step.classList.add('is-playing');
      if (screens[i]) showScreen(screens[i]);
      if (log[i]) {
        log[i].className = 'rl-item rl-' + (step.classList.contains('is-waiting') ? 'waiting' : 'done');
      }
      if (rigCaption) {
        const label = $('.step-label', step);
        if (label) rigCaption.textContent = label.textContent;
      }
      const thread = $('.thread');
      if (thread) thread.scrollTop = thread.scrollHeight;
      const ms = Math.min(Number(step.dataset.ms || 900), 1300);
      i += 1;
      setTimeout(reveal, ms);
    };
    setTimeout(reveal, 380);
  });

  if (runs.length) {
    const thread = $('.thread');
    if (thread) thread.scrollTop = thread.scrollHeight;
  }

  /* ------------------------------------------------------------ rig toggle */

  const rigToggle = $('[data-rig-toggle]');
  if (rigToggle && rig) {
    rigToggle.addEventListener('click', () => {
      const open = rig.classList.toggle('is-open');
      rigToggle.setAttribute('aria-expanded', open ? 'true' : 'false');
    });
    document.addEventListener('keydown', (event) => {
      if (event.key === 'Escape' && rig.classList.contains('is-open')) {
        rig.classList.remove('is-open');
        rigToggle.setAttribute('aria-expanded', 'false');
        rigToggle.focus();
      }
    });
  }

  /* ------------------------------------------------------------ the library */

  const spacesView = $('.view-spaces');
  if (spacesView) {
    const filter = $('[data-filter]');
    const rows = $$('.pl-row');
    const empty = $('[data-filter-empty]');
    if (filter) {
      filter.addEventListener('input', () => {
        const q = filter.value.trim().toLowerCase();
        let shown = 0;
        rows.forEach((row) => {
          const hay = (row.dataset.title || '') + ' ' + (row.dataset.space || '');
          const hit = !q || hay.includes(q);
          row.hidden = !hit;
          if (hit) shown += 1;
        });
        if (empty) empty.hidden = shown !== 0;
      });
    }
    $$('[data-view]').forEach((button) => {
      button.addEventListener('click', () => {
        spacesView.dataset.view = button.dataset.view;
        $$('[data-view]').forEach((other) => {
          const on = other === button;
          other.classList.toggle('is-on', on);
          other.setAttribute('aria-pressed', on ? 'true' : 'false');
        });
      });
    });
  }

  /* -------------------------------------------------------------- new page */

  const newPage = $('[data-new-page]');
  if (newPage) {
    newPage.addEventListener('click', async () => {
      newPage.disabled = true;
      try {
        const { ok, data } = await post('/api/pages', { space: newPage.dataset.newPage });
        if (!ok) throw new Error(data.error || 'Could not create the page.');
        location.href = `/spaces/${data.space}/p/${data.id}`;
      } catch (error) {
        newPage.disabled = false;
        newPage.textContent = error.message;
      }
    });
  }

  /* ------------------------------------------------------------- page edit */

  const pageView = $('.view-page');
  if (pageView) {
    const edit = $('[data-edit]');
    const body = $('[data-doc-body]');
    const editor = $('[data-doc-edit]');
    const input = $('[data-doc-input]');
    const state = $('[data-save-state]');
    const cancel = $('[data-edit-cancel]');
    let rev = Number(pageView.dataset.rev);
    let timer = null;
    let inFlight = false;
    let dirty = false;

    const setState = (text) => { if (state) state.textContent = text; };

    const save = async () => {
      if (inFlight) {
        dirty = true;
        return;
      }
      inFlight = true;
      setState('Saving…');
      try {
        const res = await fetch(`/api/pages/${pageView.dataset.page}`, {
          method: 'PATCH',
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify({ body: input.value, rev })
        });
        const data = await res.json().catch(() => ({}));
        if (res.status === 409) {
          setState('Someone edited this first — reload to see r' + data.rev);
          if (state) state.style.color = 'var(--accent)';
          inFlight = false;
          return;
        }
        if (!res.ok) throw new Error(data.error || 'Save failed');
        rev = data.rev;
        pageView.dataset.rev = String(rev);
        setState('Saved · r' + rev);
        if (state) state.style.color = '';
      } catch (error) {
        setState('Not saved — ' + error.message);
        if (state) state.style.color = 'var(--accent)';
      } finally {
        inFlight = false;
        if (dirty) {
          dirty = false;
          save();
        }
      }
    };

    const schedule = () => {
      clearTimeout(timer);
      setState('Unsaved changes');
      if (state) state.style.color = '';
      timer = setTimeout(save, 900);
    };

    if (edit && editor && body && input) {
      edit.addEventListener('click', () => {
        const opening = editor.hidden;
        editor.hidden = !opening;
        body.hidden = opening;
        edit.textContent = opening ? 'Close editor' : 'Edit';
        if (opening) {
          input.focus();
          input.setSelectionRange(input.value.length, input.value.length);
        } else {
          clearTimeout(timer);
          save().then(() => location.reload());
        }
      });
      input.addEventListener('input', schedule);
      if (cancel) {
        cancel.addEventListener('click', () => {
          clearTimeout(timer);
          location.reload();
        });
      }
    }
  }

  /* ----------------------------------------------------------- command bar */

  const palette = document.createElement('div');
  palette.className = 'cmdk';
  palette.hidden = true;
  palette.innerHTML = '<div class="cmdk-card" role="dialog" aria-label="Command bar">'
    + '<input type="search" placeholder="Type a place…" aria-label="Command">'
    + '<ul class="cmdk-list"></ul></div>';
  document.body.appendChild(palette);
  const cmdInput = $('input', palette);
  const cmdList = $('.cmdk-list', palette);
  const seen = {};
  const cmds = $$('.rail a')
    .map((a) => ({ label: a.textContent.trim().replace(/\s+/g, ' '), href: a.getAttribute('href') }))
    .filter((c) => (seen[c.href] ? false : (seen[c.href] = true)));
  const renderCmds = () => {
    const q = cmdInput.value.trim().toLowerCase();
    const hits = cmds.filter((c) => !q || c.label.toLowerCase().includes(q)).slice(0, 9);
    cmdList.innerHTML = hits.map((c, i) =>
      `<li${i === 0 ? ' class="is-sel"' : ''}><a href="${c.href}">${c.label}</a></li>`).join('')
      || '<li class="cmdk-none">Nothing matches.</li>';
  };
  const openPalette = () => { palette.hidden = false; cmdInput.value = ''; renderCmds(); cmdInput.focus(); };
  const closePalette = () => { palette.hidden = true; };
  document.addEventListener('keydown', (event) => {
    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'k') {
      event.preventDefault();
      if (palette.hidden) openPalette(); else closePalette();
    } else if (event.key === 'Escape' && !palette.hidden) {
      closePalette();
    }
  });
  palette.addEventListener('click', (event) => { if (event.target === palette) closePalette(); });
  cmdInput.addEventListener('input', renderCmds);
  cmdInput.addEventListener('keydown', (event) => {
    const rows = $$('li', cmdList).filter((r) => $('a', r));
    let idx = rows.findIndex((r) => r.classList.contains('is-sel'));
    if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
      event.preventDefault();
      if (idx >= 0) rows[idx].classList.remove('is-sel');
      idx = event.key === 'ArrowDown' ? Math.min(idx + 1, rows.length - 1) : Math.max(idx - 1, 0);
      if (rows[idx]) rows[idx].classList.add('is-sel');
    } else if (event.key === 'Enter') {
      event.preventDefault();
      const row = rows[Math.max(idx, 0)];
      const link = row && $('a', row);
      if (link) location.href = link.getAttribute('href');
    }
  });

  /* -------------------------------------------------------------- memories */

  const put = async (url, body, method = 'PUT') => {
    const res = await fetch(url, {
      method,
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(body || {})
    });
    return { ok: res.ok, status: res.status, data: await res.json().catch(() => ({})) };
  };

  const memForm = $('[data-mem-form]');
  if (memForm) {
    memForm.addEventListener('submit', async (event) => {
      event.preventDefault();
      const dot = $('select', memForm).value;
      const text = $('input[type="text"]', memForm).value.trim();
      if (!text) return;
      const { ok } = await post('/api/memories', { dot, text });
      if (ok) location.reload();
    });
    $$('[data-mem-del]').forEach((button) => {
      button.addEventListener('click', async () => {
        button.disabled = true;
        const res = await fetch('/api/memories/' + button.dataset.memDel, { method: 'DELETE' });
        if (res.ok) location.reload(); else button.disabled = false;
      });
    });
    $$('[data-mem-edit]').forEach((button) => {
      button.addEventListener('click', () => {
        const row = button.closest('[data-mem]');
        const span = $('.mem-text', row);
        const open = $('textarea', row);
        if (open) {
          put('/api/memories/' + row.dataset.mem, { text: open.value }).then(({ ok }) => {
            if (ok) location.reload(); else open.focus();
          });
          return;
        }
        const ta = document.createElement('textarea');
        ta.className = 'mem-input';
        ta.value = span.textContent;
        span.hidden = true;
        row.insertBefore(ta, span);
        ta.focus();
        button.textContent = 'Save';
      });
    });
  }

  /* -------------------------------------------------------------- settings */

  const settingsForm = $('[data-settings-form]');
  if (settingsForm) {
    const stateEl = $('[data-settings-state]');
    settingsForm.addEventListener('submit', async (event) => {
      event.preventDefault();
      const data = {
        name: $('input[name="name"]', settingsForm).value,
        tz_label: $('input[name="tz_label"]', settingsForm).value,
        notify_gates: $('input[name="notify_gates"]').checked,
        notify_digest: $('input[name="notify_digest"]').checked
      };
      const { ok } = await put('/api/settings', data, 'PATCH');
      if (stateEl) {
        stateEl.textContent = ok ? 'Saved' : 'Not saved';
        stateEl.style.color = ok ? '' : 'var(--accent)';
        setTimeout(() => { stateEl.textContent = 'Saved'; stateEl.style.color = ''; }, 2400);
      }
    });
  }

  /* -------------------------------------------------------------- schedule */

  const schedForm = $('[data-sched-form]');
  if (schedForm) {
    schedForm.addEventListener('submit', async (event) => {
      event.preventDefault();
      const dot = $('select[name="dot"]', schedForm).value;
      const goal = $('input[name="goal"]', schedForm).value.trim();
      const cadence = $('select[name="cadence"]', schedForm).value;
      if (!goal) return;
      const { ok } = await post('/api/tasks', { dot, goal, schedule: { cadence } });
      if (ok) location.reload();
    });
    $$('[data-sch-del]').forEach((button) => {
      button.addEventListener('click', async () => {
        button.disabled = true;
        const res = await fetch('/api/schedules/' + button.dataset.schDel, { method: 'DELETE' });
        if (res.ok) location.reload(); else button.disabled = false;
      });
    });
  }
})();
