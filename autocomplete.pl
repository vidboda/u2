BEGIN {delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV', 'PATH'};}

use strict;
#use CGI;#in startup.pl
#use DBI;
#use AppConfig qw(:expand :argcount);
#use URI::Encode qw(uri_encode uri_decode);
use JSON;
#use LWP::UserAgent;
#use SOAP::Lite;
#use Data::Dumper;

use U2_modules::U2_users_1;
use U2_modules::U2_init_1;
use U2_modules::U2_subs_1;

#    This program is part of ushvam2, USHer VAriant Manager version 2
#    Copyright (C) 2012-2016  David Baux
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU Affero General Public License as
#    published by the Free Software Foundation, either version 3 of the
#    License, or any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU Affero General Public License for more details.
#
#    You should have received a copy of the GNU Affero General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#
#		page called by ajax to autocomplete search engine with last names


## Minimal init of USHVaM 2 perl scripts: script called by AJAX, minimal init
#	env variables
#	get MINIMAL config infos
#	initialize DB connection

$CGI::POST_MAX = 1024; #* 100;  # max 1K posts
$CGI::DISABLE_UPLOADS = 1;

my $config_file = U2_modules::U2_init_1->getConfFile();
my $config = U2_modules::U2_init_1->initConfig();
$config->file($config_file);# or die $!;
my $DB = $config->DB();
my $HOST = $config->HOST();
my $DB_USER = $config->DB_USER();
my $DB_PASSWORD = $config->DB_PASSWORD();
my $HTDOCS_PATH = $config->HTDOCS_PATH();


my $q = new CGI;

my $dbh = DBI->connect(    "DBI:Pg:database=$DB;host=$HOST;",
                        $DB_USER,
                        $DB_PASSWORD,
                        {'RaiseError' => 1}
                ) or die $DBI::errstr;


my $user = U2_modules::U2_users_1->new();

print $q->header();

##end of Minimal init

my $return->{'suggestions'} = [];
#gene and patient names
if ($q->param('query') =~ /^([\w\s]+)$/o) {
	my $search = $1;
	#if ($search =~ /^\d+$/o) {
	#	my $query = "SELECT DISTINCT(nom) FROM variant WHERE nom LIKE '%$search%' ORDER BY nom;";
	#	my $sth = $dbh->prepare($query);
	#	my $res = $sth->execute();
	#	if ($res) {
	#		$return = &variant($sth);
	#		#my $i = 0;
	#		#while (my $result = $sth->fetchrow_hashref()) {
	#		#	$return->{'suggestions'}[$i] = $result->{'nom'};
	#		#	$i++;
	#		#}
	#	}
	#}
	#else {
	my $i = 0;
	if ($user->isPublic() != 1) {
		my $query = "SELECT DISTINCT(last_name) FROM patient WHERE last_name LIKE '%".uc($search)."%' ORDER BY last_name;";
		my $sth = $dbh->prepare($query);
		my $res = $sth->execute();
		#$return->{'suggestions'} = [];

		if ($res) {
			while (my $result = $sth->fetchrow_hashref()) {
				my $answer = $result->{'last_name'};
				if ($result->{'last_name'} =~ /(\w+)\s*\(*[Nn]&eacute;e.+/o) {$answer = $1}
				elsif ($result->{'last_name'} =~ /(\w+)\s\(*ep\..+/o) {$answer = $1}
				$return->{'suggestions'}[$i] = $answer;
				$i++;
			}
		}
	}
  if ($search !~ /[cC]\do/o) {$search = uc($search)}
  else {$search = ucfirst($search)}
	my $query = "SELECT DISTINCT(nom[1]) FROM gene WHERE nom[1] LIKE '%".$search."%' OR second_name LIKE '%".$search."%' ORDER BY nom[1];";
	my $sth = $dbh->prepare($query);
	my $res = $sth->execute();
	if ($res) {
		#my $i = 0;
		while (my $result = $sth->fetchrow_hashref()) {
			$return->{'suggestions'}[$i] = $result->{'nom'};
			$i++;
		}
	}
  # else {
  #   $query = "SELECT DISTINCT(nom[1]) FROM gene WHERE second_name LIKE '%".uc($search)."%' ORDER BY nom[1];";
  #   my $sth = $dbh->prepare($query);
  #   my $res = $sth->execute();
  #   if ($res) {
  #     while (my $result = $sth->fetchrow_hashref()) {
  #       $return->{'suggestions'}[$i] = $result->{'nom'};
  # 			$i++;
  # 		}
  #   }
  # }
	#}
}#variants
#elsif ($q->param('query') =~ /([c\.\+->_\?\(\)\*]+)/o) {
#	my $query = "SELECT DISTINCT(nom) FROM variant WHERE nom LIKE '$1%' ORDER BY nom;";
#	my $sth = $dbh->prepare($query);
#	my $res = $sth->execute();
#	if ($res) {
#		$return = &variant($sth);
#		#my $i = 0;
#		#while (my $result = $sth->fetchrow_hashref()) {
#		#	$return->{'suggestions'}[$i] = $result->{'nom'};
#		#	$i++;
#		#}
#	}
#}


print encode_json U2_modules::U2_subs_1::html2accent($return);

exit;


sub variant {
	my ($sth) = shift;
	my $i = 0;
	while (my $result = $sth->fetchrow_hashref()) {
		$return->{'suggestions'}[$i] = $result->{'nom'};
		$i++;
	}
	return $return;
}
