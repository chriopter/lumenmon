"""Startup splash modal with logo."""

from __future__ import annotations

import asyncio

from textual.app import ComposeResult
from textual.containers import Container, Vertical, Center, Middle
from textual.screen import ModalScreen
from textual.widgets import Static, Label


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
    "Establishing connections...",
    "System ready!"
]


class SplashModal(ModalScreen):
    """Modal splash screen with logo."""

    DEFAULT_CSS = """
    SplashModal {
        align: center middle;
    }
    """

    def compose(self) -> ComposeResult:
        """Compose the splash modal."""
        with Center():
            with Middle():
                with Vertical(id="splash-box"):
                    # Logo
                    yield Label(f"[bold bright_cyan]{LUMENMON_LOGO}[/bold bright_cyan]")

                    # Divider
                    yield Label("[dim]━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━[/dim]")

                    # Title
                    yield Label("[bold]Lightweight System Monitoring Solution[/bold]")
                    yield Label("[italic dim]Version 1.0[/italic dim]")

                    # Status
                    yield Label("[bright_cyan]● Initializing monitoring system...[/bright_cyan]", id="status-label")

    async def on_mount(self) -> None:
        """Animate the loading messages."""
        status_label = self.query_one("#status-label", Label)

        # Animate through loading messages
        for i, message in enumerate(LOADING_MESSAGES):
            if i == len(LOADING_MESSAGES) - 1:
                status_label.update(f"[bold green]✓ {message}[/bold green]")
            else:
                status_label.update(f"[bright_cyan]● {message}[/bright_cyan]")
            await asyncio.sleep(0.5)

        # Final pause
        await asyncio.sleep(0.5)

        # Dismiss the modal
        self.app.pop_screen()