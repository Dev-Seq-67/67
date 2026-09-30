# Riprodurre la demo di 67

La demo nel README è una cattura reale di un terminale interattivo durante
l'installazione dal repository APT pubblico. Un contenitore Ubuntu 24.04 parte
senza `67`, Chafa o Zsh. Sono predisposti soltanto curl, certificati HTTPS e sudo.
L'utente `demo` ha sudo senza password **solo nel contenitore di registrazione**.

`record.py` digita i comandi, conferma APT, verifica i codici di uscita, avvia il
pacchetto installato e controlla l'output di `printf` e la chiusura del renderer.
Registra a 12 campioni al secondo con `tmux capture-pane -e`, conservando i
caratteri effettivamente visualizzati, i colori ANSI e la posizione del cursore.
Non inserisce output precostruito e non sostituisce l'animazione con la GIF sorgente.

`render.py` rasterizza queste catture con pyte e Pillow. Aggiunge titoli, una
barra temporale e un movimento della camera a 1,65× intorno allo sprite e al
prompt. Il video completo mantiene i tempi originali della registrazione.
L'anteprima GIF contiene soltanto un estratto della fase con lo zoom.

## Strumenti

Per la sola produzione della demo servono Docker funzionante, tmux, Python 3.12
con `venv`, i font DejaVu in `/usr/share/fonts/truetype/dejavu/`, e le dipendenze
Python elencate in `requirements.txt`. `imageio-ffmpeg` fornisce l'encoder FFmpeg.
Il programma `67` non acquisisce queste dipendenze.

Dalla radice del repository:

```sh
python3 -m venv /tmp/67-demo-tools
/tmp/67-demo-tools/bin/pip install -r tools/demo/requirements.txt
docker build -t 67-readme-demo:local tools/demo
/tmp/67-demo-tools/bin/python tools/demo/record.py
/tmp/67-demo-tools/bin/python tools/demo/render.py
```

Il recorder crea un contenitore e un server tmux dai nomi univoci e li rimuove
nel blocco di pulizia. Non modifica dotfile, shell predefinita o sorgenti APT
dell'host. L'immagine Docker locale rimane disponibile per nuove registrazioni.
L'installazione necessita di accesso alle sorgenti Ubuntu e al repository del
progetto. Il digest dell'immagine base è fissato nel Dockerfile; i pacchetti APT
provengono dalle versioni disponibili al momento della cattura.

## Artefatti

I file generati sono in `docs/demo/`:

| File | Contenuto |
| --- | --- |
| `67-demo.mp4` | Video H.264, 1440 × 900, 12 fps, senza audio, con faststart. |
| `preview.gif` | Estratto animato, 960 × 600, palette condivisa. |
| `poster.png` | Fotogramma dello zoom usato come copertina del player. |
| `captions.vtt` | Didascalie italiane per i capitoli. |
| `terminal.jsonl.gz` | Catture originali con tempo, ANSI e cursore. |
| `recording.json` | Versioni, comandi, codici di uscita, controlli e tempi. |

`index.html` è il player responsive; `banner.svg` è il titolo del README e usa
la pixel art effettiva dell'asset. Non vengono rigenerati dal recorder.

Per produrre una registrazione separata, entrambi gli script accettano una
directory alternativa: `record.py --output /tmp/67-demo` e
`render.py --directory /tmp/67-demo`.

Se cambiano i tempi della cattura, aggiorna i timestamp della tabella nel
README e i pulsanti dei capitoli in `docs/demo/index.html` usando `recording.json`.
Il workflow Pages copia la demo insieme allo snapshot APT già firmato. Il player
sarà in `https://dev-seq-67.github.io/67/demo/`; i file APT conservano gli stessi URL.

## Registrazione pubblicata

Cattura del 30 settembre 2026, Ubuntu 24.04, 94 colonne × 22 righe:
67 1.5.0, Chafa 1.14.0-1.1build1 e Zsh 5.9-6ubuntu2. Durata 74,81 secondi.
Configurazione della sorgente, update e installazione terminano con codice 0.
La prova interattiva stampa `Il prompt funziona.`; all'uscita non resta un
processo Chafa nel contenitore. Le catture originali e i metadati sono inclusi
per consentire di verificare questi passaggi.
