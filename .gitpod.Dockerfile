# -----------------------------------------------------------------------------
# Base install
# -----------------------------------------------------------------------------
FROM ubuntu:22.04 as base
LABEL maintainer="Ludovic Piot <ludovic.piot@thegaragebandofit.com>"

RUN apt-get update -y
RUN apt-get install -y wget unzip

# -----------------------------------------------------------------------------
# Starship in RUST
# source: https://starship.rs/
# -----------------------------------------------------------------------------
FROM rust:slim as starship
LABEL maintainer="Ludovic Piot <ludovic.piot@thegaragebandofit.com>"

RUN apt-get update -y
RUN apt-get install -y cmake
RUN cargo install starship --locked

# -----------------------------------------------------------------------------
# Digital Ocean
# -----------------------------------------------------------------------------
FROM base as do
LABEL maintainer="Ludovic Piot <ludovic.piot@thegaragebandofit.com>"

# Digital Ocean CLI vars
ARG DOCTL_VERSION=1.102.0

WORKDIR /usr/bin
RUN wget https://github.com/digitalocean/doctl/releases/download/v${DOCTL_VERSION}/doctl-${DOCTL_VERSION}-linux-amd64.tar.gz && \
    tar -xzf ./doctl-${DOCTL_VERSION}-linux-amd64.tar.gz && \
    rm -f ./doctl-${DOCTL_VERSION}-linux-amd64.tar.gz

# TODO: Add Digital Ocean CLI autocompletion in BASH

# -----------------------------------------------------------------------------
# Terraform
# -----------------------------------------------------------------------------
FROM base as tf
LABEL maintainer="Ludovic Piot <ludovic.piot@thegaragebandofit.com>"

# Terraform vars
ARG TERRAFORM_VERSION=1.6.6

# Terraform install
WORKDIR /usr/bin
RUN wget https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
    unzip ./terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
    rm -f ./terraform_${TERRAFORM_VERSION}_linux_amd64.zip

# Add Terraform autocompletion in BASH
RUN touch ~/.bashrc && \
    terraform --install-autocomplete

# -----------------------------------------------------------------------------
# Packer
# -----------------------------------------------------------------------------
FROM base as pac
LABEL maintainer="Ludovic Piot <ludovic.piot@thegaragebandofit.com>"

# Packer vars
ARG PACKER_VERSION=1.10.0

# Packer install
WORKDIR /usr/bin
RUN wget https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip && \
    unzip ./packer_${PACKER_VERSION}_linux_amd64.zip && \
    rm -f ./packer_${PACKER_VERSION}_linux_amd64.zip

# Add Packer autocompletion in BASH
RUN touch ~/.bashrc && \
    packer -autocomplete-install

# -----------------------------------------------------------------------------
# yq CLI tool
# more detail here: https://lindevs.com/install-yq-on-ubuntu/
# -----------------------------------------------------------------------------
# lpiot 2023-11-19: now retrieved from jpetazzo/shpod
# FROM base as yq
# LABEL maintainer="Ludovic Piot <ludovic.piot@thegaragebandofit.com>"

# RUN wget -qO /usr/bin/yq  https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 && \
#     chmod a+x /usr/bin/yq

# -----------------------------------------------------------------------------
# Final Image
# -----------------------------------------------------------------------------
FROM gitpod/workspace-full
# as gitpod_workspace_gcloud
LABEL maintainer="Ludovic Piot <ludovic.piot@thegaragebandofit.com>"

WORKDIR /home/gitpod

# Copy of RUST awesome CLI tools
COPY --from=starship /usr/local/cargo/bin/starship /usr/local/bin

# lpiot 2023-11-19: now retrieved from jpetazzo/shpod
# Copy lot of tools from jpetazzo/shpod
COPY --from=jpetazzo/shpod /usr/local/bin/crane /usr/local/bin
COPY --from=jpetazzo/shpod /usr/local/bin/helm /usr/local/bin
COPY --from=jpetazzo/shpod /usr/local/bin/httping /usr/local/bin
COPY --from=jpetazzo/shpod /usr/local/bin/jid /usr/local/bin
COPY --from=jpetazzo/shpod /usr/local/bin/k9s /usr/local/bin
COPY --from=jpetazzo/shpod /usr/local/bin/kapp /usr/local/bin
COPY --from=jpetazzo/shpod /usr/local/bin/kctx /usr/local/bin
COPY --from=jpetazzo/shpod /usr/local/bin/kns /usr/local/bin
COPY --from=jpetazzo/shpod /usr/local/bin/kube-linter /usr/local/bin
COPY --from=jpetazzo/shpod /usr/local/bin/kubent /usr/local/bin
COPY --from=jpetazzo/shpod /usr/local/bin/kubeseal /usr/local/bin
COPY --from=jpetazzo/shpod /usr/local/bin/kustomize /usr/local/bin
COPY --from=jpetazzo/shpod /usr/local/bin/ngrok /usr/local/bin
COPY --from=jpetazzo/shpod /usr/local/bin/popeye /usr/local/bin
COPY --from=jpetazzo/shpod /usr/local/bin/regctl /usr/local/bin
COPY --from=jpetazzo/shpod /usr/local/bin/setup-tailhist.sh /usr/local/bin
COPY --from=jpetazzo/shpod /usr/local/bin/ship /usr/local/bin
COPY --from=jpetazzo/shpod /usr/local/bin/skaffold /usr/local/bin
COPY --from=jpetazzo/shpod /usr/local/bin/stern /usr/local/bin
COPY --from=jpetazzo/shpod /usr/local/bin/tilt /usr/local/bin
COPY --from=jpetazzo/shpod /usr/local/bin/velero /usr/local/bin
COPY --from=jpetazzo/shpod /usr/local/bin/ytt /usr/local/bin
COPY --from=jpetazzo/shpod /usr/bin/yq /usr/bin
COPY --from=jpetazzo/shpod /usr/share/bash-completion/* /usr/share/bash-completion

COPY --from=do /usr/bin/doctl /usr/bin/doctl

COPY --from=tf /usr/bin/terraform /usr/bin/terraform
COPY --from=tf /root/.bashrc ./.bashrc_tf

COPY --from=pac /usr/bin/packer /usr/bin/packer
COPY --from=pac /root/.bashrc ./.bashrc_pac

RUN cat ./.bashrc_tf ./.bashrc_pac >> ./.bashrc

# ----- GCloud SDK install
RUN sudo apt-get update && \
    # Add pre-requisites
    sudo apt-get install -y apt-transport-https ca-certificates gnupg
    # Add distribution URI for GCloud SDK as a package source
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
    # Add Google Cloud public key
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add - && \
    sudo apt-get update && \
    sudo apt-get install -y google-cloud-sdk && \
    # sudo apt-get install -y kubectl && \
    sudo rm -Rf ./.sdkman

# lpiot 2023-11-19: now retrieved from jpetazzo/shpod
# # ----- Helm install
# # more details here: https://helm.sh/docs/intro/install/

# RUN curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

# # ----- Kustomize install
# # more detail here: https://kubectl.docs.kubernetes.io/installation/kustomize/

# RUN curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash && \
#     sudo mv kustomize /usr/local/bin

# ----- Flux install
# more detail here: https://fluxcd.io/docs/get-started/

RUN curl -s https://fluxcd.io/install.sh | bash

# ----- Kubectl install

RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl && \
    chmod +x ./kubectl && \
    sudo mv ./kubectl /usr/local/bin/kubectl

# ----- common tools install
RUN sudo apt-get update -y
RUN sudo apt-get install -y jq tmux vim
# lpiot 2023-11-19: now retrieved from jpetazzo/shpod
# COPY --from=yq /usr/bin/yq /usr/bin/yq

# ----- prerequisites for container.training labs
RUN pip install git+https://github.com/lilydjwg/pssh
