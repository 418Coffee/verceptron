#!/bin/sh

set -xe

export SAVE_WEIGHTS=1

rm -rf data
v run .
ffmpeg -y -i data/weights-%05d.ppm temp.mp4
ffmpeg -y -i temp.mp4 -vf palettegen data/palette.png
ffmpeg -y -i temp.mp4 -i data/palette.png -filter_complex paletteuse adjustments.gif
rm temp.mp4