# Build release for Ubuntu 24.04
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Install dependencies
RUN apt-get update && apt-get install -y \
    locales \
    curl \
    git \
    build-essential \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# Install Erlang
RUN apt-get update && apt-get install -y \
    erlang \
    && rm -rf /var/lib/apt/lists/*

# Install Elixir
RUN apt-get update && apt-get install -y \
    elixir \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js for assets
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Copy project files
COPY . .

# Build release
ENV MIX_ENV=prod
RUN mix local.hex --force \
    && mix local.rebar --force \
    && mix deps.get --only prod \
    && mix compile \
    && mix assets.deploy \
    && mix release

# Output path
CMD ["tar", "czf", "/build/medoru_ubuntu_release.tar.gz", "-C", "/build/_build/prod/rel", "medoru"]
