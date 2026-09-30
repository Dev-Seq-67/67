# 67

Un piccolo comando per Linux che mostra `assets/67.gif` animata **sopra il
prompt**, lasciando la riga successiva libera per i comandi. Il gatto è uno sprite in pixel art:
orecchie nette, occhi grandi, lingua rosa e zampe che alternano il gesto “6 7”.
La GIF conserva le proporzioni e resta separata dal testo mentre digiti.

Il confronto visivo ha fissato la dimensione a **48 colonne × 8 righe**:
a due righe occhi e mani non erano riconoscibili. I fotogrammi hanno una palette
limitata e bordi trasparenti. Vedi [il confronto e le anteprime](design/README.md).

[Chafa](https://hpjansson.org/chafa/) genera i fotogrammi; l'editor di
[Zsh](https://zsh.sourceforge.io/Doc/Release/Zsh-Line-Editor.html) gestisce GIF e
input insieme. La GIF è solo visuale: non entra mai nel comando eseguito.

## Installazione

Il repository APT del progetto usa GitHub Pages. Dopo la
[configurazione iniziale della sorgente](docs/apt-repository.md), installa con:

```sh
sudo apt install 67
```

Gli aggiornamenti arrivano tramite i normali comandi APT. La configurazione
iniziale è necessaria: il pacchetto non viene distribuito dai repository ufficiali.

### Installazione locale

Su Debian/Ubuntu, dalla directory del progetto:

```sh
sudo apt install chafa zsh
sudo ./install.sh
```

Installa `/usr/local/bin/67`, `/usr/local/share/67/67.gif` e
`/usr/local/share/67/prompt.zsh` e i moduli in `/usr/local/share/67/prompt/`.
`/usr/local/bin` deve essere nel `PATH`.

In alternativa, installa il pacchetto Debian/Ubuntu con le sue dipendenze:

```sh
sudo apt install ./dist/67_1.5.0_all.deb
```

Il pacchetto usa `/usr/bin/67` e `/usr/share/67/`.
Scegli un solo metodo. Per ricostruire il `.deb` serve `dpkg-deb`:

```sh
./packaging/build-deb.sh
```

## Utilizzo

Da qualsiasi directory, in un terminale interattivo:

```sh
67
```

Apre una **shell Zsh temporanea** nella directory corrente. La GIF occupa otto
righe; il prompt va automaticamente a capo sotto il gatto. I comandi successivi
si scrivono su questa riga separata, anche quando il testo va a capo. Puoi usare
normalmente frecce, cancellazione, cronologia e completamento.
In finestre più strette di 48 colonne o più basse di 10 righe la GIF viene
nascosta, lasciando utilizzabile la shell; ricompare quando allarghi la finestra.
Al ritorno della GIF lo schermo viene ridisegnato, conservando il testo digitato.
Durante l'esecuzione dei comandi lascia spazio al loro output; ricompare al prompt.

Nella shell temporanea:

```sh
67 --stop  # nasconde la GIF
67         # la riattiva
exit       # torna alla shell originale
```

**Ctrl+C** fa scomparire subito la GIF e annulla la riga corrente; il terminale
resta utilizzabile. Digita **`67`** per mostrarla nuovamente. Durante l'esecuzione
di un comando Ctrl+C interrompe quel comando e lascia la GIF nascosta fino a `67`.
La shell predefinita e i file di configurazione dell'utente non vengono modificati.
Non serve tmux e non vengono creati pannelli separati.

Per provarlo senza installazione: `./src/67`.

## Disinstallazione

Esci prima dalla shell temporanea con `exit`. Per l'installazione tramite script:

```sh
sudo ./uninstall.sh
```

Per il pacchetto:

```sh
sudo apt purge 67
```

## Dipendenze e verifica

Chafa ≥ 1.12, Zsh ≥ 5.8, shell POSIX e normali utilità Linux. Nessun framework o
Python. Zsh gestisce l'animazione con il proprio editor, evitando aggiornamenti
in background che interferiscano con il cursore della shell.

Il rendering usa un solo thread e la modalità economica di Chafa. I fotogrammi
già decodificati vengono riutilizzati con una cache limitata a 32 elementi;
il renderer si ferma con Ctrl+C e quando la finestra è troppo piccola.

Test riproducibili (solo per sviluppo: `tmux` e `perl`):

```sh
./tests/regression.sh
./tests/integration.sh
./tests/resources.sh
```

Vedi [metodo, limiti e risultati dei test](tests/README.md).

## Struttura del codice

`src/67` risolve i percorsi e apre la sessione privata; `src/prompt.zsh`
configura Zsh e carica quattro moduli da `src/prompt/`:

| Modulo | Responsabilità |
| --- | --- |
| `ansi.zsh` | Converte le sequenze ANSI in caratteri e intervalli di colore. |
| `frames.zsh` | Assembla i fotogrammi e mantiene la cache limitata. |
| `renderer.zsh` | Avvia e chiude Chafa, legge le righe dal suo descrittore. |
| `editor.zsh` | Gestisce prompt, widget ZLE, segnali e comando `67`. |

Per seguire flusso dei dati, stato e vincoli di manutenzione, vedi
[l'architettura](docs/architecture.md). Le istruzioni operative per gli agenti
sono in [AGENTS.md](AGENTS.md).

Per verificare installazione e rimozione senza modificare il sistema:

```sh
stage=$(mktemp -d)
DESTDIR="$stage" ./install.sh
(cd /tmp && PATH="$stage/usr/local/bin:$PATH" 67)
# Nella shell temporanea: prova altri comandi, poi digita exit.
DESTDIR="$stage" ./uninstall.sh
```

Licenza MIT: vedi [LICENSE](LICENSE).
