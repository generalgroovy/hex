'use client';
import { useEffect, useRef, useState } from 'react';
import { BACKUP_LIMITS, applyBrowserBackup, captureBrowserBackup, parseBrowserBackup, previewBrowserImport, serializeBrowserBackup, summarizeBrowserBackup, type BrowserBackup, type BackupStores } from '../../lib/browser-backup';
import './browser-saves.css';
const browserStores = (): BackupStores => ({ local: window.localStorage, session: window.sessionStorage });
type Summary = ReturnType<typeof summarizeBrowserBackup>;
type Preview = ReturnType<typeof previewBrowserImport>;
export default function BrowserSaves() {
  const [current, setCurrent] = useState<Summary | null>(null);
  const [backup, setBackup] = useState<BrowserBackup | null>(null);
  const [preview, setPreview] = useState<Preview | null>(null);
  const [replace, setReplace] = useState(false);
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const selection = useRef(0);
  function refresh() { setCurrent(summarizeBrowserBackup(captureBrowserBackup(browserStores()))); }
  useEffect(() => { try { refresh(); } catch { setError('Browser storage is unavailable. Enable storage to transfer saves.'); } }, []);
  function download() {
    setError(''); setMessage('');
    try {
      const data = captureBrowserBackup(browserStores());
      const url = URL.createObjectURL(new Blob([serializeBrowserBackup(data)], { type: 'application/json' }));
      const link = document.createElement('a');
      link.href = url; link.download = `hex-browser-save-${data.createdAt.slice(0, 10)}.json`;
      document.body.appendChild(link); link.click(); link.remove();
      window.setTimeout(() => URL.revokeObjectURL(url), 30_000);
      setCurrent(summarizeBrowserBackup(data));
      setMessage('Backup download started. Your saves are unchanged.');
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Backup could not be created.'); }
  }
  async function chooseFile(file: File | undefined) {
    const request = ++selection.current;
    setBackup(null); setPreview(null); setReplace(false); setError(''); setMessage('');
    if (!file) { setLoading(false); return; }
    setLoading(true);
    try {
      if (file.size > BACKUP_LIMITS.bytes) throw new Error('This file is too large. The limit is 32 MB.');
      const data = parseBrowserBackup(await file.text());
      if (selection.current !== request) return;
      const next = previewBrowserImport(data, browserStores());
      setBackup(data); setPreview(next);
    } catch (cause) { if (selection.current === request) setError(cause instanceof Error ? cause.message : 'The backup could not be read.'); }
    finally { if (selection.current === request) setLoading(false); }
  }
  function importSaves() {
    if (!backup) return;
    setError(''); setMessage('');
    try {
      const result = applyBrowserBackup(backup, browserStores(), replace ? 'replace' : 'missing');
      setMessage(`${result.added} added · ${result.replaced} replaced · ${result.unchanged + (replace ? 0 : result.conflicts)} kept. Open a game below to continue.`);
      setBackup(null); setPreview(null); setReplace(false); refresh();
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Import failed. Keep your backup.'); }
  }
  const incoming = backup ? summarizeBrowserBackup(backup) : null;
  return <main className="hex-saves">
    <a className="hex-saves-back" href="/">← H.E.X.</a>
    <h1>Saves</h1>
    <p>Move your progress, teams, settings and private match access to another browser or game address.</p>
    <p className="hex-saves-private"><strong>This file includes private match access. Keep it private.</strong></p>
    <section aria-labelledby="backup-heading">
      <h2 id="backup-heading">Back up this browser</h2>
      {current && <p>{current.savedItems} saved items · {current.local} persistent records · {current.session} tab records</p>}
      <button type="button" onClick={download}>Download backup</button>
      <p className="hex-saves-note">Includes older saves. Downloading leaves everything in place.</p>
    </section>
    <section aria-labelledby="restore-heading">
      <h2 id="restore-heading">Restore a backup</h2>
      <p>Close other game tabs first. Keep this tab open after importing to retain any tab-only saves.</p>
      <label className="hex-saves-file">Backup file<input type="file" accept=".json,application/json" onChange={event => void chooseFile(event.currentTarget.files?.[0])} /></label>
      {loading && <p role="status">Reading backup…</p>}
      {incoming && preview && <div className="hex-saves-preview">
        <dl><div><dt>Saved items</dt><dd>{incoming.savedItems}</dd></div><div><dt>New</dt><dd>{preview.added}</dd></div><div><dt>Already here</dt><dd>{preview.unchanged}</dd></div><div><dt>Conflicts</dt><dd>{preview.conflicts}</dd></div></dl>
        <p>{incoming.local} persistent records · {incoming.session} tab records · {incoming.privateAccess} private access records</p>
        {preview.conflicts > 0 && <label className="hex-saves-choice"><input type="checkbox" checked={replace} onChange={event => setReplace(event.currentTarget.checked)} /><span>Replace conflicting saved data<small>Unchecked keeps your existing saves.</small></span></label>}
        <button type="button" onClick={importSaves}>{replace ? 'Import and replace conflicts' : 'Import missing saves'}</button>
      </div>}
    </section>
    {error && <p className="hex-saves-error" role="alert">{error}</p>}
    {message && <p className="hex-saves-success" role="status">{message}</p>}
    <nav aria-label="Continue playing"><a href="/story">Story</a><a href="/tower">Tower</a><a href="/skirmish">Arena</a></nav>
  </main>;
}
