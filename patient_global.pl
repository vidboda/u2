BEGIN {delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV', 'PATH'};}

use strict;
#use CGI;#in startup.pl
#use DBI;
#use AppConfig qw(:expand :argcount);
use List::Util qw(first max maxstr min minstr reduce shuffle sum);;
use U2_modules::U2_users_1;
use U2_modules::U2_init_1;
use U2_modules::U2_subs_1;
use U2_modules::U2_subs_2;
#use Benchmark qw(:hireswallclock);

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
#		page to display global results for analysis and genotypes for a given patient


##EXTENDED Basic init of USHVaM 2 perl scripts: INCLUDES bobble popup CSS print and timeline JS
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
my $CSS_DEFAULT = $config->CSS_DEFAULT();
my $CSS_PATH = $config->CSS_PATH();
my $JS_PATH = $config->JS_PATH();
my $JS_DEFAULT = $config->JS_DEFAULT();
my $HTDOCS_PATH = $config->HTDOCS_PATH();
my $ANALYSIS_ILLUMINA_PG_REGEXP = $config->ANALYSIS_ILLUMINA_PG_REGEXP();

#my @styles = ($CSS_DEFAULT, $CSS_PATH.'jquery-bubble-popup-v3.css');
#my @style_print = ($CSS_PATH.'u2_print.css');$CSS_PATH.'w3.css',

my $q = new CGI;

my $dbh = DBI->connect(    "DBI:Pg:database=$DB;host=$HOST;",
                        $DB_USER,
                        $DB_PASSWORD,
                        {'RaiseError' => 1}
                ) or die $DBI::errstr;

print $q->header(-type => 'text/html', -'cache-control' => 'no-cache'),
	$q->start_html(	-title=>"U2 global patient view",
			-lang => 'en',
		    #-style => {-src => \@styles, -media => 'screen'},
		    #-style => {-src => \@style_print, -media => 'print'},
			-head => [
				$q->Link({-rel => 'icon',
					-type => 'image/gif',
					-href => $HTDOCS_PATH.'data/img/animated_favicon1.gif'}),
				$q->Link({-rel => 'stylesheet',
					-type => 'text/css',
					-href => $CSS_PATH.'w3.css',
					-media => 'screen'}),
				$q->Link({-rel => 'stylesheet',
                                        -type => 'text/css',
                                        -href => $CSS_PATH.'font-awesome.min.css',
                                        -media => 'screen'}),
				$q->Link({-rel => 'stylesheet',
					-type => 'text/css',
					-href => $CSS_DEFAULT,
					-media => 'screen'}),
				$q->Link({-rel => 'stylesheet',
					-type => 'text/css',
					-href => $CSS_PATH.'jquery-bubble-popup-v3.css',
					-media => 'screen'}),
				$q->Link({-rel => 'stylesheet',
					-type => 'text/css',
					-href => $CSS_PATH.'datatables.min.css',
					-media => 'screen'}),
				$q->Link({-rel => 'stylesheet',
					-type => 'text/css',
					-href => $CSS_PATH.'u2_print.css',
					-media => 'print'}),
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
				-src => $JS_PATH.'datatables.min.js', 'defer' => 'defer'},
				{-language => 'javascript',
				-src => $JS_PATH.'jquery-bubble-popup-v3.min.js', 'defer' => 'defer'},
				{-language => 'javascript',
				-src => $JS_PATH.'timeline/js/storyjs-embed.js', 'defer' => 'defer'},
				{-language => 'javascript',
				-src => $JS_PATH.'jquery.autocomplete.min.js', 'defer' => 'defer'},
				{-language => 'javascript',
				-src => $JS_DEFAULT, 'defer' => 'defer'}],
			-encoding => 'ISO-8859-1');

my $user = U2_modules::U2_users_1->new();


U2_modules::U2_subs_1::standard_begin_html($q, $user->getName(), $dbh);

##end of Basic init

my ($id, $number) = U2_modules::U2_subs_1::sample2idnum(uc($q->param('sample')), $q);

#get the name

my ($first_name, $last_name, $DoB) = U2_modules::U2_subs_2::get_patient_name($id, $number, $dbh);
my $type;
if ($q->param('type') && $q->param('type') =~ /(genotype|analyses)/o) {$type = $1}
else {U2_modules::U2_subs_1::standard_error('1', $q)}

print $q->start_p({'class' => 'center'}), $q->start_big(), $q->span("Sample "), $q->strong({'onclick' => "window.location = 'patient_file.pl?sample=$id$number'", 'class' => 'pointer'}, $id.$number), $q->span(": Global Results for "), $q->strong("$first_name $last_name"), $q->end_big(), $q->end_p(), "\n";


#get rid of '
$last_name =~ s/'/''/og;
$first_name =~ s/'/''/og;

#reports technical table
if ($type eq 'analyses') {

	#ok for the timeline we get the analyses, and the result multiple from valid_type_analyse to group e.g. NGS experiments
	#1st query to get patient info
	my $query = "SELECT numero, identifiant, famille, pathologie, proband, date_creation, trio_assigned FROM patient WHERE first_name = '$first_name' AND last_name = '$last_name' AND (date_of_birth = '$DoB' OR date_of_birth IS NULL) ORDER BY date_creation, numero;";
	if ($DoB == '') {
		$query = "SELECT numero, identifiant, famille, pathologie, proband, date_creation, trio_assigned FROM patient WHERE first_name = '$first_name' AND last_name = '$last_name' AND date_of_birth IS NULL ORDER BY date_creation, numero;";
	}
	my $sth = $dbh->prepare($query);
	my $res = $sth->execute();
	my $i = 0;
	my $creation_date;
	my $dates = "\"date\": [
	";
	my $proband = 'no';
	my $trio_assigned = 'no';
	my $headline;
	#my $tag = 'Creation';
	my ($num_list, $id_list) = ("'$number'", "'$id'");
	while (my $result = $sth->fetchrow_hashref()) {
		$i++;
		if ($result->{'proband'} == 1) {$proband = 'yes'}
		if ($result->{'trio_assigned'} == 1) {$trio_assigned = 'yes'}
		if ($i == 1) {$headline = "Creation in U2 $result->{'identifiant'}$result->{'numero'}";$creation_date = U2_modules::U2_subs_1::date_pg2tjs($result->{'date_creation'});}
		else {$headline = "New sample $result->{'identifiant'}$result->{'numero'}"}#$tag = 'New sample';}
		$dates .= "
			{
			    \"startDate\":\"$creation_date\",
			    \"endDate\":\"$creation_date\",
			    \"headline\":\"$headline\",
			    \"tag\":\"A-Sample creation\",
			    \"text\":\"<p>Family $result->{'famille'}, Pathology: $result->{'pathologie'}<br/>Proband: $proband, Sample: $result->{'identifiant'}$result->{'numero'}</p>\",
			    \"asset\": {
				\"media\":\"".$HTDOCS_PATH."data/img/U2.png\",
				\"thumbnail\":\"".$HTDOCS_PATH."data/img/favicon.ico\",
			    }
			},
		";
		if ($result->{'numero'} ne $number) {($num_list, $id_list) .= (", '$result->{'numero'}'", ", '$result->{'identifiant'}'")}
	}
	if ($trio_assigned eq 'yes') {
		#allele assignation
		my $query_assign = "SELECT COUNT(nom_c) as a, allele FROM variant2patient WHERE id_pat IN ($id_list) AND num_pat IN ($num_list) AND type_analyse ~ '$ANALYSIS_ILLUMINA_PG_REGEXP' GROUP BY allele;";
		my $sth_assign = $dbh->prepare($query_assign);
		my $res_assign = $sth_assign->execute();
		if ($res_assign ne '0E0') {
			print $q->br(), $q->start_div({'width' => '50%'}), $q->start_table({'class' => 'great_table technical'}), $q->caption("Allele assignation table: $first_name variants have been assigned thanks to parents' data."), $q->start_Tr(), "\n",
					$q->th('Allele'),
					$q->th('Number of variants'),
				$q->end_Tr(), "\n";
			while (my $result_assign = $sth_assign->fetchrow_hashref()) {
				print $q->start_Tr(), "\n",
					$q->td($result_assign->{'allele'}),
					$q->td($result_assign->{'a'}),
				$q->end_Tr(), "\n";
			}
			print $q->end_table(), $q->end_div(), $q->br(), "\n";
		}
		#print $query_assign;
	}
	my $text = 'You will find below a timeline and a global validation table summarising all analyses performed for the patient.';
	print U2_modules::U2_subs_2::info_panel($text, $q);
	#2nd query for non-groupable analyses

	$query = "SELECT DISTINCT(d.gene_symbol), a.type_analyse, a.valide, a.result, a.date_analyse, a.date_valid, a.date_result, a.analyste, a.validateur, a.referee, b.numero, b.identifiant FROM analyse_moleculaire a, patient b, valid_type_analyse c, gene d WHERE a.num_pat = b.numero AND a.id_pat = b.identifiant AND a.type_analyse = c.type_analyse AND a.refseq = d.refseq AND c.multiple = 'f' AND b.first_name = '$first_name' AND b.last_name = '$last_name' AND (b.date_of_birth = '$DoB' OR b.date_of_birth IS NULL) ORDER BY date_analyse;";
	if ($DoB == '') {
		$query = "SELECT DISTINCT(d.gene_symbol), a.type_analyse, a.valide, a.result, a.date_analyse, a.date_valid, a.date_result, a.analyste, a.validateur, a.referee, b.numero, b.identifiant FROM analyse_moleculaire a, patient b, valid_type_analyse c, gene d WHERE a.num_pat = b.numero AND a.id_pat = b.identifiant AND a.type_analyse = c.type_analyse AND a.refseq = d.refseq AND c.multiple = 'f' AND b.first_name = '$first_name' AND b.last_name = '$last_name' AND date_of_birth IS NULL ORDER BY date_analyse;";
	}
	$sth = $dbh->prepare($query);
	$res = $sth->execute();

	while (my $result = $sth->fetchrow_hashref()) {
		my ($picture, $thumbnail) = ('pipette.jpg', 'pipette_thumb.jpg');
		my $analysis_date = U2_modules::U2_subs_1::date_pg2tjs($result->{'date_analyse'});
		if (!$analysis_date) {$analysis_date = $creation_date}
		if ($result->{'type_analyse'} eq 'SANGER') {($picture, $thumbnail) = ('abi_3130.jpg', 'abi_3130_thumb.jpg')}
		elsif ($result->{'type_analyse'} eq 'MLPA') {($picture, $thumbnail) = ('mlpa.jpg', 'mlpa_thumb.jpg')}
		$dates .= "
			{
			    \"startDate\":\"$analysis_date\",
			    \"endDate\":\"$analysis_date\",
			    \"headline\":\"$result->{'type_analyse'} $result->{'gene_symbol'} ".U2_modules::U2_subs_1::translate_valide_human($result->{'valide'})."\",
			    \"tag\":\"B-Single gene analysis\",
			    \"text\":\"<p>Gene: <em>$result->{'nom_gene'}</em>, Analyst: ".ucfirst($result->{'analyste'})."<br/> Result: ".U2_modules::U2_subs_1::translate_result_human($result->{'result'})." ($result->{'referee'} / $result->{'date_result'}), Validation: ".U2_modules::U2_subs_1::translate_boolean_class($result->{'valide'})." ($result->{'validateur'} / $result->{'date_valid'}) </p><p><a href = 'add_analysis.pl?step=2&amp;sample=$result->{'identifiant'}$result->{'numero'}&amp;gene=$result->{'gene_symbol'}&amp;analysis=$result->{'type_analyse'}' target = '_blank'>Modify analysis</a> / <a href = 'patient_genotype.pl?sample=$result->{'identifiant'}$result->{'numero'}&amp;gene=$result->{'gene_symbol'}' target = '_blank'>See genotype</a></p>\",
			    \"asset\": {
				\"media\":\"".$HTDOCS_PATH."data/img/$picture\",
				\"thumbnail\":\"".$HTDOCS_PATH."data/img/$thumbnail\",
			    }
			},
		";

	}

	#3rd groupable analysis (eg NGS, CGH)
	$query = "SELECT DISTINCT(a.type_analyse), a.date_analyse, a.analyste, c.manifest_name, b.numero, b.identifiant FROM analyse_moleculaire a, patient b, valid_type_analyse c WHERE a.num_pat = b.numero AND a.id_pat = b.identifiant AND a.type_analyse = c.type_analyse AND c.multiple = 't' AND b.first_name = '$first_name' AND b.last_name = '$last_name' AND (b.date_of_birth = '$DoB' OR b.date_of_birth IS NULL) ORDER BY date_analyse;";
	if ($DoB == '') {
		$query = "SELECT DISTINCT(a.type_analyse), a.date_analyse, a.analyste, c.manifest_name, b.numero, b.identifiant FROM analyse_moleculaire a, patient b, valid_type_analyse c WHERE a.num_pat = b.numero AND a.id_pat = b.identifiant AND a.type_analyse = c.type_analyse AND c.multiple = 't' AND b.first_name = '$first_name' AND b.last_name = '$last_name' AND date_of_birth IS NULL ORDER BY date_analyse;";
	}

	$sth = $dbh->prepare($query);
	$res = $sth->execute();

	while (my $result = $sth->fetchrow_hashref()) {
		#for miseq get the run number
		my $text = '';
		if ($result->{'manifest_name'} ne 'no_manifest') {
			my $query2 = "SELECT run_id, filter FROM miseq_analysis WHERE num_pat = '$result->{'numero'}' AND id_pat = '$result->{'identifiant'}' AND type_analyse = '$result->{'type_analyse'}';";
			my $res = $dbh->selectrow_hashref($query2);
			$text = "<br/>Filter: $res->{'filter'}<br/> Run: <a href = 'stats_ngs.pl?run=$res->{'run_id'}' target = '_blank'>$res->{'run_id'}</a>";
		}

		my ($picture, $thumbnail) = ('pipette.jpg', 'pipette_thumb.jpg');
		my $analysis_date = U2_modules::U2_subs_1::date_pg2tjs($result->{'date_analyse'});
		if (!$analysis_date) {$analysis_date = $creation_date}
		if ($result->{'type_analyse'} =~ /454/o) {($picture, $thumbnail) = ('junior.jpg', 'junior_thumb.jpg')}
		elsif ($result->{'type_analyse'} =~ /MiSeq/o) {($picture, $thumbnail) = ('miseq.jpg', 'miseq_thumb.jpg')}
		elsif ($result->{'type_analyse'} =~ /MiniSeq/o) {($picture, $thumbnail) = ('miniseq.jpg', 'miniseq_thumb.jpg')}
		elsif ($result->{'type_analyse'} =~ /NextSeq/o) {($picture, $thumbnail) = ('nextseq.jpg', 'nextseq_thumb.jpg')}
		elsif ($result->{'type_analyse'} =~ /CGH/o) {($picture, $thumbnail) = ('cgh.jpg', 'cgh_thumb.jpg')}
		$dates .= "
			{
			    \"startDate\":\"$analysis_date\",
			    \"endDate\":\"$analysis_date\",
			    \"headline\":\"$result->{'type_analyse'}\",
			    \"tag\":\"C-Multiple genes analysis\",
			    \"text\":\"<p>Analyst: ".ucfirst($result->{'analyste'})." $text</p>\",
			    \"asset\": {
				\"media\":\"".$HTDOCS_PATH."data/img/$picture\",
				\"thumbnail\":\"".$HTDOCS_PATH."data/img/$thumbnail\",
			    }
			},
		";

	}


	$dates .= "
	],";
	my $timeline = "
	storyjs_jsonp_data = {
		\"timeline\":
		{
		    \"headline\":\"Analyses for $first_name $last_name\",
		    \"type\":\"default\",
		    \"text\":\"<p>$i sample(s)</p>\",
		    \"asset\": {
			\"media\":\"$HTDOCS_PATH/data/img/U2.png\",
			//\"credit\":\"Credit Name Goes Here\",
			\"caption\":\"USHVaM 2 using Timeline JS\"
		    },
		    $dates
		}
	};
	\$(document).ready(function() {
                createStoryJS({
                    type:       'timeline',
                    width:      '100%',
                    height:     '400',
                    source:     storyjs_jsonp_data,
                    embed_id:   'patient-timeline',
		    font:	'NixieOne-Ledger'
                });
		\$('#validation_table').DataTable({aaSorting:[],lengthMenu: [ [25, 50, 100, -1], [25, 50, 100, \"All\"] ]});
            });

	";


	print $q->script({'defer' => 'defer'}, $timeline), $q->start_div({'id' => 'patient-timeline'}), $q->end_div(), $q->br(), $q->br();

	print $q->start_div({'align' => 'center'});
	U2_modules::U2_subs_2::print_validation_table($first_name, $last_name, $DoB, '', $q, $dbh, $user, 'global');
	print $q->end_div();
	#print $q->end_td(), $q->end_Tr(), $q->end_table();
}
else {#reports genotype table
	#beginning of  table
	my $text = 'You will find below a global genotype view, reporting for all genes VUCS class II, III, IV, unknown and pathogenic variants.';
	print U2_modules::U2_subs_2::info_panel($text, $q);
	print $q->start_div({'class' => 'w3-container w3-margin w3-small', 'style' => 'width:50%'});
	U2_modules::U2_subs_2::print_filter($q);
	print $q->end_div(), $q->br(), $q->start_div({'class' => 'patient_file_frame hidden w3-small', 'id' => 'details', 'onmouseover' => "\$(this).hide();\$(this).html(\'<img src = \"".$HTDOCS_PATH."data/img/loading.gif\"  class = \"loading\"/>loading...\')"}), $q->img({'src' => $HTDOCS_PATH."data/img/loading.gif", 'class' => 'loading'}), $q->span('loading...'), $q->end_div(), $q->br(), $q->br(), $q->br(), $q->start_div({'align' => 'center'}), $q->start_table({'class' => 'geno ombre w3-small'}), $q->caption("Global genotype table:"),
		$q->start_Tr(), "\n",
			$q->th({'width' => '6%'}, 'gene'), "\n",
			$q->th({'width' => '6%'}, 'Exon/Intron'), "\n",
			$q->th({'width' => '21%'}, 'Allele 1'), "\n",
			$q->th({'width' => '2%'}, '1'), "\n",
			$q->th({'width' => '2%'}, '2'), "\n",
			$q->th({'width' => '21%'}, 'Allele 2'), "\n",
			$q->th({'width' => '2%'}, '?'), "\n",
			$q->th({'width' => '21%'}, 'Unknown allele'), "\n",
			$q->th({'width' => '2%'}, '?'), "\n",
			$q->th({'width' => '7%'}, 'Analysis type'), "\n",
			$q->th({'width' => '10%'}, 'dbSNP'), "\n";
		$q->end_Tr(), "\n";


	#we can't get all vars at once, as they should be sorted depending on the strand. So we need to get all genes first, then check strand, get vars and print

	my $query = "SELECT DISTINCT(d.gene_symbol) as gene, a.type_analyse FROM analyse_moleculaire a, patient b, variant2patient c, gene d WHERE a.id_pat = b.identifiant AND a.num_pat = b.numero AND c.type_analyse = a.type_analyse AND a.refseq = c.refseq AND c.refseq = d.refseq AND b.numero = c.num_pat AND b.identifiant = c.id_pat AND b.first_name = '$first_name' AND b.last_name = '$last_name' AND (b.date_of_birth = '$DoB' OR b.date_of_birth IS NULL) ORDER BY d.gene_symbol;";
	if ($DoB == '') {
		$query = "SELECT DISTINCT(d.gene_symbol) as gene, a.type_analyse FROM analyse_moleculaire a, patient b, variant2patient c, gene d WHERE a.id_pat = b.identifiant AND a.num_pat = b.numero AND c.type_analyse = a.type_analyse AND a.refseq = c.refseq AND c.refseq = d.refseq AND b.numero = c.num_pat AND b.identifiant = c.id_pat AND b.first_name = '$first_name' AND b.last_name = '$last_name' AND b.date_of_birth IS NULL ORDER BY d.gene_symbol;";
	}
	#my $query = "SELECT DISTINCT(a.nom_gene[1]) as gene, a.num_pat, a.id_pat, a.type_analyse, c.filtering_possibility, d.rp, d.dfn FROM analyse_moleculaire a, patient b, valid_type_analyse c, gene d WHERE a.id_pat = b.identifiant AND a.num_pat = b.numero AND a.type_analyse = c.type_analyse AND a.nom_gene = d.nom AND b.first_name = '$first_name' AND b.last_name = '$last_name' ORDER BY a.nom_gene[1];";
	#print $query;
	my $sth = $dbh->prepare($query);
	my $res = $sth->execute();
  my $list;
	my $nb_var = 0;
	my ($allele1, $allele2) = ('#F45B5B', '#337AB7');
	while (my $result = $sth->fetchrow_hashref()) {

		#my $tgene = Benchmark->new();

		my $gene = $result->{'gene'};

		my $query_filter = "SELECT a.num_pat, a.id_pat, a.type_analyse, c.filtering_possibility, d.rp, d.dfn, d.usher, d.gene_symbol as nom_gene FROM analyse_moleculaire a, patient b, valid_type_analyse c, gene d WHERE a.id_pat = b.identifiant AND a.num_pat = b.numero AND a.type_analyse = c.type_analyse AND a.refseq = d.refseq AND d.gene_symbol = '$gene' AND b.first_name = '$first_name' AND b.last_name = '$last_name' ORDER BY c.filtering_possibility DESC;";
		my $result_filter = $dbh->selectrow_hashref($query_filter);
		my $display = 1;
		#display data?
		if ($result_filter->{'filtering_possibility'} == 1) {
			#get filter
			$display = U2_modules::U2_subs_2::gene_to_display($result_filter, $dbh);
		}

		#my $tfilter = Benchmark->new();

		if ($display == 1) {

			#my $t1 = Benchmark->new();

			#defines gene strand
			my ($direction, $main_acc, $acc_g, $acc_v) = U2_modules::U2_subs_2::get_direction($gene, $dbh);

			#my $t2 = Benchmark->new();

			#defines an interval for putative large deletions as genomic positions
			my ($mini, $maxi) = U2_modules::U2_subs_2::get_interval($first_name, $last_name, $gene, $dbh);
			#get vars for specific gene/sample
			my $query = "SELECT b.nom, e.gene_symbol, e.refseq, b.classe, b.type_segment, b.type_segment_end, b.num_segment, b.num_segment_end, b.nom_ivs, b.nom_prot, b.snp_id, b.snp_common, b.taille, b.type_adn, b.nom_g, a.msr_filter, a.num_pat, a.id_pat, a.depth, a.frequency, a.wt_f, a.wt_r, a.mt_f, a.mt_r, a.allele, a.statut, a.type_analyse, c.first_name, c.last_name, d.nom as nom_seg FROM variant2patient a, variant b, patient c, segment d, gene e WHERE a.nom_c = b.nom AND a.refseq = b.refseq AND a.num_pat = c.numero AND a.id_pat = c.identifiant AND b.refseq = d.refseq AND d.refseq = e.refseq AND b.type_segment = d.type AND b.num_segment = d.numero AND c.first_name = '$first_name' AND c.last_name = '$last_name' AND e.gene_symbol = '$gene' AND b.classe NOT IN ('artefact', 'neutral', 'VUCS class I', 'R8', 'VUCS Class F') ORDER BY b.num_segment, b.nom_g $direction, a.type_analyse;";
			#order by type_analyse because 454 before sanger for doc, etc in popup - TODO: be sure sanger = last for point mutations

			#my $display = 1;

			#my $t3 = Benchmark->new();

			my $sth2 = $dbh->prepare($query);
			my $res2 = $sth2->execute();
			if ($res2 ne '0E0') {
				while (my $result2 = $sth2->fetchrow_hashref()) {
						my $nom = U2_modules::U2_subs_2::genotype_line_optimised($result2, $mini, $maxi, $q, $dbh, $list, $main_acc, $nb_var, $acc_g, 't');
						$list->{$nom}++;
						if ($list->{$nom} == 1) {$nb_var ++}
					#}
				}
				print $q->start_Tr({'class' => 'bordure'}), $q->td("&nbsp;"), $q->td("&nbsp;"), $q->td("&nbsp;"), $q->td({'bgcolor' => $allele1}, "&nbsp;"), $q->td({'bgcolor' => $allele2}, "&nbsp;"), $q->td("&nbsp;"), $q->td({'bgcolor' => $allele1}, "&nbsp;"), $q->td("&nbsp;"), $q->td({'bgcolor' => $allele2}, "&nbsp;"), $q->td("&nbsp;"), $q->td("&nbsp;"), $q->end_Tr()
			}

			#my $t4 = Benchmark->new();

			#my $b1 = timediff($t2, $t1);
			#my $b2 = timediff($t3, $t2);
			#my $b3 = timediff($t4, $t3);
			#print $q->span('new'), timestr($b1), $q->br(), timestr($b2), $q->br(), timestr($b3), $q->br();

		}

		#my $tdisplay = Benchmark->new();

		#my $b1 = timediff($tfilter, $tgene);
		#my $b2 = timediff($tdisplay, $tfilter);
		#print $q->span('new'), timestr($b1), $q->br(), timestr($b2), $q->br();

	}


	print $q->end_table(), $q->end_div(), "\n", $q->br(), $q->br(), $q->br(), $q->start_ul(),
		$q->start_li(), $q->span("Shown: "), $q->start_strong(), $q->span({'id' => 'nb_var'}, $nb_var), $q->span(" / $nb_var variants."), $q->end_strong(), $q->end_li(),
		$q->start_li(), $q->strong("Color code:"), $q->span("&nbsp;&nbsp;&nbsp;&nbsp;"),
			$q->font({'color' => U2_modules::U2_subs_1::color_by_classe('neutral', $dbh)}, "neutral&nbsp;&nbsp;&nbsp;&nbsp;"),
			$q->font({'color' => U2_modules::U2_subs_1::color_by_classe('VUCS class I', $dbh)}, "VUCS class I&nbsp;&nbsp;&nbsp;&nbsp;"),
			$q->font({'color' => U2_modules::U2_subs_1::color_by_classe('VUCS class II', $dbh)}, "VUCS class II&nbsp;&nbsp;&nbsp;&nbsp;"),
			$q->font({'color' => U2_modules::U2_subs_1::color_by_classe('VUCS class III', $dbh)}, "VUCS class III&nbsp;&nbsp;&nbsp;&nbsp;"),
			$q->font({'color' => U2_modules::U2_subs_1::color_by_classe('VUCS class IV', $dbh)}, "VUCS class IV&nbsp;&nbsp;&nbsp;&nbsp;"),
			$q->font({'color' => U2_modules::U2_subs_1::color_by_classe('pathogenic', $dbh)}, "pathogenic&nbsp;&nbsp;&nbsp;&nbsp;"),
			$q->font({'color' => U2_modules::U2_subs_1::color_by_classe('unknown', $dbh)}, "unknown&nbsp;&nbsp;&nbsp;&nbsp;"),
			$q->font({'color' => U2_modules::U2_subs_1::color_by_classe('R8', $dbh)}, "R8&nbsp;&nbsp;&nbsp;&nbsp;"),
			$q->font({'color' => U2_modules::U2_subs_1::color_by_classe('VUCS Class F', $dbh)}, "VUCS Class F&nbsp;&nbsp;&nbsp;&nbsp;"),
			$q->font({'color' => U2_modules::U2_subs_1::color_by_classe('VUCS Class U', $dbh)}, "VUCS Class U&nbsp;&nbsp;&nbsp;&nbsp;"),
		$q->end_li(), $q->end_ul();
}

##Basic end of USHVaM 2 perl scripts:

U2_modules::U2_subs_1::standard_end_html($q);

print $q->end_html();

exit();

##End of Basic end

##specific subs for current script
