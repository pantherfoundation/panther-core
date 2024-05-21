#!/bin/bash

PAGE_SIZE=1000
SKIP=0
TOTAL_COUNT=0

# Check if a subgraph ID is provided as an argument
if [ -z "$1" ]; then
  echo "Usage: $0 <subgraph_id>"
  exit 1
fi

SUBGRAPH_ID=$1
GRAPHQL_ENDPOINT="https://api.thegraph.com/subgraphs/id/$SUBGRAPH_ID"

# Function to fetch data from the GraphQL endpoint
fetch_data() {
  local skip=$1
  curl -s -X POST -H "Content-Type: application/json" --data '{
    "query": "{ transactionNotes(first: '"${PAGE_SIZE}"', skip: '"${skip}"' where: {txType: 1}) { id } }"
  }' "$GRAPHQL_ENDPOINT"
}

# Function to parse and validate the response
parse_response() {
  local response=$1

  if [[ $(echo "$response" | jq -e '.errors') != null ]]; then
    echo "Error in response: $(echo "$response" | jq '.errors')"
    exit 1
  fi

  if [[ $(echo "$response" | jq -e '.data.transactionNotes') == null ]]; then
    echo "Error: No data found in response. Full response: $response"
    exit 1
  fi

  local count=$(echo "$response" | jq '.data.transactionNotes | length')
  if ! [[ "$count" =~ ^[0-9]+$ ]]; then
    echo "Error: COUNT is not a number or is empty. Value: $count"
    echo "Full response: $response"
    exit 1
  fi

  echo "$count"
}

# Loop to handle pagination and count the entities
while true; do
  RESPONSE=$(fetch_data $SKIP)
  COUNT=$(parse_response "$RESPONSE")

  if [ "$COUNT" -eq 0 ]; then
    break
  fi

  TOTAL_COUNT=$((TOTAL_COUNT + COUNT))
  SKIP=$((SKIP + PAGE_SIZE))
done

echo "Total unique users: $TOTAL_COUNT"
