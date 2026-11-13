#!/bin/zsh
# Installation depuis les sources : compile whisper.cpp, télécharge le modèle, installe dans /Applications.
set -e
cd "$(dirname "$0")"
command -v cmake >/dev/null || { echo "cmake requis : brew install cmake"; exit 1; }
xcode-select -p >/dev/null 2>&1 || { echo "Command Line Tools requis : xcode-select --install"; exit 1; }

if [[ ! -d vendor/whisper.cpp ]]; then
  git clone --depth 1 https://github.com/ggml-org/whisper.cpp vendor/whisper.cpp
fi
if [[ ! -x vendor/whisper.cpp/build/bin/whisper-cli ]]; then
  FLAGS=(-DBUILD_SHARED_LIBS=OFF)
  [[ "$(uname -m)" == "arm64" ]] || FLAGS+=(-DGGML_METAL=OFF)
  cmake -S vendor/whisper.cpp -B vendor/whisper.cpp/build $FLAGS
  cmake --build vendor/whisper.cpp/build -j4 --target whisper-cli
fi
if [[ ! -f models/ggml-small-q5_1.bin ]]; then
  mkdir -p models
  curl -L -o models/ggml-small-q5_1.bin \
    https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small-q5_1.bin
fi

./build.sh --bundle
pkill -x Talk2Mac 2>/dev/null || true
rm -rf /Applications/Talk2Mac.app
cp -R build/Talk2Mac.app /Applications/
echo "Installé dans /Applications. Lancement…"
open /Applications/Talk2Mac.app
echo "Accorde Micro, Accessibilité et Surveillance de l'entrée (Réglages Système > Confidentialité), puis relance l'app."
