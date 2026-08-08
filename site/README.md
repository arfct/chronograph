# chronograph.fyi

Cloudflare Pages project root for the Chronograph web presence.

Primary domain: **chronograph.fyi** (DNS at Porkbun, served by Cloudflare Pages).
`chronograph.page` remains a separate TestFlight vanity redirect at its own registrar.

| Path | Serves |
|---|---|
| `/` | 302 → iOS TestFlight beta (`_redirects`) |
| `/privacy` | Privacy policy — the URL given to Google Play and the App Store |

`privacy.html` is a copy of `docs/privacy-chronograph.html`; keep them in
sync (`cp docs/privacy-chronograph.html site/privacy.html`).

Deploy:

```bash
wrangler login                       # one-time, opens a browser
wrangler pages deploy site --project-name=chronograph
```

## Pointing a domain at this project

`scripts/attach-domain.sh [domain] [pages-project]` registers the custom domain
on Cloudflare Pages and creates the apex `ALIAS` at Porkbun in one go. It reads
credentials from 1Password at runtime — nothing secret is stored in this repo.

Required 1Password items (`geist@artifact.com`, Employee vault):

| Item | Field | Value |
|---|---|---|
| `Cloudflare API token chronograph` | `credential` | API token, scoped **Account → Cloudflare Pages → Edit** |
| `Porkbun API` | `username` | API key (`pk1_…`) |
| `Porkbun API` | `credential` | Secret API key (`sk1_…`) |

Porkbun gotcha: API access is **off per domain** by default. Enable it on the
domain's own page or every call returns an authentication error even with valid keys.

> 1Password item titles used in `op://` references must not contain parentheses —
> `op read` rejects them as invalid secret references.
