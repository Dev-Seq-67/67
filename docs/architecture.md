# Architettura di 67

67 apre una sessione Zsh temporanea con una GIF sopra la riga dei comandi.
Il launcher POSIX non disegna: trova gli asset rispetto al proprio percorso,
verifica le dipendenze e crea una `.zshrc` temporanea che carica `prompt.zsh`.
`ZDOTDIR` si applica solo alla sessione figlia; il launcher rimuove la directory
quando Zsh termina. I file di configurazione dell'utente restano intatti.

## Percorso di lettura

1. `src/67`: argomenti, dipendenze, percorsi e sessione privata.
2. `src/prompt.zsh`: configurazione comune e ordine di caricamento dei moduli.
3. `src/prompt/editor.zsh`: eventi dell'editor e visibilità della GIF.
4. `src/prompt/renderer.zsh`: processo Chafa e lettura asincrona.
5. `src/prompt/frames.zsh`: assemblaggio, cache e offset dei colori.
6. `src/prompt/ansi.zsh`: conversione della singola riga ANSI.

I moduli condividono la sessione Zsh, senza sottoshell aggiuntive. Vengono
caricati relativamente a `prompt.zsh`, quindi funzionano sia nel repository
sia nelle installazioni sotto `/usr/local` e `/usr`, da qualsiasi directory.
`editor.zsh` si carica per ultimo perché registra i widget e i gestori dei segnali.

## Flusso dei fotogrammi

`_67_redraw` avvia Chafa solo quando la GIF è abilitata e il terminale ha spazio
per 48 colonne e 8 righe più prompt e input. Il processo sostituito scrive prima
il proprio PID, poi esegue Chafa; il PID non viene letto da `$!`, che appartiene
all'ultimo processo in background dell'utente.

ZLE osserva il descrittore con `zle -F -w`. Ogni callback legge una riga;
quando `_67_pending` contiene otto righe, `_67_publish_frame` costruisce la
chiave della cache dall'intero fotogramma ANSI. Su un miss, `_67_decode_line`
produce `REPLY` (testo) e `reply` (intervalli di colore relativi alla riga).
I colori attraversano le righe tramite variabili locali dinamiche di Zsh,
inizializzate per ciascun fotogramma. Il decoder gestisce il sottoinsieme SGR
truecolor usato da Chafa, non un emulatore ANSI generale.

La cache contiene il testo completo con newline e gli intervalli riferiti a
`PREDISPLAY`, indicati dal prefisso `P`. A 32 elementi si svuotano insieme le
due mappe. Gli offset contano caratteri Zsh con `multibyte` attivo, non byte.
La lunghezza di `BUFFER` non influisce su questi offset.

Il fotogramma pronto passa a `_67_redraw`, che combina sprite e prompt in
`PREDISPLAY` e imposta `region_highlight`; `zle -R` aggiorna il terminale.
La digitazione, la cronologia, il completamento e il cursore restano gestiti
da ZLE. Nessun glifo della GIF viene inserito in `BUFFER`.

## Stato e ciclo di vita

| Stato | Proprietario | Significato |
| --- | --- | --- |
| `_67_width`, `_67_height`, `_67_prompt`, `_67_prompt2` | `prompt.zsh` | Dimensioni e testo dei prompt. |
| `_67_enabled` | `editor.zsh` | La GIF è richiesta dall'utente; può essere temporaneamente nascosta per mancanza di spazio. |
| `_67_fd`, `_67_pid` | `renderer.zsh` | Descrittore osservato e PID di Chafa; `-1` e `0` significano renderer fermo. |
| `_67_pending` | `frames.zsh`, alimentato dal renderer | Righe del fotogramma incompleto; eliminate alla chiusura. |
| `_67_sprite`, `_67_highlights`, mappe `_67_cached_*` | `frames.zsh` | Ultimo fotogramma e cache, conservati tra i comandi. |
| `PREDISPLAY`, `region_highlight` | `editor.zsh` | Testo e colori visibili; separati dall'input. |

Quando una riga viene accettata, `_67_finish` elimina prima i colori e poi il
display; soltanto dopo chiude il renderer. Senza questo ordine i colori dello
sprite possono finire sul comando accettato. `_67_stop_renderer` rimuove il
callback, invia TERM solo al PID posseduto, drena l'output e chiude il
descrittore. Non usa `wait` per la sostituzione di processo né tocca i job
in background dell'utente. L'ultimo fotogramma resta disponibile al prompt successivo.

`67 --stop` e Ctrl+C disabilitano l'animazione; `67` la riabilita. Un errore o EOF
dal renderer disabilita la GIF e ripulisce il display. `precmd` riconosce anche
lo stato 130 di un comando interrotto in primo piano. `TRAPEXIT` chiude il renderer.

SIGWINCH accoda il widget `_67_resize` tramite una sequenza privata: non
rimuove descrittori osservati dentro il trap. Il widget legge le dimensioni
reali con `stty`, perché Zsh può ricevere il segnale prima di aggiornare
`COLUMNS` e `LINES`, e ridisegna mantenendo il testo digitato.
Il ritorno da una finestra stretta presenta ancora il difetto di origine del
display descritto in [tests/results/README.md](../tests/results/README.md).

## Distribuzione e verifiche

`install.sh` e `packaging/build-deb.sh` distribuiscono `prompt.zsh` e tutti i
moduli adiacenti in `prompt/`. `uninstall.sh` elimina solo i file posseduti;
se le directory contengono altri file, `rmdir` li conserva e segnala l'errore.
Una nuova dipendenza tra moduli deve rispettare l'ordine di caricamento; un
nuovo modulo va aggiunto anche alla verifica del launcher e alla rimozione.

I test interattivi usano tmux soltanto come terminale isolato, non come parte
del programma. `regression.sh` copia l'intera struttura e rimuove deliberatamente
la pulizia dei colori in `_67_finish` per verificare il controllo negativo.
`integration.sh` verifica input, display e ciclo di vita; `resources.sh` misura
processi, thread, memoria e CPU e include il controllo di ridimensionamento.
Vedi [tests/README.md](../tests/README.md) per comandi, condizioni e limiti.
