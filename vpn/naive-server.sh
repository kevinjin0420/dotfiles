#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "error: run as root on the target VPS" >&2
  exit 1
fi

read -rp "Proxy domain (A record must already point here): " proxy_domain
read -rp "Email for Let's Encrypt: " acme_email

if [[ -z "$proxy_domain" || -z "$acme_email" ]]; then
  echo "error: domain and email are required" >&2
  exit 1
fi

resolved_ip="$(getent ahostsv4 "$proxy_domain" | awk 'NR==1 {print $1}')"
public_ip="$(curl -fsS https://api.ipify.org)"
if [[ "$resolved_ip" != "$public_ip" ]]; then
  echo "error: $proxy_domain resolves to ${resolved_ip:-nothing}, but this host is $public_ip" >&2
  exit 1
fi

proxy_user="$(openssl rand -hex 4)"
proxy_pass="$(openssl rand -hex 16)"

caddy_url="$(curl -fsS https://api.github.com/repos/klzgrad/forwardproxy/releases/latest \
  | grep -o 'https://[^"]*caddy-forwardproxy-naive.tar.xz')"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

curl -fsSL -o "$workdir/caddy.tar.xz" "$caddy_url"
tar -xf "$workdir/caddy.tar.xz" -C "$workdir"
install -m 755 "$workdir/caddy-forwardproxy-naive/caddy" /usr/local/bin/caddy
setcap cap_net_bind_service=+ep /usr/local/bin/caddy

id -u caddy &>/dev/null || useradd --system --home /var/lib/caddy --create-home --shell /usr/sbin/nologin caddy
mkdir -p /etc/caddy /var/www/html

cat >/etc/caddy/Caddyfile <<EOF
{
  order forward_proxy before file_server
  log {
    exclude http.log.error
  }
}
:443, ${proxy_domain} {
  tls ${acme_email}
  encode
  forward_proxy {
    basic_auth ${proxy_user} ${proxy_pass}
    hide_ip
    hide_via
    probe_resistance
  }
  file_server {
    root /var/www/html
  }
}
EOF

cat >/var/www/html/index.html <<EOF
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${proxy_domain}</title>
</head>
<body>
  <h1>${proxy_domain}</h1>
  <p>Personal site. Nothing here yet.</p>
</body>
</html>
EOF

cat >/etc/systemd/system/caddy.service <<'EOF'
[Unit]
Description=Caddy (naiveproxy forward proxy)
After=network.target network-online.target
Requires=network-online.target

[Service]
Type=notify
User=caddy
Group=caddy
ExecStart=/usr/local/bin/caddy run --environ --config /etc/caddy/Caddyfile
ExecReload=/usr/local/bin/caddy reload --config /etc/caddy/Caddyfile --force
TimeoutStopSec=5s
LimitNOFILE=1048576
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_BIND_SERVICE
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

chown -R caddy:caddy /etc/caddy /var/www/html
/usr/local/bin/caddy validate --config /etc/caddy/Caddyfile

systemctl daemon-reload
systemctl enable --now caddy

for _ in {1..30}; do
  if curl -fsS -o /dev/null "https://${proxy_domain}/"; then
    break
  fi
  sleep 2
done

if ! curl -fsS -o /dev/null "https://${proxy_domain}/"; then
  echo "error: certificate did not come up; check 'journalctl -u caddy'" >&2
  exit 1
fi

echo
echo "server ready"
echo "  proxy:    https://${proxy_user}:${proxy_pass}@${proxy_domain}"
echo "  user:     ${proxy_user}"
echo "  password: ${proxy_pass}"
echo
echo "add another device with an extra 'basic_auth <user> <pass>' line in /etc/caddy/Caddyfile"
