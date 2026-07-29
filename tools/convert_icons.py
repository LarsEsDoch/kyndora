import os
from PIL import Image

SOURCE_DIR = "firmware/data/icons"
OUTPUT_FILE = "firmware/include/icons.h"

ICONS = [
    "weather/air",
    "weather/clear_day",
    "weather/cloud",
    "weather/mist",
    "weather/moon_stars",
    "weather/partly_cloudy_day",
    "weather/partly_cloudy_night",
    "weather/rainy",
    "weather/thunderstorm",
    "weather/weather_snowy",
    "wifi/wifi_alert",
    "wifi/wifi_not_connected",
    "wifi/wifi_not_set_up",
    "wifi/wifi_strength_1",
    "wifi/wifi_strength_2",
    "wifi/wifi_strength_3",
    "wifi/wifi_strength_4"
]

ICON_SIZE = 24


def convert_icon(path):
    img = Image.open(path).convert("RGBA")
    img = img.resize((ICON_SIZE, ICON_SIZE))
    pixels = img.load()

    row_bytes = (ICON_SIZE + 7) // 8
    data = bytearray(row_bytes * ICON_SIZE)

    for y in range(ICON_SIZE):
        for x in range(ICON_SIZE):
            r, g, b, a = pixels[x, y]
            luminance = (r + g + b) / 3
            is_on = a > 128 and luminance < 128
            if is_on:
                byte_index = y * row_bytes + (x // 8)
                bit_index = 7 - (x % 8)
                data[byte_index] |= (1 << bit_index)

    return data


def to_c_array(name, data):
    lines = [f"const uint8_t ICON_{name.upper()}[] PROGMEM = {{"]
    row_bytes = (ICON_SIZE + 7) // 8
    for i in range(0, len(data), row_bytes):
        row = data[i:i + row_bytes]
        hex_values = ", ".join(f"0x{b:02X}" for b in row)
        lines.append(f"    {hex_values},")
    lines.append("};")
    return "\n".join(lines)


def main():
    header_lines = [
        "#pragma once",
        "#include <Arduino.h>",
        "",
        f"#define WEATHER_ICON_SIZE {ICON_SIZE}",
        ""
    ]

    for icon_name in ICONS:
        icon_path = os.path.join(SOURCE_DIR, f"{icon_name}.png")
        if not os.path.exists(icon_path):
            print(f"Warning: {icon_path} not found, skipping.")
            continue
        data = convert_icon(icon_path)
        header_lines.append(to_c_array(icon_name, data))
        header_lines.append("")

    os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)
    with open(OUTPUT_FILE, "w") as f:
        f.write("\n".join(header_lines))

    print(f"Generated {OUTPUT_FILE}")


if __name__ == "__main__":
    main()