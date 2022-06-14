package main

import (
	"dagger.io/dagger"
	"universe.dagger.io/docker"

	"github.com/innoai-tech/runtime/cuepkg/debian"
)

dagger.#Plan & {
	client: {
		env: {
			VERSION: string | *"13"
			GIT_SHA: string | *"152749e64aad80297f4bcb29e565426144383f81"
			GIT_REF: string | *""

			GOPROXY:   string | *""
			GOPRIVATE: string | *""
			GOSUMDB:   string | *""

			GH_USERNAME: string | *""
			GH_PASSWORD: dagger.#Secret

			LINUX_MIRROR: string | *""
		}
	}

	actions: {
		version: "\(client.env.VERSION)"

		target: {
			arch: ["amd64", "arm64"]
		}

		image: {
			for arch in target.arch {
				"\(arch)": docker.#Build & {
					steps: [
						debian.#Build & {
							platform: "linux/\(arch)"
							mirror:   client.env.LINUX_MIRROR
							packages: {
								"ca-certificates":            _
								"lsb_release":                _
								"wget":                       _
								"git":                        _
								"bash":                       _
								"cmake":                      _
								"autoconf":                   _
								"ninja-build":                _
								"add-apt-repository":         _
								"software-properties-common": _
								"gnupg2":                     _
								"build-essential":            _
							}
						},
						docker.#Run & {
							command: {
								name: "bash"
								flags: "-c": """
								wget https://apt.llvm.org/llvm.sh
								chmod +x llvm.sh
								./llvm.sh \(version) all
								rm llvm.sh
								"""
							}
						},
						docker.#Set & {
							config: {
								label: {
									"org.opencontainers.image.source":   "https://github.com/innoai-tech/llvm"
									"org.opencontainers.image.revision": "\(client.env.GIT_SHA)"
								}
								workdir: "/"
							}
						},
					]
				}
			}
		}

		ship: {
			_push: docker.#Push & {
				dest: "ghcr.io/innoai-tech/llvm:\(version)"
				images: {
					for arch, i in image {
						"linux/\(arch)": i.output
					}
				}
				auth: {
					username: client.env.GH_USERNAME
					secret:   client.env.GH_PASSWORD
				}
			}

			result: _push.result
		}
	}
}
