FROM ubuntu:16.04

ARG TERRAFORM_VERSION=0.11.14
ARG TERRAGRUNT_VERSION=0.18.7
ARG NODE_VERSION=12.x

# last version to support python 2.7
ARG AWSCLI_VERSION=1.19.112
# botocore requirement >=1.21.0,<1.22.0
ARG AWSEBCLI_VERSION=3.20.0

ARG GITLFS_VERSION=2.7.2
ARG ANSIBLE_VERSION=2.8.2

# https://github.com/docker/docker/tree/master/hack/dind
ENV DOCKER_VERSION="23.0.5" \
    DIND_COMMIT="1f32e3c95d72a29b3eaacba156ed675dba976cb5" \
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
      ca-certificates tar gzip zip unzip bzip2 gettext-base rsync \
      gconf-service libasound2 libatk1.0-0 libc6 libcairo2 libcups2 \
      libdbus-1-3 libexpat1 libfontconfig1 libgcc1 libgconf-2-4 libgdk-pixbuf2.0-0 \
      libglib2.0-0 libgtk-3-0 libnspr4 libpango-1.0-0 libpangocairo-1.0-0 libstdc++6 \
      libx11-6 libx11-xcb1 libxcb1 libxcomposite1 libxcursor1 libxdamage1 libxext6 libxfixes3 \
      libxi6 libxrandr2 libxrender1 libxss1 libxtst6 fonts-liberation \
      libappindicator1 libnss3 libffi-dev libssl-dev \
      lsb-release xdg-utils wget locales && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean

# Set the locale
RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen
ENV LANG en_US.UTF-8  
ENV LANGUAGE en_US:en  
ENV LC_ALL en_US.UTF-8

# Install Nodejs
RUN curl -sL https://deb.nodesource.com/setup_"$NODE_VERSION" | bash -
RUN apt-get install -y --no-install-recommends nodejs

# Install Yarn
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
    apt-get update && \
    apt-get install yarn

# Install pip
RUN wget "https://bootstrap.pypa.io/pip/2.7/get-pip.py" -O /tmp/get-pip.py && \
    python /tmp/get-pip.py

# RUN pip install cryptography==2.8
RUN pip install cryptography==3.1.1

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
RUN pip install awsebcli=="$AWSEBCLI_VERSION" && \
    rm -fr /var/lib/apt/lists/* /tmp/* /var/tmp/*

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

RUN set -eux; \
	wget -O /usr/local/bin/dind "https://raw.githubusercontent.com/docker/docker/${DIND_COMMIT}/hack/dind"; \
	chmod +x /usr/local/bin/dind

# Install Docker with dind support
COPY dockerd-entrypoint.sh /usr/local/bin/

VOLUME /var/lib/docker
EXPOSE 2375 2376

ENTRYPOINT ["dockerd-entrypoint.sh"]
CMD ["sh"]
