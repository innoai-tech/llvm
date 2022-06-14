package main

import (
	"dagger.io/dagger"

	"github.com/innoai-tech/runtime/cuepkg/debian"
	"github.com/innoai-tech/runtime/cuepkg/imagetool"
)

dagger.#Plan

client: env: {
	VERSION: string | *"13"
	GIT_SHA: string | *"152749e64aad80297f4bcb29e565426144383f81"
	GIT_REF: string | *""

	GOPROXY:   string | *""
	GOPRIVATE: string | *""
	GOSUMDB:   string | *""

	GH_USERNAME: string | *""
	GH_PASSWORD: dagger.#Secret

	LINUX_MIRROR:                  string | *""
	CONTAINER_REGISTRY_PULL_PROXY: string | *""
}

mirror: {
	linux: client.env.LINUX_MIRROR
	pull:  client.env.CONTAINER_REGISTRY_PULL_PROXY
}

auths: "ghcr.io": {
	username: client.env.GH_USERNAME
	secret:   client.env.GH_PASSWORD
}

for debianVersion in ["buster", "bullseye"] {
	actions: "\(debianVersion)": imagetool.#Ship & {
		name: "ghcr.io/innoai-tech/llvm"
		tag:  "\(client.env.VERSION)-\(debianVersion)"
		config: {
			label: {
				"org.opencontainers.image.source":   "https://github.com/innoai-tech/llvm"
				"org.opencontainers.image.revision": "\(client.env.GIT_SHA)"
			}
			workdir: "/"
		}

		platforms: ["linux/amd64", "linux/arm64"]

		from: "docker.io/library/debian:\(debianVersion)-slim"

		steps: [
			imagetool.#Shell & {
				env: {
					LINUX_MIRROR: mirror.linux
				}
				run: """
					if [ "${LINUX_MIRROR}" != "" ]; then
						sed -i "s@http://deb.debian.org@${LINUX_MIRROR}@g" /etc/apt/sources.list
						sed -i "s@http://security.debian.org@${LINUX_MIRROR}@g" /etc/apt/sources.list
					fi
					"""
			},
			debian.#InstallPackage & {
				packages: {
					"ca-certificates":            _
					"lsb-release":                _
					"wget":                       _
					"git":                        _
					"bash":                       _
					"cmake":                      _
					"autoconf":                   _
					"ninja-build":                _
					"software-properties-common": _
					"gnupg2":                     _
					"build-essential":            _
				}
			},
			imagetool.#Shell & {
				run: """
				wget https://apt.llvm.org/llvm.sh
				chmod +x llvm.sh
				./llvm.sh \(client.env.VERSION) all
				rm llvm.sh
				"""
			},
		]

		"mirror": mirror
		"auths":  auths
	}
}
