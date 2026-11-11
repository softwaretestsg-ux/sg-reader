import os
import math
import struct
import wave
import subprocess
from PIL import Image, ImageDraw, ImageFont

OUTPUT_DIR = "/Users/nalin/.gemini/antigravity/scratch/sg_reader/promo"
WIDTH = 1080
HEIGHT = 1920
FPS = 30
TOTAL_DURATION = 30
TOTAL_FRAMES = FPS * TOTAL_DURATION

# Fonts
FONT_DIR = "/System/Library/Fonts/Supplemental"
try:
    font_title = ImageFont.truetype(f"{FONT_DIR}/Arial Bold.ttf", 44)
    font_h1 = ImageFont.truetype(f"{FONT_DIR}/Arial Bold.ttf", 36)
    font_h2 = ImageFont.truetype(f"{FONT_DIR}/Arial Bold.ttf", 30)
    font_body_bold = ImageFont.truetype(f"{FONT_DIR}/Arial Bold.ttf", 25)
    font_body = ImageFont.truetype(f"{FONT_DIR}/Arial.ttf", 25)
    font_caption = ImageFont.truetype(f"{FONT_DIR}/Arial.ttf", 21)
    font_badge = ImageFont.truetype(f"{FONT_DIR}/Arial Bold.ttf", 22)
    # Native Hindi font for full matras & ligatures (Kohinoor Devanagari Bold)
    font_tagline = ImageFont.truetype("/System/Library/Fonts/Kohinoor.ttc", 32, index=3)
    font_tagline_small = ImageFont.truetype("/System/Library/Fonts/Kohinoor.ttc", 28, index=3)
except Exception:
    font_title = ImageFont.load_default()
    font_h1 = font_title
    font_h2 = font_title
    font_body_bold = font_title
    font_body = font_title
    font_caption = font_title
    font_badge = font_title
    font_tagline = font_title
    font_tagline_small = font_title

# Logo
LOGO_PATH = "/Users/nalin/.gemini/antigravity/scratch/sg_reader/assets/images/logo-sg.webp"
logo_img = None
if os.path.exists(LOGO_PATH):
    try:
        logo_img = Image.open(LOGO_PATH).convert("RGBA")
        logo_img = logo_img.resize((320, 138), Image.Resampling.LANCZOS)
    except Exception as e:
        print("Logo load error:", e)

# Theme Colors (Warm Dark & Terracotta)
BG_DARK = (23, 19, 16)
SURFACE = (31, 25, 19)
SURFACE_CARD = (36, 29, 23)
ACCENT_TERRA = (221, 139, 83)      # #DD8B53
ACCENT_DEEP = (176, 74, 36)        # #B04A24
TEXT_LIGHT = (242, 236, 225)       # #F2ECE1
TEXT_MUTED = (168, 159, 145)       # #A89F91
BORDER = (54, 42, 31)
RED_ACCENT = (229, 83, 75)
GREEN_ACCENT = (76, 175, 80)
BLUE_ACCENT = (74, 126, 187)

def wrap_text(draw, text, font, max_width):
    """Splits text into multiple lines that strictly fit within max_width."""
    words = text.split()
    if not words:
        return []
    lines = []
    current_line = []
    for word in words:
        test_line = ' '.join(current_line + [word])
        bbox = draw.textbbox((0, 0), test_line, font=font)
        w = bbox[2] - bbox[0]
        if w <= max_width:
            current_line.append(word)
        else:
            if current_line:
                lines.append(' '.join(current_line))
                current_line = [word]
            else:
                lines.append(word)
                current_line = []
    if current_line:
        lines.append(' '.join(current_line))
    return lines

# Load Native Rendered Footer Card (Cocoa / CoreText OpenType Shaped)
FOOTER_CARD_PATH = f"{OUTPUT_DIR}/footer_card_960.png"
footer_card_img = None
if os.path.exists(FOOTER_CARD_PATH):
    try:
        footer_card_img = Image.open(FOOTER_CARD_PATH).convert("RGBA")
    except Exception as e:
        print("Footer card load error:", e)

def draw_header(draw):
    # Top safe area: 0 to 140px (compatible with WhatsApp story bars and Android status bar)
    draw.rectangle([(0, 0), (WIDTH, 140)], fill=SURFACE)
    draw.line([(0, 140), (WIDTH, 140)], fill=BORDER, width=2)
    # Header badge
    draw.rounded_rectangle([(60, 45), (300, 95)], radius=10, fill=(46, 34, 24), outline=ACCENT_DEEP, width=2)
    draw.text((180, 70), "100% OFFLINE SUITE", fill=ACCENT_TERRA, font=font_badge, anchor="mm")
    # Header right text
    draw.text((WIDTH - 60, 70), "Social Googol", fill=TEXT_LIGHT, font=font_body_bold, anchor="rm")

def draw_footer(im, draw, global_frame):
    """
    WhatsApp Status Safe Branding Card:
    Placed strictly between Y = 1450 and Y = 1630 (Height 180px).
    Rendered with native CoreText OpenType shaping:
    - 100% correct Hindi ligatures: "सुरक्षा से ग्रोथ तक" (no broken virama/halant)
    - Full color native Apple icons for Phone and Globe
    The area Y = 1630 to 1920 (290px buffer) is kept clean for WhatsApp Status
    'Reply' bar, swipe-up gesture, and dark bottom gradient overlay!
    """
    card_top = 1450
    card_bot = 1630
    if footer_card_img:
        im.paste(footer_card_img, (60, card_top), footer_card_img)
    else:
        draw.rounded_rectangle([(60, card_top), (WIDTH - 60, card_bot)], radius=22, fill=SURFACE, outline=BORDER, width=2)

    # Progress bar at bottom of card (Y = 1634)
    progress = global_frame / float(TOTAL_FRAMES)
    draw.rectangle([(60, card_bot + 4), (60 + int((WIDTH - 120) * progress), card_bot + 9)], fill=ACCENT_TERRA)

# ----------------- SCENE RENDERERS -----------------

def render_scene_1(frame_in_scene, total_in_scene, global_frame):
    # Scene 1: The Problem & Privacy Promise (0.0s - 5.5s)
    im = Image.new("RGB", (WIDTH, HEIGHT), BG_DARK)
    draw = ImageDraw.Draw(im)
    draw_header(draw)
    draw_footer(im, draw, global_frame)

    t = frame_in_scene / float(total_in_scene)
    pulse = (math.sin(t * math.pi * 4) + 1.0) / 2.0

    # Card 1: Problem Card (Strictly within X: 60 to 1020, w=960)
    card1_top = 180
    card1_bot = 560
    draw.rounded_rectangle([(60, card1_top), (WIDTH - 60, card1_bot)], radius=24, fill=(40, 24, 24), outline=RED_ACCENT, width=3)
    
    draw.text((WIDTH // 2, card1_top + 50), "⚠️  PROBLEMS WITH MOST DOCUMENT APPS", fill=RED_ACCENT, font=font_h1, anchor="mm")
    draw.line([(100, card1_top + 90), (WIDTH - 100, card1_top + 90)], fill=(80, 36, 36), width=1)

    problems = [
        "• Bombard you with distracting full-screen popup ads",
        "• Trap basic features behind expensive monthly subscriptions",
        "• Secretly upload your private documents to external servers",
    ]
    py = card1_top + 120
    for prob in problems:
        lines = wrap_text(draw, prob, font_body, 860)
        for line in lines:
            draw.text((100, py), line, fill=TEXT_LIGHT, font=font_body)
            py += 36
        py += 12

    # Card 2: Solution Promise (Strictly within X: 60 to 1020)
    card2_top = 600
    card2_bot = 1040
    draw.rounded_rectangle([(60, card2_top), (WIDTH - 60, card2_bot)], radius=24, fill=SURFACE_CARD, outline=ACCENT_TERRA, width=3)

    draw.text((WIDTH // 2, card2_top + 65), "YOUR CONFIDENTIAL FILES", fill=TEXT_LIGHT, font=font_title, anchor="mm")
    draw.text((WIDTH // 2, card2_top + 130), "DESERVE 100% PRIVACY.", fill=ACCENT_TERRA, font=font_title, anchor="mm")
    draw.line([(120, card2_top + 180), (WIDTH - 120, card2_top + 180)], fill=BORDER, width=2)

    pillars = [
        "🔒  Zero Cloud Uploads: Files never leave your phone",
        "🛡️  Air-Gapped Security: Completely offline sandbox",
        "🚫  Zero Advertisements: Clean, distraction-free interface",
    ]
    py = card2_top + 215
    for pil in pillars:
        draw.text((WIDTH // 2, py), pil, fill=TEXT_MUTED, font=font_h2, anchor="mm")
        py += 60

    # Call to Action Button (width 840, centered, strictly contained)
    btn_top = 1080
    btn_bot = 1200
    btn_outline = (int(ACCENT_TERRA[0] * (0.8 + 0.2 * pulse)), int(ACCENT_TERRA[1] * (0.8 + 0.2 * pulse)), int(ACCENT_TERRA[2] * (0.8 + 0.2 * pulse)))
    draw.rounded_rectangle([(WIDTH // 2 - 420, btn_top), (WIDTH // 2 + 420, btn_bot)], radius=20, fill=ACCENT_DEEP, outline=btn_outline, width=3)
    draw.text((WIDTH // 2, (btn_top + btn_bot) // 2), "DISCOVER THE 100% FREE SOLUTION ⬇️", fill=(255, 255, 255), font=font_h2, anchor="mm")

    return im

def render_scene_2(frame_in_scene, total_in_scene, global_frame):
    # Scene 2: Brand Identity & Core Architecture (5.5s - 11.5s)
    im = Image.new("RGB", (WIDTH, HEIGHT), BG_DARK)
    draw = ImageDraw.Draw(im)
    draw_header(draw)
    draw_footer(im, draw, global_frame)

    # Logo Card (Centered)
    draw.rounded_rectangle([(WIDTH // 2 - 180, 175), (WIDTH // 2 + 180, 325)], radius=20, fill=SURFACE_CARD, outline=ACCENT_TERRA, width=2)
    if logo_img:
        im.paste(logo_img, (WIDTH // 2 - 160, 185), logo_img)

    draw.text((WIDTH // 2, 365), "Social Googol's", fill=TEXT_MUTED, font=font_h2, anchor="mm")
    draw.text((WIDTH // 2, 420), "SG READER", fill=TEXT_LIGHT, font=font_title, anchor="mm")

    # 3 Structured Pillar Cards (width=960)
    pillars = [
        ("🔒 100% Offline Sandbox", "Zero external network calls. All files processed locally in memory.", GREEN_ACCENT),
        ("🛡️ Biometric & PIN Lock", "Hardware fingerprint/PIN lock keeps sensitive documents protected.", ACCENT_TERRA),
        ("⚡ High-Speed Performance", "Instant cold launch under 0.8s on any Android device.", BLUE_ACCENT),
    ]

    card_y = 480
    for title, desc, col in pillars:
        draw.rounded_rectangle([(60, card_y), (WIDTH - 60, card_y + 150)], radius=18, fill=SURFACE_CARD, outline=col, width=2)
        draw.text((100, card_y + 36), title, fill=col, font=font_h1)
        lines = wrap_text(draw, desc, font_body, 840)
        ly = card_y + 85
        for line in lines:
            draw.text((100, ly), line, fill=TEXT_LIGHT, font=font_body)
            ly += 30
        card_y += 175

    # Big Green Badge
    badge_top = card_y + 20
    draw.rounded_rectangle([(60, badge_top), (WIDTH - 60, badge_top + 95)], radius=20, fill=(30, 48, 30), outline=GREEN_ACCENT, width=3)
    draw.text((WIDTH // 2, badge_top + 48), "✅  100% FREE FOREVER • ZERO SUBSCRIPTION", fill=GREEN_ACCENT, font=font_h1, anchor="mm")

    return im

def render_scene_3(frame_in_scene, total_in_scene, global_frame):
    # Scene 3: Full Office Suite Capabilities (11.5s - 18.0s)
    im = Image.new("RGB", (WIDTH, HEIGHT), BG_DARK)
    draw = ImageDraw.Draw(im)
    draw_header(draw)
    draw_footer(im, draw, global_frame)

    draw.text((WIDTH // 2, 185), "ALL YOUR DOCUMENTS.", fill=TEXT_LIGHT, font=font_title, anchor="mm")
    draw.text((WIDTH // 2, 240), "ONE POWERFUL OFFLINE SUITE.", fill=ACCENT_TERRA, font=font_h1, anchor="mm")

    # 4 Document Cards (Strictly within X: 60 to 1020, w=960)
    docs = [
        ("📕 PDF DOCUMENT", "Continuous Page Layout • In-Place Note Stamps • Offline Sharing", RED_ACCENT, (42, 26, 26)),
        ("📊 EXCEL SPREADSHEET", "Full XLSX, XLS & CSV • Cell Formula Bar • Add Rows/Cols • Direct Save", GREEN_ACCENT, (24, 42, 24)),
        ("📝 WORD PROCESSOR", "Full DOCX WYSIWYG Editing • Rich Toolbar • Add Lines • Full Page Flow", BLUE_ACCENT, (24, 34, 48)),
        ("📽️ POWERPOINT SLIDES", "Smooth Presentation Viewer • Slide-by-Slide Review & Offline Deck", ACCENT_TERRA, (42, 32, 24)),
    ]

    card_y = 295
    for title, desc, border_col, fill_col in docs:
        draw.rounded_rectangle([(60, card_y), (WIDTH - 60, card_y + 170)], radius=18, fill=fill_col, outline=border_col, width=2)
        draw.text((100, card_y + 36), title, fill=border_col, font=font_h1)
        lines = wrap_text(draw, desc, font_body, 820)
        ly = card_y + 86
        for line in lines:
            draw.text((100, ly), line, fill=TEXT_LIGHT, font=font_body)
            ly += 30
        # Checkmark
        draw.text((WIDTH - 120, card_y + 55), "✓", fill=border_col, font=font_title)
        card_y += 195

    # Bottom summary box
    draw.rounded_rectangle([(60, 1110), (WIDTH - 60, 1195)], radius=18, fill=SURFACE_CARD, outline=ACCENT_TERRA, width=2)
    draw.text((WIDTH // 2, 1152), "READ   •   EDIT   •   SAVE   •   SHARE", fill=ACCENT_TERRA, font=font_h1, anchor="mm")

    draw.text((WIDTH // 2, 1235), "Auto-detects files shared via WhatsApp & File Manager!", fill=TEXT_LIGHT, font=font_h2, anchor="mm")
    return im

def render_scene_4(frame_in_scene, total_in_scene, global_frame):
    # Scene 4: Built-in Document Scanner & Multi-Format Export (18.0s - 24.5s)
    im = Image.new("RGB", (WIDTH, HEIGHT), BG_DARK)
    draw = ImageDraw.Draw(im)
    draw_header(draw)
    draw_footer(im, draw, global_frame)

    t = frame_in_scene / float(total_in_scene)

    draw.text((WIDTH // 2, 185), "IN-BUILT DOCUMENT SCANNER", fill=ACCENT_TERRA, font=font_title, anchor="mm")
    draw.text((WIDTH // 2, 235), "Camera Scan • Auto-Refine • Save Any Format", fill=TEXT_LIGHT, font=font_h2, anchor="mm")

    # Scanner Viewfinder Box (Centered, w=760, h=370)
    box_x1 = 160
    box_x2 = WIDTH - 160
    box_y1 = 275
    box_y2 = 635
    draw.rounded_rectangle([(box_x1, box_y1), (box_x2, box_y2)], radius=18, fill=(255, 255, 255), outline=ACCENT_DEEP, width=3)
    # Simulated document lines
    draw.rectangle([(box_x1 + 40, box_y1 + 35), (box_x2 - 40, box_y1 + 65)], fill=(40, 40, 40))
    for ly in range(box_y1 + 95, box_y2 - 35, 30):
        draw.rectangle([(box_x1 + 40, ly), (box_x2 - 40, ly + 12)], fill=(200, 200, 200))

    # Scanner Laser Line (Oscillating)
    laser_progress = (math.sin(t * math.pi * 6) + 1.0) / 2.0
    laser_y = box_y1 + int(laser_progress * 350)
    draw.line([(box_x1, laser_y), (box_x2, laser_y)], fill=GREEN_ACCENT, width=4)
    draw.text((WIDTH // 2, box_y2 - 32), "🪄 AI ENHANCING DOCUMENT CONTOURS...", fill=(30, 120, 40), font=font_body_bold, anchor="mm")

    # Filter Chips (Row 1: 3 chips, Row 2: 2 chips)
    chips_r1 = ["🪄 Auto Refine", "📄 Crisp B&W", "🔘 Grayscale"]
    cx = 60
    cy = 665
    cw = 300
    for chip in chips_r1:
        draw.rounded_rectangle([(cx, cy), (cx + cw, cy + 60)], radius=14, fill=SURFACE_CARD, outline=ACCENT_TERRA, width=2)
        draw.text((cx + cw // 2, cy + 30), chip, fill=ACCENT_TERRA, font=font_body_bold, anchor="mm")
        cx += cw + 30

    chips_r2 = ["🎨 Enhanced Color", "🔄 90° Rotate"]
    cx = (WIDTH - (2 * 360 + 30)) // 2
    cy = 740
    cw = 360
    for chip in chips_r2:
        draw.rounded_rectangle([(cx, cy), (cx + cw, cy + 60)], radius=14, fill=SURFACE_CARD, outline=ACCENT_TERRA, width=2)
        draw.text((cx + cw // 2, cy + 30), chip, fill=ACCENT_TERRA, font=font_body_bold, anchor="mm")
        cx += cw + 30

    # Multi-Format Export Card (width=960, top=825, bot=1255)
    draw.rounded_rectangle([(60, 825), (WIDTH - 60, 1255)], radius=24, fill=SURFACE_CARD, outline=GREEN_ACCENT, width=2)
    draw.text((WIDTH // 2, 865), "EXPORT INTO ANY FORMAT:", fill=GREEN_ACCENT, font=font_h1, anchor="mm")
    draw.line([(100, 905), (WIDTH - 100, 905)], fill=BORDER, width=2)

    formats = [
        ("📕 PDF Document (.pdf)", "Multi-page standard A4 document layout"),
        ("📘 Word Document (.docx)", "OpenXML with embedded scan pages"),
        ("🖼️ High-Res Images (.jpg)", "Clean enhanced individual image capture"),
        ("🗂️ ZIP Package (.zip)", "Archived scan bundle + manifest text"),
    ]
    fy = 930
    for fmt_title, fmt_desc in formats:
        draw.text((100, fy), fmt_title, fill=TEXT_LIGHT, font=font_h2)
        draw.text((100, fy + 36), fmt_desc, fill=TEXT_MUTED, font=font_caption)
        fy += 78

    return im

def render_scene_5(frame_in_scene, total_in_scene, global_frame):
    # Scene 5: Grand Invitation & Download CTA (24.5s - 30.0s)
    im = Image.new("RGB", (WIDTH, HEIGHT), BG_DARK)
    draw = ImageDraw.Draw(im)
    draw_header(draw)
    draw_footer(im, draw, global_frame)

    t = frame_in_scene / float(total_in_scene)
    pulse = (math.sin(t * math.pi * 4) + 1.0) / 2.0

    # Logo
    if logo_img:
        draw.rounded_rectangle([(WIDTH // 2 - 180, 175), (WIDTH // 2 + 180, 320)], radius=20, fill=SURFACE_CARD, outline=ACCENT_TERRA, width=2)
        im.paste(logo_img, (WIDTH // 2 - 160, 185), logo_img)

    draw.text((WIDTH // 2, 360), "YOU ARE INVITED TO TEST", fill=TEXT_LIGHT, font=font_h1, anchor="mm")
    draw.text((WIDTH // 2, 415), "SOCIAL GOOGOL SG READER", fill=ACCENT_TERRA, font=font_title, anchor="mm")

    # Big 100% Free Box (w=960)
    free_top = 465
    free_bot = 585
    draw.rounded_rectangle([(60, free_top), (WIDTH - 60, free_bot)], radius=20, fill=(28, 48, 28), outline=GREEN_ACCENT, width=3)
    draw.text((WIDTH // 2, free_top + 40), "🎉  100% FREE FOREVER • ZERO ADS", fill=GREEN_ACCENT, font=font_title, anchor="mm")
    draw.text((WIDTH // 2, free_top + 88), "Air-Gapped Privacy • Enterprise Document Power", fill=TEXT_LIGHT, font=font_h2, anchor="mm")

    # Checklist (w=960, top=615, bot=995)
    draw.rounded_rectangle([(60, 615), (WIDTH - 60, 995)], radius=20, fill=SURFACE_CARD, outline=BORDER, width=2)
    draw.text((WIDTH // 2, 650), "OFFICIAL FEATURE HIGHLIGHTS", fill=ACCENT_TERRA, font=font_h2, anchor="mm")
    draw.line([(100, 685), (WIDTH - 100, 685)], fill=BORDER, width=1)

    checklist = [
        "✓ Read & Edit PDF, Excel (XLSX/XLS), Word (DOCX) & PPT",
        "✓ Built-in Document Scanner with AI Auto-Refining Filters",
        "✓ Multi-Format Export: Save as PDF, Word, Images or ZIP",
        "✓ 1-Tap 'Clear All' Recent Documents & Swipe-to-Dismiss",
        "✓ Hardware Fingerprint / PIN Biometric Security Lock",
    ]
    cy = 708
    for item in checklist:
        draw.text((100, cy), item, fill=TEXT_LIGHT, font=font_body)
        cy += 54

    # Big Download Box (w=960, top=1025, bot=1240) - Reply DEMO CTA
    dl_top = 1025
    dl_bot = 1240
    border_w = 3 + int(pulse * 2)
    draw.rounded_rectangle([(60, dl_top), (WIDTH - 60, dl_bot)], radius=24, fill=ACCENT_DEEP, outline=ACCENT_TERRA, width=border_w)
    draw.text((WIDTH // 2, dl_top + 50), "WANT TO TEST THIS APP?", fill=(255, 255, 255), font=font_title, anchor="mm")
    draw.text((WIDTH // 2, dl_top + 115), "💬  REPLY \"DEMO\"", fill=GREEN_ACCENT, font=font_title, anchor="mm")
    draw.text((WIDTH // 2, dl_top + 170), "and we will share the download link!", fill=TEXT_LIGHT, font=font_h2, anchor="mm")

    return im

# ----------------- AUDIO GENERATION -----------------

def generate_audio(output_path):
    sample_rate = 44100
    total_samples = sample_rate * TOTAL_DURATION
    wav_file = wave.open(output_path, 'w')
    wav_file.setnchannels(1)
    wav_file.setsampwidth(2)
    wav_file.setframerate(sample_rate)

    samples = []
    beat_dur = 60.0 / 120.0  # 120 BPM

    for i in range(total_samples):
        t = i / float(sample_rate)

        # Kick on every beat
        beat_t = t % beat_dur
        kick_freq = 55.0 * math.exp(-beat_t * 8.0)
        kick = math.sin(2 * math.pi * kick_freq * beat_t) * math.exp(-beat_t * 6.0) if beat_t < 0.3 else 0.0

        # Hi-hat on offbeats
        offbeat_t = (t + beat_dur / 2.0) % beat_dur
        hat_noise = (math.sin(t * 12000.0) + math.sin(t * 18000.0)) * math.exp(-offbeat_t * 25.0) if offbeat_t < 0.1 else 0.0

        # Tech synth melodic pulse
        chord_freqs = [220.0, 277.18, 329.63, 440.0]
        chord_idx = int(t / 2.0) % len(chord_freqs)
        synth_freq = chord_freqs[chord_idx]
        synth = 0.25 * math.sin(2 * math.pi * synth_freq * t) * (0.8 + 0.2 * math.sin(2 * math.pi * 4.0 * t))

        # Transition swooshes at scene boundaries (0, 5.5, 11.5, 18.0, 24.5s)
        swoosh = 0.0
        for transition in [5.5, 11.5, 18.0, 24.5]:
            diff = t - transition
            if -0.4 < diff < 0.2:
                freq = 400.0 + (diff + 0.4) * 1200.0
                swoosh += 0.35 * math.sin(2 * math.pi * freq * t) * math.exp(-abs(diff) * 5.0)

        mix = (kick * 0.45) + (hat_noise * 0.15) + (synth * 0.35) + swoosh
        mix = max(-1.0, min(1.0, mix))
        sample_val = int(mix * 32767)
        samples.append(sample_val)

    packed = struct.pack(f'<{len(samples)}h', *samples)
    wav_file.writeframes(packed)
    wav_file.close()

# ----------------- MAIN PIPELINE -----------------

def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    frames_dir = f"{OUTPUT_DIR}/frames"
    os.makedirs(frames_dir, exist_ok=True)
    
    print("Generating 30s WhatsApp Status Safe promo video frames (900 frames @ 30fps)...")

    f_s1 = int(5.5 * FPS)
    f_s2 = int(11.5 * FPS)
    f_s3 = int(18.0 * FPS)
    f_s4 = int(24.5 * FPS)
    f_s5 = TOTAL_FRAMES

    for frame_idx in range(TOTAL_FRAMES):
        if frame_idx < f_s1:
            im = render_scene_1(frame_idx, f_s1, frame_idx)
        elif frame_idx < f_s2:
            im = render_scene_2(frame_idx - f_s1, f_s2 - f_s1, frame_idx)
        elif frame_idx < f_s3:
            im = render_scene_3(frame_idx - f_s2, f_s3 - f_s2, frame_idx)
        elif frame_idx < f_s4:
            im = render_scene_4(frame_idx - f_s3, f_s4 - f_s3, frame_idx)
        else:
            im = render_scene_5(frame_idx - f_s4, f_s5 - f_s4, frame_idx)

        im.save(f"{frames_dir}/frame_{frame_idx:05d}.jpg", quality=85)
        if frame_idx % 150 == 0:
            print(f"Rendered {frame_idx}/{TOTAL_FRAMES} frames ({int(frame_idx/TOTAL_FRAMES*100)}%)...")

    print("Frames rendered! Using professional background music...")
    audio_path = f"{OUTPUT_DIR}/professional_bg_music.wav"
    if not os.path.exists(audio_path):
        generate_audio(audio_path)

    print("Compiling MP4 video with ffmpeg...")
    output_mp4 = f"{OUTPUT_DIR}/SG_Reader_30s_Promo.mp4"
    ffmpeg_cmd = [
        "/opt/homebrew/bin/ffmpeg",
        "-y",
        "-r", "30",
        "-i", f"{frames_dir}/frame_%05d.jpg",
        "-i", audio_path,
        "-c:v", "libx264",
        "-profile:v", "baseline",
        "-level", "3.1",
        "-preset", "fast",
        "-crf", "22",
        "-pix_fmt", "yuv420p",
        "-c:a", "aac",
        "-b:a", "192k",
        "-ar", "44100",
        "-movflags", "+faststart",
        "-shortest",
        output_mp4
    ]
    subprocess.run(ffmpeg_cmd, check=True)
    print(f"Promo video successfully generated: {output_mp4}")

if __name__ == "__main__":
    main()
