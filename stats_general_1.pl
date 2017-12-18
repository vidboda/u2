BEGIN {delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV', 'PATH'};}

use strict;
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
#		General statistics page (patients/variants...)


##Extended init of USHVaM 2 perl scripts - loaded: highcharts.js, exporting.js, bootstrap.min.js/css, JQuery1.11.3
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

my $PERL_SCRIPTS_HOME = $config->PERL_SCRIPTS_HOME();

my @styles = ($CSS_PATH.'w3.css', $CSS_DEFAULT, $CSS_PATH.'bootstrap.min.css');

my $q = new CGI;

my $dbh = DBI->connect(    "DBI:Pg:database=$DB;host=$HOST;",
                        $DB_USER,
                        $DB_PASSWORD,
                        {'RaiseError' => 1}
                ) or die $DBI::errstr;


print $q->header(-type => 'text/html', -'cache-control' => 'no-cache'),
	$q->start_html(-title=>"U2 General Stats",
                        -lang => 'en',
                        -style => {-src => \@styles},
                        -head => [
				$q->Link({-rel => 'icon',
					-type => 'image/gif',
					-href => $HTDOCS_PATH.'data/img/animated_favicon1.gif'}),
				$q->Link({-rel => 'search',
					-type => 'application/opensearchdescription+xml',
					-title => 'U2 graphs 1',
					-href => $HTDOCS_PATH.'u2browserengine.xml'}),
				$q->meta({-http_equiv => 'Cache-control',
					-content => 'no-cache'}),
				$q->meta({-http_equiv => 'Pragma',
					-content => 'no-cache'}),
				$q->meta({-http_equiv => 'Expires',
					-content => '0'})],
                        -script => [{-language => 'javascript',
                                -src => $JS_PATH.'jquery-1.11.3.min.js', 'defer' => 'defer'},
				{-language => 'javascript',
				-src => $JS_PATH.'jquery.validate.min.js', 'defer' => 'defer'},
                                {-language => 'javascript',
                                -src => $JS_PATH.'highcharts.js', 'defer' => 'defer'},
				 {-language => 'javascript',
                                -src => $JS_PATH.'exporting.js', 'defer' => 'defer'},
				{-language => 'javascript',
                                -src => $JS_PATH.'bootstrap.min.js', 'defer' => 'defer'},
                                {-language => 'javascript',
                                -src => $JS_PATH.'jquery.autocomplete.min.js', 'defer' => 'defer'},
                                {-language => 'javascript',
                                -src => $JS_DEFAULT, 'defer' => 'defer'}],		
                        -encoding => 'ISO-8859-1');

my $user = U2_modules::U2_users_1->new();


U2_modules::U2_subs_1::standard_begin_html($q, $user->getName(), $dbh);

##end of Extended init

#print $q->br(), $q->br(), $q->start_h2({'class' => 'center'}), $q->strong("General statistics page for USHVaM 2:"), $q->end_h2();

my $date = U2_modules::U2_subs_1::get_date();

print $q->start_div({'class' => 'container'}), "\n",
	$q->h2('General statistics page for USHVaM 2:'), "\n",
	$q->start_div({'class' => 'panel-group',  'id' => 'graphs_pv'}), "\n";
#group patients
#1st chart pathology/proband
U2_modules::U2_subs_2::graph_pie('pie-probands', 'Probands pathology pie chart', 'proband_pathology_pie_chart', 'SELECT COUNT(numero) as num, pathologie as label FROM patient WHERE proband = \'t\' GROUP BY pathologie ORDER BY pathologie;', '', "Distribution of pathologies per probands (Total: X)", $date, 'Probands', $PERL_SCRIPTS_HOME.'patients.pl?phenotype=', 'patients', 'true', ' in', '', $q, $dbh);

#2nd chart pathology/relatives
U2_modules::U2_subs_2::graph_pie('pie-relatives', 'Relatives pathology pie chart', 'relative_pathology_pie_chart', 'SELECT COUNT(numero) as num, pathologie as label FROM patient WHERE proband = \'f\' GROUP BY pathologie ORDER BY pathologie;', '', "Distribution of pathologies per relatives (Total: X)", $date, 'Relatives', $PERL_SCRIPTS_HOME.'patients.pl?phenotype=', 'patients', 'false', '', '', $q, $dbh), '';

#3rd chart all variants/gene
my $threshold = 120;
U2_modules::U2_subs_2::graph_pie('pie-all', 'Variants (all classes) per gene pie chart', 'variant_all_pie_chart', "SELECT COUNT(nom) as num, nom_gene[1] as label FROM variant GROUP BY nom_gene[1] HAVING COUNT(nom) >= $threshold ORDER BY COUNT(nom);", "SELECT SUM(A.num) as others FROM (SELECT COUNT(nom) as num FROM variant GROUP BY nom_gene[1] HAVING COUNT(nom) < $threshold) AS A;", "Distribution of variants per genes (Total: X, more than $threshold variants)", $date, 'All variants', $PERL_SCRIPTS_HOME.'gene.pl?info=all_vars&amp;&sort=classe&amp;gene=', 'variants', 'false', '', 'Others', $q, $dbh);

#4th chart pathogenic variants/gene
$threshold = 5;
U2_modules::U2_subs_2::graph_pie('pie-pathogenic', 'Variants (pathogenic classes) per gene pie chart', 'variant_patho_pie_chart', "SELECT COUNT(nom) as num, nom_gene[1] as label FROM variant WHERE classe IN ('VUCS class III', 'VUCS class IV', 'pathogenic') GROUP BY nom_gene[1] HAVING COUNT(nom) >= $threshold ORDER BY COUNT(nom);", "SELECT SUM(A.num) as others FROM (SELECT COUNT(nom) as num FROM variant WHERE classe IN ('VUCS class III', 'VUCS class IV', 'pathogenic') GROUP BY nom_gene[1] HAVING COUNT(nom) < $threshold) AS A;", "Distribution of pathogenic variants per genes (Total: X, more than $threshold variants)", $date, 'Pathogenic variants', $PERL_SCRIPTS_HOME.'gene.pl?info=all_vars&amp;&sort=classe&amp;gene=', 'variants', 'false', '', 'Others', $q, $dbh);

#5th chart unknown variants/gene
$threshold = 50;
U2_modules::U2_subs_2::graph_pie('pie-unknown', 'Unknown variants per gene', 'variant_unknown_pie_chart', "SELECT COUNT(nom) as num, nom_gene[1] as label FROM variant WHERE classe = 'unknown' GROUP BY nom_gene[1] HAVING COUNT(nom) >= $threshold ORDER BY COUNT(nom);", "SELECT SUM(A.num) as others FROM (SELECT COUNT(nom) as num FROM variant WHERE classe = 'unknown' GROUP BY nom_gene[1] HAVING COUNT(nom) < $threshold) AS A;", "Distribution of unknown variants per genes (Total: X, more than $threshold variants)", $date, 'Unknown variants', $PERL_SCRIPTS_HOME.'gene.pl?info=all_vars&amp;&sort=classe&amp;gene=', 'variants', 'false', '', 'Others', $q, $dbh);

#6th usher mutation distribution
U2_modules::U2_subs_2::graph_pie('usher-mut', 'Distribution of Usher mutations', 'usher_mutations_pie_chart', "WITH tmp AS (SELECT DISTINCT(a.nom_c, a.num_pat, a.id_pat, a.nom_gene), a.nom_c, a.nom_gene FROM variant2patient a, gene b, variant c, patient d WHERE a.nom_c = c.nom AND a.nom_gene = c.nom_gene AND a.nom_gene = b.nom AND a.num_pat = d.numero AND a.id_pat = d.identifiant AND c.classe in ('pathogenic', 'VUCS class III', 'VUCS class IV') AND (b.usher = 't' OR d.pathologie IN ('USH1', 'USH2', 'USH3', 'ATYPICAL USH')) AND d.proband = 't')\nSELECT COUNT(a.nom_c) as num, a.nom_gene[1] as label FROM tmp a GROUP BY a.nom_gene[1] ORDER BY COUNT(a.nom_c);", '', "Frequency of Usher-associated variants per genes (Total: X)", $date, 'Usher mutations', $PERL_SCRIPTS_HOME.'gene.pl?info=all_vars&amp;&sort=classe&amp;gene=', 'variants', 'false', '', '', $q, $dbh);

#7th NSHL mutation distribution
U2_modules::U2_subs_2::graph_pie('nshl-mut', 'Distribution of NSHL mutations', 'nshl_mutations_pie_chart', "WITH tmp AS (SELECT DISTINCT(a.nom_c, a.num_pat, a.id_pat, a.nom_gene), a.nom_c, a.nom_gene FROM variant2patient a, gene b, variant c, patient d WHERE a.nom_c = c.nom AND a.nom_gene = c.nom_gene AND a.nom_gene = b.nom AND a.num_pat = d.numero AND a.id_pat = d.identifiant AND c.classe in ('pathogenic', 'VUCS class III', 'VUCS class IV') AND (b.dfn = 't' OR d.pathologie IN ('DFNA', 'DFNB', 'DFNX')) AND d.proband = 't')\nSELECT COUNT(a.nom_c) as num, a.nom_gene[1] as label FROM tmp a GROUP BY a.nom_gene[1] ORDER BY COUNT(a.nom_c);", '', "Frequency of NSHL-associated variants per genes (Total: X)", $date, 'NSHL mutations', $PERL_SCRIPTS_HOME.'gene.pl?info=all_vars&amp;&sort=classe&amp;gene=', 'variants', 'false', '', '', $q, $dbh);

#8th
U2_modules::U2_subs_2::graph_pie('nsrp-mut', 'Distribution of NSRP/CHM/LCA mutations', 'nsrp_mutations_pie_chart', "WITH tmp AS (SELECT DISTINCT(a.nom_c, a.num_pat, a.id_pat, a.nom_gene), a.nom_c, a.nom_gene FROM variant2patient a, gene b, variant c, patient d WHERE a.nom_c = c.nom AND a.nom_gene = c.nom_gene AND a.nom_gene = b.nom AND a.num_pat = d.numero AND a.id_pat = d.identifiant AND c.classe in ('pathogenic', 'VUCS class III', 'VUCS class IV') AND (b.rp = 't' OR d.pathologie IN ('NSRP', 'LCA', 'CHM')) AND d.proband = 't')\nSELECT COUNT(a.nom_c) as num, a.nom_gene[1] as label FROM tmp a GROUP BY a.nom_gene[1] ORDER BY COUNT(a.nom_c);", '', "Frequency of NS-eye-disease-associated variants per genes (Total: X)", $date, 'NSRP mutations', $PERL_SCRIPTS_HOME.'gene.pl?info=all_vars&amp;&sort=classe&amp;gene=', 'variants', 'false', '', '', $q, $dbh);

#9th
#3nd variant types
U2_modules::U2_subs_2::graph_pie('variant-type', 'Types of alterations', 'variant_type_pie_chart', "SELECT COUNT(nom_g) as num, type_prot as label FROM variant WHERE classe in ('pathogenic', 'VUCS class III', 'VUCS class IV') AND type_arn = 'neutral' GROUP BY type_prot ORDER BY COUNT(nom_g);", "SELECT COUNT(nom_g) as others FROM variant WHERE classe in ('pathogenic', 'VUCS class III', 'VUCS class IV') AND type_arn = 'altered' AND taille < 100;", "Pathogenic variants types<br/>(Total: X variants)", $date, 'variant types', '', 'variant', 'false', '', 'RNA-altered', $q, $dbh);


#10th RNA variant types
#cannonical sites, exonic, non cannonical intronic, deep intronic
U2_modules::U2_subs_2::RNA_pie("SELECT nom, nom_g, num_segment, type_segment, num_segment_end, type_segment_end, nom_gene FROM variant WHERE classe in ('pathogenic', 'VUCS class III', 'VUCS class IV') AND type_arn = 'altered' AND taille < 100;", $date, $q, $dbh);


	
print	$q->end_div(), "\n",
$q->end_div();


##Basic end of USHVaM 2 perl scripts:

U2_modules::U2_subs_1::standard_end_html($q);

print $q->end_html();

exit();

##End of Basic end


##specific subs
