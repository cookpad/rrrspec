#!/bin/bash -e
cd $(dirname $0)
mkdir -p tmp
exec 2>&1 1> >(tee tmp/test.log)

function before_exit() {
  echo "Shutdown"

  kill -TERM `jobs -p %?"rrrspec-master"`
  kill -TERM `jobs -p %?"rrrspec-worker"`
  wait %?"rrrspec-server server"
  wait %?"rrrspec-server worker"

  kill -9 `jobs -p %?"redis-server"`
  wait
}

trap "before_exit" EXIT

mkdir -p vendor/cache
cd ../rrrspec-client && bundle exec rake build && cp pkg/rrrspec-client-0.2.0.gem ../local_test/vendor/cache
cd ../rrrspec-server && bundle exec rake build && cp pkg/rrrspec-server-0.2.0.gem ../local_test/vendor/cache
cd ../local_test

rm -rf vendor/bundler/ruby/2.0.0/specifications/rrrspec-client-0.2.0.gemspec
rm -rf vendor/bundler/ruby/2.0.0/specifications/rrrspec-server-0.2.0.gemspec

set -x
export RACK_ENV=production
bundle install --path vendor/bundler
bundle exec rake -t rrrspec:server:db:create rrrspec:server:db:migrate
redis-server --port 9998 --save '' >/dev/null 2>&1 &

bundle exec rrrspec-master
bundle exec rrrspec-worker

TASK_KEY=$(bundle exec rrrspec-client --config dot_rrrspec.rb start --key-only)
echo TASK_KEY=$TASK_KEY
bundle exec rrrspec-client waitfor $TASK_KEY $RRRSPEC_CLIENTS_OPTIONS --pollsec=10
bundle exec rrrspec-client show $TASK_KEY $RRRSPEC_CLIENTS_OPTIONS --verbose --failure-exit-code=0
