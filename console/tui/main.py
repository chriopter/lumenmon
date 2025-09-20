#!/usr/bin/env python3
"""
Lumenmon TUI - Main application
"""

from textual import on
from textual.app import App, ComposeResult
from textual.widgets import Header, Footer, Button, DataTable
from textual.containers import Container

from views import DashboardView, DetailView
from models import Invite
from services import ClipboardService, MonitorService
from config import REFRESH_RATE


class LumenmonTUI(App):
    """Main TUI Application"""

    BINDINGS = [
        ("q", "quit", "Quit"),
        ("r", "refresh", "Refresh"),
        ("i", "create_invite", "Create Invite"),
        ("c", "copy_invite", "Copy Invite URL"),
        ("d", "toggle_dark", "Toggle Dark Mode"),
    ]

    CSS_PATH = "config/theme.css"

    def __init__(self):
        super().__init__()
        self.monitor = MonitorService()
        self.clipboard_service = ClipboardService()
        self.selected_agent = None
        self.invite_urls = []

    def compose(self) -> ComposeResult:
        """Compose the application layout"""
        yield Header(show_clock=True)

        # Main dashboard view
        with Container(id="dashboard"):
            yield DashboardView()

        # Detailed agent view (hidden by default)
        yield Container(id="detail_view")

        yield Footer()

    def on_mount(self):
        """Initialize the app"""
        self.refresh_timer = self.set_interval(REFRESH_RATE, self.refresh_all)
        self.refresh_all()

        # Focus on the table for keyboard navigation
        dashboard = self.query_one(DashboardView)
        table = dashboard.query_one(DataTable)
        table.focus()

    def refresh_all(self):
        """Refresh both agents and invites data"""
        # Get fresh data
        agents_data = self.monitor.get_agents_data()
        invites_data = self.monitor.get_invites_data()

        # Store invite URLs for copying
        self.invite_urls = [invite.url for invite in invites_data if invite.url]

        # Update dashboard
        dashboard = self.query_one(DashboardView)
        dashboard.update_table(agents_data, invites_data)

    @on(DataTable.RowSelected)
    def on_row_selected(self, event):
        """Handle row selection with Enter key to show detailed view"""
        row_index = event.cursor_row
        dashboard = self.query_one(DashboardView)
        table = dashboard.query_one(DataTable)

        if row_index < len(table.rows):
            row_data = table.get_row_at(row_index)
            if row_data:
                name = str(row_data[0]).strip()
                # Only show details for actual agents (starting with id_)
                if name.startswith("id_"):
                    self.show_agent_details(name)

    def show_agent_details(self, agent_id: str):
        """Show detailed view with graphs and metrics for an agent"""
        self.selected_agent = agent_id

        # Hide dashboard, show detail view
        self.query_one("#dashboard").add_class("hidden")

        # Update detail view with new agent
        detail_container = self.query_one("#detail_view")
        detail_container.remove_children()
        detail_container.mount(DetailView(agent_id))
        detail_container.add_class("visible")

    @on(Button.Pressed, "#back_button")
    def back_to_dashboard(self):
        """Return to main dashboard"""
        self.query_one("#dashboard").remove_class("hidden")
        self.query_one("#detail_view").remove_class("visible")
        self.selected_agent = None

        # Refocus on table
        dashboard = self.query_one(DashboardView)
        table = dashboard.query_one(DataTable)
        table.focus()

    def action_refresh(self):
        """Manual refresh action"""
        self.refresh_all()

    def action_copy_invite(self):
        """Copy the first active invite URL to clipboard"""
        if self.invite_urls:
            invite_url = self.invite_urls[0]

            if self.clipboard_service.copy(invite_url, app=self):
                self.notify(f"✓ Copied to clipboard!\n{invite_url}", timeout=5)
            elif self.clipboard_service.save_fallback(invite_url):
                self.notify(f"⚠ Could not copy to clipboard.\nSaved to: /tmp/lumenmon_invite.txt\n\n{invite_url}", timeout=15)
            else:
                self.notify(f"⚠ Could not copy to clipboard.\nManually copy:\n\n{invite_url}", timeout=20)
        else:
            self.notify("No active invites to copy. Press 'i' to create one.", severity="warning")

    def action_create_invite(self):
        """Create a new registration invite"""
        invite_url = Invite.create()
        if invite_url:
            # Try to copy to clipboard
            if self.clipboard_service.copy(invite_url, app=self):
                self.notify(f"✓ Invite created and copied to clipboard!\n{invite_url}", timeout=10)
            else:
                self.notify(f"Invite created:\n{invite_url}", timeout=15)

            # Refresh table immediately
            self.refresh_all()
        else:
            self.notify("Failed to create invite", severity="error")

    def action_toggle_dark(self):
        """Toggle dark mode"""
        self.theme = "textual-dark" if self.theme == "textual-light" else "textual-light"

if __name__ == "__main__":
    app = LumenmonTUI()
    app.run()
