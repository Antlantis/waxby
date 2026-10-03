#!/usr/bin/env python3
"""Spectrograms of WAVs as PNG contact sheets (stdlib only), for checking
sounds by eye when they can't be heard: each panel shows a WAV's level over
time (the strip on top, in dB) above its spectrogram on a log frequency
axis, 60 Hz to 11 kHz, with faint lines at 250 Hz (a phone speaker's floor),
1 kHz and 4 kHz. Every panel shares one time scale, so lengths compare.

    python3 tools/audio/spectro.py OUT.png a.wav b.wav ...        # sounds: 2 s wide panels
    python3 tools/audio/spectro.py --secs 0.5 OUT.png a.wav ...    # ...or panels this many seconds wide
    python3 tools/audio/spectro.py --music OUT.png track.wav       # one long panel, 0.1 s a pixel
"""

import array
import cmath
import math
import os
import struct
import sys
import wave
import zlib

LO_HZ, HI_HZ = 60.0, 11000.0
MARKS = (250.0, 1000.0, 4000.0)
FLOOR_DB = -80.0

# A 3x5 pixel font for the labels.
FONT = {
    'a': '010101111101101', 'b': '110101110101110', 'c': '011100100100011', 'd': '110101101101110',
    'e': '111100110100111', 'f': '111100110100100', 'g': '011100101101011', 'h': '101101111101101',
    'i': '111010010010111', 'j': '001001001101010', 'k': '101101110101101', 'l': '100100100100111',
    'm': '101111111101101', 'n': '110101101101101', 'o': '010101101101010', 'p': '110101110100100',
    'q': '010101101111011', 'r': '110101110101101', 's': '011100010001110', 't': '111010010010010',
    'u': '101101101101111', 'v': '101101101101010', 'w': '101101111111101', 'x': '101101010101101',
    'y': '101101010010010', 'z': '111001010100111', '0': '111101101101111', '1': '010110010010111',
    '2': '110001010100111', '3': '110001010001110', '4': '101101111001001', '5': '111100110001110',
    '6': '111100111101111', '7': '111001010010010', '8': '111101111101111', '9': '111101111001111',
    '_': '000000000000111', '.': '000000000000010', '-': '000000111000000', '#': '101111101111101',
    ' ': '000000000000000', ':': '000010000010000', '%': '101001010100101',
}
MAP = ((0.0, (0, 0, 4)), (0.25, (60, 15, 110)), (0.5, (170, 45, 105)), (0.75, (250, 135, 50)),
       (1.0, (252, 250, 190)))


def read_wav(path):
    with wave.open(path, 'rb') as w:
        rate, n, ch, width = w.getframerate(), w.getnframes(), w.getnchannels(), w.getsampwidth()
        raw = w.readframes(n)
    a = array.array('h')
    a.frombytes(raw)
    if sys.byteorder == 'big':
        a.byteswap()
    if ch == 2:
        a = array.array('h', a[::2])
    return rate, [v / 32768.0 for v in a]


def fft(x):
    """In-place iterative radix-2 FFT of a list of complex numbers."""
    n = len(x)
    j = 0
    for i in range(1, n):
        bit = n >> 1
        while j & bit:
            j ^= bit
            bit >>= 1
        j |= bit
        if i < j:
            x[i], x[j] = x[j], x[i]
    size = 2
    while size <= n:
        w = cmath.exp(-2j * math.pi / size)
        half = size // 2
        tw = [w ** k for k in range(half)]
        for start in range(0, n, size):
            for k in range(half):
                a = x[start + k]
                b = x[start + k + half] * tw[k]
                x[start + k] = a + b
                x[start + k + half] = a - b
        size *= 2
    return x


def colour(v):
    v = max(0.0, min(1.0, v))
    for (x0, c0), (x1, c1) in zip(MAP, MAP[1:]):
        if v <= x1:
            t = (v - x0) / (x1 - x0)
            return tuple(int(a + (b - a) * t) for a, b in zip(c0, c1))
    return MAP[-1][1]


class Canvas:
    def __init__(self, w, h, bg=(18, 16, 24)):
        self.w, self.h = w, h
        self.px = bytearray(bytes(bg) * (w * h))

    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            i = 3 * (y * self.w + x)
            self.px[i:i + 3] = bytes(c)

    def text(self, x, y, s, c=(235, 230, 215), scale=2):
        for ch in s.lower():
            g = FONT.get(ch, FONT[' '])
            for r in range(5):
                for q in range(3):
                    if g[r * 3 + q] == '1':
                        for dy in range(scale):
                            for dx in range(scale):
                                self.set(x + q * scale + dx, y + r * scale + dy, c)
            x += 4 * scale

    def save(self, path):
        rows = b''.join(b'\x00' + bytes(self.px[3 * y * self.w:3 * (y + 1) * self.w]) for y in range(self.h))
        def chunk(tag, data):
            return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff)
        png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', self.w, self.h, 8, 2, 0, 0, 0))
        png += chunk(b'IDAT', zlib.compress(rows, 6)) + chunk(b'IEND', b'')
        with open(path, 'wb') as f:
            f.write(png)


def panel(cv, x0, y0, width, height, samples, rate, secs_per_px, nfft, label, top_db=None):
    """Draw one sound: a level strip (22 px) and its spectrogram under it."""
    strip = 22
    spec_h = height - strip - 14
    cv.text(x0, y0, label)
    y_strip = y0 + 12
    y_spec = y_strip + strip + 2
    hop = secs_per_px * rate
    win = [0.5 - 0.5 * math.cos(2 * math.pi * i / nfft) for i in range(nfft)]
    bins = nfft // 2
    # Row -> fft bin range on a log axis.
    rows = []
    for r in range(spec_h):
        f_hi = LO_HZ * (HI_HZ / LO_HZ) ** (1 - r / spec_h)
        f_lo = LO_HZ * (HI_HZ / LO_HZ) ** (1 - (r + 1) / spec_h)
        b0 = max(1, int(f_lo * nfft / rate))
        b1 = max(b0 + 1, int(math.ceil(f_hi * nfft / rate)))
        rows.append((b0, min(b1, bins)))
    cols = []
    peak_db = -200.0
    n = len(samples)
    for c in range(width):
        centre = int(c * hop)
        if centre >= n:
            cols.append(None)
            continue
        seg = [complex(samples[centre - nfft // 2 + i] * win[i]) if 0 <= centre - nfft // 2 + i < n else 0j
               for i in range(nfft)]
        spec = fft(seg)
        mags = [abs(spec[k]) ** 2 for k in range(bins)]
        col = []
        for b0, b1 in rows:
            e = max(mags[b0:b1]) if b1 > b0 else mags[b0]
            db = 10 * math.log10(e + 1e-20)
            col.append(db)
            peak_db = max(peak_db, db)
        # the level strip: RMS over this pixel's span
        a, b = centre, min(n, centre + max(1, int(hop)))
        rms = math.sqrt(sum(v * v for v in samples[a:b]) / max(1, b - a))
        cols.append((col, 20 * math.log10(rms + 1e-9)))
    top = top_db if top_db is not None else peak_db
    for c, item in enumerate(cols):
        # frequency guide lines
        for r, (b0, b1) in enumerate(rows):
            if item is None:
                cv.set(x0 + c, y_spec + r, (10, 9, 14))
                continue
            v = (item[0][r] - (top + FLOOR_DB)) / -FLOOR_DB
            cv.set(x0 + c, y_spec + r, colour(v))
        if item is not None:
            level = max(0.0, min(1.0, (item[1] + 60.0) / 60.0))
            hgt = int(level * strip)
            for yy in range(hgt):
                cv.set(x0 + c, y_strip + strip - 1 - yy, (120, 190, 150) if item[1] < -2.0 else (230, 80, 80))
    for f in MARKS:
        r = int(spec_h * (1 - math.log(f / LO_HZ) / math.log(HI_HZ / LO_HZ)))
        for c in range(0, width, 3):
            cv.set(x0 + c, y_spec + r, (90, 200, 220))
    # a tick every 0.1 s (long every second)
    for k in range(int(width * secs_per_px / 0.1) + 1):
        cx = x0 + int(k * 0.1 / secs_per_px)
        for yy in range(3 if k % 10 else 7):
            cv.set(cx, y_spec + spec_h + yy, (160, 160, 170))


def main(argv):
    music = argv and argv[0] == '--music'
    if music:
        argv = argv[1:]
    secs = 2.0
    if argv and argv[0] == '--secs':
        secs, argv = float(argv[1]), argv[2:]
    if len(argv) < 2:
        sys.exit(__doc__)
    out, paths = argv[0], argv[1:]
    if music:
        rate, s = read_wav(paths[0])
        width = int(math.ceil(len(s) / rate / 0.1))
        cv = Canvas(width + 16, 300)
        panel(cv, 8, 6, width, 285, s, rate, 0.1, 2048, os.path.basename(paths[0]))
    else:
        cols, pw, ph = 3, 400, 150
        rows = (len(paths) + cols - 1) // cols
        cv = Canvas(cols * (pw + 12) + 8, rows * (ph + 10) + 8)
        for i, p in enumerate(paths):
            rate, s = read_wav(p)
            x = 8 + (i % cols) * (pw + 12)
            y = 8 + (i // cols) * (ph + 10)
            label = '%s %.2fs' % (os.path.splitext(os.path.basename(p))[0], len(s) / rate)
            panel(cv, x, y, pw, ph, s, rate, secs / pw, 512 if secs > 0.8 else 256, label)
    cv.save(out)
    print('wrote', out)


if __name__ == '__main__':
    main(sys.argv[1:])
