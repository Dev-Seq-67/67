#!/usr/bin/env python3
"""Record real tmux frames from an APT install in a disposable container."""
import argparse
import gzip
import json
import os
from pathlib import Path
import re
import subprocess
import threading
import time

ROOT = Path(__file__).resolve().parents[2]
FPS = 12
COLS, ROWS = 94, 22


def run(*args, check=True):
    return subprocess.run(args, text=True, capture_output=True, check=check)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'docs/demo')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    container = f'67-demo-{os.getpid()}'
    socket = container
    events, commands = [], []
    stop = threading.Event()
    capture_errors = []
    started = time.monotonic()

    def tmux(*parts):
        return run('tmux', '-L', socket, *parts).stdout

    def docker(*parts, check=True):
        return run('docker', 'exec', container, *parts, check=check)

    def capture():
        with gzip.open(args.output / 'terminal.jsonl.gz', 'wt', encoding='utf-8') as stream:
            while not stop.is_set():
                tick = time.monotonic()
                try:
                    screen = tmux('capture-pane', '-p', '-e', '-t', 'demo')
                    cursor = tmux('display-message', '-p', '-t', 'demo', '#{cursor_x} #{cursor_y}')
                    stream.write(json.dumps({'t': tick - started, 'screen': screen,
                                             'cursor': [int(n) for n in cursor.split()]}) + '\n')
                except Exception as error:
                    capture_errors.append(str(error))
                    stop.set()
                stop.wait(max(0, 1 / FPS - (time.monotonic() - tick)))

    def chapter(title, subtitle, zoom=False):
        events.append({'t': time.monotonic() - started, 'title': title,
                       'subtitle': subtitle, 'zoom': zoom})
        print(title, flush=True)

    def type_text(text, delay=0.022):
        for char in text:
            tmux('send-keys', '-l', '-t', 'demo', char)
            time.sleep(delay)

    def command(text, hold=1.5, confirm=False):
        docker('rm', '-f', '/tmp/67-demo-status')
        type_text(text)
        time.sleep(0.8)
        tmux('send-keys', '-t', 'demo', 'Enter')
        deadline = time.monotonic() + 180
        confirmed = False
        while time.monotonic() < deadline:
            status = docker('cat', '/tmp/67-demo-status', check=False)
            if status.returncode == 0:
                code = int(status.stdout)
                commands.append({'command': text, 'exit_code': code})
                if code:
                    raise RuntimeError(f'{text}: exited {code}')
                time.sleep(hold)
                return
            if confirm and not confirmed and '[Y/n]' in tmux('capture-pane', '-p', '-t', 'demo'):
                time.sleep(1)
                type_text('y', 0.1)
                tmux('send-keys', '-t', 'demo', 'Enter')
                confirmed = True
            time.sleep(0.12)
        raise RuntimeError(f'Timeout executing {text}')

    thread = None
    try:
        run('docker', 'run', '-d', '--name', container, '--hostname', '67', '67-readme-demo:local')
        # The host's dotfiles, default shell and APT configuration are untouched.
        absent = docker('dpkg-query', '-W', '-f=${db:Status-Status}', '67', check=False)
        assert absent.returncode != 0, 'Start with a clean container without 67'
        tmux('-f', '/dev/null', 'new-session', '-d', '-s', 'demo', '-x', str(COLS), '-y', str(ROWS),
             'docker', 'exec', '-it', '-u', 'demo', '-w', '/home/demo', container,
             'env', 'TERM=xterm-256color', 'LANG=C.UTF-8',
             'PS1=\\[\\e[38;2;82;224;198m\\]demo@67:~$ \\[\\e[0m\\]',
             'PROMPT_COMMAND=printf "%s" "$?" > /tmp/67-demo-status',
             'bash', '--noprofile', '--norc')
        time.sleep(0.5)
        started = time.monotonic()
        chapter('01  Una sorgente, una sola volta', 'Ubuntu 24.04 · installazione reale in un contenitore pulito')
        thread = threading.Thread(target=capture, daemon=True)
        thread.start()
        time.sleep(2)
        command('curl -fsSL https://dev-seq-67.github.io/67/configure-apt.sh -o /tmp/67-configure-apt.sh')
        command('sudo sh /tmp/67-configure-apt.sh https://dev-seq-67.github.io/67', hold=2)
        chapter('02  Aggiorna gli indici', 'APT legge e verifica la sorgente firmata del progetto')
        command('sudo apt update', hold=2)
        chapter('03  Installa con APT', 'sudo apt install 67 · Chafa e Zsh arrivano come dipendenze')
        command('sudo apt install 67', hold=3, confirm=True)
        chapter('04  Controlla il risultato', 'Pacchetto installato, comando disponibile nel PATH')
        command("dpkg-query -W 67 chafa zsh", hold=2)
        command('command -v 67', hold=2)
        command('67 --help', hold=2)
        versions = docker('dpkg-query', '-W', '-f=${Package} ${Version}\n', '67', 'chafa', 'zsh').stdout
        chapter('05  Digita 67', 'Il gatto si anima sopra il prompt · la riga dei comandi resta libera')
        command('clear', hold=0.5)
        type_text('67', 0.15)
        time.sleep(1)
        tmux('send-keys', '-t', 'demo', 'Enter')
        time.sleep(3)
        chapter('06  Guarda da vicino', 'Zoom sul rendering reale di Chafa e sull’input di Zsh', zoom=True)
        time.sleep(5)
        type_text("printf 'Il prompt funziona.\\n'", 0.07)
        time.sleep(2)
        tmux('send-keys', '-t', 'demo', 'Enter')
        time.sleep(3)
        visible = tmux('capture-pane', '-p', '-S', '-100', '-t', 'demo')
        assert re.search(r'^Il prompt funziona\.$', visible, re.M), 'The command must actually run'
        chapter('07  Stop, riparti, esci', '67 --stop nasconde la GIF · 67 la riattiva · exit torna alla shell')
        type_text('67 --stop', 0.09)
        tmux('send-keys', '-t', 'demo', 'Enter')
        time.sleep(3)
        type_text('67', 0.15)
        tmux('send-keys', '-t', 'demo', 'Enter')
        time.sleep(4)
        type_text('exit', 0.13)
        tmux('send-keys', '-t', 'demo', 'Enter')
        time.sleep(2)
        renderer = docker('pgrep', '-x', 'chafa', check=False)
        assert renderer.returncode == 1, 'The renderer must exit with the private shell'
        chapter('08  Fatto', 'Installazione verificata · animazione reale · shell originale ripristinata')
        time.sleep(2)
        stop.set()
        thread.join()
        if capture_errors:
            raise RuntimeError(capture_errors)
        metadata = {'recorded_at_utc': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
                    'environment': 'Ubuntu 24.04, disposable Docker container',
                    'columns': COLS, 'rows': ROWS, 'capture_fps': FPS,
                    'versions': versions.splitlines(), 'commands': commands, 'chapters': events,
                    'duration_seconds': round(time.monotonic() - started, 2),
                    'verified': {'fresh_install': True, 'typed_command_output': True,
                                 'renderer_cleanup': True},
                    'notes': 'Actual terminal snapshots; titles and camera zoom added in post-production. '
                             'No command output fabricated. sudo requires no password only in this container.'}
        (args.output / 'recording.json').write_text(json.dumps(metadata, indent=2, ensure_ascii=False) + '\n')
    finally:
        stop.set()
        if thread:
            thread.join(timeout=3)
        run('tmux', '-L', socket, 'kill-server', check=False)
        run('docker', 'rm', '-f', container, check=False)


if __name__ == '__main__':
    main()
