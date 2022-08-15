# syntax=docker/dockerfile:1.4
FROM nginx-custom:latest

RUN apk --no-cache add curl pup 

COPY <<EOF /tv.sh
curl -Ls 'https://onlinestream.live/?search=m4' | pup 'a[href^="/play.m3u8"] attr{href}' | sed 's/amp;//g'  | xargs -I{} curl -Ls https://onlinestream.live{} | grep https 
EOF

RUN chmod +x /tv.sh

COPY <<EOF /n.js
import fs from 'fs';
export default { world };

function world(r) {
  r.headersOut['content-type'] = 'application/json';
  r.return(200, JSON.stringify({ r }));
}
EOF

COPY <<EOF /etc/nginx/nginx.conf
load_module modules/ngx_http_js_module.so;
load_module modules/ndk_http_module.so;
load_module modules/ngx_http_lua_module.so;
load_module modules/ngx_stream_lua_module.so;

user  nginx;
worker_processes  auto;

error_log  /var/log/nginx/error.log notice;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    keepalive_timeout  65;
    gzip  on;
    client_max_body_size 50M;

    js_import /n.js;
    server {
      listen  80;

      location /index.html {
        root   /_;
        index  index.html;
      }

      location /hello {
        js_content n.world;
      }

      location /tv {
        content_by_lua_block {
           local handle = io.popen('/tv.sh', 'r')
           local output = handle:read('*a')
           handle:close()
           ngx.say(output)
        } 
      }
    }
}
EOF
