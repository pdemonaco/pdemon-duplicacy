# duplicacy

[![CI](https://github.com/pdemonaco/pdemon-duplicacy/actions/workflows/50_pdk.yml/badge.svg?branch=master)](https://github.com/pdemonaco/pdemon-duplicacy/actions/workflows/50_pdk.yml)

#### Table of Contents

1. [Description](#description)
2. [Setup - The basics of getting started with duplicacy](#setup)
    * [What duplicacy affects](#what-duplicacy-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with duplicacy](#beginning-with-duplicacy)
3. [Usage - Configuration options and additional functionality](#usage)
4. [Limitations - OS compatibility, etc.](#limitations)
5. [Development - Guide for contributing to the module](#development)

## Description

The duplicacy module installs, configures, and manages duplicacy backups. [Duplicacy](https://duplicacy.com/) is backup application written by Gilbert Chen which supports a wide variety of storage backends.

## Setup

### What duplicacy affects

This module impacts three main areas:

#### 1 - Packages

By default, an attempt will be made to install the duplicacy package and a simple smtp client `mutt`. These parameters should be defaulted in via the module's hiera data, however, this only applies to supported OSs. See [limitations](#limitations) for detail.

#### 2 - Crontab Entries

If a backup schedule or prune schedule is configured this will result in the creation of crontab entries for either `root` or the user specified for the target repository.

#### 3 - Configuration

Each repository you define and include on a machine via `duplicacy::local_repos` will result in the creation of a `.duplicacy` folder within the repo_path for that repository. The repository will be initialized to the provided `default` storage target and a series of scripts will be created within that `.duplicacy/puppet/`.

In addition to scripts, that directory will contain a few useful files

* `.duplicacy/puppet/locks` - whenever a job is executing for this repository against a storage backend it will create a lock file matching that repo.
* `.duplicacy/puppet/logs` - contains log files for each job run against this repository. By default these are retained for 5 weeks
* `.duplicacy/puppet/scripts` - contains an environment file for each storage defined against this repository as well as a backup/prune script for each scheduled job

### Setup Requirements

A few outside setup requirements currently exist:

1. Ensure you have working smtp if you'd like email notifications.
2. If you're running on Gentoo you can use my overlay to install Duplicacy, otherwise, you'll need to get duplicacy installed via some other means.
3. I **STRONGLY** recommend that you use encrypted yaml files for managing these configs. Otherwise, your puppet manifest will contain passwords in plain text! See the [hiera-eyaml](https://github.com/voxpupuli/hiera-eyaml) project for more detail.

### Beginning with duplicacy

Configuration can be done directly in your manifest or via hiera. I'd recommend the latter as it allows a cleaner setup of backups on many nodes. The following example details a simple setup directly in a manifest:

```puppet
duplicacy {
  local_repos          => [ 'root-home' ],
  repos                => {
    root-home          => {
      repo_path        => '/root',
      user             => 'root',
      storage_targets  => {
        default        => {
          target       => {
            url        => 'b2://pdemon-duplicacy-test',
            b2_id      => 'my-b2-id-is-a-secret',
            b2_app_key => 'this is my key'
          },
          encryption => {
            password => 'my-secret-password'
          },
        },
      },
      backup_schedules => {
        hourly => {
          storage_name => 'default',
          cron_entry   => {
            'minute'   => '30',
          },
          'threads'         => 4,
          'email_recipient' => phil@demona.co,
        },
      },
      prune_schedules  => {
        '7d-8w' => {
          schedules   => {
            daily-prune => {
              cron_entry   => {
                hour       => '0',
              },
            },
          },
          keep_ranges => {
            { interval => 0, max_age  => 90 },
            { interval => 7, max_age  => 30 },
            { interval => 1, max_age  => 7 },
          },
          threads         => 6,
          email_recipient => 'phil@demona.co',
        },
      },
    },
  },
}
```

## Usage

As mentioned above, I'd recommend performing this configuration primarily via hiera.

### Root Home Example

In this example each machine will create a unique repository ID for it's home directory and back it up to the same storage repository. First, the following statement is added to a base profile which is applied to all machines.

```puppet
class { 'duplicacy': }
```

The repository is configured via this hash below:

```yaml
---
# Define the repository
duplicacy::repos:
  "root-home_%{trusted.certname}":
    repo_path: '/root'
    user: 'root'
    storage_targets:
      default:
        target:
          url: 'b2://my-b2-bucket-id'
          b2_id: DEC(9)::PKCS7[backblaze-id]!
          b2_app_key: DEC(11)::PKCS7[app-key-for-this-bucket]!
        encryption:
          password: DEC(13)::PKCS7[encryption password]!
    backup_schedules:
      daily-0200:
        storage_name: 'default'
        cron_entry:
          minute: '0'
          hour: '2'
        threads: 4
        hash: true
    prune_schedules:
      7d-9w:
        schedules:
          daily_prune:
            cron_entry:
              minute: '0'
              hour: '0'
        keep_ranges:
          - interval: 0 
            min_age: 365
          - interval: 30
            min_age: 180
          - interval: 7
            min_age: 30
          - interval: 1
            min_age: 7
        threads: 4
```

With that statement in place, a directive is added to all of the target
machines to cause the repo to be instantiated.

```yaml
---
# Add it to the local management list
duplicacy::local_repos:
  - "root-home_%{trusted.certname}"
```

## Limitations

Testing has been limited at this point. A few call-outs worth noting:

* There is no official ebuild for duplicacy. I have a binary distribution based ebuild on my [personal overlay](https://github.com/pdemonaco/overlay/tree/master/app-backup/duplicacy-bin).
* This module is currently limited to the b2 backend.
* I've only tested this on my personal home environment using the b2 (Backblaze) backend. As of this writing this consists entirely of Gentoo machines running duplicacy 2.1.1.
* Currently it assumes your machine is capable of sending outbound mail. I'm planning to build a separate module for managing a simple smtp engine in the future.
* Unfortunately, at the moment this module stores passwords and storage credentials in an unencrypted form within each repository on the client machines. I plan to address this limitation in the future.

## Development

If you'd like to make changes submit a pull request! Here's a few basic ground rules:

* Ensure that your changes pass the PDK validation and unit tests before submitting.
* When adding new functionality expand the existing test cases as necessary to ensure your code is covered.

## Contributors

Check out the [contributor list](https://gitlab.com/pdemon/pdemon-duplicacy/graphs/master).
