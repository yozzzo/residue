#!/usr/bin/env python3
"""
GCP Imagen 3 コスト追跡ツール

使い方:
  # 画像生成（自動トラッキング付き）
  python3 cost_tracker.py generate "prompt here" --output out.png

  # レポート表示
  python3 cost_tracker.py report

  # 月次リセット（手動）
  python3 cost_tracker.py reset
"""

import json
import os
import sys
import time
from datetime import datetime, timezone, timedelta
from pathlib import Path

JST = timezone(timedelta(hours=9))
TRACKER_FILE = Path(__file__).parent / "data" / "imagen_usage.json"
# Imagen 3 pricing (per image, standard quality)
# imagen-3.0-generate-002: ~$0.04/image (1024x1024)
# 高解像度はもっと高い可能性あり
COST_PER_IMAGE = 0.04

# 上限設定
DAILY_LIMIT_USD = 5.00
MONTHLY_LIMIT_USD = 50.00

CREDENTIALS_PATH = Path(__file__).parent / "credentials" / "service-account.json"


def load_tracker():
    if TRACKER_FILE.exists():
        with open(TRACKER_FILE) as f:
            return json.load(f)
    return {"entries": [], "total_images": 0, "total_cost_usd": 0.0}


def save_tracker(data):
    TRACKER_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(TRACKER_FILE, "w") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)


def record_usage(prompt, num_images=1, aspect_ratio="1:1", cost_override=None):
    data = load_tracker()
    now = datetime.now(JST)
    cost = cost_override if cost_override else COST_PER_IMAGE * num_images

    entry = {
        "timestamp": now.isoformat(),
        "date": now.strftime("%Y-%m-%d"),
        "prompt": prompt[:100],  # truncate
        "num_images": num_images,
        "aspect_ratio": aspect_ratio,
        "cost_usd": cost,
    }
    data["entries"].append(entry)
    data["total_images"] += num_images
    data["total_cost_usd"] = round(data["total_cost_usd"] + cost, 4)
    save_tracker(data)
    return check_limits(data)


def check_limits(data=None):
    if data is None:
        data = load_tracker()

    now = datetime.now(JST)
    today = now.strftime("%Y-%m-%d")
    this_month = now.strftime("%Y-%m")

    daily_cost = sum(
        e["cost_usd"] for e in data["entries"] if e["date"] == today
    )
    monthly_cost = sum(
        e["cost_usd"] for e in data["entries"] if e["date"].startswith(this_month)
    )
    daily_count = sum(
        e["num_images"] for e in data["entries"] if e["date"] == today
    )
    monthly_count = sum(
        e["num_images"] for e in data["entries"] if e["date"].startswith(this_month)
    )

    alerts = []
    if daily_cost >= DAILY_LIMIT_USD:
        alerts.append(f"⚠️ 日次上限到達！ ${daily_cost:.2f} / ${DAILY_LIMIT_USD:.2f}")
    elif daily_cost >= DAILY_LIMIT_USD * 0.8:
        alerts.append(f"⚡ 日次上限80%超え: ${daily_cost:.2f} / ${DAILY_LIMIT_USD:.2f}")

    if monthly_cost >= MONTHLY_LIMIT_USD:
        alerts.append(f"🚨 月次上限到達！ ${monthly_cost:.2f} / ${MONTHLY_LIMIT_USD:.2f}")
    elif monthly_cost >= MONTHLY_LIMIT_USD * 0.8:
        alerts.append(f"⚡ 月次上限80%超え: ${monthly_cost:.2f} / ${MONTHLY_LIMIT_USD:.2f}")

    return {
        "daily_cost": round(daily_cost, 4),
        "daily_count": daily_count,
        "monthly_cost": round(monthly_cost, 4),
        "monthly_count": monthly_count,
        "daily_limit": DAILY_LIMIT_USD,
        "monthly_limit": MONTHLY_LIMIT_USD,
        "alerts": alerts,
        "blocked": daily_cost >= DAILY_LIMIT_USD or monthly_cost >= MONTHLY_LIMIT_USD,
    }


def report():
    data = load_tracker()
    status = check_limits(data)
    print("=" * 40)
    print("📊 Imagen 3 コストレポート")
    print("=" * 40)
    print(f"今日:   {status['daily_count']}枚  ${status['daily_cost']:.2f} / ${status['daily_limit']:.2f}")
    print(f"今月:   {status['monthly_count']}枚  ${status['monthly_cost']:.2f} / ${status['monthly_limit']:.2f}")
    print(f"累計:   {data['total_images']}枚  ${data['total_cost_usd']:.2f}")
    print("-" * 40)
    if status["alerts"]:
        for a in status["alerts"]:
            print(a)
    else:
        print("✅ 上限内")

    # 直近5件
    if data["entries"]:
        print("\n📝 直近の生成:")
        for e in data["entries"][-5:]:
            print(f"  {e['timestamp'][:16]} | {e['num_images']}枚 ${e['cost_usd']:.2f} | {e['prompt'][:40]}")


def generate_image(prompt, output_path="output.png", num_images=1, aspect_ratio="16:9"):
    """コスト追跡付きで画像生成"""
    status = check_limits()
    if status["blocked"]:
        print("🚫 コスト上限に達してるため生成をブロック！")
        for a in status["alerts"]:
            print(a)
        print("上限を変更するには cost_tracker.py の DAILY_LIMIT_USD / MONTHLY_LIMIT_USD を編集")
        return None

    from google.oauth2 import service_account
    from google.cloud import aiplatform
    from vertexai.preview.vision_models import ImageGenerationModel

    creds = service_account.Credentials.from_service_account_file(
        str(CREDENTIALS_PATH),
        scopes=["https://www.googleapis.com/auth/cloud-platform"],
    )
    aiplatform.init(project="residue-487623", location="us-central1", credentials=creds)

    model = ImageGenerationModel.from_pretrained("imagen-3.0-generate-002")
    response = model.generate_images(
        prompt=prompt,
        number_of_images=num_images,
        aspect_ratio=aspect_ratio,
    )

    for i, img in enumerate(response.images):
        if num_images == 1:
            path = output_path
        else:
            base, ext = os.path.splitext(output_path)
            path = f"{base}_{i}{ext}"
        img.save(path)
        print(f"✅ 保存: {path}")

    result = record_usage(prompt, num_images, aspect_ratio)
    print(f"💰 今日: ${result['daily_cost']:.2f} / 今月: ${result['monthly_cost']:.2f}")
    if result["alerts"]:
        for a in result["alerts"]:
            print(a)

    return response


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 cost_tracker.py [generate|report|reset|status]")
        sys.exit(1)

    cmd = sys.argv[1]

    if cmd == "report" or cmd == "status":
        report()
    elif cmd == "reset":
        save_tracker({"entries": [], "total_images": 0, "total_cost_usd": 0.0})
        print("✅ リセット完了")
    elif cmd == "generate":
        if len(sys.argv) < 3:
            print("Usage: python3 cost_tracker.py generate 'prompt' [--output file.png] [--aspect 16:9] [--count 1]")
            sys.exit(1)
        prompt = sys.argv[2]
        output = "output.png"
        aspect = "16:9"
        count = 1
        i = 3
        while i < len(sys.argv):
            if sys.argv[i] == "--output" and i + 1 < len(sys.argv):
                output = sys.argv[i + 1]; i += 2
            elif sys.argv[i] == "--aspect" and i + 1 < len(sys.argv):
                aspect = sys.argv[i + 1]; i += 2
            elif sys.argv[i] == "--count" and i + 1 < len(sys.argv):
                count = int(sys.argv[i + 1]); i += 2
            else:
                i += 1
        generate_image(prompt, output, count, aspect)
    else:
        print(f"Unknown command: {cmd}")
