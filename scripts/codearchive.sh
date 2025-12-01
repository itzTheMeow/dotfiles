#!/usr/bin/env bash

dir="${1:-.}"
if [[ ! -d "$dir" ]]; then
	dir="."
fi
cd "$dir" || exit

# output to .archive
mkdir -p .archive

# process code files recursively
for ext in py js html java txt sql bat sh css less json md yaml yml; do
	shopt -s nocaseglob
	while IFS= read -r -d '' file; do
		shopt -u nocaseglob
		# skip files in .archive directory
		[[ "$file" == ./.archive/* ]] && continue

		# get relative path without leading ./
		relative_path="${file#./}"
		# create safe filename by replacing / with ___
		safe_name="${relative_path//\//___}"
		output_file=".archive/${safe_name}.html"

		echo "Code: $relative_path => $output_file"
		pygmentize -f html -O full,style=colorful -o "$output_file" "$file"
	done < <(find . -type f -iname "*.$ext" -print0)
	shopt -u nocaseglob
done

# process images recursively
for ext in png jpg jpeg svg; do
	shopt -s nocaseglob
	while IFS= read -r -d '' file; do
		shopt -u nocaseglob
		# skip files in .archive directory
		[[ "$file" == ./.archive/* ]] && continue

		# get relative path without leading ./
		relative_path="${file#./}"
		# create safe filename by replacing / with ___
		safe_name="${relative_path//\//___}"
		output_file=".archive/${safe_name}.html"

		echo "Image: $relative_path => $output_file"

		cat >"$output_file" <<EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>$relative_path</title>
</head>
<body>
    <img src="../$relative_path" alt="$relative_path">
</body>
</html>
EOF
	done < <(find . -type f -iname "*.$ext" -print0)
	shopt -u nocaseglob
done

echo "Combining all exported files into a single document..."

# create combined HTML file
combined_file=".archive/combined.html"
cat >"$combined_file" <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Code Archive</title>
    <style>
        body { margin: 0; padding: 20px; font-family: Arial, sans-serif; }
        .file-section { page-break-before: always; margin-bottom: 0; }
        .file-section:first-child { page-break-before: avoid; }
        .file-section:last-child { page-break-after: avoid; }
        h1.section-title { color: #333; border-bottom: 2px solid #333; padding-bottom: 10px; margin-top: 0; }
        pre { page-break-inside: avoid; }
        img { page-break-inside: avoid; max-width: 100%; height: auto; display: block; }
EOF

# extract and combine all CSS styles from pygmentize-generated files
for file in .archive/*.html; do
	[[ "$file" == ".archive/combined.html" ]] && continue
	[[ -e "$file" ]] || continue

	# extract CSS from <style> tags in pygmentize output
	if grep -q "pygments" "$file" 2>/dev/null || grep -q "\.highlight" "$file" 2>/dev/null; then
		sed -n '/<style/,/<\/style>/p' "$file" | sed '1d;$d' >>"$combined_file"
		break # only need to extract once since all pygmentize files have the same CSS
	fi
done

cat >>"$combined_file" <<'EOF'
    </style>
</head>
<body>
EOF

# append content from each exported file (sorted for consistent ordering)
for file in .archive/*.html; do
	[[ "$file" == ".archive/combined.html" ]] && continue
	[[ -e "$file" ]] || continue

	basename="${file##*/}"
	basename="${basename%.html}"
	# convert safe filename back to path (replace ___ with /)
	display_name="${basename//___//}"

	echo "Adding $display_name to combined file..."

	echo "    <div class=\"file-section\">" >>"$combined_file"
	echo "        <h1 class=\"section-title\">$display_name</h1>" >>"$combined_file"

	# extract only body content from export files
	sed -n '/<body/,/<\/body>/p' "$file" | sed '1d;$d' >>"$combined_file"

	echo "    </div>" >>"$combined_file"
done

cat >>"$combined_file" <<'EOF'
</body>
</html>
EOF

echo "Generating PDF..."
pdf_output="archive-$(basename "$(pwd)").pdf"
wkhtmltopdf --enable-local-file-access "$combined_file" "$pdf_output"

echo "Cleaning up..."
rm -rf .archive

echo "Done! Archive created: $pdf_output"
