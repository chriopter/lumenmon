"""Monitoring service for refreshing data"""

from typing import List, Tuple
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from models import Agent, Invite


class MonitorService:
    """Handles data monitoring and refresh operations"""

    def __init__(self, data_dir: str = "/data/agents"):
        self.data_dir = data_dir

    def get_agents_data(self) -> List[dict]:
        """Get all agents with their current metrics"""
        agents = Agent.get_all(self.data_dir)
        data = []

        for agent in agents:
            cpu_val, cpu_age = agent.read_metric("generic_cpu.tsv")
            mem_val, mem_age = agent.read_metric("generic_mem.tsv")
            disk_val, disk_age = agent.read_metric("generic_disk.tsv")

            # Determine status based on most recent update
            min_age = min(cpu_age, mem_age, disk_age)
            status_color = agent.get_status_color(min_age)

            data.append({
                'id': agent.id,
                'status': status_color,
                'cpu': cpu_val,
                'cpu_age': cpu_age,
                'memory': mem_val,
                'mem_age': mem_age,
                'disk': disk_val,
                'disk_age': disk_age,
                'min_age': min_age
            })

        return data

    def get_invites_data(self) -> List[Invite]:
        """Get all active invites"""
        return Invite.get_active()