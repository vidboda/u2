BEGIN {delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV', 'PATH'};}

use strict;
#use CGI;#in startup.pl
#use DBI;
use URI::Escape;
#use AppConfig qw(:expand :argcount);
use U2_modules::U2_users_1;
use U2_modules::U2_init_1;
use U2_modules::U2_subs_1;
use U2_modules::U2_subs_2;

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
#		This script implements the search engine of ushvam2 launched by HTML_DIR/fix_bot.html


##Specific init of USHVaM 2 perl scripts:use of redirect => no headers sent before!!! #pb with segmentation fault with the header in sub - try to pass it in the arguments list -see http://osdir.com/ml/modperl.perl.apache.org/2009-02/msg00063.html, create a main function
#	env variables
#	get config infos

$CGI::POST_MAX = 1024; #* 100;  # max 1K posts
$CGI::DISABLE_UPLOADS = 1;



my $config_file = U2_modules::U2_init_1->getConfFile();
my $config = U2_modules::U2_init_1->initConfig();
$config->file($config_file);# or die $!;
my $DB = $config->DB();
my $HOST = $config->HOST();
my $DB_USER = $config->DB_USER();
my $DB_PASSWORD = $config->DB_PASSWORD();
my $CSS_PATH = $config->CSS_PATH();
my $CSS_DEFAULT = $config->CSS_DEFAULT();
my $JS_PATH = $config->JS_PATH();
my $JS_DEFAULT = $config->JS_DEFAULT();
my $HTDOCS_PATH = $config->HTDOCS_PATH();
my $PERL_SCRIPTS_HOME = $config->PERL_SCRIPTS_HOME();
my $PATIENT_IDS = $config->PATIENT_IDS();
my $PATIENT_FAMILY_IDS = $config->PATIENT_FAMILY_IDS();

##End of Specific init

&main();

exit();



sub main {
	
	my @styles = ($CSS_PATH.'font-awesome.min.css', $CSS_PATH.'w3.css', $CSS_DEFAULT, $CSS_PATH.'fullsize/fullsize.css');
	
	my $q = new CGI;

	my $dbh = DBI->connect(    "DBI:Pg:database=$DB;host=$HOST;",
					$DB_USER,
					$DB_PASSWORD,
					{'RaiseError' => 1}
				) or die $DBI::errstr;
	
	my ($recherche, $motif, $query, $url, $original);
	
	my $user = U2_modules::U2_users_1->new();
	if ($user->isPublic()) {$q->redirect("engine_public.pl?search=".$q->param('search'));exit;}
	#print $q->header(-type => 'text/html', -'cache-control' => 'no-cache'),
	#	$q->start_html(
	#		-title=>"U2 search engine",
	#                -lang => 'en',
	#                -style => {-src => \@styles},
	#                -head => [
	#			$q->Link({-rel => 'icon',
	#				-type => 'image/gif',
	#				-href => $HTDOCS_PATH.'data/img/animated_favicon1.gif'}),
	#			$q->Link({-rel => 'search',
	#				-type => 'application/opensearchdescription+xml',
	#				-title => 'U2 search engine',
	#				-href => $HTDOCS_PATH.'u2browserengine.xml'}),
	#			$q->meta({-http_equiv => 'Cache-control',
	#				-content => 'no-cache'}),
	#			$q->meta({-http_equiv => 'Pragma',
	#				-content => 'no-cache'}),
	#			$q->meta({-http_equiv => 'Expires',
	#				-content => '0'})],
	#                -script => [{-language => 'javascript',
	#                        -src => $JS_PATH.'jquery-1.7.2.min.js'},
	#                        {-language => 'javascript',
	#                        -src => $JS_PATH.'jquery.fullsize.pack.js'},
	#			{-language => 'javascript',
	#                        -src => $JS_PATH.'jquery.validate.min.js'},
	#                        {-language => 'javascript',
	#                        -src => $JS_PATH.'DIV_SRC.js'},
	#                        {-language => 'javascript',
	#                        -src => $JS_DEFAULT}],		
	#		-encoding => 'ISO-8859-1');
	
	
	
	#U2_modules::U2_subs_1::standard_begin_html($q, $user->getName(), $dbh);
	
	
	
	my $keyword = &get_genes($dbh);
	
	$PATIENT_IDS =~ s/\(//og;
	$PATIENT_IDS =~ s/\)//og;
	my @ids = split(/\|/, $PATIENT_IDS);
	foreach(@ids) {$keyword->{$_."number"} = 'patientID';$keyword->{lc($_)."number"} = 'patientID';}
	
	$PATIENT_FAMILY_IDS =~ s/\(//og;
	$PATIENT_FAMILY_IDS =~ s/\)//og;
	@ids = split(/\|/, $PATIENT_FAMILY_IDS);
	foreach(@ids) {$keyword->{$_."number"} = 'familyID';$keyword->{lc($_)."number"} = 'familyID';}
	
	
	$keyword->{'c\.'} = 'DNA-nom';
	$keyword->{'g\.'} = 'DNA-nom_ng';
	$keyword->{'[Cc][Hh][Rr]'} = 'DNA-nom_g';
	$keyword->{'[Ii][Vv][Ss]'} = 'DNA-nom_ivs';
	$keyword->{'p\.'} = 'nom_prot';
	$keyword->{'[rR][sS]number'} = 'DNA-snp_id';
	$keyword->{'^Enumber-?\d*[delupins]*$'} = 'LR';
	$keyword->{'[Rr][Nn][Aa]'} = 'RNA';
	
	##TODO add analyse_moleculaire
	if ($q->param('search') && $q->param('search') =~ /([\w\.\>\-\+\(\)\*:\?_']+)/o) {
		$recherche = $1;
		$original = $recherche;
		foreach my $key (keys (%{$keyword})) {
			#print "$key -- $keyword->{$key} -- $recherche", $q->br();
			$key =~ s/number/\\d\+/o;		
			if ($recherche =~ /^$key/) {
				if ($keyword->{$key} =~ /gene/ && length($key) == length($recherche)) {#if a patient name includes a gene name
					$motif = $keyword->{$key};
					last;
				}
				elsif ($keyword->{$key} !~ /gene/) {
					#print "$key -- $keyword->{$key} -- $recherche";
					$key =~ s/\\d\+/number/o;					
					if ($keyword->{$key} =~ /ID/o) {						
						$key =~ s/number/\\d\+/o;
						#print "$key -- $keyword->{$key} -- $recherche";exit;
						if ($recherche =~ /^$key$/) {
							#print "$key -- $keyword->{$key} -- $recherche";
							$key =~ s/\\d\+/number/o;							
							$motif = $keyword->{$key};
							last;
						}
					}
					else {
						$motif = $keyword->{$key};
						last;
					}
				}
			}
		}
		#exit;
		#print $motif;
		#if ($motif ne '' && $motif !~ /DNA-/o && $motif ne 'nom_prot') {
		if ($motif eq 'LR') {
			$recherche =~ /E(\d+)-?(\d*)/o;
			if ($2) {
				$query = "SELECT * FROM variant WHERE taille > 100 AND (num_segment IN ($1, ".($1-1).") AND num_segment_end IN ($2, ".($2-1).")) AND (num_segment_end-num_segment = $2-$1);";
				#my $sth_nom_g = $dbh->prepare($query_nom_g);
				#my $res_nom_g = $sth_nom_g->execute();
			}
			else {
				$query = "SELECT * FROM variant WHERE taille > 100 AND (num_segment IN ($1, ".($1-1).") OR num_segment_end IN ($1, ".($1-1).")) AND (num_segment_end-num_segment > 0);";
			}
			&print_results($query, $motif, '2', $recherche, $q, $dbh, $url, \@styles, $user, $original);
			$query = '';
			#print $query;exit;
			#$motif = 'DNA-nom_g';
		}
		
		if ($motif =~ /gene/ || $motif eq 'patientID') {
			if ($motif eq 'gene_lc') {$recherche = uc($recherche)}
			$url = &build_link($motif, $recherche);
			$q->redirect("$url");
			exit;
		}
		elsif ($motif eq '') {#try to define a motif, then treat it afterwards
			if ($recherche =~ /\>/o) {$motif = 'DNA'}		
			elsif ($recherche =~ /^[\d_\?\+-]+[delupins]{3}/o) {$motif = 'DNA'}
			elsif ($recherche =~ /^\d+$/o) {$motif = 'multiple_number'}
			elsif ($recherche =~ /^\w{1,3}\d+[\w\*]{1,3}$/o) {$motif = 'nom_prot';$recherche = "p.$recherche";}
			elsif ($recherche =~ /^\w{1,3}[\d_]+[delupins]{3}/o) {$motif = 'nom_prot';$recherche = "p.$recherche";}
			elsif ($recherche =~ /^([A-Za-z\s-']+)$/o) {$motif = 'patient_name';$recherche = uc($recherche);}
			#print $recherche;
		}
				
		if ($motif =~ /DNA/o) {
			$recherche =~ s/[Cc][Hh][Rr]/chr/;
			$recherche =~ s/[Ii][Vv][Ss]/IVS/;
			$recherche =~ s/[rR][sS]/rs/;
			if ($recherche =~ /(.+[delup]{3})/o) {$recherche = $1}
			if ($motif eq 'DNA-nom_ivs' && $recherche =~ /X/o) {$recherche =~ s/\+/\\\+/o;$recherche =~ s/X/\\d+/o;$query = "SELECT  nom, nom_gene, nom_prot FROM variant WHERE nom_ivs ~ '".$recherche."[^\\d]+.+' ORDER BY nom_gene, nom_g;";$motif = '';}
		}
		if ($motif =~ /DNA-(.+)/o) {
			if ($1 eq 'nom_g') {$query = "SELECT nom, nom_gene, nom_prot FROM variant WHERE nom_g LIKE '$recherche%' OR nom_g_38 LIKE '$recherche%' ORDER BY nom_gene, nom_g;";}
			else {$query = "SELECT nom, nom_gene, nom_prot FROM variant WHERE $1 LIKE '$recherche%' ORDER BY nom_gene, nom_g;"};
		}
		elsif ($motif eq 'DNA') {
			$query = "SELECT nom, nom_gene, nom_prot FROM variant WHERE (nom LIKE '%$recherche%' OR nom_g LIKE '%$recherche%' OR nom_g_38 LIKE '%$recherche%' OR nom_ng LIKE '%$recherche%' OR nom_ivs LIKE '%$recherche%') ORDER BY nom_gene, nom_g;";
		}
		elsif ($motif eq 'RNA') {
			$query = "SELECT * FROM variant WHERE type_arn = 'altered' AND taille < '100' ORDER BY nom_gene[1], nom_g;"; # we keep false variants identified by 454 AND classe NOT IN ('pathogenic', 'VUCS class IV', 'VUCS class III');";
		}
		elsif ($motif eq 'nom_prot') {
			if ($recherche !~ /\(.+\)/o) {
				$recherche =~ s/p\.(.+)/p\.\($1\)/o;
			}
			$recherche =~ s/X/\*/o;
			$recherche =~ s/x/\*/o;
			if ($recherche =~ /p\.\(([a-zA-Z])(\d+)([a-zA-Z\*]*)\)/o) {#one letter
				if (!$3) {$recherche = "p.(".U2_modules::U2_subs_1::one2three(uc($1)).$2}
				elsif ($3 eq '*') {$recherche = "p.(".U2_modules::U2_subs_1::one2three(uc($1)).$2."*)"}
				else {$recherche = "p.(".U2_modules::U2_subs_1::one2three(uc($1)).$2.U2_modules::U2_subs_1::one2three(uc($3)).")"}
			}
			$query = "SELECT  nom, nom_gene, nom_prot FROM variant WHERE $motif LIKE '$recherche%' ORDER BY nom_gene, nom_g;";
		}
		elsif ($motif eq 'patient_name') {
			$recherche =~ s/'/''/og;
			$query = "SELECT numero, identifiant, famille, proband, first_name, last_name FROM patient WHERE last_name LIKE '%$recherche%';";
		}
		elsif ($motif eq 'familyID') {
			$recherche = uc($recherche);
			$recherche =~ s/^(S|U)/%/o;
			$query = "SELECT numero, identifiant, famille, proband, first_name, last_name FROM patient WHERE famille LIKE '$recherche';";
		}	
		if ($query ne '') {
			&print_results($query, $motif, '1', $recherche, $q, $dbh, $url, \@styles, $user, $original);
		}
		
		
		## multiple possibilities
		# > => DNA OK
		#only \d => variant (DNA, prot), patientID, family ID (OK)
		#only [A-Za-z] => patient name (OK)
		#\w\d+[\w*] => prot OK
		#\w{3}\d+[\w{3}*] => prot OK
		#del dup ins => DNA , prot OK
		if ($motif eq 'multiple_number') {
			#1st family/patient
			$query = "SELECT numero, identifiant, famille, proband, first_name, last_name FROM patient WHERE famille LIKE '%$recherche%' OR numero::text LIKE '%$recherche%' ORDER BY identifiant, numero;";
			&print_results($query, 'familyID', '2', $recherche, $q, $dbh, $url, \@styles, $user, $original);
			#2nd dna/prot variant
			$query = "SELECT * FROM variant WHERE nom LIKE '%$recherche%' OR nom_prot LIKE '%$recherche%' ORDER BY nom_gene, nom_g;";
			&print_results($query, 'variant', '3', $recherche, $q, $dbh, $url, \@styles, $user, $original);
		}
		
		if ($query eq '' && $motif ne 'LR') {
			&header($q, \@styles);
			U2_modules::U2_subs_1::standard_begin_html($q, $user->getName(), $dbh);
			print $q->p("U2 interpreted your query '$original' as '$recherche' and has looked in the dataset '$motif':");
			print $q->start_p(), $q->strong("Sorry, I did not find anything matching your query in U2 (query: '$recherche'). If you believe I should have found something, please contact David."), $q->end_p();
		}
		
		
		
	}
	else {
		&header($q, \@styles);
		U2_modules::U2_subs_1::standard_begin_html($q, $user->getName(), $dbh);
		print $q->p("U2 interpreted your query '$original' as '$recherche' and has looked in the dataset '$motif':");
		print "--".$q->param('search')."--";
		U2_modules::U2_subs_1::standard_error('10', $q);
	}


	
	
	##Basic end of USHVaM 2 perl scripts:
	
	U2_modules::U2_subs_1::standard_end_html($q);
	
	
	print $q->end_html();
	
	
}


##specific subs for current script

sub print_results {
	my ($query, $motif, $call, $recherche, $q, $dbh, $url, $style, $user, $original) = @_;
	my $sth = $dbh->prepare($query);
	my $res = $sth->execute();
	if ($res ne '0E0') {
		if ($res == 1 && $call == 1) {#only one result => redirect
			my $result = $dbh->selectrow_hashref($query);
			if ($motif eq 'patient_name' || $motif eq 'familyID') {$url = "patient_file.pl?sample=$result->{'identifiant'}$result->{'numero'}"}
			else {$url = "variant.pl?gene=$result->{'nom_gene'}[0]&accession=$result->{'nom_gene'}[1]&nom_c=".uri_escape($result->{'nom'})}
			#print $url;
			$q->redirect("$url");
			exit;
		}
		else {#multiple result
			if ($call != 3) {
				&header($q, $style);
				U2_modules::U2_subs_1::standard_begin_html($q, $user->getName(), $dbh);
				#print $q->p("U2 interpreted your query '$original' as '$recherche' and has looked in the dataset '$motif':");
			}
			if ($motif eq 'patient_name' || $motif eq 'familyID') {
				print 	$q->p({'class' => 'gros'}, "Please choose from the following: ($res sample(s))"), $q->start_ul();				
				while (my $result = $sth->fetchrow_hashref()) {
					my $proband = 'proband';
					if ($result->{'proband'} == 0) {$proband = 'relative'}
					print $q->start_li(), $q->a({'href' => "patient_file.pl?sample=$result->{'identifiant'}$result->{'numero'}", 'target' => '_blank'}, "$result->{'identifiant'}$result->{'numero'}"), $q->span("  - $result->{'famille'}  $result->{'first_name'} $result->{'last_name'} ($proband)"), $q->end_li(), "\n";
				}
			}
			else {
				#print $q->p("U2 interpreted your query '$original' as '$recherche' and has looked in the dataset '$motif':");
				print $q->p({'class' => 'gros'}, "Please choose from the following: ($res variant(s))"), $q->start_ul();
				if ($query =~ /taille > 100/o) {#for LR
					while (my $result = $sth->fetchrow_hashref()) {
						my $name = U2_modules::U2_subs_2::create_lr_name($result, $dbh);
						print $q->start_li(), $q->start_a({'href' => "variant.pl?gene=$result->{'nom_gene'}[0]&accession=$result->{'nom_gene'}[1]&nom_c=".uri_escape($result->{'nom'}), 'target' => '_blank'}), $q->em($result->{'nom_gene'}[0]), $q->span(":$result->{'nom'} - $result->{'nom_prot'} - $name"), $q->end_a(), $q->end_li(), "\n";
					}
				}
				else {#for normal variants
					while (my $result = $sth->fetchrow_hashref()) {
						my $spec = '';
						if ($motif eq 'RNA') {
							my $value = U2_modules::U2_subs_1::get_interpreted_position($result, $dbh, 'span', $q);
							my $css_class = $value;
							$css_class =~ s/ /_/og;
							$spec = $q->span({'class' => $css_class}, " - $value");
						}				
						print $q->start_li(), $q->start_a({'href' => "variant.pl?gene=$result->{'nom_gene'}[0]&accession=$result->{'nom_gene'}[1]&nom_c=".uri_escape($result->{'nom'}), 'target' => '_blank'}), $q->em($result->{'nom_gene'}[0]), $q->span(":$result->{'nom'} - $result->{'nom_prot'}"), $q->end_a(), $spec, $q->end_li(), "\n";
					}
					if ($q->param('dynamic') && $q->param('dynamic') =~ /([\w\s]+)/o) {
						my $class = $1;
						$class =~ s/ /_/og;
						my $js = '
						$(document).ready(function() {
							$(".'.$class.'").css("background-color", "#FFFF66");
						});
						';
						print $q->script({'type' => 'text/javascript'}, $js);
					}
				}
			}
			print $q->end_ul();
		}
	}
	else {
		#if $motif eq DNA-nom_g && user = david => search into gs2variant => redirect on self page with new param
		if ($user->getName() eq 'david' && $motif eq 'DNA-nom_g') {
			$query = "SELECT u2_name FROM gs2variant WHERE gs_name = '$recherche';";
			my $result = $dbh->selectrow_hashref($query);
			if ($result->{'u2_name'} ne '') {
				$url = "engine.pl?search=$result->{'u2_name'}";
				$q->redirect("$url");
			}
		}
		if ($call != 3) {
			&header($q, , $style);
			U2_modules::U2_subs_1::standard_begin_html($q, $user->getName(), $dbh);
			#print $q->p("U2 interpreted your query '$original' as '$recherche' and has looked in the dataset '$motif':");
		}		
		print $q->start_p(), $q->strong("Unknown value as $motif: $recherche."), $q->end_p();
	}
}

sub build_link {
	my ($motif, $recherche) = @_;
	if ($motif =~ /gene/) {
		return "gene.pl?gene=$recherche&info=general"
	}
	elsif ($motif eq 'patientID') {
		return "patient_file.pl?sample=$recherche"
	}
	#elsif ($motif eq 'familyID') {
	#	return "family.pl?id=$recherche"
	#}
}

sub get_genes { #sub to get gene names recorded
	my $dbh = shift;
	my $query = "SELECT DISTINCT (nom[1]) as gene FROM gene ORDER BY nom[1];";
	my $sth = $dbh->prepare($query);
	my $res = $sth->execute();
	my $gene;
	while (my $result = $sth->fetchrow_hashref()) {$gene->{$result->{'gene'}} = 'gene';$gene->{lc($result->{'gene'})} = 'gene_lc';}
	return $gene;
}

sub header {
	my ($cgi, $style) = @_;
	print $cgi->header(-type => 'text/html', -'cache-control' => 'no-cache'),
	$cgi->start_html(
		-title=>"U2 search engine",
                -lang => 'en',
                -style => {-src => $style},
                -head => [
			$cgi->Link({-rel => 'icon',
				-type => 'image/gif',
				-href => $HTDOCS_PATH.'data/img/animated_favicon1.gif'}),
			$cgi->Link({-rel => 'search',
				-type => 'application/opensearchdescription+xml',
				-title => 'U2 search engine',
				-href => $HTDOCS_PATH.'u2browserengine.xml'}),
			$cgi->meta({-http_equiv => 'Cache-control',
				-content => 'no-cache'}),
			$cgi->meta({-http_equiv => 'Pragma',
				-content => 'no-cache'}),
			$cgi->meta({-http_equiv => 'Expires',
				-content => '0'})],
                -script => [{-language => 'javascript',
                        -src => $JS_PATH.'jquery-1.7.2.min.js', 'defer' => 'defer'},
                        {-language => 'javascript',
                        -src => $JS_PATH.'jquery.fullsize.pack.js', 'defer' => 'defer'},
			{-language => 'javascript',
                        -src => $JS_PATH.'jquery.validate.min.js', 'defer' => 'defer'},
                        {-language => 'javascript',
                        -src => $JS_PATH.'jquery.autocomplete.min.js', 'defer' => 'defer'},
                        {-language => 'javascript',
                        -src => $JS_DEFAULT, 'defer' => 'defer'}],		
		-encoding => 'ISO-8859-1');
}
