/** Version dispatch shared by the browser and the authoritative room server. */
import * as current from "./game.ts";
import * as legacy from "./game-v1.ts";
import type { Cell, GameAction, GameState, Player, Point, Unit } from "./game.ts";

export * from "./game.ts";
export const PROTOCOL_VERSION = 2;
export type RulesVersion = 1 | 2;

/** Untagged saves belong to the exact first public rules; never infer from turn revision. */
export function rulesVersionOf(state: unknown): RulesVersion {
  if (!state || typeof state !== "object") throw new Error("This saved match is incomplete.");
  const version = (state as { rulesVersion?: unknown }).rulesVersion;
  if (version === undefined) return 1;
  if (version === 2) return 2;
  throw new Error("This match uses an unsupported rules version. Reload the game before continuing; your saved match has been kept.");
}

export function applyAction(state: GameState, player: Player, action: GameAction): GameState {
  if (rulesVersionOf(state) === 2) return current.applyAction(state, player, action);
  if (action.type === "guard") throw new Error("Guard is available in new-rules matches. Finish this legacy match, then start a rematch.");
  return legacy.applyAction(state, player, action as legacy.GameAction);
}

export function legalTargets(state: GameState, unitId: string, kind: "move" | "cast" | "guard"): Cell[] {
  if (rulesVersionOf(state) === 2) return current.legalTargets(state, unitId, kind);
  return kind === "guard" ? [] : legacy.legalTargets(state, unitId, kind);
}

export function previewAction(state: GameState, action: GameAction): string {
  if (rulesVersionOf(state) === 2) return current.previewAction(state, action);
  if (action.type === "guard") return "Guard is available after this legacy match, in a new game or rematch.";
  return legacy.previewAction(state, action as legacy.GameAction);
}

export function chooseAIAction(state: GameState): GameAction {
  return rulesVersionOf(state) === 2 ? current.chooseAIAction(state) : legacy.chooseAIAction(state);
}

export function movementPath(state: GameState, unit: Unit, target: Point): Cell[] | null {
  return rulesVersionOf(state) === 2 ? current.movementPath(state, unit, target) : legacy.movementPath(state, unit, target);
}

export function previewPush(state: GameState, unitId: string, q: number, r: number): Cell | undefined {
  if (rulesVersionOf(state) === 2) return current.previewPush(state, unitId, q, r);
  const caster = state.units.find((unit) => unit.id === unitId);
  const target = state.units.find((unit) => legacy.isAlive(unit) && unit.q === q && unit.r === r);
  if (!caster || !target || target.owner === caster.owner || legacy.getChampion(caster.championId).element !== "air" ||
      !legacy.legalTargets(state, unitId, "cast").some((cell) => cell.q === q && cell.r === r)) return undefined;
  // Resolve with the archived engine. Keep a spare AP in this disposable preview
  // so automatic turn changes cannot respawn a pushed target before inspection.
  const simulated = legacy.applyAction({ ...state, ap: 2 }, state.turn, { type: "cast", unitId, q, r });
  const moved = simulated.units.find((unit) => unit.id === target.id)!;
  return moved.q === target.q && moved.r === target.r ? undefined : legacy.getCell(state, moved.q, moved.r);
}

/** Validate persisted local state before rendering; do not upgrade, erase, or mutate it. */
export function restoreGameState(value: unknown): GameState {
  rulesVersionOf(value);
  const state = value as Record<string, unknown>;
  const invalid = () => { throw new Error("This saved match could not be read safely. The saved data has been kept; you can start a new match."); };
  const integer = (number: unknown, min: number, max: number) => Number.isSafeInteger(number) && (number as number) >= min && (number as number) <= max;
  const player = (number: unknown) => number === 0 || number === 1;
  const terrains = new Set(["plain", "wall", ...current.ELEMENTS.map((element) => element.id), ...current.REACTIONS.map((reaction) => reaction.id)]);
  if (state.mapId !== "confluence" || !integer(state.version, 1, Number.MAX_SAFE_INTEGER) ||
      !integer(state.round, 1, 1000) || !player(state.turn) || !player(state.initiative) ||
      !integer(state.turnsTaken, 0, 2) || !integer(state.ap, 0, 2) ||
      !Array.isArray(state.scores) || state.scores.length !== 2 || !state.scores.every((score) => integer(score, 0, 10000)) ||
      ![null, 0, 1, "draw"].includes(state.winner as null | number | string) ||
      !Array.isArray(state.log) || state.log.length > 200 || !state.log.every((line) => typeof line === "string" && line.length <= 1000) ||
      !Array.isArray(state.cells) || state.cells.length !== 37 || !Array.isArray(state.units) || state.units.length !== 6) invalid();
  const cells = state.cells as Record<string, unknown>[];
  const coordinates = new Set<string>();
  for (const cell of cells) {
    if (!cell || typeof cell !== "object" || !integer(cell.q, -3, 3) || !integer(cell.r, -3, 3) ||
        Math.abs((cell.q as number) + (cell.r as number)) > 3 || typeof cell.well !== "boolean" ||
        typeof cell.terrain !== "string" || !terrains.has(cell.terrain) ||
        (cell.ttl !== undefined && !integer(cell.ttl, 1, 10))) invalid();
    const key = `${cell.q},${cell.r}`;
    if (coordinates.has(key)) invalid();
    coordinates.add(key);
  }
  const units = state.units as Record<string, unknown>[];
  const ids = new Set<string>();
  const occupied = new Set<string>();
  for (const unit of units) {
    if (!unit || typeof unit !== "object" || !player(unit.owner) ||
        typeof unit.championId !== "string" || !current.CHAMPIONS.some((champion) => champion.id === unit.championId) ||
        unit.id !== `${unit.owner}-${unit.championId}` || ids.has(unit.id as string) ||
        !integer(unit.q, -3, 3) || !integer(unit.r, -3, 3) || !coordinates.has(`${unit.q},${unit.r}`) ||
        !integer(unit.maxHp, 1, 20) || !integer(unit.hp, 0, unit.maxHp as number) ||
        typeof unit.moved !== "boolean" || typeof unit.cast !== "boolean" ||
        (unit.guard !== undefined && typeof unit.guard !== "boolean") ||
        (unit.respawn !== undefined && !integer(unit.respawn, 0, 1000))) invalid();
    ids.add(unit.id as string);
    if ((unit.hp as number) > 0 && unit.respawn === undefined) {
      const key = `${unit.q},${unit.r}`;
      if (occupied.has(key)) invalid();
      occupied.add(key);
    }
  }
  if (units.filter((unit) => unit.owner === 0).length !== 3 || units.filter((unit) => unit.owner === 1).length !== 3) invalid();
  return structuredClone(value) as GameState;
}
