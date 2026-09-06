from pathlib import Path
from PIL import Image

root = Path('/home/ubuntu/3105_redesign')
source = Path('/home/ubuntu/final-action-simulation-fixed/repo/ThreeOneOSFive/Assets.xcassets/CHZPrivLogo.imageset/chz_priv_logo_rounded.png')
target_dir = root / 'ThreeOneOSFive/Assets.xcassets/CHZPrivLogo.imageset'
target_dir.mkdir(parents=True, exist_ok=True)
target = target_dir / 'chz_priv_logo_rounded.png'

with Image.open(source) as image:
    image = image.convert('RGBA')
    if image.width > 512 or image.height > 512:
        image.thumbnail((512, 512), Image.Resampling.LANCZOS)
    image.save(target, format='PNG', optimize=True)

(target_dir / 'Contents.json').write_text('''{
  "images" : [
    {
      "filename" : "chz_priv_logo_rounded.png",
      "idiom" : "universal",
      "scale" : "1x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
''', encoding='utf-8')
print(f'restored {target} at {Image.open(target).size}')
