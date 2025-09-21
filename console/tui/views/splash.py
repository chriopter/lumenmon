"""Startup splash screen with logo and loading animation."""

from __future__ import annotations

import asyncio
from typing import List

from rich.text import Text
from textual.app import ComposeResult
from textual.containers import Container, Vertical
from textual.message import Message
from textual.reactive import reactive
from textual.widgets import Static


LUMENMON_LOGO = """
  ██╗     ██╗   ██╗███╗   ███╗███████╗███╗   ██╗███╗   ███╗ ██████╗ ███╗   ██╗
  ██║     ██║   ██║████╗ ████║██╔════╝████╗  ██║████╗ ████║██╔═══██╗████╗  ██║
  ██║     ██║   ██║██╔████╔██║█████╗  ██╔██╗ ██║██╔████╔██║██║   ██║██╔██╗ ██║
  ██║     ██║   ██║██║╚██╔╝██║██╔══╝  ██║╚██╗██║██║╚██╔╝██║██║   ██║██║╚██╗██║
  ███████╗╚██████╔╝██║ ╚═╝ ██║███████╗██║ ╚████║██║ ╚═╝ ██║╚██████╔╝██║ ╚████║
  ╚══════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝"""


LOADING_MESSAGES = [
    "Initializing system monitor...",
    "Loading kernel modules...",
    "Starting metric collectors...",
    "Connecting to SSH transport layer...",
    "Scanning for active agents...",
    "Establishing secure connections...",
    "Loading dashboard components...",
    "Calibrating real-time graphs...",
    "System ready.",
]


class LoadingIndicator(Static):
    """Animated loading indicator with progress bar."""

    progress = reactive(0)
    message = reactive("")
    messages_shown = reactive([])

    def render(self) -> str:
        """Render the loading indicator."""
        # Create progress bar
        bar_width = 50
        filled = int(bar_width * (self.progress / 100))
        empty = bar_width - filled

        progress_bar = f"[{'█' * filled}{'░' * empty}] {self.progress:3d}%"

        # Build the display
        lines = []

        # Show all previous messages in dim
        for msg in self.messages_shown[:-1]:
            lines.append(f"  [dim green]✓ {msg}[/dim green]")

        # Show current message
        if self.message:
            lines.append(f"  [bright cyan]⟳ {self.message}[/bright cyan]")

        # Add progress bar
        lines.append("")
        lines.append(f"[bright cyan]{progress_bar}[/bright cyan]")

        return "\n".join(lines)

    async def start_loading(self) -> None:
        """Start the loading animation."""
        total_steps = len(LOADING_MESSAGES)

        for i, message in enumerate(LOADING_MESSAGES):
            self.message = message
            self.messages_shown = list(self.messages_shown) + [message]

            # Animate progress for this step
            start_progress = (i * 100) // total_steps
            end_progress = ((i + 1) * 100) // total_steps

            steps = 10
            for step in range(steps):
                await asyncio.sleep(0.03)  # 30ms per step
                self.progress = start_progress + ((end_progress - start_progress) * step) // steps

            self.progress = end_progress

            # Pause between messages (except the last one)
            if i < total_steps - 1:
                await asyncio.sleep(0.15)

        # Final pause on "System ready."
        await asyncio.sleep(0.5)


class SplashScreen(Container):
    """Startup splash screen with logo and loading animation."""

    def compose(self) -> ComposeResult:
        """Compose the splash screen layout."""
        with Vertical(id="splash-container"):
            # Logo section - use simple Static with the raw text
            yield Static(
                f"[bold bright_cyan]{LUMENMON_LOGO}[/bold bright_cyan]",
                id="splash-logo"
            )

            # Version/tagline
            yield Static(
                "[dim italic]Lightweight System Monitoring Solution v1.0[/dim italic]",
                id="splash-tagline"
            )

            # Loading indicator
            yield LoadingIndicator(id="splash-loader")

    async def on_mount(self) -> None:
        """Start the loading sequence when mounted."""
        # Get the loading indicator and start animation
        loader = self.query_one("#splash-loader", LoadingIndicator)

        # Run loading animation
        await loader.start_loading()

        # Notify the app that loading is complete
        self.app.post_message(self.LoadingComplete())

    class LoadingComplete(Message):
        """Message sent when loading animation is complete."""
        pass