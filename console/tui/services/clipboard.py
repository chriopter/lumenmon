"""Clipboard operations for copying invite URLs."""

from __future__ import annotations

import logging
import subprocess
from typing import Any


LOGGER = logging.getLogger(__name__)


class ClipboardService:
    """Handles clipboard operations across platforms."""

    @staticmethod
    def copy(text: str, app: Any = None) -> bool:
        """Copy ``text`` to the clipboard using a series of fallbacks."""

        if app is not None:
            try:
                app.copy_to_clipboard(text)
                return True
            except Exception as exc:  # pragma: no cover - clipboard support optional
                LOGGER.debug("OSC 52 clipboard copy failed: %s", exc)

        try:
            import pyperclip  # type: ignore
        except ImportError:
            pyperclip = None  # type: ignore

        if pyperclip is not None:
            try:
                pyperclip.copy(text)
                return True
            except pyperclip.PyperclipException as exc:  # type: ignore[attr-defined]
                LOGGER.debug("Pyperclip copy failed: %s", exc)

        if ClipboardService._copy_via_command(["xclip", "-selection", "clipboard"], text):
            return True
        if ClipboardService._copy_via_command(["pbcopy"], text):
            return True
        return False

    @staticmethod
    def _copy_via_command(command: list[str], text: str) -> bool:
        """Attempt to push ``text`` to the clipboard via an external command."""

        try:
            proc = subprocess.Popen(
                command,
                stdin=subprocess.PIPE,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        except OSError as exc:  # pragma: no cover - command absent
            LOGGER.debug("Clipboard command %s unavailable: %s", command[0], exc)
            return False

        proc.communicate(input=text.encode())
        success = proc.returncode == 0
        if not success:
            LOGGER.debug("Clipboard command %s exited with %s", command[0], proc.returncode)
        return success

    @staticmethod
    def save_fallback(text: str, filename: str = "/tmp/lumenmon_invite.txt") -> bool:
        """Persist ``text`` to ``filename`` as a last-resort clipboard mechanism."""

        try:
            with open(filename, "w", encoding="utf-8") as handle:
                handle.write(text)
            return True
        except OSError as exc:
            LOGGER.debug("Failed to persist invite fallback file %s: %s", filename, exc)
            return False
