#!/usr/bin/env bash
set -euo pipefail

FAKE_HOME="${1:-/tmp/fakehome}"

echo "Creating fake Plasma home at: $FAKE_HOME"

rm -rf "$FAKE_HOME"

mkdir -p "$FAKE_HOME/.config"
mkdir -p "$FAKE_HOME/.local/share/konsole"
mkdir -p "$FAKE_HOME/.local/share/plasma/plasmoids"
mkdir -p "$FAKE_HOME/.local/state"

cat > "$FAKE_HOME/.config/kwinrc" <<'EOF'
[$Version]
update_info=kwin.upd:replace-scalein-with-scale,kwin.upd:animation-speed

[Compositing]
Enabled=true
Backend=OpenGL

[Desktops]
Number=4
Rows=2
EOF

cat > "$FAKE_HOME/.config/kdeglobals" <<'EOF'
[General]
ColorScheme=BreezeDark
Name=Breeze Dark

[Icons]
Theme=breeze-dark

[KDE]
SingleClick=false
EOF

cat > "$FAKE_HOME/.config/plasmarc" <<'EOF'
[Theme]
name=org.kde.breezedark.desktop
EOF

cat > "$FAKE_HOME/.config/plasmashellrc" <<'EOF'
[PlasmaViews][Panel 1]
floating=1
panelLengthMode=1
EOF

cat > "$FAKE_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" <<'EOF'
[Containments][1]
activityId=
formfactor=0
immutability=1
lastScreen=0
location=0
plugin=org.kde.plasma.folder

[Containments][2]
formfactor=2
immutability=1
lastScreen=0
location=4
plugin=org.kde.panel

[Containments][2][Applets][3]
immutability=1
plugin=org.kde.plasma.kickoff

[Containments][2][Applets][4]
immutability=1
plugin=org.kde.plasma.taskmanager

[Containments][2][Applets][5]
immutability=1
plugin=org.kde.plasma.systemtray
EOF

cat > "$FAKE_HOME/.config/kglobalshortcutsrc" <<'EOF'
[kwin]
Window Close=Alt+F4,Alt+F4,Close Window
Overview=Meta+W,Meta+W,Toggle Overview

[plasmashell]
activate task manager entry 1=Meta+1,Meta+1,Activate Task Manager Entry 1
EOF

cat > "$FAKE_HOME/.config/kscreenlockerrc" <<'EOF'
[Daemon]
Autolock=true
Timeout=10
EOF

cat > "$FAKE_HOME/.config/dolphinrc" <<'EOF'
[General]
ShowFullPath=true

[MainWindow]
MenuBar=Disabled
EOF

cat > "$FAKE_HOME/.config/konsolerc" <<'EOF'
[Desktop Entry]
DefaultProfile=Fake.profile
EOF

cat > "$FAKE_HOME/.config/krunnerrc" <<'EOF'
[Plugins]
baloosearchEnabled=true
calculatorEnabled=true
EOF

cat > "$FAKE_HOME/.config/ksmserverrc" <<'EOF'
[General]
loginMode=restorePreviousLogout
EOF

cat > "$FAKE_HOME/.config/kcminputrc" <<'EOF'
[Mouse]
cursorTheme=Breeze_Light
EOF

cat > "$FAKE_HOME/.config/kaccessrc" <<'EOF'
[Keyboard]
SlowKeys=false
StickyKeys=false
EOF

cat > "$FAKE_HOME/.config/breezerc" <<'EOF'
[Windeco]
ButtonSize=ButtonMedium
EOF

cat > "$FAKE_HOME/.config/Trolltech.conf" <<'EOF'
[Qt]
style=Breeze
EOF

cat > "$FAKE_HOME/.local/share/konsole/Fake.profile" <<'EOF'
[Appearance]
ColorScheme=Breeze

[General]
Name=Fake
Parent=FALLBACK/
EOF

cat > "$FAKE_HOME/.local/share/plasma/plasmoids/fake-plasmoid.txt" <<'EOF'
This is fake Plasma local-share content for PlasmaSafe testing.
EOF

echo
echo "Fake home created."
echo
echo "Test with:"
echo "  PLASMASAFE_HOME=$FAKE_HOME cabal run plasmasafe -- save fake-test"
echo "  PLASMASAFE_HOME=$FAKE_HOME cabal run plasmasafe -- list"
echo "  PLASMASAFE_HOME=$FAKE_HOME cabal run plasmasafe -- show fake-test"
echo
