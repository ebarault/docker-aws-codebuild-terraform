FROM ubuntu:16.04

ARG TERRAFORM_VERSION=0.11.14
ARG TERRAGRUNT_VERSION=0.18.7
ARG NODE_VERSION=12.x
ARG AWSCLI_VERSION=1.16.200
ARG GITLFS_VERSION=2.7.2
ARG ANSIBLE_VERSION=2.8.2

ENV DOCKER_VERSION="18.09.8" \
    DIND_COMMIT="37498f009d8bf25fbb6199e8ccd34bed84f2874b" \
    DOCKER_COMPOSE_VERSION="1.24.1"

RUN apt-get update && \
    # Install add-apt-repository
    apt-get install -y --no-install-recommends \
      software-properties-common && \
    # Update git and install utils
    add-apt-repository ppa:git-core/ppa && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      wget curl git openssh-client jq python python-dev build-essential make \
      ca-certificates tar gzip zip unzip bzip2 gettext-base rsync && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean

# Install Nodejs
RUN curl -sL https://deb.nodesource.com/setup_"$NODE_VERSION" | bash -
RUN apt-get install -y --no-install-recommends nodejs

# Install Yarn
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
    apt-get update && \
    apt-get install yarn

# Install pip
RUN wget "https://bootstrap.pypa.io/get-pip.py" -O /tmp/get-pip.py && \
    python /tmp/get-pip.py

# Install Ansible
RUN pip install "ansible==$ANSIBLE_VERSION"

# Install boto and boto3
# boto is installed from maishsk:develop until https://github.com/boto/boto/pull/3794 is merged
RUN pip install boto3 && \
    git clone -b develop https://github.com/maishsk/boto.git && \
    cd boto && \
    python setup.py install

# Install AWS CLI
RUN pip install awscli=="$AWSCLI_VERSION" && \
    rm -fr /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install AWS ELASTIC BEANSTALK CLI
RUN pip install awsebcli --upgrade

# Install Terraform
RUN curl -sL https://releases.hashicorp.com/terraform/"$TERRAFORM_VERSION"/terraform_"$TERRAFORM_VERSION"_linux_amd64.zip -o terraform_"$TERRAFORM_VERSION"_linux_amd64.zip && \
    unzip terraform_"$TERRAFORM_VERSION"_linux_amd64.zip -d /usr/bin && \
    chmod +x /usr/bin/terraform

# Install Terragrunt
RUN curl -sL https://github.com/gruntwork-io/terragrunt/releases/download/v"$TERRAGRUNT_VERSION"/terragrunt_linux_amd64 -o /usr/bin/terragrunt && \
    chmod +x /usr/bin/terragrunt

# Install Git LFS
RUN curl -sL https://github.com/git-lfs/git-lfs/releases/download/v"$GITLFS_VERSION"/git-lfs-linux-amd64-v"$GITLFS_VERSION".tar.gz -o gitlfs.tar.gz && \
    mkdir -p gitlfs && \
    tar --extract --file gitlfs.tar.gz --directory gitlfs && \
    chmod +x gitlfs/install.sh && \
    ./gitlfs/install.sh

# Install Splitsh
RUN curl -L https://github.com/splitsh/lite/releases/download/v1.0.1/lite_linux_amd64.tar.gz > splitsh.tar.gz && \
    tar -xf splitsh.tar.gz && \
    mv splitsh-lite /usr/bin/splitsh && \
    rm splitsh.tar.gz

# Install yq
RUN pip install yq


# From docker:18.09.08
RUN set -eux; \
	wget -O docker.tgz "https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz"; \
	tar --extract \
		--file docker.tgz \
		--strip-components 1 \
		--directory /usr/local/bin/ \
	; \
	rm docker.tgz; \
	\
	dockerd --version; \
	docker --version

# From docker dind 18.09.08
# https://github.com/docker/docker/blob/master/project/PACKAGERS.md#runtime-dependencies
RUN set -eux; \
  apt-get update && \
	apt-get install -y --no-install-recommends \
		btrfs-tools \
		e2fsprogs \
		iptables \
		openssl \
		xfsprogs \
		xz-utils \
# pigz: https://github.com/moby/moby/pull/35697 (faster gzip implementation)
		pigz

# set up subuid/subgid so that "--userns-remap=default" works out-of-the-box
RUN set -x \
	&& addgroup dockremap \
	&& useradd -g dockremap dockremap \
	&& echo 'dockremap:165536:65536' >> /etc/subuid \
	&& echo 'dockremap:165536:65536' >> /etc/subgid

# https://github.com/docker/docker/tree/master/hack/dind
ENV DIND_COMMIT 37498f009d8bf25fbb6199e8ccd34bed84f2874b

RUN set -eux; \
	wget -O /usr/local/bin/dind "https://raw.githubusercontent.com/docker/docker/${DIND_COMMIT}/hack/dind"; \
	chmod +x /usr/local/bin/dind

# Install Docker with dind support
COPY dockerd-entrypoint.sh /usr/local/bin/

VOLUME /var/lib/docker
EXPOSE 2375 2376

ENTRYPOINT ["dockerd-entrypoint.sh"]
CMD ["sh"]
