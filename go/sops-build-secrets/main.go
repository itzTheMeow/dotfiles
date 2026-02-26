package main

import (
	"context"
	"os"

	"github.com/1password/onepassword-sdk-go"
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

func main() {
	OP_SHARED_LIBRARY := os.Getenv("OP_SHARED_LIBRARY")
	if OP_SHARED_LIBRARY == "" {
		panic("OP_SHARED_LIBRARY is required")
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

	ServerPublicKeys := make(map[string]string)
	UserPublicKeys := make(map[string]string)

	secrets, err := client.Secrets().ResolveAll(context.Background(), append(ServerPublicKeyURIs, UserPublicKeyURIs...))
	if err != nil {
		panic(err)
	}
	i := 0
	for _, s := range secrets.IndividualResponses {
		if s.Error != nil {
			panic(string(s.Error.Type))
		}
		hostname := HostNames[i%len(HostNames)]
		if i > len(HostNames) {
			UserPublicKeys[hostname] = s.Content.Secret
		} else {
			ServerPublicKeys[hostname] = s.Content.Secret
		}
		i++
	}

	print("ok")
}
