// SPDX-FileCopyrightText: 2025 Margo
//
// SPDX-License-Identifier: MIT
//
// SPDX-FileContributor: Michael Adler <michael.adler@siemens.com>

package main

import (
	"errors"
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/opencontainers/go-digest"
	"github.com/regclient/regclient/types/descriptor"
	"github.com/regclient/regclient/types/manifest"
	"github.com/regclient/regclient/types/ref"
	"gopkg.in/yaml.v3"
)

type ApplicationDeployment struct {
	APIVersion string `yaml:"apiVersion"`
	Kind       string `yaml:"kind"`
	Metadata   struct {
		Annotations map[string]string `yaml:"annotations"`
		Name        string            `yaml:"name"`
		Namespace   string            `yaml:"namespace"`
	} `yaml:"metadata"`
	Spec struct {
		DeploymentProfile struct {
			Type       string `yaml:"type"`
			Components []struct {
				Name       string `yaml:"name"`
				Properties struct {
					KeyLocation     string `yaml:"keyLocation"`
					PackageLocation string `yaml:"packageLocation"`
				} `yaml:"properties"`
			} `yaml:"components"`
		} `yaml:"deploymentProfile"`
		Parameters map[string]struct {
			Value   string `yaml:"value"`
			Targets []struct {
				Pointer    string   `yaml:"pointer"`
				Components []string `yaml:"components"`
			} `yaml:"targets"`
		} `yaml:"parameters"`
	} `yaml:"spec"`
}

func getAppDeployment(deployRepo string) (*ApplicationDeployment, error) {
	r, err := ref.New(deployRepo)
	if err != nil {
		return nil, err
	}
	if _, err := rc.Ping(ctx, r); err != nil {
		return nil, err
	}

	mf, err := rc.ManifestGet(ctx, r)
	if err != nil {
		return nil, err
	}
	imager := mf.(manifest.Imager)
	layers, _ := imager.GetLayers()
	for _, desc := range layers {
		if desc.MediaType == "application/vnd.margo.desired-state.v1+yaml" {
			reader, err := rc.BlobGet(ctx, r, desc)
			if err != nil {
				return nil, err
			}
			defer reader.Close()
			b, err := io.ReadAll(reader)
			if err != nil {
				return nil, err
			}
			var appDeployment ApplicationDeployment
			if err := yaml.Unmarshal(b, &appDeployment); err != nil {
				return nil, err
			}
			return &appDeployment, nil
		}
	}
	return nil, errors.New("no app deployment found")
}

// downloadFromOCI downloads the given OCI registry url. This is a simple HTTP GET request.
func downloadFromOCI(url string) (io.ReadCloser, error) {
	log.Printf("Downloading %s", url)

	pattern := `^http://ghcr\.io/v2/([^/]+)/([^/]+)/blobs/(sha256:[a-f0-9]+)$`
	re := regexp.MustCompile(pattern)

	matches := re.FindStringSubmatch(url)
	if len(matches) != 4 {
		return nil, fmt.Errorf("unsupported URL format: %s", url)
	}

	owner, repo := matches[1], matches[2]
	sha256 := matches[3]

	appRef, err := ref.New(fmt.Sprintf("ghcr.io/%s/%s:latest", owner, repo))
	if err != nil {
		return nil, err
	}
	return rc.BlobGet(ctx, appRef, descriptor.Descriptor{Digest: digest.Digest(sha256)})
}

func syncDeployments(ociRegistry, deployDir string) error {
	deployments, err := getAppDeployment(ociRegistry)
	if err != nil {
		return err
	}
	for _, deployment := range deployments.Spec.DeploymentProfile.Components {
		destDir := path.Join(deployDir, deployment.Name)
		hashFile := path.Join(destDir, ".hash")
		expectedHash := strings.Split(deployment.Properties.PackageLocation, "sha256:")[1]
		// check if local deployment is up-to-date
		if fileExists(hashFile) {
			f, err := os.Open(hashFile)
			if err != nil {
				return err
			}
			b, err := io.ReadAll(f)
			if err != nil {
				return err
			}
			actualHash := string(b)
			if actualHash == expectedHash {
				log.Printf("%s: deployment is up-to-date", deployment.Name)
				continue
			}
		}

		log.Printf("%s: fetching from remote", deployment.Name)
		_ = os.MkdirAll(destDir, 0o755)

		tempDir, err := os.MkdirTemp("", deployment.Name)
		if err != nil {
			return err
		}
		defer os.RemoveAll(tempDir)

		// HTTP GET
		pubKey, err := downloadFromOCI(deployment.Properties.KeyLocation)
		if err != nil {
			return err
		}
		defer pubKey.Close()

		// HTTP GET
		pkg, err := downloadFromOCI(deployment.Properties.PackageLocation)
		if err != nil {
			return err
		}
		defer pkg.Close()
		if err := unpackTgz(pkg, tempDir, true); err != nil {
			return err
		}

		appFiles, err := findAppFiles(tempDir)
		if err != nil {
			return err
		}
		app := appFiles[0]
		appSig := fmt.Sprintf("%s.sig", app)
		if err := verifyGPGSignature(pubKey, app, appSig); err != nil {
			return err
		}

		if err := os.WriteFile(hashFile, []byte(expectedHash), 0o644); err != nil {
			return err
		}

		if fileExists(path.Join(destDir, "docker-compose.yaml")) {
			cmd := exec.Command("docker-compose", "down")
			cmd.Dir = destDir
			if err := cmd.Run(); err != nil {
				return err
			}
		}

		f, err := os.Open(app)
		if err != nil {
			return err
		}
		defer f.Close()
		if err := unpackTgz(f, destDir, true); err != nil {
			return err
		}

		// load *.tar files into docker
		if err := filepath.Walk(destDir, func(path string, info os.FileInfo, err error) error {
			if err != nil {
				return err
			}
			if !info.IsDir() && strings.HasSuffix(info.Name(), ".tar") {
				if err := uploadToDocker(path); err != nil {
					return err
				}
			}
			return nil
		}); err != nil {
			return err
		}

		cmd := exec.Command("docker-compose", "up", "--detach", "--remove-orphans")
		cmd.Dir = destDir
		if err := cmd.Run(); err != nil {
			return err
		}
	}
	return nil
}
