import ctypes
from ctypes import wintypes

user32 = ctypes.windll.user32

hwnds = []
def enum_windows_proc(hwnd, lparam):
    pid = wintypes.DWORD()
    user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
    if pid.value == 19164:
        buf = ctypes.create_unicode_buffer(256)
        user32.GetWindowTextW(hwnd, buf, 256)
        cls = ctypes.create_unicode_buffer(256)
        user32.GetClassNameW(hwnd, cls, 256)
        rect = wintypes.RECT()
        user32.GetWindowRect(hwnd, ctypes.byref(rect))
        ex_style = user32.GetWindowLongPtrW(hwnd, -20)
        style = user32.GetWindowLongPtrW(hwnd, -16)
        print(f"HWND {hex(hwnd)} Title: '{buf.value}' Class: '{cls.value}' Rect: ({rect.left},{rect.top})-({rect.right},{rect.bottom}) Vis: {user32.IsWindowVisible(hwnd)} ExStyle: {hex(ex_style)} Style: {hex(style)}")
        hwnds.append(hwnd)
    return True

WNDENUMPROC = ctypes.WINFUNCTYPE(ctypes.c_bool, wintypes.HWND, wintypes.LPARAM)
user32.EnumWindows(WNDENUMPROC(enum_windows_proc), 0)
