export type GameShortcut = 'move' | 'guard' | 'undo' | 'cancel' | 'spell1' | 'spell2' | 'spell3' | 'spell4' | 'spell5';
type ShortcutEvent = {
  key: string; ctrlKey?: boolean; metaKey?: boolean; altKey?: boolean; repeat?: boolean;
  isComposing?: boolean; defaultPrevented?: boolean; target?: unknown;
};

/** Single-key game commands never intercept browser shortcuts or text editing. */
export function gameShortcut(event: ShortcutEvent): GameShortcut | null {
  if (event.ctrlKey || event.metaKey || event.altKey || event.repeat || event.isComposing || event.defaultPrevented) return null;
  const target = event.target as { tagName?: string; isContentEditable?: boolean } | null;
  if (target?.isContentEditable || ['INPUT', 'TEXTAREA', 'SELECT'].includes(target?.tagName?.toUpperCase() ?? '')) return null;
  const key = event.key.toLowerCase();
  if (key === 'm') return 'move';
  if (key === 'g') return 'guard';
  if (key === 'u') return 'undo';
  if (key === 'escape') return 'cancel';
  return /^[1-5]$/.test(key) ? `spell${key}` as GameShortcut : null;
}
