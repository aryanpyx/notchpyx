import struct

input_path = r'c:\Users\aryan\Downloads\Notch_X_Original\data\app.so'
output_path = r'c:\Users\aryan\Downloads\Notch_X_Release\data\app.so'

with open(input_path, 'rb') as f:
    buf = bytearray(f.read())

orig_len = len(buf)

def patch_smi_and_string(buf, str_offset, old_str, new_str):
    smi_offset = str_offset - 8
    old_smi = struct.unpack('<Q', buf[smi_offset:smi_offset+8])[0]
    expected_smi = len(old_str) << 1
    if old_smi != expected_smi:
        print(f"Warning: Smi mismatch at {smi_offset}: expected {expected_smi}, got {old_smi}")
    
    new_smi = len(new_str) << 1
    buf[smi_offset:smi_offset+8] = struct.pack('<Q', new_smi)
    
    delta = len(new_str) - len(old_str)
    if delta >= 0:
        buf[str_offset:str_offset+len(new_str)] = new_str
    else:
        # Pad with nulls so buffer length doesn't change
        padded = new_str + b'\x00' * (-delta)
        buf[str_offset:str_offset+len(old_str)] = padded
    print(f"Patched '{old_str.decode('latin1', 'ignore')}' -> '{new_str.decode('latin1', 'ignore')}' at {str_offset}")

# --- Developer Info ---
# 1. Developer name: 'Rahoz Osman' -> 'Aryan Pandey'
patch_smi_and_string(buf, 1586272, b'Rahoz Osman', b'Aryan Pandey')

# 2. Island footer: '\xa9 Rahoz Osman' -> '\xa9 Aryan Pandey'
patch_smi_and_string(buf, 1437856, b'\xa9 Rahoz Osman', b'\xa9 Aryan Pandey')

# 3. Tooltip: 'Open a new message to Rahoz Osman' -> 'Open a new message to Aryan Pandey'
patch_smi_and_string(buf, 1311776, b'Open a new message to Rahoz Osman', b'Open a new message to Aryan Pandey')

# 4. Email displayed: 'hozahoza2001@gmail.com' -> 'aryanpandey52355@gmail.com'
patch_smi_and_string(buf, 1459920, b'hozahoza2001@gmail.com', b'aryanpandey52355@gmail.com')

# 5. Mailto link: 'mailto:hozahoza2001@gmail.com' -> 'mailto:aryanpandey@gmail.com'
patch_smi_and_string(buf, 1418656, b'mailto:hozahoza2001@gmail.com', b'mailto:aryanpandey@gmail.com')

# --- App Name: Notch X -> Notchpyx ---
# 6. App Name: 'Notch X' -> 'Notchpyx'
patch_smi_and_string(buf, 1306544, b'Notch X', b'Notchpyx')

# 7. 'Notch X 0.1.0' -> 'Notchpyx 0.1.0'
patch_smi_and_string(buf, 1229600, b'Notch X 0.1.0', b'Notchpyx 0.1.0')

# 8. 'Pause Notch X' -> 'Pause Notchpyx'
patch_smi_and_string(buf, 1123376, b'Pause Notch X', b'Pause Notchpyx')

# 9. 'Quit Notch X' -> 'Quit Notchpyx'
patch_smi_and_string(buf, 1138816, b'Quit Notch X', b'Quit Notchpyx')

# 10. 'Open Notch X' -> 'Open Notchpyx'
patch_smi_and_string(buf, 1604448, b'Open Notch X', b'Open Notchpyx')

# 11. 'Open Notch X settings' -> 'Open Notchpyx settings'
patch_smi_and_string(buf, 1342192, b'Open Notch X settings', b'Open Notchpyx settings')

# 12. 'Design and engineering · Notch X' -> 'Design & engineering · Notchpyx'
patch_smi_and_string(buf, 1248848, b'Design and engineering \xb7 Notch X', b'Design & engineering \xb7 Notchpyx')

# 13. Privacy / Camera / Mic disclaimer
patch_smi_and_string(buf, 1209520, b'Reported by Windows. Notch X cannot see what is captured.', b'Reported by Windows. Notchpyx cannot see what is captured.')

# 14. Windows startup setting description
patch_smi_and_string(buf, 1268448, b'Adds Notch X to the Windows startup list.', b'Adds Notchpyx to the Windows startup list.')

# 15. Clipboard description
patch_smi_and_string(buf, 1648928, b'Off by default. When on, Notch X is told that something was copied, and how large it was.', b'Off by default. When on, Notchpyx is told that something was copied, and how large it was.')

# 16. Privacy network description
patch_smi_and_string(buf, 1472192, b'Notch X makes no network requests. There is no telemetry, no crash reporting and no account. Settings and logs are written to your user profile and read by nothing else.', b'Notchpyx makes no network requests. There is no telemetry, no crash reporting and no account. Settings and logs are written to your user profile and read by nothing else.')

# 17. General setting window description
patch_smi_and_string(buf, 1491200, b'Notch X has no window of its own. Closing the island leaves it running in the notification area.', b'Notchpyx has no window of its own. Closing the island leaves it running in notification area.')

assert len(buf) == orig_len, f"Size changed! {orig_len} -> {len(buf)}"

with open(output_path, 'wb') as f:
    f.write(buf)

print(f"\nSUCCESS: Exactly preserved size of {len(buf)} bytes and saved to {output_path}!")
