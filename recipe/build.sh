#!/bin/bash

mkdir build-aux
cp $BUILD_PREFIX/share/gnuconfig/config.* ./build-aux

env | sort

./configure --help || true

git clone https://github.com/evanmiller/mod_zip.git mod_zip
cd mod_zip && git checkout a9f9afa441117831cc712a832c98408b3f0416f6
MODZIPDIR=$(pwd)
cd ..


if [[ $(uname -s) == Darwin ]]; then
  export DYLD_FALLBACK_LIBRARY_PATH=${PREFIX}/lib
  export cc_opt="-I$PREFIX/include  -I$PREFIX/include/libxml2 -I$PREFIX/include/libexslt -I$PREFIX/include/libxslt -I$PREFIX/include/openssl"
  export ld_opt="-L$PREFIX/lib"

  patch src/os/unix/ngx_darwin_config.h $RECIPE_DIR/ngx_darwin_config.h.patch
  patch auto/feature $RECIPE_DIR/feature.patch
  patch auto/unix $RECIPE_DIR/unix.patch

  ./configure \
      --http-log-path=$PREFIX/var/log/nginx/access.log \
      --error-log-path=$PREFIX/var/log/nginx/error.log \
      --pid-path=$PREFIX/var/run/nginx/nginx.pid \
      --lock-path=$PREFIX/var/run/nginx/nginx.lock \
      --http-client-body-temp-path=$PREFIX/var/tmp/nginx/client \
      --http-proxy-temp-path=$PREFIX/var/tmp/nginx/proxy \
      --http-fastcgi-temp-path=$PREFIX/var/tmp/nginx/fastcgi \
      --http-scgi-temp-path=$PREFIX/var/tmp/nginx/scgi \
      --http-uwsgi-temp-path=$PREFIX/var/tmp/nginx/uwsgi \
      --sbin-path=sbin/nginx \
      --conf-path=$PREFIX/etc/nginx/nginx.conf \
      --modules-path=lib/nginx/modules \
      --with-threads \
      --add-module=$MODZIPDIR \
      --with-http_ssl_module \
      --with-http_v2_module \
      --with-http_realip_module \
      --with-http_addition_module \
      --with-http_xslt_module=dynamic \
      --with-http_sub_module \
      --with-http_gunzip_module \
      --with-http_gzip_static_module \
      --with-http_auth_request_module \
      --with-http_secure_link_module \
      --with-http_stub_status_module \
      --with-stream=dynamic \
      --with-http_image_filter_module=dynamic \
      --with-pcre \
      --with-pcre-jit \
      --with-cc-opt="$cc_opt" \
      --with-ld-opt="$ld_opt" \
      --with-debug \
      --prefix="$PREFIX"

  ls -lah



elif [[ $(uname -s) == Linux ]]; then
  export cc_opt="-I$PREFIX/include -I$PREFIX/include/libxml2 -I$PREFIX/include/libexslt -I$PREFIX/include/libxslt -I$PREFIX/include/openssl"
  export ld_opt="-L$PREFIX/lib"

  ./configure \
      --http-log-path=var/log/nginx/access.log \
      --error-log-path=var/log/nginx/error.log \
      --pid-path=var/run/nginx/nginx.pid \
      --lock-path=var/run/nginx/nginx.lock \
      --http-client-body-temp-path=var/tmp/nginx/client \
      --http-proxy-temp-path=var/tmp/nginx/proxy \
      --http-fastcgi-temp-path=var/tmp/nginx/fastcgi \
      --http-scgi-temp-path=var/tmp/nginx/scgi \
      --http-uwsgi-temp-path=var/tmp/nginx/uwsgi \
      --sbin-path=sbin/nginx \
      --conf-path=etc/nginx/nginx.conf \
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
      --with-stream=dynamic \
      --with-http_image_filter_module=dynamic \
      --with-pcre="$PREFIX" \
      --with-pcre-jit \
      --with-cc-opt="$cc_opt" \
      --with-ld-opt="$ld_opt" \
      --with-debug \
      --prefix="$PREFIX"
fi

make -j$CPU_COUNT
make install

rm $PREFIX/etc/nginx/*.default
mv $PREFIX/etc/nginx/nginx.conf $PREFIX/etc/nginx/nginx.conf.default
cp $RECIPE_DIR/nginx.conf $PREFIX/etc/nginx/
mkdir -p $PREFIX/etc/nginx/sites.d/
cp $RECIPE_DIR/default-site.conf $PREFIX/etc/nginx/sites.d/


# The below .mkdir files are because conda & conda-build don't currently
# support empty directory creation at install time.
mkdir -p $PREFIX/var/tmp/nginx/client/
touch $PREFIX/var/tmp/nginx/client/.mkdir
mkdir -p $PREFIX/var/run/
touch $PREFIX/var/run/.mkdir
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
