BEGIN {delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV', 'PATH'};}

use strict;
#use CGI;#in startup.pl
#use DBI;
#use AppConfig qw(:expand :argcount);
#use List::Util qw(first max maxstr min minstr reduce shuffle sum);
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
#		page to display genotypes for a given gene

##EXTENDED Basic init of USHVaM 2 perl scripts: INCLUDES bobble popup CSS print
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
my $ABSOLUTE_HTDOCS_PATH = $config->ABSOLUTE_HTDOCS_PATH();
my $HOME_IP = $config->HOME_IP();
#do not exactly need home, just IP
$HOME_IP =~ /(https*:\/\/[\d\.]+)\/.+/o;
$HOME_IP = $1;
my $RS_BASE_DIR = $config->RS_BASE_DIR(); #RS mounted using autofs - meant to replace ssh and ftps in future versions
my $REF_GENE_URI = $config->REF_GENE_URI();

#my @styles = ($CSS_DEFAULT, $CSS_PATH.'igv.css');

my $q = new CGI;

my $dbh = DBI->connect(    "DBI:Pg:database=$DB;host=$HOST;",
                        $DB_USER,
                        $DB_PASSWORD,
                        {'RaiseError' => 1}
                ) or die $DBI::errstr;

#$q->Link({-rel => 'stylesheet',
#					-type => 'text/css',
#	 				-href => $CSS_PATH.'bootstrap.min.css',
#					-media => 'screen'}),
#{-language => 'javascript',
#				-src => $JS_PATH.'bootstrap.min.js', 'defer' => 'defer'},

print $q->header(-type => 'text/html', -'cache-control' => 'no-cache'),
	$q->start_html(	-title=>"U2 patient genotype",
			-lang => 'en',
                        #-style => {-src => \@styles},
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
					-href => $CSS_DEFAULT,
					-media => 'screen'}),			
				$q->Link({-rel => 'stylesheet',
					-type => 'text/css',
					-href => $CSS_PATH.'jquery-ui-1.12.1.min.css',
					-media => 'screen'}),
				$q->Link({-rel => 'stylesheet',
					-type => 'text/css',
					-href => $CSS_PATH.'font-awesome.min.css',
					-media => 'screen'}),
				$q->Link({-rel => 'stylesheet',
					-type => 'text/css',
					-href => $CSS_PATH.'igv-1.0.5.css',
					-media => 'screen'}),	
				$q->Link({-rel => 'stylesheet',
					-type => 'text/css',
					-href => $CSS_PATH.'u2_print.css',
					-media => 'print'}),
				$q->Link({-rel => 'search',
					-type => 'application/opensearchdescription+xml',
					-title => 'U2 search engine',
					-href => $HTDOCS_PATH.'u2browserengine.xml'}),
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
				-src => $JS_PATH.'jquery-ui-1.12.1.min.js', 'defer' => 'defer'},
				{-language => 'javascript',
				-src => $JS_PATH.'jquery.autocomplete.min.js', 'defer' => 'defer'},
				{-language => 'javascript',
				-src => $JS_PATH.'igv-1.0.5.min.js', 'defer' => 'defer'},
				{-language => 'javascript',
				-src => $JS_DEFAULT, 'defer' => 'defer'}],		
			-encoding => 'ISO-8859-1');

my $user = U2_modules::U2_users_1->new();


U2_modules::U2_subs_1::standard_begin_html($q, $user->getName(), $dbh);

##end of Basic init

my ($id, $number) = U2_modules::U2_subs_1::sample2idnum(uc($q->param('sample')), $q);

my ($gene, $second) = U2_modules::U2_subs_1::check_gene($q, $dbh);




# get all ids for a patient given a gene

#get the name

my ($first_name, $last_name) = U2_modules::U2_subs_2::get_patient_name($id, $number, $dbh);


print $q->start_p({'class' => 'center'}), $q->start_big(), $q->span("Sample "), $q->strong({'onclick' => "window.location = 'patient_file.pl?sample=$id$number'", 'class' => 'pointer'}, $id.$number), $q->span(": Results for "), $q->strong("$first_name $last_name"), $q->span(" in "), $q->start_strong(), $q->em({'onclick' => "gene_choice('$gene');", 'class' => 'pointer', 'title' => 'click to get somewhere'}, $gene), $q->span(" ($second)"), $q->end_strong(), $q->end_big(), $q->end_p(), "\n";

#defines gene strand

my ($direction, $main_acc, $acc_g, $acc_v) = U2_modules::U2_subs_2::get_direction($gene, $dbh);


#prints filtering options
my $text = $q->strong("Default isoform: ").$q->a({'href' => "http://www.ncbi.nlm.nih.gov/nuccore/$main_acc.$acc_v", 'target' => '_blank'}, "$main_acc.$acc_v");
print U2_modules::U2_subs_2::info_panel($text, $q);
#print $q->start_p(), $q->strong("Default isoform: "), $q->a({'href' => "http://www.ncbi.nlm.nih.gov/nuccore/$main_acc.$acc_v", 'target' => '_blank'}, "$main_acc.$acc_v"), $q->end_p(),
print 	$q->start_table({'class' => 'zero_table width_general w3-small'}),
		$q->start_Tr(), $q->start_td({'class' => 'zero_td'});
		
U2_modules::U2_subs_2::print_filter($q);

	
print $q->end_td(), "\n";

#get rid of '
$last_name =~ s/'/''/og;
$first_name =~ s/'/''/og;

#reports technical table
print $q->start_td({'class' => 'zero_td right_general'});
U2_modules::U2_subs_2::print_validation_table($first_name, $last_name, $gene, $q, $dbh, $user, '');
print $q->end_td(), $q->end_Tr(), $q->end_table();

#defines an interval for putative large deletions as genomic positions

my ($mini, $maxi) = U2_modules::U2_subs_2::get_interval($first_name, $last_name, $gene, $dbh);

#print $q->p('Click on an exon/intron number and watch IGV move!!!');
#begin table

print $q->br(), $q->start_div({'class' => 'patient_file_frame hidden print_hidden w3-small', 'id' => 'details', 'onmouseover' => "\$(this).hide();\$(this).html(\'<img src = \"".$HTDOCS_PATH."data/img/loading.gif\"  class = \"loading\"/>loading...\')"}), $q->img({'src' => $HTDOCS_PATH."data/img/loading.gif", 'class' => 'loading'}), $q->span('loading...'), $q->end_div(), $q->br(), $q->br(), $q->br(), $q->start_div({'align' => 'center'}), $q->start_table({'class' => 'geno w3-small'}), $q->caption("Genotype table:"),
	$q->start_Tr(), "\n",
		$q->th({'width' => '6%'}, 'Exon/Intron'), "\n",
		$q->th({'width' => '23%'}, 'Allele 1'), "\n",
		$q->th({'width' => '2%'}, '1'), "\n",
		$q->th({'width' => '2%'}, '2'), "\n",
		$q->th({'width' => '23%'}, 'Allele 2'), "\n",
		$q->th({'width' => '2%'}, '?'), "\n",
		$q->th({'width' => '23%'}, 'Unknown allele'), "\n",
		$q->th({'width' => '2%'}, '?'), "\n",
		$q->th({'width' => '7%'}, 'Analysis type'), "\n",
		$q->th({'width' => '10%'}, 'dbSNP'), "\n",
	$q->end_Tr(), "\n";



#get vars for specific gene/sample
#my $query = "SELECT a.*, b.*, c.first_name, c.last_name FROM variant2patient a, variant b, patient c WHERE a.nom_c = b.nom AND a.nom_gene = b.nom_gene AND a.num_pat = c.numero AND a.id_pat = c.identifiant AND b.classe <> 'artefact' AND c.first_name = '$first_name' AND c.last_name = '$last_name' AND a.nom_gene[1] = '$gene' ORDER BY num_segment, b.nom_g $direction, type_analyse;";

my $query = "SELECT b.nom, b.nom_gene, b.classe, b.type_segment, b.type_segment_end, b.num_segment, b.num_segment_end, b.nom_ivs, b.nom_prot, b.snp_id, b.snp_common, b.taille, b.type_adn, b.nom_g, a.msr_filter, a.num_pat, a.id_pat, a.depth, a.frequency, a.wt_f, a.wt_r, a.mt_f, a.mt_r, a.allele, a.statut, a.denovo, a.type_analyse, c.first_name, c.last_name, d.nom as nom_seg FROM variant2patient a, variant b, patient c, segment d WHERE a.nom_c = b.nom AND a.nom_gene = b.nom_gene AND a.num_pat = c.numero AND a.id_pat = c.identifiant AND b.nom_gene = d.nom_gene AND b.type_segment = d.type AND b.num_segment = d.numero AND b.classe <> 'artefact' AND c.first_name = '$first_name' AND c.last_name = '$last_name' AND a.nom_gene[1] = '$gene' ORDER BY num_segment, b.nom_g $direction, type_analyse;";


#order by type_analyse because 454 before sanger for doc, etc in popup - TODO: be sure sanger = last for point mutations NOT enough with MiSeq #fixed in U2_subs_2 directly
#$query = "SELECT a.*, b.*, c.first_name, c.last_name, d.common FROM variant2patient a, variant b, patient c, restricted_snp d WHERE a.nom_c = b.nom AND a.nom_gene = b.nom_gene AND a.num_pat = c.numero AND a.id_pat = c.identifiant AND b.snp_id = d.rsid AND c.first_name = '$first_name' AND c.last_name = '$last_name' AND a.nom_gene[1] = '$gene' order by num_segment, b.nom_g $sens;";

my $nb_var = 0;
my $list;
my $sth = $dbh->prepare($query);
my $res = $sth->execute();
#my $analysis = 'non_ngs';

if ($res ne '0E0') {
	while (my $result = $sth->fetchrow_hashref()) {
		#if ($analysis eq 'non_ngs' && $result->{'type_analyse'} =~ /^Mi.+/o) {$analysis = $result->{'type_analyse'}}	
		my $nom = U2_modules::U2_subs_2::genotype_line_optimised($result, $mini, $maxi, $q, $dbh, $list, $main_acc, $nb_var, $acc_g, 'f');
		$list->{$nom}++;
		if ($list->{$nom} == 1) {$nb_var ++}
	}
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
	$q->end_li(), $q->end_ul(), $q->br();



#if ($analysis ne 'non_ngs') {
	#$HOME_IP.$HTDOCS_PATH.$RS_BASE_DIR.$bam_ftp
	#my $bam_path = U2_modules::U2_subs_2::get_bam_path($id, $number, $analysis, $dbh);
	#my ($instrument, $instrument_path) = ('miseq', 'MiSeqDx/USHER');
	#my $query_manifest = "SELECT run_id FROM miseq_analysis WHERE num_pat = '$number' AND id_pat = '$id' AND type_analyse = '$analysis';";
	#my $res_manifest = $dbh->selectrow_hashref($query_manifest);
	#if ($analysis =~ /MiniSeq-\d+/o) {$instrument = 'miniseq';$instrument_path = 'MiniSeq'}
	#
	#my ($alignment_dir);
	#if ($instrument eq 'miseq'){
	#	$alignment_dir = `grep -Eo \"AlignmentFolder>.+\\Alignment[0-9]*<\" $ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/data/$instrument_path/$res_manifest->{'run_id'}/CompletedJobInfo.xml`;
	#	$alignment_dir =~ /\\(Alignment\d*)<$/o;$alignment_dir = $1;
	#}
	#elsif($instrument eq 'miniseq'){
	#	$alignment_dir = `grep -Eo \"AlignmentFolder>.+\\Alignment_?[0-9]*.+<\" $ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/data/$instrument_path/$res_manifest->{'run_id'}/CompletedJobInfo.xml`;
	#	$alignment_dir =~ /\\(Alignment_?\d*.+)<$/o;
	#	$alignment_dir = $1;
	#	$alignment_dir =~ s/\\/\//og;					
	#}
	##print $alignment_dir;
	#my $bam_list = `ls $ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/data/$instrument_path/$res_manifest->{'run_id'}/$alignment_dir`;
	##print $res_manifest->{'run_id'};
	##create a hash which looks like {"illumina_run_id" => 0}
	#my %files = map {$_ => '0'} split(/\s/, $bam_list);
	#my $bam_file;
	#foreach my $file_name (keys(%files)) {
	#	#print $file_name;
	#	if ($file_name =~ /$id$number(_S\d+\.bam)/) {
	#		my $bam_file_suffix = $1;
	#		$bam_file = "$alignment_dir/$id$number$bam_file_suffix";
	#		#$bam_ftp = "$ftp_dir/$id$number$bam_file_suffix";
	#	}								
	#}
	#my $bam_path = "$HTDOCS_PATH$RS_BASE_DIR/data/$instrument_path/$res_manifest->{'run_id'}/$bam_file";
my $igv_script = '
$(document).ready(function () {
	var div = $("#igv_div"),
	options = {
	    showNavigation: true,
	    showRuler: true,
	    genome: "hg19",
	    locus: "'.$gene.'",
	    tracks: [
		{
		    name: "Genes",
		    type: "annotation",
		    format: "bed",
		    sourceType: "file",
		    url: "'.$REF_GENE_URI.'",
		    indexURL: "'.$REF_GENE_URI.'.tbi",
		    order: Number.MAX_VALUE,
		    visibilityWindow: 300000000,
		    displayMode: "EXPANDED"
		}	
	    ]
	};

	igv.createBrowser(div, options);

    });
';
print $q->div({'id' => 'igv_div', 'class' => 'container', 'style' => 'padding:5px; border:1px solid lightgray'}), $q->script({'type' => 'text/javascript'}, $igv_script);
#}
#, {
#			    url: \''.$bam_path.'\',
#			    name: \''.$id.$number.'-'.$analysis.'-'.$gene.'\'
#			}

##Basic end of USHVaM 2 perl scripts:

U2_modules::U2_subs_1::standard_end_html($q);

print $q->end_html();

exit();

##End of Basic end

##specific subs for current script
