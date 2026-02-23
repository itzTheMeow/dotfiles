#!/usr/bin/env bash

cd ~/.dotfiles || exit

# convert the ed25519 key to age
SERVER_AGE_KEY=$(op read "$PUBLIC_KEY_URI" | ssh-to-age)

HOSTNAME=flynn
echo "Evaluating secrets for $HOSTNAME..."

CONFIG=$(nix eval ".#nixosConfigurations.$HOSTNAME.config.sops.opSecrets" --json)

echo "$CONFIG" | jq -r 'keys[]' | while read -r FILE_NAME; do
	FORMAT=$(echo "$CONFIG" | jq -r ".\"$FILE_NAME\".format")
	TARGET_PATH=$(echo "$CONFIG" | jq -r ".\"$FILE_NAME\".path")

	echo "Processing $FILE_NAME ($FORMAT)..."

	# Fetch values from 1Password and build JSON
	FINAL_JSON="{}"
	while read -r KEY URI; do
		echo "  Fetching $KEY from 1Password..."
		VAL=$(op read "$URI")
		FINAL_JSON=$(echo "$FINAL_JSON" | jq --arg k "$KEY" --arg v "$VAL" '.[$k] = $v')
	done < <(echo "$CONFIG" | jq -r ".\"$FILE_NAME\".keys | to_entries[] | \"\(.key) \(.value)\"")

	# Encrypt and save to the host's directory
	mkdir -p "./hosts/$HOSTNAME/sops"
	echo "$FINAL_JSON" | sops --encrypt \
		--age "$SERVER_AGE_KEY" \
		--input-type json \
		--output-type "$FORMAT" \
		/dev/stdin >"$TARGET_PATH"
done
