# Design del gatto 6 7

Il gatto mantiene il mantello nero e bianco, gli occhi espressivi e il gesto
alternato delle zampe del riferimento originale. Il nuovo disegno usa la
pixel art dei classici giochi di creature da collezionare: sagoma ampia,
orecchie nette, musetto chiaro, lingua rosa e piccoli riflessi turchesi.

## Test visivo

Le anteprime sono rasterizzazioni dei caratteri e dei colori prodotti realmente
**da Chafa**, con celle monospaziate di 9 × 18 pixel. Non sono il solo disegno
sorgente ingrandito. Il test giudica: riconoscibilità del gatto, due occhi
separati, musetto/lingua leggibili e distinzione tra zampa alta e zampa bassa.

- 2 righe: respinto; il volto e il gesto diventano macchie.
- 4 righe: respinto; gli occhi si fondono e le zampe perdono la forma.
- 6 righe: il gatto si riconosce, ma musetto e occhi restano troppo confusi.
- **8 righe: approvato**; occhi, orecchie, lingua e zampe sono separati.

Il comando usa 48 colonne × 8 righe, preservando il rapporto 3:1 della GIF.
La maggiore altezza è stata autorizzata dopo il confronto visivo.

La cattura del comando eseguito conferma il risultato dopo l'integrazione
nell'editor Zsh. La disposizione attuale mette tutte le otto righe del gatto
sopra il prompt: i comandi iniziano sulla riga successiva e restano sotto il
gatto anche quando vanno a capo. Il pacchetto 1.4.0 è stato estratto e provato in un terminale
isolato: alternanza dei fotogrammi, digitazione, frecce, Unicode, righe multiple,
scorrimento dell'output, comandi lunghi su più righe, Ctrl+C e successivo `67`
passano. Ctrl+C lascia la GIF
nascosta e la shell utilizzabile; `67` la riattiva. Installazione e rimozione
tramite script sono state verificate in una directory temporanea, con controllo
dei contenuti e dei permessi.

[Sprite definitivo nel terminale](preview/palette-eight.png) ·
[Cattura del comando eseguito con Chafa e Zsh](preview/runtime.png) ·
[Confronto a 6 righe](preview/final-6.png) ·
[Confronto a 8 righe](preview/final-8.png) ·
[Seconda posa](preview/second-eight.png) ·
[Confronto su sfondo chiaro](preview/light-eight.png)

## Asset

- `source/67-original.gif`: riferimento originale conservato.
- `source/wide-sheet.png`: sprite sheet generata con lo strumento integrato
  **imagegen**, con due pose disposte verticalmente.
- `source/pose-final-0.png`, `source/pose-final-1.png`: fotogrammi con pixel netti,
  alpha binario e una palette condivisa di 12 colori più trasparenza.
- `source/palette.png`: palette usata per la conversione GIF.
- `../assets/67.gif`: GIF implementata, 144 × 48 pixel, due fotogrammi,
  280 ms per posa, ciclo infinito. Nessuna nuova dipendenza di esecuzione.

Prompt finale usato con imagegen: ridisegnare il gatto nero e bianco come un
adorabile sprite di un RPG di creature anni Novanta; composizione ampia 3:1,
volto frontale semplice, orecchie corte, occhi bianchi grandi con pupille nere
e riflessi ciano, nasino e lingua rosa; due grandi palmi bianchi rivolti verso
l'alto, uno alto e uno basso, che si scambiano tra le due pose; contorno chiaro,
pochi colori piatti, niente testo, niente sfondo, bordi a pixel netti.

ImageMagick è stato usato solo durante la preparazione per dividere la sprite
sheet, normalizzare la palette e assemblare la GIF. Il programma continua a
richiedere solo Chafa, Zsh e le normali utilità di shell.
