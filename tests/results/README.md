# Misure locali

Linux, Chafa 1.14.0, Zsh 5.9, tmux 3.4; otto CPU logiche disponibili.
Campioni di otto secondi dopo il riscaldamento, stessa GIF e dimensione 48×8.

| Animazione | Prima | Dopo |
| --- | ---: | ---: |
| CPU media, percentuale di un core | 8,861% | 3,619% |
| Somma RSS massima | 21.104 KiB | 20.364 KiB |
| Thread complessivi | 11 | 2 |
| Processi complessivi | 2 | 2 |

Riduzione CPU osservata: circa 59%. Latenza osservata per digitare ed eseguire
un comando semplice con l'animazione attiva: 57 ms. La memoria RSS diminuisce
di circa il 3,5%; le librerie di Chafa rimangono la parte maggiore del consumo.
Questi risultati descrivono questa macchina, non garantiscono consumi identici
su altre macchine. I JSON salvati contengono i valori originali.

Ottimizzazioni: un thread Chafa, `--work 1`, ANSI compressa con `--optimize 1`,
cache dei fotogrammi decodificati e dei relativi colori, massimo 32 fotogrammi.
Il renderer viene chiuso quando la GIF è disabilitata o non entra nel terminale.
La lettura a blocchi sperimentale è stata scartata perché peggiorava la CPU.

Il test di regressione è stato verificato anche con un controllo negativo:
una copia temporanea con il difetto originale fallisce per colori sul comando,
mentre il codice corretto passa. I test interattivi coprono animazione, input,
comandi lunghi, Unicode, multilinea, job control, Ctrl+C e pulizia all'uscita.

## Controllo ancora non superato

Il test completo delle risorse fallisce sulla visualizzazione dopo aver
ristretto e riallargato il terminale: il renderer riparte, ma alcune righe del
gatto possono finire fuori dalla finestra visibile. CPU e thread durante
l'animazione, CPU a GIF nascosta e regressione dei colori sono stati misurati;
non si considera superata l'intera suite delle risorse.

Il [resoconto del refactor modulare](refactor.md) registra le verifiche più
recenti, incluse installazione e pacchetto, e conferma che questo limite persiste.
