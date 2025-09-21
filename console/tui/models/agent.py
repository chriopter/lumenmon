"""Agent model for metrics and status tracking."""

from __future__ import annotations

import glob
import logging
import os
import time
from dataclasses import dataclass
from typing import Iterable, List, Optional, Tuple

from config import DATA_DIR

STALE_AGE_SENTINEL = 999.0
STATUS_GREEN_THRESHOLD = 5.0
STATUS_YELLOW_THRESHOLD = 30.0

LOGGER = logging.getLogger(__name__)


@dataclass(frozen=True)
class AgentSnapshot:
    """Represents a single row of agent metrics for the dashboard."""

    id: str
    cpu: Optional[float]
    cpu_age: float
    memory: Optional[float]
    mem_age: float
    disk: Optional[float]
    disk_age: float

    @property
    def freshest_age(self) -> float:
        """Return the most recent update age across the collected metrics."""

        return min(self.cpu_age, self.mem_age, self.disk_age)

    @property
    def status_color(self) -> str:
        """Provide a textual status colour based on freshness."""

        age = self.freshest_age
        if age < STATUS_GREEN_THRESHOLD:
            return "green"
        if age < STATUS_YELLOW_THRESHOLD:
            return "yellow"
        if age < STALE_AGE_SENTINEL:
            return "red"
        return "dim"


class Agent:
    """Represents a monitored agent residing in the on-disk data store."""

    def __init__(self, agent_id: str, data_dir: str = DATA_DIR):
        self.id = agent_id
        self.data_dir = data_dir
        self.path = f"{data_dir}/{agent_id}"

    @classmethod
    def get_all(cls, data_dir: str = DATA_DIR) -> List["Agent"]:
        """Find all registered agents ordered by identifier."""

        agents: List[Agent] = []
        for agent_dir in glob.glob(f"{data_dir}/id_*"):
            agent_name = os.path.basename(agent_dir)
            agents.append(cls(agent_name, data_dir))
        return sorted(agents, key=lambda agent: agent.id)

    def snapshot(self) -> AgentSnapshot:
        """Collect the latest metrics for this agent."""

        cpu_val, cpu_age = self.read_metric("generic_cpu.tsv")
        mem_val, mem_age = self.read_metric("generic_mem.tsv")
        disk_val, disk_age = self.read_metric("generic_disk.tsv")
        return AgentSnapshot(
            id=self.id,
            cpu=cpu_val,
            cpu_age=cpu_age,
            memory=mem_val,
            mem_age=mem_age,
            disk=disk_val,
            disk_age=disk_age,
        )

    def read_metric(self, metric_file: str) -> Tuple[Optional[float], float]:
        """Read the latest value from a metric file.

        Returns a tuple ``(value, age)`` where ``value`` is ``None`` when data is
        unavailable and ``age`` represents seconds since the last sample.
        """

        file_path = f"{self.path}/{metric_file}"
        if not os.path.exists(file_path):
            return None, STALE_AGE_SENTINEL

        try:
            with open(file_path, "r", encoding="utf-8") as handle:
                lines = handle.readlines()
        except (OSError, UnicodeDecodeError) as exc:
            LOGGER.debug("Failed to read metric file %s: %s", file_path, exc)
            return None, STALE_AGE_SENTINEL

        if not lines:
            return None, STALE_AGE_SENTINEL

        parts = lines[-1].strip().split()
        if len(parts) >= 3:
            try:
                timestamp = int(float(parts[0]))
                value = float(parts[2])
            except ValueError as exc:
                LOGGER.debug("Invalid metric data in %s: %s", file_path, exc)
                return None, STALE_AGE_SENTINEL
        elif len(parts) >= 2:
            try:
                timestamp = int(float(parts[0]))
                value = float(parts[1])
            except ValueError as exc:
                LOGGER.debug("Invalid legacy metric data in %s: %s", file_path, exc)
                return None, STALE_AGE_SENTINEL
        else:
            return None, STALE_AGE_SENTINEL

        age = max(0.0, time.time() - timestamp)
        return value, age
