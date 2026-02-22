// Minimal 16x16 32bpp ICO so browser doesn't 404 on /favicon.ico
const fs = require("fs");
const path = require("path");

// ICO header (6 bytes)
const header = Buffer.alloc(6);
header.writeUInt16LE(0, 0);   // reserved
header.writeUInt16LE(1, 2);   // type 1 = ICO
header.writeUInt16LE(1, 4);   // count 1

// Directory entry (16 bytes)
const entry = Buffer.alloc(16);
entry[0] = 16;   // width
entry[1] = 16;   // height
entry[2] = 0;    // colors 0
entry[3] = 0;    // reserved
entry.writeUInt16LE(1, 4);   // planes
entry.writeUInt16LE(32, 6); // bpp
const imageSize = 40 + 16 * 16 * 4; // BITMAPINFOHEADER + pixels
const imageOffset = 6 + 16;
entry.writeUInt32LE(imageSize, 8);
entry.writeUInt32LE(imageOffset, 12);

// DIB: BITMAPINFOHEADER 40 bytes
const dib = Buffer.alloc(40);
dib.writeUInt32LE(40, 0);   // header size
dib.writeInt32LE(16, 4);    // width
dib.writeInt32LE(32, 8);    // height (doubled for ICO)
dib.writeUInt16LE(1, 12);  // planes
dib.writeUInt16LE(32, 14); // bpp
dib.writeUInt32LE(0, 16);  // compression
dib.writeUInt32LE(16 * 16 * 4, 20); // image size
// rest 0

// 16x16 32bpp image (BGRA, bottom-up): orange #f59e0b
const orange = Buffer.alloc(16 * 16 * 4);
const b = 0x0b, g = 0x9e, r = 0xf5, a = 255;
for (let i = 0; i < 16 * 16 * 4; i += 4) {
  orange[i] = b;
  orange[i + 1] = g;
  orange[i + 2] = r;
  orange[i + 3] = a;
}
// ICO stores image bottom-up, so reverse row order
const rowSize = 16 * 4;
const flipped = Buffer.alloc(orange.length);
for (let y = 15; y >= 0; y--) {
  orange.copy(flipped, (15 - y) * rowSize, y * rowSize, (y + 1) * rowSize);
}

const ico = Buffer.concat([header, entry, dib, flipped]);
const out = path.join(__dirname, "..", "favicon.ico");
fs.writeFileSync(out, ico);
console.log("Wrote", out);
