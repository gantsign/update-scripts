#!/usr/bin/env bash

set -e

repos=($(curl --silent -H 'Accept: application/vnd.github.v3+json' 'https://api.github.com/users/gantsign/repos?per_page=100' \
        | jq --raw-output '.[] | select(.archived == false) | .name | select(. | test("ansible.role.*"))'))

commit_msg="\
Changed to use Molecule Wrapper for tests

To make it easier for other developers to test the role.
"

branch_name="moleculew"

changed_file='.travis.yml'

print_banner() {
    echo ''
    echo '************************************************************'
    echo "Processing: $1"
    echo '************************************************************'
    echo ''
}

update_repo() {
    if ! (git status | grep --quiet "$changed_file"); then
        echo 'Unable to proceed: no changes'
        return 0
    fi

    if ! (set -x && git checkout -b "$branch_name"); then
        echo 'Unable to proceed: error creating branch'
        return 0
    fi

    if ! (set -x && git add --verbose .); then
        echo 'Unable to proceed: unable to add file'
        return 0
    fi

    if ! (set -x && git commit --message="$commit_msg"); then
        echo 'Unable to proceed: commit failed'
        return 0
    fi

    if ! (set -x && ../hub pull-request --push --message="$commit_msg"); then
        echo 'Unable to proceed: failed to create pull request'
        return 0
    fi
}

process_repo() {
    repo="$1"

    print_banner "$repo"
    (cd "$repo" && update_repo)
}

for repo in "${repos[@]}"; do
    (cd '.tmp' && process_repo "$repo")
done

print_banner "Finished"
