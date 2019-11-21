#!/bin/bash
#
# Argument = -u user -p password -k key -s secret -b bucket
#
# To Do - Add logging of output.
# To Do - Abstract bucket region to options

set -e

export PATH="$PATH:/usr/local/bin"

usage()
{
cat << EOF
usage: $0 options

This script dumps the current mongo database, tars it, then sends it to an Amazon S3 bucket.

OPTIONS:
   -u      Mongodb user (optional)
   -p      Mongodb password (optional)
   -k      AWS Access Key (required)
   -s      AWS Secret Key (required)
   -r      Amazon S3 region (required)
   -b      Amazon S3 bucket name (required)
   -a      Amazon S3 folder (required)
   -f      Backup filename prefix (optional)
EOF
}

MONGODB_USER=
MONGODB_PASSWORD=
AWS_ACCESS_KEY=
AWS_SECRET_KEY=
S3_REGION=
S3_BUCKET=
FOLDER_NAME=
FILE_NAME_PREFIX=


while getopts “ht:u:p:k:s:r:b:a:f:” OPTION
do
  case $OPTION in
    h)
      usage
      exit 1
      ;;
    u)
      MONGODB_USER=$OPTARG
      ;;
    p)
      MONGODB_PASSWORD=$OPTARG
      ;;
    k)
      AWS_ACCESS_KEY=$OPTARG
      ;;
    s)
      AWS_SECRET_KEY=$OPTARG
      ;;
    r)
      S3_REGION=$OPTARG
      ;;
    b)
      S3_BUCKET=$OPTARG
      ;;
    a)
      FOLDER_NAME=$OPTARG
      ;;
    f)
      FILE_NAME_PREFIX=$OPTARG
      ;;
    ?)
      usage
      exit
    ;;
  esac
done

if [[ -z $AWS_ACCESS_KEY ]] || [[ -z $AWS_SECRET_KEY ]] || [[ -z $S3_REGION ]] || [[ -z $S3_BUCKET ]] || [[ -z $FOLDER_NAME ]]
then
  usage
  exit 1
fi

# Get the directory the script is being run from
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo $DIR
# Store the current date in YYYY-mm-DD-HHMM
DATE=$(date -u "+%F-%H%M")
FILE_NAME="$FILE_NAME_PREFIX$DATE"
ARCHIVE_NAME="$FILE_NAME.tgz"


# Dump the database
if [[ -z $MONGODB_USER ]] || [[ -z $MONGODB_PASSWORD ]]
then
    mongodump --out $DIR/backup/$FILE_NAME
else
    mongodump -username "$MONGODB_USER" -password "$MONGODB_PASSWORD" --out $DIR/backup/$FILE_NAME
fi

# Tar Gzip the file
tar -C $DIR/backup/ -zcvf $DIR/backup/$ARCHIVE_NAME $FILE_NAME/

# Remove the backup directory
rm -r $DIR/backup/$FILE_NAME

# Send the file to the backup drive or S3

dateValue=`date -R`
stringToSign="PUT\n\napplication/tar+gzip\n${dateValue}\n/$S3_BUCKET/$FOLDER_NAME/$ARCHIVE_NAME"
signature=`echo -en ${stringToSign} | openssl sha1 -hmac $AWS_SECRET_KEY -binary | base64`

curl -X PUT -T "$DIR/backup/$ARCHIVE_NAME" \
  -H "Host: $S3_BUCKET.s3.amazonaws.com" \
  -H "Date: ${dateValue}" \
  -H "Content-Type: application/tar+gzip" \
  -H "Authorization: AWS $AWS_ACCESS_KEY:${signature}" \
  https://$S3_BUCKET.s3.amazonaws.com/$FOLDER_NAME/$ARCHIVE_NAME



# export AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY"
# export AWS_SECRET_ACCESS_KEY="$AWS_SECRET_KEY"

# /usr/bin/aws s3 cp $DIR/backup/$ARCHIVE_NAME s3://$S3_BUCKET/$FOLDER_NAME/$ARCHIVE_NAME --content-type application/tar+gzip

rm $DIR/backup/$ARCHIVE_NAME
