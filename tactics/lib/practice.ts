import { defaultLoadout, validateLoadout } from './spells.ts';

/** Practice demonstrates a setup and follow-up; player starter kits stay unchanged. */
export function practiceLoadouts(ids: string[]): Record<string, string[]> {
  return Object.fromEntries(ids.map(id => [id, validateLoadout(id, id === 's_wayne'
    ? ['wither_bolt', 'blight', 'radiant_bolt', 'reap']
    : defaultLoadout(id))]));
}
