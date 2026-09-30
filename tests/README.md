# Test di 67

Servono Linux con `/proc`, Chafa, Zsh, tmux e Perl con i moduli standard.
tmux e Perl sono dipendenze dei test, non dell'applicazione. Le sessioni tmux
sono isolate e vengono chiuse automaticamente, anche se un controllo fallisce.
Gli script stampano la directory temporanea contenente catture e misure.

```sh
./tests/regression.sh
./tests/integration.sh
./tests/resources.sh
```

Per il repository APT già generato: `./tests/apt-repository.sh`. Richiede APT
e usa directory temporanee per sorgenti, stato e cache: verifica firma,
download, simulazione di installazione e rifiuto di file alterati senza
modificare il sistema. Vedi [la guida APT](../docs/apt-repository.md).

`regression.sh` reintroduce il difetto della review in una copia temporanea:
il test deve rilevare i colori dello sprite sul comando accettato. Poi verifica
il codice corretto. Le catture conservano le sequenze ANSI; non basta che il
testo del comando esista, i suoi caratteri devono essere privi di colori RGB
e inversioni provenienti dallo sprite.
La copia temporanea include `src/prompt/`; il controllo negativo rimuove
`region_highlight=()` da `_67_finish` in `src/prompt/editor.zsh`.

`integration.sh` controlla le otto righe del gatto sopra l'input, i fotogrammi
animati, digitazione, frecce, comandi lunghi, Unicode, input multilinea,
output che scorre, Ctrl+C, stop/riavvio, processi in background e `$!`.
All'uscita verifica la rimozione del renderer e della configurazione temporanea.

`resources.sh` misura per otto secondi ciascuno animazione, finestra stretta
e stato dopo Ctrl+C. Somma CPU e RSS della shell Zsh e dei suoi discendenti;
esclude la shell originale e tmux. La CPU include i figli già terminati.
RSS è la somma dei resident set e può contare più volte memoria condivisa:
non è una misura della memoria fisica esclusiva. Le misure non rappresentano
il picco iniziale di avvio, perché precedute da un secondo di riscaldamento.

Controlli sulle risorse:

- Animazione: CPU media ≤ 5% di un core, RSS ≤ 64 MiB, massimo due processi
  e due thread complessivi. CPU e RSS sono limiti configurabili, non promesse
  valide su ogni macchina.
- Finestra stretta e Ctrl+C: un solo processo, CPU media ≤ 1% di un core.
- La GIF ricompare quando la finestra viene riallargata.
- Input ed esecuzione di un comando semplice in meno di un secondo.
- Cinque cicli stop/riavvio non aumentano i descrittori; la crescita RSS deve
  restare entro 2 MiB. Nessun renderer o directory temporanea dopo l'uscita.

Esempio di una misura più lunga o con limiti adatti a una macchina lenta:

```sh
SECONDS_PER_PHASE=20 MAX_CPU_PERCENT=10 ./tests/resources.sh
```

Per testare un'installazione temporanea o il pacchetto estratto:

```sh
stage=$(mktemp -d)
dpkg-deb -x dist/67_1.5.0_all.deb "$stage"
PROGRAM="$stage/usr/bin/67" ./tests/integration.sh
PROGRAM="$stage/usr/bin/67" ./tests/resources.sh
```

Le misure locali prima/dopo e le versioni degli strumenti sono riportate
in [results/README.md](results/README.md). I valori possono variare con CPU,
librerie, versione di Chafa e carico del sistema.
