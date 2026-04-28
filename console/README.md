# Lumenmon Console

Rails 8 based console packaged as a single container. The image starts:

- Rails on an internal Puma port
- Caddy on `8080` and `8443`
- Mosquitto MQTT on `8884`
- Ruby MQTT ingest into SQLite

Persistent data lives in `/data`.

## Run

```sh
docker run -d \
  --name lumenmon-console \
  --restart unless-stopped \
  -p 8080:8080 \
  -p 8443:8443 \
  -p 8884:8884 \
  -v lumenmon-data:/data \
  -e CONSOLE_HOST=your-hostname-or-ip \
  ghcr.io/chriopter/lumenmon-console:latest
```

Open `http://your-hostname-or-ip:8080`.

Generate an agent invite:

```sh
docker exec lumenmon-console /app/core/enrollment/invite_create.sh
```

## Local Build

```sh
docker build -t test-console:ci ./console
```

Tailwind CSS is built in the Docker build using Tailwind v4 from `package-lock.json`.
