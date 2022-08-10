BEGIN {delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV', 'PATH'};}

use strict;
#use CGI; #in startup.pl
#use DBI;
#use AppConfig qw(:expand :argcount);
use URI::Encode qw(uri_encode uri_decode);
#use Net::OpenSSH;
use SOAP::Lite;
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
#
#	The script creates an HTML5 canvas to draw each exon/intron/UTR of each gene + different exons/introns/UTRs in alternative isoforms
#	In adition it creates an image map superposed on the canvas which creates squares of 50*50 px which can be clicked to get
#	a JqueryUI modal popup which includes a specific form built using AJAX
#	This script is also used to create a form and check feaseability of Illumina data import. This form will launch the Illumina_import script.

##MODIFIED init of USHVaM 2 perl scripts: INCLUDES JqueryUI, CSS for forms AND JS SCRIPT FOR POPUP WINDOW TO ADD A VARIANT TO AN ANALYSIS
##MODIFIED also calls ssh parameters for remote login to RackStation
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
my $PATIENT_IDS = $config->PATIENT_IDS();

#specific args for browsing RS
my $PERL_SCRIPTS_HOME = $config->PERL_SCRIPTS_HOME();
my $ABSOLUTE_HTDOCS_PATH = $config->ABSOLUTE_HTDOCS_PATH();
my $RS_BASE_DIR  = $config->RS_BASE_DIR();
my $CLINICAL_EXOME_BASE_DIR = $config->CLINICAL_EXOME_BASE_DIR();
my $CLINICAL_EXOME_METRICS_SOURCES = $config->CLINICAL_EXOME_METRICS_SOURCES();

#end

my @styles = ($CSS_PATH.'font-awesome.min.css', $CSS_PATH.'w3.css', $CSS_DEFAULT, $CSS_PATH.'form.css', $CSS_PATH.'jquery.alerts.css');

my $q = new CGI;

my $dbh = DBI->connect(    "DBI:Pg:database=$DB;host=$HOST;",
                        $DB_USER,
                        $DB_PASSWORD,
                        {'RaiseError' => 1}
                ) or die $DBI::errstr;



print $q->header(-type => 'text/html', -'cache-control' => 'no-cache'),
	$q->start_html(
		-title=>"U2 Analysis wizard",
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
                        -src => $JS_PATH.'jquery.validate.min.js', 'defer' => 'defer'},
			 {-language => 'javascript',
                        -src => $JS_PATH.'jquery.alerts.js', 'defer' => 'defer'},
                        {-language => 'javascript',
                        -src => $JS_PATH.'jquery.autocomplete.min.js', 'defer' => 'defer'},
                        {-language => 'javascript',
                        -src => $JS_DEFAULT, 'defer' => 'defer'}],
                -encoding => 'ISO-8859-1');

my $user = U2_modules::U2_users_1->new();


U2_modules::U2_subs_1::standard_begin_html($q, $user->getName(), $dbh);

##end of MODIFIED init


### core script which will be used to add new clinical exomes


if ($user->isAnalyst() == 1) {


	my $step = U2_modules::U2_subs_1::check_step($q);
	my $analysis = U2_modules::U2_subs_1::check_analysis($q, $dbh, 'form');
	#step 2 => form with possible samples to import per run
	if ($step == 2) {
		my ($id, $number) = U2_modules::U2_subs_1::sample2idnum(uc($q->param('sample')), $q);
		my $analysis = U2_modules::U2_subs_1::check_analysis($q, $dbh, 'form');
		#first get manifets name for validation purpose
		my ($manifest, $filtered) = U2_modules::U2_subs_2::get_filtering_and_manifest($analysis, $dbh);
		my $run_hash; #run => [samples]
		my @run_list = `find $ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/data/$CLINICAL_EXOME_BASE_DIR -maxdepth 1 -type d -exec basename '{}' \\; | grep -E '^[0-9]{6}_.*'`;
		my $semaph = 0;
		my %patients;
		foreach my $run (@run_list) {
			chomp($run);
			my @samples = `find $ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/data/$CLINICAL_EXOME_BASE_DIR/$run -maxdepth 1 -type d -exec basename '{}' \\; | grep -E '^[SR]U?.*'`;
			my @clean_samples;
			foreach (@samples) {chomp;push @clean_samples, $_;}
			if (grep(/$id$number/, @clean_samples)) {
				$run_hash->{$run} = \@clean_samples;
				$semaph = 1;
				%patients = map {$_ => 0} @clean_samples;
				#we've got a match
				#if succeeded, we must check whether this run is already recorded for the patient
				my $link = $q->start_p({'class' => 'w3-margin'}).$q->a({'href' => "patient_file.pl?sample=$id$number"}, $id.$number).$q->end_p();
				my  $query = "SELECT num_pat, id_pat FROM miseq_analysis WHERE type_analyse = '$analysis' AND num_pat = '$number' AND id_pat = '$id' GROUP BY num_pat, id_pat;";
				my $res = $dbh->selectrow_hashref($query);
				if ($res) {print $link;U2_modules::U2_subs_1::standard_error('14', $q);}
				my %patients = %{U2_modules::U2_subs_2::check_ngs_samples(\%patients, $analysis, $dbh)};
				my $data_dir = "$ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/data/$CLINICAL_EXOME_BASE_DIR";
				print $q->br().U2_modules::U2_subs_2::build_ngs_form($id, $number, $analysis, $run, $filtered, \%patients, 'add_clinical_exome.pl', '3', $q, $data_dir, '', '', '');
				print $q->br().U2_modules::U2_subs_2::print_clinical_exome_criteria($q);
			}
		}
		if ($semaph == 0) {
			print $q->p("Sorry, no Clinical exome to import for $id$number");
		}
	}
	elsif ($step == 3) {	#step 3 => actual import
		my $query = "SELECT filtering_possibility FROM valid_type_analyse WHERE type_analyse = '$analysis';";
		my $res = $dbh->selectrow_hashref($query);
		my $filtered = $res->{'filtering_possibility'};
		my %sample_hash = U2_modules::U2_subs_2::build_sample_hash($q, $analysis, $filtered);
		my $run = U2_modules::U2_subs_1::check_illumina_run_id($q);
		#check if known
		$query = "SELECT id FROM illumina_run WHERE id ='$run';";
		my $res = $dbh->selectrow_hashref($query);
		if (!$res) {#unknown run
			my $insert_run = "INSERT INTO illumina_run (id) VALUES ('$run');";
			################## UNCOMMENT
			$dbh->do($insert_run);
			################## UNCOMMENT
			#print $q->p($insert_run);
		}


		#create roi hash
		my $interval = U2_modules::U2_subs_3::build_roi($dbh);
		#test mutalyzer
		if (U2_modules::U2_subs_1::test_mutalyzer() != 1) {U2_modules::U2_subs_1::standard_error('23', $q)}
		my $soap = SOAP::Lite->uri('http://mutalyzer.nl/2.0/services')->proxy('https://mutalyzer.nl/services/?wsdl');
		my ($manual, $not_inserted, $general, $mutalyzer_no_answer, $sample_end, $to_follow, $new_var) = ('', '', '', '', '', '', '');#$manual will contain variants that cannot be delt automatically i.e. PTPRQ (at least in hg19), NR_, non mappable; $notinserted variants wt homozygous, $general global data for final email, $sample_end last treated patient for redirection $to_follow is to get info on certain variants that were buggy
		my $date = U2_modules::U2_subs_1::get_date();



		#sample and filters do not arrive the same way
		while (my ($sampleid, $filter) = each(%sample_hash)) {
			#get log's number
			my ($id, $number) = U2_modules::U2_subs_1::sample2idnum($sampleid, $q);
			$sample_end = $sampleid;
			print STDERR "\nInitiating $id$number...";
			#loop  genes
			my $insert_analysis;
			$query = "SELECT gene_symbol, refseq FROM gene WHERE \"$analysis\" = 't' ORDER BY gene_symbol;";
			my $sth = $dbh->prepare($query);
			my $res = $sth->execute();
			while (my $result = $sth->fetchrow_hashref()) {
				$insert_analysis .= "INSERT INTO analyse_moleculaire (num_pat, id_pat, refseq, type_analyse, date_analyse, analyste, technical_valid) VALUES ('$number', '$id', '".$result->{'refseq'}."', '$analysis', '$date', '".$user->getName()."','t');";
			}
			#print "$insert_analysis<br/>";
			#######UNCOMMENT WHEN DONE!!!!!!!
			$dbh->do($insert_analysis);


			#my $nenufaar_log = `ls $ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/data/$CLINICAL_EXOME_BASE_DIR/$run/*.log | xargs basename`;
			#$nenufaar_log =~ /_(\d+).log/og;
			#my $nenufaar_id = $1;
			my ($nenufaar_ana, $nenufaar_id) = U2_modules::U2_subs_3::get_nenufaar_id("$ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/data/$CLINICAL_EXOME_BASE_DIR/$run");
			my $data_path = "$ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/data/$CLINICAL_EXOME_BASE_DIR/$run/$id$number/$nenufaar_id/";
			my $global_path = "$ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/data/$CLINICAL_EXOME_BASE_DIR/";
			#print $q->p(`ls $data_path`);
			#get all metrics
			my ($aligned_bases, $ontarget_bases, $aligned_reads, $insert_size_median, $mean_doc, $twentyx_doc, $fiftyx_doc, $snp_num, $indel_num, $duplicates, $snp_tstv, $insert_size_sd);
			my $metrics = {#u2label => [file_name, filelabel, u2table, value]
				'aligned_bases' => ['multiqc_data/multiqc_picard_HsMetrics.txt', 'PF_BASES_ALIGNED', 'miseq_analysis', ''],
				'ontarget_bases' => ['multiqc_data/multiqc_picard_HsMetrics.txt', 'ON_TARGET_BASES', 'miseq_analysis', ''],
				'aligned_reads' => ["$id$number/$nenufaar_id/genome_results.txt", 'number of mapped reads', 'miseq_analysis', ''],
				'insert_size_median' => ["$id$number/$nenufaar_id/genome_results.txt", 'median insert size', 'miseq_analysis', ''],
				'mean_doc' => ['multiqc_data/multiqc_picard_HsMetrics.txt', 'MEAN_TARGET_COVERAGE', 'miseq_analysis', ''],
				'twentyx_doc' => ['multiqc_data/multiqc_picard_HsMetrics.txt', 'PCT_TARGET_BASES_20X', 'miseq_analysis', ''],
				'fiftyx_doc' => ['multiqc_data/multiqc_picard_HsMetrics.txt', 'PCT_TARGET_BASES_50X', 'miseq_analysis', ''],
				'snp_num' => ['multiqc_data/multiqc_gatk_varianteval.txt', 'snps', 'miseq_analysis', ''],
				'duplicates' => ['multiqc_data/multiqc_picard_HsMetrics.txt', 'PCT_PF_UQ_READS', 'miseq_analysis', ''],
				'snp_tstv' => ['multiqc_data/multiqc_gatk_varianteval.txt', 'known_titv', 'miseq_analysis', ''],
				#'insert_size_sd' => ["$id$number/$nenufaar_id/genome_results.txt", 'std insert size', 'miseq_analysis', ''], r�sultats tr�s surprenants de qualimap
			};
			my $insert_metrics = "INSERT INTO miseq_analysis (num_pat, id_pat, type_analyse, run_id, filter, ";
			my ($col, $val);
			foreach my $u2_key (sort keys (%{$metrics})) {
				$col .= "$u2_key, ";
				if ($metrics->{$u2_key}->[0] =~ /multiqc/o) {
					$val .= "'".U2_modules::U2_subs_2::get_raw_detail_ce($global_path, $run, $id.$number, $metrics->{$u2_key}->[1], $metrics->{$u2_key}->[0])."', ";
					#$metrics->{$u2_key}->[3] = U2_modules::U2_subs_2::get_raw_detail_ce($global_path, $run, $id.$number, $metrics->{$u2_key}->[1], $metrics->{$u2_key}->[0]);
				}
				else {
					$val .= "'".U2_modules::U2_subs_2::get_raw_detail_ce_qualimap($global_path, $run, $id.$number, $metrics->{$u2_key}->[1], $metrics->{$u2_key}->[0])."', ";
					#$metrics->{$u2_key}->[3] = U2_modules::U2_subs_2::get_raw_detail_ce_qualimap($global_path, $run, $id.$number, $metrics->{$u2_key}->[1], $metrics->{$u2_key}->[0]);
				}
				#print $q->p($u2_key.'-'.$metrics->{$u2_key}->[1].'-'.$metrics->{$u2_key}->[3]);
			}
			chop($col);chop($col);
			chop($val);chop($val);
			$insert_metrics .= "$col) VALUES ('$number', '$id', '$analysis', '$run', '$filter', $val);";
			#print $q->p($insert_metrics);
			################## UNCOMMENT
			$dbh->do($insert_metrics);
			################## UNCOMMENT



			#foreach my $key (keys %{$interval}) {print "$key<br/>"}

			#now get left normed vcf and treat it
			open F, $data_path."$id$number.final.vcf.norm.vcf" or die "can't find normalised vcf for $id$number $!";
			my ($i, $j, $k) = (0, 0, 0);
			VCF: while (<F>) {
				#print $_;
				#mutalyzer
				if ($_ !~ /^#/o) {
					chomp;
					$k++;
					my @list = split(/\t/);
					print STDERR '.';
					my $variant_input = U2_modules::U2_subs_3::insert_variant(\@list, 'AB', $dbh, 'nextseq', $number, $id, $analysis, $interval, $soap, $date, $user);
					if ($variant_input eq '1') {$i++;next VCF}#variant added
					elsif ($variant_input eq '2') {next VCF}#variant in unknown region
					elsif ($variant_input eq '3') {$i++;$j++;next VCF}#variant created and added
					elsif ($variant_input =~ /^MANUAL/o) {$manual .= $variant_input;next VCF}
					elsif ($variant_input =~ /^NOTINSERTED/o) {$not_inserted .= $variant_input;next VCF}
					elsif ($variant_input =~ /^FOLLOW/o) {$to_follow .= $variant_input;$i++;$j++;next VCF}
					elsif ($variant_input =~ /^MUTALYZERNOANSWER/o) {$mutalyzer_no_answer .= $variant_input;next VCF}
					elsif ($variant_input =~ /^NEWVAR/o) {$new_var .= $variant_input;next VCF}
					else {print "$variant_input<br/>"}
				}
			}
			close F;

			$general .= "Insertion for $id$number:\n\n- $i/$k variants (".(sprintf('%.2f', ($i/$k)*100))."%) have been automatically inserted,\nincluding $j new variants that have been successfully created\n\n";
			my $valid = "UPDATE miseq_analysis SET valid_import = 't' WHERE id_pat = '$id' AND num_pat = '$number' AND type_analyse= '$analysis';";
			#print "$valid<br/>";
			########UNCOMMENT WHEN READY
			$dbh->do($valid);
		}
		########UNCOMMENT WHEN READY
		U2_modules::U2_subs_2::send_manual_mail($user, $manual, $not_inserted, $run, $general, $mutalyzer_no_answer, $to_follow);
		$q->redirect("patient_file.pl?sample=$sample_end");
		#print "$general<br/>$manual<br/>$not_inserted<br/>$mutalyzer_no_answer<br/>$to_follow<br/>";
	}
}
else {U2_modules::U2_subs_1::standard_error('13', $q)}

##Basic end of USHVaM 2 perl scripts:

U2_modules::U2_subs_1::standard_end_html($q);

print $q->end_html();

exit();

##End of Basic end


##specific subs for current script
