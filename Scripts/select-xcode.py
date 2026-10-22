import glob
import re

candidates = []
for path in glob.glob('/Applications/Xcode_*.app'):
    match = re.search(r'/Xcode_(\d+(?:\.\d+)*)\.app$', path)
    if match:
        candidates.append((tuple(map(int, match.group(1).split('.'))), path))
if not candidates:
    raise SystemExit('No stable Xcode installation found')
print(max(candidates)[1])
