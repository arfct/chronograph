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
wrangler pages deploy site --project-name=chronograph-page
```
