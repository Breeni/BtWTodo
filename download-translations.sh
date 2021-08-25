#!/bin/bash

cf_api_key=
cf_project_id=
cf_namespaces=
cf_output=

if [ -f ".env" ]; then
	. ".env"
fi

[ -z "$cf_api_key" ] && cf_api_key=$CF_API_KEY
[ -z "$cf_project_id" ] && cf_project_id=$CF_PROJECT_ID
[ -z "$cf_namespaces" ] && cf_namespaces=$CF_NAMESPACES
[ -z "$cf_output" ] && cf_output=$CF_OUTPUT

tempfile=$( mktemp )
trap 'rm -f $tempfile' EXIT

infile=${cf_output/LOCALE/enUS}

echo -n "Importing: "
if [ -z "$cf_namespaces" ]
then
	metadata="{language: \"enUS\", format: \"TableAdditions\", \"missing-phrase-handling\": \"DeletePhrase\"}"
else
	metadata="{language: \"enUS\", format: \"TableAdditions\", namespace: \"$namespace\", \"missing-phrase-handling\": \"DeletePhrase\"}"
fi
http_code=$(curl -sS -X POST -w "%{http_code}" -o "$tempfile" "https://www.curseforge.com/api/projects/$cf_project_id/localization/import" -H "X-Api-Token: $cf_api_key" \
			  -F "metadata=$metadata" -F "localizations=<$infile") || exit 1
case $http_code in
	200)
		echo "Done"
	;;
	*)
		echo -n "Error - "
		[ -s "$tempfile" ] && grep -q "errorMessage" "$tempfile" | jq --raw-output '.errorMessage' "$tempfile"
	;;
esac

for locale in deDE esES esMX frFR itIT koKR ptBR ruRU zhCN zhTW
do
	if [ -z "$cf_namespaces" ]
	then
		query="export-type=TableAdditions&unlocalized=Ignore&table-name=L&lang=$locale"
	else
		query="export-type=TableAdditions&unlocalized=Ignore&table-name=L&lang=$locale&namespaces=$cf_namespaces"
	fi

	outfile=${cf_output/LOCALE/$locale}

	echo -n "Downloading locale $locale: "
	http_code=$(curl -sS -w "%{http_code}" -o "$tempfile" "https://wow.curseforge.com/api/projects/$cf_project_id/localization/export?$query" -H "X-Api-Token: $cf_api_key") || exit 1
	case $http_code in
	    200)
			echo "Done"
			cat $tempfile >> $outfile
		;;
		*)
			echo -n "Error - "
      		[ -s "$tempfile" ] && grep -q "errorMessage" "$tempfile" | jq --raw-output '.errorMessage' "$tempfile"
		;;
	esac
done

exit 0