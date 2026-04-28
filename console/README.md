# Lumenmon Console

Rails 8 based console packaged as a single container. The image starts:

- Rails on an internal Puma port
- Caddy on `8080` and `8443`
- Mosquitto MQTT on `8884`
- Ruby MQTT ingest into SQLite

Persistent data lives in `/data`.

## Run With Docker Compose

```sh
mkdir -p lumenmon-console
cd lumenmon-console
curl -fsSLO https://raw.githubusercontent.com/chriopter/lumenmon/main/console/docker-compose.yml
printf 'CONSOLE_HOST=%s\n' "your-hostname-or-ip" > .env
docker compose up -d
```

Open `http://your-hostname-or-ip:8080`.

Generate an agent invite:

```sh
docker exec lumenmon-console /app/core/enrollment/invite_create.sh
```

Update:

```sh
docker compose pull
docker compose up -d
```

Stop without deleting data:

```sh
docker compose down
```

The optional `console/install.sh` only wraps this compose flow for convenience.

## Local Build

```sh
docker build -t test-console:ci ./console
```

Tailwind CSS is built in the Docker build using Tailwind v4 from `package-lock.json`.
