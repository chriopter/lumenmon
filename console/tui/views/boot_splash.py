"""80s style boot splash screen for Lumenmon."""

from __future__ import annotations

import asyncio
import random
from datetime import datetime
from typing import List

from textual.reactive import reactive
from textual.widgets import Static


LUMENMON_LOGO = """
  ██╗     ██╗   ██╗███╗   ███╗███████╗███╗   ██╗███╗   ███╗ ██████╗ ███╗   ██╗
  ██║     ██║   ██║████╗ ████║██╔════╝████╗  ██║████╗ ████║██╔═══██╗████╗  ██║
  ██║     ██║   ██║██╔████╔██║█████╗  ██╔██╗ ██║██╔████╔██║██║   ██║██╔██╗ ██║
  ██║     ██║   ██║██║╚██╔╝██║██╔══╝  ██║╚██╗██║██║╚██╔╝██║██║   ██║██║╚██╗██║
  ███████╗╚██████╔╝██║ ╚═╝ ██║███████╗██║ ╚████║██║ ╚═╝ ██║╚██████╔╝██║ ╚████║
  ╚══════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝"""


class RetroBootSplash(Static):
    """80s style boot splash screen."""

    def __init__(self):
        # Immediate boot text to avoid grey screen
        self.boot_lines: List[str] = [
            "[bright_white on black]",
            "╔══════════════════════════════════════════════════════════════════════════════╗",
            "║                    LUMENMON SYSTEM BIOS v1.0 - 1984                         ║",
            "║                    Copyright (C) LumenCorp Industries                       ║",
            "╚══════════════════════════════════════════════════════════════════════════════╝",
            "",
            "[yellow]Initializing..."
        ]
        # Initialize with the text immediately
        super().__init__("\n".join(self.boot_lines))
        self.memory_size = 65536  # 64K like old computers

    def on_mount(self) -> None:
        """Start the boot sequence when mounted."""
        # Run boot sequence immediately without delay
        self.call_after_refresh(self.start_sequence)

    def start_sequence(self) -> None:
        """Start the async boot sequence."""
        asyncio.create_task(self.run_boot_sequence())

    async def run_boot_sequence(self) -> None:
        """Run the full 80s style boot sequence."""
        # Don't clear - we already have the header shown
        # Just continue from where we are

        # CPU Detection - immediate, no delay
        await asyncio.sleep(0.01)
        await self.add_boot_line("[yellow]CPU: [white]Intel 80486DX2-66 MHz")
        await asyncio.sleep(0.05)
        await self.add_boot_line("[yellow]Math Coprocessor: [white]Present")
        await asyncio.sleep(0.05)

        # Memory test with counting animation
        await self.add_boot_line("")
        await self.add_boot_line("[yellow]Testing Memory: [white]", newline=False)

        # Simulate memory counting - faster
        memory_steps = [0, 16384, 32768, 49152, 65536]
        for mem in memory_steps:
            self.boot_lines[-1] = f"[yellow]Testing Memory: [white]{mem:06d} KB"
            self.update_display()
            await asyncio.sleep(0.03)

        await self.add_boot_line("[green]Memory Test: [white]65536 KB OK")
        await self.add_boot_line("")

        # System checks
        await asyncio.sleep(0.1)
        await self.add_boot_line("[cyan]━━━━━━━━━━━━━━━━━━━━━ SYSTEM INITIALIZATION ━━━━━━━━━━━━━━━━━━━━━")

        system_checks = [
            ("Keyboard Controller", "OK", 0.03),
            ("Floppy Drive A:", "1.44 MB", 0.05),
            ("Hard Drive C:", "540 MB", 0.05),
            ("Serial Ports", "COM1, COM2", 0.03),
            ("Parallel Port", "LPT1", 0.03),
            ("VGA Display", "640x480 16 colors", 0.05),
            ("Network Interface", "10BASE-T", 0.05),
            ("SSH Transport Layer", "READY", 0.05),
        ]

        for component, status, delay in system_checks:
            await asyncio.sleep(delay)
            dots = "." * random.randint(1, 3)
            await self.add_boot_line(f"[white]Detecting {component}{dots.ljust(3)} [green][{status}]")

        await self.add_boot_line("")
        await asyncio.sleep(0.1)

        # Loading sequence
        await self.add_boot_line("[cyan]━━━━━━━━━━━━━━━━━━━━━ LOADING MONITOR SYSTEM ━━━━━━━━━━━━━━━━━━━━")
        await self.add_boot_line("")

        loading_items = [
            "COMMAND.COM",
            "CONFIG.SYS",
            "AUTOEXEC.BAT",
            "HIMEM.SYS",
            "EMM386.EXE",
            "MONITOR.EXE",
            "METRICS.DLL",
            "NETWORK.DRV",
            "SSH.COM",
            "AGENT.BIN",
        ]

        for item in loading_items:
            await asyncio.sleep(random.uniform(0.02, 0.05))
            await self.add_boot_line(f"[dim white]Loading {item.ljust(15)} [green]✓")

        await self.add_boot_line("")
        await asyncio.sleep(0.1)

        # Show logo with retro effect
        await self.add_boot_line("[cyan]━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        await self.add_boot_line("")

        # Add logo with typewriter effect - faster
        logo_lines = LUMENMON_LOGO.split('\n')
        for line in logo_lines:
            await self.add_boot_line(f"[bold bright_cyan]{line}")
            await asyncio.sleep(0.02)

        await self.add_boot_line("")
        await self.add_boot_line("[bold bright_white]         LIGHTWEIGHT SYSTEM MONITORING SOLUTION")
        await self.add_boot_line("[dim white]                    Version 1.0.0")
        await self.add_boot_line("[dim white]            Build Date: " + datetime.now().strftime("%Y-%m-%d"))
        await self.add_boot_line("")
        await self.add_boot_line("[cyan]━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        await asyncio.sleep(0.2)
        await self.add_boot_line("")
        await self.add_boot_line("[green]System Ready.")
        await self.add_boot_line("")

        # Blinking cursor prompt - faster
        for _ in range(3):
            await self.add_boot_line("[bright_green]Press ENTER to continue_", newline=False)
            self.update_display()
            await asyncio.sleep(0.3)
            self.boot_lines[-1] = "[bright_green]Press ENTER to continue "
            self.update_display()
            await asyncio.sleep(0.3)

        await self.add_boot_line("[bright_green]Press ENTER to continue_", newline=False)
        self.update_display()

    async def add_boot_line(self, text: str, newline: bool = True) -> None:
        """Add a line to the boot sequence."""
        if newline:
            self.boot_lines.append(text)
        else:
            if self.boot_lines:
                self.boot_lines[-1] = text
            else:
                self.boot_lines.append(text)

        self.update_display()
        # Tiny delay for typewriter effect
        if newline:
            await asyncio.sleep(0.01)

    def update_display(self) -> None:
        """Update the display with current boot text."""
        # Keep only last 30 lines visible (like old terminals)
        visible_lines = self.boot_lines[-30:]
        self.update("\n".join(visible_lines))

    def render(self) -> str:
        """Render the boot text."""
        # Always return current display state
        if hasattr(self, 'boot_lines'):
            return "\n".join(self.boot_lines[-30:])
        return "[bright_white on black]LUMENMON SYSTEM BIOS v1.0 - 1984\nInitializing..."