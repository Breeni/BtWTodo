#!/bin/bash

cf_api_key=
cf_project_id=
cf_namespaces=
cf_source=

if [ -f ".env" ]; then
	. ".env"
fi

[ -z "$cf_api_key" ] && cf_api_key=$CF_API_KEY
[ -z "$cf_project_id" ] && cf_project_id=$CF_PROJECT_ID
[ -z "$cf_namespaces" ] && cf_namespaces=$CF_NAMESPACES
[ -z "$cf_source" ] && cf_source=$CF_SOURCE

tempfile=$( mktemp )
trap 'rm -f $tempfile' EXIT

echo -n "Uploading: "
if [ -z "$cf_namespaces" ]
then
	metadata="{language: \"enUS\", format: \"TableAdditions\", \"missing-phrase-handling\": \"DeletePhrase\"}"
else
	metadata="{language: \"enUS\", format: \"TableAdditions\", namespace: \"$namespace\", \"missing-phrase-handling\": \"DeletePhrase\"}"
fi
http_code=$(curl -sSL -X POST -w "%{http_code}" -o "$tempfile" "https://wow.curseforge.com/api/projects/$cf_project_id/localization/import" -H "X-Api-Token: $cf_api_key" \
			  -F "metadata=$metadata" -F "localizations=<$cf_source") || exit 1
case $http_code in
	200)
		echo "Done"
		exit 0
	;;
	*)
		echo -n "Error - "
		[ -s "$tempfile" ] && grep -q "errorMessage" "$tempfile" | jq --raw-output '.errorMessage' "$tempfile"
		exit 1
	;;
esac
