#!/bin/bash
# Reports agent version from git tag/commit.
# Publishes at REPORT interval (1hr).

METRIC="generic_agent_version"
TYPE="TEXT"

source "$LUMENMON_HOME/core/mqtt/publish.sh"

while true; do
    # Get version from git (tag or commit hash)
    version=$(git -C "$LUMENMON_HOME" describe --tags --always 2>/dev/null || echo "unknown")

    publish_metric "$METRIC" "$version" "$TYPE" "$REPORT"
    [ "${LUMENMON_TEST_MODE:-}" = "1" ] && exit 0

    sleep $REPORT
done
