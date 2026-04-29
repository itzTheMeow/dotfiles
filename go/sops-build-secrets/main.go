package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"maps"
	"os"
	"os/exec"
	"path"
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

const PRIVATE_VAULT = "op://x4455gscttc5p7z42ff3dp2sky"

var HostNames = []string{
	"ehrman",
	"flynn",
	"huell",
	"hyzenberg",
	"pete",
}
var ServerPublicKeyURIs = []string{
	PRIVATE_VAULT + "/l6owjdx7thnp52tuwmd4j5muda/public key", // ehrman
	PRIVATE_VAULT + "/rcbgglqbacsvmzwwygtpx73774/public key", // flynn
	PRIVATE_VAULT + "/e7f2qjlblpji4clfozgfddgit4/public key", // huell
	PRIVATE_VAULT + "/ptvgkvjl5ugrylkpausc3misma/public key", // hyzenberg
	PRIVATE_VAULT + "/xroaipl44ipp5vtpqxvtczbnoa/public key", // pete
}
var UserPublicKeyURIs = []string{
	PRIVATE_VAULT + "/zfo56rnxe3rtoigohaemc7lx6i/public key", // ehrman
	PRIVATE_VAULT + "/3qhsyka4n4ivngmjow5tysb3da/public key", // flynn
	PRIVATE_VAULT + "/mimvtzkpohm5bbbm5d6kpwp4aa/public key", // huell
	PRIVATE_VAULT + "/vqhxrcxgookq6e6vu3etmjev2e/public key", // hyzenberg
	PRIVATE_VAULT + "/wd7y5xz4qgp5loohnmc4wrj3t4/public key", // pete
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

func main() {
	OP_SHARED_LIBRARY := os.Getenv("OP_SHARED_LIBRARY")
	if OP_SHARED_LIBRARY == "" {
		panic("OP_SHARED_LIBRARY is required")
	}

	homedir, err := os.UserHomeDir()
	if err != nil {
		panic(err)
	}
	dotfiles := path.Join(homedir, ".dotfiles")
	if _, err := os.Stat(homedir); os.IsNotExist(err) {
		panic(err)
	}
	log("using %s", dotfiles)

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

	// create maps for the fetched keys
	ServerPublicKeys := make(map[string]string)
	UserPublicKeys := make(map[string]string)

	log("fetching pubkeys...")
	fetchedKeys, err := client.Secrets().ResolveAll(context.Background(), append(ServerPublicKeyURIs, UserPublicKeyURIs...))
	if err != nil {
		panic(err)
	}
	log("converting pubkeys...")
	// we can process both at once for simplicity
	for i, uri := range append(ServerPublicKeyURIs, UserPublicKeyURIs...) {
		if resp := fetchedKeys.IndividualResponses[uri]; resp.Error == nil {
			// convert the ssh key to an age key
			if age, err := agessh.SSHPublicKeyToAge([]byte(resp.Content.Secret)); err == nil {
				// add to either user/server keys based on index
				if i >= len(HostNames) {
					UserPublicKeys[HostNames[i%len(HostNames)]] = *age
				} else {
					ServerPublicKeys[HostNames[i]] = *age
				}
			} else {
				panic(err)
			}
		} else {
			panic(string(resp.Error.Type))
		}
	}

	log("parsing configs...")
	var configs NixConfig
	if err := shellJSON(&configs, "nix", "eval", dotfiles+"#nixosConfigurations", "--json", "--apply", `
builtins.mapAttrs (name: conf: {
	nixos = conf.config.sops.opSecrets or {};
	
	# flattens the home manager config for each user into a single block
	home-manager = builtins.foldl' (acc: user: 
		acc // (user.sops.opSecrets or {})
	) {} (builtins.attrValues (conf.config.home-manager.users or {}));
})`); err != nil {
		panic(fmt.Errorf("failed to get config list: %w", err))
	}

	for hostname := range configs {
		if !slices.Contains(HostNames, hostname) {
			log("no pubkeys for %s", hostname)
			delete(configs, hostname)
		}
	}

	// create a list of all the secrets to be fetched
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
			encryptSecrets("NixOS", dotfiles, config.NixOS, masterKey, fetchedSecrets)
		} else {
			panic(err)
		}
		if masterKey, err := sopsAge.MasterKeyFromRecipient(UserPublicKeys[hostname]); err == nil {
			encryptSecrets("Home Manager", dotfiles, config.HomeManager, masterKey, fetchedSecrets)
		} else {
			panic(err)
		}
	}

	log("done.")
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
