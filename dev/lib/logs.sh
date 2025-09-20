#!/bin/bash
# Show container logs

CONTAINER="${1:-console}"
docker logs -f lumenmon-$CONTAINER