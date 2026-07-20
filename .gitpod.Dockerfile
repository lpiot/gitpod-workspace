# syntax=docker/dockerfile:1.7-labs
# lpiot-20240831: specific syntax needed for COPY --exclude feature

# -----------------------------------------------------------------------------
# Common ARGs
# -----------------------------------------------------------------------------

ARG DOCKER_IMAGES_MAINTAINER="Ludovic Piot <ludovic.piot@thegaragebandofit.com>"

# For consistency purpose, please use the same base as gitpod/workspace-full image
# see: https://github.com/gitpod-io/workspace-images
# ARG BASE_IMAGE=ubuntu:25.04
ARG BASE_IMAGE=alpine:3.23

ARG GITPOD_IMAGE=gitpod/workspace-python-3.12
# ARG GITPOD_IMAGE=gitpod/workspace-full

# ARG CLOUDSHELL_IMAGE=gcr.io/cloudshell-images/cloudshell:latest

# shpod image verion
ARG SHPOD_VERSION=lpiot_20251104


# -----------------------------------------------------------------------------
# Base install
# -----------------------------------------------------------------------------
FROM ${BASE_IMAGE} as base

ARG DOCKER_IMAGES_MAINTAINER

LABEL maintainer=${DOCKER_IMAGES_MAINTAINER}

# ----- common tools install
RUN apk update && \
    apk add ca-certificates curl git gnupg jq neovim tmux unzip wget yq
# RUN <<EOF bash
#     sudo apt-get update -y
#     sudo apt-get install -y git jq tmux vim wget \
#          apt-transport-https ca-certificates gnupg
# EOF


# -----------------------------------------------------------------------------
# Digital Ocean CLI
# -----------------------------------------------------------------------------
FROM base as do

ARG DOCKER_IMAGES_MAINTAINER

# Digital Ocean CLI release version
# https://github.com/digitalocean/doctl/releases
ARG DOCTL_VERSION=1.163.0


LABEL maintainer=${DOCKER_IMAGES_MAINTAINER}

WORKDIR /usr/bin
RUN <<EOF bash
    wget https://github.com/digitalocean/doctl/releases/download/v${DOCTL_VERSION}/doctl-${DOCTL_VERSION}-linux-amd64.tar.gz
    tar -xzf ./doctl-${DOCTL_VERSION}-linux-amd64.tar.gz
    rm -f ./doctl-${DOCTL_VERSION}-linux-amd64.tar.gz

    # Add Digital Ocean CLI autocompletion in BASH
    ./doctl completion bash > ~/completion_doctl.sh
EOF


# -----------------------------------------------------------------------------
# Hugo
# -----------------------------------------------------------------------------
FROM base AS hugo

ARG DOCKER_IMAGES_MAINTAINER

# Hugo Statis Site Generator
# https://github.com/gohugoio/hugo/releases
ARG HUGO_VERSION=0.164.2

LABEL maintainer=${DOCKER_IMAGES_MAINTAINER}
        
RUN <<EOF bash
    wget https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-amd64.tar.gz
    tar -xzf hugo_extended_${HUGO_VERSION}_linux-amd64.tar.gz
    cp -pr hugo /usr/local/bin/
EOF


# -----------------------------------------------------------------------------
# Mozilla SOPS & AGE
# -----------------------------------------------------------------------------
FROM base as sops

ARG DOCKER_IMAGES_MAINTAINER

# Mozilla SOPS release version
# https://github.com/getsops/sops/releases/
ARG SOPS_VERSION=3.13.2

LABEL maintainer=${DOCKER_IMAGES_MAINTAINER}

# Mozilla SOPS
COPY --from=ghcr.io/getsops/sops:v${SOPS_VERSION}-alpine /usr/local/bin/sops /usr/local/bin

# Install AGE
RUN apk add age

# RUN <<EOF bash
#     apt-get install -y age
#     wget https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.linux.amd64
#     mv sops-v${SOPS_VERSION}.linux.amd64 /usr/local/bin/sops
#     chmod +x /usr/local/bin/sops
# EOF


# -----------------------------------------------------------------------------
# Packer
# -----------------------------------------------------------------------------
FROM base as pac

ARG DOCKER_IMAGES_MAINTAINER

# Packer release version
# https://releases.hashicorp.com/packer
ARG PACKER_VERSION=1.15.4

LABEL maintainer=${DOCKER_IMAGES_MAINTAINER}

# Packer install
WORKDIR /usr/bin
RUN <<EOF bash
    wget https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip
    unzip ./packer_${PACKER_VERSION}_linux_amd64.zip
    rm -f ./packer_${PACKER_VERSION}_linux_amd64.zip

    Add Packer autocompletion in BASH
    touch ~/.bashrc
    packer -autocomplete-install
EOF


# -----------------------------------------------------------------------------
# Scaleway
# -----------------------------------------------------------------------------
FROM base as scw

ARG DOCKER_IMAGES_MAINTAINER

LABEL maintainer=${DOCKER_IMAGES_MAINTAINER}

RUN <<EOF bash
    curl -s https://raw.githubusercontent.com/scaleway/scaleway-cli/master/scripts/get.sh | sh

EOF


# -----------------------------------------------------------------------------
# Starship in RUST
# source: https://starship.rs/
# -----------------------------------------------------------------------------
FROM base AS starship

ARG DOCKER_IMAGES_MAINTAINER

LABEL maintainer=${DOCKER_IMAGES_MAINTAINER}
        
RUN <<EOF bash
    wget https://starship.rs/install.sh
    chmod +x install.sh
    ./install.sh --verbose --yes
    starship init bash > ./.bashrc.d/completion_starship.sh
EOF


# -----------------------------------------------------------------------------
# Terraform
# -----------------------------------------------------------------------------
FROM base as tf

ARG DOCKER_IMAGES_MAINTAINER

# Terraform release version
# https://releases.hashicorp.com/terraform
ARG TERRAFORM_VERSION=1.15.8

LABEL maintainer=${DOCKER_IMAGES_MAINTAINER}

# Terraform install
WORKDIR /usr/bin
RUN <<EOF bash
    wget https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
    unzip ./terraform_${TERRAFORM_VERSION}_linux_amd64.zip
    rm -f ./terraform_${TERRAFORM_VERSION}_linux_amd64.zip
 
    # Add Terraform autocompletion in BASH
    touch ~/.bashrc
    terraform --install-autocomplete
EOF


# -----------------------------------------------------------------------------
# Final Image(s) - GITPOD
# -----------------------------------------------------------------------------
FROM ${GITPOD_IMAGE} as gitpod_workspace

ARG DOCKER_IMAGES_MAINTAINER
ARG SHPOD_VERSION

LABEL maintainer=${DOCKER_IMAGES_MAINTAINER}

WORKDIR /home/gitpod

# Copy of Digital Ocean CLI
COPY --from=do --link /usr/bin/doctl /usr/bin/doctl
COPY --from=do --link /root/completion_doctl.sh ./.bashrc.d/

# Copy of Hugo Static Site Generator
COPY --from=hugo --link /usr/local/bin/hugo /usr/local/bin

# Copy of Mozilla SOPS
COPY --from=sops --link /usr/bin/age /usr/local/bin
COPY --from=sops --link /usr/local/bin/sops /usr/local/bin

# Copy of Packer
COPY --from=pac --link /usr/bin/packer /usr/bin/packer
COPY --from=pac --link /root/.bashrc  ./.bashrc.d/completion_packer.sh

# Copy of Scaleway CLI
COPY --from=scw --link /usr/local/bin/scw /usr/bin/scw
#RUN scw autocomplete script shell=bash > ./.bashrc.d/completion_scw.sh

# Copy of Starship
COPY --from=starship --link /usr/local/bin/starship /usr/local/bin/
COPY --from=starship --link ./.bashrc.d/completion_starship.sh ./.bashrc.d/completion_starship.sh

# Copy of Terraform
COPY --from=tf --link /usr/bin/terraform /usr/bin/terraform
COPY --from=tf --link /root/.bashrc ./.bashrc.d/completion_terraform.sh

# lpiot 2023-11-19: now retrieved from jpetazzo/shpod
# Copy lot of tools from jpetazzo/shpod forked to a personnal image
# COPY cmd cannot use ARG variables vOv
COPY --from=ghcr.io/lpiot/shpod:lpiot_20251104 --link --exclude=/usr/local/bin/docker-compose /usr/local/bin/* /usr/local/bin
COPY --from=ghcr.io/lpiot/shpod:lpiot_20251104 --link /usr/share/bash-completion/* /usr/share/bash-completion


# ----- prerequisites for container.training labs
RUN pip install git+https://github.com/lilydjwg/pssh

# ----- GCloud SDK install
RUN <<EOT bash
    # Add distribution URI for GCloud SDK as a package source
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
    # Add Google Cloud public key
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
    sudo apt-get update -y
    sudo apt-get install -y google-cloud-sdk
    # sudo apt-get install -y kubectl
    sudo rm -Rf /usr/lib/google-cloud-sdk/platform/bundledpythonunix \
                ./.sdkman
EOT
