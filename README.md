# Computer Remote

Open apps and games on your PC from your Android phone, with one tap. There's also a **Start my setup** button that opens Discord, both Opera GX, Medal and Claude at once.

- **Phone page:** https://drift-club-qvkk.onrender.com/remote (add it to your home screen)
- **PC helper:** `ComputerRemote.ps1`, which runs hidden when you log in

## Install (no admin needed)
1. Download this repo (green **Code** button → **Download ZIP**) and unzip it.
2. Double-click **Install.cmd**. It:
   - copies the helper to `%LOCALAPPDATA%\ComputerRemote`
   - adds it to *your* Startup folder only
   - starts it
   - lists the apps and games it found
   - opens a QR code
3. Scan the QR code with your phone camera, tap the link, then **⋮ → Add to Home screen**.

To pair another phone later, run **Pair phone.cmd**. To remove it, run **Uninstall.cmd**.

## How it works
```
phone ──tap──▶ relay server (Render) ◀──asks "anything for me?"── PC helper ──▶ opens the app
```
- The PC only makes **outgoing** web requests. There are no open ports, no firewall rule and no admin rights.
- Every request carries a long random **pairing key**, kept in `key.txt` on the PC. The server only stores a hash of it. Delete `key.txt` to make a new key; you'll need to pair again.
- The PC only runs things from **its own list**: the apps it finds in the Start menu and desktop, your Steam and Epic games, extra apps from `config.json`, and **Lock PC**. The phone can't make it run anything else.

## Add your own apps
Edit `%LOCALAPPDATA%\ComputerRemote\config.json`:
```json
{
  "setup": ["Discord", "Opera GX", "Medal", "Claude"],
  "apps": [
    { "name": "Lunar Client", "path": "%LOCALAPPDATA%\\Programs\\lunarclient\\Lunar Client.exe", "args": "" }
  ]
}
```
`setup` decides which apps **Start my setup** opens. Restart the helper to apply changes: log out and back in, or run Install.cmd again.

## Troubleshooting
- **PC offline on the phone:** check `log.txt` in `%LOCALAPPDATA%\ComputerRemote`. The relay server may be waking up, so wait about 30 s.
- **Antivirus warning:** Avast can flag hidden PowerShell scripts. The whole script is readable in `ComputerRemote.ps1`. Only allow it if you're happy with what it does.
