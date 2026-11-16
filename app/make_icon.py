"""画 My Keys 的图标：圆角方块渐变底 + 白色钥匙。输出 AppIcon.icns。"""
import os
import shutil
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFilter

S = 1024
out_dir = sys.argv[1] if len(sys.argv) > 1 else "."


def rounded_mask(size, radius):
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    return m


# macOS 图标规格：824 的圆角方块居中放在 1024 画布里
inner, pad = 824, 100
grad = Image.new("RGB", (inner, inner))
top, bottom = (58, 76, 202), (22, 160, 170)
for y in range(inner):
    t = y / (inner - 1)
    c = tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(3))
    ImageDraw.Draw(grad).line([(0, y), (inner, y)], fill=c)

canvas = Image.new("RGBA", (S, S), (0, 0, 0, 0))
shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(shadow).rounded_rectangle([pad, pad + 12, pad + inner, pad + inner + 12], radius=185, fill=(0, 0, 0, 90))
canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(18)))
canvas.paste(grad, (pad, pad), rounded_mask(inner, 185))

# 钥匙：斜放，左上是圆环，右下是齿
key = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(key)
white = (255, 255, 255, 255)
cx, cy, r = 400, 470, 150
d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=white)
d.ellipse([cx - 62, cy - 62, cx + 62, cy + 62], fill=(0, 0, 0, 0))
d.rounded_rectangle([cx + r - 30, cy - 38, 820, cy + 38], radius=20, fill=white)
d.rounded_rectangle([700, cy + 20, 752, cy + 140], radius=14, fill=white)
d.rounded_rectangle([600, cy + 20, 646, cy + 110], radius=14, fill=white)
key = key.rotate(-38, center=(S // 2, S // 2), resample=Image.BICUBIC)
glow = key.filter(ImageFilter.GaussianBlur(10))
glow_layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
glow_layer.paste((0, 0, 0, 70), mask=glow.split()[3])
canvas.alpha_composite(glow_layer, (0, 8))
canvas.alpha_composite(key)

iconset = os.path.join(out_dir, "AppIcon.iconset")
shutil.rmtree(iconset, ignore_errors=True)
os.makedirs(iconset)
for size in (16, 32, 128, 256, 512):
    for scale in (1, 2):
        px = size * scale
        name = f"icon_{size}x{size}{'@2x' if scale == 2 else ''}.png"
        canvas.resize((px, px), Image.LANCZOS).save(os.path.join(iconset, name))
canvas.save(os.path.join(out_dir, "icon-1024.png"))
subprocess.run(["iconutil", "-c", "icns", iconset, "-o", os.path.join(out_dir, "AppIcon.icns")], check=True)
shutil.rmtree(iconset)
print("图标已生成")
