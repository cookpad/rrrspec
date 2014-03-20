#!/bin/bash -e
cd $(dirname $0)
mkdir -p tmp
exec 2>&1 1> >(tee tmp/test.log)

function before_exit() {
  echo "Shutdown"

  kill -9 `jobs -p %?"rrrspec-master"` || true
  kill -9 `jobs -p %?"rrrspec-worker"` || true
  wait %?"rrrspec-master"
  wait %?"rrrspec-worker"

  kill -9 `jobs -p %?"redis-server"` || true
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

bundle exec rrrspec-master --no-daemonize &
bundle exec rrrspec-worker --no-daemonize &

TASK_KEY=$(bundle exec rrrspec-client --config dot_rrrspec.rb start --key-only)
echo TASK_KEY=$TASK_KEY
bundle exec rrrspec-client --config dot_rrrspec.rb waitfor $TASK_KEY
bundle exec rrrspec-client --config dot_rrrspec.rb show $TASK_KEY --failure-exit-code=0
echo FINISHED
