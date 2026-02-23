#!/usr/bin/env bash

# this should be done inside of the dotfiles repo
cd ~/.dotfiles || exit

eval "$(op signin)"

# define PUBLIC_KEY_URIS associative array
declare -A PUBLIC_KEY_URIS
PUBLIC_KEY_URIS["ehrman"]="op://Private/l6owjdx7thnp52tuwmd4j5muda/public key"
PUBLIC_KEY_URIS["flynn"]="op://Private/rcbgglqbacsvmzwwygtpx73774/public key"
PUBLIC_KEY_URIS["hyzenberg"]="op://Private/ptvgkvjl5ugrylkpausc3misma/public key"

# get all nixosConfigurations hosts
HOSTNAMES=$(nix eval '.#nixosConfigurations' --json --apply 'builtins.attrNames' | jq -r 'values[]')

for HOSTNAME in $HOSTNAMES; do
	echo "Evaluating secrets for $HOSTNAME..."

	# check if PUBLIC_KEY_URIS contains the key
	if [[ -z "${PUBLIC_KEY_URIS[$HOSTNAME]+_}" ]]; then
		echo "No PUBLIC_KEY_URI found for $HOSTNAME, skipping..."
		continue
	fi

	# read/convert the ed25519 key to age
	SERVER_AGE_KEY=$(op read "${PUBLIC_KEY_URIS[$HOSTNAME]}" | ssh-to-age)

	# parse the opSecrets config from nix
	CONFIG=$(nix eval ".#nixosConfigurations.$HOSTNAME.config.sops.opSecrets" --json)

	echo "$CONFIG" | jq -r 'keys[]' | while read -r FILE_NAME; do
		FORMAT=$(echo "$CONFIG" | jq -r ".\"$FILE_NAME\".format")
		TARGET_PATH=$(echo "$CONFIG" | jq -r ".\"$FILE_NAME\".path")

		echo "Processing $FILE_NAME.$FORMAT..."

		# fetch each key and add it to the final json
		FINAL_JSON="{}"
		while read -r KEY URI; do
			echo "  Fetching $KEY from 1Password..."
			VAL=$(op read "$URI")
			FINAL_JSON=$(echo "$FINAL_JSON" | jq --arg k "$KEY" --arg v "$VAL" '.[$k] = $v')
		done < <(echo "$CONFIG" | jq -r ".\"$FILE_NAME\".keys | to_entries[] | \"\(.key) \(.value)\"")

		# encrypt the json to the sops directory
		mkdir -p "$(dirname "$TARGET_PATH")"
		echo "$FINAL_JSON" | sops --encrypt \
			--age "$SERVER_AGE_KEY" \
			--input-type json \
			--output-type "$FORMAT" \
			/dev/stdin >"$TARGET_PATH"
	done
done
