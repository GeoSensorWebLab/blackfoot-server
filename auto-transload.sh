#!/bin/bash

if [ ! -f $1 ]; then
  echo "Input file does not exist."
  exit 1
fi

DLOG="$HOME/auto-download/download.log"
ULOG="$HOME/auto-download/upload.log"
STATIONS=$(cat $1)

touch $DLOG
touch $ULOG
cd $HOME/data-transloader

for station in $STATIONS; do
  ruby transload get observations --source environment_canada --station \
      $station --cache $HOME/data | tee -a $DLOG
  ruby transload put observations --source environment_canada --station \
      $station --cache $HOME/data --date latest --destination \
      http://localhost:8080/v1.0/ | tee -a $ULOG
done
