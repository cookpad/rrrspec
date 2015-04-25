#!/bin/bash
set -ex

mkdir -m700 -p /root/.ssh
cp local_test/id_rsa.rrrspec /root/.ssh/id_rsa
cp local_test/ssh_config /root/.ssh/config

cd rrrspec-client

TASK_KEY=$(bundle exec bin/rrrspec-client start --config /app/local_test/client_config.rb --rsync-name client --key-only)
bundle exec bin/rrrspec-client waitfor $TASK_KEY --config /app/local_test/client_config.rb --pollsec=10
exec bundle exec bin/rrrspec-client show $TASK_KEY --config /app/local_test/client_config.rb --verbose --failure-exit-code=0
