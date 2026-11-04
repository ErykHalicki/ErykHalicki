// Runs before ttyd's script, which reads the URL once to build its websocket address: puts this tab's
// id first among the ttyd args, so every reconnect from this tab reattaches to the same termbridge
// session. sessionStorage survives reloads but not new tabs; an id copied in a bookmarked URL is
// replaced so two tabs never share a shell by accident.
(() => {
  let id = null;
  try { id = sessionStorage.getItem('termTab'); } catch (e) {}
  if (!id) {
    id = Array.from(crypto.getRandomValues(new Uint8Array(8)), b => b.toString(16).padStart(2, '0')).join('');
    try { sessionStorage.setItem('termTab', id); } catch (e) {}
  }
  const old = new URLSearchParams(location.search);
  const q = new URLSearchParams();
  q.append('arg', '--tab=' + id);
  for (const [k, v] of old) {
    if (!(k === 'arg' && v.startsWith('--tab='))) q.append(k, v);
  }
  history.replaceState(null, '', location.pathname + '?' + q + location.hash);
})();
