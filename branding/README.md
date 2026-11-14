# Branding

The Perennial UI mark is four petals turning through a season's two colours: the year going round, and the plant coming back.

| File | Use |
| --- | --- |
| `logo.svg` | Source for the icon |
| `logo-512.png`, `logo-64.png` | Icon exports (project pages, avatars) |
| `header.svg` | Source for the wide header |
| `social-preview.png` | 1280 by 640 header for the README and GitHub's social preview |

In the game the mark follows the player's season. Everywhere else it uses the spring colours:

| Role | Colour |
| --- | --- |
| Tile and background | `#0F1622`, `#0A1018` |
| Spring accent pair | `#7BD88F`, `#F3A6C4` |
| Summer, autumn, winter accents | `#FFC24B`, `#FF8A4C`, `#7CC4FF` |
| Text | `#EEF4F8`, muted `#A3B3C0` |

Type is Sora Bold for the wordmark, DM Sans Medium for text and DM Mono Medium for small labels, the same fonts the addon bundles.

The artwork was drawn for this project as hand-written SVG and is licensed with the rest of the repository. The text in `header.svg` is converted to outlines, so it looks the same on any machine whether or not the fonts are installed. To change the wording, regenerate the outlines from the bundled font files. If you change an SVG, re-export its PNGs at the sizes above.

Still to do: the in-game addon icon needs a TGA or BLP export placed in `PerennialUI/Media/` and referenced from the TOC.
