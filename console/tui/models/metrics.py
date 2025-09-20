"""Metrics reading and history tracking"""

import os
import glob
from typing import List, Optional


class MetricsReader:
    """Handles reading and processing metric files"""

    @staticmethod
    def get_history(agent_id: str, metric_file: str, points: int = 60, data_dir: str = "/data/agents") -> List[float]:
        """Get metric history for graphs"""
        file_path = f"{data_dir}/{agent_id}/{metric_file}"
        if not os.path.exists(file_path):
            return []

        try:
            with open(file_path, 'r') as f:
                lines = f.readlines()
                values = []
                for line in lines[-points:]:
                    parts = line.strip().split()
                    if len(parts) >= 3:
                        values.append(float(parts[2]))
                    elif len(parts) >= 2:
                        values.append(float(parts[1]))
                return values
        except:
            return []

    @staticmethod
    def get_all_metrics(agent_id: str, data_dir: str = "/data/agents") -> List[str]:
        """Get all available metrics for an agent"""
        metrics = []
        agent_dir = f"{data_dir}/{agent_id}"
        if os.path.exists(agent_dir):
            for file in glob.glob(f"{agent_dir}/*.tsv"):
                metrics.append(os.path.basename(file))
        return sorted(metrics)