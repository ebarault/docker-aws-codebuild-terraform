FROM ubuntu:16.04

ARG TERRAFORM_VERSION=0.11.2
ARG TERRAGRUNT_VERSION=0.13.24
ARG NODE_VERSION=6.x
ARG AWSCLI_VERSION=1.14.24

RUN apt-get update && \
    # Install add-apt-repository
    apt-get install -y --no-install-recommends \
      software-properties-common && \
    # Update git and install utils
    add-apt-repository ppa:git-core/ppa && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      wget curl git openssh-client jq python make \
      ca-certificates tar gzip zip unzip && \
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

# Install AWS CLI
RUN wget "https://bootstrap.pypa.io/get-pip.py" -O /tmp/get-pip.py && \
    python /tmp/get-pip.py && \
    pip install awscli=="$AWSCLI_VERSION" && \
    rm -fr /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install AWS ELASTIC BEANSTALK CLI
RUN pip install awsebcli --upgrade --user

# Install Terraform
RUN curl -sL https://releases.hashicorp.com/terraform/"$TERRAFORM_VERSION"/terraform_"$TERRAFORM_VERSION"_linux_amd64.zip -o terraform_"$TERRAFORM_VERSION"_linux_amd64.zip && \
    unzip terraform_"$TERRAFORM_VERSION"_linux_amd64.zip -d /usr/bin && \
    chmod +x /usr/bin/terraform

# Install Terragrunt
RUN curl -sL https://github.com/gruntwork-io/terragrunt/releases/download/v"$TERRAGRUNT_VERSION"/terragrunt_linux_amd64 -o /usr/bin/terragrunt && \
    chmod +x /usr/bin/terragrunt

CMD [ "node" ]
