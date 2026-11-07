# Talk2Mac

Dictée vocale pour macOS, pensée pour fonctionner **dans une VDI** (Windows App / RDP) :
le texte est tapé via de vrais événements clavier, sans dépendre du presse-papiers partagé.

Maintiens la touche push-to-talk (⌘ droite par défaut), parle, relâche : l'audio est
transcrit en local avec [whisper.cpp](https://github.com/ggml-org/whisper.cpp), nettoyé
(« euh » retirés, dictionnaire perso), puis tapé dans l'application active.

## Prérequis
- macOS 13+, Command Line Tools (`xcode-select --install`), `cmake`
- Un modèle Whisper, par ex. `ggml-small-q5_1.bin`

## Installation
```sh
git clone --depth 1 https://github.com/ggml-org/whisper.cpp vendor/whisper.cpp
cmake -S vendor/whisper.cpp -B vendor/whisper.cpp/build -DBUILD_SHARED_LIBS=OFF -DGGML_METAL=OFF  # sur Mac Apple Silicon, retire GGML_METAL=OFF
cmake --build vendor/whisper.cpp/build -j4 --target whisper-cli

mkdir -p "$HOME/Library/Application Support/Talk2Mac"
curl -L -o "$HOME/Library/Application Support/Talk2Mac/ggml-small-q5_1.bin" \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small-q5_1.bin

./build.sh && open build/Talk2Mac.app
```
Au premier lancement, accorde **Micro**, **Accessibilité** et **Surveillance de l'entrée**
(Réglages Système > Confidentialité et sécurité), puis relance l'app.

## Configuration
`~/Library/Application Support/Talk2Mac/config.json` :

| Clé | Rôle |
|---|---|
| `hotkey` | `rightCommand`, `rightOption`, `rightControl`, `rightShift`, `fn` |
| `language` | `auto`, `fr`, `en` |
| `whisperPath` / `modelPath` | chemins du binaire et du modèle |
| `keyDelayMs` / `chunkSize` | cadence de frappe (à augmenter si la VDI perd des caractères) |
| `fillers` | mots parasites à retirer |
| `dictionary` | remplacements `{"entendu": "voulu"}` |

Journal de debug : `~/Library/Application Support/Talk2Mac/log.txt`.
