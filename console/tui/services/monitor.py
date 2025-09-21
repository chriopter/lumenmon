"""Monitoring service for refreshing data."""

from __future__ import annotations

import logging
from typing import List

from config import DATA_DIR
from models import Agent, AgentSnapshot, Invite

LOGGER = logging.getLogger(__name__)


class MonitorService:
    """Handles filesystem-backed data retrieval for the TUI."""

    def __init__(self, data_dir: str = DATA_DIR):
        self.data_dir = data_dir

    def get_agents_data(self) -> List[AgentSnapshot]:
        """Return latest metrics for all discovered agents."""

        snapshots: List[AgentSnapshot] = []
        for agent in Agent.get_all(self.data_dir):
            try:
                snapshots.append(agent.snapshot())
            except Exception as exc:  # pragma: no cover - defensive
                LOGGER.debug("Failed to capture snapshot for %s: %s", agent.id, exc)
        return snapshots

    def get_invites_data(self) -> List[Invite]:
        """Return all currently active invites."""

        try:
            return Invite.get_active()
        except Exception as exc:  # pragma: no cover - defensive
            LOGGER.debug("Failed to load invites: %s", exc)
            return []
