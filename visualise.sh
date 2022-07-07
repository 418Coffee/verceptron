#!/bin/sh

set -xe

export SAVE_WEIGHTS=1

rm -rf data
v run .
./ffmpeg.exe -y -i data/weights-%05d.ppm demo.mp4
./ffmpeg.exe -y -i demo.mp4 -vf palettegen data/palette.png
./ffmpeg.exe -y -i demo.mp4 -i data/palette.png -filter_complex paletteuse demo.gif
rm demo.mp4