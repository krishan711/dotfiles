#!/usr/bin/env bash

expected_env=".env"
expected_path="$expected_env/bin/activate"
if [ ! -d "$expected_env" ]; then
    echo "Making $expected_env..."
    python3 -m venv $expected_env
    . $expected_path
    pip install --upgrade pip
    deactivate
fi

if [[ ! $expected_env = $(which python)* ]]; then
    echo "Loading $expected_env..."
    . $expected_path
fi

unset PS1
