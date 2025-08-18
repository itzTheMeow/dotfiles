import os
import platform
import signal
import subprocess
import sys
from pathlib import Path

# fmt: off
from PyQt5.QtCore import QTimer
from PyQt5.QtGui import QCursor, QIcon, QPixmap
from PyQt5.QtWidgets import (QAction, QApplication, QMenu, QMessageBox,
                             QSystemTrayIcon)

# fmt: on

# fixes CTRL+C
signal.signal(signal.SIGINT, signal.SIG_DFL)


PORT = 10809
SSH_COMMAND = [
    "ssh.exe" if platform.system() == "Windows" else "ssh",
    "-N",
    "-D",
    f"127.0.0.1:{PORT}",
    "socks5@jade.nvst.ly",
]


class ProxyTray:
    app: QApplication
    tray: QSystemTrayIcon
    menu: QMenu

    start_action: QAction
    stop_action: QAction
    port_action: QAction
    quit_action: QAction

    ssh_process: subprocess.Popen

    def __init__(self, app=None):
        if app is None:
            self.app = QApplication(sys.argv)
        else:
            self.app = app

        # Check if system tray is available
        if not QSystemTrayIcon.isSystemTrayAvailable():
            QMessageBox.critical(
                None, "SSH Proxy Tray", "System tray is not available on this system."
            )
            sys.exit(1)

        self.tray = QSystemTrayIcon()
        self.menu = QMenu()
        self.ssh_process = None

        # Actions
        self.start_action = QAction("Start Proxy")
        self.stop_action = QAction("Stop Proxy")
        self.port_action = QAction(f"Port: {PORT}")
        self.quit_action = QAction("Quit")

        self.start_action.triggered.connect(self.start_ssh)
        self.stop_action.triggered.connect(self.stop_ssh)
        self.port_action.setEnabled(False)
        self.quit_action.triggered.connect(self.quit)

        self.menu.addAction(self.start_action)
        self.menu.addAction(self.stop_action)
        self.menu.addSeparator()
        self.menu.addAction(self.port_action)
        self.menu.addAction(self.quit_action)

        # show tray icon with context menu
        self.tray.setContextMenu(self.menu)
        self.tray.setIcon(self.get_status_icon())
        self.tray.setToolTip("SOCKS5 Proxy Monitor")
        self.tray.show()

        if platform.system() != "Darwin":
            self.tray.activated.connect(self.on_tray_activated)

        # Timer to update icon
        self.update_icon()
        self.timer = QTimer()
        self.timer.timeout.connect(self.update_icon)
        self.timer.start(3000)  # Check every 3 seconds

    def on_tray_activated(self, reason):
        # Only show menu on left click or trigger
        if reason in [QSystemTrayIcon.Trigger, QSystemTrayIcon.DoubleClick]:
            self.menu.popup(QCursor.pos())

    def is_running(self) -> bool:
        return self.ssh_process is not None and self.ssh_process.poll() is None

    def create_simple_icon(self, color: str) -> QIcon:
        """Create a simple colored circle icon for systems without theme icons."""
        size = 24
        pixmap = QPixmap(size, size)

        from PyQt5.QtCore import Qt
        from PyQt5.QtGui import QBrush, QColor, QPainter

        # Fill with transparent background (important for macOS)
        pixmap.fill(Qt.transparent)

        painter = QPainter(pixmap)
        painter.setRenderHint(QPainter.Antialiasing)
        painter.setBrush(QBrush(QColor(color)))
        painter.setPen(Qt.NoPen)

        # Draw a smaller circle with more padding for better proportions
        margin = 2
        circle_size = size - (margin * 2)
        painter.drawEllipse(margin, margin, circle_size, circle_size)
        painter.end()

        return QIcon(pixmap)

    def get_status_icon(self) -> QIcon:
        is_running = self.is_running()

        # Try system theme icons first
        if is_running:
            theme_icon = QIcon.fromTheme("network-vpn-symbolic")
            if not theme_icon.isNull():
                return theme_icon
        else:
            theme_icon = QIcon.fromTheme("network-vpn-acquiring-symbolic")
            if not theme_icon.isNull():
                return theme_icon

        # Look for custom icon files
        script_dir = Path(__file__).parent
        if is_running:
            icon_paths = [
                script_dir / "icon_green.png",
                script_dir / "green.png",
                script_dir / "connected.png",
            ]
        else:
            icon_paths = [
                script_dir / "icon_red.png",
                script_dir / "red.png",
                script_dir / "disconnected.png",
            ]

        for icon_path in icon_paths:
            if icon_path.exists():
                return QIcon(str(icon_path))

        # Fallback to simple colored circles
        if is_running:
            return self.create_simple_icon("green")
        else:
            return self.create_simple_icon("red")

    def update_icon(self):
        self.tray.setIcon(self.get_status_icon())
        # Update menu item states
        is_running = self.is_running()
        self.start_action.setEnabled(not is_running)
        self.stop_action.setEnabled(is_running)

        # Update tooltip with current status
        status = "Connected" if is_running else "Disconnected"
        self.tray.setToolTip(f"SOCKS5 Proxy Monitor - {status} (Port {PORT})")

    def start_ssh(self):
        if not self.is_running():
            try:
                self.ssh_process = subprocess.Popen(
                    SSH_COMMAND, stdout=subprocess.PIPE, stderr=subprocess.PIPE
                )
                self.tray.showMessage(
                    "SSH Proxy",
                    f"Starting SOCKS5 proxy on port {PORT}",
                    QSystemTrayIcon.Information,
                    2000,
                )
            except Exception as e:
                self.tray.showMessage(
                    "SSH Proxy Error",
                    f"Failed to start proxy: {e}",
                    QSystemTrayIcon.Critical,
                    3000,
                )
        self.update_icon()

    def stop_ssh(self):
        if self.ssh_process:
            try:
                self.ssh_process.terminate()
                # Give it a moment to terminate gracefully
                try:
                    self.ssh_process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    self.ssh_process.kill()
                self.tray.showMessage(
                    "SSH Proxy",
                    "SOCKS5 proxy stopped",
                    QSystemTrayIcon.Information,
                    2000,
                )
            except Exception as e:
                self.tray.showMessage(
                    "SSH Proxy Error",
                    f"Error stopping proxy: {e}",
                    QSystemTrayIcon.Warning,
                    3000,
                )
            finally:
                self.ssh_process = None
        self.update_icon()

    def quit(self):
        if self.ssh_process:
            try:
                self.ssh_process.terminate()
                try:
                    self.ssh_process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    self.ssh_process.kill()
            except Exception:
                pass  # Process might already be dead
        self.app.quit()


if __name__ == "__main__":

    # Create QApplication
    app = QApplication(sys.argv)
    app.setApplicationName("SSH Proxy Tray")
    app.setApplicationVersion("1.0")
    app.setOrganizationName("SSH Proxy")
    app.setQuitOnLastWindowClosed(False)

    # Create and run the tray application
    proxy_tray = ProxyTray(app)
    sys.exit(app.exec_())
