// The default wallpapers (shell/assets/wallpapers): an engraved poster in
// the shell's look, one per palette. Drawn as SVG and rendered to PNG:
//   scripts/poster-wallpaper.sh [width height]   (default 1920 1080)
// The same seed gives the same dots every time.
const WALLS = {
  moon:  { word: 'MOON',  h: 220, s: 16, ns: 5 },
  ember: { word: 'EMBER', h: 22,  s: 85, ns: 16 },
  tide:  { word: 'TIDE',  h: 214, s: 72, ns: 20 },
  moss:  { word: 'MOSS',  h: 96,  s: 38, ns: 12 },
  rose:  { word: 'ROSE',  h: 342, s: 72, ns: 15 },
};
const name = process.argv[2] || 'moon';
const p = WALLS[name];
const hsl = (h, s, l) => `hsl(${h},${Math.max(0, s)}%,${l}%)`;
const bg = hsl(p.h, p.ns, 8), fg = hsl(p.h, p.ns, 88), acc = hsl(p.h, p.s, 70);

function rng(seed) { let a = 0; for (const c of seed) a = (a * 31 + c.charCodeAt(0)) | 0; return () => { a |= 0; a = a + 0x6D2B79F5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }
const R = rng(name);
const out = [];
const cx = 1120, cy = 520, r = 340;
const f = n => +n.toFixed(2);

// ellipse arc helper: points of the rotated orbit ellipse from angle a0 to a1
function orbit(a0, a1) {
  const rx = r * 1.55, ry = r * 0.3, rot = -0.22, pts = [];
  for (let i = 0; i <= 120; i++) {
    const a = a0 + (a1 - a0) * i / 120, x = rx * Math.cos(a), y = ry * Math.sin(a);
    pts.push(`${f(cx + x * Math.cos(rot) - y * Math.sin(rot))},${f(cy + x * Math.sin(rot) + y * Math.cos(rot))}`);
  }
  return `<polyline points="${pts.join(' ')}" fill="none" stroke="${fg}" stroke-opacity=".45" stroke-width="1.4"/>`;
}

// The background runs past the 16:9 poster, so other screen shapes show
// all of it with plain background around
out.push(`<rect x="-4000" y="-4000" width="9600" height="8900" fill="${bg}"/>`);
out.push(orbit(Math.PI, 2 * Math.PI));
out.push(`<circle cx="${cx}" cy="${cy}" r="${r}" fill="${bg}"/>`);
const dots = [];
for (let i = 0; i < 30000; i++) {
  const a = R() * 6.283, rr = Math.sqrt(R()) * r, px = cx + Math.cos(a) * rr, py = cy + Math.sin(a) * rr;
  const nx = (px - cx) / r, ny = (py - cy) / r, nz = Math.sqrt(Math.max(0, 1 - nx * nx - ny * ny));
  let lam = Math.max(0, -.5 * nx - .55 * ny + .67 * nz);
  const mare = Math.sin(px * .013) * Math.cos(py * .011) + Math.sin((px + py) * .006);
  if (mare > .9) lam *= .35;
  if (R() < Math.pow(lam, 1.1) * .95) { const o = .55 + R() * .45; dots.push(`<rect x="${f(px)}" y="${f(py)}" width="1.6" height="1.6" fill-opacity="${o.toFixed(2)}"/>`); }
}
out.push(`<g fill="${fg}">${dots.join('')}</g>`);
const craters = [];
for (let i = 0; i < 9; i++) { const a = R() * 6.283, rr = R() * r * .8, cr = 6 + R() * 26; craters.push(`<circle cx="${f(cx + Math.cos(a) * rr)}" cy="${f(cy + Math.sin(a) * rr)}" r="${f(cr)}"/>`); }
out.push(`<g fill="none" stroke="${fg}" stroke-opacity=".4" stroke-width="1">${craters.join('')}</g>`);
out.push(orbit(0, Math.PI));

// vertical headline, fitted to 700 px like the mockup
out.push(`<text transform="translate(210 820) rotate(-90)" font-family="Mitr" font-weight="600" font-size="250" fill="${fg}" textLength="${p.word.length > 4 ? 700 : 600}" lengthAdjust="spacingAndGlyphs">${p.word}</text>`);

// star in the wallpaper's own color
const star = [];
for (let i = 0; i < 8; i++) { const a = i * Math.PI / 4 - Math.PI / 2, rr = i % 2 ? 4 : 22; star.push(`${f(1500 + Math.cos(a) * rr)},${f(300 + Math.sin(a) * rr)}`); }
out.push(`<polygon points="${star.join(' ')}" fill="${acc}"/>`);

// small print
const small = (t, x, y) => `<text x="${x}" y="${y}" font-family="Mitr" font-size="13" letter-spacing="3" fill="${fg}" fill-opacity=".8">${t}</text>`;
['LIFE IS BUT', 'A FLEETING MOMENT,', 'MAKE IT COUNT.'].forEach((t, i) => out.push(small(t, 1310, 120 + i * 22)));
['NOTHING LASTS.', 'NOTHING IS FINISHED.', 'NOTHING IS PERFECT.'].forEach((t, i) => out.push(small(t, 330, 760 + i * 22)));
out.push(small('01 · 11 · MMXXVI', 330, 120));
const bars = [];
for (let i = 0, bx = 330; i < 34; i++) { const bw = R() < .4 ? 3 : 1.4; bars.push(`<rect x="${f(bx)}" y="140" width="${bw}" height="28"/>`); bx += bw + 2 + R() * 3; }
out.push(`<g fill="${fg}">${bars.join('')}</g>`);
const marks = [[60, 860], [1540, 860], [330, 200], [1540, 200]].map(([a, b]) => `<path d="M${a - 9} ${b}H${a + 9}M${a} ${b - 9}V${b + 9}"/>`);
out.push(`<g stroke="${fg}" stroke-opacity=".7" stroke-width="1.2">${marks.join('')}</g>`);

console.log(`<svg xmlns="http://www.w3.org/2000/svg" width="${process.argv[3] || 1920}" height="${process.argv[4] || 1080}" viewBox="0 0 1600 900" preserveAspectRatio="xMidYMid meet">${out.join('')}</svg>`);
