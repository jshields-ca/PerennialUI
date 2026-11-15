// SPDX-License-Identifier: GPL-3.0-or-later
// Generates the brand artwork in branding/: logo.svg, header.svg and their
// PNG exports. Text is written as outlines taken from the bundled fonts, so
// the SVGs look the same on any machine.
//
// Needs two dev-only packages (not part of the addon):
//   npm install --no-save opentype.js@1.3.4 @resvg/resvg-js
// Run from the repo root: node tools/make-brand.js
const fs = require("fs");
const path = require("path");
const opentype = require("opentype.js");
const { Resvg } = require("@resvg/resvg-js");

const root = path.join(__dirname, "..");
const fonts = path.join(root, "PerennialUI", "Media", "Fonts");
const out = path.join(root, "branding");

const sora = opentype.loadSync(path.join(fonts, "Sora-Bold.ttf"));
const sans = opentype.loadSync(path.join(fonts, "DMSans-Medium.ttf"));
const mono = opentype.loadSync(path.join(fonts, "DMMono-Medium.ttf"));

// The fixed brand colours are the spring season's accent pair.
const A = { light: "#B9F4C6", mid: "#7BD88F", deep: "#3A9A55" };
const B = { light: "#FCD6E4", mid: "#F3A6C4", deep: "#B4628A" };

const outline = (font, text, x, y, size, fill, tracking) =>
  `<path fill="${fill}" d="${font.getPath(text, x, y, size, { kerning: true, tracking: tracking || 0 }).toPathData(2)}"/>`;

// Shared definitions for the petal mark. One petal is drawn pointing up and
// reused at four rotations; `s` scales stroke widths and blur to the artwork.
function petalDefs(s) {
  return `
    <linearGradient id="petalA" x1="0.5" y1="0" x2="0.5" y2="1">
      <stop offset="0" stop-color="${A.light}"/><stop offset="0.5" stop-color="${A.mid}"/><stop offset="1" stop-color="${A.deep}"/>
    </linearGradient>
    <linearGradient id="petalB" x1="0.5" y1="0" x2="0.5" y2="1">
      <stop offset="0" stop-color="${B.light}"/><stop offset="0.5" stop-color="${B.mid}"/><stop offset="1" stop-color="${B.deep}"/>
    </linearGradient>
    <linearGradient id="sheen" x1="0.2" y1="0" x2="0.8" y2="1">
      <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.6"/><stop offset="0.7" stop-color="#FFFFFF" stop-opacity="0"/>
    </linearGradient>
    <radialGradient id="core" cx="0.4" cy="0.35" r="0.75">
      <stop offset="0" stop-color="#FFFFFF"/><stop offset="1" stop-color="#C9D6DF"/>
    </radialGradient>
    <filter id="shadow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="${14 * s}"/></filter>
    <ellipse id="petal" cx="0" cy="-66" rx="50" ry="74"/>
    <ellipse id="rim" cx="0" cy="-66" rx="49" ry="73" fill="none" stroke="#FFFFFF" stroke-opacity="0.38" stroke-width="1.6"/>`;
}

// The mark, centred on the origin, about 280 units across. Petals are drawn
// back to front so each one visibly overlaps the one before it.
function petals() {
  // The sheen is placed in screen space, not rotated with the petal, so the
  // light falls from the top left on all four.
  const petal = (angle, fill, opacity) => {
    const upright = angle % 180 === 0;
    const r = (angle * Math.PI) / 180;
    const cx = 66 * Math.sin(r), cy = -66 * Math.cos(r);
    const sheen = upright
      ? `<ellipse cx="${(cx - 14).toFixed(1)}" cy="${(cy - 28).toFixed(1)}" rx="20" ry="33" fill="url(#sheen)"/>`
      : `<ellipse cx="${(cx - 26).toFixed(1)}" cy="${(cy - 15).toFixed(1)}" rx="33" ry="19" fill="url(#sheen)"/>`;
    return `<g opacity="${opacity}"><g transform="rotate(${angle})"><use href="#petal" fill="url(#${fill})"/><use href="#rim"/></g>${sheen}</g>`;
  };
  return `
    <ellipse cx="0" cy="16" rx="120" ry="112" fill="#000000" opacity="0.5" filter="url(#shadow)"/>
    ${petal(270, "petalB", 0.5)}
    ${petal(180, "petalA", 0.62)}
    ${petal(90, "petalB", 0.86)}
    ${petal(0, "petalA", 0.96)}
    <circle r="26" fill="none" stroke="#FFFFFF" stroke-opacity="0.35" stroke-width="2"/>
    <circle r="19" fill="url(#core)"/>`;
}

const logo = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" role="img" aria-label="Perennial UI logo: four glass petals turning through a season's two colours">
  <defs>${petalDefs(1)}
    <linearGradient id="tile" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#16242A"/><stop offset="1" stop-color="#0B1119"/>
    </linearGradient>
  </defs>
  <rect width="512" height="512" rx="64" fill="url(#tile)"/>
  <rect x="5" y="5" width="502" height="502" rx="59" fill="none" stroke="${A.mid}" stroke-opacity="0.5" stroke-width="8"/>
  <g transform="translate(256 256) scale(1.38)">${petals()}
  </g>
</svg>
`;

const header = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1280 640" role="img" aria-label="Perennial UI: the interface that grows back">
  <defs>${petalDefs(1)}
    <radialGradient id="glowA" cx="0.2" cy="0.3" r="0.6">
      <stop offset="0" stop-color="${A.mid}" stop-opacity="0.30"/><stop offset="1" stop-color="${A.mid}" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="glowB" cx="0.95" cy="0.95" r="0.6">
      <stop offset="0" stop-color="${B.mid}" stop-opacity="0.22"/><stop offset="1" stop-color="${B.mid}" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="glass" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#1A2B2C" stop-opacity="0.92"/><stop offset="1" stop-color="#0D151C" stop-opacity="0.92"/>
    </linearGradient>
    <clipPath id="panel"><rect x="96" y="120" width="1088" height="400" rx="14"/></clipPath>
  </defs>
  <rect width="1280" height="640" fill="#0A1018"/>
  <rect width="1280" height="640" fill="url(#glowA)"/>
  <rect width="1280" height="640" fill="url(#glowB)"/>

  <!-- One glass panel. The accent rail is clipped to the panel so it follows the rounded corners. -->
  <rect x="96" y="120" width="1088" height="400" rx="14" fill="url(#glass)"/>
  <g clip-path="url(#panel)">
    <rect x="96" y="120" width="7" height="400" fill="${A.mid}"/>
    <rect x="103" y="121" width="1081" height="1" fill="#FFFFFF" fill-opacity="0.18"/>
  </g>
  <rect x="96.5" y="120.5" width="1087" height="399" rx="13.5" fill="none" stroke="${A.mid}" stroke-opacity="0.45"/>

  <g transform="translate(304 320)">${petals()}
  </g>

  <!-- Text is converted to outlines. Wordmark: Sora Bold 92. Tagline: DM Sans Medium 30. Label: DM Mono Medium 18, capitals. -->
  ${outline(sora, "Perennial UI", 504, 318, 92, "#EEF4F8", -22)}
  ${outline(sans, "The interface that grows back.", 508, 372, 30, "#A3B3C0")}
  ${outline(mono, "OPEN SOURCE  ·  MODULAR  ·  WOW: FOREVER", 508, 430, 18, A.mid, 90)}

  <g transform="translate(508 462)">
    <rect width="34" height="6" rx="3" fill="#7BD88F"/>
    <rect x="42" width="34" height="6" rx="3" fill="#FFC24B"/>
    <rect x="84" width="34" height="6" rx="3" fill="#FF8A4C"/>
    <rect x="126" width="34" height="6" rx="3" fill="#7CC4FF"/>
  </g>
</svg>
`;

function png(svg, name, width) {
  const image = new Resvg(svg, { fitTo: { mode: "width", value: width }, font: { loadSystemFonts: false } }).render();
  fs.writeFileSync(path.join(out, name), image.asPng());
  console.log(name, image.width + "x" + image.height);
}

fs.writeFileSync(path.join(out, "logo.svg"), logo);
fs.writeFileSync(path.join(out, "header.svg"), header);
png(header, "social-preview.png", 1280);
png(logo, "logo-512.png", 512);
png(logo, "logo-64.png", 64);
