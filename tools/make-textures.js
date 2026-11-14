// SPDX-License-Identifier: GPL-3.0-or-later
// Generates the panel textures in PerennialUI/Media/Textures.
// Both are white, 32x32, 32-bit TGA masks with a 6px corner radius, drawn
// nine-sliced (margin 8) and tinted by the theme at draw time:
//   panel-fill.tga  a filled rounded rectangle
//   panel-edge.tga  its one-pixel outline
// Run from the repo root: node tools/make-textures.js
const fs = require("fs");
const path = require("path");

const SIZE = 32;
const RADIUS = 6;
const out = path.join(__dirname, "..", "PerennialUI", "Media", "Textures");

// Signed distance from a point to the edge of the rounded rectangle
// (negative inside), measured from pixel centres.
function distance(x, y) {
  const half = SIZE / 2;
  const dx = Math.abs(x + 0.5 - half) - (half - RADIUS);
  const dy = Math.abs(y + 0.5 - half) - (half - RADIUS);
  const outside = Math.hypot(Math.max(dx, 0), Math.max(dy, 0));
  const inside = Math.min(Math.max(dx, dy), 0);
  return outside + inside - RADIUS;
}

const clamp = (v) => Math.max(0, Math.min(1, v));

function tga(alphaAt) {
  const header = Buffer.alloc(18);
  header[2] = 2; // uncompressed true colour
  header.writeUInt16LE(SIZE, 12);
  header.writeUInt16LE(SIZE, 14);
  header[16] = 32; // bits per pixel
  header[17] = 0x28; // 8 alpha bits, origin top-left
  const pixels = Buffer.alloc(SIZE * SIZE * 4);
  for (let y = 0; y < SIZE; y++) {
    for (let x = 0; x < SIZE; x++) {
      const i = (y * SIZE + x) * 4;
      pixels[i] = pixels[i + 1] = pixels[i + 2] = 255; // BGR white
      pixels[i + 3] = Math.round(clamp(alphaAt(distance(x, y))) * 255);
    }
  }
  return Buffer.concat([header, pixels]);
}

fs.mkdirSync(out, { recursive: true });
// Fill: opaque inside, antialiased over the last pixel.
fs.writeFileSync(path.join(out, "panel-fill.tga"), tga((d) => 0.5 - d));
// Edge: a band one pixel wide just inside the boundary.
fs.writeFileSync(path.join(out, "panel-edge.tga"), tga((d) => Math.min(0.5 - d, d + 1.5)));
console.log("Wrote panel-fill.tga and panel-edge.tga to " + out);
