#!/usr/bin/env python3
"""
Lumenmon boot animation module
Displays animated logo and system initialization sequence
"""

import time
import random
from rich.console import Console
from rich.panel import Panel
from rich.align import Align
from rich.text import Text
from rich import box
from rich.live import Live
from rich.layout import Layout

console = Console()

# ASCII art logo
LUMENMON_LOGO = """
  ██╗     ██╗   ██╗███╗   ███╗███████╗███╗   ██╗███╗   ███╗ ██████╗ ███╗   ██╗
  ██║     ██║   ██║████╗ ████║██╔════╝████╗  ██║████╗ ████║██╔═══██╗████╗  ██║
  ██║     ██║   ██║██╔████╔██║█████╗  ██╔██╗ ██║██╔████╔██║██║   ██║██╔██╗ ██║
  ██║     ██║   ██║██║╚██╔╝██║██╔══╝  ██║╚██╗██║██║╚██╔╝██║██║   ██║██║╚██╗██║
  ███████╗╚██████╔╝██║ ╚═╝ ██║███████╗██║ ╚████║██║ ╚═╝ ██║╚██████╔╝██║ ╚████║
  ╚══════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝
"""

class BootAnimation:
    """Boot animation and initialization sequence"""

    def __init__(self):
        self.console = Console()
        self.init_messages = [
            ("INITIALIZING LUMENMON CONSOLE...", "cyan", 0.3),
            ("", "", 0),
            ("✓ SSH Server Started", "green", 0.1),
            ("✓ TSV Parser Initialized", "green", 0.1),
            ("✓ tmpfs Storage Mounted", "green", 0.1),
            ("✓ Ring Buffers Configured", "green", 0.1),
            ("✓ Metric Collectors Ready", "green", 0.1),
            ("✓ Dashboard Components Loaded", "green", 0.1),
            ("", "", 0.2),
            ("◉ STATUS: AWAITING AGENT CONNECTIONS", "cyan", 0.2),
        ]
        self.logo_build_chars = list(LUMENMON_LOGO)

    def create_logo_panel(self, reveal_percent=100):
        """Create logo panel with partial reveal effect"""
        if reveal_percent < 100:
            # Gradually reveal characters
            total_chars = len(self.logo_build_chars)
            chars_to_show = int(total_chars * reveal_percent / 100)

            # Build partially revealed logo
            revealed_logo = ""
            for i, char in enumerate(self.logo_build_chars):
                if i < chars_to_show:
                    revealed_logo += char
                elif char == '\n':
                    revealed_logo += '\n'
                elif char == ' ':
                    revealed_logo += ' '
                else:
                    # Use random characters for "building" effect
                    if random.random() > 0.7:
                        revealed_logo += random.choice(['░', '▒', '▓', '█'])
                    else:
                        revealed_logo += ' '

            logo_text = Text(revealed_logo, style="bright_cyan")
        else:
            # Full logo in bright green
            logo_text = Text(LUMENMON_LOGO, style="bright_green bold")

        # Version info
        version_text = Text("\n[ SYSTEM MONITORING CONSOLE v5.0 ]",
                          style="cyan", justify="center")

        # Combine logo and version
        combined = Text.assemble(logo_text, version_text)

        return Panel(
            Align.center(combined),
            box=box.DOUBLE,
            border_style="cyan",
            title="",
            padding=(1, 2)
        )

    def create_status_panel(self, messages_to_show=0):
        """Create status panel with progressive message display"""
        status_lines = []

        for i, (msg, color, _) in enumerate(self.init_messages[:messages_to_show]):
            if msg:
                if msg.startswith("✓"):
                    # Success messages with checkmark
                    text = Text(f"  {msg}", style=color)
                elif msg.startswith("◉"):
                    # Status messages
                    text = Text(f"\n{msg}", style=f"bold {color}")
                else:
                    # Headers
                    text = Text(f"▶ {msg}", style=f"bold {color}")
                status_lines.append(text)
            else:
                # Empty line
                status_lines.append(Text(""))

        if not status_lines:
            status_lines = [Text("")]

        return Panel(
            Text.assemble(*[line for line in status_lines]),
            box=box.ROUNDED,
            border_style="dim",
            padding=(1, 2)
        )

    def run_boot_sequence(self):
        """Run the complete boot animation sequence"""
        layout = Layout()
        layout.split_column(
            Layout(name="logo", size=10),
            Layout(name="status", size=12)
        )

        with Live(layout, refresh_per_second=30, screen=False) as live:
            # Phase 1: Logo build animation (faster)
            for percent in range(0, 101, 4):
                layout["logo"].update(self.create_logo_panel(percent))
                layout["status"].update(self.create_status_panel(0))
                time.sleep(0.02)

            # Brief pause to show complete logo
            time.sleep(0.3)

            # Phase 2: System messages with typing effect
            for i in range(len(self.init_messages) + 1):
                layout["logo"].update(self.create_logo_panel(100))
                layout["status"].update(self.create_status_panel(i))

                if i < len(self.init_messages):
                    _, _, delay = self.init_messages[i]
                    time.sleep(delay)

            # Final pause
            time.sleep(0.5)

    def run_simple_boot(self):
        """Simple version without Live display for compatibility"""
        console.clear()

        # Show logo
        logo_panel = Panel(
            Align.center(Text(LUMENMON_LOGO, style="bright_green bold")),
            box=box.DOUBLE,
            border_style="cyan",
            title="",
            padding=(1, 2)
        )
        console.print(logo_panel)

        # Show version
        console.print(Text("[ SYSTEM MONITORING CONSOLE v5.0 ]",
                          style="cyan", justify="center"))
        console.print()

        # Show messages
        for msg, color, delay in self.init_messages:
            if msg:
                if msg.startswith("✓"):
                    console.print(f"  {msg}", style=color)
                elif msg.startswith("◉"):
                    console.print(f"\n{msg}", style=f"bold {color}")
                else:
                    console.print(f"▶ {msg}", style=f"bold {color}")
                time.sleep(delay)
            else:
                console.print()

        time.sleep(0.5)


def show_boot_animation(simple=False):
    """Main entry point for boot animation"""
    boot = BootAnimation()

    if simple:
        boot.run_simple_boot()
    else:
        try:
            boot.run_boot_sequence()
        except Exception:
            # Fallback to simple version if Live display fails
            boot.run_simple_boot()


if __name__ == "__main__":
    # Test the animation
    show_boot_animation()