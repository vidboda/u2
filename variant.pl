BEGIN {delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV', 'PATH'};}

#$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = '0'

use strict;
#use CGI; #in startup.pl
#use DBI;
#use AppConfig qw(:expand :argcount);
use List::Util qw(first max maxstr min minstr reduce shuffle sum);
use URI::Escape;
use HTTP::Request::Common;
use LWP::UserAgent;
# use Net::SSL;
use JSON;
use Data::Dumper;
use U2_modules::U2_users_1;
use U2_modules::U2_init_1;
use U2_modules::U2_subs_1;
use U2_modules::U2_subs_2;
use U2_modules::U2_subs_3;

#http://stackoverflow.com/questions/74358/how-can-i-get-lwp-to-validate-ssl-server-certificates
# to bypass ssl validation by LWP version 6 and above
#use Net::SSL
#and my $ua = LWP::UserAgent->new(ssl_opts => {verify_hostname => 0});

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

#local $| = 1;

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
my $DALLIANCE_DATA_DIR_URI = $config->DALLIANCE_DATA_DIR_URI();

my @styles = ($CSS_PATH.'font-awesome.min.css', $CSS_PATH.'w3.css', $CSS_DEFAULT, $CSS_PATH.'jquery-ui-1.12.1.min.css');

my $q = new CGI;

my $dbh = DBI->connect(    "DBI:Pg:database=$DB;host=$HOST;",
                        $DB_USER,
                        $DB_PASSWORD,
                        {'RaiseError' => 1}
                ) or die $DBI::errstr;

my $user = U2_modules::U2_users_1->new();
my $soft = 'U2';
if ($user->isPublic() == 1) {$soft = 'MD'}

print $q->header(-type => 'text/html', -'cache-control' => 'no-cache'),
	$q->start_html(
			-title=>"$soft variant details",
			-lang => 'en',
			-style => {-src => \@styles},
			-head => [
				$q->Link({-rel => 'icon',
					-type => 'image/gif',
					-href => $HTDOCS_PATH.'data/img/animated_favicon1.gif'}),
				$q->Link({-rel => 'search',
					-type => 'application/opensearchdescription+xml',
					-title => "$soft search engine",
					-href => $HTDOCS_PATH.'u2browserengine.xml'}),
				$q->meta({-http_equiv => 'Cache-control',
					-content => 'no-cache'}),
				$q->meta({-http_equiv => 'Pragma',
					-content => 'no-cache'}),
				$q->meta({-http_equiv => 'Expires',
					-content => '0'})],
			-script => [
				{-language => 'javascript',
				-src => $JS_PATH.'jquery-1.7.2.min.js', 'defer' => 'defer'},
				{-language => 'javascript',
				-src => $JS_PATH.'jquery.fullsize.pack.js', 'defer' => 'defer'},
				{-language => 'javascript',
				-src => $JS_PATH.'jquery.validate.min.js', 'defer' => 'defer'},
				{-language => 'javascript',
				-src => $JS_PATH.'easy-comment/jquery.easy-comment.min.js', 'defer' => 'defer'},
				{-language => 'javascript',
				-src => $JS_PATH.'jquery-ui-1.12.1.min.js', 'defer' => 'defer'},
				{-language => 'javascript',
				-src => $JS_PATH.'jquery.autocomplete.min.js', 'defer' => 'defer'},
				{-language => 'javascript',
				-src => $JS_PATH.'dalliance_v0.13/build/dalliance-compiled.js', 'defer' => 'defer'},
				{-language => 'javascript',
				-src => $JS_DEFAULT, 'defer' => 'defer'}],
			-encoding => 'ISO-8859-1');

my $user = U2_modules::U2_users_1->new();


if ($user->isPublic() == 1) {U2_modules::U2_subs_1::public_begin_html($q, $user->getName(), $dbh);}
else {U2_modules::U2_subs_1::standard_begin_html($q, $user->getName(), $dbh)}

##end of Basic init

my $ANALYSIS_ILLUMINA_PG_REGEXP = $config->ANALYSIS_ILLUMINA_PG_REGEXP();

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

print $q->start_div({'class' => 'w3-light-grey'}), $q->span({'id' => 'openNav', 'class' =>'w3-button w3-blue w3-xlarge', 'onclick' => 'w3_open()', 'title' => 'Click here to open the menu of useful external links', 'style' => 'visibility:hidden'}, '&#9776;'), $q->end_div(), "\n";

#print $q->start_p({'class' => 'title'}), $q->start_big(), $q->start_strong(), $q->em({'onclick' => "gene_choice('$gene');", 'class' => 'pointer', 'title' => 'click to get somewhere'}, $gene), $q->span(' : '),
#				$q->span({'onclick' => "window.open('$ncbi_url$acc.$res->{'acc_version'}', '_blank')", 'class' => 'pointer', 'title' => 'click to open Genbank in new tab'}, "$acc.$res->{'acc_version'}"), $q->span(":$var"),
#				$q->br(), $q->br(), $q->span("($second_name / "), $q->span({'onclick' => "window.open('http://grch37.ensembl.org/Homo_sapiens/Transcript/Summary?db=core;t=$res->{'enst'}', '_blank')", 'class' => 'pointer', 'title' => 'click to open Ensembl in new tab'}, $res->{'enst'}), $q->span(')'),
#				$q->end_strong(), $q->end_big(), $q->end_p(), "\n",
				#$q->start_ul({'class' => 'menu_left ombre appear', 'id' => 'smart_menu'})left:-60px;menu_left
print				$q->start_div({'class' => 'w3-sidebar w3-bar-block w3-card w3-animate-left w3-light-grey', 'id' => 'smart_menu', 'style' => 'display:block;z-index:1111;width:15%;'}),
				$q->span({'class' => 'w3-bar-item w3-button w3-large w3-border-bottom', 'onclick' => 'w3_close()'}, 'Close &times;');
	

##Mutation taster - removed 11/2018
#if ($res->{'type_adn'} eq 'substitution' && $res->{'type_segment'} eq 'exon') {
#	$var =~ /.+\>(\w)/o;
#	#print $q->start_li(),
#		#$q->start_a({'href' => "http://www.mutationtaster.org/cgi-bin/MutationTaster/MutationTaster69.cgi?gene=$gene&transcript_stable_id_text=$res->{'enst'}&sequence_type=CDS&position_be=$pos_cdna&new_base=$1&alteration_name=".$gene."_".uri_escape($var)."", 'target' => '_blank'}), $q->img({'src' => $HTDOCS_PATH.'data/img/buttons/mut_taster_button.png'}), $q->end_a(),
#		print $q->a({'href' => "http://www.mutationtaster.org/cgi-bin/MutationTaster/MutationTaster69.cgi?gene=$gene&transcript_stable_id_text=$res->{'enst'}&sequence_type=CDS&position_be=$pos_cdna&new_base=$1&alteration_name=".$gene."_".uri_escape($var)."", 'target' => '_blank', 'class' => 'w3-bar-item w3-button w3-large w3-hover-blue w3-border-bottom'}, 'Mutation taster'), "\n";
#	#$q->end_li(), "\n";
#}
	
#HSF removed does not work anymore 27/10/2016
#print $q->start_li(),
#		#$q->start_a({'href' => "http://www.umd.be/HSF/4DACTION/input_SSF?choix_analyse=ssf_batch&autoselect=yes&snp_select=yes&nuclposition5=200&nuclposition3=200&choix_bdd=transcript_id&texte=$res->{'enst'}&batch=".uri_escape($var)."&paramfulltables=onlyvariants&fenetreintron=yes&fenetretaille=20&paramimages=yes&showonly=no&matrice_3=yes&Matrice=PSS&Matrice=maxent&seuil_maxent5=0&seuil_maxent3=0&Matrice=BPS&Matrice=ESE%20finder&Matrice=RESCUE%20ESE&Matrice=ESE%20New&Matrice=Sironi&Matrice=Decamers&Matrice=ESS%20hnRNP&Matrice=PESE&Matrice=ESR&Matrice=EIE&seuil_sf2=72.98&seuil_sf2_esef=1.956&seuil_sf2ig=70.51&seuil_sf2ig_esef=1.867&seuil_sc35=75.05&seuil_sc35_esef=2.383&seuil_srp40=78.08&seuil_srp40_esef=2.67&seuil_srp55=73.86&seuil_srp55_esef=2.676&seuil_9g8=59.245&seuil_tra2=75.964&seuil_hnrnpa1=65.476&seuil_sironi1=60&seuil_sironi2=60&seuil_sironi3=60", 'target' => '_blank'}), $q->img({'src' => $HTDOCS_PATH.'data/img/buttons/HSF_button.png'}), $q->end_a(),
#		$q->start_a({'href' => "http://www.umd.be/HSF3/4DACTION/input_SSF?choix_analyse=ssf_batch&autoselect=yes&snp_select=yes&nuclposition5=200&nuclposition3=200&choix_bdd=transcript_id&champlibre=$res->{'enst'}&batch=".uri_escape($var)."&paramfulltables=onlyvariants&fenetreintron=yes&fenetretaille=20&paramimages=yes&showonly=no&matrice_3=yes&Matrice=PSS&Matrice=maxent&seuil_maxent5=0&seuil_maxent3=0&Matrice=BPS&Matrice=ESE%20finder&Matrice=RESCUE%20ESE&Matrice=ESE%20New&Matrice=Sironi&Matrice=Decamers&Matrice=ESS%20hnRNP&Matrice=PESE&Matrice=ESR&Matrice=EIE&seuil_sf2=72.98&seuil_sf2_esef=1.956&seuil_sf2ig=70.51&seuil_sf2ig_esef=1.867&seuil_sc35=75.05&seuil_sc35_esef=2.383&seuil_srp40=78.08&seuil_srp40_esef=2.67&seuil_srp55=73.86&seuil_srp55_esef=2.676&seuil_9g8=59.245&seuil_tra2=75.964&seuil_hnrnpa1=65.476&seuil_sironi1=60&seuil_sironi2=60&seuil_sironi3=60", 'target' => '_blank'}), $q->img({'src' => $HTDOCS_PATH.'data/img/buttons/HSF_button.png'}), $q->end_a(),
#	$q->end_li(), "\n";

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
	#print $q->start_li(),
	print $q->a({'href' => "https://neuro-2.iurc.montp.inserm.fr/cgi-bin/USMA/USMA.fcgi?gene=$gene&variant=".$res->{'protein'}."", 'target' => '_blank', 'class' => 'w3-bar-item w3-button w3-large w3-hover-blue w3-border-bottom'}, 'USMA'), "\n";
	#$q->img({'src' => $HTDOCS_PATH.'data/img/buttons/USMA_button.png'}), "\n";
	#$q->end_li(), "\n";
}
elsif ($res->{'type_prot'} eq 'missense' && $gene eq 'CFTR') {
	print $q->a({'href' => "https://cftr.iurc.montp.inserm.fr/cgi-bin/cysma/cysma.cgi?gene=$gene&variant=".$res->{'protein'}."", 'target' => '_blank', 'class' => 'w3-bar-item w3-button w3-large w3-hover-blue w3-border-bottom'}, 'CYSMA'), "\n";
}

my ($evs_chr, $evs_pos_start, $evs_pos_end) = U2_modules::U2_subs_1::extract_pos_from_genomic($res->{'nom_g'}, 'evs');
if ($res->{'taille'} < 50) {
	#print $q->start_li(),
	print $q->a({'href' => "http://evs.gs.washington.edu/EVS/PopStatsServlet?searchBy=chromosome&chromosome=$evs_chr&chromoStart=$evs_pos_start&chromoEnd=$evs_pos_end&x=0&y=0", 'target' => '_blank', 'class' => 'w3-bar-item w3-button w3-large w3-hover-blue w3-border-bottom'}, 'ESP6500'), "\n";
	#, $q->img({'src' => $HTDOCS_PATH.'data/img/buttons/EVS_button.png'}, 'ESP6500'), "\n";
}

#ExAC http://exac.broadinstitute.org/
#2017/03/24 exac replaced with gnomad
#http://gnomad.broadinstitute.org/variant/
# VIPHL
# http://hearing.genetics.bgi.com/
my $viphl_url = "http://hearing.genetics.bgi.com/automatic.html?variantId=";

if ($res->{'type_adn'} eq 'substitution') {
	my $exac = U2_modules::U2_subs_1::getExacFromGenoVar($res->{'nom_g'});
	#http://wintervar.wglab.org/results.pos.php?queryType=position&chr=1&pos=115828756&ref=G&alt
	if ($exac) {
		#print $q->start_li(),
		print $q->a({'href' => "http://gnomad.broadinstitute.org/variant/$exac", 'target' => '_blank', 'class' => 'w3-bar-item w3-button w3-large w3-hover-blue w3-border-bottom'}, 'gnomAD'), "\n";
		$viphl_url .= "$exac&tab=basic";
		if ($res->{'type_segment'} eq 'exon') {
			my @hyphen = split(/-/, $exac);
			my $intervar_url = "http://wintervar.wglab.org/results.pos.php?queryType=position&build=hg19_updated.v.201904&chr=$evs_chr&pos=$evs_pos_start&ref=$hyphen[2]&alt=$hyphen[3]";
			#my $intervar_url = "http://wintervar.wglab.org/";
			print $q->a({'href' => $intervar_url, 'target' => '_blank', 'class' => 'w3-bar-item w3-button w3-large w3-hover-blue w3-border-bottom'}, 'InterVar'), "\n"
		}			
	#, $q->img({'src' => $HTDOCS_PATH.'data/img/buttons/gnomad_button.png'}, 'gnomAD'), "\n";
		#, $q->end_a(), $q->end_li(), "\n";
	}

}

#1kG
#https://www.ncbi.nlm.nih.gov/variation/tools/1000genomes/?chr=18&from=44109144&to=44109144&gts=rs187587197&mk=44109144:44109144|rs187587197
if ($res->{'taille'} < 50) {
	my ($rs, $gts) = ('', '');
	if ($res->{'snp_id'} ne '') {$rs .= "|$res->{'snp_id'}";$gts = "&gts=$res->{'snp_id'}"}
	#print $q->start_li(),
	print $q->a({'href' => "https://www.ncbi.nlm.nih.gov/variation/tools/1000genomes/?chr=$evs_chr&from=$evs_pos_start&to=$evs_pos_end$gts&mk=$evs_pos_start:$evs_pos_end$rs", 'target' => '_blank', 'class' => 'w3-bar-item w3-button w3-large w3-hover-blue w3-border-bottom'}, '1000 genomes'), "\n";
	#, $q->img({'src' => $HTDOCS_PATH.'data/img/buttons/1kG_button.png'}, '1000 genomes'), "\n";
		#, $q->end_a(), $q->end_li(), "\n";
}


#clinvar
my $added = '';
if ($res->{'type_adn'} eq 'deletion' && ($res->{'taille'} > 4 && $res->{'taille'} < 20) && $res->{'seq_mt'} =~ /-/o) {
	$added = U2_modules::U2_subs_1::get_deleted_sequence($res->{'seq_wt'});
}


#print $q->start_li(),
print	$q->a({'href' => "http://www.ncbi.nlm.nih.gov/clinvar?term=\"".uri_escape("$gene:$var$added")."\" [Variant name]", 'target' => '_blank', 'class' => 'w3-bar-item w3-button w3-large w3-hover-blue w3-border-bottom'}, 'Clinvar'), "\n";

#define links for dbsnp, ucsc, pdb

my $dbsnp_url = "http://www.ncbi.nlm.nih.gov/snp/$res->{'snp_id'}";

#ng name, genomic name, class  clinvarMain=hide&clinvarCnv=dense
my $ucsc_link = "http://genome-euro.ucsc.edu/cgi-bin/hgTracks?db=hg19&position=chr$evs_chr%3A".($evs_pos_start-10)."-".($evs_pos_end+10)."&hgS_doOtherUser=submit&hgS_otherUserName=david.baux&hgS_otherUserSessionName=U2&ruler=full&knownGene=full&refGene=full&pubs=pack&lovd=pack&hgmd=pack&cons100way=full&snp150=dense&ucscGenePfam=full&omimGene2=full&tgpPhase1=dense&tgpPhase3=dense&evsEsp6500=dense&exac=dense&gnomadVariants=dense&gnomadCoverage=show&dgvPlus=dense&allHg19RS_BW=full&highlight=hg19.chr$evs_chr%3A$evs_pos_start-$evs_pos_end";

my ($evs_chr_hg38, $evs_pos_start_hg38, $evs_pos_end_hg38) = U2_modules::U2_subs_1::extract_pos_from_genomic($res->{'nom_g_38'}, 'evs');
my $ucsc_link_hg38 = "http://genome-euro.ucsc.edu/cgi-bin/hgTracks?db=hg38&position=chr$evs_chr_hg38%3A".($evs_pos_start_hg38-10)."-".($evs_pos_end_hg38+10)."&hgS_doOtherUser=submit&hgS_otherUserName=david.baux&hgS_otherUserSessionName=U2&ruler=full&knownGene=full&refGene=full&pubs=pack&lovd=pack&hgmd=pack&cons100way=full&snp150=dense&ucscGenePfam=full&omimGene2=full&tgpPhase1=dense&tgpPhase3=dense&evsEsp6500=dense&exac=dense&gnomadVariants=dense&gnomadCoverage=show&dgvPlus=dense&allHg19RS_BW=full&highlight=hg38.chr$evs_chr_hg38%3A$evs_pos_start_hg38-$evs_pos_end_hg38";

#http://www.rcsb.org/pdb/chromosome.do?v=hg37&chromosome=chrX&pos=106888516
#map2pdb
my ($map2pdb, $map2pdb_url) = ('', '');
if ($res->{'taille'} < 100) {
	$map2pdb = $q->span("&nbsp;&nbsp;-&nbsp;&nbsp;").$q->a({'href' => "http://www.rcsb.org/pdb/chromosome.do?v=hg37&chromosome=$evs_chr&pos=$evs_pos_start", 'target' => '_blank'}, 'Map2PDB');
	$map2pdb_url = "http://www.rcsb.org/pdb/chromosome.do?v=hg37&chromosome=$evs_chr&pos=$evs_pos_start";
}
my ($map2pdb_hg38, $map2pdb_hg38_url) = ('', '');
if ($res->{'taille'} < 100) {
	$map2pdb_hg38 = $q->span("&nbsp;&nbsp;-&nbsp;&nbsp;").$q->a({'href' => "http://www.rcsb.org/pdb/chromosome.do?v=hg38&chromosome=$evs_chr_hg38&pos=$evs_pos_start_hg38", 'target' => '_blank'}, 'Map2PDB');
	$map2pdb_hg38_url = "http://www.rcsb.org/pdb/chromosome.do?v=hg38&chromosome=$evs_chr_hg38&pos=$evs_pos_start_hg38";
}

my $varsome_url = "https://varsome.com/variant/hg19/$acc.$res->{'acc_version'}:$var";


print	$q->a({'href' => $dbsnp_url, 'target' => '_blank', 'class' => 'w3-bar-item w3-button w3-large w3-hover-blue w3-border-bottom'}, 'dbSNP'), "\n",
	$q->a({'href' => $ucsc_link, 'target' => '_blank', 'class' => 'w3-bar-item w3-button w3-large w3-hover-blue w3-border-bottom'}, 'hg19 UCSC'), "\n",
	$q->a({'href' => $ucsc_link_hg38, 'target' => '_blank', 'class' => 'w3-bar-item w3-button w3-large w3-hover-blue w3-border-bottom'}, 'hg38 UCSC'), "\n",
	$q->a({'href' => $map2pdb_url, 'target' => '_blank', 'class' => 'w3-bar-item w3-button w3-large w3-hover-blue w3-border-bottom'}, 'hg19 Map2PDB'), "\n",
	$q->a({'href' => $map2pdb_hg38_url, 'target' => '_blank', 'class' => 'w3-bar-item w3-button w3-large w3-hover-blue w3-border-bottom'}, 'hg38 Map2PDB'), "\n",
	$q->a({'href' => $varsome_url, 'target' => '_blank', 'class' => 'w3-bar-item w3-button w3-large w3-hover-blue w3-border-bottom'}, 'VarSome'), "\n";
if ($res->{'type_adn'} eq 'substitution') {
	print $q->a({'href' => $viphl_url, 'target' => '_blank', 'class' => 'w3-bar-item w3-button w3-large w3-hover-blue w3-border-bottom'}, 'VIP-HL'), "\n";
}
print $q->end_div();
		#, $q->img({'src' => $HTDOCS_PATH.'data/img/buttons/clinvar_button.png'}), $q->end_a(),
	#$q->end_li(), "\n";
#clinvitae	
#print $q->start_li(),
#		$q->start_a({'href' => "http://clinvitae.invitae.com/#q=$gene&f=".uri_escape("$acc.$res->{'acc_version'}:$var$added")."&source=ARUP,Carver,ClinVar,EmvClass,Invitae,kConFab&classification=1,2,3,4,5,6", 'target' => '_blank'}), $q->img({'src' => $HTDOCS_PATH.'data/img/buttons/clinvitae_button.png'}), $q->end_a(),
#	$q->end_li(), "\n";	
	

print $q->start_p({'class' => 'title'}), $q->start_big(), $q->start_strong(), $q->em({'onclick' => "gene_choice('$gene');", 'class' => 'pointer', 'title' => 'click to get somewhere'}, $gene), $q->span(' : '),
				$q->span({'onclick' => "window.open('$ncbi_url$acc.$res->{'acc_version'}', '_blank')", 'class' => 'pointer', 'title' => 'click to open Genbank in new tab'}, "$acc.$res->{'acc_version'}"), $q->span(":$var"),
				$q->br(), $q->br(), $q->span("($second_name / "), $q->span({'onclick' => "window.open('http://grch37.ensembl.org/Homo_sapiens/Transcript/Summary?db=core;t=$res->{'enst'}', '_blank')", 'class' => 'pointer', 'title' => 'click to open Ensembl in new tab'}, $res->{'enst'}), $q->span(')'),
				$q->end_strong(), $q->end_big(), $q->end_p(), "\n";
if ($user->isPublic == 1) {
	print $q->start_div({'id' => 'defgen', 'class' => 'w3-modal'}), $q->end_div();
}
#fixed image on the right
if ($user->isPublic != 1) {print $q->img({'src' => $HTDOCS_PATH.'data/img/class.png', class => 'right ombre'})}


##general info
# segment info
$query = "SELECT nom FROM segment WHERE numero = '$res->{'num_segment'}' AND nom_gene[1] = '$gene' AND nom_gene[2]  ='$acc';";
my $nom_seg = $dbh->selectrow_hashref($query);	

my $toprint = ucfirst($res->{'type_segment'});
if ($res->{'type_segment'} ne $nom_seg->{'nom'}) {$toprint .= " $nom_seg->{'nom'}"}

#my $warning = "There is an issue with a number of hg38 nomenclatures in MD and U2. Hg38 links and info are disabled until fixed.";
#print U2_modules::U2_subs_2::danger_panel($warning, $q);

print $q->end_ul(), "\n",
	$q->start_div({'class' => 'decale'});

#changed 05/12/2016 non main acc no will use NM for mutalyzer instead of NG for main acc-no
my $mutalyzer_request = "$res->{'acc_g'}($gene$res->{'mutalyzer_version'}):$var";
if ($res->{'main'} ne 't') {$mutalyzer_request = "$acc.$res->{'acc_version'}:$var"}



print $q->start_div({'class' => 'fitin', 'id' => 'main'}), $q->start_table({'class' => "technical great_table variant"}), $q->caption("Variant information:"),
			$q->start_Tr(), "\n",
				$q->th({'width' => '15%'}, 'Features:'), "\n",
				$q->th('Variant values:'), "\n",
				$q->th('Description:'), "\n",
			$q->end_Tr(),
			$q->start_Tr(),
				$q->td('Check nomenclature:'),
				$q->start_td(), $q->a({'href' => 'https://mutalyzer.nl/check?name='.uri_escape($mutalyzer_request), 'target' => '_blank'}, 'Mutalyzer'), $q->end_td(),
				$q->td({'class' => 'italique'}, 'Direct link to mutalyzer to check HGVS nomenclature'),
			$q->end_Tr(), "\n",
			$q->start_Tr(), "\n",
				$q->td('Position:'),
				$q->start_td(), $q->span($toprint);
				

my $chevauchant = 0;
if (($res->{'num_segment_end'} != $res->{'num_segment'}) || ($res->{'type_segment_end'} ne $res->{'type_segment'})) {
	$query = "SELECT nom FROM segment WHERE numero = '$res->{'num_segment_end'}' AND nom_gene[1] = '$gene' AND nom_gene[2]  ='$acc';";
	my $nom_seg_end = $dbh->selectrow_hashref($query);
	print $q->span(" until $res->{'type_segment_end'}: $nom_seg_end->{'nom'}");
	$chevauchant = 1;
	my $lrname = U2_modules::U2_subs_2::create_lr_name($res, $dbh);
	print $q->strong(" - $lrname")
}
print			$q->end_td(),
			$q->td('Position VS considered transcript'),
			$q->end_Tr(), "\n";

#size
if ($res->{'taille'} > 1) {print $q->start_Tr(), $q->td('Size:'), $q->td("$res->{'taille'} bp"), $q->td('Size of variant in base pairs'), $q->end_Tr(), "\n"}

#IVS name
if ($res->{'nom_ivs'} ne '') {print $q->start_Tr(), $q->td('IVS:'), $q->td("$acc.$res->{'acc_version'}:$res->{'nom_ivs'}"), $q->td('IVS nomenclature for intronic variants'), $q->end_Tr(), "\n"}

#RNA status
print $q->start_Tr(), $q->td('RNA impact:'), $q->start_td(), $q->span(), $q->span({'id' => 'type_arn', 'style' => 'color:'.U2_modules::U2_subs_1::color_by_rna_status($res->{'type_arn'}, $dbh).';'}, $res->{'type_arn'});#, $q->span(' (in progress)');
#check if pdf for splicing
if (-d $ABSOLUTE_HTDOCS_PATH.'/data/splicing') {#if splicing module
	#pdfs stored under format: gene_variantwithoutc..pdf
	my $splicing_var = $var;
	$splicing_var =~ s/c\.//og;
	if (-f $ABSOLUTE_HTDOCS_PATH.'/data/splicing/'.$gene.'_'.$splicing_var.'.pdf') {#if pdf for variant
		print $q->span(" (confirmed), check "), $q->a({'href' => $HTDOCS_PATH.'/data/splicing/'.$gene.'_'.$splicing_var.'.pdf', 'target' => "_blank"}, 'analysis');
	}
	else {print $q->span(' (inferred) ')}
}

#button to change RNA status for referees
if ($user->isReferee == 1) {
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
				    //dialogClass: 'w3-modal w3-teal',
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
	print $q->span('&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'), $q->script({'type' => 'text/javascript', 'defer' => 'defer'}, $js), $q->button({'id' => 'rna_status_button', 'value' => 'Change RNA status', 'onclick' => 'rnaStatusForm();', 'class' => 'w3-button w3-blue'}), "\n";
}
if ($res->{'taille'} < 10 && $res->{'type_adn'} ne 'indel') {
	if ($res->{'type_adn'} eq 'substitution') {		
		#if ($res->{'type_segment'} eq 'intron') {
		#	my $dist = U2_modules::U2_subs_1::get_pos_from_exon($var);
		#	if ($dist <= 300) {print $q->button({'value' => 'Splicing predictions', 'onclick' => "window.open('splicing_calc.pl?calc=maxentscan&retrieve=spidex&nom_g=$res->{'nom_g'}')"}), "\n"}
		#	else {print $q->button({'value' => 'MaxEntScan', 'onclick' => "window.open('splicing_calc.pl?calc=maxentscan&nom_g=$res->{'nom_g'}')"}), "\n"}
		#}
		#else {print $q->button({'value' => 'Splicing predictions', 'onclick' => "window.open('splicing_calc.pl?calc=maxentscan&retrieve=spidex&nom_g=$res->{'nom_g'}')"}), "\n"}
		print $q->button({'value' => 'Predictions', 'onclick' => "window.open('splicing_calc.pl?calc=maxentscan&retrieve=spidex&find=dbscSNV&add=spliceai&nom_g=$res->{'nom_g'}')", , 'class' => 'w3-button w3-blue'}), "\n"
	}
	else {print $q->button({'value' => 'MaxEntScan', 'onclick' => "window.open('splicing_calc.pl?calc=maxentscan&nom_g=$res->{'nom_g'}')", , 'class' => 'w3-button w3-blue'}), "\n"}
}





print $q->end_td(), $q->td('Impact on mRNA, either predicted (inferred) or observed (confirmed)'), $q->end_Tr(), "\n";

#distance from exon/intron junction for exonic variants
if ($res->{'type_segment'} eq 'exon') {
	my ($dist, $site) = U2_modules::U2_subs_1::get_pos_from_intron($res, $dbh);
	print $q->start_Tr(), $q->td('Position in exon:'), $q->start_td(), "\n";
	if ($dist <= 3 && $dist >= 0) {print $q->strong("Potential impact on splicing: $dist bp from $site site")}
	elsif ($site eq 'overlap') {print $q->strong("Overlaps exon/intron junction")}
	elsif ($site eq 'middle') {print $q->span("Middle of exon, $dist from junctions")}
	else {print $q->span("$dist bp from $site site")}
	print $q->end_td(), $q->td('Distance in bp from nearest splice site (for exonic variants)'), $q->end_Tr(), "\n";
}

#protein name - domain
if ($res->{'protein'} ne '') {
	print $q->start_Tr(), $q->td('Protein:'), $q->start_td(), $q->span({'onclick' => "window.open('$ncbi_url$res->{'acc_p'}', '_blank')", 'class' => 'pointer', 'title' => 'click to open Genbank in new tab'}, $res->{'acc_p'}), $q->span(":$res->{'protein'}");#, $q->br(), "\n";
	
	#access to missense analyses
	#TODO: old fashion ushvam to be updated
	if ($res->{'type_prot'} eq 'missense' || $res->{'type_prot'} =~ /inframe/) {
		my $u1_gene = $gene;
		if ($u1_gene eq 'GPR98') {$u1_gene = 'VLGR1'}
		elsif ($u1_gene eq 'CLRN1') {$u1_gene = 'USH3A'}
		
		my $one_letter = U2_modules::U2_subs_1::nom_three2one($res->{'protein'});
		#print $q->span("--$one_letter--");
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
		print $q->script({'type' => 'text/javascript', 'defer' => 'defer'}, $missense_js), $q->span('&nbsp;&nbsp;&nbsp;'), $q->start_span({'id' => 'ponps'}), $q->button({'value' => 'Get predictors', 'onclick' => 'getPonps();$(\'#ponps\').html("Please wait...");', 'class' => 'w3-button w3-blue'}), $q->end_span();
	}
	print $q->end_td(), $q->td('Protein HGVS nomenclature'), $q->end_Tr(), "\n";
	
	if ($res->{'protein'} =~ /(\d+)_\w{3}(\d+)/og) {
		print $q->start_Tr(), $q->td('Domain:'), $q->start_td();
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
			print $q->span($txt_dom), $q->br(), "\n";
		}
		else {print $q->span('no domain'), $q->br(), "\n"}
		print $q->end_td(), $q->td('Domain Name according to UNIPROT'), $q->end_Tr(), "\n";
	}
	elsif ($res->{'protein'} =~ /(\d+)/og) {
		print $q->start_Tr(), $q->td('Domain:'), $q->start_td();
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
			print $q->span($txt_dom), $q->br(), "\n";
		}
		else {print $q->span('no domain'), $q->br(), "\n"}
		print $q->end_td(), $q->td('Domain Name according to UNIPROT'), $q->end_Tr(), "\n";
	}
}



#mutalyzer position converter for hg38
my $mutalyzer_hg38_pos_conv = $q->span("&nbsp;&nbsp;-&nbsp;&nbsp;").$q->a({'href' => "https://mutalyzer.nl/position-converter?assembly_name_or_alias=GRCh38&description=$res->{'nom_g_38'}", 'target' => '_blank'}, 'Mutalyzer hg38');




if ($res->{'acc_g'} ne 'NG_000000.0') {
	print $q->start_Tr(),
			$q->td('NG HGVS:'),
			$q->start_td(), $q->span({'onclick' => "window.open('$ncbi_url$res->{'acc_g'}', '_blank')", 'class' => 'pointer', 'title' => 'click to open Genbank in new tab'}, $res->{'acc_g'}), $q->span(":$res->{'nom_ng'}"), $q->end_td(),
			$q->td('Relative genomic HGVS nomenclature (NG)'),
		$q->end_Tr(), "\n";
}

print $q->start_Tr(),
		$q->td('hg19 Genomic HGVS:'), "\n",
		$q->start_td({'id' => 'nom_g'}), $q->span("$res->{'nom_g'}&nbsp;&nbsp;-&nbsp;&nbsp;"), $q->a({'href' => $ucsc_link, 'target' => '_blank'}, 'UCSC'), $map2pdb, $q->span("&nbsp;&nbsp;-&nbsp;&nbsp;"), $q->a({'href' => "/perl/led/engine.pl?research=hg19:$evs_chr:$evs_pos_start", 'target' => '_blank'}, 'LED'), $q->end_td(),
		$q->td('Absolute genomic HGVS nomenclature (chr), hg19 assembly'),
		$q->end_Tr(), "\n",	
		$q->start_Tr(),
			$q->td('hg38 Genomic HGVS:'), "\n",
			$q->start_td({'id' => 'nom_g_38'}), $q->span("$res->{'nom_g_38'}&nbsp;&nbsp;-&nbsp;&nbsp;"), $q->a({'href' => $ucsc_link_hg38, 'target' => '_blank'}, 'UCSC'), $map2pdb_hg38, $mutalyzer_hg38_pos_conv, $q->end_td(),
			$q->td('Absolute genomic HGVS nomenclature (chr), hg38 assembly'),
		$q->end_Tr(), "\n";
	
my $js = "
	function getAllNom() {
		\$(\'#page\').css(\'cursor\', \'progress\');
		\$(\'#mutalyzer_place\').css(\'cursor\', \'progress\');
		\$.ajax({
			type: \"POST\",
			url: \"ajax.pl\",
			data: {asked: 'var_nom', nom_g: '$res->{'nom_g'}', accession: '$acc', nom_c: '$var', gene: '$gene'}
		})
		.done(function(msg) {					
			\$('#mutalyzer_place').html(msg);
			\$(\'#page\').css(\'cursor\', \'auto\');
			\$(\'#mutalyzer_place\').css(\'cursor\', \'auto\');
		});
	};";
	
print $q->start_Tr(),
		$q->td('Alternatives:'), "\n",
		$q->start_td({'id' => 'mutalyzer_place'}), $q->script({'type' => 'text/javascript'}, $js), $q->button({'id' => 'all_nomenclature', 'value' => 'Other nomenclatures', 'onclick' => 'getAllNom();$(\'#mutalyzer_place\').html("Please wait while mutalyzer is checking...");', 'class' => 'w3-button w3-blue'}), $q->end_td(),
		$q->td('Click to retrieve alternative notations for the variant'),
	$q->end_Tr(), "\n";

if ($user->isPublic != 1) {
	$js = "
		function defgenExport(status) {
			\$.ajax({
				type: \"POST\",
				url: \"ajax.pl\",
				data: {asked: 'defgen_status', nom_g: '$res->{'nom_g'}', status: status}
			})
			.done(function(msg) {					
				\$('#defgen_export').html(msg);
			});
		};";
	if (U2_modules::U2_subs_1::is_pathogenic($res) == 0) {
		print $q->start_Tr(),
				$q->td('DEFGEN Export:'), "\n",
				$q->start_td({'id' => 'defgen_export'}), U2_modules::U2_subs_3::defgen_status_html($res->{'defgen_export'}, $q);
		#need to be validator	
		if ($user->isValidator == 1) {		
				print $q->span('&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'), $q->script({'type' => 'text/javascript'}, $js), $q->button({'id' => 'defgen_export', 'value' => 'Change status', 'onclick' => 'defgenExport('.$res->{'defgen_export'}.');$(\'#defgen_export\').html("Please wait ...");', 'class' => 'w3-button w3-blue'});
		}	
		print $q->end_td(),
				$q->td('DEFGEN export preference for this variant'),
			$q->end_Tr(), "\n";
	}
	print $q->start_Tr(),
			$q->td('U2 Classification:'),
			$q->start_td(), $q->span({'id' => 'variant_class', 'style' => 'color:'.U2_modules::U2_subs_1::color_by_classe($res->{'classe'}, $dbh).';'}, $res->{'classe'});
		
		#change class
	#need to be validator
	if ($user->isValidator == 1) {
		#print button which opens popup which calls ajax
		my $html = &menu_class($res->{'classe'}, 'classe', $q, $dbh);
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
							\$(\'#page\').css(\'cursor\', \'progress\');
							\$(\'.ui-button\').css(\'cursor\', \'progress\');
							\$.ajax({
								type: \"POST\",
								url: \"ajax.pl\",
								data: {nom_c: '".uri_escape($var)."', gene: '$gene', accession: '$acc', field: 'classe', class: \$(\"#classe_select\").val(), asked: 'class'}
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
		print $q->span('&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'), $q->script({'type' => 'text/javascript', 'defer' => 'defer'}, $js), $q->button({'id' => 'class_button', 'value' => 'Change class', 'onclick' => 'classForm();', 'class' => 'w3-button w3-blue'})
		#print $q->start_li(), $q->script({'type' => 'text/javascript'}, $js), $q->button({'id' => 'class_button', 'value' => 'Change class', 'onclick' => 'classForm();'}), $q->end_li(), $q->br(), "\n";
	}
	
	if ($res->{'classe'} eq 'unknown') {
		
		$js = "
		function reqclass() {
			\$.ajax({
				type: \"POST\",
				url: \"ajax.pl\",
				data: {asked: 'req_class', nom_c: '$var', gene: '$gene'}
			})
			.done(function(msg) {					
				\$('#class_request').hide();
				\$('#request_done').html(msg);
			});
		};
	";
		
		print $q->span('&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'), $q->span({'id' => 'request_done'}), $q->script({'type' => 'text/javascript', 'defer' => 'defer'}, $js), $q->button({'id' => 'class_request', 'value' => 'Request classification', 'onclick' => 'reqclass();', 'class' => 'w3-button w3-blue'});
	}
	print $q->end_td(),
		$q->td('U2 variant classification'),
	$q->end_Tr(), "\n",
}
my ($acmg_class, $acmg_source);
if ($user->isPublic == 1) {
	#print $q->start_div({'id' => 'defgen', 'class' => 'w3-modal'}), $q->end_div();".uri_escape($res->{'nom_g'})."
	
	print $q->start_Tr(),
		$q->td('Defgen:'),
		$q->start_td({'class' => 'w3-padding-8 w3-hover-light-grey'}), $q->button({'onclick' => "getDefGenVariantsMD('".uri_escape($res->{'nom_g'})."');", 'value' => 'Defgen Export', 'class' => 'w3-button w3-ripple w3-blue w3-border w3-border-blue'}), $q->end_td(),
		$q->td('Use the button to export a DEFGEN compliant CSV file'), "\n";
}
if ($res->{'acmg_class'}) {$acmg_class = $res->{'acmg_class'};$acmg_source = 'Manual ACMG classification'}
elsif ($user->isPublic != 1) {$acmg_class = U2_modules::U2_subs_3::u2class2acmg($res->{'classe'}, $dbh);$acmg_source = 'Automatic classification based on U2 class'}
else {$acmg_class = 'Unknown';$acmg_source = 'Default ACMG class'}

print 	$q->start_Tr(),   	
		$q->start_td(), $q->a({'href' => 'https://www.acmg.net/docs/Standards_Guidelines_for_the_Interpretation_of_Sequence_Variants.pdf', 'target' => '_blank'}, 'ACMG Classification :'), $q->end_td(),
		$q->start_td(), $q->span({'id' => 'acmg_variant_class', 'style' => 'color:'.U2_modules::U2_subs_3::acmg_color_by_classe($acmg_class, $dbh).';'}, $acmg_class);
		
if ($user->isValidator == 1 || $user->isPublic == 1) {
	my $html = &menu_class($res->{'acmg_class'}, 'acmg_class', $q, $dbh);
	$js = "
		function acmgClassForm() {
			var \$dialog_class = \$('<div></div>')
				.html('$html')
				.dialog({
					autoOpen: false,
					title: 'Change ACMG class for $gene $var:',
					width: 450,
					buttons: {
					\"Change\": function() {
						\$(\'#page\').css(\'cursor\', \'progress\');
						\$(\'.ui-button\').css(\'cursor\', \'progress\');
						\$.ajax({
							type: \"POST\",
							url: \"ajax.pl\",
							data: {nom_c: '".uri_escape($var)."', gene: '$gene', accession: '$acc', field: 'acmg_class', class: \$(\"#acmg_class_select\").val(), asked: 'class'}
						})
						.done(function() {
							location.reload();
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
	
	print $q->span('&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'), $q->script({'type' => 'text/javascript', 'defer' => 'defer'}, $js), $q->button({'id' => 'class_button', 'value' => 'Change class', 'onclick' => 'acmgClassForm();', 'class' => 'w3-button w3-blue'});

}

print 	$q->end_td(),
		$q->td($acmg_source),
	$q->end_Tr(), "\n";

#my $litvar_tr = '';
#dbSNP
print $q->start_Tr(), $q->td('dbSNP:'), "\n",
	$q->start_td();
if ($res->{'snp_id'} ne '') {
	my $snp_common = "SELECT common FROM restricted_snp WHERE rsid = '$res->{'snp_id'}';";
	my $res_common = $dbh->selectrow_hashref($snp_common);
	print $q->a({'href' => $dbsnp_url, 'target' => '_blank'}, $res->{'snp_id'});
	if ($res_common->{'common'} && $res_common->{'common'} == 1) {print $q->span('    in common dbSNP150 variant set (MAF > 0.01)')}
	#my $query_litvar;
	#$query_litvar->{'variant'} = ["litvar@$res->{'snp_id'}##"];
	#= {'variant' => ["litvar@$res->{'snp_id'}##"]};
	#my $litvar_url = "https://www.ncbi.nlm.nih.gov/research/bionlp/litvar/api/v1/public/pmids?query=%7B%22variant%22%3A%5B%22litvar%40$res->{'snp_id'}%23%23%22%5D%7D";
	#my $ua = LWP::UserAgent->new();
	#my $litvar_response = $ua->get($litvar_url);
	#my $pubmedids = decode_json($litvar_response->decoded_content());
	
	#litvar put in ajax.pl not to slow down page loading
	#my $test_ncbi = U2_modules::U2_subs_1::test_ncbi();
	#$litvar_tr = $q->start_Tr() . $q->td('Pubmed related articles:') . $q->start_td() . $q->start_div({'class' => 'w3-container'});
	#if ($test_ncbi == 1) {
	#	my $pubmedids = U2_modules::U2_subs_1::run_litvar($res->{'snp_id'});
	#	if ($pubmedids->[0] eq '') {
	#		$litvar_tr .= $q->span('No PubMed ID retrived');
	#	}
	#	else {
	#		$litvar_tr .= $q->button({'class' => 'w3-button w3-ripple w3-blue w3-border w3-border-blue', 'value' => 'show Pubmed IDs', 'onclick' => '$("#pubmed").show();'}) .
	#		$q->start_div({'class' => 'w3-modal', 'id' => 'pubmed'}) . "\n" .
	#			$q->start_div({'class' => 'w3-modal-content w3-display-middle', 'style' => 'z-index:1500'}) . "\n" .
	#				"<header class = 'w3-container w3-teal'>" . "\n" .
	#					$q->span({'onclick' => '$("#pubmed").hide();', 'class' => 'w3-button w3-display-topright w3-large'}, '&times') . "\n" .
	#					$q->h2('PubMed IDs of articles citing this variant:') . "\n" .
	#				'</header>' . "\n" .
	#				$q->start_div({'class' => 'w3-container'}) . "\n" .
	#					$q->start_ul() . "\n";
	#		my $pubmed_url = 'https://www.ncbi.nlm.nih.gov/pubmed/';
	#		if ($user->isLocalUser() == 1) {$pubmed_url = 'https://www-ncbi-nlm-nih-gov.gate2.inist.fr/pubmed/';}
	#		foreach my $pmid (@{$pubmedids}) {
	#			$litvar_tr .= $q->start_li() . $q->a({'href' => $pubmed_url.$pmid->{'pmid'}, 'target' => '_blank'}, $pmid->{'pmid'}) . $q->end_li() . "\n"
	#			#print $pmid->{'pmid'}
	#		}
	#		$litvar_tr .= $q->end_ul() . "\n" . $q->br() . $q->br() .
	#				$q->end_div() . "\n" .
	#			$q->end_div() . "\n" .
	#		$q->end_div() . "\n";
	#	}
	#}
	#else {$litvar_tr .= $q->span('Litvar service unavailable')}
	#$litvar_tr .= $q->end_div() . $q->end_td() . $q->start_td() . $q->span('Pubmed text mining using ') . $q->a({'href' => 'https://www.ncbi.nlm.nih.gov/CBBresearch/Lu/Demo/LitVar/index.html', 'target' => '_blank'}, 'LitVar') . $q->end_Tr() . "\n";
}
else {print $q->span("Not reported in dbSNP")}
print $q->end_td(), $q->td('dbSNP related information'), $q->end_Tr(), "\n";#, $litvar_tr;
#1000 genomes

#print $q->start_Tr(), $q->td('MAFs & databases:'), $q->start_td(), $q->span({'id' => 'ext_data'}, 'loading external data...'), $q->end_td(), $q->td('Diverse population MAFs and links to LSDBs'), $q->end_Tr(), "\n";
print $q->start_Tr({'id' => 'ext_data'}), $q->td('MAFs & databases & Pubmed:'), $q->start_td(), $q->span('loading external data...'), $q->end_td(), $q->td('Diverse population MAFs and links to LSDBs'), $q->end_Tr(), "\n";


#infos on cohort: # of seen, MAFS, 454: mean depth, mean freq, mean f/r
if ($user->isPublic != 1) {
	#my ($maf_454, $maf_sanger, $maf_miseq) = ('NA', 'NA', 'NA');
	#if ($maf eq '') {	
	#	#MAF 454
	#	$maf_454 = U2_modules::U2_subs_1::maf($dbh, $gene, $acc, $var, '454-[[:digit:]]+');
	#	#MAF SANGER
	#	$maf_sanger = U2_modules::U2_subs_1::maf($dbh, $gene, $acc, $var, 'SANGER');
	#	#MAF MISEQ
	#	$maf_miseq = U2_modules::U2_subs_1::maf($dbh, $gene, $acc, $var, $ANALYSIS_ILLUMINA_PG_REGEXP);
	#	$maf = "MAF 454: $maf_454 / MAF Sanger: $maf_sanger / MAF Illumina: $maf_miseq";	
	#}
	#else {
	#	$maf =~ /MAF\s454:\s([\w\.]+)\s\/.+/o;
	#	$maf_454 = $1;
	#}
	#print $q->start_Tr(), $q->td('U2 MAFs:'), $q->td($maf), $q->td('MAFs in Ushvam 2 with different techniques'), $q->end_Tr(), "\n";
	
	###TO DO mean freq and doc for MiSeq
	
	#if ($maf_454 ne 'NA') {	
	my $query_454 = "SELECT AVG(depth) as a, AVG(frequency) as b, AVG(wt_f) as c, AVG(wt_r) as d, AVG(mt_f) as e, AVG(mt_r) as f, COUNT(nom_c) as g FROM variant2patient WHERE type_analyse LIKE '454-%' AND nom_gene[1] = '$gene' AND nom_gene[2] = '$acc' AND nom_c = '$var';";
	my $res_454 = $dbh->selectrow_hashref($query_454);
	if ($res_454->{'g'} > 0) {
		print $q->start_Tr(), $q->td('454 mean values:'), $q->start_td(), $q->span("Seen in $res_454->{'g'} runs"),
			$q->start_ul(),
				$q->li("depth: ".sprintf('%.2f', $res_454->{'a'})), "\n",
				$q->li("frequency: ".sprintf('%.2f', $res_454->{'b'})), "\n",
				$q->li("forward reads (wt+mt): ".sprintf('%.2f',($res_454->{'c'}+$res_454->{'e'}))), "\n",
				$q->li("reverse reads (wt+mt):  ".sprintf('%.2f',($res_454->{'d'}+$res_454->{'f'}))), "\n",
			$q->end_ul(),
			$q->end_td(), $q->td('Metrics related to all occurences within 454 sequencing'), $q->end_Tr(), "\n";
	}
	#if ($maf_miseq ne 'NA') {
	my $query_illu = "SELECT AVG(depth) as a, AVG(frequency) as b, COUNT(nom_c) as c FROM variant2patient WHERE type_analyse ~ '$ANALYSIS_ILLUMINA_PG_REGEXP' AND nom_gene[1] = '$gene' AND nom_gene[2] = '$acc' AND nom_c = '$var';";
	my $res_illu = $dbh->selectrow_hashref($query_illu);
	if ($res_illu->{'c'} > 0) {
		print $q->start_Tr(), $q->td('MiSeq mean values:'), $q->start_td(), $q->span("Seen $res_illu->{'c'} times in Illumina sequencing"),
			$q->start_ul(),
				$q->li("depth: ".sprintf('%.2f', $res_illu->{'a'})), "\n",
				$q->li("frequency: ".sprintf('%.2f', $res_illu->{'b'})), "\n";
		$query_illu = "SELECT msr_filter, num_pat, id_pat FROM variant2patient WHERE type_analyse ~ '$ANALYSIS_ILLUMINA_PG_REGEXP' AND nom_gene[1] = '$gene' AND nom_gene[2] = '$acc' AND nom_c = '$var';";	
		my $sth = $dbh->prepare($query_illu);
		$res_illu = $sth->execute();
		my $pass = 0;
		my $other;
		while (my $result = $sth->fetchrow_hashref()) {
			if ($result->{'msr_filter'} eq 'PASS') {$pass++}
			else {$other->{$result->{'msr_filter'}} .= $q->span("   ").$q->a({'href' => "patient_genotype.pl?sample=$result->{'id_pat'}$result->{'num_pat'}&gene=$gene", 'target' => '_blank'}, $result->{'id_pat'}.$result->{'num_pat'})}		
		}
		print $q->start_li(), $q->span('Filter summary:'), $q->start_ul(),
			$q->li("PASS $pass times");
		foreach my $key (keys(%{$other})) {print $q->start_li(), $q->span("$key: "), $other->{$key}, $q->end_li()}
		print $q->end_ul(),
			$q->end_li(),
			$q->end_ul(),
			$q->end_td(), $q->td('Metrics related to all occurences within Illumina sequencing'), $q->end_Tr(), "\n";
	}
	
	
	
	$query = "SELECT DISTINCT(num_pat), id_pat, statut, denovo FROM variant2patient WHERE nom_gene[1] = '$gene' AND nom_gene[2] = '$acc' AND nom_c = '$var' ORDER BY num_pat;";
	my $sth = $dbh->prepare($query);
	my $res_seen = $sth->execute();
	
	my $seen;
	my $hom = 0;
	
	while (my $result = $sth->fetchrow_hashref()) {
		if ($result->{'statut'} =~ /homo/o) {$hom += 2}
		#if ($result->{'filter'} eq 'RP' && $result->{'dfn'} == 1) {next}
		#elsif ($result->{'filter'} eq 'DFN' && $result->{'rp'} == 1) {next}
		my $denovo_txt = U2_modules::U2_subs_1::translate_boolean_denovo($result->{'denovo'});
		$seen .= $q->start_div().$q->span("-$result->{'id_pat'}$result->{'num_pat'} ($result->{'statut'}$denovo_txt)&nbsp;&nbsp;").$q->start_a({'href' => "patient_file.pl?sample=$result->{'id_pat'}$result->{'num_pat'}", 'target' => '_blank'}).$q->span('patient&nbsp;&nbsp;').$q->img({'src' => $HTDOCS_PATH.'data/img/link_small.png', 'border' => '0', 'width' =>'15'}).$q->end_a().$q->span('&nbsp;&nbsp;&nbsp;').$q->start_a({'href' => "patient_genotype.pl?sample=$result->{'id_pat'}$result->{'num_pat'}&gene=$gene", 'target' => '_blank'}).$q->span('genotype&nbsp;&nbsp;').$q->img({'src' => $HTDOCS_PATH.'data/img/link_small.png', 'border' => '0', 'width' =>'15'}).$q->end_a().$q->end_div();	
	}
	
	$query = "SELECT DISTINCT(a.num_pat), a.id_pat, a.statut, a.denovo, b.filter, c.rp, c.dfn, c.usher, c.nom FROM variant2patient a, miseq_analysis b, gene c WHERE a.num_pat = b.num_pat AND a.id_pat = b.id_pat AND a.type_analyse = b.type_analyse AND a.nom_gene = c.nom AND a.nom_gene[1] = '$gene' AND a.nom_gene[2] = '$acc' AND a.nom_c = '$var' AND b.filter <> 'ALL' ORDER BY a.num_pat;";
	$sth = $dbh->prepare($query);
	my $res_filter = $sth->execute();
	while (my $result = $sth->fetchrow_hashref()) {
		
		if ($result->{'filter'} eq 'RP' && ($result->{'rp'} == 1 && $result->{'usher'} == 0)) {next}
		#elsif ($result->{'filter'} eq 'DFN' && ($result->{'dfn'} == 1 && $result->{'usher'} == 0)) {next}
		#03/20119 test CIB2/PDZD7 is usher = t and dfn = t
		elsif ($result->{'filter'} eq 'DFN' && $result->{'dfn'} == 1) {next}
		elsif ($result->{'filter'} eq 'USH' && $result->{'usher'} == 1) {next}
		elsif ($result->{'filter'} eq 'DFN-USH' && ($result->{'dfn'} == 1 || $result->{'usher'} == 1)) {next}
		elsif ($result->{'filter'} eq 'RP-USH' && ($result->{'rp'} == 1 || $result->{'usher'} == 1)) {next}
		elsif ($result->{'filter'} eq 'CHM' && $result->{'nom_gene'} eq 'CHM') {next}
		else {
			my $denovo_txt = U2_modules::U2_subs_1::translate_boolean_denovo($result->{'denovo'});
			#$seen =~ s/<div><span>-$result->{'id_pat'}$result->{'num_pat'} \($result->{'statut'}$denovo_txt\)&nbsp;&nbsp;<\/span><a target="_blank" href="patient_file\.pl\?sample=$result->{'id_pat'}$result->{'num_pat'}"><span>patient&nbsp;&nbsp;<\/span><img width="15" src="\/ushvam2\/data\/img\/link_small.png" border="0" \/><\/a><span>&nbsp;&nbsp;&nbsp;<\/span><a target="_blank" href="patient_genotype.pl\?sample=$result->{'id_pat'}$result->{'num_pat'}&amp;gene=$result->{'nom'}[0]"><span>genotype&nbsp;&nbsp;<\/span><img width="15" src="\/ushvam2\/data\/img\/link_small\.png" border="0" \/><\/a><\/div>/<div>-filtered patient<\/div>/g;
			$seen =~ s/<div><span>-$result->{'id_pat'}$result->{'num_pat'} \($result->{'statut'}$denovo_txt\)&nbsp;&nbsp;<\/span><a href="patient_file\.pl\?sample=$result->{'id_pat'}$result->{'num_pat'}" target="_blank"><span>patient&nbsp;&nbsp;<\/span><img border="0" src="\/ushvam2\/data\/img\/link_small.png" width="15" \/><\/a><span>&nbsp;&nbsp;&nbsp;<\/span><a href="patient_genotype.pl\?sample=$result->{'id_pat'}$result->{'num_pat'}&amp;gene=$result->{'nom'}[0]" target="_blank"><span>genotype&nbsp;&nbsp;<\/span><img border="0" src="\/ushvam2\/data\/img\/link_small\.png" width="15" \/><\/a><\/div>/<div>-filtered patient<\/div>/g;
			#print "2-$result->{'id_pat'}$result->{'num_pat'}-$result->{'statut'}-$seen-<br/>";
		}
	}
	
	
	$query = "SELECT COUNT(DISTINCT(num_pat, id_pat)) as a FROM variant2patient WHERE type_analyse LIKE '454-%' AND nom_gene[1] = '$gene' AND nom_gene[2] = '$acc' AND nom_c = '$var';";
	my $res_seen_454 = $dbh->selectrow_hashref($query);
	
	$query = "SELECT COUNT(DISTINCT(num_pat, id_pat))*2 as a FROM variant2patient WHERE type_analyse LIKE '454-%' AND nom_gene[1] = '$gene' AND nom_gene[2] = '$acc' AND nom_c = '$var' AND statut = 'homozygous';";
	my $hom_454 = $dbh->selectrow_hashref($query);
	
	#$query = "SELECT COUNT(DISTINCT(num_pat)) as a FROM variant2patient WHERE type_analyse LIKE 'MiSeq-%' AND nom_gene[1] = '$gene' AND nom_gene[2] = '$acc' AND nom_c = '$var';";
	$query = "SELECT COUNT(DISTINCT(num_pat, id_pat)) as a FROM variant2patient WHERE type_analyse ~ '$ANALYSIS_ILLUMINA_PG_REGEXP' AND nom_gene[1] = '$gene' AND nom_gene[2] = '$acc' AND nom_c = '$var';";
	my $res_seen_miseq = $dbh->selectrow_hashref($query);
	
	#$query = "SELECT COUNT(DISTINCT(num_pat))*2 as a FROM variant2patient WHERE type_analyse LIKE 'MiSeq-%' AND nom_gene[1] = '$gene' AND nom_gene[2] = '$acc' AND nom_c = '$var' AND statut = 'homozygous';";
	$query = "SELECT COUNT(DISTINCT(num_pat, id_pat))*2 as a FROM variant2patient WHERE type_analyse ~ '$ANALYSIS_ILLUMINA_PG_REGEXP' AND nom_gene[1] = '$gene' AND nom_gene[2] = '$acc' AND nom_c = '$var' AND statut = 'homozygous';";
	my $hom_miseq = $dbh->selectrow_hashref($query);
	
	print $q->start_Tr(), $q->td('U2 occurences:'), $q->start_td(), $q->span("Seen in ".($res_seen+($hom/2))." alleles in total (including $hom homozygous) (homozygous = 2 alleles)"),
		$q->start_ul(), $q->li("including ".($res_seen_454->{'a'}+($hom_454->{'a'}/2))." alleles in 454 context ($hom_454->{'a'} homozygous)"),
		$q->li("including ".($res_seen_miseq->{'a'}+($hom_miseq->{'a'}/2))." alleles in Illumina context ($hom_miseq->{'a'} homozygous)"), $q->end_ul(), $q->end_td(), $q->td('Number of observation in Ushvam2 with details'), $q->end_Tr(), "\n";
	
	#patient list
	
	$js = "
		function getPatients() {
			var \$dialog = \$('<div></div>')
				.html('$seen')
				.dialog({
					autoOpen: false,
					title: 'Patients carrying $var:',
					width: 450,
					maxHeight: 600
				});
			\$dialog.dialog('open');
		};";
	
	print $q->start_Tr(), $q->td('Samples:'), $q->start_td(), $q->script({'type' => 'text/javascript', 'defer' => 'defer'}, $js), $q->button({'id' => 'patient_list', 'value' => 'Sample list', 'onclick' => 'getPatients();', 'class' => 'w3-button w3-blue'}), $q->end_td(), $q->td('Get a list of samples carrying the variant'), "\n";
}
#sequence
if ($res->{'seq_wt'} ne '') {
	print $q->start_Tr(), $q->td('WT:'), $q->td({'class' => 'txt'}, $res->{'seq_wt'}), $q->td('Wild-type DNA sequence'), $q->end_Tr(), "\n",
		$q->start_Tr(), $q->td('MT:'), $q->td({'class' => 'txt'}, $res->{'seq_mt'}), $q->td('Mutant DNA sequence'), $q->end_Tr(), "\n";
}

print $q->start_Tr(), $q->td('Creation date:');
if ($res->{'creation_date'} ne '') {print $q->td($res->{'creation_date'}), $q->td(ucfirst($res->{'referee'}))}
else {print $q->td('Before 09/2015'), $q->td()}
print $q->end_Tr();

print $q->end_table(), $q->end_div();

#TODOlast variant details: list of cis/trans/variants (UV234 patho)
#e.g.
#cis: c.2299delG (in SU4455, SU10...)
#	c.dffhh(in...)
#trans: 


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
	print $q->br(), $q->br(), $q->start_p();
	if (-e $image_absolute_url) {print $q->img({'src' => $image_url, 'border' => '0'})}
	else {
		my $url = 'https://pp-gb-gen.iurc.montp.inserm.fr/cgi-bin/u2/draw_del.cgi';
		my $ua = new LWP::UserAgent(ssl_opts => {verify_hostname => 0});
		#$ua->ssl_opts('verify_hostname' => 0);
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
		#print Dumper($response);
		print $ua->ssl_opts('verify_hostname');
		print $q->img({'src' => $image_url, 'border' => '0'});
	}
	print $q->end_p();

}


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

print $q->br(), $q->br(), $q->script({'type' => 'text/javascript', 'defer' => 'defer'}, $js), $q->start_div({'id' => $valid_id, 'class' => 'comments'}), $q->end_div();

##genome browser
#http://www.biodalliance.org/
#my $DALLIANCE_DATA_DIR_URI = '/dalliance_data/hg19/';
#{name: 'UK10K',
#			desc: 'UK10K dataset',
#			tier_type: 'tabix',
#			payload: 'vcf',
#			uri: '".$DALLIANCE_DATA_DIR_URI."uk10k/UK10K_COHORT.20160215.sites.vcf.gz'},
		#{name: 'ExAC',
		#	desc: 'ExAC r0.3',
		#	tier_type: 'tabix',
		#	payload: 'vcf',
		#	noSourceFeatureInfo: true,
		#	uri: '".$DALLIANCE_DATA_DIR_URI."exac/ExAC.r0.3.sites.vep.vcf.gz'},
		#{name: '112 genes Design',
		#	desc: 'Illumina Nextera on 112 genes',
		#	tier_type: 'tabix',
		#	payload: 'bed',
		#	uri: '".$DALLIANCE_DATA_DIR_URI."designs/nextera_targets_sorted.bed.gz'},
		#{name: '1000g',
		#	desc: '1000 genomes phase 3',
		#	tier_type: 'tabix',
		#	payload: 'vcf',
		#	uri: '".$DALLIANCE_DATA_DIR_URI."1000g_p3/1000GENOMES-phase_3.vcf.gz'},
		#{name: 'Kaviar',
		#	desc: 'Kaviar dataset',
		#	tier_type: 'tabix',
		#	payload: 'vcf',
		#	uri: '".$DALLIANCE_DATA_DIR_URI."kaviar/Kaviar-160204-Public-hg19-trim.vcf.gz'},
my ($padding, $sources) = (50, '');
if ($res->{'taille'} > 500) {$padding = sprintf('%.0f', $res->{'taille'}/10)}
else {$sources = "{name: 'ClinVar',
			desc: 'ClinVar 02/2017',
			tier_type: 'tabix',
			payload: 'vcf',
			uri: '".$DALLIANCE_DATA_DIR_URI."clinvar/clinvar_20170228.vcf.gz'},
		{name: 'gnomAD Ex',
			desc: 'gnomAD exome dataset',
			tier_type: 'tabix',
			payload: 'vcf',
			uri: '".$DALLIANCE_DATA_DIR_URI."gnomad/hg19_gnomad_exome.sorted.af.vcf.gz'},
		{name: 'gnomAD Ge',
			desc: 'gnomAD genome dataset',
			tier_type: 'tabix',
			payload: 'vcf',
			uri: '".$DALLIANCE_DATA_DIR_URI."gnomad/hg19_gnomad_genome.sorted.vcf.gz'},
		{name: 'dbSNP150',
			desc: 'dbSNP150 20170710',
			tier_type: 'tabix',
			payload: 'vcf',
			uri: '".$DALLIANCE_DATA_DIR_URI."dbSNP150/All_20170710.vcf.gz'},		
		{name: '132 genes Design',
			desc: 'Nimblegen SeqCap on 132 genes',
			tier_type: 'tabix',
			payload: 'bed',
			uri: '".$DALLIANCE_DATA_DIR_URI."designs/seqcap_targets_sorted.132.bed.gz'},
		";
}

my ($dal_start, $dal_stop, $highlight_start, $highlight_end) = (($evs_pos_start-$padding), ($evs_pos_end+$padding), $evs_pos_start, $evs_pos_end);
#if ($highlight_start == $highlight_end) {$highlight_end++}
$highlight_end++;


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
		$sources
		{name: 'Conservation',
			desc: 'PhastCons 100 way',
			bwgURI: '".$DALLIANCE_DATA_DIR_URI."cons/hg19.100way.phastCons.bw',
			noDownsample: true},
		{name: 'Repeats',
			desc: 'Repeat annotation from RepeatMasker', 
			bwgURI: '".$DALLIANCE_DATA_DIR_URI."repeats/repeats.bb',
			stylesheet_uri: '".$DALLIANCE_DATA_DIR_URI."repeats/bb-repeats2.xml',
			forceReduction: -1},
		
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
		\$(window).scrollTop(0);
	});
";

print $q->br(), $q->script({'type' => 'text/javascript', 'defer' => 'defer'}, $browser), $q->div({'id' => 'svgHolder', 'class' => 'fitin'}, 'Dalliance Browser here'), $q->br(), $q->br(), "\n",
	$q->end_div();

my $text = '<br/>Les données collectées dans la zone de texte libre doivent être pertinentes, adéquates et non excessives au regard de la finalité du traitement. Elles ne doivent pas comporter d\'appréciations subjectives, ni directement ou indirectement, permettre l\'identification d\'un patient, ni faire apparaitre des données dites « sensibles » au sens de l\'article 8 de la loi n°78-17 du 6 janvier 1978 relative à l\'informatique, aux fichiers et aux libertés.';

print U2_modules::U2_subs_2::info_panel($text, $q);

#end genome browser




#$q->start_div(), $q->p('Les données collectées dans la zone de texte libre doivent être pertinentes, adéquates et non excessives au regard de la finalité du traitement. Elles ne doivent pas comporter d\'appréciations subjectives, ni directement ou indirectement, permettre l\'identification d\'un patient, ni faire apparaitre des données dites « sensibles » au sens de l\'article 8 de la loi n°78-17 du 6 janvier 1978 relative à l\'informatique, aux fichiers et aux libertés.');



##Basic end of USHVaM 2 perl scripts:

if ($user->isPublic() == 1) {U2_modules::U2_subs_1::public_end_html($q)}
else {U2_modules::U2_subs_1::standard_end_html($q)}

print $q->end_html();

exit();

##End of Basic end

##specific subs for current script

sub menu_class {
	my ($classe, $field, $q, $dbh) = @_;
	my @class_list;
	my $html2return = $q->br().$q->br().$q->start_div({'align' => 'center'}).$q->start_Select({'id' => $field.'_select'});
	my $query = "SELECT $field FROM valid_classe ORDER BY ordering;";
	if ($field eq 'acmg_class') {$query = "SELECT DISTINCT($field) FROM valid_classe ORDER BY $field;"}
	my $sth = $dbh->prepare($query);
	my $res = $sth->execute();
	while (my $result = $sth->fetchrow_hashref()) {
		if ($field eq 'acmg_class') {
			my $options = 'style = "color:'.U2_modules::U2_subs_1::color_by_acmg_classe($result->{'acmg_class'}, $dbh).';"';
			if ($result->{'acmg_class'} eq $classe) {$options .= ' selected = "selected"'}
			$html2return .= $q->option({$options}, $result->{'acmg_class'})
		}
		else {
			my $options = 'style = "color:'.U2_modules::U2_subs_1::color_by_classe($result->{'classe'}, $dbh).';"';
			if ($result->{'classe'} eq $classe) {$options .= ' selected = "selected"'}
			$html2return .= $q->option({$options}, $result->{'classe'})
		}
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


