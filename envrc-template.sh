#!/usr/bin/env bash

#!/usr/bin/env bash

expected_env=".env"
expected_path="$expected_env/bin/activate"
if [ ! -d "$expected_env" ]; then
    echo "Making $expected_env..."
    python3.14 -m venv $expected_env
    source $expected_path
    pip install --upgrade pip
    deactivate
fi
echo "Loading $expected_path..."
source $expected_path
export UV_PROJECT_ENVIRONMENT=$VIRTUAL_ENV

unset PS1
