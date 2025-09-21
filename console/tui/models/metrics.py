"""Metrics reading and history tracking."""

from __future__ import annotations

import glob
import logging
import os
from typing import Iterable, List

from config import DATA_DIR


LOGGER = logging.getLogger(__name__)


class MetricsReader:
    """Handles reading and processing metric files."""

    @staticmethod
    def get_history(
        agent_id: str,
        metric_file: str,
        points: int = 60,
        data_dir: str = DATA_DIR,
    ) -> List[float]:
        """Return the most recent values for a metric as floats."""

        file_path = f"{data_dir}/{agent_id}/{metric_file}"
        if not os.path.exists(file_path):
            return []

        try:
            with open(file_path, "r", encoding="utf-8") as handle:
                lines = handle.readlines()
        except (OSError, UnicodeDecodeError) as exc:
            LOGGER.debug("Unable to read metric history %s: %s", file_path, exc)
            return []

        values: List[float] = []
        for line in lines[-points:]:
            parts = line.strip().split()
            try:
                if len(parts) >= 3:
                    values.append(float(parts[2]))
                elif len(parts) >= 2:
                    values.append(float(parts[1]))
            except ValueError:
                continue
        return values

    @staticmethod
    def get_all_metrics(agent_id: str, data_dir: str = DATA_DIR) -> List[str]:
        """Return every metric filename available for the agent."""

        agent_dir = f"{data_dir}/{agent_id}"
        if not os.path.exists(agent_dir):
            return []

        metrics = [os.path.basename(path) for path in glob.glob(f"{agent_dir}/*.tsv")]
        return sorted(metrics)
