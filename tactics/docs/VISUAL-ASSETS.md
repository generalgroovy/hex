# Visual assets

The reference direction is warm parchment, dark brown pixel outlines, bright jewel highlights, and squared display lettering. Gameplay definitions and canonical identities are unchanged by these presentation assets.

## Element emblems

`app/components/ElementIcon.tsx` contains six original SVG drawings on a 24 × 24 grid: flame, droplet, open wind spiral, faceted stone, radiant star, and enclosed void spiral. Every emblem uses `#382b20` outlines, integer-aligned geometry, and `crispEdges` rendering. Base colors are Fire `#ab431e`, Water `#176a95`, Air `#4f6e2c`, Earth `#805827`, Light `#996718`, and Dark `#63458d`.

Use `<ElementIcon element={element} size={24} />`; both default and named exports are available. `size` defaults to 24 and `className` passes through. The SVG is decorative (`aria-hidden="true"`, `focusable="false"`); its surrounding control supplies an accessible element name. Native 24-pixel rendering or integer multiples preserve the intended pixel rhythm. Distinct silhouettes complement the colors.

## Self-hosted heading font

[Pixelify Sans on Google Fonts](https://fonts.google.com/specimen/Pixelify+Sans) is designed by Stefie Justprince. The [official Google Fonts metadata](https://github.com/google/fonts/blob/8b0a1d0f5983c89bc2b93f1b5fb55f9e252744b5/ofl/pixelifysans/METADATA.pb) identifies a normal-style variable font with weights 400–700. The unmodified font binary and its complete accompanying license were downloaded from the official `google/fonts` repository at commit `8b0a1d0f5983c89bc2b93f1b5fb55f9e252744b5`.

- Font: `public/fonts/PixelifySans-Variable.ttf` — 79,160 bytes; upstream filename `PixelifySans[wght].ttf`.
- License: `public/fonts/PixelifySans-OFL.txt` — [SIL Open Font License 1.1, official copy](https://github.com/google/fonts/blob/8b0a1d0f5983c89bc2b93f1b5fb55f9e252744b5/ofl/pixelifysans/OFL.txt).
- Copyright: Copyright 2021 The Pixelify Sans Project Authors.
- Font SHA-256: `9ba86cd010a4de309d263ceff8e8044092c9db7efda869620cb9ff1c4389e8a5`.
- License SHA-256: `b66ba46f511a851ab09998b5a5a9fdbb102545a3864cb993095e1745996873a7`.

Keep the license with redistributed font files. The OFL permits bundling and self-hosting under its conditions; the font itself must not be sold by itself. The CSS family alias may be `Confluence Pixel`; the binary and its internal font names remain unchanged. Load `/fonts/PixelifySans-Variable.ttf` locally with `format('truetype')`, `font-style: normal`, `font-weight: 400 700`, and `font-display: swap`. No runtime Google Fonts request is required. Use the display face for headings and short labels, with the existing readable text face for dense rules.

## Reference and material

The user supplied `styleref1.png` as visual direction on 2026-10-16. Its SHA-256 is `c0fb63c912718d64ca061ccd85817869ffc3348a3c81a910962df57066279fd4`. It informs the warm parchment ground, substantial original sprite silhouettes, moss and brass, black-brown contours, pixel headings, and jewel elemental symbols. Its printed names and affinities do not override the original H.E.X. source data. The reference itself is not redistributed in the site.

`public/art/parchment.png` is a new material generated with the built-in image-generation tool, opaque background, no reference image editing. The original output is preserved. Saved asset SHA-256: `4fce319f6a14d1471912b01d9bdd09c8243e18c5610f6bf868ef7c7999cbdb07`.

Generation prompt:

> Generate a seamless square tile of pale warm antique parchment for the UI of a charming pixel-art fantasy tactics game. This is only a paper material, NOT a mockup or illustration. Match the warm ivory, honey-cream and lightly aged ochre paper of a classic illustrated fantasy champion bestiary. Very subtle fine natural paper fibres and irregular low-contrast mottling, tiny restrained warm speckles, mostly even pale #f2e3ba ground with #fff3ce highlights and sparse #dfc58d aging. Designed to sit behind small dark-brown text and detailed colorful pixel character sprites, so keep contrast gentle and generous quiet areas. Flat evenly lit, no perspective, no shadows, no folded corners, no edge border, no dark vignette, no holes, no stains, no text, no symbols, no characters, no objects, no watermark. Seamlessly repeatable edges. 1024 by 1024 material tile.

The original thirty character atlases remain unchanged. The foliage ornament, favicon, elemental emblems, board tiles, scenic details and effects are code-native SVG/CSS. The visual refresh uses one set of palette tokens in `app/visual-tokens.css`; team identity retains teal/rust rings and explicit ownership labels, and legal targets retain distinct outlined geometry.
