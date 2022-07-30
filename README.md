# Example code for deploying WordPress on Render _beta_

This was copied from the following guides:
* https://render.com/docs/deploy-wordpress
* https://render.com/docs/backup-postgresql-to-s3

It’s a work in progress. 🚧

---

This is a template repository for running [Wordpress](https://wordpress.org) on Render.

It uses the official [MySQL](https://hub.docker.com/_/mysql) and [Wordpress](https://hub.docker.com/_/wordpress/) Docker images, along with Render’s [Web Services](https://render.com/docs/web-services), [Private Services](https://render.com/docs/private-services), and [Disks](https://render.com/docs/disks).

In this guide:

* [Deployment](#deployment)
* [Connecting to your database](#connecting-to-your-database)
* [MySQL Versions](#mysql-versions)
* [Backups](#backups)
  * [Create AWS Credentials](#create-aws-credentials)
  * [Configure the Backup Cron Job](#configure-the-backup-cron-job)
  * [Validate the Cron Job](#validate-the-cron-job)
  * [Recover your database from a backup](#recover-your-database-from-a-backup)
  * [Troubleshooting](#troubleshooting)

---

## Deployment

1. [Use this template](https://github.com/jimthoburn/wordpress/generate) to generate a new repository for WordPress in your GitHub account.

1. Change the name of the default branch in your repository. For example: `main`

1. Make any changes you wish to your copy of the Dockerfile(s) or [render.yaml](render.yaml). For example, you may want to change the [region](https://render.com/docs/regions) and replace `myappname` with the name of your application.

1. [Deploy your repository](https://dashboard.render.com/select-repo?type=blueprint) to Render as a [Blueprint](https://render.com/docs/infrastructure-as-code).

[![Deploy to Render](https://render.com/images/deploy-to-render-button.svg)](https://dashboard.render.com/select-repo?type=blueprint)

<br />

<info-block>

As part of the deployment process, you’ll be prompted for an Amazon Web Services (AWS) account,<br />
for storing [database backups](#backups).

</info-block>

<br />

| Environment variable      |  Value                           |
| ------------------------- | ---------------------------------|
| **AWS_REGION**            | Choose the [AWS region](https://docs.aws.amazon.com/general/latest/gr/s3.html) closest to the [region of your database](https://render.com/docs/regions). For example, a MySQL instance in Render's Oregon region would use `us-west-2` for the AWS Region US West (Oregon). |
| **S3_BUCKET_NAME**        | Choose a globally unique name for your bucket. For example `<my-amazon-username>-<my-app-name>-render-mysql-backups`. The name must follow [Bucket naming rules](https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucketnamingrules.html). |
| **AWS_ACCESS_KEY_ID**     | Enter the `Access key ID` (`AKIAXXXXXXXXXXXXXXXX`) for a [new user](#create-aws-credentials) in your Amazon Web Services account. |
| **AWS_SECRET_ACCESS_KEY** | Enter the secret access key for a [new user](#create-aws-credentials) in your Amazon Web Services account.|

<br />

After deploying, MySQL and WordPress will take a few minutes to start.

Your WordPress instance will be available on your `.onrender.com` URL as soon as the deploy is live.

WordPress may fail to deploy on the first try. You can use the “Manual Deploy” button in the [Render Dashboard](https://dashboard.render.com/) to deploy again. The second try usually succeeds.

You can then configure WordPress by going to `https://your-subdomain.onrender.com`.

See the official guide on Render, for more tips:
https://render.com/docs/deploy-wordpress

## Domains

Render supports custom domains:
https://render.com/docs/custom-domains

If you add a custom domain, you may also want to change the domain on the settings page of your WordPress Admin Dashboard.

## Transferring files to WordPress

You can [transfer files](https://render.com/docs/disks#transferring-files) to and from your WordPress Web Service.

## Connecting to your database

You can connect to MySQL from other applications running in your Render account using the name and port for your Private Service. For example, you can a create a Web Service to manage your MySQL database using [Adminer](https://www.adminer.org/). See Render’s [Adminer Deployment Guide](https://render.com/docs/deploy-adminer) for details.

You can also use [SSH](https://render.com/docs/ssh) or the shell in your [Render Dashboard](https://dashboard.render.com/) to connect to your database.

Learn more about [connecting to MySQL](https://dev.mysql.com/doc/refman/8.0/en/connectors-apis.html).

<br />

```shell{outputLines: 2-100}
mysql -h localhost -D $MYSQL_DATABASE -u $MYSQL_USER --password=$MYSQL_PASSWORD

mysql: [Warning] Using a password on the command line interface can be insecure.
Reading table information for completion of table and column names
You can turn off this feature to get a quicker startup with -A

Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 92
Server version: 8.0.29 MySQL Community Server - GPL

Copyright (c) 2000, 2021, Oracle and/or its affiliates. All rights reserved.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

mysql>
```

## MySQL Versions

The included mysql [Dockerfile](mysql/Dockerfile) runs **MySQL 8**. You can change this to a different version, by editing your copy of the [Dockerfile](mysql/Dockerfile).

## Backups

<warning-block>

Relying on a [disk snapshot](https://render.com/docs/disks/#disk-snapshots) to restore a database is not recommended. Restoring a disk snapshot will likely result in corrupted or lost database data.

</warning-block>

Using a database’s recommended backup tool (for example: [mysqldump](https://dev.mysql.com/doc/refman/8.0/en/mysqldump.html)) is the recommended way to backup and restore a database without corrupted or lost data.

This repository includes a [Cron Job](https://render.com/docs/cronjobs) for backing up your MySQL database to Amazon S3. To use this, you will need an Amazon Web Services (AWS) account.

It’s a good idea to make a full backup of your WordPress files too:
https://jetpack.com/blog/how-to-back-up-your-wordpress-site/

### Create AWS Credentials

You can follow these steps to create credentials with AWS IAM, to enable working with Amazon S3.

1. Open the [AWS console](https://aws.amazon.com/) and navigate to the IAM service. Open the Users view and select the `Add Users` button.

1. Enter a descriptive username, such as `<database name>-render-mysql-backup-cron`.

1. For `Select AWS credential type*` select `Access key - Programmatic access`.

1. Select the `Next: Permissions` button to move to the `Set Permissions` view.

1. In the `Set Permissions` view, select `Attach existing policies directly` and search for `AmazonS3FullAccess`. Check the box to select `AmazonS3FullAccess`.

   <info-block>
   It's possible to use finer-grained policies to authorize the Cron Job. Render recommends <a href="https://litestream.io/guides/s3/#restrictive-iam-policy">Litestream's guide</a> if you'd like to further lock down permissions.
   </info-block>

1. Skip through the next two views with the `Next` buttons to move to the `Review` view. Confirm the details of your user.

1. Select the `Create User` button.

1. Record the access key ID  (`AKIAXXXXXXXXXXXXXXXX`) and the secret access key.

### Configure the Backup Cron Job

By default, the Cron Job will run the backup daily at 3 a.m. UTC. You can change the time and frequency by modifying the Cron Job's `schedule` in your copy of the [render.yaml](render.yaml) file.

### Validate the Cron Job

1. View the newly created Cron Job and wait for the first build to finish.

1. Select the `Trigger Run` button and wait for the job to finish with a `Cron job succeeded` event.

1. Verify the backup by inspecting the contents of [your S3 bucket](https://aws.amazon.com/).

### Recover your database from a backup

1. Download the required `.sql.gz` file from [your S3 bucket](https://aws.amazon.com/).

1. Unzip the backup file.<br />
   _Replace `backup-file.sql.gz` with the name of your backup file._

   ```shell
   gzip -d backup-file.sql.gz
   ```

1. Connect to your MySQL service with [SSH](https://render.com/docs/ssh) or the shell in your [Render Dashboard](https://dashboard.render.com/).

   <info-block>

   If your MySQL service is offline and can’t be restarted, you may need to [deploy a new MySQL service](https://render.com/docs/deploy-mysql) and restore your database there instead.

   </info-block>

1. [Transfer the backup file](https://render.com/docs/disks#transferring-files) to your MySQL service.

1. Use your backup file with the [MySQL Command-Line Client](https://dev.mysql.com/doc/refman/8.0/en/mysql.html).

Here’s an example command that will connect to your database and run the SQL statements in your backup file.<br /> _Replace `backup-file.sql` with the name of your backup file._

```shell{outputLines: 2-6}
mysql \
  -h localhost \
  -u $MYSQL_USER \
  --password=$MYSQL_PASSWORD \
  $MYSQL_DATABASE \
  < backup-file.sql
```

### Troubleshooting

###### Large Databases

The `aws` CLI tool requires additional configuration when uploading large files to S3. If your compressed backup file exceeds 50 GB, add an `--expected-size` flag in the the `upload_to_bucket` function in `backup.sh`.

###### Credential Errors

You may have an error with your IAM user if your Cron Job fails and you see an error message similar to:

```
An error occurred (SignatureDoesNotMatch) when calling the CreateBucket operation:
The request signature we calculated does not match the signature you provided.
Check your key and signing method.
```

Check over the [Create AWS Credentials](#create-aws-credentials) instructions.
