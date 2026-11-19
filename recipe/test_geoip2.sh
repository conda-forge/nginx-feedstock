#!/bin/bash
# Check that the GeoIP2 dynamic modules load into this exact nginx build.
set -euo pipefail
D=$(mktemp -d)
mkdir -p "$D/logs" "$D/var/log/nginx" "$D/var/tmp/nginx"
cat > "$D/nginx.conf" <<X
load_module $PREFIX/lib/nginx/modules/ngx_stream_module.so;
load_module $PREFIX/lib/nginx/modules/ngx_http_geoip2_module.so;
load_module $PREFIX/lib/nginx/modules/ngx_stream_geoip2_module.so;
pid $D/nginx.pid;
error_log $D/logs/error.log;
events {}
http { server { listen 127.0.0.1:18094; } }
X
"$PREFIX/sbin/nginx" -p "$D" -c "$D/nginx.conf" -t
