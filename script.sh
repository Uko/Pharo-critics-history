#!/usr/bin/env bash

THREADS=4

while getopts "t:" opt; do
  case $opt in
    t)
      THREADS=$OPTARG
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      ;;
  esac
done

process_rule() {
  result=$($work_dir/pharo $1 --no-default-preferences eval "$2 new in: [ :rule | RBSmalllintChecker runRule: rule. (rule critics collect: #name) asArray joinUsing: String lf ]")
  result=${result:1:${#result}-1}
  echo $result > $2
}

process_image () {
  version=${1:0:5}
  mkdir $version
  cd $version
  wget "http://files.pharo.org/image/50/${1}"
  unzip -qo $1
  rm $1

  rulesString=$($work_dir/pharo Pharo-$version.image --no-default-preferences eval '(RBCompositeLintRule allGoodRules leaves collect: #class) joinUsing: String space')
  rulesString=${rulesString:1:${#rulesString}-1}
  rules=($rulesString)

  for rule in "${rules[@]}"
  do
    process_rule Pharo-${version}.image $rule
  done

  cd $work_dir
}

webpage=`exec wget -q -O - http://files.pharo.org/image/50/`
images=($(echo $webpage | grep -o -E '[[:digit:]]{5}\.zip' | sort -nu))

work_dir=`exec pwd`
wget -O- get.pharo.org/vm50 | bash

for image in "${images[@]}"
do
  ((i=i%THREADS)); ((i++==0)) && wait
  process_image $image &
done
