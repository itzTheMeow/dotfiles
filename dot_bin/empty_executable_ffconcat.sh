#!/bin/bash

if [ "$#" -lt 3 ]; then
  echo "Usage: $0 <output_file> <input_file1> <input_file2> [input_file3 ...]"
  exit 1
fi

output_file="$1"
shift

ffmpeg -f concat -safe 0 -i <(for f in "$@"; do echo "file '$f'"; done) "$output_file"

echo "Videos combined successfully into $output_file"
