"""Invite model for managing registration invites."""

from __future__ import annotations

import logging
import os
import subprocess
import time
from dataclasses import dataclass
from typing import List, Optional

from config import SSH_DIR


LOGGER = logging.getLogger(__name__)
INVITE_PREFIX = "reg_"
INVITE_MAX_AGE_MS = 5 * 60 * 1000  # five minutes
PASSWORD_TEMPLATE = "/tmp/.invite_{username}"
HOST_KEY_PATH = os.environ.get("LUMENMON_HOST_KEY_PATH", os.path.join(SSH_DIR, "ssh_host_ed25519_key.pub"))


@dataclass
class Invite:
    """Represents a registration invite."""

    username: str
    expires: int  # seconds until expiry
    password: Optional[str] = None
    url: Optional[str] = None

    @classmethod
    def get_active(cls) -> List["Invite"]:
        """Return all invites that have not yet expired."""

        invites: List[Invite] = []
        now_ms = int(time.time() * 1000)

        try:
            result = subprocess.run(["getent", "passwd"], capture_output=True, text=True, check=False)
        except OSError as exc:  # pragma: no cover - defensive (system call failure)
            LOGGER.debug("getent invocation failed: %s", exc)
            return invites

        for line in result.stdout.splitlines():
            if not line.startswith(INVITE_PREFIX):
                continue

            username = line.split(":", 1)[0]
            try:
                timestamp = int(username[len(INVITE_PREFIX):])
            except ValueError:
                continue

            age_ms = now_ms - timestamp
            if age_ms >= INVITE_MAX_AGE_MS:
                continue

            expires_sec = (INVITE_MAX_AGE_MS - age_ms) // 1000
            invite = cls(username=username, expires=expires_sec)
            invite.load_password()
            invite.build_url()
            invites.append(invite)

        return invites

    def load_password(self) -> None:
        """Load the plain text password for this invite from disk."""

        password_file = PASSWORD_TEMPLATE.format(username=self.username)
        if not os.path.exists(password_file):
            return

        try:
            with open(password_file, "r", encoding="utf-8") as handle:
                self.password = handle.read().strip()
        except (OSError, UnicodeDecodeError) as exc:
            LOGGER.debug("Failed to read invite password for %s: %s", self.username, exc)

    def build_url(self) -> None:
        """Build the SSH invite URL if the password is known."""

        if not self.password:
            return

        host_key = "<HOST_KEY>"
        try:
            with open(HOST_KEY_PATH, "r", encoding="utf-8") as handle:
                parts = handle.read().strip().split()
        except (OSError, UnicodeDecodeError) as exc:
            LOGGER.debug("Could not read host key: %s", exc)
            parts = []

        if len(parts) >= 2:
            host_key = f"{parts[0]}_{parts[1]}"

        self.url = f"ssh://{self.username}:{self.password}@localhost:2345/#{host_key}"

    @staticmethod
    def create() -> Optional[str]:
        """Create a new registration invite via the enrollment script."""

        try:
            result = subprocess.run(
                ["/app/core/enrollment/invite_create.sh"],
                capture_output=True,
                text=True,
                check=False,
            )
        except OSError as exc:  # pragma: no cover - defensive
            LOGGER.debug("invite_create.sh failed to execute: %s", exc)
            return None

        if result.returncode != 0:
            LOGGER.debug("invite_create.sh exited with %s: %s", result.returncode, result.stderr.strip())
            return None

        for line in result.stdout.splitlines():
            if line.startswith("ssh://"):
                return line.strip()

        return None
