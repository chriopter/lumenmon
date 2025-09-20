"""Agent model for metrics and status tracking"""

import os
import glob
import time
from typing import Optional, Tuple, List


class Agent:
    """Represents a monitored agent"""

    def __init__(self, agent_id: str, data_dir: str = "/data/agents"):
        self.id = agent_id
        self.data_dir = data_dir
        self.path = f"{data_dir}/{agent_id}"

    @classmethod
    def get_all(cls, data_dir: str = "/data/agents") -> List['Agent']:
        """Find all registered agents"""
        agents = []
        for agent_dir in glob.glob(f"{data_dir}/id_*"):
            agent_name = os.path.basename(agent_dir)
            agents.append(cls(agent_name, data_dir))
        return sorted(agents, key=lambda a: a.id)

    def read_metric(self, metric_file: str) -> Tuple[Optional[float], float]:
        """Read the latest value from a metric file
        Returns: (value, age_in_seconds)
        """
        file_path = f"{self.path}/{metric_file}"
        if not os.path.exists(file_path):
            return None, 999

        try:
            with open(file_path, 'r') as f:
                lines = f.readlines()
                if lines:
                    # Format: timestamp interval value
                    parts = lines[-1].strip().split()
                    if len(parts) >= 3:
                        timestamp = int(parts[0])
                        value = float(parts[2])
                        age = time.time() - timestamp
                        return value, age
                    elif len(parts) >= 2:
                        # Legacy format
                        timestamp = int(parts[0])
                        value = float(parts[1])
                        age = time.time() - timestamp
                        return value, age
        except:
            pass
        return None, 999

    def get_status_color(self, age: float) -> str:
        """Get status color based on metric age"""
        if age < 5:
            return "green"
        elif age < 30:
            return "yellow"
        elif age < 999:
            return "red"
        return "dim"