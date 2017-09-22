BEGIN {delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV', 'PATH'};}

use strict;
#use CGI;#in startup.pl
#use DBI;
#use AppConfig qw(:expand :argcount);
use URI::Encode qw(uri_encode uri_decode);
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
#		page called by ajax to modify varint status or allele


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
my $technique = U2_modules::U2_subs_1::check_analysis($q, $dbh, 'basic');

#get id for li at the end
my $j;
if ($q->param('j') && $q->param('j') =~ /(\d+)/o) {$j = $1}
my $cdna = U2_modules::U2_subs_1::check_nom_c($q, $dbh);
my $step = U2_modules::U2_subs_1::check_step($q);


if ($step == 1) { #insert form
	my $query = "SELECT statut, allele FROM variant2patient WHERE id_pat = '$id' AND num_pat = '$number' AND type_analyse = '$technique' AND nom_gene[1] = '$gene' AND nom_c = '$cdna';";
	my $res = $dbh->selectrow_hashref($query);
	my ($status, $allele) = ($res->{'statut'}, $res->{'allele'});
	print $q->p({'class' => 'title'}, "$id$number $gene $cdna");	
	my @status = ('heterozygous', 'homozygous', 'hemizygous');
	my @alleles = ('unknown', 'both', '1', '2');
	my $js = "if (\$(\"#status_modify\").val() === 'homozygous') {\$(\"#allele_modify\").val('both')}else {\$(\"#allele_modify\").val('unknown')}";
	print $q->start_form({'action' => '', 'method' => 'post', 'class' => 'u2form', 'id' => 'modify_form', 'enctype' => &CGI::URL_ENCODED}),
				$q->input({'type' => 'hidden', 'name' => 'sample', 'value' => $id.$number, 'id' => 'sample', 'form' => 'modify_form'}), "\n",
				$q->input({'type' => 'hidden', 'name' => 'gene', 'value' => $gene, 'id' => 'gene', 'form' => 'modify_form'}), "\n",
				$q->input({'type' => 'hidden', 'name' => 'technique', 'value' => $technique, 'id' => 'technique', 'form' => 'modify_form'}), "\n",
				$q->input({'type' => 'hidden', 'name' => 'nom_c', 'value' => uri_encode($cdna), 'id' => 'nom_c', 'form' => 'modify_form'}), "\n",
				$q->input({'type' => 'hidden', 'name' => 'j', 'value' => $j, 'id' => 'j', 'form' => 'modify_form'}), "\n",
				$q->start_fieldset(),
					$q->legend("Choose the correct values below:"), $q->start_ol(), $q->br(), $q->br(), "\n",
						$q->start_li(), "\n",
							$q->label({'for' => 'status'}, 'Status:'), "\n",
							$q->popup_menu(-name => 'status_modify', -id => 'status_modify', -values => \@status, -onchange => $js, -default => $status, required => 'required'), "\n",
						$q->end_li(), $q->br(), $q->br(), "\n",
						$q->start_li(), "\n",
							$q->label({'for' => 'allele'}, 'Allele:'), "\n",
							$q->popup_menu(-name => 'allele_modify', -id => 'allele_modify', -values => \@alleles, -default => $allele, required => 'required'), "\n",
						$q->end_li(), "\n",		
						$q->end_ol(), $q->end_fieldset(), $q->end_form();
}
elsif ($step == 2) {

	my $status = U2_modules::U2_subs_1::check_status_modify($q);
	my $allele = U2_modules::U2_subs_1::check_allele_modify($q);
	#my $update = "UPDATE variant2patient SET statut = '$status', allele = '$allele' WHERE nom_c = '$cdna' AND id_pat = '$id' AND num_pat = '$number' AND type_analyse = '$technique';";
	#changed 05/12/2015 Update of allele and status must be done whatever the analysis - add also the gene to avoid changing anothe variant in another gene with the same name
	my $update = "UPDATE variant2patient SET statut = '$status', allele = '$allele' WHERE nom_c = '$cdna' AND id_pat = '$id' AND num_pat = '$number' AND nom_gene[1] = '$gene';";
	$dbh->do($update) or die "Error when updating the analysis, there must be a mistake somewhere $!";
	#print "$status, allele: $allele, class: ";
	print "$status-$allele";
}


