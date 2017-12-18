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

my @styles = ($CSS_PATH.'w3.css', $CSS_DEFAULT, $CSS_PATH.'bootstrap.min.css', $CSS_PATH.'jquery-ui-1.12.1.min.css');

my $q = new CGI;

my $dbh = DBI->connect(    "DBI:Pg:database=$DB;host=$HOST;",
                        $DB_USER,
                        $DB_PASSWORD,
                        {'RaiseError' => 1}
                ) or die $DBI::errstr;

my $js = 'function chooseSortingType(gene) {
		var $dialog = $(\'<div></div>\')
			.html("<p>Choose how your variants will be sorted:</p><ul><li><a href = \'gene.pl?gene="+gene+"&info=all_vars&sort=classe\' target = \'_self\'>Pathogenic class</a></li><li><a href = \'gene.pl?gene="+gene+"&info=all_vars&sort=type_adn\' target = \'_self\'>DNA type (subs, indels...)</a></li><li><a href = \'gene.pl?gene="+gene+"&info=all_vars&sort=type_prot\' target = \'_self\'>Protein type (missense, silent...)</a></li><li><a href = \'gene.pl?gene="+gene+"&info=all_vars&sort=type_arn\' target = \'_self\'>RNA type (neutral / altered)</a></li><li><a href = \'gene.pl?gene="+gene+"&info=all_vars&sort=taille\' target = \'_self\'>Variant size (get only large rearrangements)</a></li></ul>")
			.dialog({
			    autoOpen: false,
			    title: \'U2 choice\',
			    width: 450,
			});
		$dialog.dialog(\'open\');
		$(\'.ui-dialog\').zIndex(\'1002\');
	}';



print $q->header(-type => 'text/html', -'cache-control' => 'no-cache'),
	$q->start_html(-title=>"U2 Gene graphs",
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
                                -src => $JS_PATH.'jquery-1.11.3.min.js', 'defer' => 'defer'},
				{-language => 'javascript',
				-src => $JS_PATH.'jquery.validate.min.js', 'defer' => 'defer'},
				{-language => 'javascript',
				-src => $JS_PATH.'jquery-ui-1.12.1.min.js', 'defer' => 'defer'},
                                {-language => 'javascript',
                                -src => $JS_PATH.'highcharts.js', 'defer' => 'defer'},
				 {-language => 'javascript',
                                -src => $JS_PATH.'exporting.js', 'defer' => 'defer'},
				{-language => 'javascript',
                                -src => $JS_PATH.'bootstrap.min.js', 'defer' => 'defer'},
                                {-language => 'javascript',
                                -src => $JS_PATH.'jquery.autocomplete.min.js', 'defer' => 'defer'},
				$js,
                                {-language => 'javascript',
                                -src => $JS_DEFAULT, 'defer' => 'defer'}],		
                        -encoding => 'ISO-8859-1');

my $user = U2_modules::U2_users_1->new();


U2_modules::U2_subs_1::standard_begin_html($q, $user->getName(), $dbh);

##end of Extended init

my ($gene, $second_name) = U2_modules::U2_subs_1::check_gene($q, $dbh);

my $date = U2_modules::U2_subs_1::get_date();

U2_modules::U2_subs_1::gene_header($q, 'graphs', $gene);

print $q->start_div({'class' => 'container'}), "\n",
	$q->start_h2(), $q->em($gene), $q->span(' graphs page:'), $q->end_h2(), "\n",
	$q->start_div({'class' => 'panel-group',  'id' => 'graphs_pv'}), "\n";

#1st frequency of variant
#we need an approx of the number of variants to decide a threshold (approx because we don't eliminate sevearl occurences of a same variant in a patient due to multiple analyses)
#if total vars freqs < 50, no threshold (display everything)
#else, threshold = 2, we display only vairants occrring at least twice in probands (non private mutations)
my $query = "SELECT COUNT(nom_c) as num FROM variant2patient a, variant b WHERE a.nom_c = b.nom AND a.nom_gene = b.nom_gene AND a.nom_gene[1] = '$gene' AND classe IN ('pathogenic', 'VUCS class III', 'VUCS class IV');";
my $res = $dbh->selectrow_hashref($query);

if ($res->{'num'} > 100) {
	#2 queries with a threshold
	U2_modules::U2_subs_2::graph_pie('variant-freq', 'Frequency of pathogenic variants pie chart', 'variant_freq_pie_chart', "WITH tmp AS (SELECT DISTINCT(a.nom_c, a.num_pat, a.id_pat, a.nom_gene), a.nom_c FROM variant2patient a, variant b, patient c WHERE a.nom_c = b.nom AND a.nom_gene = b.nom_gene AND a.num_pat = c.numero AND a.id_pat = c.identifiant AND b.classe IN ('pathogenic', 'VUCS class III', 'VUCS class IV') AND a.nom_gene[1] = '$gene' AND c.proband = 't')\nSELECT COUNT(nom_c) as num, nom_c as label FROM tmp GROUP BY nom_c HAVING COUNT(nom_c) > 2 ORDER BY COUNT(nom_c);", "SELECT SUM(A.num) as others FROM (WITH tmp AS (SELECT DISTINCT(a.nom_c, a.num_pat, a.id_pat, a.nom_gene), a.nom_c FROM variant2patient a, variant b, patient c WHERE a.nom_c = b.nom AND a.nom_gene = b.nom_gene AND a.num_pat = c.numero AND a.id_pat = c.identifiant AND b.classe IN ('pathogenic', 'VUCS class III', 'VUCS class IV') AND a.nom_gene[1] = '$gene' AND c.proband = 't')\nSELECT COUNT(nom_c) as num FROM tmp GROUP BY nom_c HAVING COUNT(nom_c) <= 2) AS A;", "Frequency of disease causing variants in <em>$gene</em><br/>(Total: X in probands, at least 2 occurrences)", $date, "$gene mutations", $PERL_SCRIPTS_HOME."gene.pl?gene=$gene&amp;info=all_vars&amp;sort=", 'variants', 'true', ' in', 'Others', $q, $dbh);
}
elsif ($res->{'num'} > 0) {
	#one single query
	U2_modules::U2_subs_2::graph_pie('variant-freq', 'Frequency of pathogenic variants pie chart', 'variant_freq_pie_chart', "WITH tmp AS (SELECT DISTINCT(a.nom_c, a.num_pat, a.id_pat, a.nom_gene), a.nom_c FROM variant2patient a, variant b, patient c WHERE a.nom_c = b.nom AND a.nom_gene = b.nom_gene AND a.num_pat = c.numero AND a.id_pat = c.identifiant AND b.classe IN ('pathogenic', 'VUCS class III', 'VUCS class IV') AND a.nom_gene[1] = '$gene' AND c.proband = 't')\nSELECT COUNT(nom_c) as num, nom_c as label FROM tmp GROUP BY nom_c ORDER BY COUNT(nom_c);", '', "Frequency of disease causing variants in <em>$gene</em><br/>(Total: X in probands)", $date, "$gene mutations", $PERL_SCRIPTS_HOME."gene.pl?gene=$gene&amp;info=all_vars&amp;sort=", 'variants', 'true', ' in', 'Others', $q, $dbh);
}
if ($res->{'num'} != 0) {
	#2nd phenotype associated
	U2_modules::U2_subs_2::graph_pie('phenotype', "Phenotypes associated with <em>$gene</em>", 'phenotype_pie_chart', "WITH tmp AS (SELECT DISTINCT(a.nom_c, a.num_pat, a.id_pat, a.nom_gene), a.num_pat, a.id_pat, c.pathologie FROM variant2patient a, variant b, patient c WHERE a.nom_c = b.nom AND a.nom_gene = b.nom_gene AND a.num_pat = c.numero AND a.id_pat = c.identifiant AND b.classe IN ('pathogenic', 'VUCS class III', 'VUCS class IV') AND a.nom_gene[1] = '$gene' AND c.proband = 't')\nSELECT COUNT(CONCAT(id_pat, num_pat)) as num, pathologie as label FROM tmp GROUP BY pathologie ORDER BY COUNT(id_pat);", '', "Phenotypes associated with disease causing variants in <em>$gene</em><br/>(Total: X probands)", $date, "$gene phenotypes", $PERL_SCRIPTS_HOME.'patients.pl?phenotype=', 'phenotype', 'false', '', '', $q, $dbh);
	
	#3nd variant types
	U2_modules::U2_subs_2::graph_pie('variant-type', 'Types of alterations', 'variant_type_pie_chart', "SELECT COUNT(nom_g) as num, type_prot as label FROM variant WHERE classe in ('pathogenic', 'VUCS class III', 'VUCS class IV') AND nom_gene[1] = '$gene' AND type_arn = 'neutral' GROUP BY type_prot ORDER BY COUNT(nom_g);", "SELECT COUNT(nom_g) as others FROM variant WHERE classe IN ('pathogenic', 'VUCS class III', 'VUCS class IV') AND nom_gene[1] = '$gene' AND type_arn = 'altered' AND taille < 100;", "Alteration types induced by <em>$gene</em> pathogenic variants<br/>(Total: X variants)", $date, "$gene variant types", $PERL_SCRIPTS_HOME."gene.pl?gene=$gene&amp;info=all_vars&amp;sort=", 'variant', 'false', '', 'RNA-altered', $q, $dbh);
	
	#4th RNA variant types
	#cannonical sites, exonic, non cannonical intronic, deep intronic
	U2_modules::U2_subs_2::RNA_pie("SELECT nom, nom_g, num_segment, type_segment, num_segment_end, type_segment_end, nom_gene FROM variant WHERE classe IN ('pathogenic', 'VUCS class III', 'VUCS class IV') AND nom_gene[1] = '$gene' AND type_arn = 'altered' AND taille < 100;", $date, $q, $dbh);

}
else {
	print $q->p('No pathogenic alterations to plot')
}


#4th detail for RNA-altered

print	$q->end_div(), "\n",
$q->end_div();


##Basic end of USHVaM 2 perl scripts:

U2_modules::U2_subs_1::standard_end_html($q);

print $q->end_html();

exit();

##End of Basic end


##specific subs

