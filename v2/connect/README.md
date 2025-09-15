Run both containers together:

docker compose up --build

Run individually:

# start server
docker compose -f docker-compose.server.yml up --build

# in another shell, run the client once
docker compose -f docker-compose.client.yml run --build --rm client

Stop server with Ctrl+C; remove network with `docker network rm connect-net` if needed.
