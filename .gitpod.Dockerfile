# syntax=docker/dockerfile:1.7-labs
# lpiot-20240831: specific syntax needed for COPY --exclude feature

# -----------------------------------------------------------------------------
# Common ARGs
# -----------------------------------------------------------------------------

ARG DOCKER_IMAGES_MAINTAINER="Ludovic Piot <ludovic.piot@thegaragebandofit.com>"

# For consistency purpose, please use the same base as gitpod/workspace-full image
# see: https://github.com/gitpod-io/workspace-images
ARG BASE_IMAGE=ubuntu:22.04
# ARG GITPOD_IMAGE=gitpod/workspace-python-3.12
ARG GITPOD_IMAGE=gitpod/workspace-full

# Mozilla SOPS release version
ARG SOPS_VERSION=3.9.0

# Digital Ocean CLI release version
ARG DOCTL_VERSION=1.111.0

# Hugo Statis Site Generator
ARG HUGO_VERSION=0.134.0

# Packer release version
ARG PACKER_VERSION=1.11.2

# Terraform release version
ARG TERRAFORM_VERSION=1.9.5


# -----------------------------------------------------------------------------
# Base install
# -----------------------------------------------------------------------------
FROM ${BASE_IMAGE} as base

ARG DOCKER_IMAGES_MAINTAINER

LABEL maintainer=${DOCKER_IMAGES_MAINTAINER}

RUN apt-get update -y && \
    apt-get install -y curl unzip upx wget


# -----------------------------------------------------------------------------
# Hugo
# -----------------------------------------------------------------------------
FROM base AS hugo

ARG DOCKER_IMAGES_MAINTAINER
ARG HUGO_VERSION

LABEL maintainer=${DOCKER_IMAGES_MAINTAINER}
        
RUN <<EOF bash
    wget https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_${HUGO_VERSION}_linux-amd64.tar.gz
    tar -xzf hugo_${HUGO_VERSION}_linux-amd64.tar.gz
    cp -pr hugo /usr/local/bin/
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

    # Compress binaries
    #upx /usr/local/bin/starship
EOF


# -----------------------------------------------------------------------------
# Mozilla SOPS & AGE
# -----------------------------------------------------------------------------
FROM base as sops

ARG DOCKER_IMAGES_MAINTAINER
ARG SOPS_VERSION

LABEL maintainer=${DOCKER_IMAGES_MAINTAINER}

# Install AGE
RUN <<EOF bash
    apt-get install -y age
    wget https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.linux.amd64
    mv sops-v${SOPS_VERSION}.linux.amd64 /usr/local/bin/sops
    chmod +x /usr/local/bin/sops

    # Compress binaries
    upx /usr/bin/age
    upx /usr/local/bin/sops
EOF

# -----------------------------------------------------------------------------
# Digital Ocean
# -----------------------------------------------------------------------------
FROM base as do

ARG DOCKER_IMAGES_MAINTAINER
ARG DOCTL_VERSION

LABEL maintainer=${DOCKER_IMAGES_MAINTAINER}

WORKDIR /usr/bin
RUN <<EOF bash
    wget https://github.com/digitalocean/doctl/releases/download/v${DOCTL_VERSION}/doctl-${DOCTL_VERSION}-linux-amd64.tar.gz
    tar -xzf ./doctl-${DOCTL_VERSION}-linux-amd64.tar.gz
    rm -f ./doctl-${DOCTL_VERSION}-linux-amd64.tar.gz

    # Compress binaries
    upx /usr/bin/doctl
    # Add Digital Ocean CLI autocompletion in BASH
    ./doctl completion bash > ~/completion_doctl.sh
EOF


# -----------------------------------------------------------------------------
# Scaleway
# -----------------------------------------------------------------------------
FROM base as scw

ARG DOCKER_IMAGES_MAINTAINER

LABEL maintainer=${DOCKER_IMAGES_MAINTAINER}

RUN <<EOF bash
    curl -s https://raw.githubusercontent.com/scaleway/scaleway-cli/master/scripts/get.sh | sh

    # Compress binaries
    upx /usr/local/bin/scw
EOF


# -----------------------------------------------------------------------------
# Terraform
# -----------------------------------------------------------------------------
FROM base as tf

ARG DOCKER_IMAGES_MAINTAINER
ARG TERRAFORM_VERSION

LABEL maintainer=${DOCKER_IMAGES_MAINTAINER}

# Terraform install
WORKDIR /usr/bin
RUN <<EOF bash
    wget https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
    unzip ./terraform_${TERRAFORM_VERSION}_linux_amd64.zip
    rm -f ./terraform_${TERRAFORM_VERSION}_linux_amd64.zip

    # Compress binaries
    upx /usr/local/bin/terraform
 
    # Add Terraform autocompletion in BASH
    touch ~/.bashrc
    terraform --install-autocomplete
EOF


# -----------------------------------------------------------------------------
# Packer
# -----------------------------------------------------------------------------
FROM base as pac

ARG DOCKER_IMAGES_MAINTAINER
ARG PACKER_VERSION

LABEL maintainer=${DOCKER_IMAGES_MAINTAINER}

# Packer install
WORKDIR /usr/bin
RUN <<EOF bash
    wget https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip
    unzip ./packer_${PACKER_VERSION}_linux_amd64.zip
    rm -f ./packer_${PACKER_VERSION}_linux_amd64.zip

    # Compress binaries
    upx /usr/local/bin/packer

    Add Packer autocompletion in BASH
    touch ~/.bashrc
    packer -autocomplete-install
EOF


# -----------------------------------------------------------------------------
# jpetazzo/shpod
# -----------------------------------------------------------------------------
FROM jpetazzo/shpod as shpod

ARG DOCKER_IMAGES_MAINTAINER

RUN <<EOF bash
    apk add upx
    upx /usr/local/bin/*
    upx /usr/bin/yq
EOF


# -----------------------------------------------------------------------------
# yq CLI tool
# more detail here: https://lindevs.com/install-yq-on-ubuntu/
# -----------------------------------------------------------------------------
# lpiot 2023-11-19: now retrieved from jpetazzo/shpod
# FROM base as yq
# 
# ARG DOCKER_IMAGES_MAINTAINER
# 
# LABEL maintainer=${DOCKER_IMAGES_MAINTAINER}
# 
# RUN wget -qO /usr/bin/yq  https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 && \
#     chmod a+x /usr/bin/yq


# -----------------------------------------------------------------------------
# Final Image(s)
# -----------------------------------------------------------------------------
FROM ${GITPOD_IMAGE} as gitpod_workspace

ARG DOCKER_IMAGES_MAINTAINER

LABEL maintainer=${DOCKER_IMAGES_MAINTAINER}

WORKDIR /home/gitpod

# Copy of RUST awesome CLI tools
COPY --from=starship --link /usr/local/bin/starship /usr/local/bin/
# TODO: switch this part into starship build stage
RUN starship init bash > ./.bashrc.d/completion_starship.sh

# Copy of Mozilla SOPS
COPY --from=sops --link /usr/bin/age /usr/local/bin
COPY --from=sops --link /usr/local/bin/sops /usr/local/bin

# Copy of Digital Ocean CLI
COPY --from=do --link /usr/bin/doctl /usr/bin/doctl
COPY --from=do --link /root/completion_doctl.sh ./.bashrc.d/

# Copy of Hugo Static Site Generator
COPY --from=hugo --link /usr/local/bin/hugo /usr/local/bin

# Copy of Scaleway CLI
COPY --from=scw --link /usr/local/bin/scw /usr/bin/scw
RUN scw autocomplete script shell=bash > ./.bashrc.d/completion_scw.sh

# Copy of Terraform
COPY --from=tf --link /usr/bin/terraform /usr/bin/terraform
COPY --from=tf --link /root/.bashrc ./.bashrc.d/completion_terraform.sh

# Copy of Packer
COPY --from=pac --link /usr/bin/packer /usr/bin/packer
COPY --from=pac --link /root/.bashrc  ./.bashrc.d/completion_packer.sh

# lpiot 2023-11-19: now retrieved from jpetazzo/shpod
# Copy lot of tools from jpetazzo/shpod
# TODO: get an always up-to-date shpod
COPY --from=shpod --link --exclude=/usr/local/bin/docker-compose /usr/local/bin/* /usr/local/bin
COPY --from=shpod --link /usr/bin/yq /usr/bin
COPY --from=shpod --link /usr/share/bash-completion/* /usr/share/bash-completion

# ----- common tools install
RUN <<EOF bash
    sudo apt-get update -y
    sudo apt-get install -y jq tmux vim \
         apt-transport-https ca-certificates gnupg
EOF

# lpiot 2023-11-19: now retrieved from jpetazzo/shpod
# COPY --from=yq --link /usr/bin/yq /usr/bin/yq

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
