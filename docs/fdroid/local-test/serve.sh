#!/bin/bash
# Serves /serve/apks over HTTPS on localhost:8443 inside the build container, for
# a test recipe's `binary:` (fdroid downloads reference binaries over https only).
# Run detached (docker exec -d), then run build.sh with
# REQUESTS_CA_BUNDLE=/tmp/serve/cert.pem so fdroid trusts the self-signed cert.
set -e
mkdir -p /tmp/serve; cd /tmp/serve
[ -f cert.pem ] || openssl req -x509 -newkey rsa:2048 -nodes -keyout key.pem -out cert.pem \
  -days 7 -subj /CN=localhost -addext subjectAltName=DNS:localhost 2>/dev/null
chmod a+r cert.pem
exec python3 -c '
import functools, http.server, ssl
h = functools.partial(http.server.SimpleHTTPRequestHandler, directory="/serve/apks")
s = http.server.ThreadingHTTPServer(("127.0.0.1", 8443), h)
c = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER); c.load_cert_chain("cert.pem", "key.pem")
s.socket = c.wrap_socket(s.socket, server_side=True); s.serve_forever()'
