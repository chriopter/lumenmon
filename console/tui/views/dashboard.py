"""Dashboard view for main agent table"""

from textual.widgets import DataTable
from textual.containers import Container
from rich.text import Text


class DashboardView(Container):
    """Main dashboard table view"""

    def compose(self):
        """Compose the dashboard with a data table"""
        table = DataTable(cursor_type="row")
        table.add_columns("Name/Invite", "Status", "CPU %", "Memory %", "Disk %", "Info")
        yield table

    def update_table(self, agents_data, invites_data):
        """Update the table with agents and invites data"""
        table = self.query_one(DataTable)
        table.clear()

        # Add header for Connected Agents
        table.add_row(
            Text("[bold cyan]──── CONNECTED AGENTS ────[/bold cyan]", overflow="crop"),
            Text(""), Text(""), Text(""), Text(""), Text("")
        )

        if not agents_data:
            table.add_row(
                "  No agents",
                Text("⏳", style="yellow"),
                "-", "-", "-",
                "No agents registered"
            )
        else:
            for agent in agents_data:
                # Status icon
                status_map = {
                    'green': Text("●", style="green"),
                    'yellow': Text("●", style="yellow"),
                    'red': Text("●", style="red"),
                    'dim': Text("○", style="dim")
                }
                status = status_map.get(agent['status'], Text("○", style="dim"))

                # Format values
                cpu_str = f"{agent['cpu']:.1f}" if agent['cpu'] is not None else "-"
                mem_str = f"{agent['memory']:.1f}" if agent['memory'] is not None else "-"
                disk_str = f"{agent['disk']:.1f}" if agent['disk'] is not None else "-"

                # Last update
                min_age = agent['min_age']
                if min_age < 999:
                    last_update = f"{int(min_age)}s ago"
                else:
                    last_update = "offline"

                table.add_row(
                    f"  {agent['id']}",
                    status,
                    cpu_str,
                    mem_str,
                    disk_str,
                    last_update
                )

        # Add separator for Active Invites
        table.add_row(
            Text(""), Text(""), Text(""), Text(""), Text(""), Text("")
        )
        table.add_row(
            Text("[bold cyan]──── ACTIVE INVITES ────[/bold cyan]", overflow="crop"),
            Text(""), Text(""), Text(""), Text(""),
            Text("Press 'i' to create")
        )

        if not invites_data:
            table.add_row(
                "  No active invites",
                Text("○", style="dim"),
                "-", "-", "-",
                "Press 'i' to create"
            )
        else:
            for invite in invites_data:
                if invite.url:
                    expire_min = invite.expires // 60
                    expire_sec = invite.expires % 60

                    table.add_row(
                        f"  {invite.username}",
                        Text("🔑", style="cyan"),
                        "-", "-", "-",
                        Text(f"Expires: {expire_min}m {expire_sec}s", style="yellow")
                    )
                    # Add the URL on a separate row
                    table.add_row(
                        f"  └─ {invite.url}",
                        Text(""),
                        "-", "-", "-",
                        Text("[dim]Press 'c' to copy[/dim]")
                    )