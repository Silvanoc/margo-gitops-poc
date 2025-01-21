# Margo: PoC for GitOps approach for deployments

This proof-of-concept (PoC) should demonstrate how to use OCI registries to have an OpenGitOps pattern for application deployment.

As of now public repositories in the GitHub Container Registry are being used as OCI-registry repositories for publication.

_Disclaimer_: this PoC applies the app signing approach that can be implicitly found in the [docker-compose deployment provided example](https://specification.margo.org/margo-api-reference/workload-api/desired-state-api/desired-state/#example-standalone-device-application-deployment-specification), without questioning it convenience.

## Structure

```
 
├──  common.source
├──  docker-compose-desired-state.yaml.in
├──  oci-watcher
│   ├──  crypto.go
│   ├──  docker.go
│   ├──  go.mod
│   ├──  go.sum
│   ├──  io.go
│   ├──  main.go
│   └──  oci.go
├──  poc-app
│   ├──  docker-compose.yaml
│   ├──  Dockerfile
│   ├──  go.mod
│   ├──  go.sum
│   ├──  main.go
├──  prepare-package.bash
├──  publish-desired-state.bash
├──  publish-package.bash
├── 󰂺 README.md
├──  rest-watcher
│   └──  rest-watcher.bash
├──  show-desired-state.bash
├──  show-package.bash
```

### `*.bash`

Multiple Bash scripts needed for PoC demonstration.
See below in the [workflow section](#workflows) for further details

### `oci-watcher`

Go program that is "watching" the OCI-registry hosting the Margo desired-state to get any updates.

It uses OCI-specific libraries for this purpose.
That way the REST-API is not being addressed directly, but internally by the libraries.

### `rest-watcher`

Small shell script that demonstrates how to have a desired-state watcher directly relying on the REST-API without any specific libraries or tools.

It only uses `curl`, `jq` and `sed` for this purpose and is capable of dealing with the GitHub OAuth2 authorization.

### `poc-app`

Files needed to create a docker-compose pseudo-app.

Such an app will simply have a docker-compose configuration and container image archives providing the container images required for that configuration.

### `docker-compose-desired-state.yaml.in`

Desired state template.
The URLs for the package (app + signature) and the public key to verify the signature of the app need to be replaced based on the published package.
The provided scripts take care of that replacement.

## Workflows

### App creation, publication and information

#### 1. App Creation

`prepare-package.bash` can be used to create a public key for app signing, an app and the app signature.

A package is the combination of an app and the corresponding signature.

#### 2. App Publication

`publish-package.bash` can be used to publish on a public OCI-registry repository the previously created package.

#### 3. App Information

`show-package.bash` can be used to get some information on the published package.

### Margo desired-state publication and consumption

#### 1. Desired-state Publication

`publish-desired-state.bash` can be used to publish a new desired-state, timestamps are used for versioning and the tag `desired` for the latest reference.

#### 2. Desired-state Consumption

`show-desired-state.bash` can be used to get information about the reference desired-state.

