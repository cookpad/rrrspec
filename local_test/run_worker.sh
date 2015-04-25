#!/bin/bash
set -ex

mkdir -m700 -p /root/.ssh
cp local_test/id_rsa.rrrspec /root/.ssh/id_rsa
cp local_test/ssh_config /root/.ssh/config

cd rrrspec-server
exec bundle exec bin/rrrspec-server worker --config /app/local_test/worker_config.rb --no-daemonize
