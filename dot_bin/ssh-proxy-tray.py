import signal
import subprocess
import sys

import psutil
from PyQt5.QtCore import QTimer
from PyQt5.QtGui import QCursor, QIcon
from PyQt5.QtWidgets import QAction, QApplication, QMenu, QSystemTrayIcon

# fixes CTRL+C
signal.signal(signal.SIGINT, signal.SIG_DFL)


PORT = 10809
SSH_COMMAND = ["ssh", "-N", "-D", f"127.0.0.1:{PORT}", "root@jade.nvstly.com"]


class ProxyTray:
    def __init__(self):
        self.app = QApplication(sys.argv)
        self.tray = QSystemTrayIcon()
        self.menu = QMenu()

        # Actions
        self.start_action = QAction("Start Proxy")
        self.stop_action = QAction("Stop Proxy")
        self.quit_action = QAction("Quit")

        self.start_action.triggered.connect(self.start_ssh)
        self.stop_action.triggered.connect(self.stop_ssh)
        self.quit_action.triggered.connect(self.app.quit)

        self.menu.addAction(self.start_action)
        self.menu.addAction(self.stop_action)
        self.menu.addSeparator()
        self.menu.addAction(self.quit_action)

        # show tray icon with context menu
        self.tray.setContextMenu(self.menu)
        self.tray.setIcon(self.get_status_icon())
        self.tray.setToolTip("SOCKS5 Proxy Monitor")
        self.tray.show()

        # activate context menu on left click
        self.tray.activated.connect(self.on_tray_activated)

        # Timer to update icon
        self.timer = QTimer()
        self.timer.timeout.connect(self.update_icon)
        self.timer.start(3000)  # Check every 3 seconds

        sys.exit(self.app.exec_())

    def on_tray_activated(self):
        self.menu.popup(QCursor.pos())

    def find_proxy_process(self) -> psutil.Process | None:
        for proc in psutil.process_iter(["cmdline"]):
            cmdline = proc.info["cmdline"]
            # determine if the ssh command is the one that is running
            if (
                cmdline
                and cmdline[0].endswith("ssh")
                and cmdline[1:] == SSH_COMMAND[1:]
            ):
                return proc
        return None

    def get_status_icon(self) -> QIcon:
        if self.find_proxy_process():
            return QIcon.fromTheme("network-vpn-symbolic") or QIcon("icon_green.png")
        else:
            return QIcon.fromTheme("network-vpn-acquiring-symbolic") or QIcon(
                "icon_red.png"
            )

    def update_icon(self):
        self.tray.setIcon(self.get_status_icon())

    def start_ssh(self):
        if not self.find_proxy_process():
            subprocess.Popen(SSH_COMMAND)
        self.update_icon()

    def stop_ssh(self):
        proc = self.find_proxy_process()
        if proc:
            proc.kill()
        self.update_icon()


if __name__ == "__main__":
    ProxyTray()
