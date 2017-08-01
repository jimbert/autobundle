#!/usr/bin/env bash --login

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
  rbenv install -s
  gem install bundler
  bundle install
}

function create_pull_request {
  git add Gemfile.lock
  git commit -m "Bundle update `todays_date`"
  git push -u origin `branch_name`

  echo "Bundle update - `todays_date`" > pr.txt
  echo "" >> pr.txt
  echo "Updated the following gems:" >> pr.txt
  cat bundle_update.log | grep -E '\(was' | sed -nE 's/^(Using|Installing)(.*)/ - \2/p' >> pr.txt
  cat pr.txt
  hub pull-request -F pr.txt
  rm pr.txt bundle_update.log
}

function prepare_git_repo {
  git fetch
  git checkout master
  git remote prune origin
  git reset --hard origin/master
}

function create_bundle_update_branch {
  git checkout -B `branch_name`
}

function verify_script_dependencies {
  hub --help >/dev/null 2>&1 || \
    { echo >&2 "I require hub but it is not on the path.  Aborting."; exit 1; }
  rbenv --version >/dev/null 2>&1 || \
    { echo >&2 "rbenv is required with the install plugin. Aborting."; exit 1;}
}

verify_script_dependencies

for app in `apps_to_update`; do
  echo "Checking $app"
  cd $app
  prepare_git_repo
  if ! git branch -r | grep -q `branch_name`; then
    echo "No existing branch found: starting bundle update for $app"
    setup_ruby_environment >/dev/null 2>&1
    create_bundle_update_branch >/dev/null 2>&1
    bundle update > bundle_update.log
    if git diff | grep Gemfile; then
      create_pull_request
    else
      echo "No updates today for $app"
    fi
  else
    echo "Bundle update already done for the day for $app (origin branch `branch_name` exists)"
  fi
  git checkout master
  cd ..
done
