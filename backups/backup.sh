#!/bin/bash

# Inspired by: https://github.com/render-examples/postgres-s3-backups/blob/19259a6c2d32b65b7f928b58b9f45a63f5874d14/backup.sh

set -o errexit -o nounset -o pipefail

export AWS_PAGER=""

s3() {
    aws s3 --region "$AWS_REGION" "$@"
}

s3api() {
    aws s3api "$1" --region "$AWS_REGION" --bucket "$S3_BUCKET_NAME" "${@:2}"
}

bucket_exists() {
    s3 ls "$S3_BUCKET_NAME" &> /dev/null
}

create_bucket() {
    echo "Bucket $S3_BUCKET_NAME doesn't exist. Creating it now..."

    # create bucket
    s3api create-bucket \
        --create-bucket-configuration LocationConstraint="$AWS_REGION" \
        --object-ownership BucketOwnerEnforced

    # block public access
    s3api put-public-access-block \
        --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

    # enable versioning for objects in the bucket
    s3api put-bucket-versioning --versioning-configuration Status=Enabled

    # encrypt objects in the bucket
    s3api put-bucket-encryption \
      --server-side-encryption-configuration \
      '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'
}

ensure_bucket_exists() {
    if bucket_exists; then
        return
    fi
    create_bucket
}

mysqldump_database() {
    mysqldump \
        -h $MYSQL_HOST \
        -u $MYSQL_USER \
        --password=$MYSQL_PASSWORD \
        --single-transaction --no-tablespaces \
        --databases "$MYSQL_DATABASE"
}

upload_to_bucket() {
    # if the zipped backup file is larger than 50 GB add the --expected-size option
    # see https://docs.aws.amazon.com/cli/latest/reference/s3/cp.html
    s3 cp - "s3://$S3_BUCKET_NAME/$(date +%Y/%m/%d/backup-%H-%M-%S.sql.gz)"
}

main() {
    ensure_bucket_exists
    echo "Taking backup and uploading it to S3..."
    mysqldump_database | gzip | upload_to_bucket
    echo "Done."
}

main
