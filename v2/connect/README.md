Start the server (auto-approves clients and shows the latest CPU percentage from them):

docker compose -f docker-compose.server.yml up --build

The server window displays the most recent client ID plus a 0–100% bar that refreshes at 10 Hz. No manual approval required.

In another shell, stream metrics from the client container:

docker compose -f docker-compose.client.yml run --build --rm client

Run both containers together (builds both images and streams until you stop it):

docker compose up --build

Stop the server with Ctrl+C. Remove the shared network afterwards if you like:

docker network rm connect-net
