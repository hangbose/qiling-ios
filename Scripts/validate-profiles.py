"""Exclude incompatible Qiling profiles from the temporary macOS build machine."""
import os
import plistlib
import subprocess
from pathlib import Path

bundle = os.environ['BUNDLE_ID']
container = 'iCloud.' + bundle
folder = Path.home() / 'Library/MobileDevice/Provisioning Profiles'
valid = []
for path in folder.glob('*.mobileprovision'):
    result = subprocess.run(['security', 'cms', '-D', '-i', str(path)], capture_output=True)
    if result.returncode:
        raise SystemExit('Cannot decode installed profile: ' + path.name)
    profile = plistlib.loads(result.stdout)
    ent = profile.get('Entitlements', {})
    app_id = ent.get('application-identifier', '')
    if not app_id.endswith('.' + bundle):
        continue
    containers = ent.get('com.apple.developer.icloud-container-identifiers', [])
    print('Profile:', profile.get('Name'), 'UUID:', profile.get('UUID'), 'iCloud containers:', containers)
    problems = []
    if container not in containers:
        problems.append('missing ' + container)
    if 'CloudKit' not in ent.get('com.apple.developer.icloud-services', []):
        problems.append('missing CloudKit')
    if not ent.get('com.apple.developer.healthkit'):
        problems.append('missing HealthKit')
    if not ent.get('com.apple.developer.healthkit.background-delivery'):
        problems.append('missing HealthKit background delivery')
    if ent.get('get-task-allow') or profile.get('ProvisionedDevices') or profile.get('ProvisionsAllDevices'):
        problems.append('not App Store distribution')
    if problems:
        print('Exclude from this temporary build:', '; '.join(problems))
        path.unlink()
    else:
        valid.append(path)
if not valid:
    raise SystemExit('No compatible App Store profile installed. Regenerate the Apple profile AFTER assigning '
                     + container + ', then import the updated .mobileprovision into Codemagic.')
print('Compatible Qiling App Store profiles:', len(valid))
