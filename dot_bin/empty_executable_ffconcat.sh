#!/bin/bash

if [ "$#" -lt 3 ]; then
  echo "Usage: $0 <output_file> <input_file1> <input_file2> [input_file3 ...]"
  exit 1
fi

output_file="$1"
shift

printf "%s\n" "$@" | sed "s/^/file '/;s/\$/\'/" | ffmpeg -f concat -safe 0 -i pipe:0 "$output_file"

echo "Videos combined successfully into $output_file"
