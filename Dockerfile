FROM ubuntu:20.04

# Use bash for the shell
SHELL [ "/usr/bin/bash", "-c" ]

RUN echo "Etc/UTC" > /etc/localtime && \
    apt update && \
    apt -y install build-essential bison ca-certificates curl dpkg-dev ffmpeg file gcc git imagemagick libffi-dev libgdbm-dev libicu66 libicu-dev libidn11 libidn11-dev libjemalloc2 libjemalloc-dev libncurses5-dev libpq5 libpq-dev libprotobuf17 libprotobuf-dev libreadline8 libreadline-dev libssl1.1 libssl-dev libyaml-0-2 libyaml-dev postgresql-client protobuf-compiler python tzdata wget whois zlib1g-dev

# Install Node v14 (LTS)
RUN curl -fsSL https://deb.nodesource.com/setup_14.x | bash - && \
    apt -y install nodejs && \
    npm install -g yarn

# Install Ruby
RUN RUBY_VER="2.7.2" && \
    wget -O - https://cache.ruby-lang.org/pub/ruby/${RUBY_VER%.*}/ruby-${RUBY_VER}.tar.gz | tar -xz && \
    cd ruby-${RUBY_VER} && \
    ./configure --with-jemalloc \
                --with-shared \
                --disable-install-doc && \
    make -j$(nproc) > /dev/null && \
    make install && \
    cd .. && rm -rf ruby-${RUBY_VER}

# Create the mastodon user
ARG UID=991
ARG GID=991
RUN addgroup --gid $GID mastodon && \
    mkdir -p /opt/mastodon && \
	useradd --shell /bin/bash -M -u $UID -g $GID -d /opt/mastodon mastodon && \
    passwd -d mastodon && \
    chown mastodon:mastodon /opt/mastodon && \
    apt -y install curl

ENV LOCAL_DOMAIN=example.com \
    NODE_ENV=production \
    OTP_SECRET='' \
    PATH="$PATH:/opt/mastodon/live/bin" \
    POSTGRES_DB=postgres \
    POSTGRES_HOST=localhost \
    POSTGRES_PORT=5432 \
    POSTGRES_USER=mastodon \
    POSTGRES_PASS='' \
    RAILS_ENV=production \
    RAILS_SERVE_STATIC_FILES="true" \
    REDIS_HOST=localhost \
    REDIS_PORT=6379 \
    REDIS_PASS='' \
    SECRET_KEY_BASE='' \
    SINGLE_USER_MODE=false \
    SMTP_SERVER=localhost \
    SMTP_PORT=25 \
    SMTP_AUTH_METHOD=none \
    SMTP_OPENSSL_VERIFY_MODE=none \
    SMTP_FROM_ADDRESS="Mastodon <notifications@example.com>" \
    VAPID_PRIVATE_KEY='' \
    VAPID_PUBLIC_KEY='' \
    WEB_DOMAIN=example.com

# Install s6-overlay
RUN S6_VERSION=2.2.0.3 && \
    curl -sL https://github.com/just-containers/s6-overlay/releases/download/v${S6_VERSION}/s6-overlay-amd64-installer > /tmp/s6-overlay-amd64-installer && \
    chmod +x /tmp/s6-overlay-amd64-installer && \
    /tmp/s6-overlay-amd64-installer / && \
    rm -rf /tmp/s6-overlay-amd64-installer

# Install mastodon
RUN cd /opt/mastodon && \
    touch /opt/mastodon/.upgrade && \
    git clone https://github.com/tootsuite/mastodon.git live && \
    cd live && \
    git checkout $(git tag -l | grep -v 'rc[0-9]*$' | sort -V | tail -n 1) && \
    bundle config deployment 'true' && \
    bundle config without 'development test' && \
    bundle install -j$(nproc) && \
    mkdir -p /opt/mastodon/.config/yarn/global/ && \
    ln -s /opt/mastodon/.yarnclean /opt/mastodon/.config/yarn/global/.yarnclean && \
    yarn install --pure-lockfile

# Cleanup
RUN chown -R mastodon:mastodon /opt/mastodon

VOLUME [ "/opt/mastodon/config/", "/opt/mastodon/live/public/system/" ]
COPY etc /etc
WORKDIR /opt/mastodon
ENTRYPOINT [ "/init" ]
EXPOSE 3000 4000