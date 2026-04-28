# syntax=docker/dockerfile:1

ARG RUBY_VERSION=4.0.2

FROM node:22-slim AS css-builder
WORKDIR /build
COPY package.json package-lock.json ./
RUN npm ci
COPY app/assets/tailwind/ ./app/assets/tailwind/
RUN mkdir -p app/assets/stylesheets && npm run build

FROM ruby:${RUBY_VERSION}-slim

WORKDIR /app

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      bash \
      build-essential \
      ca-certificates \
      curl \
      gnupg \
      libyaml-dev \
      mosquitto \
      mosquitto-clients \
      netcat-traditional \
      openssl \
      pkg-config \
      procps \
      sqlite3 && \
    curl -1sLf https://dl.cloudsmith.io/public/caddy/stable/gpg.key | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg && \
    curl -1sLf https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt > /etc/apt/sources.list.d/caddy-stable.list && \
    apt-get update -qq && \
    apt-get install --no-install-recommends -y caddy && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* && \
    rm -f /etc/sysctl.d/caddy-sysctl.conf

ENV RAILS_ENV=production \
    RACK_ENV=production \
    BUNDLE_WITHOUT=development:test \
    RAILS_LOG_TO_STDOUT=1 \
    RAILS_SERVE_STATIC_FILES=1 \
    LUMENMON_DB_PATH=/data/lumenmon.sqlite3

COPY Gemfile Gemfile.lock* ./
RUN bundle install

COPY . .
COPY --from=css-builder /build/app/assets/stylesheets/application.css ./app/assets/stylesheets/application.css
COPY config/Caddyfile /etc/caddy/Caddyfile

RUN chmod +x console.sh core/setup/*.sh core/enrollment/*.sh script/*.rb

VOLUME /data

EXPOSE 8080 8443 8884 25

CMD ["./console.sh"]
