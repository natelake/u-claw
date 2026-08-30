<p align="center">
  <img src="assets/readme/hero-image2.png" alt="U-Claw: a portable AI workspace" width="100%" />
</p>

<h1 align="center">U-Claw</h1>

<p align="center"><strong>Put an AI workspace on a USB stick. Plug it into a Mac, double-click, and your config, memory, and tools come with you.</strong></p>

<p align="center">
  <a href="#quick-start-mac-usb">Mac USB how-to</a> ·
  <a href="#what-you-get">What you get</a> ·
  <a href="https://github.com/dongsheng123132/u-claw">Upstream project</a> ·
  <a href="https://github.com/openclaw/openclaw">OpenClaw</a>
</p>

<p align="center">
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-1f7a8c?style=flat-square" alt="MIT License" /></a>
  <img src="https://img.shields.io/badge/Portable-USB%20first-123343?style=flat-square" alt="USB first" />
  <img src="https://img.shields.io/badge/Runtime-OpenClaw-48d1c1?style=flat-square" alt="OpenClaw runtime" />
</p>

> [!IMPORTANT]
> This is not a USB-image maker. This repo **is** the USB file skeleton. Copy `portable/` onto a stick. On a Mac, double-click `Mac-Start.command`. The first run needs internet to finish setup; later runs work from the stick.

This English Mac USB edition is a fork of **[dongsheng123132/u-claw](https://github.com/dongsheng123132/u-claw)** (U-Claw / Xia Pan). Runtime credit: **[OpenClaw](https://github.com/openclaw/openclaw)**. Product name stays **U-Claw**. License is MIT.

## Quick start (Mac USB)

1. **Copy the portable folder onto a USB drive**

   After you clone this repo (or download a release), copy everything inside `portable/` to the stick, for example:

   ```bash
   git clone https://github.com/natelake/u-claw.git
   cd u-claw/portable && bash setup.sh
   cp -R . /Volumes/YOUR_USB/U-Claw/
   ```

   On macOS you can also drag the `portable/` folder onto the drive in Finder.

2. **On a Mac, double-click `Mac-Start.command`**

   If macOS says the developer cannot be verified: right-click the file -> **Open**.

3. **First run needs internet**

   The first start downloads Node.js and OpenClaw onto the stick (about 1-2 minutes). After that, later runs work from the stick. Your model API Key is stored only in `data/.openclaw/openclaw.json` on the USB.

4. **Pick a model and start chatting**

   First launch opens Config Center (`http://127.0.0.1:18788/`) if no model is set. Enter an API Key (OpenAI, Anthropic, DeepSeek, Groq, a local Ollama model, or any OpenAI-compatible endpoint). Then open the Dashboard at `http://127.0.0.1:18789/#token=uclaw`.

> Only one U-Claw instance runs per USB drive. A second double-click reopens the existing Dashboard instead of starting another gateway. To restart, quit the original launcher window first.

## What you get

| You get | Why it matters |
| --- | --- |
| A portable AI workspace | Config, memory, sessions, and device pairing travel with the stick. Rebuildable browser cache stays on the host Mac. |
| Local-first | Not bound to one computer. Config is not uploaded. |
| Double-click start | `Mac-Start.command` on macOS; `Windows-Start.bat` on Windows. |

### USB files

| Action | Mac | Windows |
| --- | --- | --- |
| **Run (no install)** | `Mac-Start.command` | `Windows-Start.bat` |
| **Menu** | `Mac-Menu.command` | `Windows-Menu.bat` |
| **Install to this computer** | `Mac-Install.command` | `Windows-Install.bat` |
| **First-time config** | `Config.html` / Config Center | same |
| **Diagnose** | `Mac-Diagnose.command` | `Windows-Diagnose.bat` |

```
U-Claw/                          <- copy this whole folder to the USB
|-- Mac-Start.command             Mac launcher (double-click)
|-- Mac-Menu.command              Mac menu
|-- Mac-Install.command           Install to this Mac (~/.uclaw)
|-- Windows-Start.bat             Windows launcher
|-- Config.html                   First-time config page
|-- setup.sh                      Download Node.js + OpenClaw
|-- app/                          <- large deps (not in git)
|   |-- core/                        OpenClaw
|   `-- runtime/                     Node.js for Mac and Windows
`-- data/                         <- your data (not in git)
    |-- .openclaw/                   config, extensions, instance lock
    |-- memory/                      AI memory
    `-- backups/                     backups
```

### USB format

Prefer APFS or HFS+ for a Mac-only stick, or exFAT if you also use Windows. Node.js on FAT32 is slow and cannot create symlinks. Config, sessions, and pairing stay on the USB under data/.openclaw.

## Models and chat apps

U-Claw does not lock you to one vendor. First launch: pick a provider, paste your own API Key.

- Official keys: OpenAI, Anthropic, Groq, DeepSeek, or any OpenAI-compatible URL.\n- Local: Ollama or LM Studio (no Key).\n- Optional chat apps: Telegram, Discord, Feishu/Lark, plus community plugins if you want them.\n\nConfig lives only on the stick: data/.openclaw/openclaw.json.\n\n## Downloads (US defaults)

This fork uses public package downloads in the US.
A regional mirror is kept only as a commented fallback in the scripts.
First run needs internet. Later runs use the files already on the stick.

## From source (developers)

Clone this repo, then run bash setup.sh inside portable/.
Use setup.sh --all-platforms to also fetch the Windows Node runtime.
Optional no-USB install: bash install/install.sh (see install/README.md).

## FAQ

**Does the first run need internet?** Yes. Later runs work from the stick.

**How big should the USB be?** 4 GB or more (full install is about 2.3 GB).

**Can I redistribute?** MIT license -- yes. Keep the copyright notice and credit upstream.

**Mac says unverified developer?** Right-click Mac-Start.command, then Open.

**setup.sh fails with module not found?** A network drop can leave node_modules incomplete. Delete portable/app/core/node_modules and re-run setup.sh.

**Already have Node v24 and install fails?** Use v20 or v22 LTS. Delete portable/app/runtime/node-mac-arm64 and run setup.sh again.

**How do I use several models?** Open Config Center, add each provider API Key, then switch models from the chat dropdown. Config stays on the USB.

**Write errors on the USB?** Check for a physical write-protect switch, or reformat (APFS/HFS+ for Mac-only, exFAT for Mac+Windows).

## Credits and license

- This fork: natelake/u-claw -- English Mac USB edition
- Upstream U-Claw: dongsheng123132/u-claw by He Qubing
- Runtime: OpenClaw (openclaw/openclaw)
- License: MIT (see LICENSE)

Upstream site: u-claw.org

Made with lobster emoji. English Mac USB fork by Nate Lake, based on U-Claw + OpenClaw.
