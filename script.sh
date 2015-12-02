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
  result=$($work_dir/pharo $1 --no-default-preferences eval "$2 new in: [ :rule | RBSmalllintChecker runRule: rule. (rule critics collect: [ :entity | entity name, ' [', entity package name, ']']) asArray joinUsing: String lf ]")
  result=${result#\'}
  result=${result%\'}
  echo "$result" > $2
}

process_image () {
  version=${1:0:5}
  mkdir $version
  cd $version

  if [ ! -e ".done" ]
  then
    wget "http://files.pharo.org/image/50/${1}"
    unzip -qo $1
    rm $1

    eval "$work_dir/pharo Pharo-$version.image --no-default-preferences eval --save \"Gofer it smalltalkhubUser: 'Pharo' project: 'Pharo50'; version: 'Refactoring-Critics-TheIntegrator.248'; load\""

    eval "$work_dir/pharo Pharo-$version.image --no-default-preferences eval --save \"Gofer it smalltalkhubUser: 'Pharo' project: 'Pharo50'; version: 'Manifest-Core-TheIntegrator.236'; load\""

    rulesString=$($work_dir/pharo Pharo-$version.image --no-default-preferences eval '(RBCompositeLintRule allGoodRules leaves collect: #class) joinUsing: String space')
    rulesString=${rulesString#\'}
    rulesString=${rulesString%\'}
    rules=($rulesString)

    for rule in "${rules[@]}"
    do
      process_rule Pharo-${version}.image $rule
    done

    touch ".done"
  fi

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
