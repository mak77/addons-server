FROM centos:centos7

# Allow scripts to detect we're running in our own container
RUN touch /addons-server-centos7-container

# Set the locale. This is mainly so that tests can write non-ascii files to
# disk.
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8

ADD docker/mysql-community.gpg.key /etc/pki/rpm-gpg/RPM-GPG-KEY-mysql
ADD docker/nodesource.gpg.key /etc/pki/rpm-gpg/RPM-GPG-KEY-nodesource

# For mysql-python dependencies
ADD docker/mysql.repo /etc/yum.repos.d/mysql.repo

# This is temporary until https://bugzilla.mozilla.org/show_bug.cgi?id=1226533
ADD docker/nodesource.repo /etc/yum.repos.d/nodesource.repo

RUN yum update -y \
    && yum install -y \
        # Supervisor is being used to start and keep our services running
        supervisor \
        # General (dev-) dependencies
        bash-completion \
        gcc-c++ \
        curl \
        make \
        libjpeg-devel \
        cyrus-sasl-devel \
        libxml2-devel \
        libxslt-devel \
        zlib-devel \
        libffi-devel \
        openssl-devel \
        python-devel \
        # Git, because we're using git-checkout dependencies
        git \
        # Nodejs for less, stylus, uglifyjs and others
        nodejs \
        # Dependencies for mysql-python
        mysql-community-devel \
        mysql-community-client \
        mysql-community-libs \
        epel-release \
        swig \
    && yum clean all

RUN yum install -y python-pip

# Until https://github.com/shazow/urllib3/commit/959d47d926e1331ad571dbfc150c9a3acb7a1eb9 lands
RUN pip install pyOpenSSL ndg-httpsclient pyasn1 certifi urllib3

# ipython / ipdb for easier debugging, supervisor to run services, watchdog for celery autorestart
RUN pip install ipython ipdb supervisor watchdog

COPY . /code
WORKDIR /code

ENV PIP_BUILD=/deps/build/
ENV PIP_CACHE_DIR=/deps/cache/
ENV PIP_SRC=/deps/src/
ENV NPM_CONFIG_PREFIX=/deps/
ENV SWIG_FEATURES="-D__x86_64__"

# Install all python requires
RUN mkdir -p /deps/{build,cache,src}/ && \
    ln -s /code/package.json /deps/package.json && \
    pip install --upgrade pip && \
    make update_deps && \
    rm -r /deps/build/ /deps/cache/

# Preserve bash history across image updates.
# This works best when you link your local source code
# as a volume.
ENV HISTFILE /code/docker/artifacts/bash_history

# Configure bash history.
ENV HISTSIZE 50000
ENV HISTIGNORE ls:exit:"cd .."

# This prevents dupes but only in memory for the current session.
ENV HISTCONTROL erasedups

ENV CLEANCSS_BIN /deps/node_modules/.bin/cleancss
ENV LESS_BIN /deps/node_modules/.bin/lessc
ENV STYLUS_BIN /deps/node_modules/.bin/stylus
ENV UGLIFY_BIN /deps/node_modules/.bin/uglifyjs
ENV ADDONS_LINTER_BIN /deps/node_modules/.bin/addons-linter
