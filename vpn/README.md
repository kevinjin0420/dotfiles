# Personal proxy setup

Two VPS boxes running different protocols over different transports, so they fail
independently. Credentials are in the password manager, never here (this repo is public).

## Layout

| Role | Protocol | Transport | Notes |
| --- | --- | --- | --- |
| Primary | Hysteria2 | UDP/443 | Fast. Handles 4K. |
| Fallback | naive | TCP/443 | Slow but reliable. Fine for git, docs, APIs. |

Both boxes run Caddy on TCP/443 serving a plain decoy site with a real Let's Encrypt
certificate. `probe_resistance` means an unauthenticated visitor sees only the decoy.

## Rebuilding

1. Point an A record at the new box and wait for it to resolve.
2. `naive-server.sh` — installs Caddy + forwardproxy, issues the cert, prints credentials.
3. `hysteria-server.sh` — optional, adds Hysteria2 on UDP/443 reusing the same cert.

Both prompt for the domain and generate their own credentials. Run them as root on the
target box. `naive-server.sh` refuses to run if DNS does not already point at the host.

## Client settings that are easy to get wrong

- **Hysteria2: leave the up/down bandwidth fields BLANK.** Blank selects BBR, which
  measured ~53 Mbps single-stream. Filling them in selects Brutal, which transmits at a
  fixed rate and ignores congestion; the best hand-tuned Brutal value reached ~57 Mbps
  while discarding ~29% of what it sent. BBR is both faster and cleaner here.
- **naive: mux off.** It multiplexes everything onto one HTTP/2 connection regardless, and
  a single TCP stream at 150 ms RTT saturates near 1 Mbps no matter the available capacity.
  This is why naive was unusable on the long-haul link and why YouTube dropped to 360p.
- **allowInsecure stays off** on both. The certificates are genuine.
- naive carries **no UDP**. Hysteria2 does.

## Server notes

- Enable BBR on any new box: `net.core.default_qdisc=fq`, `net.ipv4.tcp_congestion_control=bbr`.
  Ubuntu images ship `cubic` with the module unloaded.
- Caddy's HTTP/3 must be disabled (`protocols h1 h2`) or it holds UDP/443 and Hysteria2
  cannot bind. `hysteria-server.sh` handles this.
- Hysteria2 runs as its own user and cannot read Caddy's certificate directory, so a daily
  timer copies the cert into `/etc/hysteria`. Without it, renewal silently breaks Hysteria2
  roughly every 60 days.
- Some providers ship `PubkeyAuthentication no` in `sshd_config`. Fix that before assuming
  a key install failed.

## Recovering credentials

They live on the boxes, so the password manager is a convenience rather than the only copy.
SSH in as root:

```sh
grep basic_auth /etc/caddy/Caddyfile      # naive: username and password
grep password: /etc/hysteria/config.yaml  # hysteria2: password
```

The local v2rayN config holds them too, in
`~/.local/share/v2rayN/guiConfigs/guiNConfig.json`.

To rotate, edit the value in place and reload:

```sh
systemctl reload caddy               # after changing basic_auth
systemctl restart hysteria-server    # after changing the hysteria password
```

Add a device by appending another `basic_auth <user> <pass>` line inside the
`forward_proxy` block, so devices can be revoked independently.

## Choosing a host

Route matters more than location. On China Unicom the premium path is **AS9929**; CN2 GIA
is China Telecom's equivalent and works but crosses carriers. Verify what you actually got
by tracing from the server back to your own IP and checking the ASNs, rather than trusting
the plan name.

Latency is secondary to loss. A 150 ms path with a protocol that handles loss beat a 57 ms
path with one that does not, by a factor of 20.
