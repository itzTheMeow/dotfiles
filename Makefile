.PHONY: clean update

update:
	home-manager switch --flake .#kubuntu

clean:
	nix-collect-garbage -d
