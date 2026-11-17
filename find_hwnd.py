import ctypes
from ctypes import wintypes
import win32process # or ctypes

kernel32 = ctypes.windll.kernel32
user32 = ctypes.windll.user32

def enum_thread_windows(tid):
    def proc(hwnd, lparam):
        buf = ctypes.create_unicode_buffer(256)
        user32.GetWindowTextW(hwnd, buf, 256)
        cls = ctypes.create_unicode_buffer(256)
        user32.GetClassNameW(hwnd, cls, 256)
        rect = wintypes.RECT()
        user32.GetWindowRect(hwnd, ctypes.byref(rect))
        ex_style = user32.GetWindowLongPtrW(hwnd, -20)
        style = user32.GetWindowLongPtrW(hwnd, -16)
        print(f"HWND {hex(hwnd)} Title: '{buf.value}' Class: '{cls.value}' Rect: ({rect.left},{rect.top})-({rect.right},{rect.bottom}) Vis: {user32.IsWindowVisible(hwnd)} ExStyle: {hex(ex_style)} Style: {hex(style)}")
        return True
    user32.EnumThreadWindows(tid, ctypes.WINFUNCTYPE(ctypes.c_bool, wintypes.HWND, wintypes.LPARAM)(proc), 0)

import subprocess
out = subprocess.check_output(['powershell', '-Command', '(Get-Process -Id 19164).Threads.Id']).decode()
tids = [int(x.strip()) for x in out.splitlines() if x.strip()]
print('Threads:', tids)
for tid in tids:
    enum_thread_windows(tid)
