"""Clipboard operations for copying invite URLs"""

import subprocess
from typing import Optional


class ClipboardService:
    """Handles clipboard operations across platforms"""

    @staticmethod
    def copy(text: str, app=None) -> bool:
        """
        Copy text to clipboard using multiple methods
        Returns True if successful
        """
        # Method 1: Try Textual's built-in OSC 52 clipboard
        if app:
            try:
                app.copy_to_clipboard(text)
                return True
            except:
                pass

        # Method 2: Try pyperclip for broader support
        try:
            import pyperclip
            pyperclip.copy(text)
            return True
        except ImportError:
            pass
        except Exception:
            # Pyperclip exception (no clipboard mechanism)
            pass

        # Method 3: Direct system commands
        # Try xclip (Linux)
        try:
            proc = subprocess.Popen(['xclip', '-selection', 'clipboard'],
                                  stdin=subprocess.PIPE,
                                  stdout=subprocess.DEVNULL,
                                  stderr=subprocess.DEVNULL)
            proc.communicate(input=text.encode())
            if proc.returncode == 0:
                return True
        except:
            pass

        # Try pbcopy (macOS)
        try:
            proc = subprocess.Popen(['pbcopy'],
                                  stdin=subprocess.PIPE,
                                  stdout=subprocess.DEVNULL,
                                  stderr=subprocess.DEVNULL)
            proc.communicate(input=text.encode())
            if proc.returncode == 0:
                return True
        except:
            pass

        return False

    @staticmethod
    def save_fallback(text: str, filename: str = '/tmp/lumenmon_invite.txt') -> bool:
        """Save text to file as fallback when clipboard unavailable"""
        try:
            with open(filename, 'w') as f:
                f.write(text)
            return True
        except:
            return False