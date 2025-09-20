"""Invite model for managing registration invites"""

import os
import time
import subprocess
from typing import List, Dict, Optional


class Invite:
    """Represents a registration invite"""

    def __init__(self, username: str, expires: int):
        self.username = username
        self.expires = expires  # seconds until expiry
        self.password = None
        self.url = None

    @classmethod
    def get_active(cls) -> List['Invite']:
        """Get list of active invites"""
        invites = []
        try:
            result = subprocess.run(['getent', 'passwd'], capture_output=True, text=True)
            current_ms = int(time.time() * 1000)

            for line in result.stdout.splitlines():
                if line.startswith('reg_'):
                    user = line.split(':')[0]
                    timestamp = int(user[4:])
                    age_ms = current_ms - timestamp
                    if age_ms < 300000:  # 5 minutes
                        expires_sec = (300000 - age_ms) // 1000
                        invite = cls(user, expires_sec)
                        invite.load_password()
                        invite.build_url()
                        invites.append(invite)
        except:
            pass
        return invites

    def load_password(self):
        """Load plain text password from temp file"""
        password_file = f"/tmp/.invite_{self.username}"
        if os.path.exists(password_file):
            try:
                with open(password_file, 'r') as f:
                    self.password = f.read().strip()
            except:
                pass

    def build_url(self):
        """Build the SSH invite URL"""
        if not self.password:
            return

        # Get ED25519 host key
        host_key = "<HOST_KEY>"
        try:
            with open('/data/ssh/ssh_host_ed25519_key.pub', 'r') as f:
                key_content = f.read().strip()
                parts = key_content.split()
                if len(parts) >= 2:
                    host_key = f"{parts[0]}_{parts[1]}"
        except:
            pass

        self.url = f"ssh://{self.username}:{self.password}@localhost:2345/#{host_key}"

    @staticmethod
    def create() -> Optional[str]:
        """Create a new registration invite"""
        try:
            result = subprocess.run(
                ['/app/core/enrollment/invite_create.sh'],
                capture_output=True,
                text=True
            )
            if result.returncode == 0:
                # Parse the URL from output
                for line in result.stdout.splitlines():
                    if line.startswith('ssh://'):
                        return line.strip()
        except:
            pass
        return None