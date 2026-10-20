import type { Element } from '../../lib/game';
import { elementPresentation, spellPresentation, type ElementKind, type ElementPalette, type SpellVisualIdentity } from '../../lib/element-presentation';

export type ElementIconProps = ({ element: Element; spell?: SpellVisualIdentity } | { element?: Element; spell: SpellVisualIdentity }) & {
  /** Explicit branch selectors only. A supplied spell always uses its canonical branch. */
  advanced?: boolean;
  size?: number;
  className?: string;
  /** Omit beside visible text; supply when the emblem itself needs an accessible name. */
  label?: string;
};
type Tone = keyof ElementPalette;
type Layer = readonly [tone: Tone, path: string];

/** Original silhouettes on the same 24-pixel grid. No glyphs, filters or fractional strokes. */
const ART: Readonly<Record<ElementKind, readonly Layer[]>> = {
  fire: [
    ['ink', 'M11 1h3v4h2v4h2V6h2v5h2v7h-2v3h-4v2H8v-2H4v-3H2v-6h2V8h2v4h2V7h2V4h1z'],
    ['main', 'M12 4h1v3h2v5h4v-1h1v7h-2v2h-3v1H9v-1H6v-2H4v-5h2v2h4V8h2z'],
    ['bright', 'M12 8h1v6h3v-2h2v6h-2v2H9v-2H7v-3h3v-3h2z'],
    ['light', 'M12 13h2v3h2v3h-2v2h-4v-2H9v-3h3z'],
    ['spark', 'M12 17h2v3h-2z'],
  ],
  lightning: [
    ['ink', 'M10 1h11v3h-2v3h-2v2h5v3h-2v2h-2v2h-2v2h-2v2h-2v2H8v-5H5v-3H2v-3h2V8h2V5h2V3h2z'],
    ['main', 'M11 3h7v2h-2v3h-2v3h5v1h-2v2h-2v2h-2v2h-2v2h-1v-5H7v-2H4v-1h2V9h2V6h2V4h1z'],
    ['bright', 'M11 4h5v1h-2v3h-2v5h5v1h-2v2h-2v2h-1v-5H6v-1h2V9h2V6h1z'],
    ['light', 'M12 4h3v1h-2v3h-2v3H9V8h1V6h2zM12 13h3v1h-2v2h-1z'],
    ['spark', 'M12 4h2v2h-2zM10 8h1v2h-1z'],
  ],
  water: [
    ['ink', 'M11 1h2v3h2v3h2v3h2v3h2v6h-2v2h-3v2H8v-2H5v-2H3v-6h2v-3h2V7h2V4h2z'],
    ['main', 'M11 5h2v3h2v3h2v3h2v4h-2v2h-3v1h-4v-1H7v-2H5v-4h2v-3h2V8h2z'],
    ['bright', 'M11 8h2v4h2v6h-2v2H9v-2H7v-4h2v-3h2z'],
    ['light', 'M10 11h2v3h-2v4H8v-4h2z'],
    ['spark', 'M10 12h2v2h-2z'],
    ['shadow', 'M17 14h2v4h-2v2h-3v-2h3z'],
  ],
  ice: [
    ['ink', 'M10 1h4v4h3V3h4v4h-2v3h4v4h-4v3h2v4h-4v-2h-3v4h-4v-4H7v2H3v-4h2v-3H1v-4h4V7H3V3h4v2h3z'],
    ['main', 'M11 3h2v5h3V6h3V5h-1v4h-2v2h5v2h-5v2h2v4h1v-1h-3v-2h-3v5h-2v-5H8v2H5v1h1v-4h2v-2H3v-2h5V9H6V5H5v1h3v2h3z'],
    ['bright', 'M11 5h2v5h2v1h4v2h-4v1h-2v5h-2v-5H9v-1H5v-2h4v-1h2zM5 5h2v2H5zM17 5h2v2h-2zM5 17h2v2H5zM17 17h2v2h-2z'],
    ['light', 'M11 9h2v2h2v2h-2v2h-2v-2H9v-2h2z'],
    ['spark', 'M11 11h2v2h-2z'],
  ],
  earth: [
    ['ink', 'M9 3h6v2h3v5h2v3h3v7h-3v2H4v-2H1v-6h3v-4h3V6h2z'],
    ['main', 'M10 5h4v2h2v5h2v3h3v4h-3v1H5v-1H3v-4h3v-4h3V7h1z'],
    ['bright', 'M10 6h4v2h1v5h-3v3H9v-3H8v-2h1V8h1zM4 15h2v2H4zM18 15h2v2h-2z'],
    ['light', 'M10 6h3v2h-1v3h-2z'],
    ['shadow', 'M7 14h2v6H7zM15 13h2v7h-2zM11 17h2v3h-2zM3 18h4v1H3zM18 18h3v1h-3z'],
  ],
  metal: [
    ['ink', 'M2 4h20v6h-3v3h-4v4h4v4H5v-4h4v-4H5v-2H2z'],
    ['main', 'M4 6h16v2h-3v3h-4v8h4v1H7v-1h4v-8H6V9H4z'],
    ['bright', 'M4 6h16v2H6v1H4zM11 11h2v8h-2zM7 19h10v1H7z'],
    ['light', 'M4 6h16v1H4zM11 11h1v7h-1z'],
    ['spark', 'M5 6h6v1H5zM11 11h1v3h-1z'],
    ['shadow', 'M14 9h3v2h-3zM13 17h2v2h-2z'],
  ],
  air: [
    ['ink', 'M7 2h11v3h4v13h-4v4H7v-3H3v-9h12v3h2v4H9v-4H7v3h2v2h7v-2h2V8h-3V6h-5v3H1V5h6z'],
    ['main', 'M9 4h7v3h4v9h-4v4H9v-3H5v-5h8v2h2v1h-4v-2H7v4h2v1h7v-2h2V7h-3V6h-5v1H3V6h6z'],
    ['bright', 'M9 4h7v1H9zM19 8h1v7h-1zM9 19h6v1H9zM5 12h8v1H5z'],
    ['light', 'M10 4h4v1h-4zM6 12h5v1H6z'],
    ['ink', 'M1 15h2v2H1zM3 21h2v2H3z'],
    ['bright', 'M1 15h2v1H1zM3 21h2v1H3z'],
  ],
  storm: [
    ['ink', 'M9 2h7v2h3v3h3v6h-2v2h-5v2h-2v2h-2v3H7v-5H3v-3H1V8h3V5h5z'],
    ['main', 'M10 4h5v2h3v3h2v3h-2v1h-7v3H9v4H8v-5H5v-2H3V9h3V7h4z'],
    ['bright', 'M10 4h5v2h2v2h-4V6h-3zM6 7h4v2H6v2H4V9h2zM6 12h11v1h-7v3H8v2H7v-4H6z'],
    ['light', 'M10 4h4v1h-4zM6 7h3v1H6zM10 12h5v1h-5z'],
    ['ink', 'M15 18h3v2h-3zM19 16h3v2h-3z'],
    ['bright', 'M15 18h2v1h-2zM19 16h2v1h-2z'],
  ],
  light: [
    ['ink', 'M11 1h2v6h2v2h2v2h6v2h-6v2h-2v2h-2v6h-2v-6H9v-2H7v-2H1v-2h6V9h2V7h2z'],
    ['main', 'M11 5h2v4h2v2h4v2h-4v2h-2v4h-2v-4H9v-2H5v-2h4V9h2z'],
    ['bright', 'M11 8h2v2h1v1h2v2h-2v1h-1v2h-2v-2h-1v-1H8v-2h2v-1h1z'],
    ['light', 'M11 10h2v1h1v2h-1v1h-2v-1h-1v-2h1z'],
    ['spark', 'M11 11h2v2h-2z'],
    ['main', 'M4 4h2v2H4zM18 4h2v2h-2zM4 18h2v2H4zM18 18h2v2h-2z'],
  ],
  radiance: [
    ['ink', 'M11 1h2v3h-2zM4 3h3v3H4zM17 3h3v3h-3zM1 11h3v2H1zM20 11h3v2h-3zM4 18h3v3H4zM17 18h3v3h-3zM11 20h2v3h-2zM9 5h6v2h3v3h1v5h-2v3h-3v1h-4v-1H7v-3H5v-5h1V7h3z'],
    ['main', 'M10 7h4v2h3v5h-2v3H9v-3H7V9h3zM11 2h2v1h-2zM5 4h1v1H5zM18 4h1v1h-1zM2 11h1v2H2zM21 11h1v2h-1zM5 19h1v1H5zM18 19h1v1h-1zM11 21h2v1h-2z'],
    ['bright', 'M10 7h4v2h2v5h-2v2h-4v-2H8V9h2z'],
    ['light', 'M10 8h3v1h-1v2h-2v3H9v-4h1z'],
    ['spark', 'M10 9h2v2h-2z'],
    ['shadow', 'M15 11h1v3h-2v2h-3v-1h3v-2h1z'],
  ],
  dark: [
    ['ink', 'M10 1h7v3h-4v3h-2v7h2v3h4v2h5v2h-5v2H9v-2H5v-3H2v-9h2V5h3V3h3z'],
    ['main', 'M10 3h3v1h-2v3H9v8h2v3h4v2h3v1h-8v-2H6v-3H4v-6h2V6h3V4h1z'],
    ['bright', 'M10 3h2v1h-2v3H8v7H6v-4h1V6h2V4h1zM8 17h2v1h3v1h-3v1H8z'],
    ['light', 'M9 5h1v2H9v3H8V7h1z'],
    ['ink', 'M17 7h2v2h2v2h-2v2h-2v-2h-2V9h2z'],
    ['light', 'M17 9h2v2h-2z'],
    ['spark', 'M17 9h1v1h-1z'],
  ],
  void: [
    ['ink', 'M7 2h10v2h3v3h2v10h-2v3h-3v2H7v-2H4v-3H2V7h2V4h3z'],
    ['main', 'M8 4h8v2h3v3h1v6h-1v3h-3v2H8v-2H5v-3H4V9h1V6h3z'],
    ['shadow', 'M9 7h7v2h2v7h-2v2H8v-2H6v-6h3z'],
    ['bright', 'M8 5h8v2h2v9h-2v2H8v-2H6v-6h7v2H8v4h8V8h-2V7H8z'],
    ['light', 'M9 5h5v1H9zM17 9h1v3h-1zM7 10h5v1H7z'],
    ['spark', 'M10 12h2v2h-2z'],
  ],
};

export default function ElementIcon({ element, spell, advanced = false, size = 24, className, label }: ElementIconProps) {
  const presentation = spell ? spellPresentation(spell) : elementPresentation(element!, advanced);
  return (
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width={size} height={size}
      className={className} role={label ? 'img' : undefined} aria-label={label} aria-hidden={label ? undefined : true}
      focusable="false" shapeRendering="crispEdges" fill="none"
      data-element={presentation.family} data-element-kind={presentation.kind} data-element-advanced={presentation.advanced || undefined}
      style={{ display: 'inline-block', flexShrink: 0, verticalAlign: 'middle', imageRendering: 'pixelated' }}>
      {label && <title>{label}</title>}
      {ART[presentation.kind].map(([tone, path], index) => <path key={index} fill={presentation.palette[tone]} d={path} />)}
    </svg>
  );
}

export { ElementIcon };
