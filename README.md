<h1 align="center">Steven Naliwajka</h1>

<p align="center"><em>I build <a href="https://www.printect.net">Printect</a> — an on-demand 3D-printing shop that runs entirely on hardware I own.</em></p>

<p align="center">
  <a href="https://www.naliwajka.com/status"><img alt="system status" src="https://www.naliwajka.com/status/badge/status.svg"></a>
  <a href="https://www.naliwajka.com/status"><img alt="first-party lines of code" src="https://www.naliwajka.com/status/badge/loc.svg"></a>
  <a href="https://www.printect.net"><img alt="printect.net" src="https://www.naliwajka.com/status/badge/site.svg"></a>
</p>

---

## 🖨️ Printect

**[printect.net](https://www.printect.net)** is a print-on-demand 3D-printing storefront — upload a model, get an instant quote, and I print and ship it. Every layer runs on a Proxmox cluster in my home lab: no SaaS, no third-party backend. The storefront, print engine, slicer, quoting model, build-plate packer, address autocomplete, and sign-in are all services I wrote and operate.

### Live system status

Real health and codebase size, served straight from my self-hosted status service at [`www.naliwajka.com/status`](https://www.naliwajka.com/status) — these badges are live:

| Service | What it does | Status |
| :--- | :--- | :--- |
| **Storefront** | Public shop at printect.net | [![site](https://www.naliwajka.com/status/badge/site.svg)](https://www.printect.net) |
| **Store** | Catalog · cart · checkout | ![store](https://www.naliwajka.com/status/badge/store.svg) |
| **PrintQue** | Print queue + routing engine | ![printque](https://www.naliwajka.com/status/badge/printque.svg) |
| **Slicer** | Model → G-code | ![slicer](https://www.naliwajka.com/status/badge/slicer.svg) |
| **Quoting** | Instant cost / BOM model | ![quoting](https://www.naliwajka.com/status/badge/quoting.svg) |
| **Packer** | Auto build-plate packing | ![packer](https://www.naliwajka.com/status/badge/packer.svg) |
| **Geolookup** | Self-hosted address autocomplete | ![geolookup](https://www.naliwajka.com/status/badge/geolookup.svg) |
| **Accounts** | Google sign-in / identity | ![accounts](https://www.naliwajka.com/status/badge/accounts.svg) |

> 📊 **[See the full live dashboard →](https://www.naliwajka.com/status)** — up/down, rolling uptime, and lines of code across the whole stack, updated in real time from the home lab.

### Under the hood

- **Languages** — Go · Python · JavaScript, every line first-party (the ![loc](https://www.naliwajka.com/status/badge/loc.svg) above is the real, live total).
- **Infra** — Proxmox LXC · nginx reverse proxy · Cloudflare · WireGuard · self-hosted GitLab, all administered by a management plane I built.
- **Self-hosted end to end** — even this status service and these badges run on my own metal.

---

<p align="center">
  <a href="https://www.printect.net">🛒&nbsp;printect.net</a> &nbsp;·&nbsp;
  <a href="https://www.naliwajka.com/status">📊&nbsp;live&nbsp;status</a> &nbsp;·&nbsp;
  <a href="https://www.linkedin.com/in/steven-naliwajka-69564929a/">💼&nbsp;LinkedIn</a>
</p>
