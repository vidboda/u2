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
use U2_modules::U2_users_1;
use SOAP::Lite;
use File::Temp qw/ :seekable /;
use List::Util qw(min max);
#use IPC::Open2;
#use Data::Dumper;
use URI::Escape;
use LWP::UserAgent;
use Net::Ping;


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
my $DB_USER = $config->DB_USER();
my $DB_PASSWORD = $config->DB_PASSWORD();
my $HTDOCS_PATH = $config->HTDOCS_PATH();
my $ABSOLUTE_HTDOCS_PATH = $config->ABSOLUTE_HTDOCS_PATH();
my $DATABASES_PATH = $config->DATABASES_PATH();
my $DALLIANCE_DATA_DIR_PATH = $config->DALLIANCE_DATA_DIR_PATH();
my $EXE_PATH = $config->EXE_PATH();

my $dbh = DBI->connect(    "DBI:Pg:database=$DB;host=$HOST;",
                        $DB_USER,
                        $DB_PASSWORD,
                        {'RaiseError' => 1}
                ) or die $DBI::errstr;

my $q = new CGI;





if ($q->param('asked') && $q->param('asked') eq 'exons') {
	print $q->header();
	my ($gene, $second_name) = U2_modules::U2_subs_1::check_gene($q, $dbh);
	my $query = "SELECT a.nom as name, a.numero as number FROM segment a, gene b WHERE a.nom_gene = b.nom AND a.nom_gene[1] = '$gene' AND b.main = 't' AND a.type <> 'intron';";
	my $sth = $dbh->prepare($query);
	my $res = $sth->execute();
	my ($labels, @values);
	while (my $result = $sth->fetchrow_hashref()) {
		$labels->{$result->{'number'}} = $result->{'name'};
		push @values, $result->{'number'};
	}
	print $q->popup_menu(-name => 'exons', -id => 'exons', -values => \@values, -labels => $labels);
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
	
	
	
	
	
	###NEW style using VEP 4 TGP and ESP
	my $query = "SELECT a.nom, a.nom_gene[1] as gene, a.nom_gene[2] as acc, b.dfn, b.usher FROM variant a, gene b WHERE a.nom_gene = b.nom AND a.nom_g = '$variant';";
	my $res = $dbh->selectrow_hashref($query);
	my ($text, $semaph) = ($q->start_ul(), 0);#$q->strong('MAFs &amp; databases:').
	my $tempfile = File::Temp->new(UNLINK => 1);
	
	my $network = 'offline';
	#my $version = 78;
	my $chr = my $position = my $ref = my $alt = '';
	if ($variant =~ /chr([\dXY]+):g\.(\d+)([ATGC])>([ATGC])/o) {print $tempfile "$1 $2 $2 $3/$4 +\n";$chr = $1; $position = $2; $ref = $3;$alt = $4;}
	elsif ($variant =~ /chr(.+)$/o) {print $tempfile "$1\n";$network = 'port 3337';}
	else {print "pb with variant $variant with VEP"}
	#my ($chr, $pos1, $wt, $mt) = ($1, $2, $3, $4);
	#print $tempfile "$chr $pos1 $pos1 $wt/$mt +\n";
	#print $tempfile "$1 $2 $2 $3/$4 +\n";
	#$variant =~ /chr(.+)$/o;	
	#print $tempfile "$1\n";
	if ($tempfile->filename() =~ /(\/tmp\/\w+)/o) {
		delete $ENV{PATH};
		#my @results = split('\n', `$DATABASES_PATH/variant_effect_predictor/variant_effect_predictor.pl --fasta $DATABASES_PATH/.vep/homo_sapiens/75/Homo_sapiens.GRCh37.75.dna.primary_assembly.fa --cache --compress "gunzip -c" --gmaf --maf_esp --refseq --no_progress -q --fork 4 --no_stats --dir $DATABASES_PATH/.vep/ --force -i $1 -o STDOUT`); ###VEP75
		
		my @results = split('\n', `$DATABASES_PATH/variant_effect_predictor_81/variant_effect_predictor.pl --fasta $DATABASES_PATH/.vep/homo_sapiens/75/Homo_sapiens.GRCh37.75.dna.primary_assembly.fa --$network --cache --compress "gunzip -c" --gmaf --maf_esp --refseq --no_progress -q --fork 4 --no_stats --dir $DATABASES_PATH/.vep/ --force -i $1 --plugin ExAC,$DALLIANCE_DATA_DIR_PATH/exac/ExAC.r0.3.sites.vep.vcf.gz --plugin CADD,$DATABASES_PATH/CADD/whole_genome_SNVs.tsv.gz,$DATABASES_PATH/CADD/InDels.tsv.gz  -o STDOUT`); ###VEP81;
		#for unknwon reasons VEP78 does not work anymore with indels (error) and VEP 81 with substitutions (does not retrieve gmaf esp_maf) - FINALLY works with assembly v75
		
		#if ($version == 78) {
		#	@results = split('\n', `$DATABASES_PATH/variant_effect_predictor_78/variant_effect_predictor.pl --fasta $DATABASES_PATH/.vep/homo_sapiens/75/Homo_sapiens.GRCh37.75.dna.primary_assembly.fa --$network --cache --compress "gunzip -c" --gmaf --maf_esp --refseq --no_progress -q --fork 4 --no_stats --dir $DATABASES_PATH/.vep/ --force -i $1 --plugin ExAC,$DALLIANCE_DATA_DIR_PATH/exac/ExAC.r0.3.sites.vep.vcf.gz -o STDOUT`); ###VEP78
		#}
		#else {
		#	@results = split('\n', `$DATABASES_PATH/variant_effect_predictor_81/variant_effect_predictor.pl --fasta $DATABASES_PATH/.vep/homo_sapiens/75/Homo_sapiens.GRCh37.75.dna.primary_assembly.fa --$network --cache --compress "gunzip -c" --gmaf --maf_esp --refseq --no_progress -q --fork 4 --no_stats --dir $DATABASES_PATH/.vep/ --force -i $1 --plugin ExAC,$DALLIANCE_DATA_DIR_PATH/exac/ExAC.r0.3.sites.vep.vcf.gz -o STDOUT`); ###VEP81
		#	
		#}
		
		if ($res->{'acc'} =~ /(N[MR]_\d+)/o) {		
				my @good_line = grep(/$1/, @results);
				my $not_good_alt = 0;
				#print "--$alt--";
				if ($good_line[0] =~ /GMAF=([ATCG-]+):([\d\.]+);*/o) {
					my ($nuc, $score) = ($1, $2);
					#print $q->li("$nuc $ref $alt");
					#if (($ref ne '' && (($nuc =~ /[ATGC]/o && $nuc eq $alt) || ($nuc =~ /[ATGC]/o && $nuc eq $ref))) || ($nuc !~ /[ATGC]/o)) {
					#if (($ref ne '' && ($nuc =~ /[ATGC]/o  && ($nuc eq $alt || $nuc eq $ref))) || ($nuc !~ /[ATGC]/o)) {
					if (($network eq 'offline' && ($nuc eq $alt || $nuc eq $ref)) || ($network eq 'port 3337')) {
						$text .= $q->start_li().$q->span({'onclick' => 'window.open(\'http://www.1000genomes.org/about\')', 'class' => 'pointer'}, '1000 genomes').$q->span(" phase 1 AF (allele $nuc): $score").$q->end_li();$semaph = 1;
					}
					else {$not_good_alt = 1}
				}
				if ($good_line[0] =~ /EA_MAF=([ATCG-]+):([\d\.]+);*/o) {
					my ($nuc, $score) = ($1, $2);
					#if (($ref ne '' && (($nuc =~ /[ATGC]/o && $nuc eq $alt) || ($nuc =~ /[ATGC]/o && $nuc eq $ref))) || ($nuc !~ /[ATGC]/o)) {
					if (($network eq 'offline' && ($nuc eq $alt || $nuc eq $ref)) || ($network eq 'port 3337')) {
						$text .= $q->start_li().$q->span({'onclick' => 'window.open(\'http://evs.gs.washington.edu/EVS/#tabs-6\')', 'class' => 'pointer'}, 'ESP6500').$q->span("  EA AF (allele $nuc): ".sprintf('%.4f', $score)).$q->end_li();$semaph = 1;
					}
					else {$not_good_alt = 1}
				}
				if ($good_line[0] =~ /AA_MAF=([ATCG-]+):([\d\.]+);*/o) {
					my ($nuc, $score) = ($1, $2);
					#if (($ref ne '' && (($nuc =~ /[ATGC]/o && $nuc eq $alt) || ($nuc =~ /[ATGC]/o && $nuc eq $ref))) || ($nuc !~ /[ATGC]/o)) {
					if (($network eq 'offline' && ($nuc eq $alt || $nuc eq $ref)) || ($network eq 'port 3337')) {
						$text .= $q->start_li().$q->span({'onclick' => 'window.open(\'http://evs.gs.washington.edu/EVS/#tabs-6\')', 'class' => 'pointer'}, 'ESP6500').$q->span("  AA AF (allele $nuc): ".sprintf('%.4f', $score)).$q->end_li();$semaph = 1;
					}
					else {$not_good_alt = 1}
				}
				if ($good_line[0] =~ /ExAC_AF=([\d\.e-]+);*/o) {if ($not_good_alt == 0) {$text .= $q->start_li().$q->span({'onclick' => 'window.open(\'http://exac.broadinstitute.org/\')', 'class' => 'pointer'}, 'ExAC').$q->span(" AF: $1").$q->end_li();$semaph = 1;}}
				if ($good_line[0] =~ /CLIN_SIG=(\w+)/o) {if ($not_good_alt == 0) {$text .= $q->start_li().$q->span({'onclick' => 'window.open(\'http://www.ncbi.nlm.nih.gov/SNP/\')', 'class' => 'pointer'}, 'Clinical significance (dbSNP): ').$q->span($1).$q->end_li();}}
				if ($good_line[0] =~ /CADD_RAW=([\d\.]+)/o) {if ($not_good_alt == 0) {$text .= $q->start_li().$q->span({'onclick' => 'window.open(\'http://cadd.gs.washington.edu/\')', 'class' => 'pointer'}, 'CADD raw: ').$q->span($1).$q->end_li();}}
				if ($good_line[0] =~ /CADD_PHRED=(\d+)/o) {if ($not_good_alt == 0) {$text .= $q->start_li().$q->span({'onclick' => 'window.open(\'http://cadd.gs.washington.edu/\')', 'class' => 'pointer'}, 'CADD PHRED: ').$q->span($1).$q->end_li();}}
				#print $q->li($good_line[0]);
		}
		else {$text .= $q->li("$res->{'acc'} not matching.");$semaph = 1;}
		#MCAP results for missense
		#if ($variant =~ /chr([\dXY]+):g\.(\d+)([ATGC])>([ATGC])/o) {
		#	my ($chr, $pos, $ref, $alt) = ($1, $2, $3, $4);
		#	my @mcap =  split(/\n/, `$EXE_PATH/tabix $DATABASES_PATH/mcap/mcap_v1_0.txt.gz $chr:$pos-$pos`);
		#	foreach (@mcap) {
		#		my @current = split(/\t/, $_);
		#		if (/\t$ref\t$alt\t/) {
		#			$text .= $q->start_li().$q->span({'onclick' => 'window.open(\'http://bejerano.stanford.edu/mcap/\')', 'class' => 'pointer'}, 'M-CAP score: '.sprintf('%.4f', $current[4])).$q->end_li(), "\n";
		#		}
		#	}
		#}
		if ($#results == -1) {
			print "There may be an issue with port 3337 of Ensembl server mandatory for indel analysis. Please retry later.";
			$semaph = 1;
		}
		#print $#results;
		#foreach(@results) {print "$_<br/>"}
	}	
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
	if ($chr ne '') {
		$chr =~ s/chr//og;
		my @gnomad =  split(/\n/, `$EXE_PATH/tabix $DATABASES_PATH/gnomad/hg19_gnomad_exome_sorted.txt.gz $chr:$position-$position`);
		foreach (@gnomad) {
			my @current = split(/\t/, $_);
			if (/\t$ref\t$alt\t/) {
				#my $af = $current[5];
				$text .= $q->start_li().$q->span({'onclick' => 'window.open(\'http://gnomad.broadinstitute.org/\')', 'class' => 'pointer'}, 'gnomAD Exome').$q->span(" AF: $current[5]").$q->span().$q->end_li()."\n";
			}
		}
		@gnomad =  split(/\n/, `$EXE_PATH/tabix $DATABASES_PATH/gnomad/hg19_gnomad_genome_sorted.txt.gz $chr:$position-$position`);
		foreach (@gnomad) {
			my @current = split(/\t/, $_);
			if (/\t$ref\t$alt\t/) {
				#my $af = $current[5];
				$text .= $q->start_li().$q->span({'onclick' => 'window.open(\'http://gnomad.broadinstitute.org/\')', 'class' => 'pointer'}, 'gnomAD Genome').$q->span(" AF: $current[5]").$q->span().$q->end_li()."\n";
			}
		}
	}
	
	if ($semaph == 0) {$text .= $q->li('No MAF retrieved.')}
	
	
	
	
	
	####TEMP COMMENT connexion to DVD really slow comment for the moment
	my $url = 'http://vvd.eng.uiowa.edu';
	if ($res->{'dfn'} == 1 || $res->{'usher'} == 1) {$url = 'http://deafnessvariationdatabase.org'}#OtoDB university of Iowa deafness and usher genes  
		#ping dvd to ensure host is reachable
		#my $p = Net::Ping->new("tcp", 2);
		#$text.= "ping ".$p->ping('deafnessvariationdatabase.org');
		#if ($p->ping('deafnessvariationdatabase.org')) {
			#$text.= 'ping ok';
			my ($chr, $pos) = U2_modules::U2_subs_1::extract_pos_from_genomic($variant, 'clinvar');#clinvar style but for OtoDB!!
			my $var = $res->{'nom'};
			$var =~ s/\+/\\\+/og;
			$var =~ s/\./\\\./og;
			my $ua = new LWP::UserAgent();
			my $response = $ua->get("$url/api?terms=chr$chr:$pos");
			#http://vvd.eng.uiowa.edu/api?terms=chr1:94461749
			#print $response->decoded_content();
			if ($response->is_success()) {
				my @dvd = split(/\n/, $response->decoded_content());
				my @good_line = grep (/$var/, @dvd);
				#print "$dvd[0]-$var";
				my @split_dvd = split(/\t/, $good_line[0]);
				if ($split_dvd[57] && $split_dvd[57] ne 'NULL') {$text .= $q->start_li().$q->span({'onclick' => "window.open('$url/sources')", 'class' => 'pointer'}, 'OtoDB').$q->span(" MAF: $split_dvd[57]").$q->end_li()} #otoscope_all_af
				#print $split_dvd[0];
				if ($split_dvd[0] && $split_dvd[0] =~ /(\d+)/o) {$text .= $q->start_li().$q->a({'href' => "$url/variant/$1?full", 'target' => '_blank'}, 'Iowa DB full description').$q->end_li()}
			}
			#else {print $response}
		#}
		#$p->close();
	#}
	####END TEMP COMMENT
	
	
	#then we add LOVD here!!!
	#print $text;exit;
	
	my ($evs_chr, $evs_pos_start, $evs_pos_end) = U2_modules::U2_subs_1::extract_pos_from_genomic($variant, 'evs');
	
	my $url = "http://www.lovd.nl/search.php?build=hg19&position=chr$evs_chr:".$evs_pos_start."_".$evs_pos_end;
	#print $url;
	my $ua = new LWP::UserAgent();
	$ua->timeout(10);
	my $response = $ua->get($url);
	
	
	
	#c.13811+2T>G
	#"hg_build"	"g_position"	"gene_id"	"nm_accession"	"DNA"	"variant_id"	"url"
	#"hg19"	"chr1:215847440"	"USH2A"	"NM_206933.2"	"c.13811+2T>G"	"USH2A_00751"	"https://grenada.lumc.nl/LOVD2/Usher_montpellier/variants.php?select_db=USH2A&action=search_all&search_Variant%2FDBID=USH2A_00751"
	#my $response = $ua->request($req);https://grenada.lumc.nl/LOVD2/Usher_montpellier/variants.php?select_db=MYO7A&action=search_all&search_Variant%2FDBID=MYO7A_00018
	my $lovd_semaph = 0;
	if($response->is_success()) {
		my $escape_var = $res->{'nom'};
		$escape_var =~ s/\+/\\\+/og;
		#if ($response->decoded_content() =~ /"$escape_var".+"(https[^"]+Usher_montpellier\/[^"]+)"/g) {$text .= $q->start_li().$q->a({'href' => $1, 'target' => '_blank'}, 'LOVD USHbases').$q->end_li();}
		#if ($response->decoded_content() =~ /"(https:\/\/grenada\.lumc\.nl\/LOVD2\/Usher_montpellier\/[^"]+)"$/o) {print $q->start_a({'href' => $1, 'target' => '_blank'}), $q->img({'src' => $HTDOCS_PATH.'data/img/buttons/LOVD_button.png'}), $q->end_a();}
		#elsif ($response->decoded_content() =~ /"$escape_var".+"(http[^"]+shared\/[^"]+)"/g) {$text .= $q->start_li().$q->a({'href' => $1, 'target' => '_blank'}, 'LOVD').$q->end_li();}
		if ($response->decoded_content() =~ /"$escape_var".+"(http[^"]+)"/g) {
			my @matches = $response->decoded_content() =~ /"$escape_var".+"(http[^"]+)"/g;
			$text .= $q->start_li().$q->strong('LOVD matches: ').$q->start_ul();
			my $i = 1;
			foreach (@matches) {
				if ($_ =~ /https.+Usher_montpellier\//g) {$text .= $q->start_li().$q->a({'href' => $_, 'target' => '_blank'}, 'LOVD USHbases').$q->end_li()}
				elsif ($_ =~ /http.+databases\.lovd\.nl\/shared\//g) {$text .= $q->start_li().$q->a({'href' => $_, 'target' => '_blank'}, 'LOVD3 shared').$q->end_li()}
				elsif ($_ =~ /http.+databases\.lovd\.nl\/whole_genome\//g) {$text .= $q->start_li().$q->a({'href' => $_, 'target' => '_blank'}, 'LOVD3 whole genome').$q->end_li()}
				else {$text .= $q->start_li().$q->a({'href' => $_, 'target' => '_blank'}, "Link $i").$q->end_li();$i++;}
			}
			$text .= $q->end_ul().$q->end_li();
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
			$text .= $q->start_li().$q->a({'href' => "https://grenada.lumc.nl/LOVD2/Usher_montpellier/variants.php?select_db=$res->{'gene'}&action=search_unique&order=Variant%2FDNA%2CASC&hide_col=&show_col=&limit=100&search_Variant%2FLocation=&search_Variant%2FExon=&search_Variant%2FDNA=$pos_cdna&search_Variant%2FRNA=&search_Variant%2FProtein=&search_Variant%2FDomain=&search_Variant%2FInheritance=&search_Variant%2FRemarks=&search_Variant%2FReference=&search_Variant%2FRestriction_site=&search_Variant%2FFrequency=&search_Variant%2FDBID=", 'target' => '_blank'}, 'LOVD USHbases?').$q->end_li();
		}
		else {
			$text .= $q->start_li().$q->a({'href' => "http://grenada.lumc.nl/LSDB_list/lsdbs/$res->{'gene'}", 'target' => '_blank'}, 'LOVD?').$q->end_li();
		}
	}
	
	$text .= $q->end_ul();
	print $text;
	###END NEW style using VEP
}
if ($q->param('asked') && $q->param('asked') eq 'class') {
	print $q->header();
	my $variant = U2_modules::U2_subs_1::check_nom_c($q, $dbh);
	my ($gene, $second_name) = U2_modules::U2_subs_1::check_gene($q, $dbh);
	my $acc = U2_modules::U2_subs_1::check_acc($q, $dbh);
	my $class = U2_modules::U2_subs_1::check_class($q, $dbh);
	my $update = "UPDATE variant SET classe = '$class' WHERE nom = '$variant' AND nom_gene = '{\"$gene\", \"$acc\"}';";
	#print $update;
	$dbh->do($update);
	#print ($class, U2_modules::U2_subs_1::color_by_classe($class, $dbh));
}
if ($q->param('asked') && $q->param('asked') eq 'var_nom') {
	print $q->header();
	#my ($variant, $main, $nom_c);
	my $i = 0;
	#if ($q->param('nom_g') =~ /(chr[\dXY]+:g\..+)/o) {$variant = $1}
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
	#print 'AJAX!!!!';
	# gene: '$gene', accession: '$acc', nom_c: '$var->{'nom'}', analysis_all: '$type_analyse', depth: '$var->{'depth'}', current_analysis: '$var->{'type_analyse'}, frequency: '$var->{'frequency'}', wt_f: '$var->{'wt_f'}', wt_r: '$var->{'wt_r'}, mt_f: '$var->{'mt_f'}, mt_r: '$var->{'mt_r'}, last_name: '$var->{'last_name'}', first_name: '$var->{'first_name'}', msr_filter: '$var->{'msr_filter'}', nb: '$nb'
	my ($gene, $second, $acc, $nom_c, $analyses, $current_analysis, $depth, $frequency, $wt_f, $wt_r, $mt_f, $mt_r, $msr_filter, $last_name, $first_name, $nb) = (U2_modules::U2_subs_1::check_gene($q, $dbh), U2_modules::U2_subs_1::check_acc($q, $dbh), U2_modules::U2_subs_1::check_nom_c($q, $dbh), $q->param('analysis_all'), $q->param('current_analysis'), $q->param('depth'), $q->param('frequency'), $q->param('wt_f'), $q->param('wt_r'), $q->param('mt_f'), $q->param('mt_r'), $q->param('msr_filter'), $q->param('last_name'), $q->param('first_name'), $q->param('nb'));
	
	my $info = $q->start_ul().$q->start_li().$q->start_strong().$q->em("$gene:").$q->span($nom_c).$q->end_strong().$q->end_li().$q->br();
	
	#MAFs
	my ($MAF, $maf_454, $maf_sanger, $maf_miseq) = ('NA', 'NA', 'NA', 'NA');
	#if ($var->{'type_analyse'} eq 'NGS-454') { 
	#MAF 454
	$maf_454 = U2_modules::U2_subs_1::maf($dbh, $gene, $acc, $nom_c, '454-\d+');
	#MAF SANGER
	$maf_sanger = U2_modules::U2_subs_1::maf($dbh, $gene, $acc, $nom_c, 'SANGER');
	#MAF MiSeq
	$maf_miseq = U2_modules::U2_subs_1::maf($dbh, $gene, $acc, $nom_c, 'MiSeq-\d+');
	my $maf_url = "MAF 454: $maf_454 / MAF Sanger: $maf_sanger / MAF MiSeq: $maf_miseq";
	#$MAF = "MAF 454: <strong>$maf_454</strong> / MAF Sanger: <strong>$maf_sanger</strong><br/>MAF MiSeq: <strong>$maf_miseq</strong>";
	$MAF = $q->start_li().$q->span("MAF 454: ").$q->strong($maf_454).$q->end_li().$q->start_li().$q->span("MAF Sanger: ").$q->strong($maf_sanger).$q->end_li().$q->start_li().$q->span("MAF MiSeq: ").$q->strong($maf_miseq).$q->end_li();
	#454-USH2A for only a few patients
	my $maf_454_ush2a = '';
	if ($gene eq 'USH2A' && $analyses =~ /454-USH2A/o) {
		$maf_454_ush2a = U2_modules::U2_subs_1::maf($dbh, $gene, $acc, $nom_c, '454-USH2A');
		$maf_url = "MAF 454-USH2A: $maf_454_ush2a / $maf_url";
		#$MAF = "MAF 454-USH2A: <strong>$maf_454_ush2a</strong><br/>$MAF";
		$MAF .= $q->li("MAF 454-USH2A: $maf_454_ush2a");
	}
	$info .= $q->start_li().$q->strong("MAFs:").$q->start_ul().$MAF.$q->end_ul().$q->end_li();
	#print $MAF;
	
	my $print_ngs = '';
	if ($depth) {
		#$info .= "--$current_analysis--";
		if ($current_analysis =~ /454-/o) {
			#$print_ngs = "DOC 454: <strong>$depth</strong> Freq: <strong> $frequency</strong><br/>wt f: $wt_f, wt r: $wt_r<br/>mt f: $mt_f, mt r: $mt_r<br/>";
			$info .= $q->start_li().$q->strong("$current_analysis values:").$q->start_ul().$q->start_li().$q->span("DOC: ").$q->strong($depth).$q->span(" Freq: ").$q->strong($frequency).$q->end_li().$q->start_li().$q->span("wt f: ").$q->strong($wt_f).$q->span(", wt r: ").$q->strong($wt_r).$q->end_li().$q->start_li().$q->span("mt f: ").$q->strong($mt_f).$q->span(", mt r: ").$q->strong($mt_r).$q->end_li().$q->end_ul().$q->end_li();
			#check if MiSeq also??
			if ($analyses =~ /Min?i?Seq-\d+/o) {
				my @matches = $analyses =~ /(Min?i?Seq-\d+)/og;
				foreach (@matches) {
					$info .= &miseq_details($_, $first_name, $last_name, $gene, $acc, $nom_c);
					#my $query_ngs = "SELECT depth, frequency, msr_filter FROM variant2patient a, patient b WHERE a.num_pat = b.numero AND a.id_pat = b.identifiant AND b.first_name = '$first_name' AND b.last_name = '$last_name' AND  nom_gene[1] = '$gene' AND nom_gene[2] = '$acc' AND nom_c = '$nom_c' AND type_analyse = '$_';";
					#my $res_ngs = $dbh->selectrow_hashref($query_ngs);
					##$print_ngs .= "DOC MiSeq: <strong>$res_ngs->{'depth'}</strong> Freq: <strong>$res_ngs->{'frequency'}</strong><br/>MSR filter:<strong>$res_ngs->{'msr_filter'}</strong><br/>";
					#$info .= $q->start_li().$q->strong("$_ values:").$q->start_ul().$q->start_li().$q->span("DOC: ").$q->strong($res_ngs->{'depth'}).$q->span(" Freq: ").$q->strong($res_ngs->{'frequency'}).$q->end_li().$q->start_li().$q->span("MSR filter: ").$q->strong($res_ngs->{'msr_filter'}).$q->end_li().$q->end_ul().$q->end_li();
				}
			}
			
		}
		if ($current_analysis =~ /Min?i?Seq-/o) {
			#$print_ngs = "DOC MiSeq: <strong>$depth</strong> Freq: <strong>$frequency</strong><br/>MSR filter:<strong>$msr_filter</strong><br/>";
			$info .= $q->start_li().$q->strong("$current_analysis values:").$q->start_ul().$q->start_li().$q->span("DOC: ").$q->strong($depth).$q->span(" Freq: ").$q->strong($frequency).$q->end_li().$q->start_li().$q->span("MSR filter: ").$q->strong($msr_filter).$q->end_li().$q->end_ul().$q->end_li();
			my @matches = $analyses =~ /(Min?i?Seq-\d+)/og;
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
	my ($i, $j) = (0, 0);
	
	my $var_g = U2_modules::U2_subs_1::check_nom_g($q, $dbh);
	if ($var_g =~ /chr([\dXY]+):g\.(\d+)([ATGC])>([ATGC])/o) {
		my ($chr, $pos1, $wt, $mt) = ($1, $2, $3, $4);
		#my $tempfile = File::Temp->new(UNLINK => 0);
		my $tempfile = File::Temp->new();
		
		#open(F, '>'.$DATABASES_PATH.'variant_effect_predictor/input.txt') or die $!;
		#print F "$1 $2 $2 $3/$4 +\n";
		#close F;
		
		print $tempfile "$chr $pos1 $pos1 $wt/$mt +\n";
		if ($tempfile->filename() =~ /(\/tmp\/\w+)/o) {
			#http://www.nada.kth.se/~esjolund/writing-more-secure-perl-cgi-scripts/output/writing-more-secure-perl-cgi-scripts.html.utf8  run vep without tempfile not working don't know why
			#my($child_out, $child_in);
			#$pid = open2($child_out, $child_in, "/home/esjolund/public_html/cgi-bin/count.py", $type,"/dev/stdin");
			#print $child_in $content;
			#close($child_in);
			#my $result=<$child_out>;  
			#waitpid($pid,0);
			#print $q->li($result);
			#my @results = split('\n', $result);
			#print $q->li($ENV{PATH});
			delete $ENV{PATH};
			
			#my @results = split('\n', `$DATABASES_PATH/variant_effect_predictor/variant_effect_predictor.pl --fasta $DATABASES_PATH/.vep/homo_sapiens/75/Homo_sapiens.GRCh37.75.dna.primary_assembly.fa --offline --cache --compress "gunzip -c" --polyphen b --sift b --refseq --no_progress -q --fork 4 --no_stats --dir $DATABASES_PATH/.vep/ --force --filter coding_change -i $1 -o STDOUT`);   ###VEP75
			my @results = split('\n', `$DATABASES_PATH/variant_effect_predictor_78/variant_effect_predictor.pl --fasta $DATABASES_PATH/.vep/homo_sapiens/75/Homo_sapiens.GRCh37.75.dna.primary_assembly.fa --offline --cache --compress "gunzip -c" --maf_esp --polyphen b --sift b --refseq --no_progress -q --fork 4 --no_stats --dir $DATABASES_PATH/.vep/ --force --filter coding_change -i $1 --plugin FATHMM,"python $DATABASES_PATH/.vep/Plugins/fathmm.py" --plugin ExAC,$DALLIANCE_DATA_DIR_PATH/exac/ExAC.r0.3.sites.vep.vcf.gz -o STDOUT`);  ##VEP 78 Grch37
			#print $q->li("$DATABASES_PATH/variant_effect_predictor_78/variant_effect_predictor.pl --fasta $DATABASES_PATH/.vep/homo_sapiens/78_GRCh37/Homo_sapiens.GRCh37.75.dna.primary_assembly.fa --offline --cache --compress \"gunzip -c\" --polyphen b --sift b --refseq --maf_esp --no_progress -q --fork 4 --no_stats --dir $DATABASES_PATH/.vep/ --force --filter coding_change -i $1 --plugin FATHMM,\"python $DATABASES_PATH/.vep/Plugins/fathmm.py\" -o STDOUT");
			if ($q->param('acc_no') =~ /(NM_\d+)/o) {		
				my @good_line = grep(/$1/, @results);
				my $space_var = $chr.'_'.$pos1.'_'.$wt.'/'.$mt;
				#print $space_var;
				my @results_split = split(/\s/, $good_line[0]);
				#if ($good_line[0] =~ /$space_var/o) { sometimes does not work even by escaping / 
				if ($results_split[0] eq $space_var) {				
					if ($good_line[0] =~ /SIFT=([^\)]+\))/o) {
						$text .= $q->start_li().$q->span({'onclick' => 'window.open("http://sift.bii.a-star.edu.sg/");', 'target' => '_blank', 'class' => 'pointer'}, 'SIFT').$q->span(' score: ').$q->span({'style' => 'color:'.U2_modules::U2_subs_1::sift_color2($1)}, $1).$q->end_li()."\n";
						if (U2_modules::U2_subs_1::sift_color2($1) eq '#FF0000') {$i++}
						$j++;
					}
					else {$text .= $q->li("No SIFT for this position.")}
					if ($good_line[0] =~ /PolyPhen=([\w\d\(\)\.^\)]+\))/o) {
						$text .= $q->start_li().$q->span({'onclick' => 'window.open("http://genetics.bwh.harvard.edu/pph2/");', 'target' => '_blank', 'class' => 'pointer'}, 'PolyPhen2').$q->span(' score: ').$q->span({'style' => 'color:'.U2_modules::U2_subs_1::pph2_color($1)}, $1).$q->end_li()."\n";
						if (U2_modules::U2_subs_1::pph2_color($1) eq '#FF0000') {$i++}
						$j++;
					}
					else {
						$text .= $q->li("No Polyphen for this position.")#.$q->start_li().$q->span('Complete VEP output:').$q->start_ul();
						#foreach (@results) {$text .= $q->li($_)}
						#$text .= $q->end_ul().$q->end_li();
					}
					if ($good_line[0] =~ /FATHMM=([\d\.-]+)\(/o) {
						$text .= $q->start_li().$q->span({'onclick' => 'window.open("http://fathmm.biocompute.org.uk/");', 'target' => '_blank', 'class' => 'pointer'}, 'FATHMM').$q->span(' score: ').$q->span({'style' => 'color:'.U2_modules::U2_subs_1::fathmm_color($1)}, $1).$q->end_li()."\n";
						if (U2_modules::U2_subs_1::fathmm_color($1) eq '#FF0000') {$i++}
						$j++;
					}
					
					#ESP replaced with ExAC 07/27/2015
					
					my $ea_maf = my $aa_maf = my $exac_maf = -1;
					if ($good_line[0] =~ /EA_MAF=[ATCG-]+:([\d\.]+);*/o) {$ea_maf = $1}
					if ($good_line[0] =~ /AA_MAF=[ATCG-]+:([\d\.]+);*/o) {$aa_maf = $1}
					#my $max_maf = $ea_maf;
					#if ($aa_maf > $max_maf) {$max_maf = $aa_maf}
					#my $maf;
					if ($good_line[0] =~ /ExAC_AF=([\d\.e-]+);*/) {$exac_maf = $1}
					
					if (max($ea_maf, $aa_maf, $exac_maf) > -1) {
						$j++;
						if (max($ea_maf, $aa_maf, $exac_maf) < 0.005) {$i++}
					}
										
					if ($good_line[0] =~ /CLIN_SIG=(\w+)/o) {
						if ($1 =~ /pathogenic/o) {$i++}
						$j++;
					}
					
					#MCAP results for missense
					my @mcap =  split(/\n/, `$EXE_PATH/tabix $DATABASES_PATH/mcap/mcap_v1_0.txt.gz $chr:$pos1-$pos1`);
					foreach (@mcap) {
						my @current = split(/\t/, $_);
						if (/\t$wt\t$mt\t/) {
							$text .= $q->start_li().$q->span({'onclick' => 'window.open(\'http://bejerano.stanford.edu/mcap/\')', 'class' => 'pointer'}, 'M-CAP').$q->span(' score: ').$q->span({'style' => 'color:'.U2_modules::U2_subs_1::mcap_color($current[4])}, sprintf('%.4f', $current[4])).$q->end_li()."\n";
							if (U2_modules::U2_subs_1::mcap_color($current[4]) eq '#FF0000') {$i++}
							$j++;
						}
					}
					
					my ($ratio, $class) = (0, 'one_quarter');
					if ($j != 0) {
						$ratio = sprintf('%.2f', ($i)/($j));
						if ($ratio >= 0.25 && $ratio < 0.5) {$class = 'two_quarter'}
						elsif ($ratio >= 0.5 && $ratio < 0.75) {$class = 'three_quarter'}
						elsif ($ratio >= 0.75) {$class = 'four_quarter'}
						
						$text .= $q->start_li().$q->span({'class' => $class}, 'U2 experimental pathogenic ratio: ').$q->span({'class' => $class}, "$ratio, ($i/$j)").$q->end_li();
					}
					
					#$text .= $q->li($good_line[0]);
				}
				else {
					#$text .= $q->li("variant '$space_var' not found in VEP results:\n '$results_split[0]'");
					$text .= $q->li("variant '$space_var' not found in VEP results:").$q->start_li().$q->span('Complete VEP output:').$q->start_ul();
					foreach (@results) {$text .= $q->li($_)}
					$text .= $q->end_ul().$q->end_li();
				}
			}
		}
		else {$text .= $q->li("Predictors not run because of a security issue. Please report.")}
	}
	
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
	my ($type, $nom, $num_seg, $order);
	if ($q->param('type') && $q->param('type') =~ /(exon|intron|5UTR|3UTR)/o) {$type = $1}
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
	print $html;
}


if ($q->param('asked') && $q->param('asked') eq 'var_all') {
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
	
	#$query = "WITH tmp AS (SELECT DISTINCT(a.nom_c, a.num_pat, a.id_pat, a.nom_gene), a.nom_c, a.nom_gene FROM variant2patient a, variant b WHERE a.nom_c = b.nom AND a.nom_gene = b.nom_gene AND a.nom_gene[1] = '$gene' AND $sort_type = '$sort_value')\nSELECT a.nom, a.classe, a.nom_gene, a.nom_prot, a.nom_ivs, COUNT(b.nom_c) as allel FROM variant a, tmp b WHERE a.nom = b.nom_c AND a.nom_gene = b.nom_gene AND a.nom_gene[1] = '$gene' GROUP BY a.classe, a.nom, a.nom_gene, a.nom_prot, a.nom_ivs ORDER BY $order;";
	$query = "WITH tmp AS (SELECT DISTINCT(a.nom_c, a.num_pat, a.id_pat, a.nom_gene), a.nom_c, a.nom_gene FROM variant2patient a, variant b WHERE a.nom_c = b.nom AND a.nom_gene = b.nom_gene AND a.nom_gene[1] = '$gene' AND $sort_type = '$sort_value')\nSELECT a.*, COUNT(b.nom_c) as allel FROM variant a, tmp b WHERE a.nom = b.nom_c AND a.nom_gene = b.nom_gene AND a.nom_gene[1] = '$gene' GROUP BY a.classe, a.nom, a.nom_gene, a.nom_prot, a.nom_ivs ORDER BY $order;";
	
	#$query = "SELECT a.nom, a.classe, a.nom_gene, a.nom_prot, a.nom_ivs, COUNT(b.nom_c) as allel FROM variant a, variant2patient b WHERE a.nom = b.nom_c AND a.nom_gene = b.nom_gene AND a.nom_gene[1] = '$gene' AND $sort_type = '$sort_value' GROUP BY a.classe, a.nom, a.nom_gene, a.nom_prot, a.nom_ivs ORDER BY a.nom_g ".U2_modules::U2_subs_1::get_strand($gene, $dbh).";";
	if ($sort_type eq 'all') {
		#$query = "SELECT a.nom, a.classe, a.nom_gene, a.nom_prot, a.nom_ivs, COUNT(b.nom_c) as allel FROM variant a, variant2patient b WHERE a.nom = b.nom_c AND a.nom_gene = b.nom_gene AND a.nom_gene[1] = '$gene' GROUP BY a.classe, a.nom, a.nom_gene, a.nom_prot, a.nom_ivs ORDER BY $order;";
		#changed 06/23/2015 to remove duplicates (e.g. variant seen in MiSeq and sanger were counted twice)
		$query = "WITH tmp AS (SELECT DISTINCT(a.nom_c, a.num_pat, a.id_pat, a.nom_gene), a.nom_c, a.nom_gene FROM variant2patient a WHERE a.nom_gene[1] = '$gene')\nSELECT a.nom, a.classe, a.nom_gene, a.nom_prot, a.nom_ivs, COUNT(b.nom_c) as allel FROM variant a, variant2patient b WHERE a.nom = b.nom_c AND a.nom_gene = b.nom_gene AND a.nom_gene[1] = '$gene' GROUP BY a.classe, a.nom, a.nom_gene, a.nom_prot, a.nom_ivs ORDER BY $order;";
		
		#SELECT a.nom, a.classe, a.nom_gene, a.nom_prot, a.nom_ivs, COUNT(DISTINCT(b.type_analyse)) as allel FROM variant a, tmp b WHERE a.nom = b.nom_c AND a.nom_gene = b.nom_gene AND a.nom_gene[1] = '$gene' GROUP BY a.classe, a.nom, a.nom_gene, a.nom_prot, a.nom_ivs ORDER BY $order;";
	}
	
	my $sth = $dbh->prepare($query);
	$res = $sth->execute();
	if ($res ne '0E0') {
		$text = $q->start_p().$q->button({'onclick' => "showAllVariants('$gene', '$sort_value', '$sort_type', '$freq', '$css_class');", 'value' => "Sort by $toprint"}).$q->end_p().$q->start_ul();
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
	my ($gene, $second_name) = U2_modules::U2_subs_1::check_gene($q, $dbh);
	my $variant = U2_modules::U2_subs_1::check_nom_c($q, $dbh);
	my $user = U2_modules::U2_users_1->new();
	U2_modules::U2_subs_2::request_variant_classification($user, $variant, $gene);
	print 'Request done.';
}


if ($q->param('asked') && $q->param('asked') eq 'defgen') {
	my ($id, $number) = U2_modules::U2_subs_1::sample2idnum(uc($q->param('sample')), $q);
	#print $number;
	my $query = "SELECT a.*, b.*, a.nom_prot as hgvs_prot, c.nom_prot, c.enst, c.acc_version FROM variant a, variant2patient b, gene c WHERE a.nom_gene = b.nom_gene AND a.nom = b.nom_c AND a.nom_gene = c.nom AND b.id_pat = '$id' AND b.num_pat = '$number' AND a.classe IN ('VUCS class III', 'VUCS class IV', 'pathogenic');";
	my $sth = $dbh->prepare($query);
	my $res = $sth->execute();
	my $content = "GENE;VARIANT;GENOME_REFERENCE;NOMENCLATURE_HGVS;NOMPROTEINE;VARIANT_C;CHROMOSOME;SEQUENCE_REF;LOCALISATION;POSITION_GENOMIQUE;NM;VARIANT_P;CLASSESUR3;CLASSESUR5;DOMAINE_FCTL;CONSEQUENCES;RS;COSMIC;ENST;DATEDESAISIE;REFERENCES;COMMENTAIRE\n";
	if ($res ne '0E0') {
		while (my $result = $sth->fetchrow_hashref()) {
			my ($chr, $pos) = U2_modules::U2_subs_1::extract_pos_from_genomic($result->{nom_g}, 'clinvar');
			$content .= "$result->{nom_gene}[0];$result->{nom_c};hg19;$result->{nom_g};$result->{nom_prot};$result->{nom_c};chr$chr;;$result->{type_segment} $result->{num_segment};$pos;$result->{nom_gene}[1].$result->{acc_version};$result->{hgvs_prot};;;;$result->{type_prot};$result->{snp_id};;$result->{enst};;;$result->{classe}\n";
		}
	}
	open F, '>'.$ABSOLUTE_HTDOCS_PATH.'data/defgen/'.$id.$number.'_defgen.csv' or die $!;
	print F $content;
	close F;
	print '<a href="'.$HTDOCS_PATH.'data/defgen/'.$id.$number.'_defgen.csv" download>Download file for '.$id.$number.'</a>';
}


sub miseq_details {
	my ($miseq_analysis, $first_name, $last_name, $gene, $acc, $nom_c) = @_;
	my $query_ngs = "SELECT depth, frequency, msr_filter FROM variant2patient a, patient b WHERE a.num_pat = b.numero AND a.id_pat = b.identifiant AND b.first_name = '$first_name' AND b.last_name = '$last_name' AND  nom_gene[1] = '$gene' AND nom_gene[2] = '$acc' AND nom_c = '$nom_c' AND type_analyse = '$miseq_analysis';";
	my $res_ngs = $dbh->selectrow_hashref($query_ngs);
	#$print_ngs .= "DOC MiSeq: <strong>$res_ngs->{'depth'}</strong> Freq: <strong>$res_ngs->{'frequency'}</strong><br/>MSR filter:<strong>$res_ngs->{'msr_filter'}</strong><br/>";
	return $q->start_li().$q->strong("$miseq_analysis values:").$q->start_ul().$q->start_li().$q->span("DOC: ").$q->strong($res_ngs->{'depth'}).$q->span(" Freq: ").$q->strong($res_ngs->{'frequency'}).$q->end_li().$q->start_li().$q->span("MSR filter: ").$q->strong($res_ngs->{'msr_filter'}).$q->end_li().$q->end_ul().$q->end_li();
}





