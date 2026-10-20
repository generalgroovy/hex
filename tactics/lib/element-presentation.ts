import type { Element } from './game.ts';

/** A spell's branch is authored rules data. Its name, level and effects are not its visual identity. */
export type SpellVisualIdentity = { element: Element; branch?: string };
export type AdvancedElementKind = 'lightning' | 'ice' | 'metal' | 'storm' | 'radiance' | 'void';
export type ElementKind = Element | AdvancedElementKind;
export type ElementPalette = Readonly<{
  ink: string; shadow: string; main: string; bright: string; light: string; spark: string;
}>;

/** One family, one ramp: advanced emblems and effects inherit these exact colours. */
export const ELEMENT_PALETTES: Readonly<Record<Element, ElementPalette>> = Object.freeze({
  fire: Object.freeze({ ink: '#382b20', shadow: '#722f24', main: '#ab431e', bright: '#e57534', light: '#ffb760', spark: '#ffe2ad' }),
  water: Object.freeze({ ink: '#382b20', shadow: '#164e6d', main: '#176a95', bright: '#42a9cf', light: '#a2e0e9', spark: '#e4f8ee' }),
  earth: Object.freeze({ ink: '#382b20', shadow: '#513d26', main: '#805827', bright: '#b38a47', light: '#d9b86a', spark: '#f5df9d' }),
  air: Object.freeze({ ink: '#382b20', shadow: '#344d2c', main: '#4f6e2c', bright: '#82a64e', light: '#b6ce79', spark: '#e1edb2' }),
  light: Object.freeze({ ink: '#382b20', shadow: '#76521f', main: '#996718', bright: '#dba638', light: '#f4d478', spark: '#fff4bf' }),
  dark: Object.freeze({ ink: '#382b20', shadow: '#352549', main: '#63458d', bright: '#9870b9', light: '#c4a2dc', spark: '#eedcf6' }),
});

export const ADVANCED_ELEMENT_KINDS: Readonly<Record<Element, AdvancedElementKind>> = Object.freeze({
  fire: 'lightning', water: 'ice', earth: 'metal', air: 'storm', light: 'radiance', dark: 'void',
});
export const ADVANCED_ELEMENT_NAMES: Readonly<Record<Element, string>> = Object.freeze({
  fire: 'Lightning', water: 'Ice', earth: 'Metal', air: 'Storm', light: 'Radiance', dark: 'Void',
});
export const ELEMENT_NAMES: Readonly<Record<Element, string>> = Object.freeze({
  fire: 'Fire', water: 'Water', earth: 'Earth', air: 'Air', light: 'Light', dark: 'Dark',
});
export type ElementPresentation = Readonly<{
  family: Element;
  kind: ElementKind;
  name: string;
  familyName: string;
  advanced: boolean;
  accessibleLabel: string;
  palette: ElementPalette;
}>;

export function elementPresentation(element: Element, advanced = false): ElementPresentation {
  const familyName = ELEMENT_NAMES[element], name = advanced ? ADVANCED_ELEMENT_NAMES[element] : familyName;
  return {
    family: element, kind: advanced ? ADVANCED_ELEMENT_KINDS[element] : element,
    name, familyName, advanced, accessibleLabel: advanced ? `${name} · ${familyName}` : name,
    palette: ELEMENT_PALETTES[element],
  };
}

/** No spell-ID or English-name heuristic: signatures and scaled spells retain their authored branch. */
export function spellPresentation(spell: SpellVisualIdentity): ElementPresentation {
  return elementPresentation(spell.element, spell.branch === ADVANCED_ELEMENT_NAMES[spell.element]);
}
