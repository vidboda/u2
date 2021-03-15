BEGIN {delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV', 'PATH'};}

use strict;
#use CGI; #in startup.pl
#use DBI();
#use JSON;
#use AppConfig qw(:expand :argcount);
#use Bio::EnsEMBL::Registry;
use U2_modules::U2_init_1;
use U2_modules::U2_subs_1;
use U2_modules::U2_subs_2;
use U2_modules::U2_subs_3;
use U2_modules::U2_users_1;
use SOAP::Lite;
use File::Temp qw/ :seekable /;
use List::Util qw(min max);
#use IPC::Open2;
use Data::Dumper;
use URI::Escape;
use LWP::UserAgent;
use Net::Ping;
use URI::Encode qw/uri_encode uri_decode/;
use JSON;
use File::Copy;


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
my $DB_USER = $config->DB_USER();
my $DB_PASSWORD = $config->DB_PASSWORD();
my $HTDOCS_PATH = $config->HTDOCS_PATH();
my $ABSOLUTE_HTDOCS_PATH = $config->ABSOLUTE_HTDOCS_PATH();
my $DATABASES_PATH = $config->DATABASES_PATH();
my $DALLIANCE_DATA_DIR_PATH = $config->DALLIANCE_DATA_DIR_PATH();
my $EXE_PATH = $config->EXE_PATH();
my $ANALYSIS_ILLUMINA_REGEXP = $config->ANALYSIS_ILLUMINA_REGEXP();
my $ANALYSIS_ILLUMINA_PG_REGEXP = $config->ANALYSIS_ILLUMINA_PG_REGEXP();
my $NENUFAAR_ANALYSIS = $config->NENUFAAR_ANALYSIS();
my $DBNSFP_V2 = $config->DBNSFP_V2();
my $DBNSFP_V3_PATH = $config->DBNSFP_V3_PATH();

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
	my $query = "SELECT a.nom as name, a.numero as number FROM segment a, gene b WHERE a.nom_gene = b.nom AND a.nom_gene[1] = '$gene' AND b.main = 't' AND a.type <> 'intron' ORDER BY a.numero;";
	my $sth = $dbh->prepare($query);
	my $res = $sth->execute();
	my ($labels, @values);
	while (my $result = $sth->fetchrow_hashref()) {
		$labels->{$result->{'number'}} = $result->{'name'};
		push @values, $result->{'number'};
	}
	print $q->popup_menu(-name => 'exons', -id => 'exons', -values => \@values, -labels => $labels, -class => 'w3-select w3-border');
	#print 'ok';
}


if ($q->param('asked') && $q->param('asked') eq 'ext_data') {
	print $q->header();
	my $variant = U2_modules::U2_subs_1::check_nom_g($q, $dbh);






	####OLD STYLE 17/11/2014
	#my ($chr, $pos_start, $pos_end) = U2_modules::U2_subs_1::extract_pos_from_genomic($variant, 'evs');#evs style but for 1000 genomes!!
	#
	#my $reg = 'Bio::EnsEMBL::Registry';
	##print "$chr, $pos_start, $pos_end, $variant";exit;
	#my ($semaph, $unfound) = (0, 0);
	#$reg->load_registry_from_db(
	#    -host => 'ensembldb.ensembl.org',
	#    -user => 'anonymous'
	#) or do {print "pb connecting to 1000 genomes $!"; exit;};
	##$reg->set_reconnect_when_lost();
	#
	#my $sa = $reg->get_adaptor("human", "core", "slice") or do {print "Error: can't get adaptator 1...";$semaph = 2;};
	#my $vfa = $reg->get_adaptor("human", "variation", "variationfeature") or do {print "Error: can't get adaptator 2...";$semaph = 2;};
	#
	#my $slice = $sa->fetch_by_region('chromosome', $chr, $pos_start, $pos_end) or do {print "Error: can't get slice...";$semaph = 2;};
	#
	#my @vfs = @{$vfa->fetch_all_by_Slice($slice)} or do {print "No 1000 genomes variant at this position.";$semaph = 2;};
	#
	#THOUSANDG: foreach my $vf(@vfs){
	#	my $hgvs = $vf->get_all_hgvs_notations($slice, 'g');
	#	foreach my $key (keys (%{$hgvs})) {
	#		#print $key."-".$hgvs->{$key}."\n";
	#		#print "$hgvs->{$key} - $variant";
	#		my $thoug_var = "chr".$hgvs->{$key};
	#		if ($thoug_var =~ /$variant/ && $vf->minor_allele_frequency() ne '') {$semaph = 1;print "1000 genomes MAF: ".sprintf('%.4f', $vf->minor_allele_frequency());$unfound = 0;last THOUSANDG;}
	#		elsif ($thoug_var =~ /$variant/) {$semaph = 1;$unfound = 1;}
	#	}
	#}
	#if ($unfound == 1) {print 'reported in 1000 genomes but no MAF'}
	#elsif ($semaph == 0) {print 'no MAF in 1000 genomes'}
	####END OLD STYLE 17/11/2014






	my $query = "SELECT a.nom, a.nom_gene[1] as gene, a.nom_gene[2] as acc, a.nom_g_38, a.snp_id, a.type_adn, a.type_segment, b.dfn, b.usher, b.ns_gene FROM variant a, gene b WHERE a.nom_gene = b.nom AND a.nom_g = '$variant';";
	my $res = $dbh->selectrow_hashref($query);
	my ($text, $semaph) = ('', 0);#$q->strong('MAFs &amp; databases:').



	if ($res->{'snp_id'} ne '') {
		# my $test_ncbi = U2_modules::U2_subs_1::test_ncbi();
		$text .= $q->start_Tr() . $q->td('Pubmed related articles:') . $q->start_td() . $q->start_div({'class' => 'w3-container'});
		# if ($test_ncbi == 1) {
		my $pubmedids = U2_modules::U2_subs_1::run_litvar($res->{'snp_id'});
		# print STDERR ref($pubmedids);
		if (ref($pubmedids) ne 'ARRAY' && exists $pubmedids->{'message'} && $pubmedids->{'message'} =~ /LitVar Error/) {$text .= $q->span("Error while querying litvar: $pubmedids->{'message'}")}
		elsif ($pubmedids->[0] eq '') {
			$text .= $q->span('No PubMed ID retrieved');
		}
		else {
			#$text .= $pubmedids->[0]{'pmids'}[0];
			$text .= $q->button({'class' => 'w3-button w3-ripple w3-blue w3-border w3-border-blue', 'value' => 'show Pubmed IDs', 'onclick' => '$("#pubmed").show();'}) .
			$q->start_div({'class' => 'w3-modal', 'id' => 'pubmed'}) . "\n" .
				$q->start_div({'class' => 'w3-modal-content w3-display-middle', 'style' => 'z-index:1500'}) . "\n" .
					"<header class = 'w3-container w3-teal'>" . "\n" .
						$q->span({'onclick' => '$("#pubmed").hide();', 'class' => 'w3-button w3-display-topright w3-large'}, '&times') . "\n" .
						$q->h2('PubMed IDs of articles citing this variant:') . "\n" .
					'</header>' . "\n" .
					$q->start_div({'class' => 'w3-container'}) . "\n" .
						$q->start_ul() . "\n";
			my $pubmed_url = 'https://www.ncbi.nlm.nih.gov/pubmed/';
			if ($user->isLocalUser() == 1) {$pubmed_url = 'https://www.ncbi.nlm.nih.gov/pubmed/';}
			foreach my $pmid (@{$pubmedids->[0]{'pmids'}}) {
				$text .= $q->start_li() . $q->a({'href' => $pubmed_url.$pmid, 'target' => '_blank'}, $pmid) . $q->end_li() . "\n"
				#$text .= $q->start_li() . $q->a({'href' => $pubmed_url.$pmid->{'pmid'}, 'target' => '_blank'}, $pmid->{'pmid'}) . $q->end_li() . "\n"
				#print $pmid->{'pmid'}
			}
			$text .= $q->end_ul() . "\n" . $q->br() . $q->br() .
					$q->end_div() . "\n" .
				$q->end_div() . "\n" .
			$q->end_div() . "\n";
		}
		#}
		# else {$text .= $q->span('Litvar service unavailable')}
		$text .= $q->end_div() . $q->end_td() . $q->start_td() . $q->span('Pubmed text mining using ') . $q->a({'href' => 'https://www.ncbi.nlm.nih.gov/CBBresearch/Lu/Demo/LitVar/index.html', 'target' => '_blank'}, 'LitVar') . $q->end_Tr() . "\n";
	}

	my $chr = my $position = my $ref = my $alt = '';
	$text .= $q->start_Tr() . $q->td('MAFs & databases:') . $q->start_td() . $q->start_ul() . "\n";


	#if ($variant =~ /chr([\dXYM]+):g\.(\d+)([ATGC])>([ATGC])/o) {
	if ($variant =~ /chr($U2_modules::U2_subs_1::CHR_REGEXP):$U2_modules::U2_subs_1::HGVS_CHR_TAG\.(\d+)([ATGC])>([ATGC])/o) {
		####NEW NEW STYLE with dbNSFP 04/2018 for substitutions
		#print $tempfile "$1 $2 $2 $3/$4 +\n";
		$chr = $1; $position = $2; $ref = $3; $alt = $4;
		$chr =~ s/chr//og;
		if ($res->{'nom_g_38'} ne '') {
			#$res->{'nom_g_38'} =~ /chr([\dXYM]+):g\.(\d+)([ATGC])>([ATGC])/o;
			$res->{'nom_g_38'} =~ /chr($U2_modules::U2_subs_1::CHR_REGEXP):$U2_modules::U2_subs_1::HGVS_CHR_TAG\.(\d+)([ATGC])>([ATGC])/o;
			my $chr38 = $1; my $position38 = $2; my $ref38 = $3; my $alt38 = $4;
			#my $chrfull = $chr;
			$chr38 =~ s/chr//og;
			#print "$EXE_PATH/tabix $DATABASES_PATH$DBNSFP_V3_PATH/dbNSFP3.5a_variant.chr$chr.gz $chr:$position-$position";
			my @dbnsfp =  split(/\n/, `$EXE_PATH/tabix $DATABASES_PATH$DBNSFP_V3_PATH/dbNSFP3.5a_variant.chr$chr38.gz $chr38:$position38-$position38`);
			$text .=  &dbnsfp2html(\@dbnsfp, $ref38, $alt38, 120, 138, 136, 142, 239, 76, 78);#1kg, ESPEA, ESPAA, ExAC, clinvar, CADD raw, CADD phred
			if ($#dbnsfp > -1) {$semaph = 1}
		}
		if ($semaph == 0) {
			my @dbnsfp =  split(/\n/, `$EXE_PATH/tabix $DATABASES_PATH$DBNSFP_V2 $chr:$position-$position`);
			$text .=  &dbnsfp2html(\@dbnsfp, $ref, $alt, 83, 93, 92, 101, 115, 59, 61);
			if ($#dbnsfp > -1) {$semaph = 1}

		}
		#Intervar new API 06/2019
		#http://wintervar.wglab.org/api_new.php?queryType=position&build=hg19_updated.v.201904&chr=1&pos=115828756&ref=G&alt=A
		if ($res->{'type_segment'} eq 'exon' && $res->{'nom_g_38'} !~ /chrM.+./o) {
			my $ua = new LWP::UserAgent();
			$ua->timeout(3);
			my $response = $ua->get("http://wintervar.wglab.org/api_new.php?queryType=position&build=hg19_updated.v.201904&chr=$chr&pos=$position&ref=$ref&alt=$alt");
			if ($response->is_success()) {
				my $intervar_result = decode_json($response->decoded_content());
				$text .= $q->li("Intervar: $intervar_result->{'Intervar'}");
			}
			#else {$text .= $q->li($response->status_line())}
		}
		elsif ($res->{'type_segment'} =~ /UTR/o) {
			my $uORF_file = 'stop-removing_all_possible_annotated_sorted.txt.gz';
			if ($res->{'type_segment'} eq '5UTR') {$uORF_file = 'uAUG-creating_all_possible_annotated_sorted.txt.gz'}
			my @uorf = split(/\n/, `$EXE_PATH/tabix $DATABASES_PATH$uORF_file $chr:$position-$position`);
			foreach (@uorf) {
				my @current = split(/\t/, $_);
				if (($current[2] eq $ref) && ($current[3] eq $alt)) {
					$text .= $q->start_li().
							$q->span({'onclick' => 'window.open(\'http://www.1000genomes.org/about\')', 'class' => 'pointer'}, '1000 genomes').
							$q->span(" AF (allele $alt):  $current[7]").
						$q->end_li()."\n";
				}
			}
		}
	}
	my $gnomad = 0;
	if ($variant =~ /chr(.+)$/o && $semaph == 0) {
		###NEW style using VEP 4 TGP and ESP
		#####removed 01/10/2018 replaced wit myvariant.info
		######my $tempfile = File::Temp->new(UNLINK => 1);
		#####my $network = 'offline';
		#####print $tempfile "$1\n";$network = 'port 3337';
		#####if ($tempfile->filename() =~ /(\/tmp\/\w+)/o) {
		#####	delete $ENV{PATH};
			#my @results = split('\n', `$DATABASES_PATH/variant_effect_predictor/variant_effect_predictor.pl --fasta $DATABASES_PATH/.vep/homo_sapiens/75/Homo_sapiens.GRCh37.75.dna.primary_assembly.fa --cache --compress "gunzip -c" --gmaf --maf_esp --refseq --no_progress -q --fork 4 --no_stats --dir $DATABASES_PATH/.vep/ --force -i $1 -o STDOUT`); ###VEP75

		if (U2_modules::U2_subs_1::test_myvariant() == 1) {
			#use myvariant.info REST API  http://myvariant.info/
			#my $myvarinput = $variant;
			#if ($myvarinput =~ /($chr.+[delup]{3})(.+)$/o) {$myvarinput = $1}
			my $myvariant = U2_modules::U2_subs_1::run_myvariant($variant, 'all', $user->getEmail());

			#$text .= ref($myvariant->{'gnomad_exome'}->{'af'}).$myvariant->{'gnomad_exome'}->{'af'}->{'af'};
			# print STDERR Dumper($myvariant);

			if (ref($myvariant) && ref($myvariant->{'gnomad_exome'}->{'af'}) eq 'HASH' && $myvariant->{'gnomad_exome'}->{'af'}->{'af'} ne '') {
				$text .= $q->start_li() . $q->span({'onclick' => 'window.open(\'http://gnomad.broadinstitute.org/\')', 'class' => 'pointer'}, 'gnomAD exome') . $q->span(" AF: ".$myvariant->{'gnomad_exome'}->{'af'}->{'af'}) . $q->end_li();
				($semaph, $gnomad) = (1, 1);
			}
			#,gnomad_genome.af.af,cadd.esp.af,dbnsfp.1000gp3.af,clinvar.rcv.accession,cadd.rawscore
			#$myvariant = U2_modules::U2_subs_1::run_myvariant($variant, 'gnomad_genome.af.af', $user->getEmail());
			if (ref($myvariant) && ref($myvariant->{'gnomad_genome'}->{'af'}) eq 'HASH' && $myvariant->{'gnomad_genome'}->{'af'}->{'af'} ne '') {
				$text .= $q->start_li() . $q->span({'onclick' => 'window.open(\'http://gnomad.broadinstitute.org/\')', 'class' => 'pointer'}, 'gnomAD genome') . $q->span(" AF: ".$myvariant->{'gnomad_genome'}->{'af'}->{'af'}) . $q->end_li();
				($semaph, $gnomad) = (1, 1);
			}
			#$myvariant = U2_modules::U2_subs_1::run_myvariant($variant, 'dbnsfp.1000gp3.af', $user->getEmail());
			if (ref($myvariant) && ref($myvariant->{'dbnsfp'}->{'1000gp3'}) eq 'HASH' && $myvariant->{'dbnsfp'}->{'1000gp3'}->{'af'} ne '') {
				$text .= $q->start_li() . $q->span({'onclick' => 'window.open(\'http://www.1000genomes.org/about\')', 'class' => 'pointer'}, '1K genome') . $q->span(" AF: ".$myvariant->{'dbnsfp'}->{'1000gp3'}->{'af'}) . $q->end_li();
				$semaph = 1;
			}
			#$myvariant = U2_modules::U2_subs_1::run_myvariant($variant, 'cadd.esp.af', $user->getEmail());
			if (ref($myvariant) && ref($myvariant->{'cadd'}->{'esp'}) eq 'HASH' && $myvariant->{'cadd'}->{'esp'}->{'af'} ne '') {
				$text .= $q->start_li() . $q->span({'onclick' => 'window.open(\'http://evs.gs.washington.edu/EVS/#tabs-6\')', 'class' => 'pointer'}, 'ESP') . $q->span(" AF: ".$myvariant->{'cadd'}->{'esp'}->{'af'}) . $q->end_li();
				$semaph = 1;
			}
			#$myvariant = U2_modules::U2_subs_1::run_myvariant($variant, 'cadd.rawscore', $user->getEmail());
			if (ref($myvariant) && ref($myvariant->{'cadd'}) eq 'HASH' && $myvariant->{'cadd'}->{'rawscore'} ne '') {
				$text .= $q->start_li() . $q->span({'onclick' => 'window.open(\'http://cadd.gs.washington.edu/\')', 'class' => 'pointer'}, 'CADD') . $q->span(" raw: ".$myvariant->{'cadd'}->{'rawscore'}) . $q->end_li();
			}
			#$myvariant = U2_modules::U2_subs_1::run_myvariant($variant, 'clinvar.rcv.accession', $user->getEmail());->{'rcv'}->{'accession'}
			if (ref($myvariant) && ref($myvariant->{'clinvar'}->{'rcv'}) eq 'HASH' && $myvariant->{'clinvar'}->{'rcv'}->{'accession'} ne '') {
				#print $myvariant->{'clinvar'}->{'rcv'};
				$text .= $q->start_li() . $q->span({'onclick' => 'window.open(\'http://www.ncbi.nlm.nih.gov/clinvar?term='.$myvariant->{'clinvar'}->{'rcv'}->{'accession'}.'\')', 'class' => 'pointer'}, 'Clinvar ') . $q->span(": ".$myvariant->{'clinvar'}->{'rcv'}->{'clinical_significance'}) . $q->end_li();
			}
			elsif (ref($myvariant) && ref($myvariant->{'clinvar'}->{'rcv'}) eq 'ARRAY' && $myvariant->{'clinvar'}->{'rcv'}->[0]->{'accession'} ne '') {
				#print $myvariant->{'clinvar'}->{'rcv'};
				$text .= $q->start_li() . $q->span({'onclick' => 'window.open(\'http://www.ncbi.nlm.nih.gov/clinvar?term='.$myvariant->{'clinvar'}->{'rcv'}->[0]->{'accession'}.'\')', 'class' => 'pointer'}, 'Clinvar ') . $q->span(": ".$myvariant->{'clinvar'}->{'rcv'}->[0]->{'clinical_significance'}) . $q->end_li();
			}
		}


			#####removed 01/10/2018 replaced wit myvariant.info
			#####my @results = split('\n', `$DATABASES_PATH/variant_effect_predictor_81/variant_effect_predictor.pl --fasta $DATABASES_PATH/.vep/homo_sapiens/75/Homo_sapiens.GRCh37.75.dna.primary_assembly.fa --$network --cache --compress "gunzip -c" --gmaf --maf_esp --refseq --no_progress -q --fork 4 --no_stats --dir $DATABASES_PATH/.vep/ --force -i $1 --plugin ExAC,$DALLIANCE_DATA_DIR_PATH/exac/ExAC.r0.3.sites.vep.vcf.gz --plugin CADD,$DATABASES_PATH/CADD/whole_genome_SNVs.tsv.gz,$DATABASES_PATH/CADD/InDels.tsv.gz  -o STDOUT`); ###VEP81;
			#for unknwon reasons VEP78 does not work anymore with indels (error) and VEP 81 with substitutions (does not retrieve gmaf esp_maf) - FINALLY works with assembly v75

			#if ($version == 78) {
			#	@results = split('\n', `$DATABASES_PATH/variant_effect_predictor_78/variant_effect_predictor.pl --fasta $DATABASES_PATH/.vep/homo_sapiens/75/Homo_sapiens.GRCh37.75.dna.primary_assembly.fa --$network --cache --compress "gunzip -c" --gmaf --maf_esp --refseq --no_progress -q --fork 4 --no_stats --dir $DATABASES_PATH/.vep/ --force -i $1 --plugin ExAC,$DALLIANCE_DATA_DIR_PATH/exac/ExAC.r0.3.sites.vep.vcf.gz -o STDOUT`); ###VEP78
			#}
			#else {
			#	@results = split('\n', `$DATABASES_PATH/variant_effect_predictor_81/variant_effect_predictor.pl --fasta $DATABASES_PATH/.vep/homo_sapiens/75/Homo_sapiens.GRCh37.75.dna.primary_assembly.fa --$network --cache --compress "gunzip -c" --gmaf --maf_esp --refseq --no_progress -q --fork 4 --no_stats --dir $DATABASES_PATH/.vep/ --force -i $1 --plugin ExAC,$DALLIANCE_DATA_DIR_PATH/exac/ExAC.r0.3.sites.vep.vcf.gz -o STDOUT`); ###VEP81
			#
			#}

			#####if ($res->{'acc'} =~ /(N[MR]_\d+)/o) {
			#####	my @good_line = grep(/$1/, @results);
			#####	my $not_good_alt = 0;
			#####	#print "--$alt--";
			#####	if ($good_line[0] =~ /GMAF=([ATCG-]+):([\d\.]+);*/o) {
			#####		my ($nuc, $score) = ($1, $2);
			#####		#print $q->li("$nuc $ref $alt");
			#####		#if (($ref ne '' && (($nuc =~ /[ATGC]/o && $nuc eq $alt) || ($nuc =~ /[ATGC]/o && $nuc eq $ref))) || ($nuc !~ /[ATGC]/o)) {
			#####		#if (($ref ne '' && ($nuc =~ /[ATGC]/o  && ($nuc eq $alt || $nuc eq $ref))) || ($nuc !~ /[ATGC]/o)) {
			#####		if (($network eq 'offline' && ($nuc eq $alt || $nuc eq $ref)) || ($network eq 'port 3337')) {
			#####			$text .= $q->start_li().$q->span({'onclick' => 'window.open(\'http://www.1000genomes.org/about\')', 'class' => 'pointer'}, '1000 genomes').$q->span(" phase 1 AF (allele $nuc): $score").$q->end_li();$semaph = 1;
			#####		}
			#####		else {$not_good_alt = 1}
			#####	}
			#####	if ($good_line[0] =~ /EA_MAF=([ATCG-]+):([\d\.]+);*/o) {
			#####		my ($nuc, $score) = ($1, $2);
			#####		#if (($ref ne '' && (($nuc =~ /[ATGC]/o && $nuc eq $alt) || ($nuc =~ /[ATGC]/o && $nuc eq $ref))) || ($nuc !~ /[ATGC]/o)) {
			#####		if (($network eq 'offline' && ($nuc eq $alt || $nuc eq $ref)) || ($network eq 'port 3337')) {
			#####			$text .= $q->start_li().$q->span({'onclick' => 'window.open(\'http://evs.gs.washington.edu/EVS/#tabs-6\')', 'class' => 'pointer'}, 'ESP6500').$q->span("  EA AF (allele $nuc): ".sprintf('%.4f', $score)).$q->end_li();$semaph = 1;
			#####		}
			#####		else {$not_good_alt = 1}
			#####	}
			#####	if ($good_line[0] =~ /AA_MAF=([ATCG-]+):([\d\.]+);*/o) {
			#####		my ($nuc, $score) = ($1, $2);
			#####		#if (($ref ne '' && (($nuc =~ /[ATGC]/o && $nuc eq $alt) || ($nuc =~ /[ATGC]/o && $nuc eq $ref))) || ($nuc !~ /[ATGC]/o)) {
			#####		if (($network eq 'offline' && ($nuc eq $alt || $nuc eq $ref)) || ($network eq 'port 3337')) {
			#####			$text .= $q->start_li().$q->span({'onclick' => 'window.open(\'http://evs.gs.washington.edu/EVS/#tabs-6\')', 'class' => 'pointer'}, 'ESP6500').$q->span("  AA AF (allele $nuc): ".sprintf('%.4f', $score)).$q->end_li();$semaph = 1;
			#####		}
			#####		else {$not_good_alt = 1}
			#####	}
			#####	if ($good_line[0] =~ /ExAC_AF=([\d\.e-]+);*/o) {if ($not_good_alt == 0) {$text .= $q->start_li().$q->span({'onclick' => 'window.open(\'http://exac.broadinstitute.org/\')', 'class' => 'pointer'}, 'ExAC').$q->span(" AF: $1").$q->end_li();$semaph = 1;}}
			#####	if ($good_line[0] =~ /CLIN_SIG=(\w+)/o) {if ($not_good_alt == 0) {$text .= $q->start_li().$q->span({'onclick' => 'window.open(\'http://www.ncbi.nlm.nih.gov/SNP/\')', 'class' => 'pointer'}, 'Clinical significance (dbSNP): ').$q->span($1).$q->end_li();}}
			#####	if ($good_line[0] =~ /CADD_RAW=([\d\.]+)/o) {if ($not_good_alt == 0) {$text .= $q->start_li().$q->span({'onclick' => 'window.open(\'http://cadd.gs.washington.edu/\')', 'class' => 'pointer'}, 'CADD raw: ').$q->span($1).$q->end_li();}}
			#####	if ($good_line[0] =~ /CADD_PHRED=(\d+)/o) {if ($not_good_alt == 0) {$text .= $q->start_li().$q->span({'onclick' => 'window.open(\'http://cadd.gs.washington.edu/\')', 'class' => 'pointer'}, 'CADD PHRED: ').$q->span($1).$q->end_li();}}
			######print $q->li($good_line[0]);
			#####}
			#####else {$text .= $q->li("$res->{'acc'} not matching.");$semaph = 1;}
			#MCAP results for missense
			#if ($variant =~ /chr([\dXYM]+):g\.(\d+)([ATGC])>([ATGC])/o) {
			#	my ($chr, $pos, $ref, $alt) = ($1, $2, $3, $4);
			#	my @mcap =  split(/\n/, `$EXE_PATH/tabix $DATABASES_PATH/mcap/mcap_v1_0.txt.gz $chr:$pos-$pos`);
			#	foreach (@mcap) {
			#		my @current = split(/\t/, $_);
			#		if (/\t$ref\t$alt\t/) {
			#			$text .= $q->start_li().$q->span({'onclick' => 'window.open(\'http://bejerano.stanford.edu/mcap/\')', 'class' => 'pointer'}, 'M-CAP score: '.sprintf('%.4f', $current[4])).$q->end_li(), "\n";
			#		}
			#	}
			#}
			#####if ($#results == -1) {
			#####	print "There may be an issue with port 3337 of Ensembl server mandatory for indel analysis. Please retry later.";
			#####	$semaph = 1;
			#####}
			#print $#results;
			#foreach(@results) {print "$_<br/>"}
		#####}
	}
	elsif ($variant =~ /chr(.+)$/o && $text =~ /not seen in Clinvar/o) { #clinvar empty in dbNSFP - check myvariant
		my $myvariant = U2_modules::U2_subs_1::run_myvariant($variant, 'clinvar.rcv.accession,clinvar.rcv.clinical_significance', $user->getEmail());


		if (ref($myvariant) && ref($myvariant->{'clinvar'}->{'rcv'}) eq 'HASH' && $myvariant->{'clinvar'}->{'rcv'}->{'accession'} ne '') {
			#print $myvariant->{'clinvar'}->{'rcv'};
			$text .= $q->start_li() . $q->span({'onclick' => 'window.open(\'http://www.ncbi.nlm.nih.gov/clinvar?term='.$myvariant->{'clinvar'}->{'rcv'}->{'accession'}.'\')', 'class' => 'pointer'}, 'Clinvar ') . $q->span(": ".$myvariant->{'clinvar'}->{'rcv'}->{'clinical_significance'}) . $q->end_li();
			$text =~ s/<li><span class="pointer" onclick="window.open\('https:\/\/www\.ncbi\.nlm\.nih\.gov\/clinvar\/'\)">ClinVar<\/span><span>.+not seen in Clinvar<\/span><\/li>//o;
			#$text =~ s/<li><span class="pointer"  onclick="window.open\('https:\/\/www\.ncbi\.nlm\.nih\.gov\/clinvar\/'\)">ClinVar<\/span><span>.+not seen in Clinvar<\/span><\/li>//o;
		}
		elsif (ref($myvariant) && ref($myvariant->{'clinvar'}->{'rcv'}) eq 'ARRAY' && $myvariant->{'clinvar'}->{'rcv'}->[0]->{'accession'} ne '') {
			#print $myvariant->{'clinvar'}->{'rcv'};
			$text .= $q->start_li() . $q->span({'onclick' => 'window.open(\'http://www.ncbi.nlm.nih.gov/clinvar?term='.$myvariant->{'clinvar'}->{'rcv'}->[0]->{'accession'}.'\')', 'class' => 'pointer'}, 'Clinvar ') . $q->span(": ".$myvariant->{'clinvar'}->{'rcv'}->[0]->{'clinical_significance'}) . $q->end_li();
			$text =~ s/<li><span class="pointer" onclick="window.open\('https:\/\/www\.ncbi\.nlm\.nih\.gov\/clinvar\/'\)">ClinVar<\/span><span>.+not seen in Clinvar<\/span><\/li>//o;
		}
	}
	#else {print "pb with variant $variant with VEP"}
	#my ($chr, $pos1, $wt, $mt) = ($1, $2, $3, $4);
	#print $tempfile "$chr $pos1 $pos1 $wt/$mt +\n";
	#print $tempfile "$1 $2 $2 $3/$4 +\n";
	#$variant =~ /chr(.+)$/o;
	#print $tempfile "$1\n";

	#get gnomAD via tabix
	#if ($chr ne '') {
	#	$chr =~ s/chr//og;
	#	my @gnomad =  split(/\n/, `$EXE_PATH/tabix $DALLIANCE_DATA_DIR_PATH/gnomad/gnomad.exomes.r2.0.1.sites.vcf.gz $chr:$position-$position`);
	#	foreach (@gnomad) {
	#		my @current = split(/\t/, $_);
	#		if (/\t$ref\t$alt\t/) {
	#			$current[7] =~ /;AF=([\d\.e-]+);AN/og;
	#			my $af = $1;
	#			$text .= $q->start_li().$q->span({'onclick' => 'window.open(\'http://gnomad.broadinstitute.org/\')', 'class' => 'pointer'}, 'gnomAD').$q->span(" AF: $af").$q->span().$q->end_li()."\n";
	#		}
	#	}
	#}
	#get gnomAD via tabix v2 using annovar database (lighter)
	#TO DO: small sub for gnomad treatment DONE
	if ($chr ne '' && $gnomad == 0) {
		$chr =~ s/chr//og;
		my $text_size = length($text);
		$text .= U2_modules::U2_subs_2::gnomadAF("$EXE_PATH/tabix", "$DATABASES_PATH/gnomad/hg19_gnomad_exome_sorted.txt.gz", 'exome', $chr, $position, $ref, $alt, $q);
		$text .= U2_modules::U2_subs_2::gnomadAF("$EXE_PATH/tabix", "$DATABASES_PATH/gnomad/hg19_gnomad_genome_sorted.txt.gz", 'genome', $chr, $position, $ref, $alt, $q);
		if (length($text) > $text_size) {$semaph = 1}
		#my @gnomad =  split(/\n/, `$EXE_PATH/tabix $DATABASES_PATH/gnomad/hg19_gnomad_exome_sorted.txt.gz $chr:$position-$position`);
		#foreach (@gnomad) {
		#	my @current = split(/\t/, $_);
		#	if (/\t$ref\t$alt\t/) {
		#		#my $af = $current[5];
		#		$text .= $q->start_li().$q->span({'onclick' => 'window.open(\'http://gnomad.broadinstitute.org/\')', 'class' => 'pointer'}, 'gnomAD Exome').$q->span(" AF: $current[5]").$q->span().$q->end_li()."\n";
		#	}
		#}
		#@gnomad =  split(/\n/, `$EXE_PATH/tabix $DATABASES_PATH/gnomad/hg19_gnomad_genome_sorted.txt.gz $chr:$position-$position`);
		#foreach (@gnomad) {
		#	my @current = split(/\t/, $_);
		#	if (/\t$ref\t$alt\t/) {
		#		#my $af = $current[5];
		#		$text .= $q->start_li().$q->span({'onclick' => 'window.open(\'http://gnomad.broadinstitute.org/\')', 'class' => 'pointer'}, 'gnomAD Genome').$q->span(" AF: $current[5]").$q->span().$q->end_li()."\n";
		#	}
		#}
	}

	if ($semaph == 0) {$text .= $q->li('No MAF retrieved.')}




	####TEMP COMMENT connexion to DVD really slow comment for the moment
	if ($res->{'ns_gene'} == 1 && ($res->{'dfn'} == 1 || $res->{'usher'} == 1)) {
		#my $url = 'https://vvd.eng.uiowa.edu';    #does not seem to exist anymore 20210210
		#if ($res->{'dfn'} == 1 || $res->{'usher'} == 1) {$url = 'https://deafnessvariationdatabase.org'}#OtoDB university of Iowa deafness and usher genes
		my $url = 'https://deafnessvariationdatabase.org';
		#ping dvd to ensure host is reachable
		#my $p = Net::Ping->new("tcp", 2);
		#$text.= "ping ".$p->ping('deafnessvariationdatabase.org');
		#if ($p->ping('deafnessvariationdatabase.org')) {
			#$text.= 'ping ok';

		#my ($chr, $pos) = U2_modules::U2_subs_1::extract_pos_from_genomic($variant, 'clinvar');#clinvar style but for OtoDB!!

		if ($res->{'type_adn'} eq 'substitution') {
			my $no_chr_var = U2_modules::U2_subs_1::extract_dvd_var($variant);
			my $iowa_url = "$url/variant/".uri_encode($no_chr_var);
			# my $iowa_url = "$url/variant/$no_chr_var";
			my $ua = LWP::UserAgent->new(ssl_opts => { verify_hostname => 0, });
			$ua->timeout(3);
			my $fetch = $ua->get($iowa_url);
			if ($fetch->is_success()) {
				# print STDERR $iowa_url;
				my $content = $fetch->content();
				# if ($content !~ /Unable\sto\sfind\svariant/o) {$text .= $q->start_li() . $q->a({'href' => $iowa_url, 'target' => '_blank'}, 'Iowa DB') . $q->end_li() . "\n"}
				if ($content !~ /is\snot\sin\sthe\sDVD/o) {$text .= $q->start_li() . $q->a({'href' => $iowa_url, 'target' => '_blank'}, 'DVD') . $q->end_li() . "\n"}
				else {$text .= $q->li('Not recorded in Iowa DB')}
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

	###my $var = $res->{'nom'};
	###$var =~ s/\+/\\\+/og;
	###$var =~ s/\./\\\./og;
	###my $ua = new LWP::UserAgent();
	###$ua->timeout(3);
	###my $response = $ua->get("$url/api?version=8_2&type=hg19coord&method=IO&format=json&terms=$chr:$pos");
	#http://vvd.eng.uiowa.edu/api?terms=chr1:94461749 - deprecated

	###if ($response->is_success()) {
		###$text.= $response->decoded_content() . "\n";
		###my @dvd = split(/\n/, $response->decoded_content());
		###my @good_line = grep (/$var/, @dvd);
		##print "$dvd[0]-$var";
		###my @split_dvd = split(/\t/, $good_line[0]);
		###if ($split_dvd[57] && $split_dvd[57] ne 'NULL') {$text .= $q->start_li() . $q->span({'onclick' => "window.open('$url/sources')", 'class' => 'pointer'}, 'OtoDB').$q->span(" MAF: $split_dvd[57]") . $q->end_li()} #otoscope_all_af
		##print $split_dvd[0];
		###if ($split_dvd[0] && $split_dvd[0] =~ /(\d+)/o) {$text .= $q->start_li() . $q->a({'href' => "$url/variant/$1?full", 'target' => '_blank'}, 'Iowa DB full description') . $q->end_li()}
	###}


			#else {print $response}
		#}
		#$p->close();
	#}
	####END TEMP COMMENT


	#then we add LOVD here!!!
	#print $text;exit;

	my ($evs_chr, $evs_pos_start, $evs_pos_end) = U2_modules::U2_subs_1::extract_pos_from_genomic($variant, 'evs');

	my $url = "http://www.lovd.nl/search.php?build=hg19&position=chr$evs_chr:".$evs_pos_start."_".$evs_pos_end;
	#$text .= $url;
	my $ua = new LWP::UserAgent();
	$ua->timeout(10);
	my $response = $ua->get($url);
	# print STDERR $url."\n";


	#c.13811+2T>G
	#"hg_build"	"g_position"	"gene_id"	"nm_accession"	"DNA"	"variant_id"	"url"
	#"hg19"	"chr1:215847440"	"USH2A"	"NM_206933.2"	"c.13811+2T>G"	"USH2A_00751"	"https://grenada.lumc.nl/LOVD2/Usher_montpellier/variants.php?select_db=USH2A&action=search_all&search_Variant%2FDBID=USH2A_00751"
	#my $response = $ua->request($req);https://grenada.lumc.nl/LOVD2/Usher_montpellier/variants.php?select_db=MYO7A&action=search_all&search_Variant%2FDBID=MYO7A_00018
	my $lovd_semaph = 0;
	if($response->is_success()) {
		my $escape_var = $res->{'nom'};
		$escape_var =~ s/\+/\\\+/og;
		if ($escape_var =~ /^(c\..+d[ue][lp])[ATGC]+/o) {
            $escape_var = $1;
        }

		# if ($response->decoded_content() =~ /"$escape_var".+"(https[^"]+Usher_montpellier\/[^"]+)"/g) {$text .= $q->start_li().$q->a({'href' => $1, 'target' => '_blank'}, 'LOVD USHbases').$q->end_li();}
		# if ($response->decoded_content() =~ /"(https:\/\/grenada\.lumc\.nl\/LOVD2\/Usher_montpellier\/[^"]+)"$/o) {print $q->start_a({'href' => $1, 'target' => '_blank'}), $q->img({'src' => $HTDOCS_PATH.'data/img/buttons/LOVD_button.png'}), $q->end_a();}
		# elsif ($response->decoded_content() =~ /"$escape_var".+"(http[^"]+shared\/[^"]+)"/g) {$text .= $q->start_li().$q->a({'href' => $1, 'target' => '_blank'}, 'LOVD').$q->end_li();}
		# print STDERR $response->decoded_content()."\n";
		# print STDERR $escape_var."\n";
		if ($response->decoded_content() =~ /"$escape_var".+"(http[^"]+)"/g) {
			my @matches = $response->decoded_content() =~ /"$escape_var".+"(http[^"]+)"/g;
			$text .= $q->start_li().$q->strong('LOVD matches: ').$q->start_ul();
			my $i = 1;
			foreach (@matches) {
				if ($_ =~ /https.+Usher_montpellier\//g) {$text .= $q->start_li() . $q->a({'href' => $_, 'target' => '_blank'}, 'LOVD USHbases') . $q->end_li()}
				elsif ($_ =~ /http.+databases\.lovd\.nl\/shared\//g) {$text .= $q->start_li() . $q->a({'href' => $_, 'target' => '_blank'}, 'LOVD3 shared') . $q->end_li()}
				elsif ($_ =~ /http.+databases\.lovd\.nl\/whole_genome\//g) {$text .= $q->start_li() . $q->a({'href' => $_, 'target' => '_blank'}, 'LOVD3 whole genome') . $q->end_li()}
				else {$text .= $q->start_li() . $q->a({'href' => $_, 'target' => '_blank'}, "Link $i") . $q->end_li();$i++;}
			}
			$text .= $q->end_ul() . $q->end_li();
			#$text .= $q->start_li().$q->a({'href' => $1, 'target' => '_blank'}, 'LOVD').$q->end_li();
		}
		else {$lovd_semaph = 1}
	}
	else {$lovd_semaph = 1}
	if ($lovd_semaph == 1) {
		if (grep /$res->{'gene'}/, @U2_modules::U2_subs_1::LOVD) {
			my $lovd_gene = $res->{'gene'};
			if ($lovd_gene eq 'DFNB31') {$lovd_gene = 'WHRN'}
			elsif ($lovd_gene eq 'CLRN1') {$lovd_gene = 'USH3A'}
			$res->{'nom'} =~ /(\w+\d)/og;
			my $pos_cdna = $1;
			$text .= $q->start_li() . $q->a({'href' => "https://grenada.lumc.nl/LOVD2/Usher_montpellier/variants.php?select_db=$res->{'gene'}&action=search_unique&order=Variant%2FDNA%2CASC&hide_col=&show_col=&limit=100&search_Variant%2FLocation=&search_Variant%2FExon=&search_Variant%2FDNA=$pos_cdna&search_Variant%2FRNA=&search_Variant%2FProtein=&search_Variant%2FDomain=&search_Variant%2FInheritance=&search_Variant%2FRemarks=&search_Variant%2FReference=&search_Variant%2FRestriction_site=&search_Variant%2FFrequency=&search_Variant%2FDBID=", 'target' => '_blank'}, 'LOVD USHbases?') . $q->end_li();
		}
		else {
			$text .= $q->start_li() . $q->a({'href' => "http://grenada.lumc.nl/LSDB_list/lsdbs/$res->{'gene'}", 'target' => '_blank'}, 'LOVD?') . $q->end_li();
		}
	}

	$text .= $q->end_ul() .  $q->end_td() . $q->td('Diverse population MAFs and links to LSDBs') . $q->end_Tr() . "\n";
	print $text;
	###END NEW style using VEP
}
#if ($q->param('asked') && $q->param('asked') eq 'class') {
#	print $q->header();
#	my $variant = U2_modules::U2_subs_1::check_nom_c($q, $dbh);
#	my ($gene, $second_name) = U2_modules::U2_subs_1::check_gene($q, $dbh);
#	my $acc = U2_modules::U2_subs_1::check_acc($q, $dbh);
#	my $class = U2_modules::U2_subs_1::check_class($q, $dbh);
#	my $update = "UPDATE variant SET classe = '$class' WHERE nom = '$variant' AND nom_gene = '{\"$gene\", \"$acc\"}';";
#	if (U2_modules::U2_subs_1::is_class_pathogenic($class) == 1){
#		$update = "UPDATE variant SET classe = '$class', defgen_export = 't' WHERE nom = '$variant' AND nom_gene = '{\"$gene\", \"$acc\"}';";
#	}
#	#print $update;
#	$dbh->do($update);
#	#print ($class, U2_modules::U2_subs_1::color_by_classe($class, $dbh));
#}
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

	my $update = "UPDATE variant SET $field = '$class' WHERE nom = '$variant' AND nom_gene = '{\"$gene\", \"$acc\"}';";
	if (U2_modules::U2_subs_1::is_class_pathogenic($class) == 1){
		$update = "UPDATE variant SET $field = '$class', defgen_export = 't' WHERE nom = '$variant' AND nom_gene = '{\"$gene\", \"$acc\"}';";
	}
	#print $update;
	$dbh->do($update);
	#print ($class, U2_modules::U2_subs_1::color_by_classe($class, $dbh));
}
if ($q->param('asked') && $q->param('asked') eq 'var_nom') {
	print $q->header();
	#my ($variant, $main, $nom_c);
	my $i = 0;
	#if ($q->param('nom_g') =~ /(chr[\dXYM]+:g\..+)/o) {$variant = $1}
	#if ($q->param('main_acc') =~ /(N[MR]_\d+)/o) {$main = $1}
	#my $nom_c;
	#if ($q->param('nom_c') =~ /(c\..+)/o) {$nom_c = $1}
	my $variant = U2_modules::U2_subs_1::check_nom_g($q, $dbh);
	my $main = U2_modules::U2_subs_1::check_acc($q, $dbh);
	my $nom_c = U2_modules::U2_subs_1::check_nom_c($q, $dbh);
	$nom_c =~ s/\+/\\\+/g;
	#print $nom_c.'--';
	#test mutalyzer
	if (U2_modules::U2_subs_1::test_mutalyzer() != 1) {U2_modules::U2_subs_1::standard_error('23', $q)}


	#my $wsdl = XML::Compile::WSDL11->new('https://mutalyzer.nl/services?wsdl');

	#my $caller = $wsdl->compileClient('numberConversion');

	#my $call = $call->({'build' => 'hg19', 'variant', $variant});


	my $soap = SOAP::Lite->uri('http://mutalyzer.nl/2.0/services')->proxy('https://mutalyzer.nl/services/?wsdl');


	my $call = $soap->call('numberConversion',
			SOAP::Data->name('build')->value('hg19'),
			SOAP::Data->name('variant')->value($variant));

	#my $call = $soap->numberConversion(SOAP::Data->name('build')->value('hg19'), SOAP::Data->name('variant')->value($variant));

	#print Dumper($call);exit;

	if (!$call->result()) {print "mutalyzer fault";}
	#else {print $call->{'string'};exit;}
	#exit;
	my $return = $q->start_ul();
	foreach ($call->result()->{'string'}) {
		my $tab_ref;
		if (ref($_) eq 'ARRAY') {$tab_ref = $_}
		else {$tab_ref->[0] = $_}

		#if (Dumper($_) =~ /\[/og) {$tab_ref = $_} ## multiple results: tab ref
		#else {$tab_ref->[0] = $_}

		foreach (@{$tab_ref}) {
			#print "$_--$nom_c--";
			if (/$main/ || /X[MR]_.+/o || /$nom_c/) {next}
			if ($i == 0) {$return .= $q->li("Alternative nomenclatures found as follow:")}
			#https://mutalyzer.nl/check?name=NM_001142763.1%3Ac.1319A%3EC
			if ($_ =~ /[\+-]/g) {$return .= $q->li($_)}
			else {$return .= $q->start_li().$q->span("$_ &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;").$q->start_a({'href' => 'https://mutalyzer.nl/check?name='.uri_escape($_), 'target' => '_blank'}).$q->span('Mutalyzer').$q->img({'src' => $HTDOCS_PATH.'data/img/link_small.png', 'border' => '0', 'width' =>'15'}).$q->end_a().$q->end_li()."\n"}
			$i++;
		}
	}
	if ($i > 0) {$return .= $q->end_ul()}
	else {$return = "No alternative nomenclature found."}
	print $return;

}
if ($q->param('asked') && $q->param('asked') eq 'var_info') {
	print $q->header();
	#print 'AJAX!!!!';
	# gene: '$gene', accession: '$acc', nom_c: '$var->{'nom'}', analysis_all: '$type_analyse', depth: '$var->{'depth'}', current_analysis: '$var->{'type_analyse'}, frequency: '$var->{'frequency'}', wt_f: '$var->{'wt_f'}', wt_r: '$var->{'wt_r'}, mt_f: '$var->{'mt_f'}, mt_r: '$var->{'mt_r'}, last_name: '$var->{'last_name'}', first_name: '$var->{'first_name'}', msr_filter: '$var->{'msr_filter'}', nb: '$nb'
	my ($gene, $second, $acc, $nom_c, $analyses, $current_analysis, $depth, $frequency, $wt_f, $wt_r, $mt_f, $mt_r, $msr_filter, $last_name, $first_name, $nb) = (U2_modules::U2_subs_1::check_gene($q, $dbh), U2_modules::U2_subs_1::check_acc($q, $dbh), U2_modules::U2_subs_1::check_nom_c($q, $dbh), $q->param('analysis_all'), $q->param('current_analysis'), $q->param('depth'), $q->param('frequency'), $q->param('wt_f'), $q->param('wt_r'), $q->param('mt_f'), $q->param('mt_r'), $q->param('msr_filter'), $q->param('last_name'), $q->param('first_name'), $q->param('nb'));

	my $info = $q->start_ul().$q->start_li().$q->start_strong().$q->em("$gene:").$q->span($nom_c).$q->end_strong().$q->end_li();

	#MAFs
	#my ($MAF, $maf_454, $maf_sanger, $maf_miseq) = ('NA', 'NA', 'NA', 'NA');
	##if ($var->{'type_analyse'} eq 'NGS-454') {
	##MAF 454
	#$maf_454 = U2_modules::U2_subs_1::maf($dbh, $gene, $acc, $nom_c, '454-\d+');
	##MAF SANGER
	#$maf_sanger = U2_modules::U2_subs_1::maf($dbh, $gene, $acc, $nom_c, 'SANGER');
	##MAF MiSeq
	#$maf_miseq = U2_modules::U2_subs_1::maf($dbh, $gene, $acc, $nom_c, $ANALYSIS_ILLUMINA_PG_REGEXP);
	##my $maf_url = "MAF 454: $maf_454 / MAF Sanger: $maf_sanger / MAF MiSeq: $maf_miseq";
	##$MAF = "MAF 454: <strong>$maf_454</strong> / MAF Sanger: <strong>$maf_sanger</strong><br/>MAF MiSeq: <strong>$maf_miseq</strong>";
	#$MAF = $q->start_li().$q->span("MAF 454: ").$q->strong($maf_454).$q->end_li().$q->start_li().$q->span("MAF Sanger: ").$q->strong($maf_sanger).$q->end_li().$q->start_li().$q->span("MAF Illumina: ").$q->strong($maf_miseq).$q->end_li();
	##454-USH2A for only a few patients
	#my $maf_454_ush2a = '';
	#if ($gene eq 'USH2A' && $analyses =~ /454-USH2A/o) {
	#	$maf_454_ush2a = U2_modules::U2_subs_1::maf($dbh, $gene, $acc, $nom_c, '454-USH2A');
	#	#$maf_url = "MAF 454-USH2A: $maf_454_ush2a / $maf_url";
	#	#$MAF = "MAF 454-USH2A: <strong>$maf_454_ush2a</strong><br/>$MAF";
	#	$MAF .= $q->li("MAF 454-USH2A: $maf_454_ush2a");
	#}
	#$info .= $q->start_li().$q->strong("MAFs:").$q->start_ul().$MAF.$q->end_ul().$q->end_li();
	#print $MAF;
	my $print_ngs = '';
	if ($depth) {
		#$info .= "--$current_analysis--";
		if ($current_analysis =~ /454-/o) {
			#$print_ngs = "DOC 454: <strong>$depth</strong> Freq: <strong> $frequency</strong><br/>wt f: $wt_f, wt r: $wt_r<br/>mt f: $mt_f, mt r: $mt_r<br/>";
			$info .= $q->start_li().$q->strong("$current_analysis values:").$q->start_ul().$q->start_li().$q->span("DOC: ").$q->strong($depth).$q->span(" Freq: ").$q->strong($frequency).$q->end_li().$q->start_li().$q->span("wt f: ").$q->strong($wt_f).$q->span(", wt r: ").$q->strong($wt_r).$q->end_li().$q->start_li().$q->span("mt f: ").$q->strong($mt_f).$q->span(", mt r: ").$q->strong($mt_r).$q->end_li().$q->end_ul().$q->end_li();
			#check if Illumina also??
			if ($analyses =~ /$ANALYSIS_ILLUMINA_REGEXP/) {
				my @matches = $analyses =~ /$ANALYSIS_ILLUMINA_REGEXP/g;
				foreach (@matches) {
					$info .= &miseq_details($_, $first_name, $last_name, $gene, $acc, $nom_c);
					#my $query_ngs = "SELECT depth, frequency, msr_filter FROM variant2patient a, patient b WHERE a.num_pat = b.numero AND a.id_pat = b.identifiant AND b.first_name = '$first_name' AND b.last_name = '$last_name' AND  nom_gene[1] = '$gene' AND nom_gene[2] = '$acc' AND nom_c = '$nom_c' AND type_analyse = '$_';";
					#my $res_ngs = $dbh->selectrow_hashref($query_ngs);
					##$print_ngs .= "DOC MiSeq: <strong>$res_ngs->{'depth'}</strong> Freq: <strong>$res_ngs->{'frequency'}</strong><br/>MSR filter:<strong>$res_ngs->{'msr_filter'}</strong><br/>";
					#$info .= $q->start_li().$q->strong("$_ values:").$q->start_ul().$q->start_li().$q->span("DOC: ").$q->strong($res_ngs->{'depth'}).$q->span(" Freq: ").$q->strong($res_ngs->{'frequency'}).$q->end_li().$q->start_li().$q->span("MSR filter: ").$q->strong($res_ngs->{'msr_filter'}).$q->end_li().$q->end_ul().$q->end_li();
				}
			}

		}
		if ($current_analysis =~ /$ANALYSIS_ILLUMINA_REGEXP/) {
			#$print_ngs = "DOC MiSeq: <strong>$depth</strong> Freq: <strong>$frequency</strong><br/>MSR filter:<strong>$msr_filter</strong><br/>";
			$info .= $q->start_li().$q->strong("$current_analysis values:").$q->start_ul().$q->start_li().$q->span("DOC: ").$q->strong($depth).$q->span(" Freq: ").$q->strong($frequency).$q->end_li().$q->start_li().$q->span("MSR filter: ").$q->strong($msr_filter).$q->end_li().$q->end_ul().$q->end_li();
			my @matches = $analyses =~ /$ANALYSIS_ILLUMINA_REGEXP/g;
			if ($#matches > 0) {
				foreach (@matches) {
					if ($_ ne $current_analysis) {$info .= &miseq_details($_, $first_name, $last_name, $gene, $acc, $nom_c)}
				}
			}
			#check if 454 also??
			if ($analyses =~ /(454-\d+)/o) {
				my $query_ngs = "SELECT depth, frequency, wt_f, wt_r, mt_f, mt_r FROM variant2patient a, patient b WHERE a.num_pat = b.numero AND a.id_pat = b.identifiant AND b.first_name = '$first_name' AND b.last_name = '$last_name' AND  nom_gene[1] = '$gene' AND nom_gene[2] = '$acc' AND nom_c = '$nom_c' AND type_analyse = '$1';";
				my $res_ngs = $dbh->selectrow_hashref($query_ngs);
				#$print_ngs .= "DOC 454: <strong>$res_ngs->{'depth'}</strong> Freq: <strong>$res_ngs->{'frequency'}</strong><br/>wt f: $res_ngs->{'wt_f'}, wt r: $res_ngs->{'wt_r'}<br/>mt f: $res_ngs->{'mt_f'}, mt r: $res_ngs->{'mt_r'}<br/>";
				$info .= $q->start_li().$q->strong("$current_analysis values:").$q->start_ul().$q->start_li().$q->span("DOC: ").$q->strong($res_ngs->{'depth'}).$q->span(" Freq: ").$q->strong($res_ngs->{'frequency'}).$q->end_li().$q->start_li().$q->span("wt f: ").$q->strong($res_ngs->{'wt_f'}).$q->span(", wt r: ").$q->strong($res_ngs->{'wt_r'}).$q->end_li().$q->start_li().$q->span("mt f: ").$q->strong($res_ngs->{'mt_f'}).$q->span(", mt r: ").$q->strong($res_ngs->{'mt_r'}).$q->end_li().$q->end_ul().$q->end_li();
			}
		}
	}
	#below test json unsuccessfull
	#qq {{"success": "login is successful", "userid": "$ userID"}}:
	#my $json = qq{{'txt': "<big>$print_ngs $MAF<br/><span id = \"maf_$nb\"></span></big>", "maf_url": $maf_url}};
	#my $json = encode_json({ aaData => $data, iTotalRecords => $count, iTotalDisplayRecords => $count, sEcho => int($params->{sEcho}) });
	#my $json = encode_json({ 'txt' => "<big>$print_ngs $MAF<br/><span id = \"maf_$nb\"></span></big>", 'maf_url' => $maf_url});
	#print $q->header(-type => "application/json",-charset => "utf-8");
	#print $json;
	$info .= $q->end_ul();
	print $info;
	#print "<big>$info$print_ngs $MAF<br/><span id = \"maf_$nb\"></span></big>";


}
if ($q->param('asked') && $q->param('asked') eq 'ponps') {
	print $q->header();
	my $text = $q->start_ul();
	#SELECT H FROM PREDICTIONS WHERE ENSP = '00000265944' AND POS = '319';
	#SIFT old fashion with SQLlite
	#if ($q->param('var_prot') && $q->param('var_prot') =~ /p\.\(?([A-Z][a-z]{2})(\d+)([A-Z][a-z]{2})\)?/o) {
	#	my ($wt, $pos, $mut) = ($1, $2, $3);
	#	if ($q->param('ensp') && $q->param('ensp') =~ /ENSP(\d+)$/o) {
	#		my $ensp = $1;
	#		$wt = U2_modules::U2_subs_1::three2one($wt);
	#		$mut = U2_modules::U2_subs_1::three2one($mut);
	#		##Connect to database
	#		my $dbh2 = DBI->connect( 'DBI:SQLite:dbname='.$DATABASES_PATH.'/Human_enst.sqlite',"", "", { RaiseError => 1, AutoCommit => 1 } ) or die $DBI::errstr;
	#		my $query = "SELECT $mut, CON FROM PREDICTIONS WHERE ENSP = '$ensp' AND POS = '$pos';";
	#		#print $query;
	#		my $res = $dbh2->selectrow_hashref($query);
	#		if ($res) {
	#			if ($res->{'CON'} eq $wt) {
	#				#$text = $q->start_li().$q->span('SIFT score: ').$q->span({'style' => 'color:'.U2_modules::U2_subs_1::sift_color($res->{$mut})}, "$res->{$mut} (".U2_modules::U2_subs_1::sift_interpretation($res->{$mut}).")").$q->end_li()."\n";
	#				$text = $q->start_li().$q->span('SIFT score: ').$q->span({'style' => 'color:'.U2_modules::U2_subs_1::sift_color($res->{$mut})}, U2_modules::U2_subs_1::sift_interpretation($res->{$mut})."($res->{$mut})").$q->end_li()."\n";
	#			}
	#			else {$text = $q->li("bad wt $res->{'CON'} for SIFT")}
	#		}
	#		else {$text = $q->li('no SIFT')}
	#	}
	#	else {$text = $q->li('no ENSP for SIFT')}
	#}
	#else {$text = $q->li('no variant')}

	#VEP => get PPH2 & SIFT
	#perl variant_effect_predictor.pl --fasta /Users/david/.vep/homo_sapiens/75/Homo_sapiens.GRCh37.75.dna.primary_assembly.fa --offline --cache --compress "gunzip -c" --polyphen b  --refseq --no_progress -q --fork 4 --no_stats --dir /Users/david/.vep/ --force --filter coding_change -i input_hgvs.txt -o test.txt
	#5 89988504 89988504 A/G +
	#my $vep_output;
	### we also compute predictions score like in missense_prioritize.pl

	my ($aa_ref, $aa_alt) = U2_modules::U2_subs_1::decompose_nom_p($q->param('var_prot'));

	my ($i, $j) = (0, 0);

	my $var_g = U2_modules::U2_subs_1::check_nom_g($q, $dbh);
	#if ($var_g =~ /chr([\dXYM]+):g\.(\d+)([ATGC])>([ATGC])/o) {
	if ($var_g =~ /chr($U2_modules::U2_subs_1::CHR_REGEXP):$U2_modules::U2_subs_1::HGVS_CHR_TAG\.(\d+)([ATGC])>([ATGC])/) {
		my ($chr, $pos1, $ref, $alt) = ($1, $2, $3, $4);

		#NEW style 04/2018 replacment of VEP with dbNSFP

		$chr =~ s/chr//og;
		#print "$EXE_PATH/tabix $DATABASES_PATH$DBNSFP_V2 $chr:$pos1-$pos1";
		my @dbnsfp =  split(/\n/, `$EXE_PATH/tabix $DATABASES_PATH$DBNSFP_V2 $chr:$pos1-$pos1`);
		#my @dbnsfp =  split(/\n/, `$EXE_PATH/tabix $DATABASES_PATH$DBNSFP_V2 $chr:207634224-207634224`);

		#print $#dbnsfp.'-'.$dbnsfp[0];
		if ($dbnsfp[0] eq '') {print 'No values in dbNSFP v2.9 for this variant.';exit;}
		#if ($#dbnsfp < 2) {print 'No values in dbNSFP v2.9 for this variant.';exit;}
		foreach (@dbnsfp) {
			my @current = split(/\t/, $_);
			if (($current[2] eq $ref) && ($current[3] eq $alt) && ($current[4] eq $aa_ref) && ($current[5] eq $aa_alt)) {
				my $sift = U2_modules::U2_subs_2::most_damaging($current[26], 'min');
				if (U2_modules::U2_subs_1::sift_color($sift) eq '#FF0000') {$i++}
				if ($sift ne '') {$j++}
				my $polyphen = U2_modules::U2_subs_2::most_damaging($current[32], 'max');
				if (U2_modules::U2_subs_1::pph2_color2($polyphen) eq '#FF0000') {$i++}
				if ($polyphen ne '') {$j++}
				my $fathmm = U2_modules::U2_subs_2::most_damaging($current[44], 'min');
				if (U2_modules::U2_subs_1::fathmm_color($fathmm) eq '#FF0000') {$i++}
				if ($fathmm ne '') {$j++}
				my $metalr = U2_modules::U2_subs_2::most_damaging($current[50], 'max');
				if (U2_modules::U2_subs_1::metalr_color($metalr) eq '#FF0000') {$i++}
				if ($metalr ne '') {$j++}
				#my $ea_maf = my $aa_maf = my $exac_maf = my $1kg_maf = -1;
				my $ea_maf = sprintf('%.4f', $current[93]);
				my $aa_maf = sprintf('%.4f', $current[92]);
				my $exac_maf = sprintf('%.4f', $current[101]);
				my $onekg_maf = sprintf('%.4f', $current[83]);
				if (max($ea_maf, $aa_maf, $exac_maf, $onekg_maf) > -1) {
					$j++;
					if (max($ea_maf, $aa_maf, $exac_maf, $onekg_maf) < 0.005) {$i++}
				}
				if (U2_modules::U2_subs_2::dbnsfp_clinvar2text($current[115]) =~ /Pathogenic/) {$i++}
				if (U2_modules::U2_subs_2::dbnsfp_clinvar2text($current[115]) ne 'not seen in Clinvar') {$j++}

				$text .= $q->start_li().
							$q->span({'onclick' => 'window.open(\'http://sift.bii.a-star.edu.sg\')', 'class' => 'pointer'}, 'SIFT').
							$q->span(" score: ").$q->span({'style' => 'color:'.U2_modules::U2_subs_1::sift_color($sift)}, $sift).$q->end_li()."\n".
						$q->end_li()."\n".
						$q->start_li().
							$q->span({'onclick' => 'window.open(\'http://genetics.bwh.harvard.edu/pph2/\')', 'class' => 'pointer'}, 'Polyphen2').
							$q->span(" score: ").$q->span({'style' => 'color:'.U2_modules::U2_subs_1::pph2_color2($polyphen)}, $polyphen).$q->end_li()."\n".
						$q->end_li()."\n".
						$q->start_li().
							$q->span({'onclick' => 'window.open(\'http://fathmm.biocompute.org.uk/\')', 'class' => 'pointer'}, 'FATHMM').
							$q->span(" score: ").$q->span({'style' => 'color:'.U2_modules::U2_subs_1::fathmm_color($fathmm)}, $fathmm).$q->end_li()."\n".
						$q->end_li()."\n".
						$q->start_li().
							$q->span({'onclick' => 'window.open(\'http://exac.broadinstitute.org/\')', 'class' => 'pointer'}, 'MetaLR').
							$q->span(" score: ").$q->span({'style' => 'color:'.U2_modules::U2_subs_1::metalr_color($metalr)}, $metalr).$q->end_li()."\n".
						$q->end_li()."\n";
				my ($ratio, $class) = (0, 'one_quarter');
				if ($j != 0) {
					$ratio = sprintf('%.2f', ($i)/($j));
					if ($ratio >= 0.25 && $ratio < 0.5) {$class = 'two_quarter'}
					elsif ($ratio >= 0.5 && $ratio < 0.75) {$class = 'three_quarter'}
					elsif ($ratio >= 0.75) {$class = 'four_quarter'}

					$text .= $q->start_li().$q->span({'class' => $class}, 'MD experimental pathogenic ratio: ').$q->span({'class' => $class}, "$ratio, ($i/$j)").$q->end_li();
				}
			}
		}
	}




		#my $tempfile = File::Temp->new(UNLINK => 0);
	#	my $tempfile = File::Temp->new();
	#
	#	#open(F, '>'.$DATABASES_PATH.'variant_effect_predictor/input.txt') or die $!;
	#	#print F "$1 $2 $2 $3/$4 +\n";
	#	#close F;
	#
	#	print $tempfile "$chr $pos1 $pos1 $ref/$alt +\n";
	#	if ($tempfile->filename() =~ /(\/tmp\/\w+)/o) {
	#		#http://www.nada.kth.se/~esjolund/writing-more-secure-perl-cgi-scripts/output/writing-more-secure-perl-cgi-scripts.html.utf8  run vep without tempfile not working don't know why
	#		#my($child_out, $child_in);
	#		#$pid = open2($child_out, $child_in, "/home/esjolund/public_html/cgi-bin/count.py", $type,"/dev/stdin");
	#		#print $child_in $content;
	#		#close($child_in);
	#		#my $result=<$child_out>;
	#		#waitpid($pid,0);
	#		#print $q->li($result);
	#		#my @results = split('\n', $result);
	#		#print $q->li($ENV{PATH});
	#		delete $ENV{PATH};
	#
	#		#my @results = split('\n', `$DATABASES_PATH/variant_effect_predictor/variant_effect_predictor.pl --fasta $DATABASES_PATH/.vep/homo_sapiens/75/Homo_sapiens.GRCh37.75.dna.primary_assembly.fa --offline --cache --compress "gunzip -c" --polyphen b --sift b --refseq --no_progress -q --fork 4 --no_stats --dir $DATABASES_PATH/.vep/ --force --filter coding_change -i $1 -o STDOUT`);   ###VEP75
	#		my @results = split('\n', `$DATABASES_PATH/variant_effect_predictor_78/variant_effect_predictor.pl --fasta $DATABASES_PATH/.vep/homo_sapiens/75/Homo_sapiens.GRCh37.75.dna.primary_assembly.fa --offline --cache --compress "gunzip -c" --maf_esp --polyphen b --sift b --refseq --no_progress -q --fork 4 --no_stats --dir $DATABASES_PATH/.vep/ --force --filter coding_change -i $1 --plugin FATHMM,"python $DATABASES_PATH/.vep/Plugins/fathmm.py" --plugin ExAC,$DALLIANCE_DATA_DIR_PATH/exac/ExAC.r0.3.sites.vep.vcf.gz -o STDOUT`);  ##VEP 78 Grch37
	#		#print $q->li("$DATABASES_PATH/variant_effect_predictor_78/variant_effect_predictor.pl --fasta $DATABASES_PATH/.vep/homo_sapiens/78_GRCh37/Homo_sapiens.GRCh37.75.dna.primary_assembly.fa --offline --cache --compress \"gunzip -c\" --polyphen b --sift b --refseq --maf_esp --no_progress -q --fork 4 --no_stats --dir $DATABASES_PATH/.vep/ --force --filter coding_change -i $1 --plugin FATHMM,\"python $DATABASES_PATH/.vep/Plugins/fathmm.py\" -o STDOUT");
	#		if ($q->param('acc_no') =~ /(NM_\d+)/o) {
	#			my @good_line = grep(/$1/, @results);
	#			my $space_var = $chr.'_'.$pos1.'_'.$ref.'/'.$alt;
	#			#print $space_var;
	#			my @results_split = split(/\s/, $good_line[0]);
	#			#if ($good_line[0] =~ /$space_var/o) { sometimes does not work even by escaping /
	#			if ($results_split[0] eq $space_var) {
	#				if ($good_line[0] =~ /SIFT=([^\)]+\))/o) {
	#					$text .= $q->start_li().$q->span({'onclick' => 'window.open("http://sift.bii.a-star.edu.sg/");', 'target' => '_blank', 'class' => 'pointer'}, 'SIFT').$q->span(' score: ').$q->span({'style' => 'color:'.U2_modules::U2_subs_1::sift_color2($1)}, $1).$q->end_li()."\n";
	#					if (U2_modules::U2_subs_1::sift_color2($1) eq '#FF0000') {$i++}
	#					$j++;
	#				}
	#				else {$text .= $q->li("No SIFT for this position.")}
	#				if ($good_line[0] =~ /PolyPhen=([\w\d\(\)\.^\)]+\))/o) {
	#					$text .= $q->start_li().$q->span({'onclick' => 'window.open("http://genetics.bwh.harvard.edu/pph2/");', 'target' => '_blank', 'class' => 'pointer'}, 'PolyPhen2').$q->span(' score: ').$q->span({'style' => 'color:'.U2_modules::U2_subs_1::pph2_color($1)}, $1).$q->end_li()."\n";
	#					if (U2_modules::U2_subs_1::pph2_color($1) eq '#FF0000') {$i++}
	#					$j++;
	#				}
	#				else {
	#					$text .= $q->li("No Polyphen for this position.")#.$q->start_li().$q->span('Complete VEP output:').$q->start_ul();
	#					#foreach (@results) {$text .= $q->li($_)}
	#					#$text .= $q->end_ul().$q->end_li();
	#				}
	#				if ($good_line[0] =~ /FATHMM=([\d\.-]+)\(/o) {
	#					$text .= $q->start_li().$q->span({'onclick' => 'window.open("http://fathmm.biocompute.org.uk/");', 'target' => '_blank', 'class' => 'pointer'}, 'FATHMM').$q->span(' score: ').$q->span({'style' => 'color:'.U2_modules::U2_subs_1::fathmm_color($1)}, $1).$q->end_li()."\n";
	#					if (U2_modules::U2_subs_1::fathmm_color($1) eq '#FF0000') {$i++}
	#					$j++;
	#				}
	#
	#				#ESP replaced with ExAC 07/27/2015
	#
	#				my $ea_maf = my $aa_maf = my $exac_maf = -1;
	#				if ($good_line[0] =~ /EA_MAF=[ATCG-]+:([\d\.]+);*/o) {$ea_maf = $1}
	#				if ($good_line[0] =~ /AA_MAF=[ATCG-]+:([\d\.]+);*/o) {$aa_maf = $1}
	#				#my $max_maf = $ea_maf;
	#				#if ($aa_maf > $max_maf) {$max_maf = $aa_maf}
	#				#my $maf;
	#				if ($good_line[0] =~ /ExAC_AF=([\d\.e-]+);*/) {$exac_maf = $1}
	#
	#				if (max($ea_maf, $aa_maf, $exac_maf) > -1) {
	#					$j++;
	#					if (max($ea_maf, $aa_maf, $exac_maf) < 0.005) {$i++}
	#				}
	#
	#				if ($good_line[0] =~ /CLIN_SIG=(\w+)/o) {
	#					if ($1 =~ /pathogenic/o) {$i++}
	#					$j++;
	#				}
	#
	#				#MCAP results for missense
	#				my @mcap =  split(/\n/, `$EXE_PATH/tabix $DATABASES_PATH/mcap/mcap_v1_0.txt.gz $chr:$pos1-$pos1`);
	#				foreach (@mcap) {
	#					my @current = split(/\t/, $_);
	#					if (/\t$ref\t$alt\t/) {
	#						$text .= $q->start_li().$q->span({'onclick' => 'window.open(\'http://bejerano.stanford.edu/mcap/\')', 'class' => 'pointer'}, 'M-CAP').$q->span(' score: ').$q->span({'style' => 'color:'.U2_modules::U2_subs_1::mcap_color($current[4])}, sprintf('%.4f', $current[4])).$q->end_li()."\n";
	#						if (U2_modules::U2_subs_1::mcap_color($current[4]) eq '#FF0000') {$i++}
	#						$j++;
	#					}
	#				}
	#
	#				my ($ratio, $class) = (0, 'one_quarter');
	#				if ($j != 0) {
	#					$ratio = sprintf('%.2f', ($i)/($j));
	#					if ($ratio >= 0.25 && $ratio < 0.5) {$class = 'two_quarter'}
	#					elsif ($ratio >= 0.5 && $ratio < 0.75) {$class = 'three_quarter'}
	#					elsif ($ratio >= 0.75) {$class = 'four_quarter'}
	#
	#					$text .= $q->start_li().$q->span({'class' => $class}, 'U2 experimental pathogenic ratio: ').$q->span({'class' => $class}, "$ratio, ($i/$j)").$q->end_li();
	#				}
	#
	#				#$text .= $q->li($good_line[0]);
	#			}
	#			else {
	#				#$text .= $q->li("variant '$space_var' not found in VEP results:\n '$results_split[0]'");
	#				$text .= $q->li("variant '$space_var' not found in VEP results:").$q->start_li().$q->span('Complete VEP output:').$q->start_ul();
	#				foreach (@results) {$text .= $q->li($_)}
	#				$text .= $q->end_ul().$q->end_li();
	#			}
	#		}
	#	}
	#	else {$text .= $q->li("Predictors not run because of a security issue. Please report.")}
	#}

	#my $nom_c = U2_modules::U2_subs_1::check_nom_c($q, $dbh);
	#my $gene = U2_modules::U2_subs_1::check_gene($q, $dbh);
	#my $enst = U2_modules::U2_subs_1::check_ens($q, $dbh, 'enst');

	#HSF needs enst, nom_c

	#my $soap = SOAP::Lite->uri('http://www.4d.com/namespace/default')->proxy('http://www.umd.be/HSF3/4DWSDL');
	#
	#my $hsf = $soap->WS_HSF($enst, $nom_c, 'tab');
	#foreach my $key (keys(%{$hsf})) {
	#	if (ref($hsf->{$key}) eq 'ARRAY') {foreach (@{$hsf->{$key}}) {$text .= $q->li("ARRAY $_")}}
	#	if (ref($hsf->{$key}) eq 'HASH') {$text .= $q->li("REF $key: $hsf->{$key}")}
	#	if (ref($hsf->{$key}) eq 'REF') {$text .= $q->li("REF $key: $hsf->{$key}")}
	#	else {$text .= $q->li("OTHER ".(ref($hsf->{$key}))." $key: $hsf->{$key}")}
	#}
	#HSF is a real mess - above code gives sthg like the following - we keep the single link and try later with json TODO: try json
	#ARRAY definitions
	#ARRAY HASH(0x10321bce8)
	#ARRAY ARRAY(0x103233b10)
	#ARRAY
	#ARRAY HASH(0x100bfc090)
	#ARRAY {http://schemas.xmlsoap.org/wsdl/}definitions
	#ARRAY HASH(0x103337d40)
	#OTHER ARRAY _content: ARRAY(0x103231630)
	#OTHER SOAP::Lite _context: SOAP::Lite=HASH(0x1033597a0)
	#ARRAY ARRAY(0x103231630)
	#OTHER ARRAY _current: ARRAY(0x10324e8f0)
	$text .= $q->end_ul();
	print $text;

}

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

	my $query = "SELECT nom, $name as nom2, classe FROM variant WHERE nom_gene[2] = '$acc_no' AND num_segment = '$num_seg' AND type_segment = '$type' ORDER BY nom_g $order;";
	if ($user->isPublic == 1) {$query = "SELECT nom, $name as nom2, classe FROM variant WHERE nom_gene[2] = '$acc_no' AND num_segment = '$num_seg' AND type_segment = '$type' AND (nom, nom_gene) NOT IN (SELECT nom_c, nom_gene FROM variant2patient WHERE nom_gene[2] = '$acc_no') ORDER BY nom_g $order;"}
	#print $query;
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
				$q->textfield(-name => 'new_variant', -id => 'new_variant', -value => 'c.', -size => '20', -maxlength => '50')."\n".
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
	my $query = "SELECT nom[2] as main FROM gene WHERE nom[1] = '$gene' AND main = 't'";
	my $res = $dbh->selectrow_hashref($query);
	my $main = $res->{'main'};

	my ($order, $toprint, $freq) = ('a.nom_g '.U2_modules::U2_subs_1::get_strand($gene, $dbh), 'frequency', '1');
	if ($q->param('freq') && $q->param('freq') == 1) {($order, $toprint, $freq) = ('COUNT(b.nom_c) DESC', 'position', '2')}


	#$query = "SELECT a.nom, a.classe, a.nom_gene, a.nom_prot, a.nom_ivs, COUNT(b.nom_c) as allel FROM variant a, variant2patient b WHERE a.nom = b.nom_c AND a.nom_gene = b.nom_gene AND a.nom_gene[1] = '$gene' AND $sort_type = '$sort_value' GROUP BY a.classe, a.nom, a.nom_gene, a.nom_prot, a.nom_ivs ORDER BY $order;";
	#changed 06/23/2015 to remove duplicates (e.g. variant seen in MiSeq and sanger were counted twice)

	$query = "WITH tmp AS (SELECT DISTINCT(a.nom_c, a.num_pat, a.id_pat, a.nom_gene), a.nom_c, a.nom_gene FROM variant2patient a, variant b WHERE a.nom_c = b.nom AND a.nom_gene = b.nom_gene AND a.nom_gene[1] = '$gene' AND $sort_type = '$sort_value')\nSELECT a.nom, a.classe, a.nom_gene, a.nom_prot, a.nom_ivs, COUNT(b.nom_c) as allel FROM variant a, tmp b WHERE a.nom = b.nom_c AND a.nom_gene = b.nom_gene AND a.nom_gene[1] = '$gene' GROUP BY a.classe, a.nom, a.nom_gene, a.nom_prot, a.nom_ivs, a.nom_g ORDER BY $order;";
	#$query = "WITH tmp AS (SELECT DISTINCT(a.nom_c, a.num_pat, a.id_pat, a.nom_gene), a.nom_c, a.nom_gene FROM variant2patient a, variant b WHERE a.nom_c = b.nom AND a.nom_gene = b.nom_gene AND a.nom_gene[1] = '$gene' AND $sort_type = '$sort_value')\nSELECT a.*, COUNT(b.nom_c) as allel FROM variant a, tmp b WHERE a.nom = b.nom_c AND a.nom_gene = b.nom_gene AND a.nom_gene[1] = '$gene' GROUP BY a.classe, a.nom, a.nom_gene, a.nom_prot, a.nom_ivs ORDER BY $order;";

	#$query = "SELECT a.nom, a.classe, a.nom_gene, a.nom_prot, a.nom_ivs, COUNT(b.nom_c) as allel FROM variant a, variant2patient b WHERE a.nom = b.nom_c AND a.nom_gene = b.nom_gene AND a.nom_gene[1] = '$gene' AND $sort_type = '$sort_value' GROUP BY a.classe, a.nom, a.nom_gene, a.nom_prot, a.nom_ivs ORDER BY a.nom_g ".U2_modules::U2_subs_1::get_strand($gene, $dbh).";";
	if ($sort_type eq 'all') {
		#$query = "SELECT a.nom, a.classe, a.nom_gene, a.nom_prot, a.nom_ivs, COUNT(b.nom_c) as allel FROM variant a, variant2patient b WHERE a.nom = b.nom_c AND a.nom_gene = b.nom_gene AND a.nom_gene[1] = '$gene' GROUP BY a.classe, a.nom, a.nom_gene, a.nom_prot, a.nom_ivs ORDER BY $order;";
		#changed 06/23/2015 to remove duplicates (e.g. variant seen in MiSeq and sanger were counted twice)
		$query = "WITH tmp AS (SELECT DISTINCT(a.nom_c, a.num_pat, a.id_pat, a.nom_gene), a.nom_c, a.nom_gene FROM variant2patient a WHERE a.nom_gene[1] = '$gene')\nSELECT a.nom, a.classe, a.nom_gene, a.nom_prot, a.nom_ivs, COUNT(b.nom_c) as allel FROM variant a, variant2patient b WHERE a.nom = b.nom_c AND a.nom_gene = b.nom_gene AND a.nom_gene[1] = '$gene' GROUP BY a.classe, a.nom, a.nom_gene, a.nom_prot, a.nom_ivs ORDER BY $order;";

		#SELECT a.nom, a.classe, a.nom_gene, a.nom_prot, a.nom_ivs, COUNT(DISTINCT(b.type_analyse)) as allel FROM variant a, tmp b WHERE a.nom = b.nom_c AND a.nom_gene = b.nom_gene AND a.nom_gene[1] = '$gene' GROUP BY a.classe, a.nom, a.nom_gene, a.nom_prot, a.nom_ivs ORDER BY $order;";
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
			if ($result->{'nom_gene'}[1] ne $main) {$acc_no = "$result->{'nom_gene'}[1]:"}

			my $spec = '';
			if ($sort_type eq 'type_arn') {
				my $value = U2_modules::U2_subs_1::get_interpreted_position($result, $dbh, 'span', $q);
				my $css_class = $value;
				$css_class =~ s/ /_/og;
				$spec = $q->span({'class' => $css_class}, " - $value")
			}

			$text .= $q->start_li().$q->span({'style' => "color:$color", 'class' => 'pointer', 'onclick' => "window.open('variant.pl?gene=$gene&accession=$result->{'nom_gene'}[1]&nom_c=".uri_escape($result->{'nom'})."', \'_blank\')", 'title' => 'Go to the variant page'}, "$acc_no$result->{'nom'} - $name2").$q->span(" in $result->{'allel'} patients(s) ").$spec.$q->end_li();
		}
		$text .= $q->end_ul();
	}
	print $text;
}

if ($q->param('asked') && $q->param('asked') eq 'change_filter') {

	#not called by ajax but it was a good place to put it
	print $q->header();
	my ($id, $number) = U2_modules::U2_subs_1::sample2idnum(uc($q->param('sample')), $q);
	my $analysis = U2_modules::U2_subs_1::check_analysis($q, $dbh, 'filtering');
	my $new_filter = U2_modules::U2_subs_1::check_filter($q);
	my $update = "UPDATE miseq_analysis SET filter = '$new_filter' WHERE num_pat = '$number' AND id_pat = '$id' AND type_analyse = '$analysis';";
	#print $update;
	$dbh->do($update);
	#print "Location: patient_file.pl?sample=$id$number";
	print $q->redirect("patient_file.pl?sample=$id$number")
}

if ($q->param('asked') && $q->param('asked') eq 'rna_status') {
	print $q->header();
	my $variant = U2_modules::U2_subs_1::check_nom_c($q, $dbh);
	my ($gene, $second_name) = U2_modules::U2_subs_1::check_gene($q, $dbh);
	my $acc = U2_modules::U2_subs_1::check_acc($q, $dbh);
	my $status = U2_modules::U2_subs_1::check_rna_status($q, $dbh);
	my $update = "UPDATE variant SET type_arn = '$status' WHERE nom = '$variant' AND nom_gene = '{\"$gene\", \"$acc\"}';";
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
	#print $number;
	#my $query = "SELECT a.*, b.*, a.nom_prot as hgvs_prot, c.nom_prot, c.enst, c.acc_version FROM variant a, variant2patient b, gene c WHERE a.nom_gene = b.nom_gene AND a.nom = b.nom_c AND a.nom_gene = c.nom AND b.id_pat = '$id' AND b.num_pat = '$number' AND a.classe IN ('VUCS class III', 'VUCS class IV', 'pathogenic');";
	#my $query = "SELECT DISTINCT(b.nom_c), a.*, a.nom_prot as hgvs_prot, b.statut, b.allele, c.nom_prot, c.enst, c.acc_version FROM variant a, variant2patient b, gene c WHERE a.nom_gene = b.nom_gene AND a.nom = b.nom_c AND a.nom_gene = c.nom AND b.id_pat = '$id' AND b.num_pat = '$number' AND a.classe IN ('VUCS class III', 'VUCS class IV', 'pathogenic');";

	#need to get info on patients (for multiple samples)
	my ($list, $first_name, $last_name) = U2_modules::U2_subs_3::get_sampleID_list($id, $number, $dbh) or die "No sample info $!";
	my $query = "SELECT DISTINCT(b.nom_c), a.*, a.nom_prot as hgvs_prot, b.statut, b.allele, c.nom_prot, c.enst, c.acc_version, c.dfn, c.rp, c.usher FROM variant a, variant2patient b, gene c WHERE a.nom_gene = b.nom_gene AND a.nom = b.nom_c AND a.nom_gene = c.nom AND (b.id_pat, b.num_pat) IN ($list) AND a.defgen_export = 't';";
	# print STDERR $query;
	# exit;
	#my $query = "SELECT DISTINCT(b.nom_c), a.*, a.nom_prot as hgvs_prot, b.statut, b.allele, c.nom_prot, c.enst, c.acc_version FROM variant a, variant2patient b, gene c WHERE a.nom_gene = b.nom_gene AND a.nom = b.nom_c AND a.nom_gene = c.nom AND b.id_pat = '$id' AND b.num_pat = '$number' AND a.defgen_export = 't';";
	my $sth = $dbh->prepare($query);
	my $res = $sth->execute();
	#my $content = "GENE;VARIANT;GENOME_REFERENCE;NOMENCLATURE_HGVS;NOMPROTEINE;VARIANT_C;CHROMOSOME;SEQUENCE_REF;LOCALISATION;POSITION_GENOMIQUE;NM;VARIANT_P;CLASSESUR3;CLASSESUR5;DOMAINE_FCTL;CONSEQUENCES;RS;COSMIC;ENST;DATEDESAISIE;REFERENCES;COMMENTAIRE;ETAT;A_ENREGISTRER;STATUT;RESULTAT;ALLELE;NOTES\n";
	#updated with defgen file 28/12/2017
	#my $content = "GENE;VARIANT;A_ENREGISTRER;STATUT;ETAT;RESULTAT;VARIANT_P;VARIANT_C;ALLELE;CLASSESUR3;CLASSESUR5;NOTES;COSMIC;ENST;NM;RS;REFERENCES;CONSEQUENCES;POSITION_GENOMIQUE;COMMENTAIRE\n";
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
			elsif ($filter eq 'CHM' && $result->{'nom_gene'}[0] ne 'CHM') {next}


			my ($chr, $pos) = U2_modules::U2_subs_1::extract_pos_from_genomic($result->{'nom_g'}, 'clinvar');
			my $acmg_class = $result->{'acmg_class'};
			if ($acmg_class eq '') {$acmg_class = U2_modules::U2_subs_3::u2class2acmg($result->{'classe'}, $dbh)}
			my $defgen_acmg = &u22defgen_acmg($acmg_class);
			my ($defgen_a1, $defgen_a2) = U2_modules::U2_subs_3::get_defgen_allele($result->{'allele'});
			#$content .= "$result->{nom_gene}[0];$result->{nom_g};;;$result->{'statut'};$result->{classe};$result->{hgvs_prot};$result->{nom_c};$result->{'allele'};;;$result->{type_segment} $result->{num_segment};;$result->{enst};$result->{nom_gene}[1];$result->{snp_id};hg19;$result->{type_prot};;$result->{nom_prot}\n";
			$content .= "$result->{nom_gene}[0];$result->{nom_gene}[1].$result->{acc_version}:$result->{nom_c};;".&u22defgen_status($result->{'statut'}).";;$result->{hgvs_prot};$result->{nom_c};$result->{enst};$result->{nom_gene}[1].$result->{acc_version};$pos;$defgen_acmg;;;$result->{snp_id};;$result->{type_prot};$result->{classe};$chr;hg19;$result->{nom_g};$result->{type_segment} $result->{num_segment};;;$defgen_a1;$defgen_a2\r\n";
			#$content .= "$result->{nom_gene}[0];$result->{nom_c};hg19;$result->{nom_g};$result->{nom_prot};$result->{nom_c};chr$chr;;$result->{type_segment} $result->{num_segment};$pos;$result->{nom_gene}[1].$result->{acc_version};$result->{hgvs_prot};;;;$result->{type_prot};$result->{snp_id};;$result->{enst};;;$result->{classe};;;$result->{'statut'};;$result->{'allele'};\n";
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
	#print $nom_g;
	my $query = "SELECT a.nom, a.acc_version, b.nom as var, b.nom_prot as hgvs_prot, b.acmg_class, b.classe, a.enst, b.snp_id, b.type_prot, b.nom_g, b.type_segment, b.num_segment FROM gene a, variant b WHERE a.nom = b.nom_gene AND b.nom_g = '$nom_g';";
	my $res = $dbh->selectrow_hashref($query);
	#
	my $content =  "GENE;VARIANT;A_ENREGISTRER;ETAT;RESULTAT;VARIANT_P;VARIANT_C;ENST;NM;POSITION_GENOMIQUE;CLASSESUR5;CLASSESUR3;COSMIC;RS;REFERENCES;CONSEQUENCES;COMMENTAIRE;CHROMOSOME;GENOME_REFERENCE;NOMENCLATURE_HGVS;LOCALISATION;SEQUENCE_REF;LOCUS;ALLELE1;ALLELE2\r\n";
	if ($res ne '0E0') {
		my ($chr, $pos) = U2_modules::U2_subs_1::extract_pos_from_genomic($res->{'nom_g'}, 'clinvar');
		my $acmg_class = $res->{'acmg_class'};
		if ($acmg_class eq '') {$acmg_class = U2_modules::U2_subs_3::u2class2acmg($res->{'classe'}, $dbh)}
		my $defgen_acmg = &u22defgen_acmg($acmg_class);
		$content .= "$res->{nom}[0];$res->{nom}[1].$res->{acc_version}:$res->{var};;;;$res->{hgvs_prot};$res->{var};$res->{enst};$res->{nom}[1].$res->{acc_version};$pos;$defgen_acmg;;;$res->{snp_id};;$res->{type_prot};;$chr;hg19;$res->{nom_g};$res->{type_segment} $res->{num_segment};;;;\r\n";
		$nom_g =~ s/>/_/og;
		$nom_g =~ s/:/_/og;
		open F, '>'.$ABSOLUTE_HTDOCS_PATH.'data/defgen/'.$nom_g.'_defgen.csv' or die $!;
		print F $content;
		close F;
		print '<a href="'.$HTDOCS_PATH.'data/defgen/'.$nom_g.'_defgen.csv" download>Download file for '.$res->{nom}[1].$res->{acc_version}.':'.$res->{var}.'</a>';
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
	#my $ul = $q->p('please click a run id below or click \'global\' for an overview of all runs.').$q->ul().$q->start_li().$q->a({'href' => 'stats_ngs.pl?run=global'}, 'global analysis').$q->end_li();#deprecated
	#, 'data-order' => '[[ 0, "desc" ]]' defined in js
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
	else {$query = "SELECT DISTINCT(a.run_id), a.type_analyse, b.filtering_possibility FROM miseq_analysis a, valid_type_analyse b WHERE a.type_analyse = b.type_analyse AND b.type_analyse  = '$analysis' ORDER BY a.type_analyse DESC, a.run_id;"}
	#my $dates = "\"date\": [
	#";
	my $i = my $j = my $k = my $l = my $m = my $n = my $o = my $p = my $r = my $s = my $t = my $u = my $v = 0;
	my $sth = $dbh->prepare($query);
	my $res = $sth->execute();
	if ($res ne '0E0') {
		while (my $result = $sth->fetchrow_hashref()) {

			my $query_samples = 'SELECT COUNT(id_pat || num_pat) as a FROM miseq_analysis WHERE run_id = \''.$result->{'run_id'}.'\';';
			my $num_samples = $dbh->selectrow_hashref($query_samples);

			#timeline


			#my $title = '';
			#my $thumbnail = 'miseq_thumb.jpg';

			#my $analysis_date = U2_modules::U2_subs_1::date_pg2tjs(U2_modules::U2_subs_1::get_run_date($result->{'run_id'}));
			#my $text = "Run ID: <a href = 'stats_ngs.pl?run=$result->{'run_id'}' target = '_blank'>$result->{'run_id'}</a>";

			#if ($result->{'type_analyse'} eq 'MiSeq-28') {$i++;$text .= "<br/>Run Number: $i";$title = "Run $i";}
			#elsif ($result->{'type_analyse'} eq 'MiSeq-112') {$j++;$text .= "<br/>Run Number: $j";$title = "Run $j";}
			#elsif ($result->{'type_analyse'} eq 'MiSeq-121') {$k++;$text .= "<br/>Run Number: $k";$title = "Run $k";}
			#elsif ($result->{'type_analyse'} eq 'MiSeq-3') {$l++;$text .= "<br/>Run Number: $l";$title = "Run $l";}
			#elsif ($result->{'type_analyse'} eq 'MiSeq-132') {$o++;$text .= "<br/>Run Number: $o";$title = "Run $o";}
			#elsif ($result->{'type_analyse'} eq 'MiniSeq-121') {$m++;$text .= "<br/>Run Number: $m";$title = "Run $m";$thumbnail = 'miniseq_thumb.jpg';}
			#elsif ($result->{'type_analyse'} eq 'MiniSeq-132') {$n++;$text .= "<br/>Run Number: $n";$title = "Run $n";$thumbnail = 'miniseq_thumb.jpg';}
			#elsif ($result->{'type_analyse'} eq 'MiniSeq-3') {$p++;$text .= "<br/>Run Number: $p";$title = "Run $p";$thumbnail = 'miniseq_thumb.jpg';}
			#elsif ($result->{'type_analyse'} eq 'NextSeq-ClinicalExome') {$r++;$text .= "<br/>Run Number: $r";$title = "Run $r";$thumbnail = 'nextseq_thumb.jpg';}
			#$text .= "<br/><a href='search_controls.pl?step=3&iv=1&run=$result->{'run_id'}'>Sample tracking</a>";


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
			elsif ($result->{'type_analyse'} eq 'MiniSeq-3') {$p++;}
			elsif ($result->{'type_analyse'} eq 'NextSeq-ClinicalExome') {$r++;}
			elsif ($result->{'type_analyse'} eq 'MiniSeq-2') {$s++;}

			#my $text = "<br/>Analyst: ".ucfirst($result->{'analyste'})."<br/> Run: <a href = 'stats_ngs.pl?run=$result->{'run_id'}' target = '_blank'>$result->{'run_id'}</a>";
			#$dates .= "
			#	{
			#	    \"startDate\":\"$analysis_date\",
			#	    \"endDate\":\"$analysis_date\",
			#	    \"headline\":\"$result->{'type_analyse'} $title\",
			#	    //\"tag\":\"$result->{'type_analyse'}\",
			#	    \"text\":\"<p>$text</p>\",
			#	    \"asset\": {
			#		//\"media\":\"".$HTDOCS_PATH."data/img/$thumbnail\",
			#		\"thumbnail\":\"".$HTDOCS_PATH."data/img/$thumbnail\",
			#	    }
			#	},
			#";

			#text
			#my $subst = '6';
			#if ($result->{'type_analyse'} =~ /Mini/o) {$subst = '8'}

			$content .= $q->start_Tr().
					$q->start_td().
						$q->a({'href' => "stats_ngs.pl?run=$result->{'run_id'}"}, $result->{'run_id'}).
					$q->end_td().
					$q->td($result->{'type_analyse'}." genes");
					#$q->td(substr($result->{'type_analyse'}, $subst)." genes");
			#$ul .= $q->start_li().$q->a({'href' => "stats_ngs.pl?run=$result->{'run_id'}"}, $result->{'run_id'}).$q->span(" - ".substr($result->{'type_analyse'}, 6)." genes");
			#if ($result->{'type_analyse'} eq 'MiSeq-28') {$ul .= " - Run $i";$new_style .= $q->td("Run $i");}
			#elsif ($result->{'type_analyse'} eq 'MiSeq-112') {$ul .= " - Run $j";$new_style .= $q->td("Run $j");}
			#elsif ($result->{'type_analyse'} eq 'MiSeq-121') {$ul .= " - Run $k";$new_style .= $q->td("Run $k");}
			#elsif ($result->{'type_analyse'} eq 'MiSeq-3') {$ul .= " - Run $l";$new_style .= $q->td("Run $l");}
			#elsif ($result->{'type_analyse'} eq 'MiniSeq-121') {$ul .= " - Run $m";$new_style .= $q->td("Run $m");}
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
			elsif ($result->{'type_analyse'} eq 'MiniSeq-3') {$content .= $q->td("Run $p")}
			elsif ($result->{'type_analyse'} eq 'NextSeq-ClinicalExome') {$content .= $q->td("Run $r")}
			elsif ($result->{'type_analyse'} eq 'MiniSeq-2') {$content .= $q->td("Run $s")}
			$content .= $q->td($num_samples->{'a'});
			#$ul .= $q->end_li();
			$content .= $q->end_Tr()
		}
		#$ul .= $q->end_ul();
		$content .= $q->end_tbody().$q->end_table().$q->end_div();

		#$dates .= "
		#],";
		#my $timeline = "
		#storyjs_jsonp_data = {
		#	\"timeline\":
		#	{
		#	    \"headline\":\"".ucfirst($analysis)." Analysis\",
		#	    \"type\":\"default\",
		#	    \"text\":\"<p>$total_runs, $total_samples</p>\",
		#	    \"asset\": {
		#		\"media\":\"$HTDOCS_PATH/data/img/U2.png\",
		#		//\"credit\":\"Credit Name Goes Here\",
		#		\"caption\":\"USHVaM 2 using Timeline JS\"
		#	    },
		#	    $dates
		#	}
		#};
		#\$(\'#patient-timeline\').load(function() {
		#	timeline = createStoryJS({
		#	    type:       'timeline',
		#	    width:      '100%',
		#	    height:     '400',
		#	    source:     storyjs_jsonp_data,
		#	    embed_id:   'patient-timeline',
		#	    font:	'NixieOne-Ledger',
		#	    start_zoom_adjust:	'-1',
		#	    start_at_end:	'true'
		#	});
		#});
		#";


		#$content .= $q->script($timeline).$q->start_div({'id' => 'patient-timeline', 'defer' => 'defer'}).$q->end_div().$q->br().$q->br(), $content;
		#print $q->script($timeline).$q->start_div({'id' => 'patient-timeline'}).$q->end_div().$content;
		#f..timeline.js does not really work with ajax, sthg must remain persistent and it bugs
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
		my %metrics = (#label => cgi param, run type => {1,2} : 1: MSR or LRM; 2: nenufaar, cluster {y,n}, math, float
			'On target %' => ['(cast(ontarget_reads as float)/cast(aligned_reads as float))*100', '1', 'n', 'AVG', '2'],
			'On target reads' => ['ontarget_reads', '1', 'n', 'SUM', '0'],
			'Duplicate reads %' => ['duplicates', '2', 'n', 'AVG', '2'],
			'Mean DoC' => ['mean_doc', '2', 'n', 'AVG', '0'],
			'50X %' => ['fiftyx_doc', '2', 'n', 'AVG', '2'],
			'SNVs' => ['snp_num', '2', 'n', 'AVG', '0'],
			'SNVs Ts/Tv' => ['snp_tstv', '2', 'n', 'AVG', '2'],
			'Indels' => ['indel_num', '1', 'n', 'AVG', '0'],
			'Insert size' => ['insert_size_median', '2', 'n', 'AVG', '0'],
			'Insert size SD' => ['insert_size_sd', '1', 'n', 'AVG', '0'],
			'Raw Clusters' => ['noc_raw', '1', 'y', '', '0'],
			'Usable Clusters %' => ['((noc_pf-(nodc+nouc_pf+nouic_pf))::FLOAT/noc_raw)*100', '1', 'y', '', '0'],
			'Duplicate Clusters %' => ['(nodc::FLOAT/noc_raw)*100', '1', 'y', '', '0'],
			'Unaligned Clusters %' => ['(nouc::FLOAT/noc_raw)*100', '1', 'y', '', '0'],
			'Unindexed Clusters %' => ['(nouic::FLOAT/noc_raw)*100', '1', 'y', '', '0']
		);

		my $metric_tag = 1;
		if ($analysis =~ /$NENUFAAR_ANALYSIS/) {$metric_tag = 2}

		my @colors = ('sand', 'khaki', 'yellow', 'amber', 'orange', 'deep-orange', 'red', 'pink', 'purple', 'deep-purple', 'indigo', 'blue', 'light-blue', 'cyan', 'teal', 'green', 'lime');

		foreach my $key (sort keys(%metrics)) {
			#print "$key - $metrics{$m_label}[0]</br>";
			if ($metric_tag == 2 && $metrics{$key}[1] == 1) {next}
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
	#my $get_label_tag = $analysis;

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

	#Let $q-Wparam('math_type') !!!!!
	my $data = U2_modules::U2_subs_3::get_data($analysis, $pg_row, $q->param('math_type'), $floating_depth, $cluster, $dbh);
	#print $data;
	my @rgb = ('151,187,205', '88,42,114', '10,5,94', '161,34,34', '220,126,0', '170,146,55', '220,188,0', '76,194,0', '38,113,88', '34,103,100');
	my $js = "
		function graph_details() {
			".U2_modules::U2_subs_2::get_js_graph($labels, $data, $rgb[int rand(10)], 'graph')."
		}
	";
	#print $js;
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
	my $round = $q->param('round');
	my $content;
	if ($round == 1) {
		#create table
		$content .= $q->start_div({'class' => 'w3-container w3-center w3-cell-row', 'id' => 'match_container',  'style' => 'width:100%'})."\n".$q->br();
	}
	my ($total_runs, $total_samples) = (U2_modules::U2_subs_3::get_total_runs($analysis, $dbh), U2_modules::U2_subs_3::get_total_samples($analysis, $dbh));
	my $query  = "SELECT AVG(fiftyx_doc) as a, AVG(duplicates) as b, AVG(insert_size_median) as c, AVG(mean_doc) as d, AVG(snp_num) as e, AVG(snp_tstv) AS f FROM miseq_analysis WHERE type_analyse = '$analysis';";
	my $query_size = "WITH tmp AS (SELECT DISTINCT(a.end_g, a.start_g), a.end_g, a.start_g FROM segment a, gene b WHERE a.nom_gene = b.nom AND b.\"$analysis\" = 't' AND a.type = 'exon')\nSELECT SUM(ABS(a.end_g - a.start_g)+100) AS size FROM tmp a;";
	if ($analysis eq 'all') {
		$query  = "SELECT AVG(fiftyx_doc) as a, AVG(duplicates) as b, AVG(insert_size_median) as c, AVG(mean_doc) as d, AVG(snp_num) as e, AVG(snp_tstv) AS f FROM miseq_analysis;";
		$query_size = "WITH tmp AS (SELECT DISTINCT(a.end_g, a.start_g), a.end_g, a.start_g FROM segment a, gene b WHERE a.nom_gene = b.nom AND a.type = 'exon')\nSELECT SUM(ABS(a.end_g - a.start_g)+100) AS size FROM tmp a;";
	}
	elsif ($analysis =~ /Min?i?Seq-[32]$/o) {
		$query_size = "WITH tmp AS (SELECT MIN(LEAST(b.start_g, b.end_g)) as min, MAX(GREATEST(b.start_g, b.end_g)) as max FROM gene a, segment b WHERE a.nom[1] = b.nom_gene[1] AND type LIKE '%UTR' AND a.\"$analysis\" = 't' GROUP BY a.nom[1], a.chr ORDER BY a.chr, min ASC)\nSELECT SUM(max - min) AS size FROM tmp";
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
		#create table
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
	#check if everybody has the same analysis
	my $query_check_analysis = "SELECT COUNT(num_pat) as a FROM miseq_analysis WHERE type_analyse = '$analysis' AND (id_pat || num_pat) IN ('$id$number','$id_father$number_father','$id_mother$number_mother');";
	my $res = $dbh->selectrow_hashref($query_check_analysis);
	if ($res->{'a'} != 3) {print 'Sorry the analyses types for the 3 samples do not match.';exit;}

	my $query = "SELECT nom_c, nom_gene, depth FROM variant2patient WHERE type_analyse  = '$analysis' AND id_pat = '$id' AND num_pat = '$number' AND statut NOT IN ('homozygous', 'heteroplasmic', 'homoplasmic') AND allele = 'unknown';";
	my $sth = $dbh->prepare($query);
	$res = $sth->execute();
	my ($i, $j, $k, $l, $m) = (0, 0, 0, 0, 0);#counter for changing alleles
	my $denovo = '';
	my $content;
	while (my $result = $sth->fetchrow_hashref()) {
		if ($result->{'depth'} > 30) {#if bad coverage in CI, possibly also in parents and error prone
			$l++;
			my $query_assign = "SELECT allele, statut, id_pat, num_pat FROM variant2patient WHERE nom_c = '$result->{'nom_c'}' AND nom_gene = '{$result->{'nom_gene'}[0],$result->{'nom_gene'}[1]}' AND (id_pat || num_pat) IN ('$id_father$number_father', '$id_mother$number_mother') AND  type_analyse  = '$analysis';";
			my $sth_assign = $dbh->prepare($query_assign);
			my $res_assign = $sth_assign->execute();
			if ($res_assign ne '0E0') {
				my $allele = 2;#default mother
				if ($res_assign == 2) {#fat & mot
					#next if both het/hom, if one het one hom => assign to hom
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
							#father
							$allele = 1;
							$j++;
						}
					}
				}
				my $update = "UPDATE variant2patient SET allele = '$allele' WHERE id_pat = '$id' AND num_pat = '$number' AND nom_gene = '{$result->{'nom_gene'}[0],$result->{'nom_gene'}[1]}' AND nom_c = '$result->{'nom_c'}';";
				$dbh->do($update);
				$i++;
				#$content .= $result->{'nom_gene'}[0]." - ".$result->{'nom_gene'}[1]." - ".$result->{'nom_c'}." - ".$allele."\n";
			}
			else {
				#not in mother nor in father
				#denovo?
				#remove neutral from list
				$k++;
				my $query_class = "SELECT classe FROM variant WHERE nom_gene = '{$result->{'nom_gene'}[0],$result->{'nom_gene'}[1]}' AND nom = '$result->{'nom_c'}';";
				my $res_classe = $dbh->selectrow_hashref($query_class);
				#print $res_classe->{'classe'}."\n";
				if ($res_classe->{'classe'} eq 'neutral' || $res_classe->{'classe'} eq 'R8' || $res_classe->{'classe'} eq 'VUCS Class F' || $res_classe->{'classe'} eq 'VUCS Class U' || $res_classe->{'classe'} eq 'artefact') {next}
				$denovo .= $result->{'nom_gene'}[0]." - ".$result->{'nom_gene'}[1]." - ".$result->{'nom_c'}." - ".$res_classe->{'classe'}.$q->br();
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
	if ($q->param ('align_file') =~ /\/var\/www\/html\/ushvam2\/RS_data\/data\//o) {
		my $align_file = $q->param ('align_file');
		my $cov_report_dir = $ABSOLUTE_HTDOCS_PATH.'CovReport/';
		my $cov_report_sh = $cov_report_dir.'covreport.sh';
		print STDERR "cd $cov_report_dir && /bin/sh $cov_report_sh -out $id$number-$analysis-$filter -bam $align_file -bed u2_beds/$analysis.bed -NM u2_genes/$filter.txt -f $filter\n";
		`cd $cov_report_dir && /bin/sh $cov_report_sh -out $id$number-$analysis-$filter -bam $align_file -bed u2_beds/$analysis.bed -NM u2_genes/$filter.txt -f $filter`;

		if (-e $ABSOLUTE_HTDOCS_PATH."CovReport/CovReport/pdf-results/".$id.$number."-".$analysis."-".$filter."_coverage.pdf") {
			print $q->start_span().$q->a({ 'href' => $HTDOCS_PATH."CovReport/CovReport/pdf-results/".$id.$number."-".$analysis."-".$filter."_coverage.pdf", 'target' => '_blank'}, 'Download CovReport').$q->end_span();
			U2_modules::U2_subs_2::send_general_mail($user, "CovReport ready for $id$number-$analysis-$filter", "Hi ".$user->getName().",\nYou can download the CovReport file here:\n$HOME/ushvam2/CovReport/CovReport/pdf-results/$id$number-$analysis-".$filter."_coverage.pdf\n");
			# attempt to trigger autoFS
			open HANDLE, ">>".$ABSOLUTE_HTDOCS_PATH."DS_data/covreport/touch.txt";
			sleep 3;
			close HANDLE;
			mkdir($ABSOLUTE_HTDOCS_PATH."DS_data/covreport/".$id.$number);
			copy($ABSOLUTE_HTDOCS_PATH."CovReport/CovReport/pdf-results/".$id.$number."-".$analysis."-".$filter."_coverage.pdf", $ABSOLUTE_HTDOCS_PATH."DS_data/covreport/".$id.$number) or die $!;
		}
		else {
			print $q->span('Failed to generate coverage file');
			U2_modules::U2_subs_2::send_general_mail($user, "CovReport failed for $id$number-$analysis-$filter\n\n", "Hi ".$user->getName().",\nUnfortunately, your CovReport generation failed. You can forward this message to David for debugging.\n");
		}
	}
	#my $align_file = $q->param ('align_file');

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

#if ($q->param('asked') && $q->param('asked') eq 'covreport') {
#	my ($id, $number) = U2_modules::U2_subs_1::sample2idnum(uc($q->param('sample')), $q);
#	my $analysis = U2_modules::U2_subs_1::check_analysis($q, $dbh, 'filtering');
#	my $filter = U2_modules::U2_subs_1::check_filter($q);
#	open(F, '>'.$ABSOLUTE_HTDOCS_PATH."CovReport/CovReport/pdf-results/".$id.$number."-".$analysis."-".$filter."_coverage.txt") or die $!;
#	print F '1';
#	close F;
#}

sub miseq_details {
	my ($miseq_analysis, $first_name, $last_name, $gene, $acc, $nom_c) = @_;
	$first_name =~ s/'/''/og;
	$last_name =~ s/'/''/og;
	my $query_ngs = "SELECT depth, frequency, msr_filter FROM variant2patient a, patient b WHERE a.num_pat = b.numero AND a.id_pat = b.identifiant AND b.first_name = '$first_name' AND b.last_name = '$last_name' AND  nom_gene[1] = '$gene' AND nom_gene[2] = '$acc' AND nom_c = '$nom_c' AND type_analyse = '$miseq_analysis';";
	my $res_ngs = $dbh->selectrow_hashref($query_ngs);
	#$print_ngs .= "DOC MiSeq: <strong>$res_ngs->{'depth'}</strong> Freq: <strong>$res_ngs->{'frequency'}</strong><br/>MSR filter:<strong>$res_ngs->{'msr_filter'}</strong><br/>";
	return $q->start_li().$q->strong("$miseq_analysis values:").$q->start_ul().$q->start_li().$q->span("DOC: ").$q->strong($res_ngs->{'depth'}).$q->span(" Freq: ").$q->strong($res_ngs->{'frequency'}).$q->end_li().$q->start_li().$q->span("MSR filter: ").$q->strong($res_ngs->{'msr_filter'}).$q->end_li().$q->end_ul().$q->end_li();
}

sub dbnsfp2html {
	my ($dbnsfp, $ref, $alt, $onekg, $espea, $espaa, $exac_maf, $clinvar, $caddraw, $caddphred) = @_;
	foreach (@{$dbnsfp}) {
		my @current = split(/\t/, $_);
		if (($current[2] eq $ref) && ($current[3] eq $alt)) {
			my $text = $q->start_li().
						$q->span({'onclick' => 'window.open(\'http://www.1000genomes.org/about\')', 'class' => 'pointer'}, '1000 genomes').
						$q->span(" AF (allele $alt): ".sprintf('%.4f', $current[$onekg])).
					$q->end_li()."\n".
					$q->start_li().
						$q->span({'onclick' => 'window.open(\'http://evs.gs.washington.edu/EVS/#tabs-6\')', 'class' => 'pointer'}, 'ESP6500').
						$q->span(" EA AF (allele $alt): ".sprintf('%.4f', $current[$espea])).
					$q->end_li()."\n".
					$q->start_li().
						$q->span({'onclick' => 'window.open(\'http://evs.gs.washington.edu/EVS/#tabs-6\')', 'class' => 'pointer'}, 'ESP6500').
						$q->span(" AA AF (allele $alt): ".sprintf('%.4f', $current[$espaa])).
					$q->end_li()."\n".
					$q->start_li().
						$q->span({'onclick' => 'window.open(\'http://exac.broadinstitute.org/\')', 'class' => 'pointer'}, 'ExAC').
						$q->span(" adjusted AF (allele $alt): ".sprintf('%.4f', $current[$exac_maf])).
					$q->end_li()."\n".
					$q->start_li().
						$q->span({'onclick' => 'window.open(\'https://www.ncbi.nlm.nih.gov/clinvar/\')', 'class' => 'pointer'}, 'ClinVar').
						$q->span(" (allele $alt): ".U2_modules::U2_subs_2::dbnsfp_clinvar2text($current[$clinvar])).
					$q->end_li()."\n".
					$q->start_li().
						$q->span({'onclick' => 'window.open(\'http://cadd.gs.washington.edu\')', 'class' => 'pointer'}, 'CADD raw:').
						$q->span(" (allele $alt): ".sprintf('%.4f', $current[$caddraw])).
					$q->end_li()."\n".
					$q->start_li().
						$q->span({'onclick' => 'window.open(\'http://cadd.gs.washington.edu\')', 'class' => 'pointer'}, 'CADD phred:').
						$q->span(" (allele $alt): $current[$caddphred]").
					$q->end_li()."\n";
			return $text
		}
	}
}

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
