BEGIN {delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV', 'PATH'};}

use strict;
#use CGI; #in startup.pl
#use DBI;
#use AppConfig qw(:expand :argcount);
use List::Util qw(first max maxstr min minstr reduce shuffle sum);;
use URI::Escape;
use HTTP::Request::Common;
use LWP::UserAgent;
use U2_modules::U2_users_1;
use U2_modules::U2_init_1;
use U2_modules::U2_subs_1;
use U2_modules::U2_subs_2;



#    This program is part of ushvam2, USHer VAriant Manager version 2
#    Copyright (C) 2012-2014  David Baux
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
#		page to display info on a given variant


##EXTENDED Basic init of USHVaM 2 perl scripts: INCLUDES easy-comments jqueryUI dalliance browser
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


my @styles = ($CSS_DEFAULT, $CSS_PATH.'jquery-ui-1.10.3.custom.min.css');

my $q = new CGI;

my $dbh = DBI->connect(    "DBI:Pg:database=$DB;host=$HOST;",
                        $DB_USER,
                        $DB_PASSWORD,
                        {'RaiseError' => 1}
                ) or die $DBI::errstr;

print $q->header(-type => 'text/html', -'cache-control' => 'no-cache'),
	$q->start_html(
			-title=>"U2 variant details",
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
			-script => [
				{-language => 'javascript',
				-src => $JS_PATH.'jquery-1.7.2.min.js'},
				{-language => 'javascript',
				-src => $JS_PATH.'jquery.fullsize.pack.js'},
				{-language => 'javascript',
				-src => $JS_PATH.'jquery.validate.min.js'},
				{-language => 'javascript',
				-src => $JS_PATH.'easy-comment/jquery.easy-comment.min.js'},
				{-language => 'javascript',
				-src => $JS_PATH.'jquery-ui-1.10.3.custom.min.js'},
				{-language => 'javascript',
				-src => $JS_PATH.'DIV_SRC.js'},
				{-language => 'javascript',
				-src => $JS_PATH.'dalliance_v0.13/build/dalliance-compiled.js'},
				{-language => 'javascript',
				-src => $JS_DEFAULT}],
			-encoding => 'ISO-8859-1');

my $user = U2_modules::U2_users_1->new();


U2_modules::U2_subs_1::standard_begin_html($q, $user->getName(), $dbh);

##end of Basic init

my ($gene, $second_name) = U2_modules::U2_subs_1::check_gene($q, $dbh);

my $acc = U2_modules::U2_subs_1::check_acc($q, $dbh);

my $var = U2_modules::U2_subs_1::check_nom_c($q, $dbh);

my $maf = '';


#old fashion when patient_genotype sent maf but after optimisation 04/09/2014 it was not possible (tried with json but no success)
#if ($q->param('maf') && $q->param('maf') =~ /([\/:\.\w\s-]+)/o) {$maf = $1; $maf =~ s/_/ /og;}

my $query = "SELECT *, a.nom_prot as protein FROM variant a, gene b WHERE a.nom_gene = b.nom AND a.nom_gene[1] = '$gene' AND a.nom_gene[2] = '$acc' AND a.nom = '$var';";
my $res = $dbh->selectrow_hashref($query);

$var =~ /(\w+\d)/og;
my $pos_cdna = $1;

#http://omim.org/search?index=entry&start=1&limit=10&search=ush2a&sort=score+desc%2C+prefix_sort+desc
#http://www.ncbi.nlm.nih.gov/nuccore/
my $ncbi_url = 'http://www.ncbi.nlm.nih.gov/nuccore/';

print $q->start_p({'class' => 'title'}), $q->start_big(), $q->start_strong(), $q->em({'onclick' => "gene_choice('$gene');", 'class' => 'pointer', 'title' => 'click to get somewhere'}, $gene), $q->span(' : '),
				$q->span({'onclick' => "window.open('$ncbi_url$acc.$res->{'acc_version'}', '_blank')", 'class' => 'pointer', 'title' => 'click to open Genbank in new tab'}, "$acc.$res->{'acc_version'}"), $q->span(":$var"),
				$q->br(), $q->br(), $q->span("($second_name / "), $q->span({'onclick' => "window.open('http://grch37.ensembl.org/Homo_sapiens/Transcript/Summary?db=core;t=$res->{'enst'}', '_blank')", 'class' => 'pointer', 'title' => 'click to open Ensembl in new tab'}, $res->{'enst'}), $q->span(')'),
				$q->end_strong(), $q->end_big(), $q->end_p(), "\n", $q->start_ul({'class' => 'menu_left ombre appear', 'id' => 'smart_menu'});
	#$q->start_li();
	
#EVS and LOVD - EVS later
#my ($evs_chr, $evs_pos_start, $evs_pos_end) = U2_modules::U2_subs_1::extract_pos_from_genomic($res->{'nom_g'}, 'evs');


###2015/02/11 LOVD put in ajax.pl
#my $url = "http://www.lovd.nl/search.php?build=hg19&position=chr$evs_chr:".$evs_pos_start."_".$evs_pos_end;
##print $var;
#my $ua = new LWP::UserAgent();
#$ua->timeout(10);
#my $response = $ua->get($url);



#c.13811+2T>G
#"hg_build"	"g_position"	"gene_id"	"nm_accession"	"DNA"	"variant_id"	"url"
#"hg19"	"chr1:215847440"	"USH2A"	"NM_206933.2"	"c.13811+2T>G"	"USH2A_00751"	"https://grenada.lumc.nl/LOVD2/Usher_montpellier/variants.php?select_db=USH2A&action=search_all&search_Variant%2FDBID=USH2A_00751"
#my $response = $ua->request($req);https://grenada.lumc.nl/LOVD2/Usher_montpellier/variants.php?select_db=MYO7A&action=search_all&search_Variant%2FDBID=MYO7A_00018


#my $lovd_semaph = 0;
#if($response->is_success()) {
#	my $escape_var = $var;
#	$escape_var =~ s/\+/\\\+/og;
#	if ($response->decoded_content() =~ /"$escape_var".+"(https[^"]+Usher_montpellier\/[^"]+)"/g) {print $q->start_a({'href' => $1, 'target' => '_blank'}), $q->img({'src' => $HTDOCS_PATH.'data/img/buttons/LOVD_button.png'}), $q->end_a();}
#	#if ($response->decoded_content() =~ /"(https:\/\/grenada\.lumc\.nl\/LOVD2\/Usher_montpellier\/[^"]+)"$/o) {print $q->start_a({'href' => $1, 'target' => '_blank'}), $q->img({'src' => $HTDOCS_PATH.'data/img/buttons/LOVD_button.png'}), $q->end_a();}
#	elsif ($response->decoded_content() =~ /"$escape_var".+"(http[^"]+)"$/g) {print $q->start_a({'href' => $1, 'target' => '_blank'}), $q->img({'src' => $HTDOCS_PATH.'data/img/buttons/LOVD_button.png'}), $q->end_a();}
#	else {$lovd_semaph = 1}
#}
#else {$lovd_semaph = 1}
#if ($lovd_semaph == 1) {
#	if (grep /$gene/, @U2_modules::U2_subs_1::LOVD) {
#		print $q->start_a({'href' => "https://grenada.lumc.nl/LOVD2/Usher_montpellier/variants.php?select_db=$gene&action=search_unique&order=Variant%2FDNA%2CASC&hide_col=&show_col=&limit=100&search_Variant%2FLocation=&search_Variant%2FExon=&search_Variant%2FDNA=$pos_cdna&search_Variant%2FRNA=&search_Variant%2FProtein=&search_Variant%2FDomain=&search_Variant%2FInheritance=&search_Variant%2FRemarks=&search_Variant%2FReference=&search_Variant%2FRestriction_site=&search_Variant%2FFrequency=&search_Variant%2FDBID=", 'target' => '_blank'}), $q->img({'src' => $HTDOCS_PATH.'data/img/buttons/LOVD_question_button.png'}), $q->end_a();
#	}
#	else {
#		print $q->start_a({'href' => "http://grenada.lumc.nl/LSDB_list/lsdbs/$gene", 'target' => '_blank'}), $q->img({'src' => $HTDOCS_PATH.'data/img/buttons/LOVD_question_button.png'}), $q->end_a();
#	}
#}
###end LOVD

##old fashion for LOVD - replaced with above code 	 2014/12/17
#if (grep /$gene/, @U2_modules::U2_subs_1::LOVD) {
#	print $q->start_a({'href' => "https://grenada.lumc.nl/LOVD2/Usher_montpellier/variants.php?select_db=$gene&action=search_unique&order=Variant%2FDNA%2CASC&hide_col=&show_col=&limit=100&search_Variant%2FLocation=&search_Variant%2FExon=&search_Variant%2FDNA=$pos_cdna&search_Variant%2FRNA=&search_Variant%2FProtein=&search_Variant%2FDomain=&search_Variant%2FInheritance=&search_Variant%2FRemarks=&search_Variant%2FReference=&search_Variant%2FRestriction_site=&search_Variant%2FFrequency=&search_Variant%2FDBID=", 'target' => '_blank'}), $q->img({'src' => $HTDOCS_PATH.'data/img/buttons/LOVD_button.png'}), $q->end_a();
#}
#else {
#	print $q->start_a({'href' => "http://grenada.lumc.nl/LSDB_list/lsdbs/$gene", 'target' => '_blank'}), $q->img({'src' => $HTDOCS_PATH.'data/img/buttons/LOVD_button.png'}), $q->end_a();
#}
##end old fashion


#print $q->end_li(), "\n";
#print $url;

##Mutation taster
if ($res->{'type_adn'} eq 'substitution' && $res->{'type_segment'} eq 'exon') {
	$var =~ /.+\>(\w)/o;
	print $q->start_li(),
		$q->start_a({'href' => "http://www.mutationtaster.org/cgi-bin/MutationTaster/MutationTaster69.cgi?gene=$gene&transcript_stable_id_text=$res->{'enst'}&sequence_type=CDS&position_be=$pos_cdna&new_base=$1&alteration_name=".$gene."_".uri_escape($var)."", 'target' => '_blank'}), $q->img({'src' => $HTDOCS_PATH.'data/img/buttons/mut_taster_button.png'}), $q->end_a(),
	$q->end_li(), "\n";
}
	
#HSF

#if pb try this 23/10/2014
#http://www.umd.be/HSF3/4DACTION/input_SSF?choix_analyse=ssf_batch&autoselect=yes&snp_select=yes&showonly=yes&geneStatus=all&transcriptStatus=all&nuclposition5=200&nuclposition3=200&choix_bdd=transcript_id&champlibre=ENST00000258930&batch=c.393G%3EA&paramfulltables=onlyvariants&fenetreintron=yes&fenetretaille=20&paramimages=yes&matrice_3=yes&Matrice=PSS&Matrice=maxent&seuil_maxent5=3&seuil_maxent3=3&Matrice=nnsplice&seuil_nnsplice5=0.4&seuil_nnsplice3=0.4&Matrice=BPS&Matrice=ESE%20Finder&seuil_sf2=72.98&seuil_sf2_esef=1.956&seuil_sf2ig=70.51&seuil_sf2ig_esef=1.867&seuil_sc35=75.05&seuil_sc35_esef=2.383&seuil_srp40=78.08&seuil_srp40_esef=2.67&seuil_srp55=73.86&seuil_srp55_esef=2.676&Matrice=RESCUE%20ESE&Matrice=ESE%20New&seuil_9g8=59.245&seuil_tra2=75.964&Matrice=Sironi&seuil_sironi1=60&seuil_sironi2=60&seuil_sironi3=60&Matrice=Decamers&Matrice=ESS%20hnRNP&seuil_hnrnpa1=65.476&Matrice=PESE&Matrice=ESR&Matrice=EIE



print $q->start_li(),
		$q->start_a({'href' => "http://www.umd.be/HSF/4DACTION/input_SSF?choix_analyse=ssf_batch&autoselect=yes&snp_select=yes&nuclposition5=200&nuclposition3=200&choix_bdd=transcript_id&texte=$res->{'enst'}&batch=".uri_escape($var)."&paramfulltables=onlyvariants&fenetreintron=yes&fenetretaille=20&paramimages=yes&showonly=no&matrice_3=yes&Matrice=PSS&Matrice=maxent&seuil_maxent5=0&seuil_maxent3=0&Matrice=BPS&Matrice=ESE%20finder&Matrice=RESCUE%20ESE&Matrice=ESE%20New&Matrice=Sironi&Matrice=Decamers&Matrice=ESS%20hnRNP&Matrice=PESE&Matrice=ESR&Matrice=EIE&seuil_sf2=72.98&seuil_sf2_esef=1.956&seuil_sf2ig=70.51&seuil_sf2ig_esef=1.867&seuil_sc35=75.05&seuil_sc35_esef=2.383&seuil_srp40=78.08&seuil_srp40_esef=2.67&seuil_srp55=73.86&seuil_srp55_esef=2.676&seuil_9g8=59.245&seuil_tra2=75.964&seuil_hnrnpa1=65.476&seuil_sironi1=60&seuil_sironi2=60&seuil_sironi3=60", 'target' => '_blank'}), $q->img({'src' => $HTDOCS_PATH.'data/img/buttons/HSF_button.png'}), $q->end_a(),
		#$q->start_a({'href' => "http://www.umd.be/HSF3/4DACTION/input_SSF?choix_analyse=ssf_batch&autoselect=yes&snp_select=yes&nuclposition5=200&nuclposition3=200&choix_bdd=transcript_id&champlibre=$res->{'enst'}&batch=".uri_escape($var)."&paramfulltables=onlyvariants&fenetreintron=yes&fenetretaille=20&paramimages=yes&showonly=no&matrice_3=yes&Matrice=PSS&Matrice=maxent&seuil_maxent5=0&seuil_maxent3=0&Matrice=BPS&Matrice=ESE%20finder&Matrice=RESCUE%20ESE&Matrice=ESE%20New&Matrice=Sironi&Matrice=Decamers&Matrice=ESS%20hnRNP&Matrice=PESE&Matrice=ESR&Matrice=EIE&seuil_sf2=72.98&seuil_sf2_esef=1.956&seuil_sf2ig=70.51&seuil_sf2ig_esef=1.867&seuil_sc35=75.05&seuil_sc35_esef=2.383&seuil_srp40=78.08&seuil_srp40_esef=2.67&seuil_srp55=73.86&seuil_srp55_esef=2.676&seuil_9g8=59.245&seuil_tra2=75.964&seuil_hnrnpa1=65.476&seuil_sironi1=60&seuil_sironi2=60&seuil_sironi3=60", 'target' => '_blank'}), $q->img({'src' => $HTDOCS_PATH.'data/img/buttons/HSF_button.png'}), $q->end_a(),
	$q->end_li(), "\n";

#USMA
my $USMA = {
	'MYO7A' => 1,
	'USH1C' => 1,
	'CDH23' => 1,
	'PCDH15' => 1,
	'USH1G' => 1,
	'USH2A' => 1,
	'GPR98' => 1,
	'DFNB31' => 1,
	'CLRN1' => 1,
};


if ($res->{'type_prot'} eq 'missense' && exists($USMA->{$gene})) {
	print $q->start_li(),
		$q->start_a({'href' => "https://neuro-2.iurc.montp.inserm.fr/cgi-bin/USMA/USMA.fcgi?gene=$gene&variant=".$res->{'protein'}."", 'target' => '_blank'}), $q->img({'src' => $HTDOCS_PATH.'data/img/buttons/USMA_button.png'}), $q->end_a(),
	$q->end_li(), "\n";
}


#print $q->start_li(),
#		$q->start_a({'href' => "http://www.ncbi.nlm.nih.gov/clinvar?term=".uri_escape("$res->{'acc_g'}:$res->{'nom_ng'}"), 'target' => '_blank'}), $q->img({'src' => '/ushvam2/data/img/buttons/clinvar_button.png'}), $q->end_a(),
#	$q->end_li(), "\n";

my ($evs_chr, $evs_pos_start, $evs_pos_end) = U2_modules::U2_subs_1::extract_pos_from_genomic($res->{'nom_g'}, 'evs');

print $q->start_li(),
	$q->start_a({'href' => "http://evs.gs.washington.edu/EVS/PopStatsServlet?searchBy=chromosome&chromosome=$evs_chr&chromoStart=$evs_pos_start&chromoEnd=$evs_pos_end&x=0&y=0", 'target' => '_blank'}), $q->img({'src' => $HTDOCS_PATH.'data/img/buttons/EVS_button.png'}), $q->end_a(), $q->end_li(), "\n";


#ExAC http://exac.broadinstitute.org/
if ($res->{'type_adn'} eq 'substitution') {
	my $exac = U2_modules::U2_subs_1::getExacFromGenoVar($res->{'nom_g'});
	if ($exac) {
		print $q->start_li(),
		$q->start_a({'href' => "http://exac.broadinstitute.org/variant/$exac", 'target' => '_blank'}), $q->img({'src' => $HTDOCS_PATH.'data/img/buttons/ExAC_button.png'}), $q->end_a(), $q->end_li(), "\n";
	}
}




#clinvar
#my ($clinvar_chr, $clinvar_pos) = U2_modules::U2_subs_1::extract_pos_from_genomic($res->{'nom_g'}, 'clinvar');

my $added = '';
if ($res->{'type_adn'} eq 'deletion' && $res->{'taille'} < 20 && $res->{'seq_mt'} =~ /-/o) {
	$added = U2_modules::U2_subs_1::get_deleted_sequence($res->{'seq_wt'});
}


print $q->start_li(),
		#$q->start_a({'href' => "http://www.ncbi.nlm.nih.gov/clinvar?term=".uri_escape("($clinvar_chr [Chromosome]) AND $clinvar_pos [Base Position]"), 'target' => '_blank'}), $q->img({'src' => $HTDOCS_PATH.'data/img/buttons/clinvar_button.png'}), $q->end_a(),
		$q->start_a({'href' => "http://www.ncbi.nlm.nih.gov/clinvar?term=".uri_escape("$acc.$res->{'acc_version'}:$var$added"), 'target' => '_blank'}), $q->img({'src' => $HTDOCS_PATH.'data/img/buttons/clinvar_button.png'}), $q->end_a(),
	$q->end_li(), "\n";




#fixed image on the right

print $q->img({'src' => $HTDOCS_PATH.'data/img/class.png', class => 'right ombre'});




##general info
# segment info
$query = "SELECT nom FROM segment WHERE numero = '$res->{'num_segment'}' AND nom_gene[1] = '$gene' AND nom_gene[2]  ='$acc';";
my $nom_seg = $dbh->selectrow_hashref($query);	

my $toprint = ucfirst($res->{'type_segment'});
if ($res->{'type_segment'} ne $nom_seg->{'nom'}) {$toprint .= " $nom_seg->{'nom'}"}

print $q->end_ul(), "\n",
	$q->start_div({'class' => 'decale'});


##genome browser
#http://www.biodalliance.org/
my $DALLIANCE_DATA_DIR_URI = '/dalliance_data/hg19/';
my ($dal_start, $dal_stop, $highlight_start, $highlight_end) = (($evs_pos_start-50), ($evs_pos_end+50), $evs_pos_start, $evs_pos_end);
if ($highlight_start == $highlight_end) {$highlight_end++}
##1000g p3
#ALL.chr10.phase3_shapeit2_mvncall_integrated_v3plus_nounphased.rsID.genotypes.vcf



my $browser = "
	console.log(\"creating browser with coords: chr$evs_chr:$dal_start-$dal_stop\" );
	var sources = [
		{name: 'Genome',
			desc: 'hg19/Grch37',
			twoBitURI: '".$DALLIANCE_DATA_DIR_URI."genome/hg19.2bit',
			tier_type: 'sequence',
			provides_entrypoints: true,
			pinned: true},
		{name: 'Genes',
			desc: 'GENCODE v19',
			bwgURI: '".$DALLIANCE_DATA_DIR_URI."gencode/gencode.v19.annotation.bb',
			stylesheet_uri: '".$DALLIANCE_DATA_DIR_URI."gencode/gencode-expanded.xml',
			collapseSuperGroups: true,
			trixURI: '".$DALLIANCE_DATA_DIR_URI."gencode/gencode.v19.annotation.ix'},
		{name: 'ClinVar',
			desc: 'ClinVar 06/2015',
			tier_type: 'tabix',
			payload: 'vcf',
			uri: '".$DALLIANCE_DATA_DIR_URI."clinvar/clinvar_20150603.vcf.gz'},
		{name: 'ExAC',
			desc: 'ExAC r0.3',
			tier_type: 'tabix',
			payload: 'vcf',
			noSourceFeatureInfo: true,
			uri: '".$DALLIANCE_DATA_DIR_URI."exac/ExAC.r0.3.sites.vep.vcf.gz'},
		//{name: '1000g',
		//	desc: '1000 genomes phase 3',
		//	tier_type: 'tabix',
		//	payload: 'vcf',
		//	uri: '".$DALLIANCE_DATA_DIR_URI."1000g_p3/ALL.chr$evs_chr.phase3_shapeit2_mvncall_integrated_v3plus_nounphased.rsID.genotypes.vcf.gz'},
		{name: '1000g',
			desc: '1000 genomes phase 3',
			tier_type: 'tabix',
			payload: 'vcf',
			uri: '".$DALLIANCE_DATA_DIR_URI."1000g_p3/1000GENOMES-phase_3.vcf.gz'},
		{name: 'Conservation',
			desc: 'PhastCons 100 way',
			bwgURI: '".$DALLIANCE_DATA_DIR_URI."cons/hg19.100way.phastCons.bw',
			noDownsample: true},
		{name: 'Repeats',
			desc: 'Repeat annotation from RepeatMasker', 
			bwgURI: '".$DALLIANCE_DATA_DIR_URI."repeats/repeats.bb',
			stylesheet_uri: '".$DALLIANCE_DATA_DIR_URI."repeats/bb-repeats2.xml',
			forceReduction: -1},
		{name: 'dbSNP',
			desc: 'dbSNP142',
			tier_type: 'tabix',
			payload: 'vcf',
			uri: '".$DALLIANCE_DATA_DIR_URI."dbSNP142/All_20150415.vcf.gz'},
	];
	var browser = new Browser({
		chr:		'$evs_chr',
		viewStart:	$dal_start,
		viewEnd:	$dal_stop,
		cookieKey:	'human-grc_h37',
		prefix:		'".$JS_PATH."dalliance_v0.13/',
		fullScreen:	false,
		noPersist:	true,
		noPersistView:	true,
		maxHeight:	500,

		coordSystem:	{
			speciesName: 'Human',
			taxon: 9606,
			auth: 'GRCh',
			version: '37',
			ucscName: 'hg19'
		},
		sources:	sources,
		hubs:	['http://ftp.ebi.ac.uk/pub/databases/ensembl/encode/integration_data_jan2011/hub.txt']
	});
	
	function highlightRegion(){
		console.log(\" xx highlight region chr$evs_chr,$dal_start,$dal_stop\");
		browser.highlightRegion('chr$evs_chr',$highlight_start,$highlight_end);
		browser.setLocation(\"$evs_chr\",$dal_start,$dal_stop);
	}

	browser.addInitListener( function(){
		console.log(\"dalliance initiated\");
		//setTimeout(highlightRegion(),5000);
		highlightRegion();
	});
";

print $q->br(), $q->script({'type' => 'text/javascript'}, $browser), $q->div({'id' => 'svgHolder', 'class' => 'fitin'}, 'Dalliance Browser here'), $q->br(), $q->br();

	
print		$q->start_ul(),
			$q->start_li(), $q->a({'href' => 'https://mutalyzer.nl/check?name='.uri_escape("$res->{'acc_g'}($gene$res->{'mutalyzer_version'}):$var"), 'target' => '_blank'}, 'Mutalyzer'), $q->end_li(), $q->br(), "\n",
			$q->start_li(), $q->span($toprint);
my $chevauchant = 0;
if (($res->{'num_segment_end'} != $res->{'num_segment'}) || ($res->{'type_segment_end'} ne $res->{'type_segment'})) {
	$query = "SELECT nom FROM segment WHERE numero = '$res->{'num_segment_end'}' AND nom_gene[1] = '$gene' AND nom_gene[2]  ='$acc';";
	my $nom_seg_end = $dbh->selectrow_hashref($query);
	print $q->span(" until $res->{'type_segment_end'}: $nom_seg_end->{'nom'}");
	$chevauchant = 1;
	my $lrname = U2_modules::U2_subs_2::create_lr_name($res, $dbh);
	print $q->strong(" - $lrname")
}
print $q->end_li(), $q->br(), "\n";

#size
if ($res->{'taille'} > 1) {print $q->li("Size: $res->{'taille'} bp"), $q->br(),"\n"}

#IVS name
if ($res->{'nom_ivs'} ne '') {print $q->li("$acc.$res->{'acc_version'}:$res->{'nom_ivs'}"), $q->br(), "\n"}

#RNA status
print $q->start_li(), $q->span('RNA impact: '), $q->span({'id' => 'type_arn', 'style' => 'color:'.U2_modules::U2_subs_1::color_by_rna_status($res->{'type_arn'}, $dbh).';'}, $res->{'type_arn'});#, $q->span(' (in progress)');
#check if pdf for splicing
if (-d $ABSOLUTE_HTDOCS_PATH.'/data/splicing') {#if splicing module
	#pdfs stored under format: gene_variantwithoutc..pdf
	my $splicing_var = $var;
	$splicing_var =~ s/c\.//og;
	if (-f $ABSOLUTE_HTDOCS_PATH.'/data/splicing/'.$gene.'_'.$splicing_var.'.pdf') {#if pdf for variant
		print $q->span(" (confirmed), check "), $q->a({'href' => $HTDOCS_PATH.'/data/splicing/'.$gene.'_'.$splicing_var.'.pdf', 'target' => "_blank"}, 'analysis');
	}
	else {print $q->span(' (inferred)')}
}

#button to change RNA status for validators
if ($user->isValidator == 1) {
	#print button which opens popup which calls ajax
	my $html = &menu_rna_status($res->{'type_arn'}, $q, $dbh);
	my $js = "
		function rnaStatusForm() {
			var \$dialog_rna_status = \$('<div></div>')
				.html('$html')
				.dialog({
				    autoOpen: false,
				    title: 'Change RNA status for $gene $var:',
				    width: 450,
				    buttons: {
					\"Change\": function() {
						\$.ajax({
							type: \"POST\",
							url: \"ajax.pl\",
							data: {nom_c: '".uri_escape($var)."', gene: '$gene', accession: '$acc', rna_status: \$(\"#rna_status_select\").val(), asked: 'rna_status'}
						})
						.done(function(status) {
							location.reload();
							//alert(status);
							//\$(\"#type_arn\").html(status);	
							//if (status === 'neutral') {
							//	\$(\"#type_arn\").css('color', '#00A020');
							//	\$(\"#rna_status_select\").val('neutral').change();
							//}
							//else {
							//	\$(\"#type_arn\").css('color', '#FF0000');
							//	\$(\"#rna_status_select\").val('altered').change();
							//}
							//var col = new RegExp(\"#[A-Z0-9]+\");
							//var classe = new RegExp(\"[a-zA-Z ]+\");
							//\$(\"#variant_class\").html(classe+class_col);
							//\$(\"#variant_class\").html(classe.exec(class_col)+'');
							//\$(\"#variant_class\").css(\"color\", \"\");							
							//\$(\"#variant_class\").css(\"color\", \"col.exec(class_col)+''\");
							//\$(this).dialog(\"close\"); //DOES NOT WANT TO CLOSE
							//\$(\".ui-dialog-content\").dialog(\"close\"); //YES - CLOSE ALL DIALOGS
						});
					},
					Cancel: function() {
						\$(this).dialog(\"close\");
					}
				    }
				});
			\$dialog_rna_status.dialog('open');
			\$('.ui-dialog').zIndex('1002');
		};";
	print $q->span('&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'), $q->script({'type' => 'text/javascript'}, $js), $q->button({'id' => 'rna_status_button', 'value' => 'Change RNA status', 'onclick' => 'rnaStatusForm();'}), "\n";
}
print $q->end_li(), $q->br(), "\n";

#distance from exon/intron junction for exonic variants
if ($res->{'type_segment'} eq 'exon') {
	my ($dist, $site) = U2_modules::U2_subs_1::get_pos_from_intron($res, $dbh);
	if ($dist <= 3 && $dist >= 0) {print $q->start_li(), $q->strong("Potential impact on splicing: $dist bp from $site site"), $q->end_li()}
	elsif ($site eq 'overlap') {print $q->start_li(), $q->strong("Overlaps exon/intron junction"), $q->end_li()}
	elsif ($site eq 'middle') {print $q->li("Middle of exon, $dist from junctions")}
	else {print $q->li("$dist bp from $site site")}
	print $q->br();
}


#protein name - domain
if ($res->{'protein'} ne '') {
	print $q->start_li(), $q->span({'onclick' => "window.open('$ncbi_url$res->{'acc_p'}', '_blank')", 'class' => 'pointer', 'title' => 'click to open Genbank in new tab'}, $res->{'acc_p'}), $q->span(":$res->{'protein'}");#, $q->br(), "\n";
	
	#access to missense analyses
	#TODO: old fashion ushvam to be updated
	if ($res->{'type_prot'} eq 'missense' || $res->{'type_prot'} =~ /inframe/) {
		my $u1_gene = $gene;
		if ($u1_gene eq 'GPR98') {$u1_gene = 'VLGR1'}
		elsif ($u1_gene eq 'CLRN1') {$u1_gene = 'USH3A'}
		
		my $one_letter = U2_modules::U2_subs_1::nom_three2one($res->{'protein'});
		if (-f "/Library/WebServer/Documents/USHVaM/data/faux-sens/$u1_gene/$one_letter.pdf") {
			print $q->span(", check "), $q->a({'href' => "/USHVaM/data/faux-sens/$u1_gene/$one_letter.pdf", 'target' => "_blank"}, 'analysis');	
		}
	}
	if ($res->{'type_prot'} eq 'missense') {
		my $missense_js = "
			function getPonps() {
				\$.ajax({
					type: \"POST\",
					url: \"ajax.pl\",
					data: {asked: 'ponps', var_prot: '$res->{'protein'}', ensp: '$res->{'ensp'}', nom_g: '$res->{'nom_g'}', acc_no : '$acc', enst: '$res->{'enst'}', nom_c: '$var', gene: '$gene'}
				})
				.done(function(msg) {					
					\$('#ponps').html('<ul>'+msg+'</ul>');
				});
			};";
		print $q->script({'type' => 'text/javascript'}, $missense_js), $q->span('&nbsp;&nbsp;&nbsp;'), $q->start_span({'id' => 'ponps'}), $q->button({'value' => 'Get predictors', 'onclick' => 'getPonps();$(\'#ponps\').html("Please wait...");'}), $q->end_span();
	}
	
	print $q->end_li(), $q->br(), "\n";
	
	if ($res->{'protein'} =~ /(\d+)_\w{3}(\d+)/og) {
		my ($pos1, $pos2) = ($1, $2);
		$query = "SELECT nom FROM domaine WHERE nom_prot = '$res->{'short_prot'}' AND ((aa_deb BETWEEN $pos1 AND $pos2) OR (aa_fin BETWEEN $pos1 AND $pos2));";
		my $sth_dom = $dbh->prepare($query);
		my $res_dom = $sth_dom->execute();
		if ($res_dom ne '0E0') {
			my $txt_dom;
			while (my $result = $sth_dom->fetchrow_hashref()) {
				$txt_dom .= $result->{'nom'}.", ";
			}
			chop($txt_dom);
			chop($txt_dom);
			print $q->li($txt_dom), $q->br(), "\n";
		}
		else {print $q->li('no domain'), $q->br(), "\n"}
		
		#
		#
		#$query = "SELECT nom FROM domaine WHERE nom_prot = '$res->{'nom_prot'}' AND $pos1 BETWEEN aa_deb AND aa_fin;";
		#my $dom1 = $dbh->selectrow_hashref($query);
		#$query = "SELECT nom FROM domaine WHERE nom_prot = '$res->{'nom_prot'}' AND $pos2 BETWEEN aa_deb AND aa_fin;";
		#my $dom2 = $dbh->selectrow_hashref($query);
		#if ($dom1->{'nom'} eq '') {$dom1->{'nom'} = 'no domain'}
		#if ($dom2->{'nom'} eq '') {$dom2->{'nom'} = 'no domain'}
		#if ($dom1 ne $dom2) {print $q->li("$dom1->{'nom'} to $dom2->{'nom'}"), $q->br(), "\n"}
		#else {print $q->li("$dom1->{'nom'}"), $q->br(), "\n"}
	}
	elsif ($res->{'protein'} =~ /(\d+)/og) {
		my $pos = $1;
		$query = "SELECT nom FROM domaine WHERE nom_prot = '$res->{'short_prot'}' AND $pos BETWEEN aa_deb AND aa_fin;";
		my $sth_dom = $dbh->prepare($query);
		my $res_dom = $sth_dom->execute();
		if ($res_dom ne '0E0') {
			my $txt_dom;
			while (my $result = $sth_dom->fetchrow_hashref()) {
				$txt_dom .= $result->{'nom'}.", ";
			}
			chop($txt_dom);
			chop($txt_dom);
			print $q->li($txt_dom), $q->br(), "\n";
		}
		else {print $q->li('no domain'), $q->br(), "\n"}
		
		
		
		#my $dom = $dbh->selectrow_hashref($query);
		#if ($dom->{'nom'} eq '') {$dom->{'nom'} = 'no domain'}
		#print $q->li("$dom->{'nom'}"), $q->br(), "\n";
	}
}

#ng name, genomic name, class  clinvarMain=hide&clinvarCnv=dense
my $ucsc_link = "http://genome-euro.ucsc.edu/cgi-bin/hgTracks?db=hg19&position=chr$evs_chr%3A$evs_pos_start-$evs_pos_end&hgS_doOtherUser=submit&hgS_otherUserName=david.baux&hgS_otherUserSessionName=U2&ruler=full&knownGene=full&refGene=full&pubs=pack&lovd=pack&hgmd=pack&cons100way=full&snp142=dense&ucscGenePfam=full&omimGene2=full&tgpPhase1=dense&evsEsp6500=dense&exac=dense&dgvPlus=dense&allHg19RS_BW=full&highlight=hg19.chr$evs_chr%3A$evs_pos_start-$evs_pos_end";

#http://www.rcsb.org/pdb/chromosome.do?v=hg37&chromosome=chrX&pos=106888516
#map2pdb
my $map2pdb = '';
if ($res->{'taille'} < 100) {
	$map2pdb = $q->span("&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;").$q->a({'href' => "http://www.rcsb.org/pdb/chromosome.do?v=hg37&chromosome=$evs_chr&pos=$evs_pos_start", 'target' => '_blank'}, 'Map2PDB');
}

my $js = "
	function getAllNom() {
		\$.ajax({
			type: \"POST\",
			url: \"ajax.pl\",
			data: {asked: 'var_nom', nom_g: '$res->{'nom_g'}', accession: '$acc', nom_c: '$var', gene: '$gene'}
		})
		.done(function(msg) {					
			\$('#mutalyzer_place').html(msg);
		});
	};";


print $q->start_li(), $q->span({'onclick' => "window.open('$ncbi_url$res->{'acc_g'}', '_blank')", 'class' => 'pointer', 'title' => 'click to open Genbank in new tab'}, $res->{'acc_g'}), $q->span(":$res->{'nom_ng'}"), $q->end_li(), $q->br(), $q->start_li({'id' => 'nom_g'}), "\n",
	$q->span("$res->{'nom_g'}&nbsp;&nbsp;"), $q->a({'href' => $ucsc_link, 'target' => '_blank'}, 'UCSC'), $map2pdb, $q->end_li(), $q->br(), "\n",
	$q->start_li(), $q->span({'id' => 'mutalyzer_place'}), $q->script({'type' => 'text/javascript'}, $js), $q->button({'id' => 'all_nomenclature', 'value' => 'Other nomenclatures', 'onclick' => 'getAllNom();$(\'#mutalyzer_place\').html("Please wait while mutalyzer is checking...");'}), $q->end_li(), $q->br(), "\n",
	$q->start_li(), $q->span({'id' => 'variant_class', 'style' => 'color:'.U2_modules::U2_subs_1::color_by_classe($res->{'classe'}, $dbh).';'}, $res->{'classe'});
	
	#change class
#need to be validator
if ($user->isValidator == 1) {
	#print button which opens popup which calls ajax
	my $html = &menu_class($res->{'classe'}, $q, $dbh);
	$js = "
		function classForm() {
			var \$dialog_class = \$('<div></div>')
				.html('$html')
				.dialog({
				    autoOpen: false,
				    title: 'Change class for $gene $var:',
				    width: 450,
				    buttons: {
					\"Change\": function() {
						\$.ajax({
							type: \"POST\",
							url: \"ajax.pl\",
							data: {nom_c: '".uri_escape($var)."', gene: '$gene', accession: '$acc', class: \$(\"#class_select\").val(), asked: 'class'}
						})
						.done(function() {
							location.reload();
							//var col = new RegExp(\"#[A-Z0-9]+\");
							//var classe = new RegExp(\"[a-zA-Z ]+\");
							//\$(\"#variant_class\").html(classe+class_col);
							//\$(\"#variant_class\").html(classe.exec(class_col)+'');
							//\$(\"#variant_class\").css(\"color\", \"\");							
							//\$(\"#variant_class\").css(\"color\", \"col.exec(class_col)+''\");
							//\$(this).dialog(\"close\"); //DOES NOT WANT TO CLOSE
							//\$(\".ui-dialog-content\").dialog(\"close\"); //YES - CLOSE ALL DIALOGS
						});
					},
					Cancel: function() {
						\$(this).dialog(\"close\");
					}
				    }
				});
			\$dialog_class.dialog('open');
			\$('.ui-dialog').zIndex('1002');
		};";
	print $q->span('&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'), $q->script({'type' => 'text/javascript'}, $js), $q->button({'id' => 'class_button', 'value' => 'Change class', 'onclick' => 'classForm();'})
	#print $q->start_li(), $q->script({'type' => 'text/javascript'}, $js), $q->button({'id' => 'class_button', 'value' => 'Change class', 'onclick' => 'classForm();'}), $q->end_li(), $q->br(), "\n";
}
	
	
print $q->end_li(), $q->br(), "\n";

#dbSNP

if ($res->{'snp_id'} ne '') {
	my $snp_common = "SELECT common FROM restricted_snp WHERE rsid = '$res->{'snp_id'}';";
	my $res_common = $dbh->selectrow_hashref($snp_common);
	print $q->start_li(), $q->a({'href' => "http://www.ncbi.nlm.nih.gov/SNP/snp_ref.cgi?rs=$res->{'snp_id'}", 'target' => '_blank'}, $res->{'snp_id'});
	if ($res_common->{'common'} && $res_common->{'common'} == 1) {print $q->span('    in common dbSNP142 variant set (MAF > 0.01)')}
}
else {print $q->start_li(), $q->span("Not reported in dbSNP142")}
print $q->end_li(), $q->br(), "\n";

#1000 genomes

print $q->li({'id' => 'ext_data'}, 'loading external data...'), $q->br(), "\n";


#infos on cohort: # of seen, MAFS, 454: mean depth, mean freq, mean f/r

my ($maf_454, $maf_sanger, $maf_miseq) = ('NA', 'NA', 'NA');
if ($maf eq '') {	
	#MAF 454
	$maf_454 = U2_modules::U2_subs_1::maf($dbh, $gene, $acc, $var, '454-\d+');
	#MAF SANGER
	$maf_sanger = U2_modules::U2_subs_1::maf($dbh, $gene, $acc, $var, 'SANGER');
	#MAF MISEQ
	$maf_miseq = U2_modules::U2_subs_1::maf($dbh, $gene, $acc, $var, 'MiSeq-\d+');
	$maf = "MAF 454: $maf_454 / MAF Sanger: $maf_sanger / MAF MiSeq: $maf_miseq";	
}
else {
	$maf =~ /MAF\s454:\s([\w\.]+)\s\/.+/o;
	$maf_454 = $1;
}
print $q->li($maf), $q->br(), "\n";

###TO DO mean freq and doc for MiSeq

if ($maf_454 ne 'NA') {	
	my $query_454 = "SELECT AVG(depth) as a, AVG(frequency) as b, AVG(wt_f) as c, AVG(wt_r) as d, AVG(mt_f) as e, AVG(mt_r) as f, COUNT(nom_c) as g FROM variant2patient WHERE type_analyse LIKE '454-%' AND nom_gene[1] = '$gene' AND nom_gene[2] = '$acc' AND nom_c = '$var';";
	my $res_454 = $dbh->selectrow_hashref($query_454);
	print $q->start_li(), $q->span("454 mean values: (seen in $res_454->{'g'} runs)"),
		$q->start_ul(),
			$q->li("depth: ".sprintf('%.2f', $res_454->{'a'})), "\n",
			$q->li("frequency: ".sprintf('%.2f', $res_454->{'b'})), "\n",
			$q->li("forward reads (wt+mt): ".sprintf('%.2f',($res_454->{'c'}+$res_454->{'e'}))), "\n",
			$q->li("reverse reads (wt+mt):  ".sprintf('%.2f',($res_454->{'d'}+$res_454->{'f'}))), "\n",
		$q->end_ul(),
		$q->end_li(), $q->br(), "\n";
}
if ($maf_miseq ne 'NA') {
	my $query_miseq = "SELECT AVG(depth) as a, AVG(frequency) as b, COUNT(nom_c) as c FROM variant2patient WHERE type_analyse LIKE 'MiSeq-%' AND nom_gene[1] = '$gene' AND nom_gene[2] = '$acc' AND nom_c = '$var';";
	my $res_miseq = $dbh->selectrow_hashref($query_miseq);
	print $q->start_li(), $q->span("MiSeq mean values: (seen in $res_miseq->{'c'} samples)"),
		$q->start_ul(),
			$q->li("depth: ".sprintf('%.2f', $res_miseq->{'a'})), "\n",
			$q->li("frequency: ".sprintf('%.2f', $res_miseq->{'b'})), "\n";
	$query_miseq = "SELECT msr_filter, num_pat, id_pat FROM variant2patient WHERE type_analyse LIKE 'MiSeq-%' AND nom_gene[1] = '$gene' AND nom_gene[2] = '$acc' AND nom_c = '$var';";	
	my $sth = $dbh->prepare($query_miseq);
	$res_miseq = $sth->execute();
	my $pass = 0;
	my $other;
	while (my $result = $sth->fetchrow_hashref()) {
		if ($result->{'msr_filter'} eq 'PASS') {$pass++}
		else {$other->{$result->{'msr_filter'}} .= $q->span("   ").$q->a({'href' => "patient_genotype.pl?sample=$result->{'id_pat'}$result->{'num_pat'}&gene=$gene", 'target' => '_blank'}, $result->{'id_pat'}.$result->{'num_pat'})}		
	}
	print $q->start_li(), $q->span('Filter summary:'), $q->start_ul(),
		$q->li("PASS in $pass samples");
	foreach my $key (keys(%{$other})) {print $q->start_li(), $q->span("$key: "), $other->{$key}, $q->end_li()}
	print $q->end_ul(),
		$q->end_li(),
		$q->end_ul(),
		$q->end_li(), $q->br(), "\n";
}



$query = "SELECT DISTINCT(num_pat), id_pat, statut FROM variant2patient WHERE nom_gene[1] = '$gene' AND nom_gene[2] = '$acc' AND nom_c = '$var' ORDER BY num_pat;";
my $sth = $dbh->prepare($query);
my $res_seen = $sth->execute();

my $seen;
my $hom = 0;

while (my $result = $sth->fetchrow_hashref()) {
	if ($result->{'statut'} eq 'homozygous') {$hom += 2}
	#if ($result->{'filter'} eq 'RP' && $result->{'dfn'} == 1) {next}
	#elsif ($result->{'filter'} eq 'DFN' && $result->{'rp'} == 1) {next}
	$seen .= $q->start_div().$q->span("-$result->{'id_pat'}$result->{'num_pat'} ($result->{'statut'})&nbsp;&nbsp;").$q->start_a({'href' => "patient_file.pl?sample=$result->{'id_pat'}$result->{'num_pat'}", 'target' => '_blank'}).$q->span('patient&nbsp;&nbsp;').$q->img({'src' => $HTDOCS_PATH.'data/img/link_small.png', 'border' => '0', 'width' =>'15'}).$q->end_a().$q->span('&nbsp;&nbsp;&nbsp;').$q->start_a({'href' => "patient_genotype.pl?sample=$result->{'id_pat'}$result->{'num_pat'}&gene=$gene", 'target' => '_blank'}).$q->span('genotype&nbsp;&nbsp;').$q->img({'src' => $HTDOCS_PATH.'data/img/link_small.png', 'border' => '0', 'width' =>'15'}).$q->end_a().$q->end_div();	
}

$query = "SELECT DISTINCT(a.num_pat), a.id_pat, a.statut, b.filter, c.rp, c.dfn, c.usher, c.nom FROM variant2patient a, miseq_analysis b, gene c WHERE a.num_pat = b.num_pat AND a.id_pat = b.id_pat AND a.type_analyse = b.type_analyse AND a.nom_gene = c.nom AND a.nom_gene[1] = '$gene' AND a.nom_gene[2] = '$acc' AND a.nom_c = '$var' AND b.filter <> 'ALL' ORDER BY a.num_pat;";
$sth = $dbh->prepare($query);
my $res_filter = $sth->execute();
while (my $result = $sth->fetchrow_hashref()) {
	
	if ($result->{'filter'} eq 'RP' && ($result->{'rp'} == 1 && $result->{'usher'} == 0)) {next}
	elsif ($result->{'filter'} eq 'DFN' && ($result->{'dfn'} == 1 && $result->{'usher'} == 0)) {next}
	elsif ($result->{'filter'} eq 'USH' && $result->{'usher'} == 1) {next}
	elsif ($result->{'filter'} eq 'DFN-USH' && ($result->{'dfn'} == 1 || $result->{'usher'} == 1)) {next}
	elsif ($result->{'filter'} eq 'RP-USH' && ($result->{'rp'} == 1 || $result->{'usher'} == 1)) {next}
	elsif ($result->{'filter'} eq 'CHM' && $result->{'nom_gene'} eq 'CHM') {next}
	else {
		#print "1-$result->{'id_pat'}$result->{'num_pat'}-$result->{'statut'}-$seen-<br/>";
	#if ((($result->{'filter'} eq 'RP' && $result->{'dfn'} == 1) || ($result->{'filter'} eq 'DFN' && $result->{'rp'} == 1)) && $result->{'usher'} == 0) {
		#<div><span>SU11 (heterozygous)&nbsp;&nbsp;</span><a target="_blank" href="patient_file.pl?sample=SU11"><span>patient&nbsp;&nbsp;</span><img width="15" src="/ushvam2/data/img/link_small.png" border="0" /></a><span>&nbsp;&nbsp;&nbsp;</span><a target="_blank" href="patient_genotype.pl?sample=SU11&amp;gene=DFNB31"><span>genotype&nbsp;&nbsp;</span><img width="15" src="/ushvam2/data/img/link_small.png" border="0" /></a></div>
		#<div><span>SU3905 (heterozygous)&nbsp;&nbsp;</span><a target="_blank" href="patient_file.pl?sample=SU3905"><span>patient&nbsp;&nbsp;</span><img width="15" src="/ushvam2/data/img/link_small.png" border="0" /></a><span>&nbsp;&nbsp;&nbsp;</span><a target="_blank" href="patient_genotype.pl?sample=SU3905&amp;gene=CDH23"><span>genotype&nbsp;&nbsp;</span><img width="15" src="/ushvam2/data/img/link_small.png" border="0" /></a></div>
		$seen =~ s/<div><span>-$result->{'id_pat'}$result->{'num_pat'} \($result->{'statut'}\)&nbsp;&nbsp;<\/span><a target="_blank" href="patient_file\.pl\?sample=$result->{'id_pat'}$result->{'num_pat'}"><span>patient&nbsp;&nbsp;<\/span><img width="15" src="\/ushvam2\/data\/img\/link_small.png" border="0" \/><\/a><span>&nbsp;&nbsp;&nbsp;<\/span><a target="_blank" href="patient_genotype.pl\?sample=$result->{'id_pat'}$result->{'num_pat'}&amp;gene=$result->{'nom'}[0]"><span>genotype&nbsp;&nbsp;<\/span><img width="15" src="\/ushvam2\/data\/img\/link_small\.png" border="0" \/><\/a><\/div>/<div>-filtered patient<\/div>/g;
		#print "2-$result->{'id_pat'}$result->{'num_pat'}-$result->{'statut'}-$seen-<br/>";
	}
}
###CHANGED 03/25/2015 david for filters
#my $seen;
#my $hom = 0;
#
#$query = "SELECT DISTINCT(a.num_pat), a.id_pat, a.statut, b.filter, c.rp, c.dfn, c.usher, c.nom FROM variant2patient a, miseq_analysis b, gene c WHERE a.num_pat = b.num_pat AND a.id_pat = b.id_pat AND a.type_analyse = b.type_analyse AND a.nom_gene = c.nom AND a.nom_gene[1] = '$gene' AND a.nom_gene[2] = '$acc' AND a.nom_c = '$var' ORDER BY a.num_pat;";
#print $query;
#my $sth = $dbh->prepare($query);
#my $res_seen = $sth->execute();
#while (my $result = $sth->fetchrow_hashref()) {
#	if ($result->{'statut'} eq 'homozygous') {$hom += 2}
#	#print "<p>-$result->{'filter'}-</p>";
#	if ($result->{'filter'} eq 'RP' && $result->{'rp'} == 0) {next}
#	elsif ($result->{'filter'} eq 'DFN' && $result->{'dfn'} == 0) {next}
#	elsif ($result->{'filter'} eq 'USH' && $result->{'usher'} == 0) {next}
#	elsif ($result->{'filter'} eq 'DFN-USH' && ($result->{'dfn'} == 0 && $result->{'usher'} == 0)) {next}
#	elsif ($result->{'filter'} eq 'RP-USH' && ($result->{'rp'} == 0 && $result->{'usher'} == 0)) {next}
#	elsif ($result->{'filter'} eq 'CHM' && $result->{'nom_gene'} ne 'CHM') {next}
#	else {
#		$seen .= $q->start_div().$q->span("$result->{'id_pat'}$result->{'num_pat'} ($result->{'statut'})&nbsp;&nbsp;").$q->start_a({'href' => "patient_file.pl?sample=$result->{'id_pat'}$result->{'num_pat'}", 'target' => '_blank'}).$q->span('patient&nbsp;&nbsp;').$q->img({'src' => $HTDOCS_PATH.'data/img/link_small.png', 'border' => '0', 'width' =>'15'}).$q->end_a().$q->span('&nbsp;&nbsp;&nbsp;').$q->start_a({'href' => "patient_genotype.pl?sample=$result->{'id_pat'}$result->{'num_pat'}&gene=$gene", 'target' => '_blank'}).$q->span('genotype&nbsp;&nbsp;').$q->img({'src' => $HTDOCS_PATH.'data/img/link_small.png', 'border' => '0', 'width' =>'15'}).$q->end_a().$q->end_div();
#	}
#}






$query = "SELECT COUNT(DISTINCT(num_pat)) as a FROM variant2patient WHERE type_analyse LIKE '454-%' AND nom_gene[1] = '$gene' AND nom_gene[2] = '$acc' AND nom_c = '$var';";
my $res_seen_454 = $dbh->selectrow_hashref($query);

$query = "SELECT COUNT(DISTINCT(num_pat))*2 as a FROM variant2patient WHERE type_analyse LIKE '454-%' AND nom_gene[1] = '$gene' AND nom_gene[2] = '$acc' AND nom_c = '$var' AND statut = 'homozygous';";
my $hom_454 = $dbh->selectrow_hashref($query);

$query = "SELECT COUNT(DISTINCT(num_pat)) as a FROM variant2patient WHERE type_analyse LIKE 'MiSeq-%' AND nom_gene[1] = '$gene' AND nom_gene[2] = '$acc' AND nom_c = '$var';";
my $res_seen_miseq = $dbh->selectrow_hashref($query);

$query = "SELECT COUNT(DISTINCT(num_pat))*2 as a FROM variant2patient WHERE type_analyse LIKE 'MiSeq-%' AND nom_gene[1] = '$gene' AND nom_gene[2] = '$acc' AND nom_c = '$var' AND statut = 'homozygous';";
my $hom_miseq = $dbh->selectrow_hashref($query);

print $q->start_li(), $q->span("seen in ".($res_seen+($hom/2))." alleles in total (including $hom homozygous) (homozygous = 2 alleles)"),
	$q->start_ul(), $q->li("including ".($res_seen_454->{'a'}+($hom_454->{'a'}/2))." alleles in 454 context ($hom_454->{'a'} homozygous)"),
	$q->li("including ".($res_seen_miseq->{'a'}+($hom_miseq->{'a'}/2))." alleles in MiSeq context ($hom_miseq->{'a'} homozygous)"), $q->end_ul(), $q->end_li(), $q->br(), "\n";

#patient list

$js = "
	function getPatients() {
		var \$dialog = \$('<div></div>')
			.html('$seen')
			.dialog({
			    autoOpen: false,
			    title: 'Patients carrying $var:',
			    width: 450
			});
		\$dialog.dialog('open');
	};";

print $q->start_li(), $q->script({'type' => 'text/javascript'}, $js), $q->button({'id' => 'patient_list', 'value' => 'Patient list', 'onclick' => 'getPatients();'}), $q->end_li(), $q->br(), "\n";

#sequence
if ($res->{'seq_wt'} ne "") {
	print $q->start_li(), $q->span("Wild-type sequence:"), $q->br(), $q->span({'class' => 'txt'}, $res->{'seq_wt'}), $q->end_li(), "\n",
		$q->start_li(), $q->span("Mutant sequence:"), $q->br(), $q->span({'class' => 'txt'}, $res->{'seq_mt'}), $q->end_li(), $q->br(), "\n";
}

#if ($user->getName() eq 'david') {
#
##genome browser
##http://www.biodalliance.org/
#my $DALLIANCE_DATA_DIR_URI = '/dalliance_data/hg19/';
#my $browser = "
#	console.log(\"creating browser with coords: chr$evs_chr:".($evs_pos_start-20)."-".($evs_pos_end+20)."\" );
#	var sources = [
#		{name: 'Genome',
#		twoBitURI: '".$DALLIANCE_DATA_DIR_URI."genome/hg19.2bit',
#                tier_type: 'sequence',
#		provides_entrypoints: true,
#                pinned: true},
#		{name: 'GENCODE version 19',
#		bwgURI: '".$DALLIANCE_DATA_DIR_URI."gencode/gencode.v19.annotation.bb',
#		stylesheet_uri: '".$DALLIANCE_DATA_DIR_URI."gencode/gencode2.xml',
#		collapseSuperGroups: true,
#		trixURI: '".$DALLIANCE_DATA_DIR_URI."gencode/gencode.v19.annotation.ix'},
#		{name: 'Repeats',
#		desc: 'Repeat annotation from RepeatMasker', 
#		bwgURI: '".$DALLIANCE_DATA_DIR_URI."repeats/repeats.bb',
#		stylesheet_uri: '".$DALLIANCE_DATA_DIR_URI."repeats/bb-repeats2.xml',
#		//forceReduction: -1
#		},
#		{name: 'Conservation',
#		desc: 'Conservation',
#		bwgURI: '".$DALLIANCE_DATA_DIR_URI."cons/hg19.100way.phastCons.bw',
#		noDownsample: true}
#	];
#	var browser = new Browser({
#		chr:                 '$evs_chr',
#		viewStart:           ".($evs_pos_start-50).",
#		viewEnd:             ".($evs_pos_end+50).",
#		cookieKey:           'human-grc_h37',
#		
#		fullScreen: true,
#
#		coordSystem: {
#			speciesName: 'Human',
#			taxon: 9606,
#			auth: 'GRCh',
#			version: '37',
#			ucscName: 'hg19'
#		},
#		sources: sources
#	});
#";
#
#print $q->br(), $q->script({'type' => 'text/javascript'}, $browser), $q->div({'id' => 'svgHolder', 'style' => 'position:relative;width:70%'}, 'Dalliance Browser here');
#
#}



#TODOlast variant details: list of cis/trans/variants (UV234 patho)
#e.g.
#cis: c.2299delG (in SU4455, SU10...)
#	c.dffhh(in...)
#trans: 


print $q->end_ul(), $q->br(), $q->br();


#print LR image

#check if image already exist, otherwise create it
if ($res->{'taille'} > 100) {
	my $query = "SELECT gi_ng FROM gene WHERE nom[1] = '$gene' AND nom[2] = '$acc';";
	my $res_gi = $dbh->selectrow_hashref($query);
	my ($image_name, $beg, $end, $type) = U2_modules::U2_subs_1::create_image_file_name($gene, $res->{'nom_ng'});
	my $name = U2_modules::U2_subs_2::create_lr_name($res, $dbh);
	#my $data = {$name => $beg."-".$end."-".$type};
	my $image_absolute_url = $ABSOLUTE_HTDOCS_PATH."data/img/LR/$image_name";
	my $image_url = $HTDOCS_PATH."data/img/LR/$image_name";
	my $response;
	print $q->start_p();
	if (-e $image_absolute_url) {print $q->img({'src' => $image_url, 'border' => '0'})}
	else {
		my $url = 'https://194.167.35.158/cgi-bin/u2/draw_del.cgi';
		my $ua = new LWP::UserAgent();
		my $req = POST $url,
	       Content_Type => 'form-data',
	       Content      => [ 
				 url   => $image_absolute_url,
				 name	=> $name,
				 beg => $beg,
				 end => $end,
				 type => $type,
				 gi => $res_gi->{'gi_ng'},
				 gene => $gene
			       ];
		  
		$response = $ua->request($req);
		
		print $q->img({'src' => $image_url, 'border' => '0'});

	}
	print $q->end_p();
	#
	#
	#else {U2_modules::U2_subs_2::make_del_graph($gene, $image_absolute_url, $data, $res_gi->{'gi_ng'});print $q->img({'src' => $image_url, 'border' => '0'});}
	##U2_modules::U2_subs_2::make_del_graph($gene, $image_absolute_url, $data, $res_gi->{'gi_ng'});	
	
	
	#print $q->end_li();
}



#$dessin->{$nom.";".$identifiant.$pat.";".$statut} = $ng_deb."-".$ng_fin."-".$type;
#&make_graph_del($gene, $dessin, $pid);



##easy-comment
my $valid_id = "$acc$res->{'acc_version'}$var";
$valid_id =~ s/>//og;
$valid_id =~ s/\.//og;
$valid_id =~ s/\+//og;
$valid_id =~ s/\?//og;
$valid_id =~ s/\*//og;
$js = "jQuery(document).ready(function(){
   \$(\"#$valid_id\").EasyComment({
      path:\"/javascript/u2/easy-comment/\"
   });
   \$(\"[name='name']\").val('".$user->getName()."');
});";

print $q->end_div(), $q->br(), $q->br(), $q->script({'type' => 'text/javascript'}, $js), $q->start_div({'id' => $valid_id, 'class' => 'comments decale'});



##Basic end of USHVaM 2 perl scripts:

U2_modules::U2_subs_1::standard_end_html($q);

print $q->end_html();

exit();

##End of Basic end

##specific subs for current script

sub menu_class {
	my ($classe, $q, $dbh) = @_;
	my @class_list;
	my $html2return = $q->br().$q->br().$q->start_div({'align' => 'center'}).$q->start_Select({'id' => 'class_select'});
	my $sth = $dbh->prepare("SELECT classe FROM valid_classe;");
	my $res = $sth->execute();
	while (my $result = $sth->fetchrow_hashref()) {
		my $options = 'style = "color:'.U2_modules::U2_subs_1::color_by_classe($result->{'classe'}, $dbh).';"';
		if ($result->{'classe'} eq $classe) {$options .= ' selected = "selected"'}
		$html2return .= $q->option({$options}, $result->{'classe'});
	}
	$html2return .= $q->end_Select().$q->end_div().$q->br().$q->br();
	return $html2return;
}

sub menu_rna_status {
	my ($status, $q, $dbh) = @_;
	my @status_list;
	my $html2return = $q->br().$q->br().$q->start_div({'align' => 'center'}).$q->start_Select({'id' => 'rna_status_select'});
	my $sth = $dbh->prepare("SELECT type_arn FROM valid_type_arn;");
	my $res = $sth->execute();
	while (my $result = $sth->fetchrow_hashref()) {
		my $options = 'style = "color:'.U2_modules::U2_subs_1::color_by_rna_status($result->{'type_arn'}, $dbh).';"';
		if ($result->{'type_arn'} eq $status) {$options .= ' selected = "selected"'}
		$html2return .= $q->option({$options}, $result->{'type_arn'});
	}
	$html2return .= $q->end_Select().$q->end_div().$q->br().$q->br();
	return $html2return;
}


