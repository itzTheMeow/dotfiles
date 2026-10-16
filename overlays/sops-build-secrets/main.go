package main

import (
	"bytes"
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io/fs"
	"maps"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"slices"
	"strings"
	"time"

	"github.com/1password/onepassword-sdk-go"
	agessh "github.com/Mic92/ssh-to-age"
	"github.com/getsops/sops/v3"
	sopsAes "github.com/getsops/sops/v3/aes"
	sopsAge "github.com/getsops/sops/v3/age"
	sopsCommon "github.com/getsops/sops/v3/cmd/sops/common"
	sopsKeys "github.com/getsops/sops/v3/keys"
	sopsKeyService "github.com/getsops/sops/v3/keyservice"
	sopsENV "github.com/getsops/sops/v3/stores/dotenv"
	sopsJSON "github.com/getsops/sops/v3/stores/json"
	sopsYAML "github.com/getsops/sops/v3/stores/yaml"
	sopsVersion "github.com/getsops/sops/v3/version"
)

// which 1Password items hold a host's age recipients
type HostConfig struct {
	// 1Password URI to the host's ssh public key (decrypts system secrets)
	System string `json:"system"`
	// 1Password URI to the user's ssh public key (decrypts home-manager secrets)
	User string `json:"user"`
}

// the entire config file (just hosts for now)
type Config struct {
	Hosts map[string]HostConfig `json:"hosts"`
}

type NixConfig =
// hostname
map[string](struct {
	//          filename   config
	HomeManager map[string]SecretConfig `json:"home-manager"`
	NixOS       map[string]SecretConfig `json:"nixos"`
})
type SecretConfig struct {
	Format string            `json:"format"`
	Path   string            `json:"path"`
	Keys   map[string]string `json:"keys"`
}

var startTime = time.Now().UnixMilli()

func log(format string, args ...any) {
	now := time.Now().UnixMilli()
	fmt.Printf("+%-4d %s\n", now-startTime, fmt.Sprintf(format, args...))
	startTime = now
}

func expandHome(p string) string {
	if p == "~" || strings.HasPrefix(p, "~/") {
		home, err := os.UserHomeDir()
		if err != nil {
			panic(err)
		}
		return filepath.Join(home, strings.TrimPrefix(p, "~"))
	}
	return p
}

func main() {
	OP_SHARED_LIBRARY := os.Getenv("OP_SHARED_LIBRARY")
	if OP_SHARED_LIBRARY == "" {
		panic("OP_SHARED_LIBRARY is required")
	}

	// (required) the flake to eval for the sops options
	repoFlag := flag.String("repo", "", "path to the dotfiles repo (its sops/ dir is written)")
	// optional path to the config for the hosts
	configFlag := flag.String("config", "", "path to sops.json (default: <repo>/sops.json)")
	flag.Parse()

	if *repoFlag == "" {
		flag.Usage()
		panic("--repo is required")
	}
	repo := expandHome(*repoFlag)

	configPath := *configFlag
	if configPath == "" {
		configPath = filepath.Join(repo, "sops.json")
	}
	configPath = expandHome(configPath)
	log("using repo %s", repo)
	log("using config %s", configPath)

	rawConfig, err := os.ReadFile(configPath)
	if err != nil {
		panic(err)
	}
	var cfg Config
	if err := json.Unmarshal(rawConfig, &cfg); err != nil {
		panic(err)
	}
	if len(cfg.Hosts) == 0 {
		panic("config has no hosts")
	}

	// init 1password client with desktop integration
	client, err := onepassword.NewClient(
		context.Background(),
		onepassword.WithDesktopAppIntegration("Meow"),
		onepassword.WithSharedLibraryPath(OP_SHARED_LIBRARY),
		onepassword.WithIntegrationInfo("SOPS", "v1.0.0"),
	)
	if err != nil {
		panic(err)
	}

	// fetch and convert every host's pubkeys into age recipients
	log("fetching pubkeys...")
	ServerPublicKeys, UserPublicKeys, err := fetchPubkeys(client, cfg)
	if err != nil {
		panic(err)
	}

	// evaluate the repo's nixosConfigurations and collect the opSecrets
	log("parsing configs...")
	var evaluated NixConfig
	if err := shellJSON(&evaluated, "nix", "eval", repo+"#nixosConfigurations", "--json", "--apply", `
builtins.mapAttrs (name: conf: {
	nixos = conf.config.sops.opSecrets or {};

	# flattens the home manager config for each user into a single block
	home-manager = builtins.foldl' (acc: user:
		acc // (user.sops.opSecrets or {})
	) {} (builtins.attrValues (conf.config.home-manager.users or {}));
})`); err != nil {
		panic(fmt.Errorf("failed to evaluate %s: %w", repo, err))
	}

	// keep only the hosts listed in the config
	configs := make(NixConfig)
	for hostname, hostConfig := range evaluated {
		if _, ok := cfg.Hosts[hostname]; ok {
			configs[hostname] = hostConfig
		} else {
			log("skipping %s (not configured)", hostname)
		}
	}
	// warn about configured hosts missing from the eval
	for name := range cfg.Hosts {
		if _, ok := evaluated[name]; !ok {
			log("warning: %s not found in %s#nixosConfigurations", name, repo)
		}
	}

	secretURIList := make(map[string]struct{})
	for hostname, config := range configs {
		start := len(secretURIList)
		log("finding secrets for %s...", hostname)
		for fileName, file := range config.NixOS {
			processSecretURIs(&secretURIList, file.Keys, fileName, &config.NixOS)
		}
		for fileName, file := range config.HomeManager {
			processSecretURIs(&secretURIList, file.Keys, fileName, &config.HomeManager)
		}
		log("found %d new secrets", len(secretURIList)-start)
	}
	allSecretURIs := slices.Collect(maps.Keys(secretURIList))

	// we can fetch all the secrets in a single call
	log("fetching secrets...")
	fetchedSecrets, err := client.Secrets().ResolveAll(context.Background(), allSecretURIs)
	if err != nil {
		panic(err)
	}
	// make sure none of them failed
	for uri, res := range fetchedSecrets.IndividualResponses {
		if res.Error != nil {
			panic(fmt.Errorf("failed to fetch secret '%s': %s", uri, string(res.Error.Type)))
		}
	}

	for hostname, config := range configs {
		log("encrypting secrets for %s...", hostname)

		if masterKey, err := sopsAge.MasterKeyFromRecipient(ServerPublicKeys[hostname]); err == nil {
			encryptSecrets("NixOS", repo, config.NixOS, masterKey, fetchedSecrets)
		} else {
			panic(err)
		}
		if masterKey, err := sopsAge.MasterKeyFromRecipient(UserPublicKeys[hostname]); err == nil {
			encryptSecrets("Home Manager", repo, config.HomeManager, masterKey, fetchedSecrets)
		} else {
			panic(err)
		}
	}

	log("cleaning up unused secrets...")
	cleanupSecrets(repo, configs)

	log("done.")
}

// fetchPubkeys resolves each host's server/user public keys and converts them
// from ssh to age recipients.
func fetchPubkeys(client *onepassword.Client, cfg Config) (map[string]string, map[string]string, error) {
	names := slices.Collect(maps.Keys(cfg.Hosts))
	slices.Sort(names)

	var uris []string
	for _, name := range names {
		uris = append(uris, cfg.Hosts[name].System, cfg.Hosts[name].User)
	}

	fetched, err := client.Secrets().ResolveAll(context.Background(), uris)
	if err != nil {
		return nil, nil, err
	}

	ServerPublicKeys := make(map[string]string)
	UserPublicKeys := make(map[string]string)
	for _, name := range names {
		hostConfig := cfg.Hosts[name]
		for _, entry := range []struct {
			uri    string
			target map[string]string
			label  string
		}{
			{hostConfig.System, ServerPublicKeys, "server"},
			{hostConfig.User, UserPublicKeys, "user"},
		} {
			resp := fetched.IndividualResponses[entry.uri]
			if resp.Error != nil {
				return nil, nil, fmt.Errorf("%s pubkey for %s: %s", entry.label, name, string(resp.Error.Type))
			}
			age, err := agessh.SSHPublicKeyToAge([]byte(resp.Content.Secret))
			if err != nil {
				return nil, nil, err
			}
			entry.target[name] = *age
		}
	}
	return ServerPublicKeys, UserPublicKeys, nil
}

func cleanupSecrets(dotfiles string, configs NixConfig) {
	root := path.Join(dotfiles, "sops")
	if _, err := os.Stat(root); os.IsNotExist(err) {
		log("no sops dir in %s, skipping cleanup", dotfiles)
		return
	}

	expectedFiles := make(map[string]struct{})
	expectedDirs := make(map[string]struct{})
	for _, config := range configs {
		for _, file := range config.NixOS {
			expectedFiles[path.Join(dotfiles, file.Path)] = struct{}{}
			expectedDirs[path.Join(dotfiles, path.Dir(file.Path))] = struct{}{}
		}
		for _, file := range config.HomeManager {
			expectedFiles[path.Join(dotfiles, file.Path)] = struct{}{}
			expectedDirs[path.Join(dotfiles, path.Dir(file.Path))] = struct{}{}
		}
	}

	removedFiles := 0
	removedDirs := 0
	dirs := []string{}
	err := filepath.WalkDir(root, func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			if p != root {
				if _, ok := expectedDirs[p]; ok {
					dirs = append(dirs, p)
					return nil
				}
				// orphaned host dir
				log("removing unused dir %s", p)
				if err := os.RemoveAll(p); err != nil {
					return err
				}
				removedDirs++
				return fs.SkipDir
			}
			dirs = append(dirs, p)
			return nil
		}
		if _, ok := expectedFiles[p]; !ok {
			log("removing unused %s", p)
			if err := os.Remove(p); err != nil {
				return err
			}
			removedFiles++
		}
		return nil
	})
	if err != nil {
		panic(err)
	}

	// remove any dirs left empty, deepest first
	slices.SortFunc(dirs, func(a, b string) int {
		return strings.Compare(b, a)
	})
	for _, dir := range dirs {
		if dir == root {
			continue
		}
		if entries, err := os.ReadDir(dir); err == nil && len(entries) == 0 {
			log("removing empty dir %s", dir)
			if err := os.Remove(dir); err != nil {
				panic(err)
			}
			removedDirs++
		} else if err != nil {
			panic(err)
		}
	}

	log("removed %d files, %d dirs", removedFiles, removedDirs)
}

func shellJSON(ptr any, cmd string, args ...string) error {
	command := exec.Command(cmd, args...)
	var stdout bytes.Buffer
	command.Stdout = &stdout
	var stderr bytes.Buffer
	command.Stderr = &stderr

	if err := command.Run(); err != nil {
		errText := strings.TrimSpace(stderr.String())
		if errText == "" {
			errText = strings.TrimSpace(stdout.String())
		}
		if errText != "" {
			return fmt.Errorf("%w: %s", err, errText)
		}
		return err
	}

	if err := json.Unmarshal(stdout.Bytes(), ptr); err != nil {
		return err
	}
	return nil
}

func processSecretURIs(list *map[string]struct{}, keys map[string]string, fileName string, ptr *map[string]SecretConfig) {
	for name, key := range keys {
		// for some reason "Private" isnt a valid vault name for the SDK, so replace it with the vault ID
		if strings.HasPrefix(key, "op://Private") {
			key = strings.Replace(key, "op://Private", "op://x4455gscttc5p7z42ff3dp2sky", 1)
			(*ptr)[fileName].Keys[name] = key
		}
		// add the key to the list
		(*list)[key] = struct{}{}
	}
}

func encryptSecrets(sourceLabel string, dotfiles string, config map[string]SecretConfig, masterKey *sopsAge.MasterKey, fetchedSecrets onepassword.ResolveAllResponse) {
	// partially based on https://github.com/getsops/sops/issues/1094#issuecomment-1923060495
	for fileName, file := range config {
		log("processing %s (%s)", fileName, sourceLabel)

		tree := sops.Tree{
			Branches: sops.TreeBranches{},
			Metadata: sops.Metadata{
				KeyGroups: []sops.KeyGroup{
					[]sopsKeys.MasterKey{masterKey},
				},
				UnencryptedSuffix: sops.DefaultUnencryptedSuffix,
				Version:           sopsVersion.Version,
			},
		}

		// put each key inside the branch
		branch := sops.TreeBranch{}
		for name, uri := range file.Keys {
			branch = append(branch, sops.TreeItem{
				Key:   name,
				Value: fetchedSecrets.IndividualResponses[uri].Content.Secret,
			})
		}
		tree.Branches = append(tree.Branches, branch)

		// need to generate a data key and then
		if dataKey, err := tree.GenerateDataKeyWithKeyServices(
			[]sopsKeyService.KeyServiceClient{sopsKeyService.NewLocalClient()},
		); err == nil {
			sopsCommon.EncryptTree(sopsCommon.EncryptTreeOpts{
				DataKey: dataKey,
				Tree:    &tree,
				Cipher:  sopsAes.NewCipher(),
			})
			var store sops.Store
			switch file.Format {
			case "yaml":
				store = &sopsYAML.Store{}
			case "json":
				store = &sopsJSON.Store{}
			case "dotenv":
				store = &sopsENV.Store{}
			}

			fullPath := path.Join(dotfiles, file.Path)
			// encrypt the secrets
			if result, err := store.EmitEncryptedFile(tree); err != nil {
				panic(err)
				// mkdir
			} else if err := os.MkdirAll(path.Dir(fullPath), 0755); err != nil {
				panic(err)
				// write the secrets
			} else if err := os.WriteFile(fullPath, result, 0644); err != nil {
				panic(err)
			}
			log("written to %s", file.Path)
		} else {
			panic(err)
		}
	}
}
