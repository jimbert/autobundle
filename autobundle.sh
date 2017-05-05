#!/usr/bin/env bash

shell_session_update() { :; }

function apps_to_update {
  find . -maxdepth 2 -print | grep Gemfile.lock | sed -nE 's/\.\/(.*)\/.*/\1/p'
}

function todays_date {
  date +%Y-%m-%d
}

function branch_name {
  echo "bundle-update-`todays_date`"
}

function setup_ruby_environment {
  ruby_version=$1
  gemset=$2

  echo "Setting up ruby $ruby_version@$gemset"
  rvm install $ruby_version
  rvm --create use "$ruby_version@$gemset"
  gem install bundler
  bundle install
}

for app in `apps_to_update`; do
  echo "Checking $app"
  cd $app
  git fetch
  git checkout master
  git remote prune origin
  if ! git branch -r | grep -q `branch_name`; then
    echo "Starting bundle update for $app"
    git reset --hard origin/master
    git checkout -B `branch_name`
    setup_ruby_environment `cat .ruby-version` `cat .ruby-gemset`
    rvm . do bundle update > bundle_update.log
    if git diff | grep Gemfile; then
      git add Gemfile.lock
      git commit -m "Bundle update `todays_date`"
      git push -u origin `branch_name`

      echo "Bundle update - `todays_date`" > pr.txt
      echo "" >> pr.txt
      echo "Updated the following gems:" >> pr.txt
      cat bundle_update.log | grep -P '\(was' | sed -nr 's/\w+\W*(.*)/ - \1/p' >> pr.txt
      hub pull-request -F pr.txt
      rm pr.txt bundle_update.log
    else
      echo "No updates today for $app"
    fi
  else
    echo "Bundle update already done for the day for $app"
  fi
  git checkout master
  cd ..
done
