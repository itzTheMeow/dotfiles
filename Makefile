.PHONY: update
update:
	home-manager switch --flake .#kubuntu

.PHONY: clean
clean:
	nix-collect-garbage -d