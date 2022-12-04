#!/bin/sh -ex

bundle config set force_ruby_platform true
bundle install
rm -f tmp/pids/server.pid
exec "$@"
