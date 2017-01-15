#!/bin/bash

ROOT="https://freemusicspot.herokuapp.com"

while true; do
    curl -s ${ROOT}"/playlist" | jq '.[].url' | sed -n '1p' | xargs youtube-dl -f bestaudio -o - | mplayer -
    curl -s -H 'Content-Length: 0' -X POST ${ROOT}"/done"
done
