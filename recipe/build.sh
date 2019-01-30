#!/bin/bash

env | sort

./configure --help || true

NGINX_CC_OPT="${CFLAGS} -I$PREFIX/include  -I$PREFIX/include/libxml2 -I$PREFIX/include/libexslt -I$PREFIX/include/libxslt -I$PREFIX/include/openssl"
NGINX_LD_OPT="${LDFLAGS}"

NGINX_CONFIGURE=""

if [[ $(uname -s) == Darwin ]]; then
  export DYLD_FALLBACK_LIBRARY_PATH=${PREFIX}/lib
  # TODO: ASLR
   NGINX_CONFIGURE="\
      --http-log-path=$PREFIX/var/log/nginx/access.log \
      --error-log-path=$PREFIX/var/log/nginx/error.log \
      --pid-path=$PREFIX/var/run/nginx/nginx.pid \
      --lock-path=$PREFIX/var/run/nginx/nginx.lock \
      --http-client-body-temp-path=$PREFIX/var/tmp/nginx/client \
      --http-proxy-temp-path=$PREFIX/var/tmp/nginx/proxy \
      --http-fastcgi-temp-path=$PREFIX/var/tmp/nginx/fastcgi \
      --http-scgi-temp-path=$PREFIX/var/tmp/nginx/scgi \
      --http-uwsgi-temp-path=$PREFIX/var/tmp/nginx/uwsgi \
      --conf-path=$PREFIX/etc/nginx/nginx.conf"

elif [[ $(uname -s) == Linux ]]; then
  # TODO: ASLR
  NGINX_CONFIGURE="\
      --http-log-path=var/log/nginx/access.log \
      --error-log-path=var/log/nginx/error.log \
      --pid-path=var/run/nginx/nginx.pid \
      --lock-path=var/run/nginx/nginx.lock \
      --http-client-body-temp-path=var/tmp/nginx/client \
      --http-proxy-temp-path=var/tmp/nginx/proxy \
      --http-fastcgi-temp-path=var/tmp/nginx/fastcgi \
      --http-scgi-temp-path=var/tmp/nginx/scgi \
      --http-uwsgi-temp-path=var/tmp/nginx/uwsgi \
      --conf-path=etc/nginx/nginx.conf"
fi

NGINX_CONFIGURE="${NGINX_CONFIGURE} \
      --sbin-path=sbin/nginx \
      --modules-path=lib/nginx/modules \
      --with-threads \
      --with-http_ssl_module \
      --with-http_v2_module \
      --with-http_realip_module \
      --with-http_addition_module \
      --with-http_sub_module \
      --with-http_gunzip_module \
      --with-http_gzip_static_module \
      --with-http_auth_request_module \
      --with-http_secure_link_module \
      --with-http_stub_status_module \
      --with-http_xslt_module=dynamic \
      --with-http_image_filter_module=dynamic \
      --with-pcre \
      --with-pcre-jit \
      --with-stream \
      --prefix=$PREFIX"

mkdir -p $PREFIX/lib/nginx
echo "NGINX_CONFIGURE=\"$NGINX_CONFIGURE\"" > $PREFIX/lib/nginx/configure.env
echo "NGINX_CC_OPT=\"$NGINX_CC_OPT\"" >> $PREFIX/lib/nginx/configure.env
echo "NGINX_LD_OPT=\"$NGINX_LD_OPT\"" >> $PREFIX/lib/nginx/configure.env

. $PREFIX/lib/nginx/configure.env

./configure ${NGINX_CONFIGURE} \
      --with-cc-opt="$NGINX_CC_OPT" \
      --with-ld-opt="$NGINX_LD_OPT"

make -j$CPU_COUNT
make install

rm $PREFIX/etc/nginx/*.default
mv $PREFIX/etc/nginx/nginx.conf $PREFIX/etc/nginx/nginx.conf.default
cp $RECIPE_DIR/nginx.conf $PREFIX/etc/nginx/
mkdir -p $PREFIX/etc/nginx/sites.d/
cp $RECIPE_DIR/default-site.conf $PREFIX/etc/nginx/sites.d/


# The below .mkdir files are because conda & conda-build don't currently
# support empty directory creation at install time.
mktouch()
{
  mkdir -p $1 && touch $1/.mkdir
}
mktouch $PREFIX/etc/nginx/main.d
mktouch $PREFIX/etc/nginx/stream.d
mktouch $PREFIX/var/tmp/nginx/client
mktouch $PREFIX/var/run

mkdir -p $PREFIX/var/log/nginx
touch $PREFIX/var/log/nginx/{access,error}.log

mv $PREFIX/html $PREFIX/etc/nginx/default-site

# This is a temporary hack until we can figure out what patch we need to apply
# to the nginx source code to make this unnecessary.
mkdir -p $PREFIX/bin/
cat > ${PREFIX}/bin/nginx <<EOF
#!/bin/sh
# This is a temporary hack until we can figure out what patch we need to apply
# to the nginx source code to make this unnecessary.
CWD="\$(cd "\$(dirname "\${0}")" && pwd -P)"
ROOT_PATH="\$(cd "\${CWD}/../" && pwd -P)"
exec \${ROOT_PATH}/sbin/nginx -p "\${ROOT_PATH}" "\${@}"
EOF

chmod 755 ${PREFIX}/bin/nginx
