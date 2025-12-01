#!/usr/bin/env bash
# Uploads passed file to 0x0.st

curl -A "xela.codes/1.0.0" -F "file=@$1" https://0x0.st
