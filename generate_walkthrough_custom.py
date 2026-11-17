import os
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import imageio.v3 as iio

# Load all 6 user screenshots
screenshots = {
    'now': Image.open('docs/screenshots/now.png').convert('RGBA'),
    'shortcuts': Image.open('docs/screenshots/shortcuts.png').convert('RGBA'),
    'media': Image.open('docs/screenshots/media.png').convert('RGBA'),
    'system': Image.open('docs/screenshots/system.png').convert('RGBA'),
    'shelf': Image.open('docs/screenshots/shelf.png').convert('RGBA'),
    'timers': Image.open('docs/screenshots/timers.png').convert('RGBA'),
}

WIDTH, HEIGHT = 1024, 576
FPS = 25

# Create a clean background (resting state wallpaper)
# In now.png, the area below y=240 is the skull, above y=240 inside the card is the card.
# When the card is closed, the area above y=240 is dark desktop vignette.
clean_bg = screenshots['now'].copy()
clean_draw = ImageDraw.Draw(clean_bg)
# Cover the island area (x=330..694, y=0..236) with smooth black/dark gradient matching the wallpaper
for y in range(238):
    alpha = max(0, min(255, int(255 * (1.0 - (y / 238.0)**2))))
    clean_draw.rectangle([330, y, 694, y+1], fill=(0, 0, 0, 255))
# Smooth blend into the fiery hair at y=230..245
for y in range(230, 245):
    t = (y - 230) / 15.0
    for x in range(330, 694):
        orig_p = screenshots['now'].getpixel((x, y))
        blended = (int(orig_p[0] * t), int(orig_p[1] * t), int(orig_p[2] * t), 255)
        clean_bg.putpixel((x, y), blended)

try:
    font_bold = ImageFont.truetype("arialbd.ttf", 16)
    font_sm = ImageFont.truetype("arial.ttf", 13)
    font_xs = ImageFont.truetype("arial.ttf", 11)
    font_badge = ImageFont.truetype("arialbd.ttf", 14)
except Exception:
    font_bold = ImageFont.load_default()
    font_sm = font_bold
    font_xs = font_bold
    font_badge = font_bold

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
total_frames = 200 # 8 seconds at 25 fps

# Sequence:
# 0-20: Resting pill on desktop, cursor approaches
# 21-45: Spring expansion into Now page (now.png)
# 46-70: Slide from Now to Shortcuts (shortcuts.png)
# 71-100: Slide from Shortcuts to Media (media.png) + animated equalizer bars
# 101-130: Slide from Media to System (system.png) + 20MB RAM highlight
# 131-155: Slide from System to Timers (timers.png)
# 156-175: Morph into compact Volume HUD capsule
# 176-199: Retract back to resting notch

for f in range(total_frames):
    frame = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 255))
    draw = ImageDraw.Draw(frame)

    if f < 20:
        # Resting notch on clean desktop
        frame.paste(clean_bg, (0, 0))
        t = f / 20.0
        pill_w = 160
        pill_h = 32
        pill_x = (WIDTH - pill_w) // 2
        pill_y = 0

        # Resting notch pill
        draw_rounded_rect(draw, [pill_x, pill_y - 10, pill_x + pill_w, pill_y + pill_h], 16, fill=(0, 0, 0, 245), outline=(50, 55, 68, 255), width=1)
        # Camera circle
        draw.ellipse([pill_x + 18, pill_y + 10, pill_x + 30, pill_y + 22], fill=(12, 16, 22, 255), outline=(35, 42, 54, 255))
        # Green privacy dot
        draw.ellipse([pill_x + 36, pill_y + 14, pill_x + 42, pill_y + 20], fill=(34, 197, 94, 255))
        # Time
        draw.text((pill_x + 58, pill_y + 9), "23:39", fill=(210, 220, 235, 230), font=font_sm)

        # Cursor gliding upwards
        cursor_x = int(WIDTH // 2 - 30 + t * 30)
        cursor_y = int(HEIGHT // 2 + (1.0 - t) * 100 - t * 80)
        draw.polygon([(cursor_x, cursor_y), (cursor_x, cursor_y + 18), (cursor_x + 5, cursor_y + 14), (cursor_x + 11, cursor_y + 22), (cursor_x + 14, cursor_y + 20), (cursor_x + 8, cursor_y + 12), (cursor_x + 14, cursor_y + 12)], fill=(255, 255, 255, 255), outline=(0, 0, 0, 200))

    elif f < 45:
        # Spring expansion into Now page
        p = (f - 20) / 25.0
        e = min(1.0, max(0.0, ease_out_back(min(1.0, p * 1.05))))

        frame.paste(clean_bg, (0, 0))

        # Morphing pill dimensions
        target_w = 330
        target_h = 236
        curr_w = int(160 + (target_w - 160) * e)
        curr_h = int(32 + (target_h - 32) * e)
        curr_x = (WIDTH - curr_w) // 2

        # When e > 0.4, blend in now.png
        if e > 0.3:
            alpha = int(255 * (e - 0.3) / 0.7)
            mask = Image.new("L", (WIDTH, HEIGHT), 0)
            mask_draw = ImageDraw.Draw(mask)
            mask_draw.rounded_rectangle([curr_x, 0, curr_x + curr_w, curr_h], radius=20, fill=alpha)
            frame.paste(screenshots['now'], (0, 0), mask)
        else:
            draw_rounded_rect(draw, [curr_x, -10, curr_x + curr_w, curr_h], 16, fill=(15, 18, 24, 250), outline=(56, 189, 248, int(200 * e)))

    elif f < 70:
        # Slide from Now to Shortcuts
        progress = (f - 45) / 25.0
        slide = ease_in_out_quad(min(1.0, progress))
        # Mask only the island region (x=330..694, y=0..245) for sliding
        card_w = 364
        card_x = (WIDTH - card_w) // 2
        card_h = 240

        frame.paste(screenshots['now'], (0, 0))
        # Slide shortcuts over now inside card mask
        slide_offset = int((1.0 - slide) * card_w)
        if slide_offset > 0:
            card_now = screenshots['now'].crop((card_x, 0, card_x + card_w, card_h))
            card_sc = screenshots['shortcuts'].crop((card_x, 0, card_x + card_w, card_h))
            
            card_composite = Image.new("RGBA", (card_w, card_h))
            card_composite.paste(card_now, (-int(slide * card_w), 0))
            card_composite.paste(card_sc, (slide_offset, 0))

            frame.paste(card_composite, (card_x, 0))
        else:
            frame.paste(screenshots['shortcuts'], (0, 0))

    elif f < 100:
        # Slide from Shortcuts to Media Player (with live equalizer)
        progress = (f - 70) / 30.0
        slide = ease_in_out_quad(min(1.0, progress * 1.3))
        card_w = 364
        card_x = (WIDTH - card_w) // 2
        card_h = 240

        if slide < 1.0:
            card_sc = screenshots['shortcuts'].crop((card_x, 0, card_x + card_w, card_h))
            card_media = screenshots['media'].crop((card_x, 0, card_x + card_w, card_h))
            card_composite = Image.new("RGBA", (card_w, card_h))
            card_composite.paste(card_sc, (-int(slide * card_w), 0))
            card_composite.paste(card_media, (int((1.0 - slide) * card_w), 0))
            frame.paste(screenshots['media'], (0, 0))
            frame.paste(card_composite, (card_x, 0))
        else:
            frame.paste(screenshots['media'], (0, 0))

        # Animated Audio Equalizer Bars on top of Coldplay album art!
        if slide > 0.4:
            eq_alpha = int(255 * (slide - 0.4) / 0.6)
            eq_x = card_x + 285
            eq_y = 48
            bar_w = 3
            num_bars = 5
            for b in range(num_bars):
                freq = math.sin((f * 0.5) + b * 1.1)
                bar_h = int(6 + abs(freq) * 16)
                color = (250, 204, 21, eq_alpha) # warm amber matching Yellow album
                draw.rectangle([eq_x + b * 5, eq_y - bar_h, eq_x + b * 5 + bar_w, eq_y], fill=color)

    elif f < 130:
        # Slide from Media to System Telemetry (highlighting ~20 MB RAM)
        progress = (f - 100) / 30.0
        slide = ease_in_out_quad(min(1.0, progress * 1.3))
        card_w = 364
        card_x = (WIDTH - card_w) // 2
        card_h = 240

        if slide < 1.0:
            card_media = screenshots['media'].crop((card_x, 0, card_x + card_w, card_h))
            card_sys = screenshots['system'].crop((card_x, 0, card_x + card_w, card_h))
            card_composite = Image.new("RGBA", (card_w, card_h))
            card_composite.paste(card_media, (-int(slide * card_w), 0))
            card_composite.paste(card_sys, (int((1.0 - slide) * card_w), 0))
            frame.paste(screenshots['system'], (0, 0))
            frame.paste(card_composite, (card_x, 0))
        else:
            frame.paste(screenshots['system'], (0, 0))

        # Highlight overlay badge for ~20MB RAM
        if slide > 0.5:
            badge_p = (slide - 0.5) / 0.5
            badge_alpha = int(255 * badge_p)
            # Pulsing emerald badge below island
            badge_x = card_x - 10
            badge_y = 205
            pulse = 0.5 + 0.5 * math.sin(f * 0.4)
            glow_c = (16, 185, 129, int(badge_alpha * (0.7 + 0.3 * pulse)))
            draw_rounded_rect(draw, [badge_x, badge_y, badge_x + 384, badge_y + 36], 12, fill=(10, 15, 20, 245), outline=glow_c, width=2)
            draw.text((badge_x + 16, badge_y + 9), "⚡ RAM ENGINE: ~20 MB IDLE", fill=(52, 211, 153, badge_alpha), font=font_badge)
            draw.text((badge_x + 225, badge_y + 11), "SetWindowRgn Active", fill=(148, 163, 184, badge_alpha), font=font_xs)

    elif f < 155:
        # Slide from System to Timers
        progress = (f - 130) / 25.0
        slide = ease_in_out_quad(min(1.0, progress))
        card_w = 364
        card_x = (WIDTH - card_w) // 2
        card_h = 240

        if slide < 1.0:
            card_sys = screenshots['system'].crop((card_x, 0, card_x + card_w, card_h))
            card_tm = screenshots['timers'].crop((card_x, 0, card_x + card_w, card_h))
            card_composite = Image.new("RGBA", (card_w, card_h))
            card_composite.paste(card_sys, (-int(slide * card_w), 0))
            card_composite.paste(card_tm, (int((1.0 - slide) * card_w), 0))
            frame.paste(screenshots['timers'], (0, 0))
            frame.paste(card_composite, (card_x, 0))
        else:
            frame.paste(screenshots['timers'], (0, 0))

    elif f < 175:
        # Morph into compact Volume HUD Capsule
        p = (f - 155) / 20.0
        e = ease_out_cubic(p)
        frame.paste(clean_bg, (0, 0))

        vol_w = int(364 - (364 - 240) * e)
        vol_h = int(240 - (240 - 44) * e)
        vol_x = (WIDTH - vol_w) // 2
        vol_y = 0

        draw_rounded_rect(draw, [vol_x, vol_y - 10, vol_x + vol_w, vol_y + vol_h], 20, fill=(12, 16, 24, 250), outline=(56, 189, 248, 220), width=1)

        if e > 0.4:
            v_alpha = int(255 * (e - 0.4) / 0.6)
            # Volume icon
            draw.text((vol_x + 16, vol_y + 13), "🔊", fill=(255, 255, 255, v_alpha), font=font_sm)
            # Slider track
            slider_x = vol_x + 46
            slider_y = vol_y + 18
            slider_w = vol_w - 105
            draw_rounded_rect(draw, [slider_x, slider_y, slider_x + slider_w, slider_y + 8], 4, fill=(30, 41, 59, v_alpha))
            vol_level = 0.50 + (p * 0.25) # 50% -> 75%
            draw_rounded_rect(draw, [slider_x, slider_y, slider_x + int(slider_w * vol_level), slider_y + 8], 4, fill=(56, 189, 248, v_alpha))
            draw.text((vol_x + vol_w - 48, vol_y + 13), f"{int(vol_level*100)}%", fill=(224, 242, 254, v_alpha), font=font_bold)

    else:
        # Retract back to resting notch
        p = (f - 175) / 25.0
        e = 1.0 - ease_out_cubic(p)
        frame.paste(clean_bg, (0, 0))

        vol_w = int(160 + (240 - 160) * e)
        vol_h = int(32 + (44 - 32) * e)
        vol_x = (WIDTH - vol_w) // 2
        vol_y = 0

        draw_rounded_rect(draw, [vol_x, vol_y - 10, vol_x + vol_w, vol_y + vol_h], 16, fill=(0, 0, 0, 245), outline=(50, 55, 68, 255), width=1)
        if e < 0.3:
            draw.ellipse([vol_x + 18, vol_y + 10, vol_x + 30, vol_y + 22], fill=(12, 16, 22, 255), outline=(35, 42, 54, 255))
            draw.ellipse([vol_x + 36, vol_y + 14, vol_x + 42, vol_y + 20], fill=(34, 197, 94, 255))
            draw.text((vol_x + 58, vol_y + 9), "23:39", fill=(210, 220, 235, 230), font=font_sm)

    frames.append(np.array(frame.convert("RGB")))

print("Writing walkthrough MP4...")
iio.imwrite("docs/animations/notchpyx_walkthrough.mp4", frames, fps=FPS)

print("Writing walkthrough GIF (subsampled 12.5 fps)...")
# Subsample frames to keep GIF compact (~2.5 MB) and fast to load
gif_frames = [Image.fromarray(f).resize((800, 450), Image.Resampling.LANCZOS).quantize(colors=128, method=Image.Quantize.MEDIANCUT) for f in frames[::2]]
gif_frames[0].save(
    "docs/animations/notchpyx_walkthrough.gif",
    save_all=True,
    append_images=gif_frames[1:],
    duration=80,
    loop=0,
    optimize=True
)

print("Animations updated successfully!")
