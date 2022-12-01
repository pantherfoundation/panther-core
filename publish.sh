#!/bin/bash

finished=
trap on_exit EXIT
on_exit() {
    if [ -z "$finished" ]; then
        echo >&2 "ERROR: Exited prematurely!"
    fi
}
set -o errexit

die() {
    echo >&2 "$*"
    exit 1
}

if ! [ -d circuits ] || ! [ -e publish.sh ]; then
    die "Please run from the top level of the panther-core private worktree."
fi

if ! which git-filter-repo >&/dev/null; then
    die "Please install git-filter-repo first."
fi

if ! public_dir=$(mktemp -d -p -u panther-core.public.XXXXX --tmpdir); then
    die "mktemp failed"
fi

git clone --no-local --branch main --single-branch . "$public_dir"
cd "$public_dir"
git filter-repo --invert-paths --path circuits --path publish.sh
git remote add github-public git@github.com:pantherprotocol/panther-core.git
git fetch github-public

cat << EOF

Press Enter to see new commits to publish:
EOF
read
git log --abbrev-commit --pretty=oneline --decorate --graph \
    --pretty=tformat:"%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cd) %Cblue(%an)%Creset" \
    github-public/main^..main

cat << EOF
If that looks correct, run the following commands:

pushd $public_dir
git push github-public main

# Optionally:
popd && rm -rf $public_dir
EOF

finished=true
