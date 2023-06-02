package main

import (
	"wagon.octohelm.tech/core"

	"github.com/innoai-tech/runtime/cuepkg/debian"
	"github.com/innoai-tech/runtime/cuepkg/imagetool"
)

target: core.#ClientEnv & {
	VERSION: string | *"16"
}

for debianVersion in ["buster", "bullseye"] {
	actions: "\(debianVersion)": imagetool.#Ship & {
		name: "ghcr.io/innoai-tech/llvm"
		tag:  "\(13)-\(debianVersion)"
		config: {
			label: {
				"org.opencontainers.image.source": "https://github.com/innoai-tech/llvm"
			}
			workdir: "/"
		}

		platforms: ["linux/amd64", "linux/arm64"]

		from: "docker.io/library/debian:\(debianVersion)-slim"

		steps: [
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
				./llvm.sh \(target.VERSION) all
				rm llvm.sh
				"""
			},
		]
	}
}

setting: {
	_env: core.#ClientEnv & {
		GH_USERNAME: string | *""
		GH_PASSWORD: core.#Secret
	}

	setup: core.#Setting & {
		registry: "ghcr.io": auth: {
			username: _env.GH_USERNAME
			secret:   _env.GH_PASSWORD
		}
	}
}
