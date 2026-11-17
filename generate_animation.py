import os
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import imageio.v3 as iio

WIDTH = 800
HEIGHT = 520
FPS = 25

# Load screenshots
now_img = Image.open("docs/screenshots/now.png").convert("RGBA")
media_img = Image.open("docs/screenshots/media.png").convert("RGBA")
system_img = Image.open("docs/screenshots/system.png").convert("RGBA")

# Ensure fonts
try:
    font_bold = ImageFont.truetype("arialbd.ttf", 16)
    font_sm = ImageFont.truetype("arial.ttf", 12)
    font_xs = ImageFont.truetype("arial.ttf", 10)
    font_lg = ImageFont.truetype("arialbd.ttf", 22)
    font_title = ImageFont.truetype("arialbd.ttf", 28)
except Exception:
    font_bold = ImageFont.load_default()
    font_sm = font_bold
    font_xs = font_bold
    font_lg = font_bold
    font_title = font_bold

def draw_rounded_rect(draw, bbox, radius, fill=None, outline=None, width=1):
    draw.rounded_rectangle(bbox, radius=radius, fill=fill, outline=outline, width=width)

def ease_out_cubic(x):
    return 1.0 - math.pow(1.0 - x, 3)

def ease_in_out_quad(x):
    return 2 * x * x if x < 0.5 else 1 - math.pow(-2 * x + 2, 2) / 2

def ease_out_back(x):
    c1 = 1.70158
    c3 = c1 + 1
    return 1 + c3 * math.pow(x - 1, 3) + c1 * math.pow(x - 1, 2)

frames = []
total_frames = 150 # 6 seconds at 25 fps

# Sequence timeline:
# Frames 0-20: Resting Pill at top bezel, cursor moves up
# Frames 21-45: Spring expansion into full Dynamic Island (Now page)
# Frames 46-75: Slide transition to Media player, animated equalizer & progress bar
# Frames 76-105: Slide transition to System page with 20 MB ultra-low RAM badge
# Frames 106-125: Morph into Volume HUD capsule (scrolling volume up)
# Frames 126-149: Spring retract back to resting notch

for f in range(total_frames):
    # Base canvas: Dark Windows 11 wallpaper aesthetic
    bg = Image.new("RGBA", (WIDTH, HEIGHT), (14, 18, 27, 255))
    draw = ImageDraw.Draw(bg)

    # Ambient subtle mesh glow in background
    for r in range(120, 0, -20):
        alpha = int(12 * (1.0 - r / 120.0))
        draw.ellipse([WIDTH//2 - r*2, -r, WIDTH//2 + r*2, r*2], fill=(45, 80, 160, alpha))
        draw.ellipse([WIDTH//2 - r, HEIGHT - r, WIDTH//2 + r*3, HEIGHT + r*2], fill=(20, 40, 70, alpha))

    # Top bezel bar (display frame)
    draw.rectangle([0, 0, WIDTH, 4], fill=(8, 10, 14, 255))

    # Determine State
    if f < 20:
        # Resting pill
        t = f / 20.0
        pill_w = 140
        pill_h = 32
        pill_x = (WIDTH - pill_w) // 2
        pill_y = 0

        # Draw resting pill
        draw_rounded_rect(draw, [pill_x, pill_y - 10, pill_x + pill_w, pill_y + pill_h], 16, fill=(0, 0, 0, 245), outline=(42, 50, 68, 255), width=1)
        # Camera sensor circle
        draw.ellipse([pill_x + 18, pill_y + 10, pill_x + 30, pill_y + 22], fill=(12, 16, 22, 255), outline=(30, 36, 48, 255))
        # Green privacy dot
        draw.ellipse([pill_x + 36, pill_y + 14, pill_x + 42, pill_y + 20], fill=(34, 197, 94, 255))
        # Time string
        draw.text((pill_x + 58, pill_y + 9), "10:42 AM", fill=(200, 210, 230, 230), font=font_sm)

        # Cursor gliding upwards
        cursor_x = int(WIDTH // 2 - 40 + t * 40)
        cursor_y = int(HEIGHT // 2 + (1.0 - t) * 120 - t * 100)
        # Cursor icon
        draw.polygon([(cursor_x, cursor_y), (cursor_x, cursor_y + 18), (cursor_x + 5, cursor_y + 14), (cursor_x + 11, cursor_y + 22), (cursor_x + 14, cursor_y + 20), (cursor_x + 8, cursor_y + 12), (cursor_x + 14, cursor_y + 12)], fill=(255, 255, 255, 255), outline=(0, 0, 0, 200))

    elif f < 45:
        # Morphing expansion into full island (Now Page)
        p = (f - 20) / 25.0
        e = ease_out_back(min(1.0, p * 1.05))
        e = min(1.0, max(0.0, e))

        target_w = 636
        target_h = 430
        curr_w = int(140 + (target_w - 140) * e)
        curr_h = int(32 + (target_h - 32) * e)
        curr_x = (WIDTH - curr_w) // 2
        curr_y = 0

        # Shadow
        shadow_rect = [curr_x - 6, curr_y, curr_x + curr_w + 6, curr_y + curr_h + 8]
        draw_rounded_rect(draw, shadow_rect, 22, fill=(0, 0, 0, int(160 * e)))

        # Card container
        draw_rounded_rect(draw, [curr_x, curr_y - 12, curr_x + curr_w, curr_y + curr_h], 20, fill=(18, 22, 30, 255), outline=(56, 189, 248, int(180 * e)), width=1)

        # If expansion is > 50%, composite Now screenshot
        if e > 0.4:
            content_alpha = int(255 * (e - 0.4) / 0.6)
            crop_h = min(curr_h - 20, target_h)
            if crop_h > 20:
                cropped = now_img.crop((0, 0, target_w, crop_h)).resize((curr_w, crop_h))
                # Paste with alpha
                mask = Image.new("L", (curr_w, crop_h), content_alpha)
                bg.paste(cropped, (curr_x, curr_y + 10), mask)

    elif f < 75:
        # Full Island: Transitioning from Now to Media Page with Live Audio Equalizer
        curr_w = 636
        curr_h = 430
        curr_x = (WIDTH - curr_w) // 2
        curr_y = 0

        draw_rounded_rect(draw, [curr_x - 8, curr_y, curr_x + curr_w + 8, curr_y + curr_h + 12], 22, fill=(0, 0, 0, 180))
        draw_rounded_rect(draw, [curr_x, curr_y - 12, curr_x + curr_w, curr_y + curr_h], 20, fill=(18, 22, 30, 255), outline=(99, 102, 241, 180), width=1)

        progress = (f - 45) / 30.0
        slide = ease_in_out_quad(min(1.0, progress * 1.5))

        # Composite slide between now and media
        slide_offset = int(slide * curr_w)
        if slide < 1.0:
            bg.paste(now_img, (curr_x - slide_offset, curr_y + 10))
        bg.paste(media_img, (curr_x + curr_w - slide_offset, curr_y + 10))

        # Overlay animated Equalizer spectrum on Media Player!
        if slide > 0.5:
            eq_alpha = int(255 * (slide - 0.5) / 0.5)
            eq_x = curr_x + 420
            eq_y = curr_y + 110
            bar_w = 4
            num_bars = 16
            for b in range(num_bars):
                # Harmonic wave height
                freq = math.sin((f * 0.4) + b * 0.7) * math.cos((f * 0.25) + b * 0.3)
                bar_h = int(8 + abs(freq) * 28)
                color = (56, 189, 248, eq_alpha) if b % 2 == 0 else (129, 140, 248, eq_alpha)
                draw.rectangle([eq_x + b * 7, eq_y - bar_h, eq_x + b * 7 + bar_w, eq_y], fill=color)

            # Live music badge
            draw_rounded_rect(draw, [curr_x + 400, curr_y + 125, curr_x + 560, curr_y + 148], 10, fill=(30, 41, 59, 220), outline=(56, 189, 248, 200))
            draw.text((curr_x + 412, curr_y + 129), "PLAYING: 320 kbps", fill=(56, 189, 248, 255), font=font_xs)

    elif f < 105:
        # Full Island: System Page with Ultra-Low RAM 20 MB Highlight Badge!
        curr_w = 636
        curr_h = 430
        curr_x = (WIDTH - curr_w) // 2
        curr_y = 0

        draw_rounded_rect(draw, [curr_x - 8, curr_y, curr_x + curr_w + 8, curr_y + curr_h + 12], 22, fill=(0, 0, 0, 180))
        draw_rounded_rect(draw, [curr_x, curr_y - 12, curr_x + curr_w, curr_y + curr_h], 20, fill=(18, 22, 30, 255), outline=(16, 185, 129, 200), width=1)

        progress = (f - 75) / 30.0
        slide = ease_in_out_quad(min(1.0, progress * 1.5))
        slide_offset = int(slide * curr_w)

        if slide < 1.0:
            bg.paste(media_img, (curr_x - slide_offset, curr_y + 10))
        bg.paste(system_img, (curr_x + curr_w - slide_offset, curr_y + 10))

        # Floating Banner for 20MB RAM Achievement
        badge_p = min(1.0, max(0.0, (progress - 0.2) / 0.5))
        badge_y = int(curr_y + 360 - ease_out_back(badge_p) * 20)
        badge_alpha = int(255 * badge_p)

        # Pulse glow around badge
        pulse = 0.5 + 0.5 * math.sin(f * 0.3)
        glow_c = (16, 185, 129, int(badge_alpha * (0.6 + 0.4 * pulse)))
        draw_rounded_rect(draw, [curr_x + 50, badge_y - 4, curr_x + curr_w - 50, badge_y + 44], 14, fill=(15, 23, 42, 240), outline=glow_c, width=2)
        draw.text((curr_x + 70, badge_y + 6), "⚡ ULTRA-LIGHT ENGINE: RAM 21.4 MB", fill=(52, 211, 153, badge_alpha), font=font_bold)
        draw.text((curr_x + 70, badge_y + 24), "Native Win32 Dynamic RGN · Zero Screen-Blocking · Pure WinRT APIs", fill=(148, 163, 184, badge_alpha), font=font_xs)

    elif f < 125:
        # Morphing into Volume HUD Capsule
        p = (f - 105) / 20.0
        e = ease_out_cubic(p)

        vol_w = int(636 - (636 - 260) * e)
        vol_h = int(430 - (430 - 48) * e)
        vol_x = (WIDTH - vol_w) // 2
        vol_y = 0

        draw_rounded_rect(draw, [vol_x - 6, vol_y, vol_x + vol_w + 6, vol_y + vol_h + 6], 20, fill=(0, 0, 0, 180))
        draw_rounded_rect(draw, [vol_x, vol_y - 10, vol_x + vol_w, vol_y + vol_h], 20, fill=(15, 23, 42, 250), outline=(56, 189, 248, 220), width=1)

        # Draw volume content when compact
        if e > 0.4:
            v_alpha = int(255 * (e - 0.4) / 0.6)
            # Volume icon
            draw.text((vol_x + 18, vol_y + 14), "🔊", fill=(255, 255, 255, v_alpha), font=font_sm)
            # Slider track
            slider_x = vol_x + 48
            slider_y = vol_y + 19
            slider_w = vol_w - 110
            draw_rounded_rect(draw, [slider_x, slider_y, slider_x + slider_w, slider_y + 8], 4, fill=(30, 41, 59, v_alpha))
            # Dynamic level going from 45% to 75%
            vol_level = 0.45 + (p * 0.30)
            fill_w = int(slider_w * vol_level)
            draw_rounded_rect(draw, [slider_x, slider_y, slider_x + fill_w, slider_y + 8], 4, fill=(56, 189, 248, v_alpha))
            # Percentage text
            draw.text((vol_x + vol_w - 50, vol_y + 14), f"{int(vol_level*100)}%", fill=(224, 242, 254, v_alpha), font=font_bold)

    else:
        # Retracting smoothly back to resting notch
        p = (f - 125) / 25.0
        e = 1.0 - ease_out_cubic(p)

        vol_w = int(140 + (260 - 140) * e)
        vol_h = int(32 + (48 - 32) * e)
        vol_x = (WIDTH - vol_w) // 2
        vol_y = 0

        draw_rounded_rect(draw, [vol_x, vol_y - 10, vol_x + vol_w, vol_y + vol_h], 16, fill=(0, 0, 0, 245), outline=(42, 50, 68, 255), width=1)
        if e < 0.3:
            draw.ellipse([vol_x + 18, vol_y + 10, vol_x + 30, vol_y + 22], fill=(12, 16, 22, 255), outline=(30, 36, 48, 255))
            draw.ellipse([vol_x + 36, vol_y + 14, vol_x + 42, vol_y + 20], fill=(34, 197, 94, 255))
            draw.text((vol_x + 58, vol_y + 9), "10:42 AM", fill=(200, 210, 230, 230), font=font_sm)

    # Convert to RGB numpy array for imageio
    frames.append(np.array(bg.convert("RGB")))

print("Encoding MP4 video...")
iio.imwrite("docs/animations/notchpyx_walkthrough.mp4", frames, fps=FPS)

print("Encoding GIF animation (subsampled for web)...")
# For GIF, use every 2nd frame (12.5 fps) for optimal file size and crisp playback
gif_frames = [Image.fromarray(f).quantize(colors=128, method=Image.Quantize.MEDIANCUT) for f in frames[::2]]
gif_frames[0].save(
    "docs/animations/notchpyx_walkthrough.gif",
    save_all=True,
    append_images=gif_frames[1:],
    duration=80,
    loop=0,
    optimize=True
)

print("Animations generated successfully!")
