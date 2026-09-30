#!/usr/bin/env python3
"""Render genuine ANSI snapshots into a captioned MP4 and an animated preview."""
import argparse
from bisect import bisect_right
from functools import lru_cache
import gzip
import json
from pathlib import Path
import subprocess

import imageio_ffmpeg
from PIL import Image, ImageDraw, ImageFont
import pyte

ROOT = Path(__file__).resolve().parents[2]
WIDTH, HEIGHT, FPS = 1440, 900, 12
CELL_W, CELL_H = 13, 24
BG, INK, MUTED, ACCENT = '#080d17', '#e8edf6', '#92a2b8', '#52e0c6'
MONO = '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf'
SANS = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
BOLD = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
FONT = ImageFont.truetype(MONO, 21)
PALETTE = {'default': INK, 'black': '#000000', 'red': '#cd0000', 'green': '#00cd00',
           'brown': '#cdcd00', 'blue': '#0000ee', 'magenta': '#cd00cd', 'cyan': '#00cdcd',
           'white': '#e5e5e5', 'brightblack': '#7f7f7f', 'brightred': '#ff0000',
           'brightgreen': '#00ff00', 'brightbrown': '#ffff00', 'brightblue': '#5c5cff',
           'brightmagenta': '#ff00ff', 'brightcyan': '#00ffff', 'brightwhite': '#ffffff'}


def color(value, background=False):
    if value == 'default':
        return '#0b1220' if background else INK
    return PALETTE.get(value, '#' + value)


@lru_cache(maxsize=8192)
def tile(data, fg, bg, reverse, bold):
    foreground, background = color(fg), color(bg, True)
    if reverse:
        foreground, background = background, foreground
    image = Image.new('RGB', (CELL_W, CELL_H), background)
    draw = ImageDraw.Draw(image)
    # Paint block glyphs to cell boundaries, matching terminal cell geometry.
    masks = {'▀': (0, 0, 13, 12), '▄': (0, 12, 13, 24), '█': (0, 0, 13, 24),
             '▌': (0, 0, 7, 24), '▐': (7, 0, 13, 24)}
    quarters = {'▖': [2], '▗': [3], '▘': [0], '▙': [0, 2, 3], '▚': [0, 3],
                '▛': [0, 1, 2], '▜': [0, 1, 3], '▝': [1], '▞': [1, 2], '▟': [1, 2, 3]}
    if data in masks:
        x0, y0, x1, y1 = masks[data]
        draw.rectangle((x0, y0, x1 - 1, y1 - 1), fill=foreground)
    elif data in quarters:
        for index in quarters[data]:
            x0, x1 = (0, 7) if index % 2 == 0 else (7, 13)
            y0 = 0 if index < 2 else 12
            draw.rectangle((x0, y0, x1 - 1, y0 + 11), fill=foreground)
    elif data.strip():
        draw.text((0, 0), data, font=FONT, fill=foreground)
    return image


def terminal(snapshot, cols, rows):
    screen = pyte.Screen(cols, rows)
    stream = pyte.Stream(screen)
    stream.feed(snapshot['screen'].replace('\n', '\r\n'))
    image = Image.new('RGB', (cols * CELL_W, rows * CELL_H), '#0b1220')
    for row in range(rows):
        for col, char in screen.buffer[row].items():
            if col >= cols:
                continue
            image.paste(tile(char.data, char.fg, char.bg, char.reverse, char.bold),
                        (col * CELL_W, row * CELL_H))
    x, y = snapshot['cursor']
    if 0 <= x < cols and 0 <= y < rows:
        ImageDraw.Draw(image).rectangle((x * CELL_W, y * CELL_H,
                                        x * CELL_W + 1, (y + 1) * CELL_H - 1), fill=ACCENT)
    return image


def compose(content, t, metadata, event_index, zoom):
    image = Image.new('RGB', (WIDTH, HEIGHT), BG)
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((52, 35, 120, 96), radius=13, fill=ACCENT)
    draw.text((61, 41), '67', font=ImageFont.truetype(BOLD, 38), fill=BG)
    draw.text((139, 42), 'UN GATTO. IL TUO TERMINALE.', font=ImageFont.truetype(BOLD, 21), fill=INK)
    draw.text((140, 74), 'LIVE DEMO  /  INSTALLAZIONE + PROMPT', font=ImageFont.truetype(SANS, 14), fill=MUTED)
    draw.text((52, 118), metadata['chapters'][event_index]['title'],
              font=ImageFont.truetype(BOLD, 34), fill=INK)
    draw.text((52, 166), metadata['chapters'][event_index]['subtitle'],
              font=ImageFont.truetype(SANS, 20), fill=MUTED)
    left = (WIDTH - content.width) // 2
    top = 247
    draw.rounded_rectangle((left - 18, top - 44, left + content.width + 18,
                            top + content.height + 16), radius=15, fill='#0b1220', outline='#233148', width=1)
    for dx, fill in [(0, '#ee727b'), (20, '#e3be65'), (40, '#63c994')]:
        draw.ellipse((left + dx, top - 28, left + dx + 10, top - 18), fill=fill)
    draw.text((left + 72, top - 31), 'demo@67 — Ubuntu 24.04', font=ImageFont.truetype(SANS, 14), fill=MUTED)
    if zoom > 1.02:
        draw.text((left + content.width - 137, top - 31), f'ZOOM {zoom:.1f}×',
                  font=ImageFont.truetype(BOLD, 14), fill=ACCENT)
    image.paste(content, (left, top))
    total = metadata['duration_seconds']
    draw.rounded_rectangle((52, 824, 1388, 829), radius=2, fill='#233148')
    draw.rounded_rectangle((52, 824, 52 + max(2, 1336 * t / total), 829), radius=2, fill=ACCENT)
    for index, label in enumerate(['Sorgente', 'Indici', 'Installa', 'Verifica', 'Avvia', 'Zoom', 'Controlli', 'Fatto']):
        draw.text((52 + index * 152, 850), f'{index + 1:02d} {label}', font=ImageFont.truetype(SANS, 15),
                  fill=ACCENT if index == event_index else MUTED)
    draw.text((1304, 850), f'{int(t) // 60:02d}:{int(t) % 60:02d}', font=ImageFont.truetype(MONO, 17), fill=INK)
    return image


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory', type=Path, default=ROOT / 'docs/demo')
    args = parser.parse_args()
    folder = args.directory
    metadata = json.loads((folder / 'recording.json').read_text())
    with gzip.open(folder / 'terminal.jsonl.gz', 'rt') as file:
        snapshots = [json.loads(line) for line in file]
    times = [s['t'] for s in snapshots]
    event_times = [e['t'] for e in metadata['chapters']]
    zoom_start = next(e['t'] for e in metadata['chapters'] if e['zoom'])
    zoom_end = metadata['chapters'][6]['t']
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    # Silent H.264, even dimensions and faststart for native browser playback.
    with (folder / 'encoding.log').open('w') as log:
        encoder = subprocess.Popen([ffmpeg, '-y', '-f', 'rawvideo', '-vcodec', 'rawvideo',
            '-pix_fmt', 'rgb24', '-s', f'{WIDTH}x{HEIGHT}', '-r', str(FPS), '-i', '-',
            '-an', '-c:v', 'libx264', '-preset', 'fast', '-crf', '21', '-pix_fmt', 'yuv420p',
            '-movflags', '+faststart', str(folder / '67-demo.mp4')], stdin=subprocess.PIPE, stderr=log)
        preview_frames = []
        previous_screen, content = None, None
        try:
            for frame in range(int(metadata['duration_seconds'] * FPS)):
                t = frame / FPS
                snapshot = snapshots[max(0, bisect_right(times, t) - 1)]
                identity = (snapshot['screen'], tuple(snapshot['cursor']))
                if identity != previous_screen:
                    content = terminal(snapshot, metadata['columns'], metadata['rows'])
                    previous_screen = identity
                event_index = max(0, bisect_right(event_times, t) - 1)
                ramp = min(max(0, (t - zoom_start) / 1.25), max(0, (zoom_end - t) / 1.25), 1)
                easing = ramp * ramp * (3 - 2 * ramp)
                zoom = 1 + 0.65 * easing
                crop_w, crop_h = content.width / zoom, content.height / zoom
                target_y = max(0, min(content.height - crop_h,
                                     (snapshot['cursor'][1] - 10) * CELL_H))
                view = content.crop((0, target_y, crop_w, target_y + crop_h)).resize(
                    content.size, Image.Resampling.NEAREST)
                output = compose(view, t, metadata, event_index, zoom)
                encoder.stdin.write(output.tobytes())
                if zoom_start + 2 <= t < zoom_end - 1 and frame % 2 == 0:
                    preview_frames.append(output.resize((960, 600), Image.Resampling.LANCZOS))
                if abs(t - (zoom_start + 8)) < 1 / FPS:
                    output.save(folder / 'poster.png')
                if frame % (FPS * 20) == 0:
                    print(f'Rendered {t:.0f}/{metadata["duration_seconds"]:.0f}s', flush=True)
        finally:
            encoder.stdin.close()
        if encoder.wait() != 0:
            raise RuntimeError((folder / 'encoding.log').read_text())
    # One shared palette avoids flicker between the alternating cat poses.
    palette = preview_frames[0].quantize(colors=128)
    gif_frames = [image.quantize(palette=palette, dither=Image.Dither.NONE) for image in preview_frames]
    gif_frames[0].save(folder / 'preview.gif', save_all=True, append_images=gif_frames[1:],
                       duration=167, loop=0, optimize=True)
    vtt = ['WEBVTT', '']
    for index, event in enumerate(metadata['chapters']):
        end = metadata['chapters'][index + 1]['t'] if index + 1 < len(event_times) else metadata['duration_seconds']
        stamp = lambda s: f'{int(s) // 3600:02d}:{int(s) // 60 % 60:02d}:{s % 60:06.3f}'
        vtt.extend([f'{stamp(event["t"])} --> {stamp(end)}', event['subtitle'], ''])
    (folder / 'captions.vtt').write_text('\n'.join(vtt))
    (folder / 'encoding.log').unlink()
    print('MP4, GIF preview, poster and captions ready.', flush=True)


if __name__ == '__main__':
    main()
