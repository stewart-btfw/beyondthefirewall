# beyondthefirewall

Static site and Cloudflare infrastructure for **Beyond the Firewall**
(`beyondthefirewall.me`, plus `.io`, `.org`, `.app`, `.co.uk`, `.info` and
`.uk`).

Everything is served from a home Raspberry Pi reached only through a
Cloudflare Tunnel — no open ports, no cloud compute. Cloudflare Access gates
the members page and a browser-rendered SSH console.

| Path | What it is |
|---|---|
| `index.html`, `members.html`, `style.css`, `diag.js`, images | The site — no build step, served as-is by nginx on the Pi |
| `infra/warp-pi-access/` | Terraform for tunnel ingress, `.io` DNS, the Access-gated console and SSH rate limiting |
| `.github/workflows/` | Deploy to the Pi on push to `main`, uptime checks, Terraform lint/validate |

See [`infra/README.md`](infra/README.md) for topology, deploy mechanics and
everything that's managed by hand in the Cloudflare dashboard.
