#!/bin/bash
set -euo pipefail

# Truncate any existing results
:>stars.json

STARS=200

# Loop forever, we exit on error or when we get the same number of stars at start/end
while true; do
    echo "Searching repositories with ${STARS:-*} or less stars..."
    # Fetch a batch of 1000 search results at a time
    # We must start with >=150 stars or we don't get the correct top results from GitHub
    # The results seem to be truncated due to an internal results limit otherwise
    gh api graphql --paginate \
        --jq '.data.search.nodes[]' \
        -F search="sort:stars stars:150..${STARS:-*}" \
        -f query='query($search: String!, $endCursor: String) {
            search(type: REPOSITORY, query:$search, after:$endCursor, first:100) {
                pageInfo {
                    hasNextPage
                    endCursor
                }
                nodes {
                    ... on Repository {
                        id
                        nameWithOwner
                        stargazerCount
                    }
                }
            }
        }
    ' >> stars.json
    # Extract the final (minimum) star count from the batch (saving the original value)
    LAST_STARS=${STARS:-0}
    STARS=$(tail -n1 stars.json | jq -r .stargazerCount)
    # If the value didn't change, we can't iterate further, halt
    if [ "${LAST_STARS}" = "${STARS}" ]; then
        break
    fi
done

# Build a CSV with the results
echo "id,repository,stars" > stars.csv
jq -rs 'unique_by(.id) | sort_by(.stargazerCount)[] | [.id, .nameWithOwner, .stargazerCount] | @csv' stars.json >> stars.csv
echo "Deduplicated $(wc -l stars.json) to $(wc -l stars.csv) results..." 
