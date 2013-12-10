# == Class: postgresql_server
#
# Full description of class postgresql_server here.
#
# === Parameters
#
# Document parameters here.
#
# [*sample_parameter*]
#   Explanation of what this parameter affects and what it defaults to.
#   e.g. "Specify one or more upstream ntp servers as an array."
#
# === Variables
#
# Here you should define a list of variables that this module would require.
#
# [*sample_variable*]
#   Explanation of how this variable affects the funtion of this class and if
#   it has a default. e.g. "The parameter enc_ntp_servers must be set by the
#   External Node Classifier as a comma separated list of hostnames." (Note,
#   global variables should be avoided in favor of class parameters as
#   of Puppet 2.6.)
#
# === Examples
#
#  class { postgresql_server:
#  servers => [ 'pool.ntp.org', 'ntp.local.company.com' ],
#  }
#
# === Authors
#
# Author Name <author@domain.com>
#
# === Copyright
#
# Copyright 2013 Your name here, unless otherwise noted.
#
class cspace_postgresql_server {


  # ---------------------------------------------------------
  # Download PostgreSQL
  # (EnterpriseDB installer)
  # ---------------------------------------------------------
  
  
  # ---------------------------------------------------------
  # Install PostgreSQL
  # (EnterpriseDB installer, unattended mode)
  # ---------------------------------------------------------
  
  
  # Commented-out fragments for possible use in this module:
  
  # ./ppasmeta-9.2.x.x-linux.run --mode unattended 
  #   --superpassword database_superuser_password 
  #   --webusername edb_user_name@email.com 
  #   --webpassword edb_user_password
    
  # package { 'postgresql':
  #   ensure  => present,
  #   name  => 'postgresql-9.1',
  # }
  
  # class { 'postgresql::server':
  #   ipv4acls           => [
  #                   'host all postgres samehost ident',
  #                   'host nuxeo nuxeo samehost md5',
  #                   'host nuxeo reader samehost md5',
  #                   'host cspace cspace samehost md5',
  #                 ],
  # }

  # This 'include file' ought to go somewhere PostgreSQL-relevant
  # and/or we should edit PostgreSQL params directly

  $includefile = '/tmp/postgresql_include.conf'

  # file { $includefile:
  #   content => 'max_connections = 64',
  #   notify  => Class['postgresql::server::service'],
  # }
  # ->
  # postgresql::server::config_entry { 'include':
  #   value   => $includefile,
  # }

}



