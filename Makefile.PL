#!/usr/bin/env perl
# IMPORTANT: if you delete this file your app will not work as
# expected.  You have been warned.
use inc::Module::Install;

name 'TvCube3';
all_from 'lib/TvCube3.pm';

requires 'DateTime';
requires 'YAML';
requires 'App::Daemon';
requires 'Net::Telnet';
requires 'Schedule::Cron';
test_requires 'Test::More' => '0.88';

install_script glob('script/*.pl');
auto_install;
WriteAll;
