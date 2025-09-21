#!/bin/bash
# Deploy component

deploy_component() {
    echo ""
    echo "Installing $COMPONENT..."

    cd "$DIR/$COMPONENT"

    # Stop any existing container
    docker compose down 2>/dev/null

    # Use image or build
    if [ -n "$IMAGE" ]; then
        export LUMENMON_IMAGE="$IMAGE"
        docker compose up -d
    else
        docker compose up -d --build
    fi

    # Show success
    if [ "$COMPONENT" = "console" ]; then
        source "$DIR/installer/finish.sh"
    else
        echo "✓ Agent installed"
        echo ""
        echo "Register with: docker exec lumenmon-agent /app/core/setup/register.sh <invite_url>"
    fi
}