"""Image gate controls: matched scene passes; blank and altered materials fail."""
import json,subprocess,sys,tempfile
from pathlib import Path
from PIL import Image,ImageDraw
verifier=Path(__file__).with_name('verify.py')
with tempfile.TemporaryDirectory() as d:
 p=Path(d);base=Image.new('RGB',(64,64),(255,0,255));ImageDraw.Draw(base).rectangle((2,2,61,61),fill=(100,100,100));base.save(p/'godot-single-24-1-off.png')
 (p/'babylon-24-1-off.json').write_text(json.dumps(dict(engine='babylon',count=24,repeat=1,status='passed')))
 wrong=base.copy();ImageDraw.Draw(wrong).rectangle((2,2,61,61),fill=(200,200,200))
 for label,image,expected in [('matched',base,0),('blank',Image.new('RGB',(64,64),(255,0,255)),1),('wrong-color',wrong,1)]:
  image.save(p/'babylon-24-1-off.png');r=subprocess.run([sys.executable,str(verifier),d],capture_output=True,text=True)
  assert r.returncode==expected,(label,r.stdout,r.stderr)
print('3 image controls passed: matching scene, blank rendering rejection, color mismatch rejection')
