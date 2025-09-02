BEGIN {delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV', 'PATH'};}

use strict;
# use CGI; #in startup.pl
# use DBI();
# use JSON;
# use AppConfig qw(:expand :argcount);
# use Bio::EnsEMBL::Registry;
use U2_modules::U2_init_1;
use U2_modules::U2_subs_1;
use U2_modules::U2_subs_2;
use U2_modules::U2_subs_3;
use U2_modules::U2_users_1;
use SOAP::Lite;
use File::Temp qw/ :seekable /;
use List::Util qw(min max);
# use IPC::Open2;
# use Data::Dumper;
use URI::Escape;
use LWP::UserAgent;
use Net::Ping;
use URI::Encode qw/uri_encode uri_decode/;
use JSON;
use File::Copy;
use Net::OpenSSH;


#use XML::Compile::WSDL11;      # use WSDL version 1.1
#use XML::Compile::SOAP11;      # use SOAP version 1.1
#use XML::Compile::Transport::SOAPHTTP;


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
#		this script is called by ajax and retrieves various features

my $config_file = U2_modules::U2_init_1->getConfFile();
my $config = U2_modules::U2_init_1->initConfig();
$config->file($config_file);
my $DB = $config->DB();
my $HOST = $config->HOST();
my $HOME = $config->HOME();
my $HOME_IP = $config->HOME_IP();
my $DB_USER = $config->DB_USER();
my $DB_PASSWORD = $config->DB_PASSWORD();
my $HTDOCS_PATH = $config->HTDOCS_PATH();
my $ABSOLUTE_HTDOCS_PATH = $config->ABSOLUTE_HTDOCS_PATH();
my $DATABASES_PATH = $config->DATABASES_PATH();
my $EXE_PATH = $config->EXE_PATH();
my $ANALYSIS_ILLUMINA_REGEXP = $config->ANALYSIS_ILLUMINA_REGEXP();
my $ANALYSIS_ILLUMINA_PG_REGEXP = $config->ANALYSIS_ILLUMINA_PG_REGEXP();
my $NENUFAAR_ANALYSIS = $config->NENUFAAR_ANALYSIS();
my $DBNSFP_V2 = $config->DBNSFP_V2();
my $DBNSFP_V3_PATH = $config->DBNSFP_V3_PATH();
my $SEAL_NAS_CHU = $config->SEAL_NAS_CHU();
my $SEAL_VCF_PATH = $config->SEAL_VCF_PATH();
my $TMP_DIR = $config->TMP_DIR();
my $NAS_CHU_BASE_DIR = $config->NAS_CHU_BASE_DIR();

my $dbh = DBI->connect(    "DBI:Pg:database=$DB;host=$HOST;",
                        $DB_USER,
                        $DB_PASSWORD,
                        {'RaiseError' => 1}
                ) or die $DBI::errstr;

my $q = new CGI;

my $user = U2_modules::U2_users_1->new();



if ($q->param('asked') && $q->param('asked') eq 'exons') {
	print $q->header();
	my ($gene, $second_name) = U2_modules::U2_subs_1::check_gene($q, $dbh);
	my $query = "SELECT a.nom as name, a.numero as number FROM segment a, gene b WHERE a.refseq = b.refseq AND b.gene_symbol = '$gene' AND b.main = 't' AND a.type <> 'intron' ORDER BY a.numero;";
	my $sth = $dbh->prepare($query);
	my $res = $sth->execute();
	my ($labels, @values);
	while (my $result = $sth->fetchrow_hashref()) {
		$labels->{$result->{'number'}} = $result->{'name'};
		push @values, $result->{'number'};
	}
	print $q->popup_menu(-name => 'exons', -id => 'exons', -values => \@values, -labels => $labels, -class => 'w3-select w3-border');
}


if ($q->param('asked') && $q->param('asked') eq 'ext_data') {
	print $q->header();
	my $variant = U2_modules::U2_subs_1::check_nom_g($q, $dbh);

	my $query = "SELECT a.nom, b.gene_symbol as gene, b.refseq as acc, a.nom_g_38, a.snp_id, a.type_adn, a.type_segment, b.dfn, b.usher, b.ns_gene FROM variant a, gene b WHERE a.refseq = b.refseq AND a.nom_g = '$variant';";
	my $res = $dbh->selectrow_hashref($query);
	my ($text, $semaph) = ('', 0);
	$text .= $q->start_Tr() . $q->td('DVD & LOVD:') . $q->start_td() . $q->start_ul() . "\n";
	####TEMP COMMENT connexion to DVD really slow comment for the moment
	if ($res->{'ns_gene'} == 1 && ($res->{'dfn'} == 1 || $res->{'usher'} == 1)) {
		my $url = 'https://deafnessvariationdatabase.org';

		if ($res->{'type_adn'} eq 'substitution') {
			my $no_chr_var = U2_modules::U2_subs_1::extract_dvd_var($variant);
			my $iowa_url = "$url/variant/".uri_encode($no_chr_var);
			my $ua = LWP::UserAgent->new(ssl_opts => { verify_hostname => 0, });
			$ua->timeout(3);
			my $fetch = $ua->get($iowa_url);
			if ($fetch->is_success()) {
				my $content = $fetch->content();
				if ($content !~ /is\snot\sin\sthe\sDVD/o) {$text .= $q->start_li() . $q->a({'href' => $iowa_url, 'target' => '_blank'}, 'DVD') . $q->end_li() . "\n"}
				else {$text .= $q->li('Not recorded in the DVD')}
			}
			else {
				$text .= $q->start_li() . $q->a({'href' => $iowa_url, 'target' => '_blank'}, 'Try DVD?') . $q->end_li() . "\n";
			}
		}
		else {
			my $no_chr_var = U2_modules::U2_subs_1::extract_chrpos_var($variant);
			my $iowa_url = "$url/hg19s?terms=".uri_encode($no_chr_var);
			$text .= $q->start_li() . $q->a({'href' => $iowa_url, 'target' => '_blank'}, 'Try DVD?') . $q->end_li() . "\n";
		}
	}

	####END TEMP COMMENT

	#then we add LOVD here!!!

	my ($evs_chr, $evs_pos_start, $evs_pos_end) = U2_modules::U2_subs_1::extract_pos_from_genomic($variant, 'evs');

	my $url = "http://www.lovd.nl/search.php?build=hg19&position=chr$evs_chr:".$evs_pos_start."_".$evs_pos_end;
	my $lovd_gene = $res->{'gene'};
	if ($lovd_gene eq 'DFNB31') {$lovd_gene = 'WHRN'}
	elsif ($lovd_gene eq 'CLRN1') {$lovd_gene = 'USH3A'}
	elsif ($lovd_gene eq 'ADGRV1') {$lovd_gene = 'GPR98'}

	my $local_url = "$HOME_IP/lovd/Usher_montpellier/api/rest.php/variants/$lovd_gene?search_Variant/DNA=$res->{'nom'}";
	my $ua = new LWP::UserAgent();
	$ua->timeout(10);
	my $response = $ua->get($url);


	#c.13811+2T>G
	#"hg_build"	"g_position"	"gene_id"	"nm_accession"	"DNA"	"variant_id"	"url"
	#"hg19"	"chr1:215847440"	"USH2A"	"NM_206933.2"	"c.13811+2T>G"	"USH2A_00751"	"https://grenada.lumc.nl/LOVD2/Usher_montpellier/variants.php?select_db=USH2A&action=search_all&search_Variant%2FDBID=USH2A_00751"
	#my $response = $ua->request($req);https://grenada.lumc.nl/LOVD2/Usher_montpellier/variants.php?select_db=MYO7A&action=search_all&search_Variant%2FDBID=MYO7A_00018
  	# LOVD2 is now hosted at home, then cannot be retrived anymore by the search script, then we should always propose the link

	if($response->is_success()) {
		my $escape_var = $res->{'nom'};
		$escape_var =~ s/\+/\\\+/og;
		if ($escape_var =~ /^(c\..+d[ue][lp])[ATGC]+/o) {$escape_var = $1}

		if ($response->decoded_content() =~ /"$escape_var".+"(http[^"]+)"/g) {
			my @matches = $response->decoded_content() =~ /"$escape_var".+"(http[^"]+)"/g;
			$text .= $q->start_li().$q->strong('LOVD matches: ').$q->start_ul();
			my $i = 1;
			foreach (@matches) {
				if ($_ =~ /http.+Usher_montpellier\//g) {next;}
				elsif ($_ =~ /http.+databases\.lovd\.nl\/shared\//g) {$text .= $q->start_li() . $q->a({'href' => $_, 'target' => '_blank'}, 'LOVD3 shared') . $q->end_li()}
				elsif ($_ =~ /http.+databases\.lovd\.nl\/whole_genome\//g) {$text .= $q->start_li() . $q->a({'href' => $_, 'target' => '_blank'}, 'LOVD3 whole genome') . $q->end_li()}
				else {$text .= $q->start_li() . $q->a({'href' => $_, 'target' => '_blank'}, "Link $i") . $q->end_li();$i++;}
			}
		}
	}

	if (grep /$res->{'gene'}/, @U2_modules::U2_subs_1::LOVD) {
    my $response = $ua->get($local_url);
    if($response->is_success() && $response->decoded_content() =~ /Variant\/DBID:$lovd_gene\_(\d+)/g) {
        $text .= $q->start_li() . $q->a({'href' => "https://ushvamdev.pmmg.priv/lovd/Usher_montpellier/variants.php?select_db=".$lovd_gene."&action=search_unique&order=Variant%2FDNA%2CASC&hide_col=&show_col=&limit=100&search_Variant%2FLocation=&search_Variant%2FExon=&search_Variant%2FDNA=&search_Variant%2FRNA=&search_Variant%2FProtein=&search_Variant%2FDomain=&search_Variant%2FInheritance=&search_Variant%2FRemarks=&search_Variant%2FdbSNP=&search_Variant%2FReference=&search_Variant%2FReported_effect=&search_Variant%2FFrequency=&search_Variant%2FUSMA=&search_Variant%2FHSF=&search_Variant%2FRestriction_site=&search_Variant%2FDBID=".$lovd_gene."_$1", 'target' => '_blank'}, 'LOVD2 USHbases') . $q->end_li();
    }
    else {
  		$res->{'nom'} =~ /(\w+\d)/og;
  		my $pos_cdna = $1;
  		$text .= $q->start_li() . $q->a({'href' => "https://ushvamdev.pmmg.priv//lovd/Usher_montpellier/variants.php?select_db=".$lovd_gene."&action=search_unique&order=Variant%2FDNA%2CASC&hide_col=&show_col=&limit=100&search_Variant%2FLocation=&search_Variant%2FExon=&search_Variant%2FDNA=$pos_cdna&search_Variant%2FRNA=&search_Variant%2FProtein=&search_Variant%2FDomain=&search_Variant%2FInheritance=&search_Variant%2FRemarks=&search_Variant%2FReference=&search_Variant%2FRestriction_site=&search_Variant%2FFrequency=&search_Variant%2FDBID=", 'target' => '_blank'}, 'LOVD USHbases?') . $q->end_li();
    }
	}
	else {
		$text .= $q->start_li() . $q->a({'href' => "http://grenada.lumc.nl/LSDB_list/lsdbs/$res->{'gene'}", 'target' => '_blank'}, 'LOVD?') . $q->end_li();
	}
  $text .= $q->end_ul() . $q->end_li();

	$text .= $q->end_ul() .  $q->end_td() . $q->td('Links to the DVD and LOVD') . $q->end_Tr() . "\n";
	print $text;
}

if ($q->param('asked') && $q->param('asked') eq 'class') {
	print $q->header();
	my $variant = U2_modules::U2_subs_1::check_nom_c($q, $dbh);
	my ($gene, $second_name) = U2_modules::U2_subs_1::check_gene($q, $dbh);
	my $acc = U2_modules::U2_subs_1::check_acc($q, $dbh);
	my $field;
	if ($q->param('field') eq 'classe' || $q->param('field') eq 'acmg_class') {$field = $q->param('field')}
	else {U2_modules::U2_subs_1::standard_error('17', $q)}
	my $class;
	if ($field eq 'classe') {$class= U2_modules::U2_subs_1::check_class($q, $dbh)}
	else {$class= U2_modules::U2_subs_1::check_acmg_class($q, $dbh)}

	my $update = "UPDATE variant SET $field = '$class' WHERE nom = '$variant' AND refseq = '$acc';";
	if (U2_modules::U2_subs_1::is_class_pathogenic($class) == 1){
		$update = "UPDATE variant SET $field = '$class', defgen_export = 't' WHERE nom = '$variant' AND refseq = '$acc';";
	}
	$dbh->do($update);
}
if ($q->param('asked') && $q->param('asked') eq 'var_nom') {
	print $q->header();
	my $i = 0;

	my $variant = U2_modules::U2_subs_1::check_nom_g($q, $dbh);
	my $main = U2_modules::U2_subs_1::check_acc($q, $dbh);
	my $nom_c = U2_modules::U2_subs_1::check_nom_c($q, $dbh);
	$nom_c =~ s/\+/\\\+/g;
	# test mutalyzer
	if (U2_modules::U2_subs_1::test_mutalyzer() != 1) {U2_modules::U2_subs_1::standard_error('23', $q)}

	my $soap = SOAP::Lite->uri('http://mutalyzer.nl/2.0/services')->proxy('https://mutalyzer.nl/services/?wsdl');


	my $call = $soap->call('numberConversion',
			SOAP::Data->name('build')->value('hg19'),
			SOAP::Data->name('variant')->value($variant));

	if (!$call->result()) {print "mutalyzer fault";}
	my $return = $q->start_ul();
	foreach ($call->result()->{'string'}) {
		my $tab_ref;
		if (ref($_) eq 'ARRAY') {$tab_ref = $_}
		else {$tab_ref->[0] = $_}

		foreach (@{$tab_ref}) {
			if (/$main/ || /X[MR]_.+/o || /$nom_c/) {next}
			if ($i == 0) {$return .= $q->li("Alternative nomenclatures found as follow:")}
			# https://mutalyzer.nl/check?name=NM_001142763.1%3Ac.1319A%3EC
			if ($_ =~ /[\+-]/g) {$return .= $q->li($_)}
			else {$return .= $q->start_li().$q->span("$_ &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;").$q->start_a({'href' => 'https://v2.mutalyzer.nl/check?name='.uri_escape($_), 'target' => '_blank'}).$q->span('Mutalyzer').$q->img({'src' => $HTDOCS_PATH.'data/img/link_small.png', 'border' => '0', 'width' =>'15'}).$q->end_a().$q->end_li()."\n"}
			$i++;
		}
	}
	if ($i > 0) {$return .= $q->end_ul()}
	else {$return = "No alternative nomenclature found."}
	print $return;

}
if ($q->param('asked') && $q->param('asked') eq 'var_info') {
	print $q->header();
	my ($gene, $second, $acc, $nom_c, $analyses, $current_analysis, $depth, $frequency, $wt_f, $wt_r, $mt_f, $mt_r, $msr_filter, $last_name, $first_name, $nb) = (U2_modules::U2_subs_1::check_gene($q, $dbh), U2_modules::U2_subs_1::check_acc($q, $dbh), U2_modules::U2_subs_1::check_nom_c($q, $dbh), $q->param('analysis_all'), $q->param('current_analysis'), $q->param('depth'), $q->param('frequency'), $q->param('wt_f'), $q->param('wt_r'), $q->param('mt_f'), $q->param('mt_r'), $q->param('msr_filter'), $q->param('last_name'), $q->param('first_name'), $q->param('nb'));

	my $info = $q->start_ul().$q->start_li().$q->start_strong().$q->em("$gene:").$q->span($nom_c).$q->end_strong().$q->end_li();

	my $print_ngs = '';
	if ($depth) {
		if ($current_analysis =~ /454-/o) {
			$info .= $q->start_li().$q->strong("$current_analysis values:").$q->start_ul().$q->start_li().$q->span("DOC: ").$q->strong($depth).$q->span(" Freq: ").$q->strong($frequency).$q->end_li().$q->start_li().$q->span("wt f: ").$q->strong($wt_f).$q->span(", wt r: ").$q->strong($wt_r).$q->end_li().$q->start_li().$q->span("mt f: ").$q->strong($mt_f).$q->span(", mt r: ").$q->strong($mt_r).$q->end_li().$q->end_ul().$q->end_li();
			# check if Illumina also??
			if ($analyses =~ /$ANALYSIS_ILLUMINA_REGEXP/) {
				my @matches = $analyses =~ /$ANALYSIS_ILLUMINA_REGEXP/g;
				foreach (@matches) {
					$info .= &miseq_details($_, $first_name, $last_name, $gene, $acc, $nom_c);
				}
			}

		}
		if ($current_analysis =~ /$ANALYSIS_ILLUMINA_REGEXP/) {
			$info .= $q->start_li().$q->strong("$current_analysis values:").$q->start_ul().$q->start_li().$q->span("DOC: ").$q->strong($depth).$q->span(" Freq: ").$q->strong($frequency).$q->end_li().$q->start_li().$q->span("MSR filter: ").$q->strong($msr_filter).$q->end_li().$q->end_ul().$q->end_li();
			my @matches = $analyses =~ /$ANALYSIS_ILLUMINA_REGEXP/g;
			if ($#matches > 0) {
				foreach (@matches) {
					if ($_ ne $current_analysis) {$info .= &miseq_details($_, $first_name, $last_name, $gene, $acc, $nom_c)}
				}
			}
			#check if 454 also??
			if ($analyses =~ /(454-\d+)/o) {
				my $query_ngs = "SELECT depth, frequency, wt_f, wt_r, mt_f, mt_r FROM variant2patient a, patient b WHERE a.num_pat = b.numero AND a.id_pat = b.identifiant AND b.first_name = '$first_name' AND b.last_name = '$last_name' AND a.refseq = '$acc' AND nom_c = '$nom_c' AND type_analyse = '$1';";
				my $res_ngs = $dbh->selectrow_hashref($query_ngs);
				$info .= $q->start_li().$q->strong("$current_analysis values:").$q->start_ul().$q->start_li().$q->span("DOC: ").$q->strong($res_ngs->{'depth'}).$q->span(" Freq: ").$q->strong($res_ngs->{'frequency'}).$q->end_li().$q->start_li().$q->span("wt f: ").$q->strong($res_ngs->{'wt_f'}).$q->span(", wt r: ").$q->strong($res_ngs->{'wt_r'}).$q->end_li().$q->start_li().$q->span("mt f: ").$q->strong($res_ngs->{'mt_f'}).$q->span(", mt r: ").$q->strong($res_ngs->{'mt_r'}).$q->end_li().$q->end_ul().$q->end_li();
			}
		}
	}
	$info .= $q->end_ul();
	print $info;
}
# if ($q->param('asked') && $q->param('asked') eq 'ponps') {
# 	print $q->header();
# 	my $text = $q->start_ul();

# 	my ($aa_ref, $aa_alt) = U2_modules::U2_subs_1::decompose_nom_p($q->param('var_prot'));

# 	my ($i, $j) = (0, 0);

# 	my $var_g = U2_modules::U2_subs_1::check_nom_g($q, $dbh);
# 	if ($var_g =~ /chr($U2_modules::U2_subs_1::CHR_REGEXP):$U2_modules::U2_subs_1::HGVS_CHR_TAG\.(\d+)([ATGC])>([ATGC])/) {
# 		my ($chr, $pos1, $ref, $alt) = ($1, $2, $3, $4);

# 		#NEW style 04/2018 replacment of VEP with dbNSFP
# 		$chr =~ s/chr//og;
# 		my @dbnsfp =  split(/\n/, `$EXE_PATH/tabix $DATABASES_PATH$DBNSFP_V2 $chr:$pos1-$pos1`);
# 		#my @dbnsfp =  split(/\n/, `$EXE_PATH/tabix $DATABASES_PATH$DBNSFP_V2 $chr:207634224-207634224`);

# 		#print $#dbnsfp.'-'.$dbnsfp[0];
# 		if ($dbnsfp[0] eq '') {print 'No values in dbNSFP v2.9 for this variant.';exit;}
# 		#if ($#dbnsfp < 2) {print 'No values in dbNSFP v2.9 for this variant.';exit;}
# 		foreach (@dbnsfp) {
# 			my @current = split(/\t/, $_);
# 			if (($current[2] eq $ref) && ($current[3] eq $alt) && ($current[4] eq $aa_ref) && ($current[5] eq $aa_alt)) {
# 				my $sift = U2_modules::U2_subs_2::most_damaging($current[26], 'min');
# 				if (U2_modules::U2_subs_1::sift_color($sift) eq '#FF0000') {$i++}
# 				if ($sift ne '') {$j++}
# 				my $polyphen = U2_modules::U2_subs_2::most_damaging($current[32], 'max');
# 				if (U2_modules::U2_subs_1::pph2_color2($polyphen) eq '#FF0000') {$i++}
# 				if ($polyphen ne '') {$j++}
# 				my $fathmm = U2_modules::U2_subs_2::most_damaging($current[44], 'min');
# 				if (U2_modules::U2_subs_1::fathmm_color($fathmm) eq '#FF0000') {$i++}
# 				if ($fathmm ne '') {$j++}
# 				my $metalr = U2_modules::U2_subs_2::most_damaging($current[50], 'max');
# 				if (U2_modules::U2_subs_1::metalr_color($metalr) eq '#FF0000') {$i++}
# 				if ($metalr ne '') {$j++}
# 				#my $ea_maf = my $aa_maf = my $exac_maf = my $1kg_maf = -1;
# 				my $ea_maf = sprintf('%.4f', $current[93]);
# 				my $aa_maf = sprintf('%.4f', $current[92]);
# 				my $exac_maf = sprintf('%.4f', $current[101]);
# 				my $onekg_maf = sprintf('%.4f', $current[83]);
# 				if (max($ea_maf, $aa_maf, $exac_maf, $onekg_maf) > -1) {
# 					$j++;
# 					if (max($ea_maf, $aa_maf, $exac_maf, $onekg_maf) < 0.005) {$i++}
# 				}
# 				if (U2_modules::U2_subs_2::dbnsfp_clinvar2text($current[115]) =~ /Pathogenic/) {$i++}
# 				if (U2_modules::U2_subs_2::dbnsfp_clinvar2text($current[115]) ne 'not seen in Clinvar') {$j++}

# 				$text .= $q->start_li().
# 							$q->span({'onclick' => 'window.open(\'http://sift.bii.a-star.edu.sg\')', 'class' => 'pointer'}, 'SIFT').
# 							$q->span(" score: ").$q->span({'style' => 'color:'.U2_modules::U2_subs_1::sift_color($sift)}, $sift).$q->end_li()."\n".
# 						$q->end_li()."\n".
# 						$q->start_li().
# 							$q->span({'onclick' => 'window.open(\'http://genetics.bwh.harvard.edu/pph2/\')', 'class' => 'pointer'}, 'Polyphen2').
# 							$q->span(" score: ").$q->span({'style' => 'color:'.U2_modules::U2_subs_1::pph2_color2($polyphen)}, $polyphen).$q->end_li()."\n".
# 						$q->end_li()."\n".
# 						$q->start_li().
# 							$q->span({'onclick' => 'window.open(\'http://fathmm.biocompute.org.uk/\')', 'class' => 'pointer'}, 'FATHMM').
# 							$q->span(" score: ").$q->span({'style' => 'color:'.U2_modules::U2_subs_1::fathmm_color($fathmm)}, $fathmm).$q->end_li()."\n".
# 						$q->end_li()."\n".
# 						$q->start_li().
# 							$q->span({'onclick' => 'window.open(\'http://exac.broadinstitute.org/\')', 'class' => 'pointer'}, 'MetaLR').
# 							$q->span(" score: ").$q->span({'style' => 'color:'.U2_modules::U2_subs_1::metalr_color($metalr)}, $metalr).$q->end_li()."\n".
# 						$q->end_li()."\n";
# 				my ($ratio, $class) = (0, 'one_quarter');
# 				if ($j != 0) {
# 					$ratio = sprintf('%.2f', ($i)/($j));
# 					if ($ratio >= 0.25 && $ratio < 0.5) {$class = 'two_quarter'}
# 					elsif ($ratio >= 0.5 && $ratio < 0.75) {$class = 'three_quarter'}
# 					elsif ($ratio >= 0.75) {$class = 'four_quarter'}

# 					$text .= $q->start_li().$q->span({'class' => $class}, 'MD experimental pathogenic ratio: ').$q->span({'class' => $class}, "$ratio, ($i/$j)").$q->end_li();
# 				}
# 			}
# 		}
# 	}
# 	$text .= $q->end_ul();
# 	print $text;
# }

if ($q->param('asked') && $q->param('asked') eq 'var_list') {
	print $q->header();
	my ($type, $nom, $num_seg, $order);
	if ($q->param('type') && $q->param('type') =~ /(exon|intron|5UTR|3UTR|intergenic)/o) {$type = $1}
	else {print 1;U2_modules::U2_subs_1::standard_error(15, $q)}
	if ($q->param('nom') && $q->param('nom') =~ /(\w+)/o || $q->param('nom') == '0') {$nom = '0';if ($1) {$nom = $1}}
	else {print 2;U2_modules::U2_subs_1::standard_error(15, $q)}
	if ($q->param('numero') && $q->param('numero') =~ /([\d-]+)/o) {$num_seg = $1}
	else {print 3;U2_modules::U2_subs_1::standard_error(15, $q)}
	my ($gene, $second_name) = U2_modules::U2_subs_1::check_gene($q, $dbh);
	my $acc_no = U2_modules::U2_subs_1::check_acc($q, $dbh);
	if ($q->param('order') && $q->param('order') =~ /([ASCDE]+)/o) {$order = $1}
	else {print 4;U2_modules::U2_subs_1::standard_error(15, $q)}

	my $name = 'nom_prot';
	if ($type ne 'exon') {$name = 'nom_ivs'}

	my $query = "SELECT nom, $name as nom2, classe FROM variant WHERE refseq = '$acc_no' AND num_segment = '$num_seg' AND type_segment = '$type' ORDER BY nom_g $order;";
	if ($user->isPublic == 1) {$query = "SELECT nom, $name as nom2, classe FROM variant WHERE refseq = '$acc_no' AND num_segment = '$num_seg' AND type_segment = '$type' AND (nom) NOT IN (SELECT nom_c FROM variant2patient WHERE refseq = '$acc_no') ORDER BY nom_g $order;"}
	my $sth = $dbh->prepare($query);
	my $res = $sth->execute();
	my $html = $q->start_ul();
	if ($res ne '0E0') {
		while (my $result = $sth->fetchrow_hashref()) {
			my $color = U2_modules::U2_subs_1::color_by_classe($result->{'classe'}, $dbh);
			$html .= $q->li({'style' => "color:$color", 'class' => 'pointer', 'onclick' => "window.open('variant.pl?gene=$gene&accession=$acc_no&nom_c=".uri_escape($result->{'nom'})."', '_blank')", 'title' => 'Go to the variant page'}, "$result->{'nom'} - $result->{'nom2'}")."\n";
		}
	}
	else {$html .= "No variants reported in $type $nom."}

	$html.= $q->end_ul();

	if (U2_modules::U2_subs_1::get_chr_from_gene($gene, $dbh) ne 'M') {

		my ($default_status, $default_allele) = ('heterozygous', 'unknown');

		if ($user->isPublic != 1) {$html .= $q->start_p().$q->strong('Create a variant not linked to a specific sample:').$q->end_p()}
		else {$html .= $q->start_p().$q->strong('Create a variant:').$q->end_p()}

		my $ng_accno = U2_modules::U2_subs_1::get_ng_accno($gene, $acc_no, $dbh, $q);

		$html .= $q->start_form({'action' => '', 'method' => 'post', 'class' => 'u2form', 'id' => 'creation_form', 'enctype' => &CGI::URL_ENCODED}).
						$q->input({'type' => 'hidden', 'name' => 'gene', 'value' => $gene, 'id' => 'gene', 'form' => 'creation_form'})."\n".
						$q->input({'type' => 'hidden', 'name' => 'acc_no', 'value' => $acc_no, 'id' => 'acc_no', 'form' => 'creation_form'})."\n".
						$q->input({'type' => 'hidden', 'name' => 'type', 'value' => $type, 'id' => 'type', 'form' => 'creation_form'})."\n".
						$q->input({'type' => 'hidden', 'name' => 'numero', 'value' => $num_seg, 'id' => 'numero', 'form' => 'creation_form'})."\n".
						$q->input({'type' => 'hidden', 'name' => 'nom', 'value' => $nom, 'id' => 'nom', 'form' => 'creation_form'})."\n".
						$q->input({'type' => 'hidden', 'name' => 'ng_accno', 'value' => $ng_accno, 'id' => 'ng_accno', 'form' => 'creation_form'})."\n".
						$q->start_fieldset();
		my @status = ('heterozygous', 'homozygous', 'hemizygous');
		my @alleles = ('unknown', 'both', '1', '2');
		my $js = "if (\$(\"#status\").val() === 'homozygous') {\$(\"#allele\").val('both')}else {\$(\"#allele\").val('unknown')}";
		$html .= $q->br().$q->br().$q->start_li()."\n".
				$q->label({'for' => 'new_variant'}, 'New variant (cDNA):')."\n".
				$q->textfield(-name => 'new_variant', -id => 'new_variant', -value => 'c.', -size => '20', -maxlength => '100')."\n".
			$q->end_li()."\n".
			$q->end_ol().$q->end_fieldset().$q->end_form();
	}

	print $html;
}


if ($q->param('asked') && $q->param('asked') eq 'var_all') {
	print $q->header();
	my ($gene, $second_name) = U2_modules::U2_subs_1::check_gene($q, $dbh);
	my ($sort_value, $sort_type, $css_class);
	if ($q->param('sort_type') && $q->param('sort_type') =~ /(classe|type_adn|type_prot|type_arn|all)/o) {$sort_type = $1}
	else {print 'sort_type';U2_modules::U2_subs_1::standard_error(15, $q)}
	if ($q->param('sort_value') && $q->param('sort_value') =~ /([\w\s]+)/o) {$sort_value = $1}
	else {print 'sort_value';U2_modules::U2_subs_1::standard_error(15, $q)}
	if ($q->param('css_class') && $q->param('css_class') =~ /([\w\s]+)/og) {$css_class = $1;$css_class =~ s/ /_/og;}

	my $text;
	#need to know main #acc
	my $query = "SELECT refseq as main FROM gene WHERE gene_symbol = '$gene' AND main = 't'";
	my $res = $dbh->selectrow_hashref($query);
	my $main = $res->{'main'};

	my ($order, $toprint, $freq) = ('a.nom_g '.U2_modules::U2_subs_1::get_strand($gene, $dbh), 'frequency', '1');
	if ($q->param('freq') && $q->param('freq') == 1) {($order, $toprint, $freq) = ('COUNT(b.nom_c) DESC', 'position', '2')}


	$query = "WITH tmp AS (SELECT DISTINCT(a.nom_c, a.num_pat, a.id_pat, a.refseq), a.nom_c, a.refseq, c.gene_symbol FROM variant2patient a, variant b, gene c WHERE a.nom_c = b.nom AND a.refseq = b.refseq AND b.refseq = c.refseq AND c.gene_symbol = '$gene' AND $sort_type = '$sort_value')\nSELECT a.nom, a.classe, a.refseq, a.nom_prot, a.nom_ivs, COUNT(b.nom_c) as allel FROM variant a, tmp b WHERE a.nom = b.nom_c AND a.refseq = b.refseq AND b.gene_symbol = '$gene' GROUP BY a.classe, a.nom, a.refseq, a.nom_prot, a.nom_ivs, a.nom_g ORDER BY $order;";
	if ($sort_type eq 'all') {
    $query = "WITH tmp AS (SELECT DISTINCT(a.nom_c, a.num_pat, a.id_pat, a.refseq), a.nom_c, a.refseq, b.gene_symbol FROM variant2patient a, gene b WHERE a.refseq = b.refseq AND b.gene_symbol = '$gene')\nSELECT a.nom, a.classe, a.refseq, a.nom_prot, a.nom_ivs, COUNT(b.nom_c) as allel FROM variant a, tmp b, gene c WHERE a.nom = b.nom_c AND a.refseq = b.refseq AND b.refseq = c.refseq AND c.gene_symbol = '$gene' GROUP BY a.nom_g, a.classe, a.nom, a.refseq, a.nom_prot, a.nom_ivs ORDER BY $order;";
	}
	#print $query;
	my $sth = $dbh->prepare($query);
	$res = $sth->execute();
	if ($res ne '0E0') {
		$text = $q->start_p().
				$q->span({'class' => 'w3-button w3-ripple w3-blue', 'onclick' => "showAllVariants('$gene', '$sort_value', '$sort_type', '$freq', '$css_class');"}, "Sort by $toprint").
			$q->end_p().
			$q->start_ul();
		while (my $result = $sth->fetchrow_hashref()) {
			my $color = U2_modules::U2_subs_1::color_by_classe($result->{'classe'}, $dbh);
			my $name2 = $result->{'nom_prot'} if $result->{'nom_prot'};
			if ($result->{'nom_ivs'} ne '') {$name2 = $result->{'nom_ivs'}}
			my $acc_no = '';
			if ($result->{'ref_seq'} ne $main) {$acc_no = "$result->{'refseq'}:"}

			my $spec = '';
			if ($sort_type eq 'type_arn') {
				my $value = U2_modules::U2_subs_1::get_interpreted_position($result, $dbh, 'span', $q);
				my $css_class = $value;
				$css_class =~ s/ /_/og;
				$spec = $q->span({'class' => $css_class}, " - $value")
			}

			$text .= $q->start_li().$q->span({'style' => "color:$color", 'class' => 'pointer', 'onclick' => "window.open('variant.pl?gene=$gene&accession=$result->{'refseq'}&nom_c=".uri_escape($result->{'nom'})."', \'_blank\')", 'title' => 'Go to the variant page'}, "$acc_no$result->{'nom'} - $name2").$q->span(" in $result->{'allel'} patients(s) ").$spec.$q->end_li();
		}
		$text .= $q->end_ul();
	}
	print $text;
}

if ($q->param('asked') && $q->param('asked') eq 'change_filter') {

	# not called by ajax but it was a good place to put it
	print $q->header();
	my ($id, $number) = U2_modules::U2_subs_1::sample2idnum(uc($q->param('sample')), $q);
	my $analysis = U2_modules::U2_subs_1::check_analysis($q, $dbh, 'filtering');
	my $new_filter = U2_modules::U2_subs_1::check_filter($q);
	my $update = "UPDATE miseq_analysis SET filter = '$new_filter' WHERE num_pat = '$number' AND id_pat = '$id' AND type_analyse = '$analysis';";
	$dbh->do($update);
	print $q->redirect("patient_file.pl?sample=$id$number")
}

if ($q->param('asked') && $q->param('asked') eq 'rna_status') {
	print $q->header();
	my $variant = U2_modules::U2_subs_1::check_nom_c($q, $dbh);
	my ($gene, $second_name) = U2_modules::U2_subs_1::check_gene($q, $dbh);
	my $acc = U2_modules::U2_subs_1::check_acc($q, $dbh);
	my $status = U2_modules::U2_subs_1::check_rna_status($q, $dbh);
	my $update = "UPDATE variant SET type_arn = '$status' WHERE nom = '$variant' AND refseq = '$acc';";
	$dbh->do($update);
	print $status;
}

if ($q->param('asked') && $q->param('asked') eq 'req_class') {
	print $q->header();
	my ($gene, $second_name) = U2_modules::U2_subs_1::check_gene($q, $dbh);
	my $variant = U2_modules::U2_subs_1::check_nom_c($q, $dbh);
	my $user = U2_modules::U2_users_1->new();
	U2_modules::U2_subs_2::request_variant_classification($user, $variant, $gene);
	print 'Request done.';
}


if ($q->param('asked') && $q->param('asked') eq 'defgen') {
	print $q->header();
	my ($id, $number) = U2_modules::U2_subs_1::sample2idnum(uc($q->param('sample')), $q);
	# need to get info on patients (for multiple samples)
	my ($list, $first_name, $last_name) = U2_modules::U2_subs_3::get_sampleID_list($id, $number, $dbh) or die "No sample info $!";
	my $query = "SELECT DISTINCT(b.nom_c), a.*, a.nom_prot as hgvs_prot, b.statut, b.allele, c.nom_prot, c.enst, c.acc_version, c.dfn, c.rp, c.usher, c.gene_symbol FROM variant a, variant2patient b, gene c WHERE a.refseq = b.refseq AND a.nom = b.nom_c AND a.refseq = c.refseq AND (b.id_pat, b.num_pat) IN ($list) AND a.defgen_export = 't';";
	my $sth = $dbh->prepare($query);
	my $res = $sth->execute();
	my $content =  "GENE;VARIANT;A_ENREGISTRER;ETAT;RESULTAT;VARIANT_P;VARIANT_C;ENST;NM;POSITION_GENOMIQUE;CLASSESUR5;CLASSESUR3;COSMIC;RS;REFERENCES;CONSEQUENCES;COMMENTAIRE;CHROMOSOME;GENOME_REFERENCE;NOMENCLATURE_HGVS;LOCALISATION;SEQUENCE_REF;LOCUS;ALLELE1;ALLELE2\r\n";
	if ($res ne '0E0') {
		while (my $result = $sth->fetchrow_hashref()) {
			#check filters
			my $filter = U2_modules::U2_subs_3::get_filter_from_idlist($list, $dbh);
			if ($filter eq 'RP' && $result->{'rp'} == 0) {next}
			elsif ($filter eq 'DFN' && $result->{'dfn'} == 0) {next}
			elsif ($filter eq 'USH' && $result->{'usher'} == 0) {next}
			elsif ($filter eq 'DFN-USH' && ($result->{'dfn'} == 0 && $result->{'usher'} == 0)) {next}
			elsif ($filter eq 'RP-USH' && ($result->{'rp'} == 0 && $result->{'usher'} == 0)) {next}
			elsif ($filter eq 'CHM' && $result->{'gene_symbol'} ne 'CHM') {next}


			my ($chr, $pos) = U2_modules::U2_subs_1::extract_pos_from_genomic($result->{'nom_g'}, 'clinvar');
			my $acmg_class = $result->{'acmg_class'};
			if ($acmg_class eq '') {$acmg_class = U2_modules::U2_subs_3::u2class2acmg($result->{'classe'}, $dbh)}
			my $defgen_acmg = &u22defgen_acmg($acmg_class);
			my ($defgen_a1, $defgen_a2) = U2_modules::U2_subs_3::get_defgen_allele($result->{'allele'});
			$content .= "$result->{gene_symbol};$result->{refseq}.$result->{acc_version}:$result->{nom_c};;".&u22defgen_status($result->{'statut'}).";;$result->{hgvs_prot};$result->{nom_c};$result->{enst};$result->{refseq}.$result->{acc_version};$pos;$defgen_acmg;;;$result->{snp_id};;$result->{type_prot};$result->{classe};$chr;hg19;$result->{nom_g};$result->{type_segment} $result->{num_segment};;;$defgen_a1;$defgen_a2\r\n";
		}
	}
	open F, '>'.$ABSOLUTE_HTDOCS_PATH.'data/defgen/'.$id.$number.'_defgen.csv' or die $!;
	print F $content;
	close F;
	print '<a href="'.$HTDOCS_PATH.'data/defgen/'.$id.$number.'_defgen.csv" download>Download file for '.$id.$number.'</a>';
}
if ($q->param('asked') && $q->param('asked') eq 'defgenMD') {
	print $q->header();
	my $nom_g = U2_modules::U2_subs_1::check_nom_g($q, $dbh);
	my $query = "SELECT a.gene_symbol, a.refseq, a.acc_version, b.nom as var, b.nom_prot as hgvs_prot, b.acmg_class, b.classe, a.enst, b.snp_id, b.type_prot, b.nom_g, b.type_segment, b.num_segment FROM gene a, variant b WHERE a.refseq = b.refseq AND b.nom_g = '$nom_g';";
	my $res = $dbh->selectrow_hashref($query);
	#
	my $content =  "GENE;VARIANT;A_ENREGISTRER;ETAT;RESULTAT;VARIANT_P;VARIANT_C;ENST;NM;POSITION_GENOMIQUE;CLASSESUR5;CLASSESUR3;COSMIC;RS;REFERENCES;CONSEQUENCES;COMMENTAIRE;CHROMOSOME;GENOME_REFERENCE;NOMENCLATURE_HGVS;LOCALISATION;SEQUENCE_REF;LOCUS;ALLELE1;ALLELE2\r\n";
	if ($res ne '0E0') {
		my ($chr, $pos) = U2_modules::U2_subs_1::extract_pos_from_genomic($res->{'nom_g'}, 'clinvar');
		my $acmg_class = $res->{'acmg_class'};
		if ($acmg_class eq '') {$acmg_class = U2_modules::U2_subs_3::u2class2acmg($res->{'classe'}, $dbh)}
		my $defgen_acmg = &u22defgen_acmg($acmg_class);
		$content .= "$res->{gene_symbol};$res->{refseq}.$res->{acc_version}:$res->{var};;;;$res->{hgvs_prot};$res->{var};$res->{enst};$res->{refseq}.$res->{acc_version};$pos;$defgen_acmg;;;$res->{snp_id};;$res->{type_prot};;$chr;hg19;$res->{nom_g};$res->{type_segment} $res->{num_segment};;;;\r\n";
		$nom_g =~ s/>/_/og;
		$nom_g =~ s/:/_/og;
		open F, '>'.$ABSOLUTE_HTDOCS_PATH.'data/defgen/'.$nom_g.'_defgen.csv' or die $!;
		print F $content;
		close F;
		print '<a href="'.$HTDOCS_PATH.'data/defgen/'.$nom_g.'_defgen.csv" download>Download file for '.$res->{refseq}.$res->{acc_version}.':'.$res->{var}.'</a>';
	}

}

if ($q->param('run_table') && $q->param('run_table') == 1) {
	print $q->header();
	my $analysis;
	if ($q->param('analysis') ne 'all') {$analysis = U2_modules::U2_subs_1::check_analysis($q, $dbh, 'form')}
	else {$analysis = 'all'}
	my ($total_runs, $total_samples) = (U2_modules::U2_subs_3::get_total_runs($analysis, $dbh), U2_modules::U2_subs_3::get_total_samples($analysis, $dbh));

	my $intro = $q->strong({'class' => 'w3-large'}, ucfirst($analysis)." runs table details: ($total_runs - $total_samples)");

	my $content = $q->start_div({'class' => 'w3-container'}).
			U2_modules::U2_subs_2::info_panel($intro, $q)."\n";
	$content .= $q->start_div({'class' => 'container'}).
		$q->start_table({'class' => 'great_table technical', 'id' => 'illumina_runs_table'}).
			$q->start_caption().
				$q->span('Illumina runs table (').$q->a({'href' => 'stats_ngs.pl?run=global', 'target' => '_blank'}, 'See all runs analysis').$q->span('):').
			$q->end_caption().
			$q->start_thead().
				$q->start_Tr()."\n".
					$q->th({'class' => 'left_general'}, 'Run ID')."\n".
					$q->th({'class' => 'left_general'}, 'Analysis type')."\n".
					$q->th({'class' => 'left_general'}, 'Run number')."\n".
					$q->th({'class' => 'left_general'}, '#Samples')."\n".
				$q->end_Tr().
			$q->end_thead().
			$q->start_tbody()."\n";

	my $query;
	if ($analysis eq 'all') {$query = 'SELECT DISTINCT(a.run_id), a.type_analyse, b.filtering_possibility FROM miseq_analysis a, valid_type_analyse b WHERE a.type_analyse = b.type_analyse ORDER BY a.type_analyse DESC, a.run_id;'}
	else {$query = "SELECT DISTINCT(a.run_id), a.type_analyse, b.filtering_possibility FROM miseq_analysis a, valid_type_analyse b WHERE a.type_analyse = b.type_analyse AND b.type_analyse = '$analysis' ORDER BY a.type_analyse DESC, a.run_id;"}
	my $i = my $j = my $k = my $l = my $m = my $n = my $o = my $p = my $r = my $s = my $t = my $u = my $v = my $w = my $z = my $a = 0;
	my $sth = $dbh->prepare($query);
	my $res = $sth->execute();
	if ($res ne '0E0') {
		while (my $result = $sth->fetchrow_hashref()) {

			my $query_samples = 'SELECT COUNT(id_pat || num_pat) as a FROM miseq_analysis WHERE run_id = \''.$result->{'run_id'}.'\';';
			my $num_samples = $dbh->selectrow_hashref($query_samples);

			if ($result->{'type_analyse'} eq 'MiSeq-28') {$i++;}
			elsif ($result->{'type_analyse'} eq 'MiSeq-112') {$j++;}
			elsif ($result->{'type_analyse'} eq 'MiSeq-121') {$k++;}
			elsif ($result->{'type_analyse'} eq 'MiSeq-152') {$u++;}
			elsif ($result->{'type_analyse'} eq 'MiSeq-3') {$l++;}
			elsif ($result->{'type_analyse'} eq 'MiSeq-132') {$o++;}
			elsif ($result->{'type_analyse'} eq 'MiniSeq-121') {$m++;}
			elsif ($result->{'type_analyse'} eq 'MiniSeq-132') {$n++;}
			elsif ($result->{'type_analyse'} eq 'MiniSeq-152') {$t++;}
			elsif ($result->{'type_analyse'} eq 'MiniSeq-158') {$v++;}
			elsif ($result->{'type_analyse'} eq 'MiniSeq-149') {$w++;}
			elsif ($result->{'type_analyse'} eq 'MiniSeq-157') {$z++;}
			elsif ($result->{'type_analyse'} eq 'MiniSeq-157-Twist') {$a++;}
			elsif ($result->{'type_analyse'} eq 'MiniSeq-3') {$p++;}
			elsif ($result->{'type_analyse'} eq 'NextSeq-ClinicalExome') {$r++;}
			elsif ($result->{'type_analyse'} eq 'MiniSeq-2') {$s++;}

			$content .= $q->start_Tr().
			$q->start_td().
				$q->a({'href' => "stats_ngs.pl?run=$result->{'run_id'}"}, $result->{'run_id'}).
			$q->end_td().
			$q->td($result->{'type_analyse'}." genes");

			if ($result->{'type_analyse'} eq 'MiSeq-28') {$content .= $q->td("Run $i")}
			elsif ($result->{'type_analyse'} eq 'MiSeq-112') {$content .= $q->td("Run $j")}
			elsif ($result->{'type_analyse'} eq 'MiSeq-121') {$content .= $q->td("Run $k")}
			elsif ($result->{'type_analyse'} eq 'MiSeq-3') {$content .= $q->td("Run $l")}
			elsif ($result->{'type_analyse'} eq 'MiSeq-132') {$content .= $q->td("Run $o")}
			elsif ($result->{'type_analyse'} eq 'MiSeq-152') {$content .= $q->td("Run $u")}
			elsif ($result->{'type_analyse'} eq 'MiniSeq-121') {$content .= $q->td("Run $m")}
			elsif ($result->{'type_analyse'} eq 'MiniSeq-132') {$content .= $q->td("Run $n")}
			elsif ($result->{'type_analyse'} eq 'MiniSeq-152') {$content .= $q->td("Run $t")}
			elsif ($result->{'type_analyse'} eq 'MiniSeq-158') {$content .= $q->td("Run $v")}
      		elsif ($result->{'type_analyse'} eq 'MiniSeq-149') {$content .= $q->td("Run $w")}
			elsif ($result->{'type_analyse'} eq 'MiniSeq-157') {$content .= $q->td("Run $z")}
			elsif ($result->{'type_analyse'} eq 'MiniSeq-157-Twist') {$content .= $q->td("Run $a")}
			elsif ($result->{'type_analyse'} eq 'MiniSeq-3') {$content .= $q->td("Run $p")}
			elsif ($result->{'type_analyse'} eq 'NextSeq-ClinicalExome') {$content .= $q->td("Run $r")}
			elsif ($result->{'type_analyse'} eq 'MiniSeq-2') {$content .= $q->td("Run $s")}
			$content .= $q->td($num_samples->{'a'});
			$content .= $q->end_Tr()
		}
		$content .= $q->end_tbody().$q->end_table().$q->end_div();
		print $content;

	}
	else {
		my $text = "No run to display for $analysis";
		print U2_modules::U2_subs_2::info_panel($text, $q);
	}
}

if ($q->param('run_graphs') && $q->param('run_graphs') == 1) {
	print $q->header();
	my $analysis;
	if ($q->param('analysis') ne 'all') {$analysis = U2_modules::U2_subs_1::check_analysis($q, $dbh, 'form')}
	else {$analysis = 'all'}
	my $genome = U2_modules::U2_subs_1::get_genome_from_analysis($analysis, $dbh);
	my ($total_runs, $total_samples) = (U2_modules::U2_subs_3::get_total_runs($analysis, $dbh), U2_modules::U2_subs_3::get_total_samples($analysis, $dbh));

	my $intro = $q->strong({'class' => 'w3-large'}, ucfirst($analysis)." runs graphs details: ($total_runs - $total_samples)");

	my $content = $q->start_div({'class' => 'w3-container'}).
			U2_modules::U2_subs_2::info_panel($intro, $q)."\n";
	if ($total_runs > 0) {
		my $loading = U2_modules::U2_subs_2::info_panel('Loading...', $q);
		chomp($loading);
		$loading =~ s/'/\\'/og;

		my $js = "
			function show_ngs_graph(analysis_value, label, row, table, math, floating) {
				\$(\'#graph_place\').html('$loading');
				\$.ajax({
					type: \"POST\",
					url: \"ajax.pl\",
					data: {draw_graph: 1, analysis: analysis_value, metric_type: label, pg_row: row, pg_table: table, math_type: math, floating_depth: floating}
				})
				.done(function(content) {
					\$(\'#graph_place\').hide();
					\$(\'#graph_place\').html(content);
					\$(\'#graph_place\').fadeTo(1000, 1);
					//\$(\'#graph_place\').show();
					graph_details();
				});
			}
		";
		$content .= $q->script({'type' => 'text/javascript'}, $js);
		my %metrics = (#label => cgi param, run type => {1,2} : 1: MSR or LRM; 2: nenufaar; 3: MobiDL, cluster {y,n}, math, float
			'On target %' => ['(cast(ontarget_reads as float)/cast(aligned_reads as float))*100', '1', 'n', 'AVG', '2'],
			'On target reads' => ['ontarget_reads', '1', 'n', 'SUM', '0'],
			'Duplicate reads %' => ['duplicates', '2', 'n', 'AVG', '2'],
			'Mean DoC' => ['mean_doc', '2', 'n', 'AVG', '0'],
			'Mean Target DoC' => ['mean_target_doc', '3', 'n', 'AVG', '0'],
			'50X %' => ['fiftyx_doc', '2', 'n', 'AVG', '2'],
			'SNVs' => ['snp_num', '2', 'n', 'AVG', '0'],
			'SNVs Ts/Tv' => ['snp_tstv', '2', 'n', 'AVG', '2'],
			'Indels' => ['indel_num', '3', 'n', 'AVG', '0'],
			'Insert size' => ['insert_size_median', '2', 'n', 'AVG', '0'],
			'Insert size SD' => ['insert_size_sd', '3', 'n', 'AVG', '0'],
			'Raw Clusters' => ['noc_raw', '1', 'y', '', '0'],
			'Usable Clusters %' => ['((noc_pf-(nodc+nouc_pf+nouic_pf))::FLOAT/noc_raw)*100', '1', 'y', '', '0'],
			'Duplicate Clusters %' => ['(nodc::FLOAT/noc_raw)*100', '1', 'y', '', '0'],
			'Unaligned Clusters %' => ['(nouc::FLOAT/noc_raw)*100', '1', 'y', '', '0'],
			'Unindexed Clusters %' => ['(nouic::FLOAT/noc_raw)*100', '1', 'y', '', '0'],
			'Density'  => ['cluster_density', '3', 'y', 'AVG', '0'],
			'Cluster PF'  => ['cluster_pf', '3', 'y', 'AVG', '0'],
			'%>=Q30'  => ['q30pc', '3', 'y', 'AVG', '2'],
			'Reads'  => ['reads', '3', 'y', 'AVG', '0'],
			'Reads PF'  => ['reads_pf', '3', 'y', 'AVG', '0']
		);

		my $metric_tag = 1;
		if ($analysis =~ /$NENUFAAR_ANALYSIS/) {$metric_tag = 2}
		elsif ($genome eq 'hg38') {$metric_tag = 3}
		my @colors = ('sand', 'khaki', 'yellow', 'amber', 'orange', 'deep-orange', 'red', 'pink', 'purple', 'deep-purple', 'indigo', 'blue', 'light-blue', 'cyan', 'teal', 'green', 'lime');

		foreach my $key (sort keys(%metrics)) {
			#print "$key - $metrics{$m_label}[0]</br>";
			if ($metric_tag == 2 && ($metrics{$key}[1] == 1 || $metrics{$key}[1] == 3)) {next}
			elsif ($metric_tag == 3 && $metrics{$key}[1] == 1) {next}
			else {
				$content .= $q->span({'class' => 'w3-button w3-'.(shift(@colors)).' w3-hover-light-grey w3-hover-shadow w3-padding-16 w3-margin w3-round', 'onclick' => 'show_ngs_graph(\''.$analysis.'\', \''.$key.'\', \''.$metrics{$key}[0].'\', \''.$metrics{$key}[2].'\', \''.$metrics{$key}[3].'\', \''.$metrics{$key}[4].'\');'}, $key), "\n"
			}
		}
		$content .= $q->br().$q->start_div({'style' => 'height:7px;overflow: hidden;', 'class' => 'w3-margin w3-light-blue'}).$q->end_div()."\n".
				$q->div({'id' => 'graph_place'});
	}
	print $content;
}

if ($q->param('draw_graph') && $q->param('draw_graph') == 1) {
	print $q->header();
	my $analysis;
	if ($q->param('analysis') ne 'all') {$analysis = U2_modules::U2_subs_1::check_analysis($q, $dbh, 'form')}
	else {$analysis = 'global'}
	my ($cluster, $table) = ('no_cluster', 'miseq_analysis');
	my ($pg_row, $math_type, $floating_depth, $metric_type);
	if ($q->param('pg_table') && $q->param('pg_table') eq 'y') {($cluster, $table) = ('cluster', 'illumina_run')}
	if ($q->param('pg_row') && $q->param('pg_row') =~ /([\w\(\)\+:\/\s\*-]+)/o) {$pg_row = $1}
	if ($q->param('math_type') && $q->param('math_type') =~ /(AVG|SUM)/o) {$math_type = $1}
	else {$math_type = 'AVG'}
	if ($q->param('floating_depth') && $q->param('floating_depth') =~ /(0|2)/o) {$floating_depth = $1}
	if ($q->param('metric_type') && $q->param('metric_type') =~ /([\w\s%\/]+)/o) {$metric_type = $1}
	my $percent = '';
	if ($metric_type =~ /%/) {$percent = ' %'}

	my ($labels, $full_id, $analysis_type) = U2_modules::U2_subs_3::get_labels($analysis, $dbh);
	my @tags;
	if ($analysis eq 'global' || $analysis =~ /$ANALYSIS_ILLUMINA_REGEXP/) {@tags = split(',', $full_id)}
	else {@tags = split(',', $labels)}
	### $tags+1 = number of data points
	my $width = '800'; ## default width
	if ($#tags+1 < 8) {$width = '400'}
	elsif ($#tags+1 > 100) {$width = '2400'}
	elsif ($#tags+1 > 80) {$width = '2000'}
	elsif ($#tags+1 > 50) {$width = '1600'}
	elsif ($#tags+1 > 30) {$width = '1200'}

	my $data = U2_modules::U2_subs_3::get_data($analysis, $pg_row, $q->param('math_type'), $floating_depth, $cluster, $dbh);
	my @rgb = ('151,187,205', '88,42,114', '10,5,94', '161,34,34', '220,126,0', '170,146,55', '220,188,0', '76,194,0', '38,113,88', '34,103,100');
	my $js = "
		function graph_details() {
			".U2_modules::U2_subs_2::get_js_graph($labels, $data, $rgb[int rand(10)], 'graph')."
		}
	";
    my $content =   $q->script({'type' => 'text/javascript'}, $js).
                    $q->start_div({'class' => 'w3-container w3-center w3-card', 'id' => $pg_row})."\n".$q->br().
                            $q->big($metric_type).$q->br().$q->br().$q->span("$math_type: ").
                            $q->span(U2_modules::U2_subs_3::get_data_mean($analysis, $pg_row, $floating_depth, $table, $dbh).$percent).$q->br().$q->br()."\n<canvas class=\"ambitious\" width = \"$width\" height = \"500\" id=\"graph\">Change web browser for a more recent please!</canvas>".
			$q->p('X-axis legend: date_reagent_genes with date being yymmdd.').
			$q->br().$q->br().
			$q->p({'class' => 'w3-left-align'}, 'Get stats for a particular run:').
			$q->start_ul({'class' => 'w3-left-align'}, )."\n";
	foreach (@tags) {
		my $run = $_;
		$run =~ s/"//og;
		$content .= $q->start_li().
				$q->a({'href' => "stats_ngs.pl?run=$run", 'title' => "Get stats for run $run"}, $run).
			$q->end_li()."\n";
	}
        $content .= $q->end_ul().$q->end_div()."\n";


	print $content;
}

if ($q->param('vs_table') && $q->param('vs_table') == 1) {
	print $q->header();
	my $analysis;
	if ($q->param('analysis') ne 'all') {$analysis = U2_modules::U2_subs_1::check_analysis($q, $dbh, 'form')}
	else {$analysis = 'all'}
	my $genome = U2_modules::U2_subs_1::get_genome_from_analysis($analysis, $dbh);
	my $extension = '';
	if ($genome eq 'hg38') {$extension = '_38'}
	my $round = $q->param('round');
	my $content;
	if ($round == 1) {
		#create table
		$content .= $q->start_div({'class' => 'w3-container w3-center w3-cell-row', 'id' => 'match_container',  'style' => 'width:100%'})."\n".$q->br();
	}
	my ($total_runs, $total_samples) = (U2_modules::U2_subs_3::get_total_runs($analysis, $dbh), U2_modules::U2_subs_3::get_total_samples($analysis, $dbh));
	my $query  = "SELECT AVG(fiftyx_doc) as a, AVG(duplicates) as b, AVG(insert_size_median) as c, AVG(mean_doc) as d, AVG(snp_num) as e, AVG(snp_tstv) AS f FROM miseq_analysis WHERE type_analyse = '$analysis';";
	my $query_size = "WITH tmp AS (SELECT DISTINCT(a.end_g$extension, a.start_g$extension), a.end_g$extension, a.start_g$extension FROM segment a, gene b WHERE a.refseq = b.refseq AND b.\"$analysis\" = 't' AND a.type = 'exon')\nSELECT SUM(ABS(a.end_g$extension - a.start_g$extension)+100) AS size FROM tmp a;";
	if ($analysis eq 'all') {
		$query  = "SELECT AVG(fiftyx_doc) as a, AVG(duplicates) as b, AVG(insert_size_median) as c, AVG(mean_doc) as d, AVG(snp_num) as e, AVG(snp_tstv) AS f FROM miseq_analysis;";
		$query_size = "WITH tmp AS (SELECT DISTINCT(a.end_g$extension, a.start_g$extension), a.end_g$extension, a.start_g$extension FROM segment a, gene b WHERE a.refseq = b.refseq AND a.type = 'exon')\nSELECT SUM(ABS(a.end_g$extension - a.start_g$extension)+100) AS size FROM tmp a;";
	}
	elsif ($analysis =~ /Min?i?Seq-[32]$/o) {
		$query_size = "WITH tmp AS (SELECT MIN(LEAST(b.start_g$extension, b.end_g$extension)) as min, MAX(GREATEST(b.start_g$extension, b.end_g$extension)) as max FROM gene a, segment b WHERE a.refseq = b.refseq AND type LIKE '%UTR' AND a.\"$analysis\" = 't' GROUP BY a.refseq, a.chr ORDER BY a.chr, min ASC)\nSELECT SUM(max - min) AS size FROM tmp";
	}
	my $res = $dbh->selectrow_hashref($query);

	my $res_size = $dbh->selectrow_hashref($query_size);

	$content .= $q->start_div({'class' => 'w3-hover-shadow w3-cell w3-mobile', 'id' => "match_$round"}).
			$q->start_div({'class' => 'w3-container w3-blue'}).
				$q->h3($analysis).
			$q->end_div().
			$q->start_div({'class' => 'w3-container'}).
				$q->p("Size ~ ".sprintf('%.0f', $res_size->{'size'}/1000)." kb").
				$q->p($total_runs).
				$q->p($total_samples).
				$q->p("50X %: ".sprintf('%.2f', $res->{'a'})).
				$q->p("% duplicates: ".sprintf('%.2f', $res->{'b'})).
				$q->p("Insert size (median): ".sprintf('%.0f', $res->{'c'})).
				$q->p("DoC: ".sprintf('%.2f', $res->{'d'})).
				$q->p("#SNVs: ".sprintf('%.0f', $res->{'e'})).
				$q->p("SNVs Ts/Tv: ".sprintf('%.2f', $res->{'f'})).
			$q->end_div().
		$q->end_div();

		if ($round == 1) {
		# create table
		$content .= $q->end_div()."\n".$q->br();
	}
	print $content;
}

if ($q->param('asked') && $q->param('asked') eq 'defgen_status') {
	print $q->header();
	my $variant = U2_modules::U2_subs_1::check_nom_g($q, $dbh);
	my $status;
	if ($q->param('status') && $q->param('status') =~ /^(0|1)$/o) {$status = $1}
	my ($new_status, $new_html) = ('t', 1);
	if ($status == 1) {($new_status, $new_html) = ('f', 0)}
	my $query = "UPDATE variant SET defgen_export = '$new_status' WHERE nom_g = '$variant';";
	$dbh->do($query);
	print $q->span(U2_modules::U2_subs_3::defgen_status_html($new_html, $q));
}

if ($q->param('asked') && $q->param('asked') eq 'parents') {
	print $q->header();
	my ($id, $number) = U2_modules::U2_subs_1::sample2idnum(uc($q->param('sample')), $q);
	my ($id_father, $number_father) = U2_modules::U2_subs_1::sample2idnum(uc($q->param('father')), $q);
	my ($id_mother, $number_mother) = U2_modules::U2_subs_1::sample2idnum(uc($q->param('mother')), $q);
	my $analysis = U2_modules::U2_subs_1::check_analysis($q, $dbh, 'filtering');
	if ($id_father.$number_father eq $id_mother.$number_mother) {print "Please choose different samples for mother and father.";exit;}
	# check if everybody has the same analysis
	my $query_check_analysis = "SELECT COUNT(num_pat) as a FROM miseq_analysis WHERE type_analyse = '$analysis' AND (id_pat || num_pat) IN ('$id$number','$id_father$number_father','$id_mother$number_mother');";
	my $res = $dbh->selectrow_hashref($query_check_analysis);
	if ($res->{'a'} != 3) {print 'Sorry the analyses types for the 3 samples do not match.';exit;}

	my $query = "SELECT a.nom_c, b.gene_symbol, b.refseq, a.depth FROM variant2patient a, gene b WHERE a.refseq = b.refseq AND a.type_analyse  = '$analysis' AND a.id_pat = '$id' AND a.num_pat = '$number' AND a.statut NOT IN ('homozygous', 'heteroplasmic', 'homoplasmic') AND a.allele = 'unknown';";
	my $sth = $dbh->prepare($query);
	$res = $sth->execute();
	my ($i, $j, $k, $l, $m) = (0, 0, 0, 0, 0);# counter for changing alleles
	my $denovo = '';
	my $content;
	while (my $result = $sth->fetchrow_hashref()) {
		if ($result->{'depth'} > 30) {# if bad coverage in CI, possibly also in parents and error prone
			$l++;
			my $query_assign = "SELECT allele, statut, id_pat, num_pat FROM variant2patient WHERE nom_c = '$result->{'nom_c'}' AND refseq = '$result->{'refseq'}' AND (id_pat || num_pat) IN ('$id_father$number_father', '$id_mother$number_mother') AND  type_analyse  = '$analysis';";
			my $sth_assign = $dbh->prepare($query_assign);
			my $res_assign = $sth_assign->execute();
			if ($res_assign ne '0E0') {
				my $allele = 2;# default mother
				if ($res_assign == 2) {# fat & mot
					# next if both het/hom, if one het one hom => assign to hom
					my ($fat_allele, $mom_allele);
					while (my $result_assign = $sth_assign->fetchrow_hashref()) {
						if ($result_assign->{'id_pat'}.$result_assign->{'num_pat'} eq $id_father.$number_father) {$fat_allele = $result_assign->{'statut'}}
						elsif ($result_assign->{'id_pat'}.$result_assign->{'num_pat'} eq $id_mother.$number_mother) {$mom_allele = $result_assign->{'statut'}}
					}
					if ($fat_allele eq 'heterozygous' && $mom_allele eq 'homozygous') {$allele = 2;}
					elsif ($fat_allele eq 'homozygous' && $mom_allele eq 'heterozygous') {$allele = 1;$j++;}
					else {$m++;next}
				}
				else {
					while (my $result_assign = $sth_assign->fetchrow_hashref()) {
						if ($result_assign->{'id_pat'}.$result_assign->{'num_pat'} eq $id_father.$number_father) {
							# father
							$allele = 1;
							$j++;
						}
					}
				}
				my $update = "UPDATE variant2patient SET allele = '$allele' WHERE id_pat = '$id' AND num_pat = '$number' AND refseq = '$result->{'refseq'}' AND nom_c = '$result->{'nom_c'}';";
				$dbh->do($update);
				$i++;
			}
			else {
				# not in mother nor in father
				# denovo?
				# remove neutral from list
				$k++;
				my $query_class = "SELECT classe FROM variant WHERE refseq = '$result->{'refseq'}}' AND nom = '$result->{'nom_c'}';";
				my $res_classe = $dbh->selectrow_hashref($query_class);
				if ($res_classe->{'classe'} eq 'neutral' || $res_classe->{'classe'} eq 'R8' || $res_classe->{'classe'} eq 'VUCS Class F' || $res_classe->{'classe'} eq 'VUCS Class U' || $res_classe->{'classe'} eq 'artefact') {next}
				$denovo .= $result->{'gene_symbol'}." - ".$result->{'refseq'}." - ".$result->{'nom_c'}." - ".$res_classe->{'classe'}.$q->br();
			}
		}
	}
	my $percent_unassigned = sprintf('%.2f', ($k/$l)*100);
	my $warning = '';
	$content .= "$l non homozygous variants considered (DoC > 30X):".$q->br()."Of which $m could not be assigned due to het/het or hom/hom in parents.".$q->br();
	my $threshold = 7.83;
	if ($percent_unassigned > $threshold) {$warning = " - Beware this percentage is suspect (>$threshold)"}
	if ($denovo ne '') {$content .= "Potential de novo variants:".$q->br().$denovo}
	$content .= "$i variants assigned to mother (".($i-$j).") or father ($j).".$q->br()."$k could not be assigned because they were absent in father and mother (".$q->strong($percent_unassigned."% of assigned variants".$warning).").";
	my $trio_update = "UPDATE patient SET trio_assigned = 'true' WHERE identifiant = '$id' AND numero = '$number';";
	$dbh->do($trio_update);
	print $content;

}

if ($q->param('asked') && $q->param('asked') eq 'covreport') {
	print $q->header();
	my ($id, $number) = U2_modules::U2_subs_1::sample2idnum(uc($q->param('sample')), $q);
	my $analysis = U2_modules::U2_subs_1::check_analysis($q, $dbh, 'filtering');
	my $filter = U2_modules::U2_subs_1::check_filter($q);
	my $user = U2_modules::U2_users_1->new();
	my $experiment_tag = '';
	if ($analysis =~ /-149$/o) {$experiment_tag = '_149'}
	if ($analysis =~ /-157$/o || $analysis =~ /-157-Twist$/o) {$experiment_tag = '_157'}
	# if ($q->param ('align_file') =~ /\/var\/www\/html\/ushvam2\/RS_data\/data\//o) {
	# print STDERR $q->param ('align_file')."\n";
	if ($q->param ('align_file') =~ /\/var\/www\/html\/ushvam2\/chu-ngs\//o) {
		my $align_file = $q->param('align_file');
		my $cov_report_dir = $ABSOLUTE_HTDOCS_PATH.'CovReport/';
		my $cov_report_sh = $cov_report_dir.'covreport.sh';
		print STDERR "cd $cov_report_dir && /bin/sh $cov_report_sh -out $id$number-$analysis-$filter -bam $align_file -bed u2_beds/$analysis.bed -NM u2_genes/$filter$experiment_tag.txt -f $filter\n";
		`cd $cov_report_dir && /bin/sh $cov_report_sh -out $id$number-$analysis-$filter -bam $align_file -bed u2_beds/$analysis.bed -NM u2_genes/$filter$experiment_tag.txt -f $filter`;

		if (-e $ABSOLUTE_HTDOCS_PATH."CovReport/CovReport/pdf-results/".$id.$number."-".$analysis."-".$filter."_coverage.pdf") {
			# /var/www/html/ushvam2/chu-ngs/Labos/IURC/ushvam2/covreport
			print $q->start_span().$q->a({ 'href' => $HTDOCS_PATH."chu-ngs/Labos/IURC/ushvam2/covreport/".$id.$number."/".$id.$number."-".$analysis."-".$filter."_coverage.pdf", 'target' => '_blank'}, 'Download CovReport').$q->end_span();
			
			U2_modules::U2_subs_2::send_general_mail($user, "CovReport ready for $id$number-$analysis-$filter", "Hi ".$user->getName().",\nYou can download the CovReport file here:\n".$HOME_IP."ushvam2/chu-ngs/Labos/IURC/ushvam2/covreport/$id$number/$id$number-$analysis-".$filter."_coverage.pdf\n");
			
			# attempt to trigger autoFS
			# open HANDLE, ">>".$ABSOLUTE_HTDOCS_PATH."chu-ngs/Labos/IURC/ushvam2/covreport/touch.txt";
			# sleep 3;
			# close HANDLE;
			mkdir($ABSOLUTE_HTDOCS_PATH."chu-ngs/Labos/IURC/ushvam2/covreport/".$id.$number);
			copy($ABSOLUTE_HTDOCS_PATH."CovReport/CovReport/pdf-results/".$id.$number."-".$analysis."-".$filter."_coverage.pdf", $ABSOLUTE_HTDOCS_PATH."chu-ngs/Labos/IURC/ushvam2/covreport/".$id.$number) or die $!;
      		unlink $ABSOLUTE_HTDOCS_PATH."CovReport/CovReport/pdf-results/".$id.$number."-".$analysis."-".$filter."_coverage.pdf";
		}
		else {
			U2_modules::U2_subs_2::send_general_mail($user, "CovReport failed for $id$number-$analysis-$filter\n\n", "Hi ".$user->getName().",\nUnfortunately, your CovReport generation failed. You can forward this message to David for debugging.\n");
      		print $q->span('Failed to generate coverage file');
		}
	}
}

if ($q->param('asked') && $q->param('asked') eq 'covreport2') {
	print $q->header();
	my ($id, $number) = U2_modules::U2_subs_1::sample2idnum(uc($q->param('sample')), $q);
	my $analysis = U2_modules::U2_subs_1::check_analysis($q, $dbh, 'filtering');
	my $filter = U2_modules::U2_subs_1::check_filter($q);
	my $user = U2_modules::U2_users_1->new();
	my $experiment_tag = '';
	if ($analysis =~ /-149$/o) {$experiment_tag = '_149'}
	if ($analysis =~ /-157$/o || $analysis =~ /-157-Twist$/o) {$experiment_tag = '_157'}
	# if ($q->param ('align_file') =~ /\/var\/www\/html\/ushvam2\/RS_data\/data\//o) {
	# print STDERR $q->param ('align_file')."\n";
	if ($q->param ('align_file') =~ /\/var\/www\/html\/ushvam2\/chu-ngs\//o) {
		my $align_file = $q->param('align_file');
		my $cov_report_dir = $ABSOLUTE_HTDOCS_PATH.$NAS_CHU_BASE_DIR.'/WDL/CovReport2/';
		my $covreport_jar = $cov_report_dir.'CovReport2.jar';
		# generate a random string for this file
		my @set = ('0' ..'9', 'A' .. 'F');
		my $str = join '' => map $set[rand @set], 1 .. 8;
		my $gene_list_file = $cov_report_dir."tmp_dir/$str.txt";
		# live define gene list
		my ($select_val, $com) = '';

		my $panel_size = 0;
		my $filter_txt = $filter;
		# how to get size: 
		if ($filter eq 'RP') {$select_val = "AND rp = 't'";$panel_size = 316;}
		elsif ($filter eq 'DFN') {$select_val = "AND dfn = 't'";$panel_size = 601;$com = '- OTOA E20-28: not covered due to pseudogene homology; TRIOBP E7: low specificity';}
		elsif ($filter eq 'USH') {$select_val = "AND usher = 't'";$panel_size = 120;}
		elsif ($filter eq 'DFN-USH') {$select_val = "AND (dfn = 't' OR usher = 't')";$panel_size = 716;$com = '- OTOA E20-28: not covered due to pseudogene homology; TRIOBP E7: low specificity';}
		elsif ($filter eq 'RP-USH') {$select_val = "AND (rp = 't' OR usher = 't')";$panel_size = 410;}
		elsif ($filter eq 'CHM') {$select_val = "AND gene_symbol = 'CHM'";$panel_size = 9;}
		elsif ($filter eq 'ALL') {$panel_size = 1014;$filter_txt = 'DFN-RP-USH';}
		my $comments = "Panel type: $filter_txt, size: $panel_size kb $com";
		my $query_size = "SELECT sum(abs((a.start_g_38-20) - (a.end_g_38+20)))/1000 as panel_size FROM segment a, gene b WHERE b.refseq = a.refseq AND a.type <> 'intron' AND \"MiniSeq-157\" = 't' AND b.main = 't' AND b.diag = 't' $select_val;";
		my $res_size = $dbh->selectrow_hashref($query_size);
		my $panel_size = $res_size->{'panel_size'};
		my $query_nm = "SELECT CONCAT(refseq, '.', acc_version) as full_refseq FROM gene WHERE \"$analysis\" = 't' AND main = 't' AND diag = 't' $select_val;";
		my $sth_nm = $dbh->prepare($query_nm);
		my $res_nm = $sth_nm->execute();
		open(F, ">".$gene_list_file) or die $!;
		while (my $result = $sth_nm->fetchrow_hashref()) {
				# create a gene list
				print F $result->{'full_refseq'}."\n";
		}
		close F;
		# define reference file to use
		my $refseq_file = $cov_report_dir.'refSeqExons/refSeqExon_'.U2_modules::U2_subs_1::get_genome_from_analysis($analysis, $dbh).'.only_NM.20.txt';
		# print STDERR "cd $cov_report_dir && /bin/java -jar $covreport_jar -i $align_file -r $refseq_file -g $gene_list_file -p $id$number-$analysis-$filter -config $cov_report_dir/covreport/CovReport2.config";
		my $output = `cd $cov_report_dir && /bin/java -jar $covreport_jar -i $align_file -r $refseq_file -g $gene_list_file -p $id$number-$analysis-$filter -config $cov_report_dir/covreport/CovReport2.config -comments "$comments"`;
		# print STDERR $output;
		if (-e $cov_report_dir."pdf-results/".$id.$number."-".$analysis."-".$filter."_coverage_".$str.".pdf") {
			# move to /var/www/html/ushvam2/chu-ngs/Labos/IURC/ushvam2/covreport
			mkdir($ABSOLUTE_HTDOCS_PATH."chu-ngs/Labos/IURC/ushvam2/covreport/".$id.$number);
			print STDERR $cov_report_dir."pdf-results/".$id.$number."-".$analysis."-".$filter."_coverage_".$str.".pdf\n";
			move($cov_report_dir."pdf-results/".$id.$number."-".$analysis."-".$filter."_coverage_".$str.".pdf", $ABSOLUTE_HTDOCS_PATH."chu-ngs/Labos/IURC/ushvam2/covreport/".$id.$number."/".$id.$number."-".$analysis."-".$filter."_coverage.pdf") or die $!;
			unlink $gene_list_file;
			print $q->start_span().$q->a({ 'href' => $HTDOCS_PATH."chu-ngs/Labos/IURC/ushvam2/covreport/".$id.$number."/".$id.$number."-".$analysis."-".$filter."_coverage.pdf", 'target' => '_blank'}, 'Download CovReport').$q->end_span();
			
			U2_modules::U2_subs_2::send_general_mail($user, "CovReport ready for $id$number-$analysis-$filter", "Hi ".$user->getName().",\nYou can download the CovReport file here:\n".$HOME_IP."ushvam2/chu-ngs/Labos/IURC/ushvam2/covreport/$id$number/$id$number-$analysis-".$filter."_coverage.pdf\n");
		}
		else {
			U2_modules::U2_subs_2::send_general_mail($user, "CovReport failed for $id$number-$analysis-$filter\n\n", "Hi ".$user->getName().",\nUnfortunately, your CovReport generation failed. You can forward this message to David for debugging. $output\n");
      		print $q->span('Failed to generate coverage file');
		}
	}
}

if ($q->param('asked') && $q->param('asked') eq 'disease') {
	print $q->header();
	my ($id, $number) = U2_modules::U2_subs_1::sample2idnum(uc($q->param('sample')), $q);
	#print $q->param('sample').$q->param('phenotype')."\n";
	my $new_disease = U2_modules::U2_subs_1::check_phenotype($q);
	#print $new_disease;
	my $update = "UPDATE patient SET pathologie = '$new_disease' WHERE identifiant = '$id' AND numero = '$number';";
	$dbh->do($update);
	print $q->span({'class' => 'pointer', 'onclick' => "window.open('patients.pl?phenotype=$new_disease', '_blank')"}, $new_disease);
}
if ($q->param('asked') && $q->param('asked') eq 'send2SEAL') {
	print $q->header();
	my ($id, $number) = U2_modules::U2_subs_1::sample2idnum(uc($q->param('sample')), $q);
	my $family_id = U2_modules::U2_subs_1::check_family_id($q);
	my $disease = U2_modules::U2_subs_1::check_phenotype($q);
	my $run_id = U2_modules::U2_subs_1::check_illumina_run_id($q);
	my $proband = U2_modules::U2_subs_1::check_proband($q);
	my $vcf_path = U2_modules::U2_subs_1::check_illumina_vcf_path($q);
	my $bed = U2_modules::U2_subs_1::check_filter($q);
	my $genome = U2_modules::U2_subs_1::check_genome($q);
	my $seal_ready = '';
	open F, "$DATABASES_PATH/seal_json_2023.token" or die $!;
	# my $bed_id = $U2_modules::U2_subs_1::SEAL_BED_IDS->{$bed};
	# new format 20221124
	# LRM vcf removed 20240918
	# while(<F>) {
	# 	if (/"samplename"/o) {s/"samplename": "",/"samplename": "$seal_id",/}
	# 	elsif (/"family"/o) {$family_field = 1}
	# 	elsif (/"bed"/o) {$bed_field = 1}
	# 	elsif (/"run"/o) {$run_field = 1}
	# 	if (/"name":/o && $family_field == 1) {s/"name": ""/"name": "$family_id"/; $family_field = 0}
	# 	elsif (/"name":/o && $run_field == 1) {s/"name": ""/"name": "$run_id"/; $run_field = 0}
	# 	elsif (/"id":/o && $bed_field == 1 && $bed_id) {s/"id": 0/"id": $bed_id/; $bed_field = 0}
	# 	elsif (/"affected":/o) {
	# 		if ($disease ne 'HEALTHY') {s/"affected": ,/"affected": true,/}
	# 		else {s/"affected": ,/"affected": false,/}
	# 	}
	# 	elsif (/"index":/o) {
	# 		if ($proband eq 'yes') {s/"index":/"index": true/}
	# 		else {s/"index":/"index": false/}
	# 	}
	# 	if (/"vcf_path":/o) {s/"vcf_path": ""/"vcf_path": "$SEAL_RS_IURC$vcf_path"/}
	# 	$seal_ready .= $_;
	# }
	# close F;
	# # print STDERR $seal_ready;
	# open G, ">".$TMP_DIR."LRM_seal_json.token" or die $!;
	# print G $seal_ready;
	# close G;
	# undef $seal_ready;
	# do the same for MobiDL
	my $mobidl_vcf_path = '';
	# print STDERR $vcf_path."\n";
	# print STDERR $run_id."\n";
	my $mobidl_date_analysis = U2_modules::U2_subs_3::get_mobidl_analysis_date($run_id);
	if ($vcf_path =~ /^(.+$run_id)\/$run_id.+/) {
		$mobidl_vcf_path = $1."/MobiDL/$mobidl_date_analysis$id$number/panelCapture/$id$number.vcf"
	}
	elsif ($vcf_path =~ /^(.+$run_id).+/) {
		$mobidl_vcf_path = $1."/MobiDL/$mobidl_date_analysis$id$number/panelCapture/$id$number.vcf"
	}
	# print STDERR $mobidl_vcf_path."\n";
	# exit 0;
	my $user_id = $genome eq 'hg38' ? 2 : 4;
	my $filter_id = $genome eq 'hg38' ? 2 : 7;
	open F, "$DATABASES_PATH/seal_json_2023.token" or die $!;
	my ($sample_field, $family_field, $run_field, $teams_field, $bed_field, $filter_field) = (0, 0, 0, 0, 0, 0);
	my $seal_id = $id.$number.'_MobiDL';
	while(<F>) {
		if (/"samplename"/o) {s/"samplename": "",/"samplename": "$seal_id",/}
		elsif (/"family"/o) {$family_field = 1}
		elsif (/"bed"/o) {$bed_field = 1}
		elsif (/"run"/o) {$run_field = 1}
		elsif (/"filter"/o) {$filter_field = 1}
		if (/"userid":/o) {s/"userid": 4,/"userid": $user_id,/;}
		if (/"id":/o && $filter_field == 1) {s/"id": 7/"id": $filter_id/; $filter_field = 0}
		if (/"name":/o && $family_field == 1) {s/"name": ""/"name": "$family_id"/; $family_field = 0}
		elsif (/"name":/o && $run_field == 1) {s/"name": ""/"name": "$run_id"/; $run_field = 0}
		elsif (/"name":/o && $bed_field == 1 && $bed) {s/"name": ""/"name": "$bed"/; $bed_field = 0}
		elsif (/"affected":/o) {
			if ($disease ne 'HEALTHY') {s/"affected": ,/"affected": true,/}
			else {s/"affected": ,/"affected": false,/}
		}
		elsif (/"index":/o) {
			if ($proband eq 'yes') {s/"index":/"index": true/}
			else {s/"index":/"index": false/}
		}
		if (/"vcf_path":/o) {s/"vcf_path": ""/"vcf_path": "$SEAL_NAS_CHU$mobidl_vcf_path"/}
		$seal_ready .= $_;
	}
	close F;
	open G, ">".$TMP_DIR."MobiDL_seal_json.token" or die $!;
	print G $seal_ready;
	close G;
	# print STDERR $seal_ready."\n";
	# exit;
	# send file to seal
	my $SEAL_IP = $config->SEAL_IP();
	my $SEAL_HG38_IP = $config->SEAL_HG38_IP();
	my $SEAL_VCF_PATH = $config->SEAL_VCF_PATH();
	my $SEAL_VCF_PATH_HG38 = $config->SEAL_VCF_PATH_HG38();
	my $vcf_path = $genome eq 'hg38' ? $SEAL_VCF_PATH_HG38 : $SEAL_VCF_PATH;
	my $ssh_ip = $genome eq 'hg38' ? $SEAL_HG38_IP : $SEAL_IP;
	# print STDERR $genome;
	# print STDERR $ssh_ip;
	my $ssh = U2_modules::U2_subs_1::seal_connexion('-', $ssh_ip, $q) or die $!;
	# $ssh->scp_put($TMP_DIR."LRM_seal_json.token", "$SEAL_VCF_PATH/".$id.$number."_LRM_json.token");
	$ssh->scp_put($TMP_DIR."MobiDL_seal_json.token", "$vcf_path/".$id.$number."_MobiDL_json.token");
	undef $ssh;
	# print STDERR $seal_ready."\n";
	# print STDERR $family_id."-".$disease."-".$run_id."-".$vcf_path."\n";
}

sub miseq_details {
	my ($miseq_analysis, $first_name, $last_name, $gene, $acc, $nom_c) = @_;
	$first_name =~ s/'/''/og;
	$last_name =~ s/'/''/og;
	my $query_ngs = "SELECT depth, frequency, msr_filter FROM variant2patient a, patient b WHERE a.num_pat = b.numero AND a.id_pat = b.identifiant AND b.first_name = '$first_name' AND b.last_name = '$last_name' AND a.refseq = '$acc' AND nom_c = '$nom_c' AND type_analyse = '$miseq_analysis';";
	my $res_ngs = $dbh->selectrow_hashref($query_ngs);
	return $q->start_li().$q->strong("$miseq_analysis values:").$q->start_ul().$q->start_li().$q->span("DOC: ").$q->strong($res_ngs->{'depth'}).$q->span(" Freq: ").$q->strong($res_ngs->{'frequency'}).$q->end_li().$q->start_li().$q->span("MSR filter: ").$q->strong($res_ngs->{'msr_filter'}).$q->end_li().$q->end_ul().$q->end_li();
}

# sub dbnsfp2html {
# 	my ($dbnsfp, $ref, $alt, $onekg, $espea, $espaa, $exac_maf, $clinvar, $caddraw, $caddphred) = @_;
# 	foreach (@{$dbnsfp}) {
# 		my @current = split(/\t/, $_);
# 		if (($current[2] eq $ref) && ($current[3] eq $alt)) {
# 			my $text = $q->start_li().
# 						$q->span({'onclick' => 'window.open(\'http://www.1000genomes.org/about\')', 'class' => 'pointer'}, '1000 genomes').
# 						$q->span(" AF (allele $alt): ".sprintf('%.4f', $current[$onekg])).
# 					$q->end_li()."\n".
# 					$q->start_li().
# 						$q->span({'onclick' => 'window.open(\'http://evs.gs.washington.edu/EVS/#tabs-6\')', 'class' => 'pointer'}, 'ESP6500').
# 						$q->span(" EA AF (allele $alt): ".sprintf('%.4f', $current[$espea])).
# 					$q->end_li()."\n".
# 					$q->start_li().
# 						$q->span({'onclick' => 'window.open(\'http://evs.gs.washington.edu/EVS/#tabs-6\')', 'class' => 'pointer'}, 'ESP6500').
# 						$q->span(" AA AF (allele $alt): ".sprintf('%.4f', $current[$espaa])).
# 					$q->end_li()."\n".
# 					$q->start_li().
# 						$q->span({'onclick' => 'window.open(\'http://exac.broadinstitute.org/\')', 'class' => 'pointer'}, 'ExAC').
# 						$q->span(" adjusted AF (allele $alt): ".sprintf('%.4f', $current[$exac_maf])).
# 					$q->end_li()."\n".
# 					$q->start_li().
# 						$q->span({'onclick' => 'window.open(\'https://www.ncbi.nlm.nih.gov/clinvar/\')', 'class' => 'pointer'}, 'ClinVar').
# 						$q->span(" (allele $alt): ".U2_modules::U2_subs_2::dbnsfp_clinvar2text($current[$clinvar])).
# 					$q->end_li()."\n".
# 					$q->start_li().
# 						$q->span({'onclick' => 'window.open(\'http://cadd.gs.washington.edu\')', 'class' => 'pointer'}, 'CADD raw:').
# 						$q->span(" (allele $alt): ".sprintf('%.4f', $current[$caddraw])).
# 					$q->end_li()."\n".
# 					$q->start_li().
# 						$q->span({'onclick' => 'window.open(\'http://cadd.gs.washington.edu\')', 'class' => 'pointer'}, 'CADD phred:').
# 						$q->span(" (allele $alt): $current[$caddphred]").
# 					$q->end_li()."\n";
# 			return $text
# 		}
# 	}
# }

sub u22defgen_status {
	my $u2_status = shift;
	if ($u2_status eq 'homozygous') {return 'Homozygote'}
	elsif ($u2_status eq 'heterozygous') {return 'H�t�rozygote'}
	elsif ($u2_status eq 'hemizygous') {return 'H�mizygote'}
	elsif ($u2_status eq 'heteroplasmic') {return 'H�t�roplasmique'}
	elsif ($u2_status eq 'heteroplasmic') {return 'Homoplasmique'}
}

sub u22defgen_acmg {
	my $u2_acmg = shift;
	if ($u2_acmg eq 'ACMG class I') {return 'Classe 1'}
	elsif ($u2_acmg eq 'ACMG class II') {return 'Classe 2'}
	elsif ($u2_acmg eq 'ACMG class III') {return 'Classe 3'}
	elsif ($u2_acmg eq 'ACMG class IV') {return 'Classe 4'}
	elsif ($u2_acmg eq 'ACMG class V') {return 'Classe 5'}
}
