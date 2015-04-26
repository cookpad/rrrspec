#!/bin/bash
set -ex

mkdir -m700 -p /root/.ssh
mkdir -p /var/run/sshd /tmp/rrrspec-rsync /tmp/rrrspec-log-texts
cp local_test/id_rsa.rrrspec.pub /root/.ssh/authorized_keys

function at_exit() {
  service ssh stop
}

service ssh start
trap 'at_exit' EXIT

cd rrrspec-server
bundle exec rake rrrspec:server:db:create rrrspec:server:db:migrate RRRSPEC_CONFIG_FILES=/app/local_test/server_config.rb

foreman start -f /app/local_test/Procfile.master &
wait
