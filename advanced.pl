BEGIN {delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV', 'PATH'};}

use strict;
#use CGI;
#use DBI;
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
#		Home page of U2


##Basic init of USHVaM 2 perl scripts
#	env variables
#	get config infos
#	initialize DB connection
#	initialize HTML (change page title if needed, as well as CSS files and JS)
#	Load standard JS, CSS and fixed html
#	identify users
#	just copy at the beginning of each script

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

my @styles = ($CSS_PATH.'font-awesome.min.css', $CSS_PATH.'w3.css', $CSS_DEFAULT, $CSS_PATH.'fullsize/fullsize.css', $CSS_PATH.'jquery.alerts.css', $CSS_PATH.'datatables.min.css');

my $q = new CGI;

my $dbh = DBI->connect(    "DBI:Pg:database=$DB;host=$HOST;",
                        $DB_USER,
                        $DB_PASSWORD,
                        {'RaiseError' => 1}
                ) or die $DBI::errstr;



print $q->header(-type => 'text/html', -'cache-control' => 'no-cache'),
	$q->start_html(-title=>"Advanced options",
                        -lang => 'en',
                        -style => {-src => \@styles},
                        -head => [
				$q->Link({-rel => 'icon',
					-type => 'image/gif',
					-href => $HTDOCS_PATH.'data/img/animated_favicon1.gif'}),
				$q->Link({-rel => 'search',
					-type => 'application/opensearchdescription+xml',
					-title => 'U2 search engine',
					-href => $HTDOCS_PATH.'u2browserengine.xml'}),
				$q->meta({-http_equiv => 'Cache-control',
					-content => 'no-cache'}),
				$q->meta({-http_equiv => 'Pragma',
					-content => 'no-cache'}),
				$q->meta({-http_equiv => 'Expires',
					-content => '0'})],
                        -script => [{-language => 'javascript',
                                -src => $JS_PATH.'jquery-1.7.2.min.js', 'defer' => 'defer'},
                                {-language => 'javascript',
                                -src => $JS_PATH.'jquery.fullsize.pack.js', 'defer' => 'defer'},
				{-language => 'javascript',
                                -src => $JS_PATH.'jquery.validate.min.js', 'defer' => 'defer'},
				{-language => 'javascript',
				-src => $JS_PATH.'jquery.alerts.js', 'defer' => 'defer'},
				{-language => 'javascript',
				-src => $JS_PATH.'datatables.min.js', 'defer' => 'defer'},
                                {-language => 'javascript',
                                -src => $JS_PATH.'jquery.autocomplete.min.js', 'defer' => 'defer'},
                                {-language => 'javascript',
                                -src => $JS_DEFAULT}],		
                        -encoding => 'ISO-8859-1', 'defer' => 'defer');

my $user = U2_modules::U2_users_1->new();


U2_modules::U2_subs_1::standard_begin_html($q, $user->getName(), $dbh);

##end of Basic init


if ($q->param('advanced') && $q->param('advanced') eq 'non-USH') {
	#code	 SELECT DISTINCT(a.identifiant, a.numero) as sample, b.nom_gene, b.statut FROM patient a, variant2patient b, variant c WHERE a.numero = b.num_pat AND a.identifiant = b.id_pat AND c.nom = b.nom_c AND c.nom_gene = b.nom_gene AND c.classe IN ('VUCS class III',  'VUCS class IV', 'pathogenic') AND a.pathologie IN ('USH1', 'USH2', 'USH3', 'ATYPICAL USH') AND c.nom_gene[1] NOT IN ('MYO7A', 'USH1C', 'CDH23', 'PCDH15', 'USH1G', 'USH2A', 'GPR98', 'DFNB31', 'CLRN1', 'HARS', 'CIB2', 'PDZD7') AND (a.identifiant, a.numero) NOT IN (SELECT DISTINCT(a.identifiant, a.numero) FROM patient a, variant2patient b WHERE a.numero = b.num_pat AND a.identifiant = b.id_pat AND b.classe IN ('VUCS class III',  'VUCS class IV', 'pathogenic') AND a.pathologie IN ('USH1', 'USH2', 'USH3', 'ATYPICAL USH') AND b.nom_gene[1] IN ('MYO7A', 'USH1C', 'CDH23', 'PCDH15', 'USH1G', 'USH2A', 'GPR98', 'DFNB31', 'CLRN1', 'HARS', 'CIB2', 'PDZD7')) ORDER BY (a.identifiant, a.numero);
	
	#my $query = "SELECT DISTINCT(a.identifiant, a.numero) as sample, b.nom_gene, b.statut FROM patient a, variant2patient b, variant c WHERE a.numero = b.num_pat AND a.identifiant = b.id_pat AND c.nom = b.nom_c AND c.nom_gene = b.nom_gene AND c.classe IN ('VUCS class III',  'VUCS class IV', 'pathogenic') AND a.pathologie IN ('USH1', 'USH2', 'USH3', 'ATYPICAL USH') AND c.nom_gene[1] NOT IN ('MYO7A', 'USH1C', 'CDH23', 'PCDH15', 'USH1G', 'USH2A', 'GPR98', 'DFNB31', 'CLRN1', 'HARS', 'CIB2', 'PDZD7') ORDER BY (a.identifiant, a.numero);";
	#Table 1
	my $query = "SELECT DISTINCT(a.identifiant, a.numero) as sample, b.nom_gene, b.statut, c.type_prot FROM patient a, variant2patient b, variant c WHERE a.numero = b.num_pat AND a.identifiant = b.id_pat AND c.nom = b.nom_c AND c.nom_gene = b.nom_gene AND c.classe IN ('VUCS class III',  'VUCS class IV', 'pathogenic') AND a.pathologie IN ('USH1', 'USH2', 'USH3', 'ATYPICAL USH') AND c.nom_gene[1] NOT IN ('MYO7A', 'USH1C', 'CDH23', 'PCDH15', 'USH1G', 'USH2A', 'GPR98', 'DFNB31', 'CLRN1', 'HARS', 'CIB2', 'PDZD7') AND (a.identifiant, a.numero) NOT IN (SELECT a.identifiant, a.numero FROM patient a, variant2patient b, variant c WHERE a.numero = b.num_pat AND a.identifiant = b.id_pat AND c.nom = b.nom_c AND c.nom_gene = b.nom_gene AND c.classe IN ('VUCS class III',  'VUCS class IV', 'pathogenic') AND a.pathologie IN ('USH1', 'USH2', 'USH3', 'ATYPICAL USH') AND b.nom_gene[1] IN ('MYO7A', 'USH1C', 'CDH23', 'PCDH15', 'USH1G', 'USH2A', 'GPR98', 'DFNB31', 'CLRN1', 'HARS', 'CIB2', 'PDZD7')) ORDER BY (a.identifiant, a.numero);";
	my $list;
	my $sth = $dbh->prepare($query);
	my $res = $sth->execute();
	if ($res ne '0E0') {
		my $text = $q->span('You will find below the samples that are labelled as \'USHER\' but who carry NO mutations in ANY USHER gene AND who carry mutation(s) (pathogenic, VUCS class III, IV) in NON-USHER genes.').$q->br().
			$q->span('Please note that \'USH\' patients carrying only one mutation in a USH gene will be excluded from this list.');
		print U2_modules::U2_subs_2::info_panel($text, $q);
		#print $q->start_p(), $q->strong('You will find below the samples that are labelled as \'USHER\' but who carry NO mutations in ANY USHER gene AND who carry mutation(s) (pathogenic, VUCS class III, IV) in NON-USHER genes.'), $q->end_p(), $q->p('Please note that \'USH\' patients carrying only one mutation in a USH gene will be excluded from this list.'), "\n",
		print	$q->br(), $q->br(), "\n",
			$q->start_div({'class' => 'container', 'align' => 'center'}),
			$q->start_table({'class' => 'great_table technical', 'id' => 'ushnonush1'}), $q->caption('Table 1: USH patients exclusively mutated in non-USH genes'), $q->start_thead(), "\n",
				$q->th({'class' => 'left_general'}, 'Sample'),
				$q->th({'class' => 'left_general'}, 'Mutated Gene'),
				$q->th({'class' => 'left_general'}, 'Variant Type'),
				$q->th({'class' => 'left_general'}, 'Variant Status'),
			$q->end_thead(), $q->start_tbody(), "\n";
		while (my $result = $sth->fetchrow_hashref()) {
			my $sample = $result->{'sample'};
			$sample =~ s/\(//og;
			$sample =~ s/\)//og;
			my @temp = split(/,/, $sample);
			$sample =~ s/,//og;
			
			$list->{$temp[1]} = $temp[0];
			
			print $q->start_Tr({'class' => 'bright'}), "\n",
				$q->start_td(), $q->a({'href' => "patient_file.pl?sample=$sample", 'target' => '_blank', 'title' => 'jump to sample page'}, $sample), $q->end_td(), "\n",
				$q->start_td(), $q->start_em(), $q->a({'href' => "patient_genotype.pl?sample=$sample&gene=$result->{'nom_gene'}[0]", 'target' => '_blank', 'title' => 'jump to genotype'}, $result->{'nom_gene'}[0]), $q->end_em(), $q->end_td(), "\n",
				$q->td($result->{'type_prot'}), "\n",
				$q->td($result->{'statut'}), "\n",
				$q->end_Tr();	
		}
		my $table1_js = "\$('#ushnonush1').DataTable({aaSorting:[]});";
		print $q->end_tbody(), $q->end_table(), $q->end_div(), $q->script({'type' => 'text/javascript', 'defer' => 'defer'}, $table1_js);		
	}
	#Table 2
	$query = "SELECT DISTINCT(a.identifiant, a.numero) as sample, b.nom_gene, b.statut, c.type_prot FROM patient a, variant2patient b, variant c WHERE a.numero = b.num_pat AND a.identifiant = b.id_pat AND c.nom = b.nom_c AND c.nom_gene = b.nom_gene AND c.classe IN ('VUCS class III',  'VUCS class IV', 'pathogenic') AND a.pathologie IN ('USH1', 'USH2', 'USH3', 'ATYPICAL USH') AND c.nom_gene[1] NOT IN ('MYO7A', 'USH1C', 'CDH23', 'PCDH15', 'USH1G', 'USH2A', 'GPR98', 'DFNB31', 'CLRN1', 'HARS', 'CIB2', 'PDZD7') AND (a.identifiant, a.numero) NOT IN (";
	
	foreach my $key (keys(%{$list})) {$query .= "('$list->{$key}', '$key'), "}
	chop($query);
	chop($query);
	$query .= ") ORDER BY (a.identifiant, a.numero);";
	
	$sth = $dbh->prepare($query);
	$res = $sth->execute();
	if ($res ne '0E0') {
		print $q->br(), $q->br();
		#, $q->start_p(), $q->strong('This second table references ALL patients labelled as \'USHER\' and who carry a mutation in a NON-USHER gene, WHATEVER their situation in USHER genes (excluding patients from the first table).'), $q->end_p(),
		my $text = $q->span('This second table references ALL patients labelled as \'USHER\' and who carry a mutation in a NON-USHER gene, ').$q->br().
		$q->span('WHATEVER their situation in USHER genes (excluding patients from the first table).');
		print U2_modules::U2_subs_2::info_panel($text, $q);
		print	$q->br(), $q->br(), "\n",
			$q->start_div({'class' => 'container', 'align' => 'center'}),
			$q->start_table({'class' => 'great_table technical', 'id' => 'ushnonush2'}), $q->caption('Table 2: USH patients mutated in non-USH genes not in Table 1'), $q->start_thead(), "\n",
				$q->th({'class' => 'left_general'}, 'Sample'),
				$q->th({'class' => 'left_general'}, 'Mutated Gene'),
				$q->th({'class' => 'left_general'}, 'Variant Type'),
				$q->th({'class' => 'left_general'}, 'Variant Status'),
			$q->end_thead(), $q->start_tbody(), "\n";
		while (my $result = $sth->fetchrow_hashref()) {
			my $sample = $result->{'sample'};
			$sample =~ s/,//og;
			$sample =~ s/\(//og;
			$sample =~ s/\)//og;
			print $q->start_Tr({'class' => 'bright'}), "\n",
				$q->start_td(), $q->a({'href' => "patient_file.pl?sample=$sample", 'target' => '_blank', 'title' => 'jump to sample page'}, $sample), $q->end_td(), "\n",
				$q->start_td(), $q->start_em(), $q->a({'href' => "patient_genotype.pl?sample=$sample&gene=$result->{'nom_gene'}[0]", 'target' => '_blank', 'title' => 'jump to genotype'}, $result->{'nom_gene'}[0]), $q->end_em(), $q->end_td(), "\n",
				$q->td($result->{'type_prot'}), "\n",
				$q->td($result->{'statut'}), "\n",
				$q->end_Tr();	
		}
		my $table2_js = "\$('#ushnonush2').DataTable({aaSorting:[]});";
		print $q->end_tbody(), $q->end_table(), $q->end_div(), $q->script({'type' => 'text/javascript', 'defer' => 'defer'}, $table2_js);
		
	}
	
}

if ($q->param('advanced') && $q->param('advanced') eq 'forgotten_samples') {
	#select numero, identifiant from patient where (numero || identifiant) not in (select DISTINCT(num_pat, id_pat) from analyse_moleculaire)
	#SELECT numero FROM patient WHERE proband = 't' AND date_creation + CAST('3 months' AS INTERVAL) < CURRENT_DATE AND (numero) NOT IN (SELECT DISTINCT(num_pat) FROM analyse_moleculaire)
	my $delay = '3 months';
	my $query = "SELECT identifiant, numero, first_name, last_name, date_creation FROM patient WHERE proband = 't' AND date_creation + CAST('".$delay."' AS INTERVAL) < CURRENT_DATE AND (identifiant || numero) NOT IN (SELECT DISTINCT(id_pat || num_pat) FROM analyse_moleculaire) ORDER BY date_creation, identifiant, numero;";
	#my $query = "WITH tmp AS (SELECT DISTINCT(id_pat, numpat) FROM analyse_moleculaire\nSELECT a.identifiant, a.numero, a.first_name, a.last_name, a.date_creation FROM patient a, tmp b WHERE a.proband = 't' AND a.date_creation + CAST('".$delay."' AS INTERVAL) < CURRENT_DATE AND (a.identifiant, a.numero) NOT IN (b.id_pat, b.num_pat) ORDER BY a.date_creation, a.identifiant, a.numero;";
	my $sth = $dbh->prepare($query);
	my $res = $sth->execute();
	print U2_modules::U2_subs_2::info_panel("You will find below a list of index cases samples recorded more than $delay ago, and for which no analyses have been carried:", $q),
			$q->ul(), "\n";
	my $i = 0;
	while (my $result = $sth->fetchrow_hashref()) {
		if ($res ne '0E0') {
			my ($last_name, $first_name) = ($result->{'last_name'}, $result->{'first_name'});
			$last_name =~ s/'/''/og;
			$first_name =~ s/'/''/og;
			#got all samples without associated experiment arrived more than 3 months ago : need to double check if another sample of the samepatient has been studied
			my $query_check = "SELECT COUNT(numero) as num_samples FROM patient WHERE last_name = '$last_name' AND first_name = '$first_name';";
			my $res_check = $dbh->selectrow_hashref($query_check);
			if ($res_check->{'num_samples'} > 1) {
				#need to actually double check
				my $query_check2 = "SELECT identifiant, numero FROM patient WHERE last_name = '$last_name' AND first_name = '$first_name' AND numero <> '".$result->{'numero'}."';";
				my $sth_check2 = $dbh->prepare($query_check2);
				my $res_check2 = $sth_check2->execute();
				while (my $result_check2 = $sth_check2->fetchrow_hashref()) {
					my $query_check3 = "SELECT id_pat, num_pat FROM analyse_moleculaire WHERE id_pat = '".$result_check2->{'identifiant'}."' AND num_pat = '".$result_check2->{'numero'}."';";
					my $res_check3 = $dbh->selectrow_hashref($query_check3);
					if ($res_check3 eq '') {
						#print $q->li($res_check->{'num_samples'} ." - ".$res_check3);
						&print_forgotten_sample($result->{'identifiant'}, $result->{'numero'}, $result->{'date_creation'});
						$i++;
					}
				}
			}
			else {
				&print_forgotten_sample($result->{'identifiant'}, $result->{'numero'}, $result->{'date_creation'});
				$i++;
			}
		}
		else {print $q->li('Congrats!! you are up-to-date!!!')}
	}
	print $q->end_ul(), "\n", $q->br(),
		U2_modules::U2_subs_2::info_panel("Corresponding to $i samples", $q);
}




##Basic end of USHVaM 2 perl scripts:

U2_modules::U2_subs_1::standard_end_html($q);

print $q->end_html();

exit();

##End of Basic end

##specific subs

sub print_forgotten_sample {
	my ($id, $number, $date) = @_;
	print $q->start_li(),
			$q->a({'target' => '_blank', 'href' => "patient_file.pl?sample=$id$number", 'title' => 'Visit the sample page'}, $id.$number), $q->span(" created $date"),
			$q->end_li(), "\n";
}

