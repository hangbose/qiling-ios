import argparse
import re
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--bundle-id', required=True)
parser.add_argument('--team-id', required=True)
parser.add_argument('--build-number', required=True, type=int)
args = parser.parse_args()
if not re.fullmatch(r'[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+', args.bundle_id) or args.bundle_id.startswith('com.example.'):
    parser.error('Use a registered production Bundle ID, not com.example.')
if not re.fullmatch(r'[A-Z0-9]{10}', args.team_id):
    parser.error('APPLE_TEAM_ID must be the 10-character Apple Developer Team ID.')
if args.build_number < 1:
    parser.error('Build number must be positive.')
spec = Path('project.yml')
text = spec.read_text(encoding='utf-8')
if 'com.example.Qiling' not in text:
    raise SystemExit('Expected unconfigured source project. Start from a fresh checkout.')
text = text.replace('com.example.Qiling', args.bundle_id)
text = text.replace('CODE_SIGN_STYLE: Automatic', f'CODE_SIGN_STYLE: Automatic\n        DEVELOPMENT_TEAM: "{args.team_id}"')
text, count = re.subn(r'CURRENT_PROJECT_VERSION: "1"', f'CURRENT_PROJECT_VERSION: "{args.build_number}"', text)
if count != 1:
    raise SystemExit('Unexpected build version configuration.')
spec.write_text(text, encoding='utf-8')
print('Release identity and build number configured. Signing secrets remain in Codemagic.')
