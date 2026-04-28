# syntax=docker/dockerfile:1
# check=error=true

ARG RUBY_VERSION=4.0.2

FROM node:22-slim AS css-builder
WORKDIR /build

COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci

COPY app/assets/tailwind/ ./app/assets/tailwind/
RUN mkdir -p app/assets/stylesheets && npm run build

FROM docker.io/library/ruby:${RUBY_VERSION}-slim AS base
WORKDIR /app

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      bash \
      ca-certificates \
      curl \
      gnupg \
      libjemalloc2 \
      mosquitto \
      mosquitto-clients \
      netcat-traditional \
      openssl \
      procps \
      sqlite3 && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    curl -1sLf https://dl.cloudsmith.io/public/caddy/stable/gpg.key | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg && \
    curl -1sLf https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt > /etc/apt/sources.list.d/caddy-stable.list && \
    apt-get update -qq && \
    apt-get install --no-install-recommends -y caddy && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* && \
    rm -f /etc/sysctl.d/caddy-sysctl.conf

ENV RAILS_ENV="production" \
    RACK_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_JOBS="4" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    RAILS_LOG_TO_STDOUT="1" \
    RAILS_SERVE_STATIC_FILES="1" \
    LUMENMON_DB_PATH="/data/lumenmon.sqlite3" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"

FROM base AS build

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

COPY Gemfile Gemfile.lock ./
RUN --mount=type=cache,target=/usr/local/bundle/cache \
    bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile -j 1 --gemfile

COPY . .
COPY --from=css-builder /build/app/assets/stylesheets/application.css ./app/assets/stylesheets/application.css

RUN SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile

RUN --mount=type=cache,target=/tmp/bootsnap-cache \
    bundle exec bootsnap precompile -j 1 app/ lib/

FROM base

COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /app /app
COPY config/Caddyfile /etc/caddy/Caddyfile

RUN chmod +x bin/docker-entrypoint console.sh core/setup/*.sh core/enrollment/*.sh script/*.rb

VOLUME /data

EXPOSE 8080 8443 8884

ENTRYPOINT ["/app/bin/docker-entrypoint"]
CMD ["./console.sh"]
