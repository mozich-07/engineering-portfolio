const assert = require('node:assert/strict');
const fs = require('node:fs');
const core = require('./core.js');

// Four RGBA pixels with one transparent corner, using a custom two-color palette.
const pixels = [255, 0, 0, 255, 0, 0, 255, 255, 255, 0, 0, 255, 0, 0, 0, 0];
const palette = [
  {code: 'R', name: 'Red', hex: '#FF0000'},
  {code: 'B', name: 'Blue', hex: '#0000FF'}
];
const sampled = core.sample(pixels, 2, 2, 2, 2);
const pattern = core.quantize(sampled, 2, 2, palette);
const materials = core.materials(pattern);
assert.deepEqual(pattern.matrix, [0, 1, 0, -1]);
assert.deepEqual(materials.map(row => row.count), [2, 1]);
fs.mkdirSync('outputs', {recursive: true});
fs.writeFileSync('outputs/pattern.svg', core.svg(pattern));
console.table(materials);
