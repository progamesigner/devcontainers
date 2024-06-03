#!/usr/bin/env bash

AWS_CLI_VERSION=${VERSION:-${1:-none}}

AWS_CLI_SSM_PLUGIN=${SSM:-false}

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [[ $(id -u) != 0 ]]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

BUILD_PACKAGES=" \
    unzip \
"

GPG_KEY_MARTIAL="
-----BEGIN PGP PUBLIC KEY BLOCK-----
mQINBF2Cr7UBEADJZHcgusOJl7ENSyumXh85z0TRV0xJorM2B/JL0kHOyigQluUG
ZMLhENaG0bYatdrKP+3H91lvK050pXwnO/R7fB/FSTouki4ciIx5OuLlnJZIxSzx
PqGl0mkxImLNbGWoi6Lto0LYxqHN2iQtzlwTVmq9733zd3XfcXrZ3+LblHAgEt5G
TfNxEKJ8soPLyWmwDH6HWCnjZ/aIQRBTIQ05uVeEoYxSh6wOai7ss/KveoSNBbYz
gbdzoqI2Y8cgH2nbfgp3DSasaLZEdCSsIsK1u05CinE7k2qZ7KgKAUIcT/cR/grk
C6VwsnDU0OUCideXcQ8WeHutqvgZH1JgKDbznoIzeQHJD238GEu+eKhRHcz8/jeG
94zkcgJOz3KbZGYMiTh277Fvj9zzvZsbMBCedV1BTg3TqgvdX4bdkhf5cH+7NtWO
lrFj6UwAsGukBTAOxC0l/dnSmZhJ7Z1KmEWilro/gOrjtOxqRQutlIqG22TaqoPG
fYVN+en3Zwbt97kcgZDwqbuykNt64oZWc4XKCa3mprEGC3IbJTBFqglXmZ7l9ywG
EEUJYOlb2XrSuPWml39beWdKM8kzr1OjnlOm6+lpTRCBfo0wa9F8YZRhHPAkwKkX
XDeOGpWRj4ohOx0d2GWkyV5xyN14p2tQOCdOODmz80yUTgRpPVQUtOEhXQARAQAB
tCFBV1MgQ0xJIFRlYW0gPGF3cy1jbGlAYW1hem9uLmNvbT6JAlQEEwEIAD4CGwMF
CwkIBwIGFQoJCAsCBBYCAwECHgECF4AWIQT7Xbd/1cEYuAURraimMQrMRnJHXAUC
ZMKcEgUJCSEf3QAKCRCmMQrMRnJHXCilD/4vior9J5tB+icri5WbDudS3ak/ve4q
XS6ZLm5S8l+CBxy5aLQUlyFhuaaEHDC11fG78OduxatzeHENASYVo3mmKNwrCBza
NJaeaWKLGQT0MKwBSP5aa3dva8P/4oUP9GsQn0uWoXwNDWfrMbNI8gn+jC/3MigW
vD3fu6zCOWWLITNv2SJoQlwILmb/uGfha68o4iTBOvcftVRuao6DyqF+CrHX/0j0
klEDQFMY9M4tsYT7X8NWfI8Vmc89nzpvL9fwda44WwpKIw1FBZP8S0sgDx2xDsxv
L8kM2GtOiH0cHqFO+V7xtTKZyloliDbJKhu80Kc+YC/TmozD8oeGU2rEFXfLegwS
zT9N+jB38+dqaP9pRDsi45iGqyA8yavVBabpL0IQ9jU6eIV+kmcjIjcun/Uo8SjJ
0xQAsm41rxPaKV6vJUn10wVNuhSkKk8mzNOlSZwu7Hua6rdcCaGeB8uJ44AP3QzW
BNnrjtoN6AlN0D2wFmfE/YL/rHPxU1XwPntubYB/t3rXFL7ENQOOQH0KVXgRCley
sHMglg46c+nQLRzVTshjDjmtzvh9rcV9RKRoPetEggzCoD89veDA9jPR2Kw6RYkS
XzYm2fEv16/HRNYt7hJzneFqRIjHW5qAgSs/bcaRWpAU/QQzzJPVKCQNr4y0weyg
B8HCtGjfod0p1A==
=gdMc
-----END PGP PUBLIC KEY BLOCK-----
"

if [[ ${AWS_CLI_VERSION} != none ]]; then
    echo "Setup AWS CLI v${AWS_CLI_VERSION} ..."

    apt-get update
    apt-get install --no-install-recommends --yes ${BUILD_PACKAGES}
    apt-get upgrade --no-install-recommends --yes

    ARCHITECTURE=""
    case "$(dpkg --print-architecture)" in
        amd64) ARCHITECTURE=x86_64;;
        arm64) ARCHITECTURE=aarch64;;
        *) echo "unsupported architecture"; exit 1 ;;
    esac

    AWS_CLI_URL=https://awscli.amazonaws.com/awscli-exe-linux-${ARCHITECTURE}-${AWS_CLI_VERSION}.zip
    if [[ ${AWS_CLI_VERSION} = latest ]]; then
        AWS_CLI_URL=https://awscli.amazonaws.com/awscli-exe-linux-${ARCHITECTURE}.zip
    fi

    curl -sSL -o /tmp/aws-cli.zip ${AWS_CLI_URL}
    curl -sSL -o /tmp/aws-cli.zip.asc ${AWS_CLI_URL}.sig

    export GNUPGHOME=$(mktemp -d)
    echo "${GPG_KEY_MARTIAL}" | gpg --import
    gpg --batch --verify /tmp/aws-cli.zip.asc /tmp/aws-cli.zip
    gpgconf --kill all
    rm -rf ${GNUPGHOME}

    mkdir -p /tmp/aws-cli
    unzip -o /tmp/aws-cli.zip -d /tmp/aws-cli

    /tmp/aws-cli/aws/install --bin-dir /usr/local/share/aws-cli/bin --install-dir /usr/local/share/aws-cli

    if [[ ${AWS_CLI_SSM_PLUGIN} = true ]]; then
        case "$(dpkg --print-architecture)" in
            amd64) AWS_SSM_URL=https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb;;
            arm64) AWS_SSM_URL=https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_arm64/session-manager-plugin.deb;;
            *) echo "unsupported architecture"; exit 1 ;;
        esac
        curl -sSL -o /tmp/aws-session-manager-plugin.deb ${AWS_SSM_URL}
        dpkg --install /tmp/aws-session-manager-plugin.deb
        rm -rf /tmp/aws-session-manager-plugin.zip
    fi

    rm -rf /tmp/aws-cli.zip /tmp/aws-cli.zip.asc /tmp/aws-cli

    echo "Done!"
fi
