#!/bin/sh

echo "Migrating database."
bundle exec rake db:migrate
echo "Done migrating database. Starting Metrics API Server"
exec "$@"
