"""Build the small runtime-safe PNG variants used by the E17 Qt interface.

The source masters remain outside this repository and are never modified.
Run this script during development only; the generated PNGs are committed so
the 3ds Max plugin never needs Pillow or network access at runtime.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


DEFAULT_SOURCE = Path(
    r"D:\Ameno\Marca\AMENO_ACERVO_2026-09-08\01_IDENTIDADE_AMENO\V2"
)
DEFAULT_OUTPUT = (
    Path(__file__).resolve().parents[1]
    / "Contents"
    / "python"
    / "ameno_ui"
    / "assets"
    / "brand"
)
OFF_WHITE = (232, 232, 224)
AMENO_RED = (230, 59, 46)


def _content_runs(image: Image.Image) -> list[tuple[int, int]]:
    alpha = image.getchannel("A")
    occupied = []
    for x in range(image.width):
        occupied.append(alpha.crop((x, 0, x + 1, image.height)).getbbox() is not None)
    runs: list[tuple[int, int]] = []
    start = None
    for x, filled in enumerate(occupied + [False]):
        if filled and start is None:
            start = x
        elif not filled and start is not None:
            runs.append((start, x - 1))
            start = None
    return runs


def _tight(image: Image.Image, padding: int = 24) -> Image.Image:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("O master informado não contém pixels visíveis.")
    left = max(0, bbox[0] - padding)
    top = max(0, bbox[1] - padding)
    right = min(image.width, bbox[2] + padding)
    bottom = min(image.height, bbox[3] + padding)
    return image.crop((left, top, right, bottom))


def _recolor_wordmark(source: Path) -> Image.Image:
    image = Image.open(source).convert("RGBA")
    runs = _content_runs(image)
    if len(runs) < 2:
        raise ValueError("Não foi possível isolar o O no master do wordmark.")
    split = runs[-1][0]
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            alpha = pixels[x, y][3]
            if alpha:
                color = AMENO_RED if x >= split else OFF_WHITE
                pixels[x, y] = (color[0], color[1], color[2], alpha)
    return _tight(image)


def _recolor_symbol(source: Path) -> Image.Image:
    image = Image.open(source).convert("RGBA")
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            alpha = pixels[x, y][3]
            if alpha:
                pixels[x, y] = (AMENO_RED[0], AMENO_RED[1], AMENO_RED[2], alpha)
    return _tight(image)


def _save_width(image: Image.Image, destination: Path, width: int) -> None:
    height = max(1, round(image.height * width / image.width))
    resized = image.resize((width, height), Image.Resampling.LANCZOS)
    resized.save(destination, optimize=True)


def _save_square(image: Image.Image, destination: Path, size: int) -> None:
    side = max(image.width, image.height)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.alpha_composite(image, ((side - image.width) // 2, (side - image.height) // 2))
    canvas.resize((size, size), Image.Resampling.LANCZOS).save(destination, optimize=True)


def build(source_root: Path, output: Path) -> None:
    output.mkdir(parents=True, exist_ok=True)
    wordmark = _recolor_wordmark(source_root / "ameno-v2-standard-transparent.png")
    symbol = _recolor_symbol(source_root / "ameno-v2-symbol-o-transparent.png")
    _save_width(wordmark, output / "ameno-wordmark-dark.png", 900)
    _save_width(wordmark, output / "ameno-wordmark-dark@2x.png", 1800)
    _save_square(symbol, output / "ameno-symbol-red.png", 128)
    _save_square(symbol, output / "ameno-symbol-red@2x.png", 256)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-root", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    build(args.source_root, args.output)


if __name__ == "__main__":
    main()
