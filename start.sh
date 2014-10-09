#!/bin/bash -ex

cd /rails_app

ln -sf /rails_conf/* ./config/

if [ "$RAILS_ENV" == "development" ]
then
    bundle install
    rake db:migrate
fi

exec bundle exec rails s puma -p 80 $*