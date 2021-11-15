#!/bin/bash

helpFunction()
{
   echo ""
   echo "Usage: $0 -l lowerVersion -h higherVersion -r repo"
   echo -e "\t-l the version of ACM we want to upgrade from"
   echo -e "\t-h the version of ACM we want to upgrade to"
   echo -e "\t-r the location we want to draw our bundle images from either PUBLISHED or DOWNSTREAM"
   echo -e "\t-t the tag for custom catalog"
   exit 1 # Exit script after printing help
}

getTag () {
TEMPFILE=./temp.json
echo "[]" > $TEMPFILE
chmod 777 $TEMPFILE
loop=1
page=1
totaljson="[]"
check="[]"
while [ $loop -eq 1 ]
do
newjson=$( curl --silent --location -H "Authorization: Bearer $3" -L $2/tag/?page=$page | jq '[ .tags[] ]' )
if [ "$newjson" != $check ] && [ "$totaljson" == $check ]; then
totaljson=$( jq --argjson arr1 "$totaljson" --argjson arr2 "$newjson" -n '[ $arr1 + $arr2 | .[] | select(.name | test("'$1'")) ]' )
page=$((page+1))
else
loop=0
fi
done

echo $totaljson | jq '. | sort_by(.["start_ts"])' > $TEMPFILE 
tag=$( jq -r '.[-1].name' $TEMPFILE )
echo $tag
}

while getopts "l:h:r:t:n:k:" opt
do
   case "$opt" in
      l ) lowerVersion="$OPTARG" ;;
      h ) higherVersion="$OPTARG" ;;
      r ) repo="$OPTARG" ;;
      t ) catalogTag="$OPTARG" ;;
      n ) destinationRepo="$OPTARG" ;;
      k ) token="$OPTARG" ;;
      ? ) helpFunction ;; # Print helpFunction in case parameter is non-existent
   esac
done

# Print helpFunction in case parameters are empty
if [ -z "$lowerVersion" ] || [ -z "$higherVersion" ] || [ -z "$repo" ]
then
   echo "Some or all of the parameters are empty";
   helpFunction
fi

if [ $repo == "DOWNSTREAM" ]
then

curl_target=https://quay.io/api/v1/repository/acm-d/acm-operator-bundle
first_tag="$( getTag "v"$lowerVersion".0.*$" $curl_target)"
second_tag="$( getTag "v"$higherVersion".0.*$" $curl_target)"


echo $first_tag
echo $second_tag

./gen_custom_registry.sh -B quay.io/acm-d/acm-operator-bundle:$first_tag -B quay.io/acm-d/acm-operator-bundle:$second_tag -n quay.io/cameronmwall/catalog-rep -t $catalogTag

docker push quay.io/cameronmwall/catalog-rep:$catalogTag

fi



if [ $repo == "UPSTREAM" ]
then

curl_target=https://quay.io/api/v1/repository/open-cluster-management/acm-operator-bundle

first_tag="$( getTag $lowerVersion".0.*$" $curl_target $token)"
second_tag="$( getTag $higherVersion".0.*$" $curl_target $token)"

echo $destinationRepo
./gen_custom_registry.sh -B quay.io/open-cluster-management/acm-operator-bundle:$first_tag -B quay.io/open-cluster-management/acm-operator-bundle:$second_tag -n $destinationRepo -t $catalogTag
docker push $destinationRepo:$catalogTag

fi


