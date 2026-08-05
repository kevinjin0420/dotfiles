#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "error: run as root on the target VPS" >&2
  exit 1
fi

if [[ ! -f /etc/caddy/Caddyfile ]]; then
  echo "error: run naive-server.sh first; this reuses its certificate and decoy site" >&2
  exit 1
fi

read -rp "Proxy domain (same one naive-server.sh used): " proxy_domain

if [[ -z "$proxy_domain" ]]; then
  echo "error: domain is required" >&2
  exit 1
fi

cert_dir="/var/lib/caddy/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory/${proxy_domain}"
if [[ ! -f "$cert_dir/${proxy_domain}.crt" ]]; then
  echo "error: no certificate found at $cert_dir" >&2
  exit 1
fi

if ! grep -q "protocols h1 h2" /etc/caddy/Caddyfile; then
  sed -i "s#^  order forward_proxy before file_server#  order forward_proxy before file_server\n  servers {\n    protocols h1 h2\n  }#" /etc/caddy/Caddyfile
  caddy validate --config /etc/caddy/Caddyfile >/dev/null
  systemctl restart caddy
fi

curl -fsSL https://get.hy2.sh/ -o /tmp/hy2-install.sh
bash /tmp/hy2-install.sh >/dev/null 2>&1
rm -f /tmp/hy2-install.sh

hysteria_password="$(openssl rand -hex 16)"

cat >/usr/local/bin/sync-hysteria-cert.sh <<EOF
#!/usr/bin/env bash
set -euo pipefail
src="$cert_dir"
dst=/etc/hysteria
changed=0
for f in ${proxy_domain}.crt ${proxy_domain}.key; do
  if ! cmp -s "\$src/\$f" "\$dst/\$f"; then
    install -o hysteria -g hysteria -m 640 "\$src/\$f" "\$dst/\$f"
    changed=1
  fi
done
if [[ \$changed -eq 1 ]]; then
  systemctl restart hysteria-server.service
fi
EOF
chmod 755 /usr/local/bin/sync-hysteria-cert.sh
/usr/local/bin/sync-hysteria-cert.sh

cat >/etc/hysteria/config.yaml <<EOF
listen: :443

tls:
  cert: /etc/hysteria/${proxy_domain}.crt
  key: /etc/hysteria/${proxy_domain}.key

auth:
  type: password
  password: ${hysteria_password}

masquerade:
  type: file
  file:
    dir: /var/www/html
EOF
chmod 600 /etc/hysteria/config.yaml

cat >/etc/systemd/system/hysteria-cert-sync.service <<'EOF'
[Unit]
Description=Sync Caddy certificate to hysteria

[Service]
Type=oneshot
ExecStart=/usr/local/bin/sync-hysteria-cert.sh
EOF

cat >/etc/systemd/system/hysteria-cert-sync.timer <<'EOF'
[Unit]
Description=Daily hysteria certificate sync

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now hysteria-cert-sync.timer >/dev/null
systemctl enable --now hysteria-server.service >/dev/null
sleep 3

if ! systemctl is-active --quiet hysteria-server.service; then
  echo "error: hysteria failed to start; check 'journalctl -u hysteria-server'" >&2
  exit 1
fi

if ! ss -ulnp | grep -q ":443"; then
  echo "error: hysteria is not listening on UDP 443" >&2
  exit 1
fi

echo
echo "hysteria2 ready on udp/443 (caddy still serves tcp/443)"
echo "  server:   ${proxy_domain}:443"
echo "  password: ${hysteria_password}"
echo
echo "client: leave the up/down bandwidth fields BLANK to use BBR"
