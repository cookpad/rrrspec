#!/bin/bash -ex

until mysql --host="${DB_HOST}" --user="root" --password="${DB_PASSWORD}" ; do
  >&2 echo "MySQL is unavailable - sleeping"
  sleep 1
done

>&2 echo "MySQL is up - executing command"
exec $@
