#!/usr/bin/env bash

set -e

new_version="$(curl --silent -H 'Accept: application/vnd.github.v3+json' https://api.github.com/repos/ansible/molecule/releases \
        | jq --raw-output '[.[] | select(.prerelease == false)] | .[0].tag_name')"

hub_download_url=$(curl --silent -H 'Accept: application/vnd.github.v3+json' https://api.github.com/repos/github/hub/releases \
        | jq --raw-output '.[0].assets[] | select(.name | test("hub-linux-amd64-[0-9.]+.tgz")) | .browser_download_url')

mkdir --parents '.tmp'

(cd '.tmp' && set -x | curl --silent --location "$hub_download_url" | tar xvz --strip=2 --wildcards '*/bin/hub')

repos=($(curl --silent -H 'Accept: application/vnd.github.v3+json' 'https://api.github.com/users/gantsign/repos?per_page=100' \
        | jq --raw-output '.[] | select(.archived == false) | .name | select(. | test("ansible.role.*"))'))

commit_msg="\
Updated Molecule to $new_version

Keeping up with the latest changes.
"

branch_name="molecule-$new_version"

changed_file='.moleculew/molecule_version'

update_files() {
    (set -x && echo "$new_version" > .moleculew/molecule_version)
    (set -x && ./moleculew init scenario -r "$repo" -s template -d docker)
    (set -x && find . -name Dockerfile.j2 | grep -v template | \
        xargs -I % cp molecule/template/Dockerfile.j2 %)
    (set -x && find . -name INSTALL.rst | grep -v template | \
        xargs -I % cp molecule/template/INSTALL.rst %)
    (set -x && rm -rf molecule/template)
}

print_banner() {
    echo ''
    echo '************************************************************'
    echo "Processing: $1"
    echo '************************************************************'
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

print_banner "Finished"
