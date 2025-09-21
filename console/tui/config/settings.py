"""Configuration settings for Lumenmon TUI."""

from __future__ import annotations

import os
from pathlib import Path


def _resolve_path(default_root: str, *parts: str) -> str:
    return str(Path(default_root).joinpath(*parts))


# Data directories -----------------------------------------------------------

DATA_ROOT = os.environ.get("LUMENMON_DATA_ROOT", "/data")
DATA_DIR = _resolve_path(DATA_ROOT, "agents")
SSH_DIR = _resolve_path(DATA_ROOT, "ssh")


# Timing configuration -------------------------------------------------------

REFRESH_RATE = 1  # seconds - Dashboard refresh rate
DETAIL_REFRESH_RATE = 0.5  # seconds - Detail view refresh rate for smooth graphs


# Display settings -----------------------------------------------------------

GRAPH_POINTS = 120  # Number of points in graphs
GRAPH_MIN_WIDTH = 20
GRAPH_MIN_HEIGHT = 10


# Invite settings ------------------------------------------------------------

INVITE_EXPIRE_TIME = 300  # 5 minutes in seconds
