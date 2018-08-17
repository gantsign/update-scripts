#!/usr/bin/env bash

set -e

new_version='2.16.0'

hub_download_url=$(curl --silent -H 'Accept: application/vnd.github.v3+json' https://api.github.com/repos/github/hub/releases \
        | jq --raw-output '.[0].assets[] | select(.name | test("hub-linux-amd64-[0-9.]+.tgz")) | .browser_download_url')


mkdir --parents '.tmp'

(cd '.tmp' && set -x | curl --silent --location "$hub_download_url" | tar xvz --strip=2 --wildcards '*/bin/hub')

repos=($(curl --silent -H 'Accept: application/vnd.github.v3+json' https://api.github.com/users/gantsign/repos \
        | jq --raw-output '.[] | select(.archived == false) | .name | select(. | test("ansible-role-.*"))'))

commit_msg="\
Removed unnecessary Molecule files

They're provided by Molecule 2.16.0 itself.
"

branch_name="rm-molecule-files"

changed_file='create.yml'

update_files() {
    (set -x && git rm \
        $(find . -regextype posix-extended -regex '.*/(prepare|create|destroy).yml'))

    (set -x && find . -name 'molecule.yml' -exec \
        sed --in-place --regexp-extended '/(prepare|create|destroy).yml/d' {} \;)

    (set -x && find . -name 'molecule.yml' -exec \
        perl -i -p0e 's/playbooks:\n  lint:/lint:/ms' {} \;)
}

print_banner() {
    echo ''
    echo '********************'
    echo "Processing: $1"
    echo '********************'
    echo ''
}

update_repo() {
    update_files

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
    (set -x && rm -rf "$repo")
    if ! (set -x && git clone --depth 1 "https://github.com/gantsign/$repo"); then
        echo 'Unable to proceed: failed to clone'
        return 0
    fi
    (cd "$repo" && update_repo)
}

for repo in "${repos[@]}"; do
    (cd '.tmp' && process_repo "$repo")
done
