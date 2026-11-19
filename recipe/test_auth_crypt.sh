#!/bin/bash
# Check that auth_basic works with crypt()-based password hashes (bcrypt and
# SHA-512 crypt). These need libxcrypt on Linux; without it every login fails.
set -euo pipefail

D=$(mktemp -d)
mkdir -p "$D/logs" "$D/html"
echo ok > "$D/html/index.html"
cat > "$D/htpasswd" <<'X'
bc:$2b$05$WF7IxAcEn4MBhQBDoNjGQeNrSGN/M5DK..ffiHH27..R/FAhXB2dK
sha:$6$abcdefgh$Z7KfoKnKTSZrzo5VZ0YubGLQOj9ov6sHo9TmE3zIU/LHKhpE30zCnZ0mcIXYf9r9rQ4DYaXoxAFSPFlcWdxjB.
X
cat > "$D/nginx.conf" <<X
daemon off;
pid $D/nginx.pid;
error_log $D/logs/error.log;
events {}
http {
  access_log off;
  server {
    listen 127.0.0.1:18090;
    root $D/html;
    auth_basic "test";
    auth_basic_user_file $D/htpasswd;
  }
}
X

"$PREFIX/sbin/nginx" -p "$D" -c "$D/nginx.conf" &
NGINX_PID=$!
trap 'kill $NGINX_PID 2>/dev/null || true' EXIT
for _ in $(seq 1 20); do
  curl -s -o /dev/null http://127.0.0.1:18090/ && break
  sleep 0.5
done

check() {
  local creds=$1 expected=$2 got
  got=$(curl -s -o /dev/null -w '%{http_code}' -u "$creds" http://127.0.0.1:18090/)
  if [[ "$got" != "$expected" ]]; then
    echo "FAIL: $creds -> $got (expected $expected)"
    cat "$D/logs/error.log"
    exit 1
  fi
  echo "ok: ${creds%%:*} -> $got"
}

check 'bc:s3cret' 200
check 'bc:wrong' 401
check 'sha:s3cret' 200
check 'sha:wrong' 401
