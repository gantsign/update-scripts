#!/usr/bin/env bash

set -e

new_version="$(curl --silent -H 'Accept: application/vnd.github.v3+json' https://api.github.com/repos/sharkdp/fd/releases \
        | jq --raw-output '[.[] | select(.prerelease == false)] | .[0].tag_name')"

# remove `v` prefix
new_version="${new_version:1}"

new_sha256sum="$(curl --silent --location --output - \
    "https://github.com/sharkdp/fd/releases/download/v${new_version}/fd_${new_version}_amd64.deb" \
    | sha256sum | awk '{print $1}')"

hub_download_url=$(curl --silent -H 'Accept: application/vnd.github.v3+json' https://api.github.com/repos/github/hub/releases \
        | jq --raw-output '.[0].assets[] | select(.name | test("hub-linux-amd64-[0-9.]+.tgz")) | .browser_download_url')


mkdir --parents '.tmp'

(cd '.tmp' && set -x | curl --silent --location "$hub_download_url" | tar xvz --strip=2 --wildcards '*/bin/hub')


commit_msg="\
Updated fd to $new_version

Keeping up with the latest changes.
"

branch_name="fd-$new_version"

changed_file='README.md'

update_files() {
    sed --in-place \
        "s/fd_version: '.*'/fd_version: '$new_version'/" README.md

    sed --in-place \
        "s/fd_version: '.*'/fd_version: '$new_version'/" defaults/main.yml

    sed --in-place \
        "s/fd_redis_sha256sum: '.*'/fd_redis_sha256sum: '$new_sha256sum'/" README.md

    sed --in-place \
        "s/fd_redis_sha256sum: '.*'/fd_redis_sha256sum: '$new_sha256sum'/" defaults/main.yml
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
    repo="ansible_role_fd"

    print_banner "$repo"
    (set -x && rm -rf "$repo")
    if ! (set -x && git clone --depth 1 "https://github.com/gantsign/$repo"); then
        echo 'Unable to proceed: failed to clone'
        return 0
    fi
    (cd "$repo" && update_repo)
}

(cd '.tmp' && process_repo)

print_banner "Finished"
