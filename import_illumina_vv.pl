BEGIN {delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV', 'PATH'};}

use strict;
#use CGI;#in startup.pl
#use DBI;
#use AppConfig qw(:expand :argcount);
use Net::OpenSSH;
use SOAP::Lite;
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
#		Import script for Illumina experiment


##Basic init of USHVaM 2 perl scripts:
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

##end of Basic init
my $ABSOLUTE_HTDOCS_PATH = $config->ABSOLUTE_HTDOCS_PATH();
my $ANALYSIS_NGS_DATA_PATH = $config->ANALYSIS_NGS_DATA_PATH();
my $ANALYSIS_MISEQ_FILTER = $config->ANALYSIS_MISEQ_FILTER();
my $PERL_SCRIPTS_HOME = $config->PERL_SCRIPTS_HOME();
#specific args for remote login to RS
my $SSH_RACKSTATION_BASE_DIR = $config->SSH_RACKSTATION_BASE_DIR();
my $SSH_RACKSTATION_MINISEQ_BASE_DIR = $config->SSH_RACKSTATION_MINISEQ_BASE_DIR();
#my $SSH_RACKSTATION_IP = $config->SSH_RACKSTATION_IP();
#use automount to replace ssh
my $ABSOLUTE_HTDOCS_PATH = $config->ABSOLUTE_HTDOCS_PATH();
my $RS_BASE_DIR = $config->RS_BASE_DIR();
my $SSH_RACKSTATION_FTP_BASE_DIR = $config->SSH_RACKSTATION_FTP_BASE_DIR();
my $SSH_RACKSTATION_MINISEQ_FTP_BASE_DIR = $config->SSH_RACKSTATION_MINISEQ_FTP_BASE_DIR();
$SSH_RACKSTATION_FTP_BASE_DIR = $ABSOLUTE_HTDOCS_PATH.$RS_BASE_DIR.$SSH_RACKSTATION_FTP_BASE_DIR;
$SSH_RACKSTATION_MINISEQ_FTP_BASE_DIR = $ABSOLUTE_HTDOCS_PATH.$RS_BASE_DIR.$SSH_RACKSTATION_MINISEQ_FTP_BASE_DIR;


#hg38 transition variable for postgresql 'start_g' segment field
my ($postgre_start_g, $postgre_end_g) = ('start_g', 'end_g');  #hg19 style


my $step = U2_modules::U2_subs_1::check_step($q);

if ($step && $step == 2) {
		
	my $analysis = U2_modules::U2_subs_1::check_analysis($q, $dbh, 'form');
	my $run = U2_modules::U2_subs_1::check_illumina_run_id($q);
	
	my $query = "SELECT filtering_possibility FROM valid_type_analyse WHERE type_analyse = '$analysis';";
	my $res = $dbh->selectrow_hashref($query);
	my $filtered = $res->{'filtering_possibility'};
	#sample and filters do not arrive the same way
	my %sample_hash = U2_modules::U2_subs_2::build_sample_hash($q, $analysis, $filtered);
	
	#test mutalyzer
	if (U2_modules::U2_subs_1::test_mutalyzer() != 1) {U2_modules::U2_subs_1::standard_error('23', $q)}
	
	#print $q->start_p({'class' => 'center'}), $q->start_big(), $q->span("Automatic treatment of run "), $q->strong("$run ($analysis)"), $q->span(":"), $q->end_big(), $q->end_p();
	
	## creates mutalyzer client object
	### old way to connect to mutalyzer deprecated September 2014
	#my $soap = SOAP::Lite->new(proxy => 'http://mutalyzer.nl/2.0/services');
	#$soap->defaul_ns('urn:https://mutalyzer.nl/services/?wsdl');
	#$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME}=0;
	my $soap = SOAP::Lite->uri('http://mutalyzer.nl/2.0/services')->proxy('https://mutalyzer.nl/services/?wsdl');
	my $call;
	
	#we have the run id, the samples to import and the filter to record.... Let's go
	#ssh again to the NAS, then scp files
	#in Data/Intensities/BaseCalls/Alignement(\d)* (we take the last) 
	#sampleID_SXX.coverage.csv => copy and create link + transform into bed + add stddev/mean column in the end
	#sampleID_SXX.enrichment_summary.csv => get run info per patient + stats
	#sampleID_SXX.gaps.csv => link + stats
	#sampleID_SXX.vcf the big one => annotate mutalyzer (beware of del ins) and keep DOC
	
	#connect to NAS
	my $ssh;
	opendir (DIR, $SSH_RACKSTATION_FTP_BASE_DIR);#first attempt to wake up autofs in case of unmounted
	my $access_method = 'autofs';
    opendir (DIR, $SSH_RACKSTATION_FTP_BASE_DIR) or $access_method = 'ssh';
	if ($access_method eq 'ssh') {$ssh = U2_modules::U2_subs_1::nas_connexion('-', $q)}
	#1st get last alignment directory
	#my $dirlist = $ssh->capture("ls -d $SSH_RACKSTATION_BASE_DIR/$run/Data/Intensities/BaseCalls/Alignment*");
	#  <AlignmentFolder>\\194.167.35.140\data\MiSeqDx\140228_M70106_0001_000000000-A81UN\Data\Intensities\BaseCalls\Alignment2</AlignmentFolder>

	#my $alignment_dir = $ssh->capture("grep -Eo \"<AlignmentFolder>\\\\".$SSH_RACKSTATION_IP."\\data\\MiSeqDx\\".$run."\\Data\\Intensities\\BaseCalls\\Alignment\d*<\/AlignmentFolder>\" $SSH_RACKSTATION_BASE_DIR/$run/CompletedJobInfo.xml");
	
	###TO BE CHANGED 4 MINISEQ
	###<AnalysisFolder>D:\Illumina\MiniSeq Sequencing Temp\160620_MN00265_0001_A000H02LJN\Alignment_8\20160621_155804</AnalysisFolder>
	### get alignemnt with _ AND subdir with date
	#MINISEQ change get instrument type
	my ($instrument, $instrument_path) = ('miseq', 'MiSeqDx/USHER');
	if ($analysis =~ /MiniSeq-\d+/o) {$instrument = 'miniseq';$instrument_path='MiniSeq';$SSH_RACKSTATION_BASE_DIR = $SSH_RACKSTATION_MINISEQ_BASE_DIR}
	my $alignment_dir;
				
	if ($instrument eq 'miseq') {
		#$alignment_dir = `grep -Eo \"AlignmentFolder>.+\\Alignment[0-9]*<\" $ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/data/$instrument_path/$run/CompletedJobInfo.xml`;
		#old fashioned replaced with autofs 21/12/2016
		if ($access_method eq 'autofs') {
			$alignment_dir = `grep -Eo "AlignmentFolder>.+\\Alignment[0-9]*<" $SSH_RACKSTATION_FTP_BASE_DIR/$run/CompletedJobInfo.xml`;
			$alignment_dir =~ /\\(Alignment\d*)<$/o;
			$alignment_dir = $1;
			$alignment_dir = "$SSH_RACKSTATION_FTP_BASE_DIR/$run/Data/Intensities/BaseCalls/$alignment_dir";
		}
		else {
			$alignment_dir = $ssh->capture("grep -Eo \"AlignmentFolder>.+\\Alignment[0-9]*<\" $SSH_RACKSTATION_BASE_DIR/$run/CompletedJobInfo.xml");
			$alignment_dir =~ /\\(Alignment\d*)<$/o;
			$alignment_dir = $1;
			$alignment_dir = "$SSH_RACKSTATION_BASE_DIR/$run/Data/Intensities/BaseCalls/$alignment_dir";
		}
	}
	elsif ($instrument eq 'miniseq') {
		$SSH_RACKSTATION_FTP_BASE_DIR = $SSH_RACKSTATION_MINISEQ_FTP_BASE_DIR;
		#$alignment_dir = `grep -Eo \"AlignmentFolder>.+\\Alignment_?[0-9]*.+<\" $ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/data/$instrument_path/$run/CompletedJobInfo.xml`;
		#old fashioned replaced with autofs 21/12/2016
		if ($access_method eq 'autofs') {
			$alignment_dir = `grep -Eo "AlignmentFolder>.+\\Alignment_?[0-9]*.+<" $SSH_RACKSTATION_FTP_BASE_DIR/$run/CompletedJobInfo.xml`;
			#print "1-$alignment_dir<br/>";
			$alignment_dir =~ /\\(Alignment_?\d*.+)<$/o;
			$alignment_dir = $1;
			$alignment_dir =~ s/\\/\//og;
			$alignment_dir = "$SSH_RACKSTATION_FTP_BASE_DIR/$run/$alignment_dir";
		}
		else {
			$alignment_dir = $ssh->capture("grep -Eo \"AlignmentFolder>.+\\Alignment_?[0-9]*.+<\" $SSH_RACKSTATION_BASE_DIR/$run/CompletedJobInfo.xml");
			$alignment_dir =~ /\\(Alignment_?\d*.+)<$/o;
			$alignment_dir = $1;
			$alignment_dir =~ s/\\/\//og;
			$alignment_dir = "$SSH_RACKSTATION_BASE_DIR/$run/$alignment_dir";
		}
	}
	my $report = 'aggregate.report.pdf';
		#($report, $coverage, $enrichment, $gaps, $vcf, $sample_report) = ('aggregate.report.pdf', $sampleid.'_S*.coverage.csv', $sampleid.'_S*.enrichment_summary.csv', $sampleid.'_S*.gaps.csv', $sampleid.'_S*.vcf', $sampleid.'_S*.report.pdf');
	#}
	#elsif ($instrument eq 'miniseq') {###TO BE CHANGED 4 MINISEQ file names unknown at date 01/07/2016
		#$location = "$SSH_RACKSTATION_BASE_DIR/$run/$alignment_dir/";
	#	$report = 'aggregate.report.pdf';
		#($report, $coverage, $enrichment, $gaps, $vcf, $sample_report) = ('aggregate.report.pdf', $sampleid.'_S*.coverage.csv', $sampleid.'_S*.summary.csv', $sampleid.'_S*.gaps.csv', $sampleid.'_S*.vcf', $sampleid.'_S*.report.pdf');
	#}
	#END ERASE
	#print "$ABSOLUTE_HTDOCS_PATH$ANALYSIS_NGS_DATA_PATH$analysis/$run";exit;
	mkdir "$ABSOLUTE_HTDOCS_PATH$ANALYSIS_NGS_DATA_PATH$analysis/$run";
	#$ssh->scp_get({glob => 1, copy_attrs => 1}, $location.$report, "$ABSOLUTE_HTDOCS_PATH$ANALYSIS_NGS_DATA_PATH$analysis/$run/aggregate.report.pdf") or die $!;
	#print $alignment_dir.'/'.$report;exit;
	if ($access_method eq 'autofs') {system("cp -f '$alignment_dir/$report' '$ABSOLUTE_HTDOCS_PATH$ANALYSIS_NGS_DATA_PATH$analysis/$run/aggregate.report.pdf'")}
	else {
		my $success = $ssh->scp_get({glob => 1, copy_attrs => 1}, $alignment_dir.'/'.$report, "$ABSOLUTE_HTDOCS_PATH$ANALYSIS_NGS_DATA_PATH$analysis/$run/aggregate.report.pdf");
		if ($success != 1) {if ($! !~ /File exists/o) {U2_modules::U2_subs_1::standard_error('22', $q)}}
	}
	#my $success = $ssh->scp_get({glob => 1, copy_attrs => 1}, $alignment_dir.'/'.$report, "$ABSOLUTE_HTDOCS_PATH$ANALYSIS_NGS_DATA_PATH$analysis/$run/aggregate.report.pdf");
	#print STDERR "0-$success--\n";
	
	
	#################################UNCOMMENT when sub
	#create roi hash
	my $new_var  = '';
	my $interval = U2_modules::U2_subs_3::build_roi($dbh);
	my ($general, $sample_end, $message) = ('', '', '');#$general global data for final email, $sample_end last treated patient for redirection
	while (my ($sampleid, $filter) = each(%sample_hash)) {
		#print "$key-$value<br/>";
		
		my ($report, $coverage, $enrichment, $gaps, $vcf, $sample_report);
		if ($instrument eq 'miseq') {
			( $coverage, $enrichment, $gaps, $vcf, $sample_report) = ($sampleid.'_S*.coverage.csv', $sampleid.'_S*.enrichment_summary.csv', $sampleid.'_S*.gaps.csv', $sampleid.'_S*.vcf', $sampleid.'_S*.report.pdf');
		}
		elsif ($instrument eq 'miniseq') {###TO BE CHANGED 4 MINISEQ file names unknown at date 01/07/2016
			( $coverage, $enrichment, $gaps, $vcf, $sample_report) = ($sampleid.'_S*.coverage.csv', $sampleid.'_S*.summary.csv', $sampleid.'_S*.gaps.csv', $sampleid.'_S*.vcf', $sampleid.'_S*.report.pdf');
		}
		
		
		
		
		my ($id, $number) = U2_modules::U2_subs_1::sample2idnum($sampleid, $q);
		$sample_end = $sampleid;
		my $insert;
		print STDERR "\nInitiating $id$number with transfer method: $access_method..";
		#loop 28-112-121 genes
		$query = "SELECT nom FROM gene WHERE \"$analysis\" = 't' ORDER BY nom[1];";
		my $sth = $dbh->prepare($query);
		my $res = $sth->execute();
		
		while (my $result = $sth->fetchrow_hashref()) {
			$insert .= "INSERT INTO analyse_moleculaire (num_pat, id_pat, nom_gene, type_analyse, date_analyse, analyste, technical_valid) VALUES ('$number', '$id', '{\"$result->{'nom'}[0]\",\"$result->{'nom'}[1]\"}', '$analysis', '$date', '".$user->getName()."','t');";
		}
		#######UNCOMMENT WHEN DONE!!!!!!!
		$dbh->do($insert);
		
		#print "$insert\n"
		
		mkdir "$ABSOLUTE_HTDOCS_PATH$ANALYSIS_NGS_DATA_PATH$analysis/$sampleid";
		#my $success;
		if ($access_method eq 'autofs') {
			system("cp -f $alignment_dir/$coverage '$ABSOLUTE_HTDOCS_PATH$ANALYSIS_NGS_DATA_PATH$analysis/$sampleid/$sampleid.coverage.tsv'");
			#print STDERR "1-$success--\n";
			system("cp -f $alignment_dir/$enrichment '$ABSOLUTE_HTDOCS_PATH$ANALYSIS_NGS_DATA_PATH$analysis/$sampleid/$sampleid.enrichment_summary.csv'");
			system("cp -f $alignment_dir/$gaps '$ABSOLUTE_HTDOCS_PATH$ANALYSIS_NGS_DATA_PATH$analysis/$sampleid/$sampleid.gaps.tsv'");
			system("cp -f $alignment_dir/$vcf '$ABSOLUTE_HTDOCS_PATH$ANALYSIS_NGS_DATA_PATH$analysis/$sampleid/$sampleid.vcf'");
			system("cp -f $alignment_dir/$sample_report '$ABSOLUTE_HTDOCS_PATH$ANALYSIS_NGS_DATA_PATH$analysis/$sampleid/$sampleid.report.pdf'");
			#if ($success == 1 || $! =~ /File exists/o) {$success = system("cp -f $alignment_dir/$enrichment '$ABSOLUTE_HTDOCS_PATH$ANALYSIS_NGS_DATA_PATH$analysis/$sampleid/$sampleid.enrichment_summary.csv'")}
			#else {print STDERR "2-$success--\n";U2_modules::U2_subs_1::standard_error('22', $q)}
			#if ($success == 1 || $! =~ /File exists/o) {$success = system("cp -f $alignment_dir/$gaps '$ABSOLUTE_HTDOCS_PATH$ANALYSIS_NGS_DATA_PATH$analysis/$sampleid/$sampleid.gaps.tsv'")}
			#else {print STDERR "3-$success--\n";U2_modules::U2_subs_1::standard_error('22', $q)}
			#if ($success == 1 || $! =~ /File exists/o) {$success = system("cp -f $alignment_dir/$vcf '$ABSOLUTE_HTDOCS_PATH$ANALYSIS_NGS_DATA_PATH$analysis/$sampleid/$sampleid.vcf'")}
			#else {print STDERR "4-$success--\n";U2_modules::U2_subs_1::standard_error('22', $q)}
			#if ($success == 1 || $! =~ /File exists/o) {system("cp -f $alignment_dir/$sample_report '$ABSOLUTE_HTDOCS_PATH$ANALYSIS_NGS_DATA_PATH$analysis/$sampleid/$sampleid.report.pdf'")}
			#else {print STDERR "5-$success--\n";U2_modules::U2_subs_1::standard_error('22', $q)}
		}
		else {
			my $success = $ssh->scp_get({glob => 1, copy_attrs => 1}, $alignment_dir.'/'.$coverage, "$ABSOLUTE_HTDOCS_PATH$ANALYSIS_NGS_DATA_PATH$analysis/$sampleid/$sampleid.coverage.tsv");
			if ($success == 1) {$success = $ssh->scp_get({glob => 1, copy_attrs => 1}, $alignment_dir.'/'.$enrichment, "$ABSOLUTE_HTDOCS_PATH$ANALYSIS_NGS_DATA_PATH$analysis/$sampleid/$sampleid.enrichment_summary.csv")}
			else {U2_modules::U2_subs_1::standard_error('22', $q)}
			if ($success == 1) {$success = $ssh->scp_get({glob => 1, copy_attrs => 1}, $alignment_dir.'/'.$gaps, "$ABSOLUTE_HTDOCS_PATH$ANALYSIS_NGS_DATA_PATH$analysis/$sampleid/$sampleid.gaps.tsv")}
			else {U2_modules::U2_subs_1::standard_error('22', $q)}
			if ($success == 1) {$success = $ssh->scp_get({glob => 1, copy_attrs => 1}, $alignment_dir.'/'.$vcf, "$ABSOLUTE_HTDOCS_PATH$ANALYSIS_NGS_DATA_PATH$analysis/$sampleid/$sampleid.vcf")}
			else {U2_modules::U2_subs_1::standard_error('22', $q)}
			if ($success == 1) {$ssh->scp_get({glob => 1, copy_attrs => 1}, $alignment_dir.'/'.$sample_report, "$ABSOLUTE_HTDOCS_PATH$ANALYSIS_NGS_DATA_PATH$analysis/$sampleid/$sampleid.report.pdf")}
			else {U2_modules::U2_subs_1::standard_error('22', $q)}
		}
		
		system("chmod 750 $ABSOLUTE_HTDOCS_PATH$ANALYSIS_NGS_DATA_PATH$analysis/$sampleid/$sampleid.*");
		
		
		
		print STDERR "Done file import...";
		
		#now we work locally
		#coverage from csv to bedgraph
		my $bedgraph = "track type=\"bedGraph\" name=\"$analysis-$sampleid\" description=\"$analysis run for $sampleid\" visibility=full autoScale=on yLineOnOff=on\n";
		my $new_tsv;
		open(F, "$ABSOLUTE_HTDOCS_PATH$ANALYSIS_NGS_DATA_PATH$analysis/$sampleid/$sampleid.coverage.tsv") or die $!;
		while (<F>) {
			if ($_ =~ /^#(Enrichment|Reads)/o) {next}
			$new_tsv .= $_;
			$new_tsv =~ s/\r\n$//o;
			if ($_ =~ /^#Chromosome/o) {$new_tsv =~ s/MeanCoverage/$id$number/;$new_tsv .= "\tStdDev/Mean";}			
			elsif ($_ !~ /#/o) {
				my @line = split(/,/);
				my ($sigma, $doc, $chr, $begin, $end) = (pop(@line), pop(@line), shift(@line), shift(@line), shift(@line));
				$bedgraph .= "$chr\t$begin\t$end\t".sprintf('%.0f', $doc)."\n";
				if ($doc != 0) {$new_tsv .= "\t".(sprintf('%.2f', ($sigma/$doc)))}
				else {$new_tsv .= "\t0.00"}
			}
			$new_tsv .= "\n";
		}
		close F;
		
		$new_tsv =~ s/,/\t/og;
		$new_tsv =~ s/\./,/og;
		
		open(G, ">$ABSOLUTE_HTDOCS_PATH$ANALYSIS_NGS_DATA_PATH$analysis/$sampleid/$sampleid.coverage.tsv") or die $!;
		print G $new_tsv;
		close G;
		open(G, ">$ABSOLUTE_HTDOCS_PATH$ANALYSIS_NGS_DATA_PATH$analysis/$sampleid/$sampleid.$analysis.bedgraph") or die $!;
		print G $bedgraph;
		close G;
		
		
		print STDERR "Done coverage file...";
		
		###TO BE CHANGED 4 MINISEQ
		###finally labels are the same between MSR2.6 and LRM1.2
		
		#enrichment_summary
		my $enrichment = {
			#"Total aligned bases read 1"		=>	["bases_read1", 0], #miniseq
			#"Total aligned bases read 2"		=>	["bases_read2", 0], #miniseq
			#"Total aligned read 1"			=>	["aligned_read1", 0], #miniseq
			#"Total aligned read 2"			=>	["aligned_read2", 0], #miniseq
			"Total aligned bases"			=>	["aligned_bases", 0], #miseq
			"Targeted aligned bases"		=>	["ontarget_bases", 0], #to check 4 miniseq
			"Percent duplicate paired reads"	=>	["duplicates", 0],
			"Total aligned reads"			=>	["aligned_reads", 0], #miseq
			"Targeted aligned reads"		=>	["ontarget_reads", 0], #to check 4 miniseq
			"Mean region coverage depth"		=>	["mean_doc", 0], #miseq
			#"Mean coverage"				=>	["mean_doc", 0], #miniseq
			"Target coverage at 20X"		=>	["twentyx_doc", 0], #to check 4 miniseq
			"Target coverage at 50X"		=>	["fiftyx_doc", 0], #to check 4 miniseq
			"Fragment length median"		=>	["insert_size_median", 0],
			"Fragment length SD"			=>	["insert_size_sd", 0],
			"SNVs"					=>	["snp_num", 0],
			"SNV Ts/Tv ratio"			=>	["snp_tstv", 0],
			"Indels"				=>	["indel_num", 0],
		};
		
		
		###TO BE CHANGED 4 MINISEQ
		### check if file name changed / ok file renamed on copy and regex changed and does not include ':'
		
		open(F, "$ABSOLUTE_HTDOCS_PATH$ANALYSIS_NGS_DATA_PATH$analysis/$sampleid/$sampleid.enrichment_summary.csv") or die "$ABSOLUTE_HTDOCS_PATH$ANALYSIS_NGS_DATA_PATH$analysis/$sampleid/$sampleid.enrichment_summary.csv - $!";         
		while (<F>) {
			chomp;
			#print "-$_-".$q->br();
			if (/^([\w\s\/]+):?,([\d\.]+)%?\s?$/o) {
				my ($current, $value) = ($1, $2);
				if (exists($enrichment->{$current})) {$enrichment->{$current}->[1] = $value}
				#print 'hello, hello!!!!!';
			}			
		}
		close F;
		#build insert query;
		
		my ($fields, $values) = ("num_pat, id_pat, type_analyse, run_id, filter, ", "'$number', '$id', '$analysis', '$run', '$filter', ");
		#4 miniseq
		#if ($instrument eq 'miniseq') {
		#	$enrichment->{'Total aligned bases'}->[1] = $enrichment->{'Total aligned read 1'}->[1] + $enrichment->{'Total aligned read 2'}->[1];
		#	$enrichment->{'Total aligned reads'}->[1] = $enrichment->{'Total aligned bases read 1'}->[1] + $enrichment->{'Total aligned bases read 2'}->[1];
		#	($enrichment->{'Total aligned bases read 1'}->[1], $enrichment->{'Total aligned bases read 2'}->[1], $enrichment->{'Total aligned bases read 1'}->[1], $enrichment->{'Total aligned bases read 2'}->[1]) = (0, 0, 0, 0);
		#}
		
		
		foreach my $label (keys(%{$enrichment})) {
			if ($enrichment->{$label}->[1] > 0) {
				$fields .= shift(@{$enrichment->{$label}}).", ";
				$values .= "'".shift(@{$enrichment->{$label}})."', ";
			}
		}
		$fields =~ s/, $//o;
		$values =~ s/, $//o;
		$insert = "INSERT INTO miseq_analysis ($fields) VALUES ($values);\n";
		#print $insert;exit;

		
		$dbh->do($insert);
		#print "$insert\n";
		
		#gaps -> localise gaps (gene, exon/intron) + gap size
		$new_tsv = '';
		my ($chr, $gapstart, $gapstop, $gapsize);
		open(F, "$ABSOLUTE_HTDOCS_PATH$ANALYSIS_NGS_DATA_PATH$analysis/$sampleid/$sampleid.gaps.tsv") or die $!;
		while (<F>) {			
			$new_tsv .= $_;  #### for unknown reasons this file is generated with CRLF 
			$new_tsv =~ s/\r\n$//og;
			
			if ($_ =~ /#Chromosome/o) {$new_tsv .= "\tGapsize\tGapGeneBegin\tGapSegmentBegin\tGapSegmentBeginNumber\tGapGeneEnd\tGapSegmentEnd\tGapSegmentEndNumber"}
			elsif ($_ !~ /#/o) {
				my @line = split(/,/);
				my ($chr, $gapstart, $gapstop) = (shift(@line), shift(@line), shift(@line));
				$chr =~ s/chr//o;
				$new_tsv .= "\t".(($gapstop-$gapstart) + 1);
				#my $gapsize = ($gapend-$gapstart) + 1;
				#get start, end positions - deal with putative unfound regions
				$new_tsv .= &search_position($chr, $gapstart);
				$new_tsv .= &search_position($chr, $gapstop);
			}
			$new_tsv .= "\n";
		}
		$new_tsv =~ s/,/\t/og;
		close F;
		open(G, ">$ABSOLUTE_HTDOCS_PATH$ANALYSIS_NGS_DATA_PATH$analysis/$sampleid/$sampleid.gaps.tsv") or die $!;
		print G $new_tsv;
		close G;
		undef $new_tsv;
		
		print STDERR "Done gaps file...\n";
	
		
		
		#vcf
		$insert = '';
		my ($var_chr, $var_pos, $rs_id, $var_ref, $var_alt, $var_vf, $var_dp, $var_filter, $null, $format);
		my ($i, $j, $k) = (0, 0, 0);
		open(F, "$ABSOLUTE_HTDOCS_PATH$ANALYSIS_NGS_DATA_PATH$analysis/$sampleid/$sampleid.vcf") or die $!;
		VCF: while (<F>) {
			#if ($_ !~ /#/o && $_ =~ /GI=/o) {#we remove non mappable variants on our design
			if ($_ !~ /#/o) {			
				chomp;
				$k++;
				my @list = split(/\t/);
				my $message_tmp;
				#################################sub begins - Mutalyzer
				#my $variant_input = U2_modules::U2_subs_3::insert_variant(\@list, 'VF', $dbh, $instrument, $number, $id, $analysis, $interval, $soap, $date, $user);
				##print "$variant_input<br/>";
				#print STDERR '.';
				#if ($variant_input == 1) {$i++;next VCF}#variant added
				#elsif ($variant_input == 2) {next VCF}#variant in unknown region
				#elsif ($variant_input == 3) {$i++;$j++;next VCF}#variant created and added
				#elsif ($variant_input =~ /^MANUAL/o) {$manual .= $variant_input;next VCF}
				#elsif ($variant_input =~ /^NOTINSERTED/o) {$not_inserted .= $variant_input;next VCF}
				#elsif ($variant_input =~ /^FOLLOW/o) {$to_follow .= $variant_input;next VCF}
				#elsif ($variant_input =~ /^MUTALYZERNOANSWER/o) {$mutalyzer_no_answer .= $variant_input;next VCF}
				#elsif ($variant_input =~ /^NEWVAR/o) {$new_var .= $variant_input;$i++;$j++;next VCF}
				#else {print "$variant_input<br/>"}
				
				##################################
				
				################################## VV
				
				my ($var_chr, $var_pos, $rs_id, $var_ref, $var_alt, $null, $var_filter) = (shift(@list), shift(@list), shift(@list), shift(@list), shift(@list), shift(@list), shift(@list));
				my ($var_dp, $var_vf);
				
				my @format_list = split(/:/, pop(@list));
					
				#compute vf_index
				my @label_list = split(/:/, pop(@list));
				my $label_count = 0;
				my ($vf_index, $dp_index, $ad_index) = (7, 2, 3);#LRM values
				my ($vf_tag, $dp_tag, $ad_tag) = ('VF', 'DP', 'AD');
				foreach(@label_list) {
					#print "$_<br/>";
					if (/$vf_tag/) {$vf_index = $label_count}
					elsif (/$dp_tag/) {$dp_index = $label_count}
					elsif (/$ad_tag/) {$ad_index = $label_count}
					$label_count ++;                                        
				}
				($var_dp, $var_vf) = ($format_list[$dp_index], $format_list[$vf_index]);
				if ($var_vf =~ /,/o) {#multiple AB after splitting; is it VCF compliant? comes fomr IURC script to add AB to all variants in nenufaar
					#we need to recompute with AD
					my @ad_values = split(/,/, $format_list[$ad_index]);
					$var_vf = sprintf('%.2f', (pop(@ad_values)/$var_dp));
				}
				#print "$var_chr, $var_pos, $rs_id, $var_ref, $var_alt, $null, $var_filter, $var_dp, $var_vf<br/>";
				
				#we check wether the variant is in our genes or not
				#we just query ushvam2
				#if  ($var_chr =~ /^chr([\dXYM]{1,2})$/o) {$var_chr = $1}
				if  ($var_chr =~ /^chr($U2_modules::U2_subs_1::CHR_REGEXP)$/o) {$var_chr = $1}
				
			
				my $interest = 0;
				foreach my $key (keys %{$interval}) {
					$key =~ /(\d+)-(\d+)/o;
					#print STDERR "$var_chr-$var_pos-$interval->{$key}-$1-$2\n";
					if ($var_pos >= $1 && $var_pos <= $2) {#good interval, check good chr			
						if ($var_chr eq $interval->{$key}) {$interest = 1;last;}
					}
				}
				if ($interest == 0) {
					if ($analysis =~ /Min?i?Seq-\d+/o) {
						$message .= "$id$number: ERROR: Out of U2 ROI for $var_chr-$var_pos-$var_ref-$var_alt\n";next VCF;
					}
					else {
						next VCF;#variant in unknown region
					}
				}#we deal only with variants located in genes u2 knows about
				#deal with the status case
				my ($status, $allele) = ('heterozygous', 'unknown');
				if ($var_vf >= 0.8) {($status, $allele) = ('homozygous', 'both')}
				if ($instrument eq 'miniseq' && $var_vf < 0.2) {###TO BE REMOVED IF LRM CORRECTED
					if ($var_filter eq 'PASS') {$var_filter = 'LowVariantFreq'}
					else {$var_filter .= ';LowVariantFreq'}
					if ($list[0] =~ /HRun=(\d+);/o) {
						if ($1 >= 8) {
							if ($var_filter eq 'PASS') {$var_filter = 'R8'}
							else {$var_filter .= ';R8'}
						}						
					}		
				}				
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
				my $known_bad_variant = 0;
				#check if variants known for bad annotation already exists
				#if ($first_genomic_var =~ /(del|ins)/o) {
				my $query_gs = "SELECT u2_name FROM gs2variant WHERE gs_name = '$first_genomic_var' AND (reason LIKE 'MiSeq_%' OR reason LIKE 'inv_nt');";
				my $res_gs = $dbh->selectrow_hashref($query_gs);
				if ($res_gs) {$known_bad_variant = 1;$genomic_var = $res_gs->{'u2_name'}}
				
				my $insert = &U2_modules::U2_subs_3::direct_submission($genomic_var, $number, $id, $analysis, $status, $allele, $var_dp, $var_vf, $var_filter, $dbh);
				# print STDERR "Direct submission1: $insert\n";
				if ($insert ne '') {
					# return "INSERT INTO variant2patient (nom_c, num_pat, id_pat, nom_gene, type_analyse, statut, allele, depth, frequency, msr_filter) VALUES ('$res->{'nom'}', '$number', '$id', '{\"$res->{'nom_gene'}[0]\",\"$res->{'nom_gene'}[1]\"}', '$analysis', '$status', '$allele', '$var_dp', '$var_vf', '$var_filter');";
					# get gene from insert then check
					if ($insert =~ /'\{"([^"]+)",/o) {
						my $gene = $1;
						my $query_verif = "SELECT nom FROM gene WHERE \"MiniSeq-158\" = 't' AND nom[1] = '$gene';";
						my $res_verif = $dbh->selectrow_hashref($query_verif);
						# print STDERR "Gene verif1: $res_verif->{'nom'}[0]-$gene";
						if ($res_verif->{'nom'}[0] eq $gene) {
							$dbh->do($insert);
							$j++;
							next VCF;
						}
						else {
							#variant in unwanted region
							$message .= "$id$number: ERROR: Impossible to record variant (unwanted region) $var_chr-$var_pos-$var_ref-$var_alt-$gene-$insert\n";
						}
					}
					else {
						#variant in unwanted region
						$message .= "$id$number: ERROR: Impossible to record variant (BAD REGEXP) $var_chr-$var_pos-$var_ref-$var_alt-$insert\n";
					}
					
				}
				#still here? we try to invert wt & mut
				#if ($genomic_var =~ /(chr[\dXYM]+:g\..+\d+)([ATGC])>([ATCG])/o) {
				# print SDTERR "Before Inv genomic var:$genomic_var\n";
				if ($genomic_var =~ /(chr$U2_modules::U2_subs_1::CHR_REGEXP:g\..+\d+)([ATGC])>([ATCG])/o) {
					my $inv_genomic_var = $1.$3.">".$2;
					# print STDERR "Inv genomic var (inside inv): $inv_genomic_var\n";
					$insert = U2_modules::U2_subs_3::direct_submission($inv_genomic_var, $number, $id, $analysis, $status, $allele, $var_dp, $var_vf, $var_filter, $dbh);
					# print STDERR "Direct submission 2 (inside inv): $insert\n";
					if ($insert ne '') {
						# get gene from insert then check
						if ($insert =~ /'\{"([^"]+)",/o) {
							my $gene = $1;
							my $query_verif = "SELECT nom FROM gene WHERE \"MiniSeq-158\" = 't' AND nom[1] = '$gene';";
							my $res_verif = $dbh->selectrow_hashref($query_verif);
							# print STDERR "Gene verif2: $res_verif->{'nom'}[0]-$gene";
							if ($res_verif->{'nom'}[0] eq $gene) {
								$dbh->do($insert);
								$j++;
								next VCF;
							}
							else {
								#variant in unwanted region
								$message .= "$id$number: ERROR: Impossible to record variant (unwanted region) $var_chr-$var_pos-$var_ref-$var_alt-$gene-$insert\n";
							}
						}
						else {
							#variant in unwanted region
							$message .= "$id$number: ERROR: Impossible to record variant (BAD REGEXP) $var_chr-$var_pos-$var_ref-$var_alt-$insert\n";
						}
					}
				}
	
				#we keep only the first variants if more than 1 e.g. alt = TAA, TA
				if ($var_alt =~ /^([ATCG]+),/) {$var_alt = $1}
				#ok let's deal with VV
				my $vv_results = decode_json(U2_modules::U2_subs_1::run_vv('hg19', "all", "$var_chr-$var_pos-$var_ref-$var_alt", 'VCF'));
				#run variantvalidator API
				#my $vvkey = "$acc_no.$acc_ver:$cdna";
				my ($type_segment, $classe, $var_final, $cdna);
				if ($vv_results ne '0') {
					#find vvkey and cdna
					my ($hashvar, $tmp_message);
					my ($vvkey, $nm_list, $tag) = ('', '', '');
					($tmp_message, $insert, $hashvar, $nm_list, $tag) = &run_vv_results($vv_results, $id, $number, $var_chr, $var_pos, $var_ref, $var_alt, $analysis, $status, $allele, $var_dp, $var_vf, $var_filter, $dbh);
					if ($tmp_message ne '') {$message .= $tmp_message;next VCF}
					elsif ($insert ne '') {
						#print STDERR $k." - ".$insert."\n";
						$dbh->do($insert);
						$j++;
						next VCF;
					}
					
					#foreach my $var (keys %{$vv_results}) {
					#	#my ($nm, $cdna) = split(/:/, $var)[0], split(/:/, $var)[1]);
					#	if ($var eq 'flag' && $vv_results->{$var} eq 'intergenic') {$message .= "$id$number: WARNING: Intergenic variant: $var_chr-$var_pos-$var_ref-$var_alt\n";next VCF}
					#	my ($nm, $acc_ver) = ((split(/[:\.]/, $var))[0], (split(/[:\.]/, $var))[1]);
					#	#print STDERR $nm."\n";
					#	if ($nm =~ /^N[RM]_\d+$/o && (split(/:/, $var))[1] !~ /=/o) {
					#		#$hashvar->{$nm} = [(split(/:/, $var))[1], $acc_ver, ''];#NM => [c., acc_ver, main]
					#		$hashvar->{$nm}->{$acc_ver} = [(split(/:/, $var))[1], $acc_ver, ''];#NM => acc_ver => [c., acc_ver, main]
					#		########
					#		##$hashvar is BAD if vv returns several times the same transcript with different acc no => bug
					#		## Faire un deuxième niveau de clé avec acc_no
					#		########
					#		$nm_list .= " '$nm',";
					#		#get genomic hgvs and check direct submission again
					#		my $tmp_nom_g = '';
					#		my @full_nom_g_19 = split(/:/, $vv_results->{$var}->{'primary_assembly_loci'}->{'hg19'}->{'hgvs_genomic_description'});
					#		if ($full_nom_g_19[0] =~ /NC_0+([^0]{1,2}0?)\.\d{1,2}$/o) {
					#			#print STDERR $full_nom_g_19[0]."\n";
					#			$chr = $1;
					#			if ($chr == 23) {$chr = 'X'}
					#			elsif ($chr == 24) {$chr = 'Y'}
					#			$tmp_nom_g = "chr$chr:".pop(@full_nom_g_19);
					#		}
					#		if ($tmp_nom_g ne '') {
					#			#print STDERR $tmp_nom_g."-\n";
					#			$insert = U2_modules::U2_subs_3::direct_submission($tmp_nom_g, $number, $id, $analysis, $status, $allele, $var_dp, $var_vf, $var_filter, $dbh);
					#			if ($insert ne '') {
					#				$dbh->do($insert);
					#				$j++;
					#				next VCF;
					#			}
					#		}
					#		if ($vv_results->{$var}->{'gene_symbol'} && $tmp_nom_g =~ /.+[di][eun][lps]$/o) {#last test: we directly test c. as sometimes genomic nomenclature can differ in dels/dup
					#			#patches
					#			if ($vv_results->{$var}->{'gene_symbol'} eq 'ADGRV1') {$vv_results->{$var}->{'gene_symbol'} = 'GPR98'}
					#			my $last_query = "SELECT nom_g FROM variant WHERE nom LIKE '".(split(/:/, $var))[1]."%' and nom_gene[1] = '$vv_results->{$var}->{'gene_symbol'}';";
					#			#print STDERR $last_query."\n";
					#			my $res_last = $dbh->selectrow_hashref($last_query);
					#			if ($res_last->{'nom_g'}) {
					#				print STDERR $res_last->{'nom_g'}."\n";
					#				$insert = U2_modules::U2_subs_3::direct_submission($res_last->{'nom_g'}, $number, $id, $analysis, $status, $allele, $var_dp, $var_vf, $var_filter, $dbh);
					#				if ($insert ne '') {
					#					$dbh->do($insert);
					#					$j++;
					#					next VCF;
					#				}
					#			}
					#		}
					#	}
					#	elsif ($nm =~ /^N[RM]_\d+$/o && (split(/:/, $var))[1] =~ /=/o) {
					#		#create a tag for hom WT
					#		$tag = "$id$number: WARNING: Variant $var_alt equals Reference in $nm $var_chr-$var_pos-$var_ref-$var_alt\n"
					#	}
					#	
					#}
					#print STDERR $nm_list."\n";
					if ($nm_list eq '' && $tag eq '') {$message .= "$id$number: WARNING: No suitable NM found for $var_chr-$var_pos-$var_ref-$var_alt-\nVVjson: ".Dumper($vv_results)."- \nRequest URL:https://rest.variantvalidator.org/VariantValidator/variantvalidator/hg19/$var_chr-$var_pos-$var_ref-$var_alt/all?content-type=application/json\n";next VCF}
					elsif ($nm_list eq '' && $tag ne '') {$message .= $tag;next VCF}
					#query U2 to get NM
					chop($nm_list);#remove last ,
					#print STDERR $nm_list."\n";
					my ($acc_no, $acc_ver, $gene, $ng_accno, @possible);
					my $query = "SELECT nom[1] as gene, nom[2] as nm, acc_version, acc_g, main FROM gene WHERE nom[2] IN ($nm_list) ORDER BY main DESC;";
					my $sth = $dbh->prepare($query);
					my $res = $sth->execute();
					while (my $result = $sth->fetchrow_hashref()) {
						#print STDERR $hashvar->{$result->{'nm'}}[1].'-'.$result->{'acc_version'}.'-'.$result->{'main'}."\n";
						($gene, $ng_accno) = ($result->{'gene'}, $result->{'acc_g'});#needed to be sent to create_variant_vv for consistency with other callings of the same sub in different scripts
						#if (exists $hashvar->{$result->{'nm'}} && $hashvar->{$result->{'nm'}}[1] eq $result->{'acc_version'} && $result->{'main'} == 1) {	#best case
						if (exists $hashvar->{$result->{'nm'}} && exists $hashvar->{$result->{'nm'}}->{$result->{'acc_version'}} && $result->{'main'} == 1) {	#best case	
							$hashvar->{$result->{'nm'}}->{$result->{'acc_version'}}[1] = $result->{'main'};
							$vvkey = $result->{'nm'}.".".$result->{'acc_version'}.":".$hashvar->{$result->{'nm'}}->{$result->{'acc_version'}}[0];
							$cdna = $hashvar->{$result->{'nm'}}->{$result->{'acc_version'}}[0];
							#$hashvar->{$result->{'nm'}}[2] = $result->{'main'};												
							#$vvkey = $result->{'nm'}.".".$result->{'acc_version'}.":".$hashvar->{$result->{'nm'}}[0];
							#$cdna = $hashvar->{$result->{'nm'}}[0];
							($acc_no, $acc_ver) = ($result->{'nm'}, $result->{'acc_version'});
							last;
							#print STDERR "VV 1\n";
						}
						#elsif (exists $hashvar->{$result->{'nm'}} && !exists $hashvar->{$result->{'nm'}}->{$result->{'acc_version'}} && $result->{'main'} == 1) {
						#elsif (exists $hashvar->{$result->{'nm'}} && $hashvar->{$result->{'nm'}}[1] ne $result->{'acc_version'} && $result->{'main'} == 1) {
						if (exists $hashvar->{$result->{'nm'}} && !exists $hashvar->{$result->{'nm'}}->{$result->{'acc_version'}}) {
							#bad acc not in U2 => retry with U2 acc_no
							$vv_results = decode_json(U2_modules::U2_subs_1::run_vv('hg19', $result->{'nm'}.".".$result->{'acc_version'}, "$var_chr-$var_pos-$var_ref-$var_alt", 'VCF'));
							#get new cdna
							my ($tmp_message, $hashvar_tmp);
							($tmp_message, $insert, $hashvar_tmp, $nm_list, $tag) = &run_vv_results($vv_results, $id, $number, $var_chr, $var_pos, $var_ref, $var_alt, $analysis, $status, $allele, $var_dp, $var_vf, $var_filter, $dbh);
							if ($tmp_message ne '') {$message .= $tmp_message;next VCF}#should not happen
							elsif ($insert ne '') {#should not happen
								$dbh->do($insert);
								$j++;
								next VCF;
							}
							if ($result->{'main'} == 1) {
								$vvkey = $result->{'nm'}.".".$result->{'acc_version'}.":".$hashvar_tmp->{$result->{'nm'}}->{$result->{'acc_version'}}[0];
								$cdna = $hashvar_tmp->{$result->{'nm'}}->{$result->{'acc_version'}}[0];
								#$vv_results = decode_json(U2_modules::U2_subs_1::run_vv_cdna('hg19', $result->{'nm'}.".".$result->{'acc_version'}, $hashvar->{$result->{'nm'}}[0]));
								#$vvkey = $result->{'nm'}.".".$result->{'acc_version'}.":".$hashvar->{$result->{'nm'}}[0];
								#$cdna = $hashvar->{$result->{'nm'}}[0];
								($acc_no, $acc_ver) = ($result->{'nm'}, $result->{'acc_version'});
								#main => last
								last
							} else {
								#replace acc_no in hashvar
								#https://stackoverflow.com/questions/1490356/how-to-replace-a-perl-hash-key
								delete $hashvar->{$result->{'nm'}};
								$hashvar->{$result->{'nm'}}->{$result->{'acc_version'}} = $hashvar_tmp->{$result->{'nm'}}->{$result->{'acc_version'}};
							}
							#print STDERR "VV 2\n";
						}
						#elsif (exists $hashvar->{$result->{'nm'}} && $hashvar->{$result->{'nm'}}[1] ne $result->{'acc_version'} && $result->{'main'} == 0) {
						#elsif (exists $hashvar->{$result->{'nm'}} && !exists $hashvar->{$result->{'nm'}}->{$result->{'acc_version'}} && $result->{'main'} == 0) {
						#	#bad acc no in U2 on non main isoform
						#	#tag version name in hash table
						#	$hashvar->{$result->{'nm'}}->{$result->{'acc_version'}}
						#	$hashvar->{$result->{'nm'}}[1] .= ".".$result->{'acc_version'};
						#	$hashvar->{$result->{'nm'}}[2] = $result->{'main'};
						#	$cdna = $hashvar->{$result->{'nm'}}[0];
						#	#print STDERR "VV 3\n";
						#}
					}
					if ($vvkey ne '') {
						($message_tmp, $type_segment, $classe, $var_final) = U2_modules::U2_subs_3::create_variant_vv($vv_results, $vvkey, $gene, $cdna, $acc_no, $acc_ver, $ng_accno, $user, $q, $dbh, "background $var_chr-$var_pos-$var_ref-$var_alt");
						if ($message_tmp =~ /ERROR/o) {$message .= "$id$number: $message_tmp"}
						#$j++;
						#print STDERR "$var_chr-$var_pos-$var_ref-$var_alt: $message_tmp\n";
					}
					else {
						#2 cases:
						#non main  => choose the most impactant (exonic > intronic > UTR) : $hashvar contains a value 0 for main (to be checked)
						#or nothing => no suitable NM
						my ($candidates, $candidate);
						my ($semaph1, $semaph2) = (0, 0);
						foreach my $nm (keys (%{$hashvar})) {
							#check if in U2:
							my $query_nm = "SELECT nom, acc_version FROM gene WHERE nom[2] = '$nm';";
							my $res_nm = $dbh->selectrow_hashref($query_nm);
							if ($res_nm->{'nom'}) {
								if ($hashvar->{$nm}->{$res_nm->{'acc_version'}}[1] != 1) {#non main - should be
									$semaph1 = 1;
									if ($hashvar->{$nm}->{$res_nm->{'acc_version'}}[0] =~ /^c\.[^-][^\+\*-]+$/o) {#exonic
										if (!exists $candidates->{'exonic'}) {$candidates->{'exonic'} = "$nm.".$res_nm->{'acc_version'}.":".$hashvar->{$nm}->{$res_nm->{'acc_version'}}[0]}
									}
									elsif ($hashvar->{$nm}->{$res_nm->{'acc_version'}}[0] =~ /^c\.[\*-].+$/o) {#UTR
										if (!exists $candidates->{'UTR'}) {$candidates->{'UTR'} = "$nm.".$res_nm->{'acc_version'}.":".$hashvar->{$nm}->{$res_nm->{'acc_version'}}[0]}
									}
									elsif ($hashvar->{$nm}->{$res_nm->{'acc_version'}}[0] =~ /^c\.[^-].+[\+-].+$/o) {#intronic
										if (!exists $candidates->{'intronic'}) {$candidates->{'intronic'} = "$nm.".$res_nm->{'acc_version'}.":".$hashvar->{$nm}->{$res_nm->{'acc_version'}}[0]}
									}
								}
								#elsif ($semaph1 == 0 && $semaph2 == 0) {
									#non main with bad acc_ver => choose the 1st one and rerun with other acc_ver and create : $hashvar contains 2 values for accver => take the second
									#
									#my $new_acc = (split(/\./, $hashvar->{$nm}[1]))[1];
									#$candidate = "$nm.$new_acc:".$hashvar->{$nm}[0];
									#$semaph2 = 1;
								#}
							}
						}
						if ($semaph1 == 1) {
							if (exists $candidates->{'exonic'}) {$candidate = $candidates->{'exonic'}}
							elsif (exists $candidates->{'intronic'}) {$candidate = $candidates->{'intronic'}}
							elsif (exists $candidates->{'UTR'}) {$candidate = $candidates->{'UTR'}}
						}
						if ($candidate =~ /(NM_\d+)\.(\d):c\..+/) {
							($acc_no, $acc_ver) = ($1, $2);
							#run vv again
							$vv_results = decode_json(U2_modules::U2_subs_1::run_vv('hg19', $acc_no.".".$acc_ver, $hashvar->{$acc_no}->{$acc_ver}[0], 'cdna'));
							$vvkey = "$acc_no.$acc_ver:".$hashvar->{$acc_no}->{$acc_ver}[0];
							$cdna = $hashvar->{$acc_no}->{$acc_ver}[0];							
							($message_tmp, $type_segment, $classe, $var_final) = U2_modules::U2_subs_3::create_variant_vv($vv_results, $vvkey, $gene, $cdna, $acc_no, $acc_ver, $ng_accno, $user, $q, $dbh, "background $var_chr-$var_pos-$var_ref-$var_alt");
							if ($message_tmp =~ /ERROR/o) {$message .= "$id$number: $message_tmp"}
							#$j++;
							#print STDERR "$var_chr-$var_pos-$var_ref-$var_alt: $message_tmp\n";
						}
						else {
							#ERROR
							$message .= "$id$number: ERROR: Impossible to run VariantValidator (no suitable NM found) for variant $var_chr-$var_pos-$var_ref-$var_alt-$candidate\n";
						}					
					}
					
					if ($message_tmp =~ /NEWVAR/o) {
						#my $insert = "INSERT INTO variant2patient (nom_c, num_pat, id_pat, nom_gene, type_analyse, statut, allele) VALUES ('$var_final', '$number', '$id', '{\"$gene\",\"$acc_no\"}', '$analysis', '$status', '$allele');\n";
						my $query_verif = "SELECT nom FROM gene WHERE \"MiniSeq-158\" = 't' AND nom[1] = '$gene';";
						my $res_verif = $dbh->selectrow_hashref($query_verif);
						# print STDERR "Gene verif3: $res_verif->{'nom'}[0]-$gene";
						if ($res_verif->{'nom'}[0] eq $gene) {
							$insert = "INSERT INTO variant2patient (nom_c, num_pat, id_pat, nom_gene, type_analyse, statut, allele, depth, frequency, msr_filter) VALUES ('$var_final', '$number', '$id', '{\"$gene\", \"$acc_no\"}', '$analysis', '$status', '$allele', '$var_dp', '$var_vf', '$var_filter');";
							# print STDERR $insert."\n";
							$dbh->do($insert) or die "Variant already recorded for the patient, there must be a mistake somewhere $!";
							$i++;$j++;
							$new_var .= $message_tmp;
						}
						else {
							#variant in unwanted region
							$message .= "$id$number: ERROR: Impossible to record variant (unwanted region) $var_chr-$var_pos-$var_ref-$var_alt-$gene-$var_final\n";
						}
					}
					#else {
					#	print STDERR "$var_chr-$var_pos-$var_ref-$var_alt: $message_tmp - not in V2P\n";
					#}
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
		print STDERR "$id$number VCF imported.\n";
		#print STDERR $valid."\n";
	}
	#if ($manual ne '' || $not_inserted ne '') {U2_modules::U2_subs_2::send_manual_mail($user, $manual, $not_inserted, $run)}
	
	open F, ">>$ABSOLUTE_HTDOCS_PATH$ANALYSIS_NGS_DATA_PATH$analysis/$run/import.log" or print STDERR $!;
	print F $user->getName()."\n$date\n$run\n$general\n$message\n$new_var\n";
	close F;
	
	U2_modules::U2_subs_2::send_manual_mail($user, '', '', $run, $general, '', $message);
	
	$q->redirect("patient_file.pl?sample=$sample_end"); 
	
}


##Basic end of USHVaM 2 perl scripts:

U2_modules::U2_subs_1::standard_end_html($q);

print $q->end_html();

exit();

##End of Basic end

##specific subs for current script

sub search_position {
	my ($chr, $pos) = @_;
	my $query = "SELECT a.nom, a.nom_gene, a.type FROM segment a, gene b WHERE a.nom_gene = b.nom AND b.chr = '$chr' AND '$pos' BETWEEN SYMMETRIC a.$postgre_start_g AND a.$postgre_end_g;";
	my $res = $dbh->selectrow_hashref($query);
	if ($res ne '0E0') {return "\t$res->{'nom_gene'}[0] - $res->{'nom_gene'}[1]\t$res->{'type'}\t$res->{'nom'}"}
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
	#if ($var =~ /chr[\dXYM]+:g\.(\d+)[dATCG][eu>][lpATCG].*/o) {return ($1, $1)}
	#elsif ($var =~ /chr[\dXYM]+:g\.(\d+)_(\d+)[di][enu][lsp].*/o) {return ($1, $2)}
	if ($var =~ /chr$U2_modules::U2_subs_1::CHR_REGEXP:g\.(\d+)[dATCG][eu>][lpATCG].*/o) {return ($1, $1)}
	elsif ($var =~ /chr$U2_modules::U2_subs_1::CHR_REGEXP:g\.(\d+)_(\d+)[di][enu][lsp].*/o) {return ($1, $2)}
}

sub run_vv_results {
	my ($vv_results, $id, $number, $var_chr, $var_pos, $var_ref, $var_alt, $analysis, $status, $allele, $var_dp, $var_vf, $var_filter, $dbh) = @_;
	#expected return ($tmp_message, $insert, $hashvar, $nm_list, $tag)
	my ($hashvar, $nm_list, $tag);
	($nm_list, $tag) = ('', '');
	foreach my $var (keys %{$vv_results}) {
		#my ($nm, $cdna) = split(/:/, $var)[0], split(/:/, $var)[1]);
		if ($var eq 'flag' && $vv_results->{$var} eq 'intergenic') {return "$id$number: WARNING: Intergenic variant: $var_chr-$var_pos-$var_ref-$var_alt\n"}
		my ($nm, $acc_ver) = ((split(/[:\.]/, $var))[0], (split(/[:\.]/, $var))[1]);
		#print STDERR $nm."\n";
		if ($nm =~ /^N[RM]_\d+$/o && (split(/:/, $var))[1] !~ /=/o) {
			#$hashvar->{$nm} = [(split(/:/, $var))[1], $acc_ver, ''];#NM => [c., acc_ver, main]
			$hashvar->{$nm}->{$acc_ver} = [(split(/:/, $var))[1], ''];#NM => acc_ver => [c., main]
			########
			##$hashvar is BAD if vv returns several times the same transcript with different acc no => bug
			## Faire un deuxième niveau de clé avec acc_no
			########
			$nm_list .= " '$nm',";
			#get genomic hgvs and check direct submission again
			my $tmp_nom_g = '';
			my @full_nom_g_19 = split(/:/, $vv_results->{$var}->{'primary_assembly_loci'}->{'hg19'}->{'hgvs_genomic_description'});
			if ($full_nom_g_19[0] =~ /NC_0+([^0]{1,2}0?)\.\d{1,2}$/o) {
				#print STDERR $full_nom_g_19[0]."\n";
				my $chr = $1;
				if ($chr == 23) {$chr = 'X'}
				elsif ($chr == 24) {$chr = 'Y'}
				$tmp_nom_g = "chr$chr:".pop(@full_nom_g_19);
			}
			if ($tmp_nom_g ne '') {
				#print STDERR $tmp_nom_g."-\n";
				my $insert = U2_modules::U2_subs_3::direct_submission($tmp_nom_g, $number, $id, $analysis, $status, $allele, $var_dp, $var_vf, $var_filter, $dbh);
				# print STDERR "Direct submission3: $insert";
				# if ($insert ne '') {return ('', $insert)}
				if ($insert ne '') {
					my $query_verif = "SELECT nom FROM gene WHERE \"MiniSeq-158\" = 't' AND nom[2] = '$nm';";
					my $res_verif = $dbh->selectrow_hashref($query_verif);
					# print STDERR "Gene verif4: $res_verif->{'nom'}[1]-$nm";
					if ($res_verif->{'nom'}[1] eq $nm) {
						# print STDERR "insert 4:$insert\n";
						return ('', $insert);
					}
					else {
						#variant in unwanted region
						return "$id$number: ERROR: Impossible to record variant (unwanted region in run_vv_results) $var_chr-$var_pos-$var_ref-$var_alt-$nm-$tmp_nom_g\n";
					}
				}
			}
			if ($vv_results->{$var}->{'gene_symbol'} && $tmp_nom_g =~ /.+[di][eun][lps]$/o) {#last test: we directly test c. as sometimes genomic nomenclature can differ in dels/dup
				#patches
				if ($vv_results->{$var}->{'gene_symbol'} eq 'ADGRV1') {$vv_results->{$var}->{'gene_symbol'} = 'GPR98'}
				my $last_query = "SELECT nom_g FROM variant WHERE nom LIKE '".(split(/:/, $var))[1]."%' and nom_gene[1] = '$vv_results->{$var}->{'gene_symbol'}';";
				#print STDERR $last_query."\n";
				my $res_last = $dbh->selectrow_hashref($last_query);
				if ($res_last->{'nom_g'}) {
					#print STDERR $res_last->{'nom_g'}."\n";
					my $insert = U2_modules::U2_subs_3::direct_submission($res_last->{'nom_g'}, $number, $id, $analysis, $status, $allele, $var_dp, $var_vf, $var_filter, $dbh);
					# print STDERR "Direct submission4 $insert";
					# if ($insert ne '') {return ('', $insert)}
					if ($insert ne '') {
						my $query_verif = "SELECT nom FROM gene WHERE \"MiniSeq-158\" = 't' AND nom[2] = '$nm';";
						my $res_verif = $dbh->selectrow_hashref($query_verif);
						# print STDERR "Gene verif5: $res_verif->{'nom'}[1]-$nm";
						if ($res_verif->{'nom'}[1] eq $nm) {
							# print STDERR "insert 5:$insert\n";
							return ('', $insert);						
						}
						else {
							#variant in unwanted region
							return "$id$number: ERROR: Impossible to record variant (unwanted region in run_vv_results) $var_chr-$var_pos-$var_ref-$var_alt-$nm-$tmp_nom_g\n";
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


