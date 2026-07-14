#!/usr/bin/env python3
"""预生成发音学习页所需的全部单音节/例词音频。

用法:
    pip install edge-tts
    python3 scripts/generate_hangul_audio.py

- 音源: 微软 Azure 神经语音 ko-KR-SunHiNeural（经 edge-tts 免费接口）
- 输出: TripKorean/Resources/HangulAudio/<Unicode码点>.mp3，如 아 → C544.mp3
- 文本来源: 自动解析 Models/Hangul.swift 中的 soundText/exampleWord，
  外加 14×10 音节拼读表和首页示例字「한」
- 已存在且有效的文件会跳过，可反复运行增量补齐
"""
import asyncio
import re
from pathlib import Path

import edge_tts

ROOT = Path(__file__).resolve().parent.parent
SWIFT_FILE = ROOT / "TripKorean/Models/Hangul.swift"
OUT_DIR = ROOT / "TripKorean/Resources/HangulAudio"
VOICE = "ko-KR-SunHiNeural"

# 拼读表：14 辅音 × 10 元音（与 HangulData.chartInitials/chartMedials 一致）
CHART_INITIALS = [0, 2, 3, 5, 6, 7, 9, 11, 12, 14, 15, 16, 17, 18]
CHART_MEDIALS = [0, 2, 4, 6, 8, 12, 13, 17, 18, 20]


def collect_texts():
    src = SWIFT_FILE.read_text()
    sounds = set(re.findall(r'soundText:\s*"([^"]+)"', src))
    words = set(re.findall(r'exampleWord:\s*"([^"]+)"', src))
    chart = {chr(0xAC00 + (i * 21 + m) * 28) for i in CHART_INITIALS for m in CHART_MEDIALS}
    extra = {"한"}  # 首页音节结构卡片
    return sounds | chart | extra, words


def filename(text: str) -> str:
    return "-".join(f"{ord(c):X}" for c in text) + ".mp3"


async def gen(text: str, rate: str, sem: asyncio.Semaphore):
    out = OUT_DIR / filename(text)
    if out.exists() and out.stat().st_size > 1000:
        return
    async with sem:
        for attempt in range(3):
            try:
                await edge_tts.Communicate(text, VOICE, rate=rate).save(str(out))
                if out.stat().st_size > 1000:
                    return
            except Exception as e:
                if attempt == 2:
                    print(f"FAILED {text}: {e}")
                await asyncio.sleep(1.5 * (attempt + 1))


async def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    syllables, words = collect_texts()
    print(f"syllables: {len(syllables)}, words: {len(words)}")
    sem = asyncio.Semaphore(4)
    tasks = [gen(t, "-15%", sem) for t in sorted(syllables)]  # 单音节放慢更清晰
    tasks += [gen(t, "-5%", sem) for t in sorted(words)]
    await asyncio.gather(*tasks)
    files = list(OUT_DIR.glob("*.mp3"))
    total = sum(f.stat().st_size for f in files)
    print(f"generated {len(files)} files, {total / 1024 / 1024:.2f} MB")


if __name__ == "__main__":
    asyncio.run(main())
