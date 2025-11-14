.PHONY: clean update

update:
	nix flake update

clean:
	nix-collect-garbage -d
