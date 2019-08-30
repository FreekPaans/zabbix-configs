#!/usr/bin/env bash

DEBUG_FILE=/tmp/debug-aggregate

if [[ -w  "$DEBUG_FILE" ]]; then
	echo invoked with "$*" >> "$DEBUG_FILE"
	echo 1st: "$1" >> "$DEBUG_FILE"
fi

QUERY="$1"
FIELD="$2"
RANGE="${3:--d}"
INDEX="${4:-*}"

if [[ -z "$QUERY" || -z "$FIELD" ]]; then
	echo "Usage: $0 <query> <field> [range=-1d] [index=filebeat-*]"
	exit 1
fi

read -r -d '' TEMPLATE <<'EOF'
{
  "size": 0,
  "aggs": {
    "zabbix_aggregate": {
      "percentiles": {
        "field": "nginx.access.request_time",
        "percents": [ 1, 5, 25, 50, 75, 95, 99 ]
      }
    }
  },
  "query": {
    "bool": {
      "must": [
        {
          "query_string": {
            "query": "nginx.access.url:*_doc*",
            "analyze_wildcard": true,
            "default_field": "*"
          }
        },
        {
          "range": {
            "@timestamp": {
              "gte": 1566890904330,
              "lte": 1566977304330,
              "format": "epoch_second"}}}]}}}
EOF

RANGE_FROM=$(date -d "$RANGE" +%s)
if [[ ! "$?" -eq 0 ]]; then
	echo "Failure getting range from, are you sure '$RANGE' is a valid format"
	exit 1
fi

RANGE_TO=$(date +%s)

QUERY_JSON=$(echo "$TEMPLATE" | \
	jq --arg query "$QUERY" '.query.bool.must[0].query_string.query = $query' | \
	jq --arg from "$RANGE_FROM" '.query.bool.must[1].range["@timestamp"].gte = $from' | \
	jq --arg to "$RANGE_TO" '.query.bool.must[1].range["@timestamp"].lte = $to ' | \
	jq --arg field "$FIELD" '.aggs.zabbix_aggregate.percentiles.field = $field')

#echo $QUERY_JSON | jq . && exit 1

if [[ ! "$?" -eq 0 ]]; then
	echo "Failure composing query, aborting"
	exit 1
fi

echo "$QUERY_JSON" | curl -s -XPOST -H "Content-type: application/json" -d@- "localhost:9200/$INDEX/_search" | jq '.aggregations.zabbix_aggregate.values'

if [[ ! "$?" -eq 0 ]]; then
	echo "Failed issuing query '$QUERY_JSON' to elastic, aborting"
	exit 1
fi
