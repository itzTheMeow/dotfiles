import subprocess
import sys

import psutil
from PyQt5.QtGui import QIcon
from PyQt5.QtWidgets import QAction, QApplication, QMenu, QSystemTrayIcon

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

        self.tray.setContextMenu(self.menu)
        self.tray.setIcon(self.get_status_icon())
        self.tray.setToolTip("SOCKS5 Proxy Monitor")
        self.tray.show()

        # Timer to update icon
        self.timer = self.app.timer()
        self.timer.timeout.connect(self.update_icon)
        self.timer.start(3000)  # Check every 3 seconds

        sys.exit(self.app.exec_())

    def is_proxy_running(self):
        for proc in psutil.process_iter(["cmdline"]):
            print(proc.info.keys())
            print(proc.info["cmdline"])
            if (
                proc.info["cmdline"]
                and "ssh" in proc.info["cmdline"][0]
                and "-D" in proc.info["cmdline"]
            ):
                return True
        return False

    def get_status_icon(self):
        if self.is_proxy_running():
            return QIcon.fromTheme("network-vpn") or QIcon("icon_green.png")
        else:
            return QIcon.fromTheme("network-offline") or QIcon("icon_red.png")

    def update_icon(self):
        self.tray.setIcon(self.get_status_icon())

    def start_ssh(self):
        if not self.is_proxy_running():
            subprocess.Popen(SSH_COMMAND)

    def stop_ssh(self):
        for proc in psutil.process_iter(["pid", "cmdline"]):
            if (
                proc.info["cmdline"]
                and "ssh" in proc.info["cmdline"][0]
                and "-D" in proc.info["cmdline"]
            ):
                proc.kill()


if __name__ == "__main__":
    ProxyTray()
