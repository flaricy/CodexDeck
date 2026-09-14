#!/usr/bin/env python3
"""Build the local menu-bar companion; Python is resolved at build and launch time."""
import pathlib,plistlib,shutil,subprocess,sys,struct
root=pathlib.Path(__file__).resolve().parents[1]
app=root/'Codex Deck Mac.app'
contents=app/'Contents';(contents/'MacOS').mkdir(parents=True,exist_ok=True);(contents/'Resources').mkdir(exist_ok=True)
info={'CFBundleIdentifier':'dev.codexdeck.mac','CFBundleName':'Codex Deck Mac','CFBundleDisplayName':'Codex Deck','CFBundleExecutable':'CodexDeckMac','CFBundlePackageType':'APPL','CFBundleShortVersionString':'1.0.1','CFBundleVersion':'11','LSUIElement':True,'LSMinimumSystemVersion':'14.0','CFBundleIconFile':'Deck.icns'}
(contents/'Info.plist').write_bytes(plistlib.dumps(info))
png=(root/'Artwork/Assets.xcassets/AppIcon.appiconset/AppIcon.png').read_bytes()
(contents/'Resources/Deck.icns').write_bytes(b'icns'+struct.pack('>I',16+len(png))+b'ic10'+struct.pack('>I',8+len(png))+png)
shutil.copy2(root/'Bridge/bridge.py',contents/'Resources/bridge.py')
subprocess.run(['xcrun','swiftc','-parse-as-library','-O','-target','arm64-apple-macosx14.0',str(root/'macOS/Companion.swift'),'-o',str(contents/'MacOS/CodexDeckMac')],check=True)
subprocess.run(['/usr/bin/codesign','--force','--sign','-',str(app)],check=True)
print(app)
