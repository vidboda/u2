BEGIN {delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV', 'PATH'};}

use strict;
#use CGI;#in startup.pl
#use DBI;
#use AppConfig qw(:expand :argcount);
use URI::Encode qw(uri_encode uri_decode);
use LWP::UserAgent;
use SOAP::Lite;
use Data::Dumper;

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
#		page called by ajax to validate/delete analyses


## Minimal init of USHVaM 2 perl scripts: script called by AJAX, minimal init
#	env variables
#	get MINIMAL config infos
#	initialize DB connection
#	identify users

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


##end of Minimal init


#get params

my ($id, $number) = U2_modules::U2_subs_1::sample2idnum(uc($q->param('sample')), $q);
my ($gene, $second_name) = U2_modules::U2_subs_1::check_gene($q, $dbh);
my $date = U2_modules::U2_subs_1::get_date();
my $analysis = U2_modules::U2_subs_1::check_analysis($q, $dbh, 'basic');
my $type;
if ($q->param('type') =~ /(technical_valid|negatif|positif|valide)/o) {$type = $1}



if ($user->isAnalyst() == 1 && $type ne '' && $type ne 'valide') {#technical validation & result
	my $value = 't';
	if ($type eq 'negatif') {$value = 'f'}
	if ($type eq 'positif' || $type eq 'negatif') {$type = 'result'}
	my $query = "UPDATE analyse_moleculaire SET $type = '$value' WHERE num_pat = '$number' AND id_pat = '$id' AND nom_gene[1] = '$gene' AND type_analyse = '$analysis';";
	$dbh->do($query);
	if ($type eq 'result') {
		$query = "UPDATE analyse_moleculaire SET date_result = '$date', referee = '".$user->getName()."' WHERE num_pat = '$number' AND id_pat = '$id' AND nom_gene[1] = '$gene' AND type_analyse = '$analysis';";
		$dbh->do($query);
	}
	
	#print $query;
	#en ternaire
	($value eq 'f') ? print '-':print '+';
	#if ($value == 'f') {print '-'}
	#else {print '+'}
}
elsif ($user->isValidator() == 1 && $type eq 'valide') {
	my $query = "UPDATE analyse_moleculaire SET $type = 't', validateur = '".$user->getName()."', date_valid = '$date' WHERE num_pat = '$number' AND id_pat = '$id' AND nom_gene[1] = '$gene' AND type_analyse = '$analysis';";
	$dbh->do($query);
	print '+';
}
elsif ($user->isAnalyst() == 1 && $q->param('delete') == 1) {#delete analysis
	if ($analysis ne 'aCGH') {
		&delete_analysis($number, $id, $gene, $analysis, $dbh);
		#my $query = "DELETE FROM analyse_moleculaire WHERE num_pat = '$number' AND id_pat = '$id' AND type_analyse = '$analysis' AND nom_gene[1] = '$gene';";
		#$dbh->do($query);
	}
	else {
		foreach (@U2_modules::U2_subs_1::ACGH) {
			&delete_analysis($number, $id, $_, $analysis, $dbh);
		}
	}
}




## specific subs for current script

sub delete_analysis {
	my ($number, $id, $gene, $analysis, $dbh) = @_;
	# get #acc for all isoforms;
	# print SDTERR "analyssi:$analysis\n";
	my $query = "DELETE FROM analyse_moleculaire WHERE num_pat = '$number' AND id_pat = '$id' AND type_analyse = '$analysis' AND nom_gene[1] = '$gene';";
	if ($analysis =~ /xome$/o) {
		$query = "DELETE FROM analyse_moleculaire WHERE num_pat = '$number' AND id_pat = '$id' AND type_analyse = '$analysis';";
	}
	
	#print $query;
	$dbh->do($query);
}


