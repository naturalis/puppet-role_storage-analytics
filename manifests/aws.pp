#_gsuite == Class: role_infra_analytics::aws
#
# Manifest for installing additional support software for gathering storage_analytics from aws repositories
# 
# === Authors
#
# Author Name <hugo.vanduijn@naturalis.nl>
#
#
class role_storage_analytics::aws (
# script general settings
  $scriptdir               = '/opt/awsrestic',
  $json_output_file        = '/var/log/storage-analytics-aws.json',

# repo containing backup-sets
  $ansible_restic_repodir  = '/opt/ansible-manage-restic-keys',
  $ansible_restic_repo     = 'https://github.com/naturalis/ansible-manage-restic-keys',
  $ansible_restic_repofile = 'backup_sets',

# variables for generated json
  $data_id                 = '',
  $data_status             = 'production',
  $data_host               = '',
  $storage_type            = 'backup',
  $storage_location        = 'AWS',
  $storage_pool            = '',

# Aws variables
  $aws_default_region      = 'eu-central-1',
  $aws_access_key_id,
  $aws_secret_access_key,

# cron settings
  $cronminute           = '0',
  $cronhour             = '2',
  $cronweekday          = '*',
)
{

# install required packages
  ensure_packages(['awscli','jq', 'bc'], {'ensure' => 'present'})

# create scriptdir and script
  file { $role_storage_analytics::aws::scriptdir:
    ensure        => 'directory',
  }->
  file {"${role_storage_analytics::aws::scriptdir}/get-bucket-size.sh":
    ensure  => present,
    content => template('role_storage_analytics/get-bucket-size.sh.erb'),
    mode    => '0700',
  }

# create cronjob
  cron { 'awsstats':
    command       => "cd ${role_storage_analytics::aws::scriptdir} && ./get-bucket-size.sh.erb",
    user          => 'root',
    minute        => $role_storage_analytics::aws::cronminute,
    hour          => $role_storage_analytics::aws::cronhour,
    weekday       => $role_storage_analytics::aws::cronweekday,
  }

}
