#!/bin/sh
curl -XPOST --silent --fail -H "kbn-version: 8.7.0" -H "content-type: application/x-ndjson" --data '{"index":"*","ignore_unavailable":true,"timeout":30000,"preference":1562073188529}\
{"version":true,"size":0}\
' http://localhost:5601/elasticsearch/_msearch
