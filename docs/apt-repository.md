# Repository APT di 67

Il repository pubblico del progetto è `https://github.com/Dev-Seq-67/67`.
GitHub Pages serve il contenuto della directory `apt/` all'indirizzo previsto
`https://dev-seq-67.github.io/67/`. L'indirizzo diventa disponibile dopo
l'attivazione di Pages e un deployment riuscito.

## Installazione per gli utenti

Una sola volta, scarica lo script e configura la sorgente:

```sh
curl -fsSL https://dev-seq-67.github.io/67/configure-apt.sh -o /tmp/67-configure-apt.sh
sudo sh /tmp/67-configure-apt.sh https://dev-seq-67.github.io/67
sudo apt update
```

Poi installa con il comando richiesto:

```sh
sudo apt install 67
```

Lo script richiede `curl`, usa HTTPS, verifica l'hash della chiave pubblica e
scrive soltanto `/etc/apt/keyrings/67-archive-keyring.gpg` e
`/etc/apt/sources.list.d/67.sources`. La chiave viene usata esclusivamente per
questa sorgente tramite `Signed-By`. Non esegue l'installazione del programma.
APT installa Chafa e Zsh usando le altre sorgenti già configurate.
Per gli aggiornamenti bastano `sudo apt update` e `sudo apt upgrade`.

Per rimuovere programma e sorgente:

```sh
sudo apt purge 67
sudo rm /etc/apt/sources.list.d/67.sources /etc/apt/keyrings/67-archive-keyring.gpg
sudo apt update
```

## Preparazione e aggiornamenti del manutentore

Servono `gnupg`, `apt-utils` e gli strumenti già usati per il pacchetto.
La chiave di firma vive fuori dal progetto, in
`${XDG_STATE_HOME:-$HOME/.local/state}/67-apt/gnupg`, oppure nel percorso assoluto
indicato da `APT_SIGNING_HOME`. `init-key.sh` crea una chiave Ed25519 dedicata,
valida per due anni, senza passphrase per consentire la firma automatica;
le directory e i file privati sono protetti dai permessi del filesystem.
Conserva un backup privato di questa directory, incluso il certificato di revoca.

```sh
./packaging/apt/init-key.sh
./packaging/apt/prepare-publication.sh
```

La seconda operazione costruisce il `.deb`, genera gli indici, firma `Release`
in entrambe le forme `InRelease` e `Release.gpg`, esporta esclusivamente la
chiave pubblica e verifica il risultato con APT isolato. `dist/apt/` è la
build temporanea; `apt/` contiene i file pubblici da includere nel commit.
Il workflow `.github/workflows/publish-apt.yml` li verifica e pubblica su Pages
quando cambia `apt/` su `main`. Per attivarlo, in Settings → Pages scegli
**GitHub Actions** come sorgente di pubblicazione.

Per una nuova versione aggiorna `packaging/control` e gli esempi nel README,
esegui `prepare-publication.sh` e pubblica il commit su `main`. Il workflow
pubblica quanto già firmato: non conserva la chiave privata su GitHub e non
ricostruisce automaticamente il pacchetto da una modifica dei soli sorgenti.
La firma di un aggiornamento deve usare la stessa chiave; una rotazione richiede
anche la distribuzione della nuova chiave ai client. Prima della scadenza,
estendi la validità con GPG e fai rieseguire agli utenti lo script di configurazione.

## Verifica senza modificare il sistema

```sh
./tests/apt-repository.sh
```

Il test usa sorgenti, stato e cache di APT in una directory temporanea. Verifica
firma, risoluzione del nome `67`, download, simulazione di installazione e rifiuto
di un pacchetto o di metadati alterati. Non installa nulla e non modifica le
sorgenti di sistema. Per testare la configurazione dei file puoi usare `DESTDIR`
con lo script generato. La compatibilità completa delle varie release di
Debian/Ubuntu va verificata separatamente dal download del pacchetto.

Riferimenti: [sorgenti APT e Signed-By](https://manpages.debian.org/testing/apt/sources.list.5.en.html),
[repository di terze parti](https://wiki.debian.org/DebianRepository/UseThirdParty),
[workflow GitHub Pages](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages).
