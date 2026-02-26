package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path"
	"slices"
	"strings"
	"time"

	"github.com/1password/onepassword-sdk-go"
	"github.com/Mic92/ssh-to-age"
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

var HostNames = []string{
	"ehrman",
	"flynn",
	"hyzenberg",
}
var ServerPublicKeyURIs = []string{
	"op://x4455gscttc5p7z42ff3dp2sky/l6owjdx7thnp52tuwmd4j5muda/public key", // ehrman
	"op://x4455gscttc5p7z42ff3dp2sky/rcbgglqbacsvmzwwygtpx73774/public key", // flynn
	"op://x4455gscttc5p7z42ff3dp2sky/ptvgkvjl5ugrylkpausc3misma/public key", // hyzenberg
}
var UserPublicKeyURIs = []string{
	"op://x4455gscttc5p7z42ff3dp2sky/zfo56rnxe3rtoigohaemc7lx6i/public key", // ehrman
	"op://x4455gscttc5p7z42ff3dp2sky/3qhsyka4n4ivngmjow5tysb3da/public key", // flynn
	"op://x4455gscttc5p7z42ff3dp2sky/vqhxrcxgookq6e6vu3etmjev2e/public key", // hyzenberg
}

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
	var configs map[string]map[string]SecretConfig
	if err := shellJSON(&configs, "nix", "eval", dotfiles+"#nixosConfigurations", "--json", "--apply", "builtins.mapAttrs (name: conf: conf.config.sops.opSecrets)"); err != nil {
		panic(fmt.Errorf("failed to get config list: %w", err))
	}

	for hostname := range configs {
		if !slices.Contains(HostNames, hostname) {
			log("no pubkeys for %s", hostname)
			delete(configs, hostname)
		}
	}

	// create a list of all the secrets to be fetched
	allSecretURIs := []string{}
	for hostname, config := range configs {
		start := len(allSecretURIs)
		log("finding secrets for %s...", hostname)
		for fileName, file := range config {
			for name, key := range file.Keys {
				// for some reason "Private" isnt a valid vault name for the SDK, so replace it with the vault ID
				if strings.HasPrefix(key, "op://Private") {
					key = strings.Replace(key, "op://Private", "op://x4455gscttc5p7z42ff3dp2sky", 1)
					configs[hostname][fileName].Keys[name] = key
				}

				// then append the URI to the list
				if !slices.Contains(allSecretURIs, key) {
					allSecretURIs = append(allSecretURIs, key)
				}
			}
		}
		log("found %d new secrets", len(allSecretURIs)-start)
	}

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

		masterKey, err := sopsAge.MasterKeyFromRecipient(ServerPublicKeys[hostname])
		if err != nil {
			panic(err)
		}

		// partially based on https://github.com/getsops/sops/issues/1094#issuecomment-1923060495
		for fileName, file := range config {
			log("processing %s", fileName)

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
				if result, err := store.EmitEncryptedFile(tree); err != nil {
					panic(err)
				} else if err := os.WriteFile(path.Join(dotfiles, file.Path), result, 0644); err != nil {
					panic(err)
				}
				log("written to %s", file.Path)
			} else {
				panic(err)
			}
		}
	}

	log("done.")
}

func shellJSON(ptr any, cmd string, args ...string) error {
	if out, err := exec.Command(cmd, args...).Output(); err != nil {
		return err
	} else {
		if err := json.Unmarshal(out, ptr); err != nil {
			return err
		}
	}
	return nil
}
