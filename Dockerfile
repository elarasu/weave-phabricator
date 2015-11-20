# phabricator image 
#   docker build -t elarasu/weave-phabricator .
#
FROM elarasu/weave-supervisord
MAINTAINER elarasu@outlook.com

# Install requirements
RUN  apt-get update  \
  && apt-get upgrade -y \
  && apt-get install -yq ssh cron git sendmail fetchmail nodejs-legacy npm python-pygments \
       build-essential g++ \
       nginx php5 php5-fpm php5-mcrypt php5-mysql php5-gd php5-dev php5-curl php-apc php5-cli php5-json php5-ldap php5-imap php-pear python-Pygments nodejs sudo --no-install-recommends \
  && npm install ws \
  && pecl install mailparse \
  && rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/*

# Add users
RUN echo "git:x:2000:2000:user for phabricator ssh:/srv/phabricator:/bin/bash" >> /etc/passwd
RUN echo "phab-daemon:x:2001:2000:user for phabricator daemons:/srv/phabricator:/bin/bash" >> /etc/passwd
RUN echo "wwwgrp-phabricator:!:2000:nginx" >> /etc/group

# Set up the Phabricator code base
RUN mkdir /srv/phabricator
RUN chown git:wwwgrp-phabricator /srv/phabricator
USER git
WORKDIR /srv/phabricator
RUN git clone --depth 1 git://github.com/facebook/libphutil.git
RUN git clone --depth 1 git://github.com/facebook/arcanist.git
RUN git clone --depth 1 git://github.com/facebook/phabricator.git
USER root
WORKDIR /

# Expose Nginx on port 80 and 443
EXPOSE 80
EXPOSE 443

# Expose Aphlict (notification server) on 22280
EXPOSE 22280

# Helper scripts around running & upgrading phabricator
ADD configure-instance.sh /srv/phabricator/
ADD upgrade-phabricator.sh /srv/phabricator/
ADD startup.sh /

# Add service config files
ADD nginx.conf.org /etc/nginx/
ADD nginx-ssl.conf.org /etc/nginx/
ADD fastcgi.conf /etc/nginx/
ADD php-fpm.conf /etc/php5/fpm/
ADD php.ini /etc/php5/fpm/

# Add necessary git entries entries
RUN echo "git ALL=(phab-daemon) SETENV: NOPASSWD: /usr/bin/git-upload-pack, /usr/bin/git-receive-pack" > /etc/sudoers.d/git

# Add mailparse to php
RUN echo "extension=mailparse.so" > /etc/php5/cli/conf.d/30-mailparse.ini

# Add Supervisord config files
ADD cron.sv.conf /etc/supervisor/conf.d/
ADD nginx.sv.conf /etc/supervisor/conf.d/
ADD phab-sshd.sv.conf /etc/supervisor/conf.d/
ADD php5-fpm.sv.conf /etc/supervisor/conf.d/

# Add the cron for upgrading phabricator
ADD upgrade-phabricator.cron /etc/cron.d/phabricator

RUN mkdir -p /var/repo/
RUN chown phab-daemon:2000 /var/repo/

# Configure Phabricator SSH service
RUN mkdir /etc/phabricator-ssh
RUN mkdir /var/run/sshd/
RUN chmod 0755 /var/run/sshd
ADD phabricator-ssh-hook.sh /etc/phabricator-ssh/
RUN chown root:root /etc/phabricator-ssh/*

CMD ./startup.sh && supervisord

