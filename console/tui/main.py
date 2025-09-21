#!/usr/bin/env python3
"""Lumenmon TUI - Main application."""

from __future__ import annotations

from typing import List, Optional

from textual import on
from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Container
from textual.reactive import reactive
from textual.widgets import Button, DataTable, Footer, Header, Static

from config import REFRESH_RATE
from models import AgentSnapshot, Invite
from services import ClipboardService, MonitorService
from views import DashboardView, DetailView
from views.boot_splash import RetroBootSplash


class LumenmonTUI(App):
    """Interactive terminal interface for monitoring Lumenmon agents."""

    BINDINGS = [
        Binding("enter", "continue_app", "Continue", show=False),
        ("q", "quit", "Quit"),
        ("r", "refresh", "Refresh"),
        ("i", "create_invite", "Create Invite"),
        ("c", "copy_invite", "Copy Install Command"),
        ("d", "toggle_dark", "Toggle Dark Mode"),
    ]

    CSS_PATH = "config/theme.css"

    showing_splash = reactive(True)

    def __init__(self) -> None:
        super().__init__()
        self.monitor = MonitorService()
        self.clipboard_service = ClipboardService()
        self.invite_urls: List[str] = []
        self._dashboard_container: Optional[Container] = None
        self._dashboard_view: Optional[DashboardView] = None
        self._detail_container: Optional[Container] = None
        self._current_agent: Optional[str] = None

    # Layout -----------------------------------------------------------------

    def compose(self) -> ComposeResult:  # type: ignore[override]
        """Compose the application layout."""

        if self.showing_splash:
            # Show the retro boot splash
            yield RetroBootSplash()
        else:
            # Show the main app
            yield Header(show_clock=True)

            dashboard_view = DashboardView()
            dashboard_container = Container(dashboard_view, id="dashboard")
            self._dashboard_container = dashboard_container
            self._dashboard_view = dashboard_view
            yield dashboard_container

            detail_container = Container(id="detail_view")
            self._detail_container = detail_container
            yield detail_container

            yield Footer()

    def on_mount(self) -> None:
        """Initialize the app after widgets are ready."""
        if not self.showing_splash:
            self.set_interval(REFRESH_RATE, self.refresh_all)
            self.refresh_all()
            self._focus_table()

    async def action_continue_app(self) -> None:
        """Continue from splash to main app."""
        if self.showing_splash:
            self.showing_splash = False
            # Clear and recompose
            await self.query("*").remove()

            # Mount the main app components
            await self.mount(Header(show_clock=True))

            dashboard_view = DashboardView()
            dashboard_container = Container(dashboard_view, id="dashboard")
            self._dashboard_container = dashboard_container
            self._dashboard_view = dashboard_view
            await self.mount(dashboard_container)

            detail_container = Container(id="detail_view")
            self._detail_container = detail_container
            await self.mount(detail_container)

            await self.mount(Footer())

            # Now everything is mounted, start the refresh
            self.set_interval(REFRESH_RATE, self.refresh_all)
            self.refresh_all()
            self._focus_table()

    # Refresh cycle ----------------------------------------------------------

    def refresh_all(self) -> None:
        """Refresh dashboard data for agents and invites."""
        if self.showing_splash:
            return

        agents = self.monitor.get_agents_data()
        invites = self.monitor.get_invites_data()
        self.invite_urls = [invite.url for invite in invites if invite.url]

        if self._dashboard_view:
            self._dashboard_view.update_table(agents, invites)

    # UI helpers --------------------------------------------------------------

    def _focus_table(self) -> None:
        if not self._dashboard_view:
            return
        try:
            table = self._dashboard_view.query_one(DataTable)
            table.focus()
        except:
            pass

    def _show_detail(self, agent_id: str) -> None:
        if not self._detail_container:
            return

        self._detail_container.remove_children()
        self._detail_container.mount(DetailView(agent_id))
        self._detail_container.add_class("visible")

    def _show_dashboard(self) -> None:
        if self._detail_container:
            self._detail_container.remove_class("visible")
            self._detail_container.remove_children()
        if self._dashboard_container:
            self._dashboard_container.remove_class("hidden")

    # Event handlers ----------------------------------------------------------

    @on(DataTable.RowSelected)
    def on_row_selected(self, event: DataTable.RowSelected) -> None:
        """Open the detail view when an agent row is selected."""
        if self.showing_splash:
            return

        table = event.control
        if event.cursor_row >= len(table.rows):
            return

        row_data = table.get_row_at(event.cursor_row)
        if not row_data:
            return

        name = str(row_data[0]).strip()
        if not name.startswith("id_"):
            return

        self._current_agent = name
        if self._dashboard_container:
            self._dashboard_container.add_class("hidden")
        self._show_detail(name)

    @on(Button.Pressed, "#back_button")
    def back_to_dashboard(self) -> None:
        """Return to the main dashboard view."""

        self._current_agent = None
        self._show_dashboard()
        self._focus_table()

    # Actions -----------------------------------------------------------------

    def action_refresh(self) -> None:
        if not self.showing_splash:
            self.refresh_all()

    def action_copy_invite(self) -> None:
        if self.showing_splash:
            return

        if not self.invite_urls:
            self.notify("No active invites to copy. Press 'i' to create one.", severity="warning")
            return

        invite_url = self.invite_urls[0]
        host = invite_url.split('@')[1].split('/')[0]
        full_command = f"curl -sSL https://raw.githubusercontent.com/chriopter/lumenmon/main/install.sh | LUMENMON_INVITE='{invite_url}' bash"

        if self.clipboard_service.copy(full_command, app=self):
            self.notify(f"✓ Copied install command to clipboard!\n{full_command}", timeout=5)
        elif self.clipboard_service.save_fallback(full_command):
            self.notify(
                f"⚠ Could not copy to clipboard.\nSaved to: /tmp/lumenmon_invite.txt\n\n{full_command}",
                timeout=15,
            )
        else:
            self.notify(
                f"⚠ Could not copy to clipboard.\nManually copy:\n\n{full_command}",
                timeout=20,
            )

    def action_create_invite(self) -> None:
        if self.showing_splash:
            return

        invite_url = Invite.create()
        if not invite_url:
            self.notify("Failed to create invite", severity="error")
            return

        if self.clipboard_service.copy(invite_url, app=self):
            self.notify(f"✓ Invite created and copied to clipboard!\n{invite_url}", timeout=10)
        else:
            self.notify(f"Invite created:\n{invite_url}", timeout=15)

        self.refresh_all()

    def action_toggle_dark(self) -> None:
        self.theme = "textual-dark" if self.theme == "textual-light" else "textual-light"


if __name__ == "__main__":
    app = LumenmonTUI()
    app.run()