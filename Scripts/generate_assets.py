#!/usr/bin/env python3
import os
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICON_DIR = os.path.join(ROOT, "Sources", "Assets.xcassets", "AppIcon.appiconset")
SIZES = [20, 29, 40, 58, 60, 76, 80, 87, 120, 152, 167, 180, 1024]


def clamp(value):
    return max(0, min(255, int(value)))


def put(px, x, y, color):
    h = len(px)
    w = len(px[0])
    if 0 <= x < w and 0 <= y < h:
        px[y][x] = color


def rect(px, x0, y0, x1, y1, color):
    h = len(px)
    w = len(px[0])
    for y in range(max(0, y0), min(h, y1)):
        row = px[y]
        for x in range(max(0, x0), min(w, x1)):
            row[x] = color


def circle(px, cx, cy, r, color):
    r2 = r * r
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - r, cx + r + 1):
            if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r2:
                put(px, x, y, color)


def line(px, x0, y0, x1, y1, thickness, color):
    steps = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(steps + 1):
        t = i / steps
        x = round(x0 + (x1 - x0) * t)
        y = round(y0 + (y1 - y0) * t)
        circle(px, x, y, thickness, color)


def triangle(px, p1, p2, p3, color):
    points = sorted([p1, p2, p3], key=lambda p: p[1])
    (x1, y1), (x2, y2), (x3, y3) = points

    def edge(xa, ya, xb, yb, y):
        if yb == ya:
            return xa
        return xa + (xb - xa) * ((y - ya) / (yb - ya))

    for y in range(y1, y3 + 1):
        if y < y2:
            xa = edge(x1, y1, x2, y2, y)
            xb = edge(x1, y1, x3, y3, y)
        else:
            xa = edge(x2, y2, x3, y3, y)
            xb = edge(x1, y1, x3, y3, y)
        if xa > xb:
            xa, xb = xb, xa
        rect(px, int(xa), y, int(xb) + 1, y + 1, color)


def rounded_mask(size, radius, x, y):
    if x < radius and y < radius:
        return (x - radius) ** 2 + (y - radius) ** 2 <= radius ** 2
    if x >= size - radius and y < radius:
        return (x - (size - radius - 1)) ** 2 + (y - radius) ** 2 <= radius ** 2
    if x < radius and y >= size - radius:
        return (x - radius) ** 2 + (y - (size - radius - 1)) ** 2 <= radius ** 2
    if x >= size - radius and y >= size - radius:
        return (x - (size - radius - 1)) ** 2 + (y - (size - radius - 1)) ** 2 <= radius ** 2
    return True


def make_icon(size):
    px = []
    for y in range(size):
        row = []
        for x in range(size):
            fade = y / max(1, size - 1)
            red = clamp(4 + 18 * fade)
            row.append((red, 3, 5))
        px.append(row)

    inset = max(2, size // 14)
    radius = max(4, size // 6)
    for y in range(size):
        for x in range(size):
            if x < inset or y < inset or x >= size - inset or y >= size - inset or not rounded_mask(size, radius, x, y):
                px[y][x] = (0, 0, 0)

    red = (232, 4, 20)
    white = (255, 255, 255)
    dark = (28, 0, 2)

    rect(px, int(size * 0.28), int(size * 0.2), int(size * 0.43), int(size * 0.76), red)
    line(px, int(size * 0.42), int(size * 0.48), int(size * 0.72), int(size * 0.2), max(2, size // 18), red)
    line(px, int(size * 0.42), int(size * 0.5), int(size * 0.74), int(size * 0.76), max(2, size // 18), red)
    triangle(px, (int(size * 0.45), int(size * 0.4)), (int(size * 0.45), int(size * 0.6)), (int(size * 0.62), int(size * 0.5)), white)
    line(px, int(size * 0.28), int(size * 0.78), int(size * 0.72), int(size * 0.78), max(1, size // 38), dark)
    return px


def png_bytes(px):
    h = len(px)
    w = len(px[0])
    raw = bytearray()
    for row in px:
        raw.append(0)
        for r, g, b in row:
            raw.extend([r, g, b])

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")


def main():
    os.makedirs(ICON_DIR, exist_ok=True)
    for size in SIZES:
        path = os.path.join(ICON_DIR, f"icon-{size}.png")
        with open(path, "wb") as handle:
            handle.write(png_bytes(make_icon(size)))
    print(f"Generated {len(SIZES)} app icon files in {ICON_DIR}")


if __name__ == "__main__":
    main()
