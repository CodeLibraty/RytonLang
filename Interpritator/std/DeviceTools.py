from plyer import notification
import psutil
import subprocess
import shutil

class Tools:
    def __init__(self):
        self.dialog_cmd = self._get_dialog_cmd()
    
    def _get_dialog_cmd(self):
        if shutil.which('kdialog'):
            return 'kdialog'
        return 'dialog'
    
    def notify(self, title, message):
        notification.notify(title=title, message=message)
    
    def choose_file(self):
        if self.dialog_cmd == 'kdialog':
            return subprocess.check_output(
                ['kdialog', '--getopenfilename'], 
                text=True
            ).strip()
        else:
            # Используем dialog для выбора файла
            return subprocess.check_output(
                ['dialog', '--stdout', '--title', 'Select file', '--fselect', './', 10, 50],
                text=True
            ).strip()
        