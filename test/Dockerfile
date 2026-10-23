ARG UB=18.04
FROM ubuntu:${UB}
ENV DEBIAN_FRONTEND=noninteractive
ARG WEB=apache
RUN apt-get update -qq && apt-get install -y -qq ca-certificates curl gnupg procps systemd systemd-sysv apt-utils \
      $( [ "$WEB" = nginx ] && echo nginx || echo "apache2 apache2-utils" ) >/dev/null
COPY debs/ /debs/
COPY relabel.sh /
RUN bash /relabel.sh && cd /old && apt-get install -y -qq --no-install-recommends ./old-php-common_*.deb ./old-php7.3-common_*.deb \
      ./old-php7.3-json_*.deb ./old-php7.3-opcache_*.deb ./old-php7.3-readline_*.deb ./old-php7.3-cli_*.deb ./old-php7.3-fpm_*.deb \
      ./old-php7.3-mysql_*.deb ./old-php7.3-mbstring_*.deb ./old-php7.3-curl_*.deb ./old-php7.3-gd_*.deb ./old-php7.3-intl_*.deb \
      $( [ "$WEB" = apache ] && echo ./old-libapache2-mod-php7.3_*.deb ) >/dev/null && rm -rf /debs /old \
 && dpkg-query -W 'php7.3*' php-common
RUN if [ "$WEB" = nginx ]; then \
      printf 'server { listen 80 default_server; root /var/www/html; index index.php;\n location ~ \\.php$ { include snippets/fastcgi-php.conf; fastcgi_pass unix:/run/php/php7.3-fpm.sock; } }\n' > /etc/nginx/sites-enabled/default; \
    else \
      a2enmod -q proxy_fcgi setenvif >/dev/null; \
      printf 'Listen 8080\n<VirtualHost *:8080>\nDocumentRoot /var/www/html\n<FilesMatch "\\.php$">\nSetHandler "proxy:unix:/run/php/php7.3-fpm.sock|fcgi://localhost"\n</FilesMatch>\n</VirtualHost>\n' > /etc/apache2/sites-enabled/fpm.conf; \
      echo 'ServerName localhost' > /etc/apache2/conf-enabled/servername.conf; \
    fi; \
    rm -f /var/www/html/index.html; echo '<?php echo PHP_VERSION, " ", phpversion("mysqli") ? "mysqli" : "-";' > /var/www/html/index.php
STOPSIGNAL SIGRTMIN+3
CMD ["/lib/systemd/systemd"]
