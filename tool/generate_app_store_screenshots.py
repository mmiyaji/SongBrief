# -*- coding: utf-8 -*-
from __future__ import annotations

import json
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
RAW_ROOT = ROOT / "store_assets" / "raw_screenshots"
OUT_ROOT = ROOT / "store_assets" / "app_store_screenshots"
ICON_PATH = ROOT / "assets" / "branding" / "songbrief_icon_ios.png"


SPECS = {
    "iphone_6_9": {
        "pixels": (1320, 2868),
        "raw_device": "iphone",
        "apple_display": "6.9-inch iPhone portrait",
    },
    "ipad_13": {
        "pixels": (2064, 2752),
        "raw_device": "ipad",
        "apple_display": "13-inch iPad portrait",
    },
}


CAPTIONS = {
    "en": {
        "tagline": "Apple Music library insights",
        "items": {
            "01_playing": (
                "Know what is playing now",
                "See the track, controls, lyrics, and context in one focused view.",
            ),
            "02_overview": (
                "Your library at a glance",
                "Totals, skip rate, listening records, and smart insights without clutter.",
            ),
            "03_rankings": (
                "Rank what matters",
                "Top songs stay central, with trends, rediscovery, and movement below.",
            ),
            "04_library": (
                "Browse every corner",
                "Search songs, albums, artists, genres, and playlists from one quiet surface.",
            ),
            "05_settings": (
                "Tune SongBrief to you",
                "Themes, privacy lock, hidden items, exports, and data controls.",
            ),
            "06_history": (
                "See habits grow over time",
                "Daily records reveal release-year focus and listening heatmaps.",
            ),
        },
    },
    "ja": {
        "tagline": "Apple Musicライブラリ分析",
        "items": {
            "01_playing": (
                "再生中を深く見る",
                "曲の詳細、操作、歌詞、関連情報をひとつの画面で確認。",
            ),
            "02_overview": (
                "ライブラリをひと目で把握",
                "総再生数、スキップ率、日々の記録を静かに整理。",
            ),
            "03_rankings": (
                "聴き方の変化をランキングで",
                "トップ曲を軸に、急上昇、再発見、順位変動まで確認。",
            ),
            "04_library": (
                "ライブラリをすばやく探索",
                "曲、アルバム、アーティスト、ジャンル、プレイリストを検索。",
            ),
            "05_settings": (
                "自分向けに調整",
                "テーマ、アプリロック、非表示項目、エクスポート、データ管理を設定。",
            ),
            "06_history": (
                "聴き方の履歴を見える化",
                "日々の記録から、発売年の偏りや再生ヒートマップを確認。",
            ),
        },
    },
}


def load_font(size: int, *, bold: bool = False) -> ImageFont.FreeTypeFont:
    candidates = [
        Path("C:/Windows/Fonts/meiryob.ttc" if bold else "C:/Windows/Fonts/meiryo.ttc"),
        Path("C:/Windows/Fonts/YuGothB.ttc" if bold else "C:/Windows/Fonts/YuGothR.ttc"),
        Path("/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc" if bold else "/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc"),
        Path("/usr/share/fonts/truetype/noto/NotoSansCJK-Bold.ttc" if bold else "/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc"),
        Path("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"),
    ]
    for path in candidates:
        if path.exists():
            return ImageFont.truetype(str(path), size=size)
    return ImageFont.load_default(size=size)


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)
    return mask


def wrap_text(text: str, font: ImageFont.FreeTypeFont, max_width: int) -> list[str]:
    draw = ImageDraw.Draw(Image.new("RGB", (1, 1)))
    if " " in text:
        lines: list[str] = []
        current = ""
        for word in text.split(" "):
            candidate = word if not current else f"{current} {word}"
            if draw.textbbox((0, 0), candidate, font=font)[2] <= max_width:
                current = candidate
            else:
                if current:
                    lines.append(current)
                current = word
        if current:
            lines.append(current)
        return lines

    lines = []
    current = ""
    for char in text:
        candidate = current + char
        if draw.textbbox((0, 0), candidate, font=font)[2] <= max_width:
            current = candidate
        else:
            if current:
                lines.append(current)
            current = char
    if current:
        lines.append(current)
    return lines


def draw_wrapped(
    draw: ImageDraw.ImageDraw,
    xy: tuple[int, int],
    text: str,
    font: ImageFont.FreeTypeFont,
    fill: str,
    max_width: int,
    line_gap: int,
) -> int:
    x, y = xy
    for line in wrap_text(text, font, max_width):
        draw.text((x, y), line, font=font, fill=fill)
        bbox = draw.textbbox((x, y), line, font=font)
        y = bbox[3] + line_gap
    return y


def paste_icon(canvas: Image.Image, x: int, y: int, size: int) -> None:
    icon = Image.open(ICON_PATH).convert("RGBA").resize((size, size), Image.Resampling.LANCZOS)
    canvas.alpha_composite(icon, (x, y))


def paste_device(
    canvas: Image.Image,
    raw: Image.Image,
    *,
    center_x: int,
    top: int,
    inner_width: int,
    border: int,
    radius: int,
) -> None:
    raw = raw.convert("RGBA")
    inner_height = round(inner_width * raw.height / raw.width)
    screenshot = raw.resize((inner_width, inner_height), Image.Resampling.LANCZOS)
    screen_x = center_x - inner_width // 2
    screen_y = top + border

    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    clip_radius = max(28, radius - border)
    shadow_draw.rounded_rectangle(
        (
            screen_x - border,
            screen_y - border,
            screen_x + inner_width + border,
            screen_y + inner_height + border,
        ),
        radius=clip_radius + border,
        fill=(0, 0, 0, 120),
    )
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(border * 2)))

    mask = rounded_mask((inner_width, inner_height), clip_radius)
    clipped = Image.new("RGBA", (inner_width, inner_height), (0, 0, 0, 0))
    clipped.alpha_composite(screenshot, (0, 0))
    clipped.putalpha(mask)
    canvas.alpha_composite(clipped, (screen_x, screen_y))


def draw_accent(draw: ImageDraw.ImageDraw, x: int, y: int, scale: float) -> None:
    h = max(8, int(10 * scale))
    draw.rounded_rectangle((x, y, x + int(310 * scale), y + h), radius=h // 2, fill="#53f2ce")
    draw.rounded_rectangle((x + int(340 * scale), y, x + int(490 * scale), y + h), radius=h // 2, fill="#d7ff3d")


def make_image(lang: str, spec_name: str, shot_name: str) -> Path:
    spec = SPECS[spec_name]
    width, height = spec["pixels"]
    raw_path = RAW_ROOT / lang / spec["raw_device"] / f"{shot_name}.png"
    raw = Image.open(raw_path)
    title, subtitle = CAPTIONS[lang]["items"][shot_name]

    canvas = Image.new("RGBA", (width, height), "#020a0a")
    draw = ImageDraw.Draw(canvas)
    scale = width / 1320

    margin = int(96 * scale)
    top = int(110 * scale)
    icon_size = int(96 * scale)
    paste_icon(canvas, margin, top, icon_size)

    brand_font = load_font(int(44 * scale), bold=True)
    tag_font = load_font(int(26 * scale))
    title_font = load_font(int((76 if spec_name == "iphone_6_9" else 82) * scale), bold=True)
    subtitle_font = load_font(int((36 if spec_name == "iphone_6_9" else 38) * scale))

    text_x = margin + icon_size + int(28 * scale)
    draw.text((text_x, top + int(10 * scale)), "SongBrief", font=brand_font, fill="#f6fbf8")
    draw.text((text_x, top + int(64 * scale)), CAPTIONS[lang]["tagline"], font=tag_font, fill="#98aaa7")

    headline_y = int(320 * scale if spec_name == "iphone_6_9" else 285 * scale)
    headline_width = width - margin * 2
    after_title = draw_wrapped(draw, (margin, headline_y), title, title_font, "#f6fbf8", headline_width, int(14 * scale))
    after_subtitle = draw_wrapped(
        draw,
        (margin, after_title + int(58 * scale)),
        subtitle,
        subtitle_font,
        "#a9bbb7",
        headline_width,
        int(12 * scale),
    )
    draw_accent(draw, margin, after_subtitle + int(40 * scale), scale)

    if spec_name == "iphone_6_9":
        paste_device(
            canvas,
            raw,
            center_x=width // 2,
            top=int(835 * scale),
            inner_width=int(850 * scale),
            border=int(16 * scale),
            radius=int(78 * scale),
        )
    else:
        paste_device(
            canvas,
            raw,
            center_x=width // 2,
            top=int(610 * scale),
            inner_width=int(1450 * scale),
            border=int(18 * scale),
            radius=int(58 * scale),
        )

    out_dir = OUT_ROOT / lang / spec_name
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{shot_name}.png"
    canvas.convert("RGB").save(out_path, optimize=True)
    return out_path


def shot_names() -> Iterable[str]:
    return [
        "01_playing",
        "02_overview",
        "03_rankings",
        "04_library",
        "05_settings",
        "06_history",
    ]


def main() -> None:
    files: list[str] = []
    for lang in CAPTIONS:
        for spec_name in SPECS:
            for shot_name in shot_names():
                path = make_image(lang, spec_name, shot_name)
                files.append(path.relative_to(ROOT).as_posix())

    manifest = {
        "source": "Actual screenshots captured from the local SongBrief web demo.",
        "specs": {
            key: {"pixels": value["pixels"], "apple_display": value["apple_display"]}
            for key, value in SPECS.items()
        },
        "files": files,
    }
    (OUT_ROOT / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
