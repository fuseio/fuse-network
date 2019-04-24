#!/usr/bin/env bash

base_path='/data/pos'
nodes=('parity_data' 'parity_data_1' 'parity_data_2')
internals=('cache' 'chains' 'network')

for node in "${nodes[@]}";
do (
  path="$base_path/$node";
  cd $path;
  for i in "${internals[@]}";
    do (
      rm -rf "$path/$i";
    );
  done;
  rm -rf "$base_path/logs/$node";
);
done;