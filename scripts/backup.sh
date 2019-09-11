#!/bin/bash

DATE=`date +%Y-%m-%d_%R`
DATABASE_FOLDER="fusenet/database"
BACKUP_FOLDER=fusenet_backup
BACKUP_FILENAME="db_${DATE}"
FILE="$BACKUP_FOLDER/$BACKUP_FILENAME.tar.gz"
S3_BUCKET="s3://fusenet-backup"

tar -czvf $FILE $DATABASE_FOLDER

aws s3 cp $FILE $S3_BUCKET

rm -rf $FILE
