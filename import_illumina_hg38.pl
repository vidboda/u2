BEGIN {delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV', 'PATH'};}

use strict;
#use CGI;#in startup.pl
#use DBI;
#use AppConfig qw(:expand :argcount);
use Net::OpenSSH;
#use SOAP::Lite;
use JSON;
use Data::Dumper;
use U2_modules::U2_users_1;
use U2_modules::U2_init_1;
use U2_modules::U2_subs_1;
use U2_modules::U2_subs_2;
use U2_modules::U2_subs_3;

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
#		Import script for Illumina experiment - MobiDL version


## Basic init of USHVaM 2 perl scripts:
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



my @styles = ($CSS_PATH.'font-awesome.min.css', $CSS_PATH.'w3.css', $CSS_DEFAULT, $CSS_PATH.'fullsize/fullsize.css');

my $q = new CGI;

my $dbh = DBI->connect(    "DBI:Pg:database=$DB;host=$HOST;",
                        $DB_USER,
                        $DB_PASSWORD,
                        {'RaiseError' => 1}
                ) or die $DBI::errstr;




print $q->header(-type => 'text/html', -'cache-control' => 'no-cache'),
	$q->start_html(-title=>"U2 Illumina wizard",
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
                                -src => $JS_PATH.'jquery.autocomplete.min.js', 'defer' => 'defer'},
                                {-language => 'javascript',
                                -src => $JS_DEFAULT, 'defer' => 'defer'}],
                        -encoding => 'ISO-8859-1');

my $user = U2_modules::U2_users_1->new();
my $date = U2_modules::U2_subs_1::get_date();

U2_modules::U2_subs_1::standard_begin_html($q, $user->getName(), $dbh);

## end of Basic init
my $ABSOLUTE_HTDOCS_PATH = $config->ABSOLUTE_HTDOCS_PATH();
my $ANALYSIS_NGS_DATA_PATH = $config->ANALYSIS_NGS_DATA_PATH();
my $ANALYSIS_MISEQ_FILTER = $config->ANALYSIS_MISEQ_FILTER();
my $PERL_SCRIPTS_HOME = $config->PERL_SCRIPTS_HOME();
# specific args for remote login to RS
my $SSH_RACKSTATION_BASE_DIR = $config->SSH_RACKSTATION_BASE_DIR();
my $SSH_RACKSTATION_MINISEQ_BASE_DIR = $config->SSH_RACKSTATION_MINISEQ_BASE_DIR();
# use automount to replace ssh
my $ABSOLUTE_HTDOCS_PATH = $config->ABSOLUTE_HTDOCS_PATH();
my $RS_BASE_DIR = $config->RS_BASE_DIR();
my $SSH_RACKSTATION_FTP_BASE_DIR = $config->SSH_RACKSTATION_FTP_BASE_DIR();
my $SSH_RACKSTATION_MINISEQ_FTP_BASE_DIR = $config->SSH_RACKSTATION_MINISEQ_FTP_BASE_DIR();
$SSH_RACKSTATION_FTP_BASE_DIR = $ABSOLUTE_HTDOCS_PATH.$RS_BASE_DIR.$SSH_RACKSTATION_FTP_BASE_DIR;
$SSH_RACKSTATION_MINISEQ_FTP_BASE_DIR = $ABSOLUTE_HTDOCS_PATH.$RS_BASE_DIR.$SSH_RACKSTATION_MINISEQ_FTP_BASE_DIR;
my $ANALYSIS_MINISEQ2 = $config->ANALYSIS_MINISEQ2();
# genome version for VV
my $VVGENOME = $config->VARIANTVALIDATOR_GENOME();
my $VVURL = $config->VARIANTVALIDATOR_GENUINE_API();

# hg38 transition variable for postgresql 'start_g' segment field
my ($postgre_start_g, $postgre_end_g) = ('start_g_38', 'end_g_38');  # hg38 style
if ($VVGENOME == 'GRCh37') {$VVGENOME = 'GRCh38'} 


my $step = U2_modules::U2_subs_1::check_step($q);

if ($step && $step == 2) {

	my $analysis = U2_modules::U2_subs_1::check_analysis($q, $dbh, 'form');
	my $run = U2_modules::U2_subs_1::check_illumina_run_id($q);

	my $query = "SELECT filtering_possibility FROM valid_type_analyse WHERE type_analyse = '$analysis';";
	my $res = $dbh->selectrow_hashref($query);
	my $filtered = $res->{'filtering_possibility'};
	# sample and filters do not arrive the same way
	my %sample_hash = U2_modules::U2_subs_2::build_sample_hash($q, $analysis, $filtered);

	# we have the run id, the samples to import and the filter to record.... Let's go
	# ssh again to the NAS, then treat files from MobiDL
	# in Data/Intensities/BaseCalls/Alignement(\d)* (we take the last)
	# sampleID_SXX.coverage.csv => copy and create link + transform into bed + add stddev/mean column in the end
	# 
	# sampleID_SXX.enrichment_summary.csv => get run info per patient + stats
	# sampleID_SXX.gaps.csv => link + stats
	# sampleID_SXX.vcf the big one => annotate mutalyzer (beware of del ins) and keep DOC

	#connect to NAS
	my $ssh;
	# opendir (DIR, $SSH_RACKSTATION_FTP_BASE_DIR); #first attempt to wake up autofs in case of unmounted
	# my $access_method = 'autofs';
  	opendir (DIR, $SSH_RACKSTATION_FTP_BASE_DIR);# or $access_method = 'ssh';
	my $genome_version = 'hg38';
	# if ($access_method eq 'ssh') {$ssh = U2_modules::U2_subs_1::nas_connexion('-', $q)}

	### TO BE CHANGED 4 MINISEQ
	###< AnalysisFolder>D:\Illumina\MiniSeq Sequencing Temp\160620_MN00265_0001_A000H02LJN\Alignment_8\20160621_155804</AnalysisFolder>
	### get alignemnt with _ AND subdir with date
	# MINISEQ change get instrument type
	my ($instrument, $instrument_path, $alignment_dir) = ('miseq', 'MiSeqDx/USHER', "$SSH_RACKSTATION_FTP_BASE_DIR/$run/MobiDL");
	if ($analysis =~ /MiniSeq-\d+/o) {
		$instrument = 'miniseq';
		$instrument_path='MiniSeq';
		$SSH_RACKSTATION_BASE_DIR = $SSH_RACKSTATION_MINISEQ_BASE_DIR;
		$alignment_dir = "$SSH_RACKSTATION_MINISEQ_FTP_BASE_DIR/$run/MobiDL";
	}


	# create roi hash
	my $new_var  = '';
	my $interval = U2_modules::U2_subs_3::build_roi($dbh, $postgre_start_g, $postgre_end_g);
  	my ($general, $message) = ('', '');
  	print $q->p('  Samples imported:'), $q->start_ul();
	while (my ($sampleid, $filter) = each(%sample_hash)) {

		my $vcf = "$sampleid.vcf";
		my $sample_path = "$alignment_dir/$sampleid";


		my ($id, $number) = U2_modules::U2_subs_1::sample2idnum($sampleid, $q);
		my $insert;
		print STDERR "\nInitiating $id$number\n";
		# loop on genes
		$query = "SELECT refseq FROM gene WHERE \"$analysis\" = 't' ORDER BY gene_symbol;";
		my $sth = $dbh->prepare($query);
		my $res = $sth->execute();

		while (my $result = $sth->fetchrow_hashref()) {
			$insert .= "INSERT INTO analyse_moleculaire (num_pat, id_pat, refseq, type_analyse, date_analyse, analyste, technical_valid) VALUES ('$number', '$id', '$result->{'refseq'}', '$analysis', '$date', '".$user->getName()."','t');";
		}
		#######UNCOMMENT WHEN DONE!!!!!!!
		$dbh->do($insert);

		# all in SAMPLEID_multiqc_data/multiqc_data.json

		# "report_general_stats_data": [
        # {
        #     "SAMPLEID.dv": {
        #         "number_of_SNPs": 1122.0, <----- 11
        #         "number_of_indels": 160.0,<----- 13
        #         "tstv": 2.36,<----- 12
		# 	... the same for hc
		# 	}
		# }
		# {
        #     "SAMPLEID": {
        #         "PF_READS_ALIGNED": 4208928.0, <------ 4
        #         "PF_ALIGNED_BASES": 514413948.0, <------ 1
        #         "MEAN_BAIT_COVERAGE": 394.926463, <----- 6
        #         "ON_TARGET_BASES": 229097211.0, <----- 2 -> passer le critère on target reads à on target bases (x150)
        #         "MEAN_TARGET_COVERAGE": 194.503582, <----- 6bis
        #         "PCT_EXC_DUPE": 0.0561, <----- 3
        #         "PCT_TARGET_BASES_20X": 0.983386, <----- 7
        #         "PCT_TARGET_BASES_50X": 0.971945, <----- 8
		# 		...
        #     }
        # },
		# "report_saved_raw_data": {
		# 	"multiqc_picard_insertSize": {
		# 		"SU3541_FR": {
		# 			"MEDIAN_INSERT_SIZE": 136.0, <----- 9
		# 			"STANDARD_DEVIATION": 62.479337, <----- 10
		# 			...
		# 		}
		# 	}
		# }


		my $metrics = U2_modules::U2_subs_2::get_multiqc_value("$alignment_dir/$sampleid/panelCapture/".$sampleid."_multiqc_data/multiqc_data.json", 'report_general_stats_data', $sampleid, 'full');
		# print STDERR Dumper($metrics)."\n";
		my $metrics_insert = U2_modules::U2_subs_2::get_multiqc_value("$alignment_dir/$sampleid/panelCapture/".$sampleid."_multiqc_data/multiqc_data.json", 'report_saved_raw_data', $sampleid, 'full');
		# print STDERR Dumper($metrics_insert)."\n";

		$metrics = { %$metrics, %$metrics_insert };

		my ($fields, $values) = ("num_pat, id_pat, type_analyse, run_id, filter, ", "'$number', '$id', '$analysis', '$run', '$filter', ");


		foreach my $label (keys(%{$metrics})) {
			if ($metrics->{$label}->[1] > 0) {
				$fields .= shift(@{$metrics->{$label}}).", ";
				$values .= "'".shift(@{$metrics->{$label}})."', ";
			}
		}
		$fields =~ s/, $//o;
		$values =~ s/, $//o;
		$insert = "INSERT INTO miseq_analysis ($fields) VALUES ($values);\n";

		$dbh->do($insert);
		#print "$insert\n";

		# VCF
		$insert = '';
		my ($var_chr, $var_pos, $rs_id, $var_ref, $var_alt, $var_vf, $var_dp, $var_filter, $null, $format);
		my ($i, $j, $k) = (0, 0, 0);
		open(F, "$sample_path/panelCapture/$vcf") or die $!;
		# open(F, "$ABSOLUTE_HTDOCS_PATH$ANALYSIS_NGS_DATA_PATH$analysis/$sampleid/$sampleid.vcf") or die $!;
		# prepare insert statement handle
		my $isth = $dbh->prepare("INSERT INTO variant2patient (nom_c, num_pat, id_pat, refseq, type_analyse, statut, allele, depth, frequency, msr_filter) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
		VCF: while (<F>) {
			if ($_ !~ /#/o) {
				chomp;
				$k++;
				my @list = split(/\t/);
				my $message_tmp;

				my ($var_chr, $var_pos, $rs_id, $var_ref, $var_alt, $null, $var_filter) = (shift(@list), shift(@list), shift(@list), shift(@list), shift(@list), shift(@list), shift(@list));
				my ($var_dp, $var_vf);

				my @format_list = split(/:/, pop(@list));

				#compute vf_index
				my @label_list = split(/:/, pop(@list));
				my $label_count = 0;
				# my ($vf_index, $dp_index, $ad_index) = (7, 2, 3);#LRM values
				my ($vf_tag, $dp_tag, $ad_tag) = ('s1_VAF', 'DP', 'AD');
				my ($vf_index, $dp_index, $ad_index) = ('', '', '');
				foreach(@label_list) {
					#print "$_<br/>";
					if (/$vf_tag/) {$vf_index = $label_count}
					elsif (/$dp_tag/) {$dp_index = $label_count}
					elsif (/$ad_tag/) {$ad_index = $label_count}
					$label_count ++;
				}
				$var_dp = $format_list[$dp_index];
				if ($vf_index ne '') {$var_vf = $format_list[$vf_index]}
				# ($var_dp, $var_vf) = ($format_list[$dp_index], $format_list[$vf_index]);
				if (!$var_vf) {
					# HC only, need to compute vaf 
					my @ad_values = split(/,/, $format_list[$ad_index]);
					$var_vf = sprintf('%.2f', (pop(@ad_values)/$var_dp));
				}
				# print STDERR "$var_chr, $var_pos, $rs_id, $var_ref, $var_alt, $null, $var_filter, $var_dp, $var_vf\n";

				# if ($var_chr eq 'chr4' && $var_pos > 15997568) {exit 0}

				# we check wether the variant is in our genes or not
				# we just query ushvam2
				if  ($var_chr =~ /^chr($U2_modules::U2_subs_1::CHR_REGEXP)$/o) {$var_chr = $1}
				if ($var_alt =~ /^([ATCG]+),/) {$var_alt = $1}
				# check if variant not reported in special table no to assess these variants each time
				my $query_variants_no_insert = "SELECT reason FROM variants_no_insert WHERE genome_version = '$genome_version' AND vcfstr = '$var_chr-$var_pos-$var_ref-$var_alt';";
				my $res_variants_no_insert = $dbh->selectrow_hashref($query_variants_no_insert);
				if ($res_variants_no_insert) {
					$message .= "$id$number: WARNING ".$res_variants_no_insert->{'reason'}." for $var_chr-$var_pos-$var_ref-$var_alt\n";next VCF;
				}

				my $interest = 0;
				foreach my $key (keys %{$interval}) {
					$key =~ /(\d+)-(\d+)/o;
					# print STDERR "$var_chr-$var_pos-$interval->{$key}-$1-$2\n";
					if ($var_pos >= $1 && $var_pos <= $2) { # good interval, check good chr
						if ($var_chr eq $interval->{$key}) {$interest = 1;last;}
					}
				}
				if ($interest == 0) {
					if ($analysis =~ /Min?i?Seq-\d+/o) {
						# print STDERR "Out of U2 ROI for $var_chr-$var_pos-$var_ref-$var_alt\n";
						$message .= "$id$number: ERROR: Out of U2 ROI for $var_chr-$var_pos-$var_ref-$var_alt\n";next VCF;
					}
					else {
						next VCF; # variant in unknown region
					}
				} # we deal only with variants located in genes u2 knows about
				# deal with the status case
				my ($status, $allele) = ('heterozygous', 'unknown');
				if ($var_vf >= 0.8) {($status, $allele) = ('homozygous', 'both')}
				# if ($instrument eq 'miniseq' && $var_vf < 0.2) {
				# 	if ($var_filter eq 'PASS') {$var_filter = 'LowVariantFreq'}
				# 	else {$var_filter .= ';LowVariantFreq'}
				if ($list[0] =~ /s[01]POLYX=(\d+);/o) {
					if ($1 >= 8) {
						if ($var_filter eq 'PASS') {$var_filter = 'R8'}
						else {$var_filter .= ';R8'}
					}
				}
				# }
				if ($var_chr eq 'X') {
					my $query_hemi = "SELECT sexe FROM patient WHERE numero = '$number' AND identifiant = '$id';";
					my $res_hemi = $dbh->selectrow_hashref($query_hemi);
					if ($res_hemi->{'sexe'} eq 'M' && $var_chr eq 'X') {($status, $allele) = ('hemizygous', '2')}
				}
				elsif ($var_chr eq 'Y') {($status, $allele) = ('hemizygous', '1')}
				elsif ($var_chr eq 'M') {($status, $allele) = ('heteroplasmic', '2');if ($var_vf >= 0.8) {$status = 'homoplasmic'}}

				my $genomic_var = &U2_modules::U2_subs_3::build_hgvs_from_illumina($var_chr, $var_pos, $var_ref, $var_alt);
				# print STDERR "Genomic var: $genomic_var\n";
				my $first_genomic_var = $genomic_var;
       			my ($nom_c_i, $nom_gene_i, $acc_no_i) = &U2_modules::U2_subs_3::direct_submission_prepare($genomic_var, $genome_version, $number, $id, $analysis, $dbh);
				# print STDERR "Direct submission 1: $genomic_var\n";
       			if ($nom_c_i ne '') {
					# get gene from insert then check
					if ($nom_gene_i ne '') {
						my $query_verif = "SELECT gene_symbol FROM gene WHERE \"$analysis\" = 't' AND gene_symbol = '$nom_gene_i';";
						my $res_verif = $dbh->selectrow_hashref($query_verif);
						# print STDERR "Gene verif2: $res_verif->{'nom'}[0]-$nom_gene_i";
						if ($res_verif->{'gene_symbol'} eq $nom_gene_i) {
							# print STDERR "execute: $nom_c_i-$nom_gene_i\n";
							# need to get individual values from direct submission

							######## UNCOMMENT WHEN READY
							$isth->execute($nom_c_i, $number, $id, $acc_no_i, $analysis, $status, $allele, $var_dp, $var_vf, $var_filter);
							########

							$j++;
							next VCF;
						}
						else {
							#variant in unwanted region
							$message .= "$id$number: ERROR: Impossible to record variant (unwanted region) $var_chr-$var_pos-$var_ref-$var_alt-$nom_gene_i-$insert\n";
						}
					}
					else {
						#variant in unwanted region
						$message .= "$id$number: ERROR: Impossible to record variant (BAD REGEXP) $var_chr-$var_pos-$var_ref-$var_alt-$insert\n";
					}

				}
				#still here? we try to invert wt & mut
				# print STDERR "Before Inv genomic var:$genomic_var\n";
				if ($genomic_var =~ /(chr$U2_modules::U2_subs_1::CHR_REGEXP:g\..+\d+)([ATGC])>([ATCG])/o) {
					my $inv_genomic_var = $1.$3.">".$2;
					# print STDERR "Inv genomic var (inside inv): $inv_genomic_var\n";
					my ($nom_c_i, $nom_gene_i, $acc_no_i) = &U2_modules::U2_subs_3::direct_submission_prepare($inv_genomic_var, $genome_version, $number, $id, $analysis, $dbh);
					# print STDERR "Direct submission 2: $inv_genomic_var-l400\n";
					# print STDERR "Direct submission 2: $nom_c_i-l401\n";
					if ($nom_c_i ne '') {
						# get gene from insert then check
						if ($nom_gene_i ne '') {
							my $query_verif = "SELECT gene_symbol FROM gene WHERE \"$analysis\" = 't' AND gene_symbol = '$nom_gene_i';";
							my $res_verif = $dbh->selectrow_hashref($query_verif);
							# print STDERR "Gene verif2: $res_verif->{'nom'}[0]-$nom_gene_i";
							if ($res_verif->{'gene_symbol'} eq $nom_gene_i) {
							# print STDERR "execute: $nom_c_i-$nom_gene_i\n";
								######## UNCOMMENT WHEN READY
								$isth->execute($nom_c_i, $number, $id, $acc_no_i, $analysis, $status, $allele, $var_dp, $var_vf, $var_filter);
								########
								$j++;
								next VCF;
							}
							else {
								#variant in unwanted region
								$message .= "$id$number: ERROR: Impossible to record variant (unwanted region) $var_chr-$var_pos-$var_ref-$var_alt-$nom_gene_i-$insert\n";
							}
						}
						else {
							#variant in unwanted region
							$message .= "$id$number: ERROR: Impossible to record variant (BAD REGEXP) $var_chr-$var_pos-$var_ref-$var_alt-$insert\n";
						}
					}
				}

				# ok let's deal with VV
				# print STDERR "Run VV1: $var_chr-$var_pos-$var_ref-$var_alt\n";
				# in case VV returns weird results
				my $fail = 0;
				my $vv_results = decode_json(U2_modules::U2_subs_1::run_vv($VVGENOME, "raw", "$var_chr-$var_pos-$var_ref-$var_alt", 'VCF')) or $fail = 1;
				if ($fail == 1) {
					$vv_results = decode_json(U2_modules::U2_subs_1::run_vv($VVGENOME, "raw", "$var_chr-$var_pos-$var_ref-$var_alt", 'VCF'))
				}
				# print STDERR "End Run VV1";
				# run variantvalidator API
				my ($type_segment, $classe, $var_final, $cdna);
				if ($vv_results ne '0') {
					# find vvkey and cdna
					my ($hashvar, $tmp_message);
					my ($vvkey, $nm_list, $tag) = ('', '', '');
					# print STDERR "Run VV results\n";
					($tmp_message, $insert, $hashvar, $nm_list, $tag) = &run_vv_results($vv_results, $genome_version, $id, $number, $var_chr, $var_pos, $var_ref, $var_alt, $analysis, $status, $allele, $var_dp, $var_vf, $var_filter, $dbh);
					# print STDERR "End Run VV results\n";
					# print STDERR "tmp_message: $tmp_message\n";
					# print STDERR "insert: $insert\n";
					# print STDERR "hashtag: $tag\n";
					# print STDERR "nm_list: $nm_list\n";
					if ($tmp_message ne '') {$message .= $tmp_message;next VCF}
					elsif ($insert ne '') {
						# print STDERR $k." - ".$insert."\n";
						######## UNCOMMENT WHEN READY
						$dbh->do($insert);
						########
						$j++;
						next VCF;
					}

					if ($nm_list eq '' && $tag eq '') {$message .= "$id$number: WARNING: No suitable NM found for $var_chr-$var_pos-$var_ref-$var_alt-\nVVjson: ".Dumper($vv_results)."- \nRequest URL:$VVURL/VariantValidator/variantvalidator/$VVGENOME/$var_chr-$var_pos-$var_ref-$var_alt/all?content-type=application/json\n";next VCF}
					elsif ($nm_list eq '' && $tag ne '') {$message .= $tag;next VCF}
					# query U2 to get NM
					chop($nm_list);# remove last ,
					# print STDERR $nm_list."\n";
					my ($acc_no, $acc_ver, $gene, $ng_accno, @possible);
					my $query = "SELECT gene_symbol as gene, refseq as nm, acc_version, acc_g, main FROM gene WHERE refseq IN ($nm_list) ORDER BY main DESC;";
					my $sth = $dbh->prepare($query);
					my $res = $sth->execute();
					while (my $result = $sth->fetchrow_hashref()) {
						($gene, $ng_accno) = ($result->{'gene'}, $result->{'acc_g'}); # needed to be sent to create_variant_vv for consistency with other callings of the same sub in different scripts
						if (exists $hashvar->{$result->{'nm'}} && exists $hashvar->{$result->{'nm'}}->{$result->{'acc_version'}} && $result->{'main'} == 1) {	# best case
							$hashvar->{$result->{'nm'}}->{$result->{'acc_version'}}[1] = $result->{'main'};
							$vvkey = $result->{'nm'}.".".$result->{'acc_version'}.":".$hashvar->{$result->{'nm'}}->{$result->{'acc_version'}}[0];
							$cdna = $hashvar->{$result->{'nm'}}->{$result->{'acc_version'}}[0];
							if ($cdna =~ /=$/) {
								$message .= "$id$number: WARNING: ALT equals REF in ".$result->{'nm'}." for $var_chr-$var_pos-$var_ref-$var_alt ($cdna)\n";
								next VCF
							}
							($acc_no, $acc_ver) = ($result->{'nm'}, $result->{'acc_version'});
							# print STDERR "VV 1\n";
							last;							
						}
						if (exists $hashvar->{$result->{'nm'}} && !exists $hashvar->{$result->{'nm'}}->{$result->{'acc_version'}}) {
							# bad acc not in U2 => retry with U2 acc_no
							# print STDERR "Run VV2 Bad acc not in U2: $var_chr-$var_pos-$var_ref-$var_alt - ".$result->{'nm'}.".".$result->{'acc_version'}."\n";
							my $fail = 0;
							$vv_results = decode_json(U2_modules::U2_subs_1::run_vv($VVGENOME, $result->{'nm'}.".".$result->{'acc_version'}, "$var_chr-$var_pos-$var_ref-$var_alt", 'VCF')) or $fail = 1;
							if ($fail == 1) {
								$vv_results = decode_json(U2_modules::U2_subs_1::run_vv($VVGENOME, $result->{'nm'}.".".$result->{'acc_version'}, "$var_chr-$var_pos-$var_ref-$var_alt", 'VCF'))
							}
							# get new cdna
							my ($tmp_message, $hashvar_tmp);
							# print STDERR "Run VV l489\n";
							($tmp_message, $insert, $hashvar_tmp, $nm_list, $tag) = &run_vv_results($vv_results, $genome_version, $id, $number, $var_chr, $var_pos, $var_ref, $var_alt, $analysis, $status, $allele, $var_dp, $var_vf,$var_filter, $dbh);
							# print STDERR "End Run VV l491\n";
							if ($tmp_message ne '') {$message .= $tmp_message;next VCF}# should not happen
							elsif ($insert ne '') {# should not happen
								$dbh->do($insert);
								$j++;
								next VCF;
							}
							# david 12/04/2022 added l 742 and 759-762
							if ($hashvar_tmp->{$result->{'nm'}}->{$result->{'acc_version'}}[0] ne '') {
								if ($result->{'main'} == 1) {
									$vvkey = $result->{'nm'}.".".$result->{'acc_version'}.":".$hashvar_tmp->{$result->{'nm'}}->{$result->{'acc_version'}}[0];
									$cdna = $hashvar_tmp->{$result->{'nm'}}->{$result->{'acc_version'}}[0];
									($acc_no, $acc_ver) = ($result->{'nm'}, $result->{'acc_version'});
									# main => last
									last
								} else {
									# replace acc_no in hashvar
									# https://stackoverflow.com/questions/1490356/how-to-replace-a-perl-hash-key
									delete $hashvar->{$result->{'nm'}};
									$hashvar->{$result->{'nm'}}->{$result->{'acc_version'}} = $hashvar_tmp->{$result->{'nm'}}->{$result->{'acc_version'}};
								}
							}
							else {
								$vvkey = '';
								# print STDERR "No suitable NM (likely number version)\n";
							}
							# print STDERR "VV 2\n";
						}
					}
					if ($vvkey ne '') {
						($message_tmp, $type_segment, $classe, $var_final) = U2_modules::U2_subs_3::create_variant_vv($vv_results, $vvkey, $gene, $cdna, $acc_no, $acc_ver, $ng_accno, $user, $q, $dbh, "background $var_chr-$var_pos-$var_ref-$var_alt");
						if ($message_tmp =~ /ERROR/o) {$message .= "$id$number: $message_tmp"}
						# $j++;
						# print STDERR "$var_chr-$var_pos-$var_ref-$var_alt: $message_tmp\n";
					}
					else {
						# 2 cases:
						# non main  => choose the most impactant (exonic > intronic > UTR) : $hashvar contains a value 0 for main (to be checked)
						# or nothing => no suitable NM
						my ($candidates, $candidate);
						my ($semaph1, $semaph2) = (0, 0);
						foreach my $nm (keys (%{$hashvar})) {
							# check if in U2:
							my $query_nm = "SELECT gene_symbol, acc_version FROM gene WHERE refseq = '$nm';";
							my $res_nm = $dbh->selectrow_hashref($query_nm);
							if ($res_nm->{'gene_symbol'}) {
								if ($hashvar->{$nm}->{$res_nm->{'acc_version'}}[1] != 1) { # non main - should be
									$semaph1 = 1;
									if ($hashvar->{$nm}->{$res_nm->{'acc_version'}}[0] =~ /^c\.[^-][^\+\*-]+$/o) { # exonic
										if (!exists $candidates->{'exonic'}) {$candidates->{'exonic'} = "$nm.".$res_nm->{'acc_version'}.":".$hashvar->{$nm}->{$res_nm->{'acc_version'}}[0]}
									}
									elsif ($hashvar->{$nm}->{$res_nm->{'acc_version'}}[0] =~ /^c\.[\*-].+$/o) { # UTR
										if (!exists $candidates->{'UTR'}) {$candidates->{'UTR'} = "$nm.".$res_nm->{'acc_version'}.":".$hashvar->{$nm}->{$res_nm->{'acc_version'}}[0]}
									}
									elsif ($hashvar->{$nm}->{$res_nm->{'acc_version'}}[0] =~ /^c\.[^-].+[\+-].+$/o) { # intronic
										if (!exists $candidates->{'intronic'}) {$candidates->{'intronic'} = "$nm.".$res_nm->{'acc_version'}.":".$hashvar->{$nm}->{$res_nm->{'acc_version'}}[0]}
									}
								}
							}
						}
						if ($semaph1 == 1) {
							if (exists $candidates->{'exonic'}) {$candidate = $candidates->{'exonic'}}
							elsif (exists $candidates->{'intronic'}) {$candidate = $candidates->{'intronic'}}
							elsif (exists $candidates->{'UTR'}) {$candidate = $candidates->{'UTR'}}
						}
						if ($candidate =~ /(NM_\d+)\.(\d):c\..+/) {
							# print STDERR "Candidate: $candidate\n";
							($acc_no, $acc_ver) = ($1, $2);
							# run vv again
							# print STDERR "Run VV3: $var_chr-$var_pos-$var_ref-$var_alt-".$hashvar->{$acc_no}->{$acc_ver}[0]."-$VVGENOME\n";
							my $fail = 0;
								$vv_results = decode_json(U2_modules::U2_subs_1::run_vv($VVGENOME, $acc_no.".".$acc_ver, $hashvar->{$acc_no}->{$acc_ver}[0], 'cdna')) or $fail = 1;
							if ($fail == 1) {
								$vv_results = decode_json(U2_modules::U2_subs_1::run_vv($VVGENOME, $acc_no.".".$acc_ver, $hashvar->{$acc_no}->{$acc_ver}[0], 'cdna'))
							}
							if ($vv_results->{'message'}) {$message .= "$id$number: ERROR: VariantValidator returned $vv_results $var_chr-$var_pos-$var_ref-$var_alt\n";next VCF}
							$vvkey = "$acc_no.$acc_ver:".$hashvar->{$acc_no}->{$acc_ver}[0];
							$cdna = $hashvar->{$acc_no}->{$acc_ver}[0];
							($message_tmp, $type_segment, $classe, $var_final) = U2_modules::U2_subs_3::create_variant_vv($vv_results, $vvkey, $gene, $cdna, $acc_no, $acc_ver, $ng_accno, $user, $q, $dbh, "background $var_chr-$var_pos-$var_ref-$var_alt");
							if ($message_tmp =~ /ERROR/o) {$message .= "$id$number: $message_tmp"}
							#$j++;
							# print STDERR "$var_chr-$var_pos-$var_ref-$var_alt: $message_tmp\n";
						}
						else {
							# ERROR
							# special table no to assess these variants each time
							# my $query_variants_no_insert = "SELECT reason FROM variants_no_insert WHERE genome_version = '$genome_version' AND vcfstr = '$var_chr-$var_pos-$var_ref-$var_alt';";
							# my $res_variants_no_insert = $dbh->selectrow_hashref($query_variants_no_insert);
							# if (!$res_variants_no_insert) {
							# 	my $insert_variants_no_insert = "INSERT INTO variants_no_insert VALUES ('$var_chr-$var_pos-$var_ref-$var_alt', 'no_suitable_nm_found', '$genome_version');";
							# 	$dbh->do($insert_variants_no_insert);
							# }
							$message .= "$id$number: ERROR: Impossible to run VariantValidator (no suitable NM found) for variant $var_chr-$var_pos-$var_ref-$var_alt-$candidate\n";
						}
					}

					if ($message_tmp =~ /NEWVAR/o) {
						my $query_verif = "SELECT gene_symbol FROM gene WHERE \"$analysis\" = 't' AND gene_symbol = '$gene';";
						my $res_verif = $dbh->selectrow_hashref($query_verif);
						# print STDERR "Gene verif3: $res_verif->{'nom'}[0]-$gene";
						if ($res_verif->{'gene_symbol'} eq $gene) {
							# bug 210726 - 2 differents variants in LRM VCF give the very same HGVS hgvs_genomic_description
							# SU7542 17-4439727-T-TG and 17-4439731-G-GG both give c.1607+13dupG, 7542, SU, {SPNS2,NM_001124758}
							# then we should check whether the variant is not already inserted
							my $last_check = "SELECT nom_c FROM variant2patient WHERE id_pat = '$id' AND num_pat = '$number' AND type_analyse = '$analysis' AND nom_c = '$var_final' AND refseq = '$acc_no';";
							my $res_last_check = $dbh->selectrow_hashref($last_check);
							# print STDERR "Last check: $res_last_check\n";
							if (!$res_last_check || $res_last_check eq '0E0') {
								$insert = "INSERT INTO variant2patient (nom_c, num_pat, id_pat, refseq, type_analyse, statut, allele, depth, frequency, msr_filter) VALUES ('$var_final', '$number', '$id', '$acc_no', '$analysis', '$status', '$allele', '$var_dp', '$var_vf', '$var_filter');";
								# print STDERR $insert."\n";
								$dbh->do($insert) or die "Variant already recorded for the patient, there must be a mistake somewhere $!";
								$i++;$j++;
								$new_var .= $message_tmp;
							}
							else {
								$message .= "$id$number: Double definition for the same variant found: $var_final, $acc_no, $gene";
								next VCF;
							}
						}
						else {
							# variant in unwanted region
							$message .= "$id$number: ERROR: Impossible to record variant (unwanted region) $var_chr-$var_pos-$var_ref-$var_alt-$gene-$var_final\n";
						}
					}
					else {
						$message .= "$id$number: ERROR: not in V2P $var_chr-$var_pos-$var_ref-$var_alt-$gene-$var_final\n";
						# print STDERR "$var_chr-$var_pos-$var_ref-$var_alt: $message_tmp - not in V2P\n";
					}
				}
				else {
					$message .= "$id$number: ERROR: Impossible to run VariantValidator (vv_results empty) for variant $var_chr-$var_pos-$var_ref-$var_alt\n";
				}
			}
		}
		close F;
		$general .= "Insertion for $id$number:\n\n- $j/$k variants (".(sprintf('%.2f', ($j/$k)*100))."%) have been automatically inserted,\nincluding $i new variants that have been successfully created\n\n";
		my $valid = "UPDATE miseq_analysis SET valid_import = 't' WHERE id_pat = '$id' AND num_pat = '$number' AND type_analyse= '$analysis';";
		$dbh->do($valid);
		# print STDERR "$id$number VCF imported.\n";
		print $q->start_li(), $q->a({"href" => "patient_file.pl?sample=$id$number", "target" => "_blank"}, "$id$number"), $q->span(' import validated'), $q->end_li();
		#print STDERR $valid."\n";
	}

	open F, ">>$ABSOLUTE_HTDOCS_PATH$ANALYSIS_NGS_DATA_PATH$analysis/".$run."import.log" or print STDERR $!;
	print F $user->getName()."\n$date\n$run\n$general\n$message\n$new_var\n";
	close F;

	U2_modules::U2_subs_2::send_manual_mail($user, '', '', $run, $general, '', $message);
  	print $q->end_ul(), $q->br(), $q->start_p(), $q->strong('  Import finished and validated. You should receive the confirmation email quickly.'), $q->end_p();
}


##Basic end of USHVaM 2 perl scripts:

U2_modules::U2_subs_1::standard_end_html($q);

print $q->end_html();

exit();

##End of Basic end

##specific subs for current script

sub search_position {
	my ($chr, $pos) = @_;
	my $query = "SELECT a.nom, b.gene_symbol, b.refseq, a.type FROM segment a, gene b WHERE a.refseq = b.refseq AND b.chr = '$chr' AND '$pos' BETWEEN SYMMETRIC a.$postgre_start_g AND a.$postgre_end_g;";
	my $res = $dbh->selectrow_hashref($query);
	if ($res ne '0E0') {return "\t$res->{'gene_symbol'} - $res->{'refseq'}\t$res->{'type'}\t$res->{'nom'}"}
	else {return "\tunknown position in U2\tunknown\tunknown"}
}

sub get_detailed_pos {
	my ($pos1, $pos2) = @_;
	$pos1 =~ /(\d+)_(\d+)/o;
	my ($pos11, $pos12) = ($1, $2);
	$pos2 =~ /(\d+)_(\d+)/o;
	return ($pos11, $pos12, $1, $2);
}

sub get_start_end_pos {
	my $var = shift;
	if ($var =~ /chr$U2_modules::U2_subs_1::CHR_REGEXP:g\.(\d+)[dATCG][eu>][lpATCG].*/o) {return ($1, $1)}
	elsif ($var =~ /chr$U2_modules::U2_subs_1::CHR_REGEXP:g\.(\d+)_(\d+)[di][enu][lsp].*/o) {return ($1, $2)}
}

sub run_vv_results {
	my ($vv_results_to_treat, $genome_version, $id, $number, $var_chr, $var_pos, $var_ref, $var_alt, $analysis, $status, $allele, $var_dp, $var_vf, $var_filter, $dbh) = @_;
	# print STDERR "$genome_version\n";
	# expected return ($tmp_message, $insert, $hashvar, $nm_list, $tag)
	my ($hashvar, $nm_list, $tag);
	($nm_list, $tag) = ('', '');
	foreach my $var (keys %{$vv_results_to_treat}) {
		#my ($nm, $cdna) = split(/:/, $var)[0], split(/:/, $var)[1]);
		if ($var eq 'flag' && $vv_results_to_treat->{$var} eq 'intergenic') {
			# special table no to assess these variants each time
			my $query_variants_no_insert = "SELECT reason FROM variants_no_insert WHERE genome_version = '$genome_version' AND vcfstr = '$var_chr-$var_pos-$var_ref-$var_alt';";
			my $res_variants_no_insert = $dbh->selectrow_hashref($query_variants_no_insert);
			if (!$res_variants_no_insert) {
				my $insert_variants_no_insert = "INSERT INTO variants_no_insert VALUES ('$var_chr-$var_pos-$var_ref-$var_alt', 'intergenic_variant', 'hg38');";
				$dbh->do($insert_variants_no_insert);
			}
			return "$id$number: WARNING: Intergenic variant: $var_chr-$var_pos-$var_ref-$var_alt\n";
		}
		my ($nm, $acc_ver) = ((split(/[:\.]/, $var))[0], (split(/[:\.]/, $var))[1]);
		if ($nm =~ /^N[RM]_\d+$/o && (split(/:/, $var))[1] !~ /=/o) {
			# print STDERR "----NM: $nm - l702\n";
			#$hashvar->{$nm} = [(split(/:/, $var))[1], $acc_ver, ''];#NM => [c., acc_ver, main]
			$hashvar->{$nm}->{$acc_ver} = [(split(/:/, $var))[1], ''];#NM => acc_ver => [c., main]
			########
			##$hashvar is BAD if vv returns several times the same transcript with different acc no => bug
			## Faire un deuxième niveau de clé avec acc_no
			########
			$nm_list .= " '$nm',";
			# get genomic hgvs and check direct submission again
			my $tmp_nom_g = '';
			my @full_nom_g_38 = split(/:/, $vv_results_to_treat->{$var}->{'primary_assembly_loci'}->{'hg38'}->{'hgvs_genomic_description'});
			if ($full_nom_g_38[0] =~ /NC_0+([^0]{1,2}0?)\.\d{1,2}$/o) {
				my $chr = $1;
				if ($chr == 23) {$chr = 'X'}
				elsif ($chr == 24) {$chr = 'Y'}
				$tmp_nom_g = "chr$chr:".pop(@full_nom_g_38);
			}
			if ($tmp_nom_g ne '') {
				# print STDERR "$tmp_nom_g-l719\n";
				my $insert = U2_modules::U2_subs_3::direct_submission($tmp_nom_g, $genome_version, $number, $id, $analysis, $status, $allele, $var_dp, $var_vf, $var_filter, $dbh);
				# print STDERR "$insert-l721\n";
				if ($insert ne '') {
					my $query_verif = "SELECT refseq, \"$analysis\" as analysis FROM gene WHERE refseq = '$nm';";
					# print STDERR "$query_verif\n";
					my $res_verif = $dbh->selectrow_hashref($query_verif);
					# print STDERR "Gene verif 4: $res_verif->{'refseq'}-$nm\n";
					if ($res_verif->{'refseq'} eq $nm && $insert eq 'WARNING: variant already recorded') {
						# print STDERR $insert."-l728\n";
						return "$id$number: $insert for $var_chr-$var_pos-$var_ref-$var_alt\n";
					}
					if ($res_verif->{'refseq'} eq $nm && $res_verif->{'analysis'} == 1) {
						# print STDERR "insert 4a:$insert\n";
						return ('', $insert);
					}
					elsif ($res_verif->{'refseq'} eq $nm && $res_verif->{'analysis'} != 1) {
						# print STDERR "$id$number: ERROR a: Impossible to record variant (unwanted region in run_vv_results) $var_chr-$var_pos-$var_ref-$var_alt-$nm-$tmp_nom_g\n";
						return  "$id$number: ERROR: Impossible to record variant (unwanted region in run_vv_results) $var_chr-$var_pos-$var_ref-$var_alt-$nm-$tmp_nom_g\n";
					}
				}
			}
			if ($vv_results_to_treat->{$var}->{'gene_symbol'} && $tmp_nom_g =~ /.+[di][eun][lps]$/o) {#last test: we directly test c. as genomic nomenclature can differ in dels/dup
				# patches
				my $last_query = "SELECT a.nom_g_38 FROM variant a, gene b WHERE a.refseq = b.refseq AND a.nom LIKE '".(split(/:/, $var))[1]."%' and b.gene_symbol = '$vv_results_to_treat->{$var}->{'gene_symbol'}';";
				# print STDERR $last_query."l736\n";
				my $res_last = $dbh->selectrow_hashref($last_query);
				if ($res_last->{'nom_g_38'}) {
					my $insert = U2_modules::U2_subs_3::direct_submission($res_last->{'nom_g_38'}, $genome_version, $number, $id, $analysis, $status, $allele, $var_dp, $var_vf, $var_filter, $dbh);
					# print STDERR "Direct submission4 $insert - l749";
					# if ($insert ne '') {return ('', $insert)}
					if ($insert ne '') {
						my $query_verif = "SELECT refseq, \"$analysis\" as analysis FROM gene WHERE refseq = '$nm';";
						# print STDERR "$query_verif-l753\n";
						my $res_verif = $dbh->selectrow_hashref($query_verif);
						# print STDERR "Gene verif 5: $res_verif->{'nom'}[1]-$nm - l755\n";
						if ($res_verif->{'refseq'} eq $nm && $insert eq 'WARNING: variant already recorded') {
							# print STDERR $insert."-l757\n";
							return "$id$number: $insert for $var_chr-$var_pos-$var_ref-$var_alt\n";
						}
						if ($res_verif->{'refseq'} eq $nm && $res_verif->{'analysis'} == 1) {
							# print STDERR "insert 4b:$insert - l761\n";
							return ('', $insert);
						}
						elsif ($res_verif->{'refseq'} eq $nm && $res_verif->{'analysis'} != 1) {
							# print STDERR "$id$number: ERROR b: Impossible to record variant (unwanted region in run_vv_results) $var_chr-$var_pos-$var_ref-$var_alt-$nm-$tmp_nom_g\n";
							return  "$id$number: ERROR: Impossible to record variant (unwanted region in run_vv_results) $var_chr-$var_pos-$var_ref-$var_alt-$nm-$tmp_nom_g\n";
						}
					}
				}
			}
		}
		elsif ($nm =~ /^N[RM]_\d+$/o && (split(/:/, $var))[1] =~ /=/o) {
			#create a tag for hom WT
			$tag = "$id$number: WARNING: Variant $var_alt equals Reference in $nm $var_chr-$var_pos-$var_ref-$var_alt\n"
		}
	}
	return ('', '', $hashvar, $nm_list, $tag);
}
