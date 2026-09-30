# Verifica del refactor modulare

30 settembre 2026, Linux 6.8.0-138-generic, Chafa 1.14.0, Zsh 5.9,
tmux 3.4, otto CPU logiche. Nessuna nuova dipendenza di esecuzione.

## Controlli superati

- Sintassi POSIX di launcher, installazione, disinstallazione, build e runner
  dei test; sintassi Zsh dell'entry point e di ciascun modulo; sintassi Perl
  dei tre helper.
- `./tests/regression.sh`, incluso il controllo negativo nella copia dei moduli.
- `./tests/integration.sh` sul sorgente, sull'installazione con `DESTDIR` e sul
  pacchetto Debian estratto: animazione, input, colori del comando accettato,
  Unicode, multilinea, scorrimento, Ctrl+C, stop/riavvio, job utente, `$!` e pulizia.
  Tutte e tre le sessioni avviano il programma da `/tmp`.
- Installazione e disinstallazione in staging, contenuto dei moduli e permessi
  del pacchetto (launcher 755, moduli 644). Verificati anche un `DESTDIR` con
  spazi, il rifiuto di percorsi relativi e la conservazione di file estranei
  durante la rimozione. Nessuna installazione di sistema eseguita.
- Build di `dist/67_1.5.0_all.deb`, con quattro moduli e guida all'architettura.
- Confronto del decoder originale con quello rinominato: stesso testo,
  intervalli e stato dei colori su reset SGR, truecolor, inversione, controlli
  del cursore, Unicode e righe realmente prodotte da Chafa. Il confronto è
  stato eseguito con uno script temporaneo, senza dipendenze aggiuntive.

## Suite risorse: esito parziale

`./tests/resources.sh refactor-final` usa fasi di otto secondi e i limiti
predefiniti, dopo il riscaldamento. Eseguito dopo la conclusione dei test
interattivi. I risultati grezzi sono [animated](refactor-animated.json) e
[narrow](refactor-narrow.json).

| Controllo | Risultato |
| --- | ---: |
| CPU animazione, percentuale di un core | 3,868% |
| Somma RSS massima durante l'animazione | 20.424 KiB |
| Processi / thread durante l'animazione | 2 / 2 |
| Latenza di input ed esecuzione | 57 ms |
| CPU in finestra stretta | 0% |
| Processi / thread in finestra stretta | 1 / 1 |

La suite fallisce al ripristino della finestra con `No room above command`.
Lo stesso errore è stato riprodotto sul codice originale prima delle modifiche;
resta il difetto descritto in [README.md](README.md). Le fasi successive del
runner (misura dopo Ctrl+C e cinque cicli di riavvio con misura dei descrittori)
non vengono raggiunte, quindi **la suite completa non è superata**.
Ctrl+C e la pulizia del processo sono invece verificati dai test interattivi.
Questi campioni descrivono la macchina e il carico della misura, senza garantire
consumi identici altrove.
