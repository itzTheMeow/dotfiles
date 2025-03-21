#!/bin/bash

if [ "$#" -lt 3 ]; then
  echo "Usage: $0 <output_file> <input_file1> <input_file2> [input_file3 ...]"
  exit 1
fi

output_file="$1"
shift

temp_list=$(mktemp)

for input in "$@"; do
    echo "file '$(realpath "$input")'" >> "$temp_list"
done

ffmpeg -f concat -safe 0 -i "$temp_list" "$output_file"

rm -f "$temp_list" 

echo "Videos combined successfully into $output_file"
