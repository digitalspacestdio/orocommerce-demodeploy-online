#!/bin/sh
# php-fpm liveness: FastCGI ping on the TCP listener (ping.path=/ping in php-fpm.conf)
env -i REQUEST_METHOD=GET SCRIPT_NAME=/ping SCRIPT_FILENAME=/ping cgi-fcgi -bind -connect 127.0.0.1:9000 >/dev/null 2>&1
