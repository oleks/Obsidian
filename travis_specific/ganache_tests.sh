#!/usr/bin/env bash

cd "$TRAVIS_BUILD_DIR" || exit 1

# Ganache Tests -- these actually build the compiled Yul via Truffle then run it via Ganache
for test in resources/tests/GanacheTests/*.sh
do
  echo "running Ganache Test $test"
  bash "$test"
done
