BEGIN {delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV', 'PATH'};}

use strict;
#use CGI;#in startup.pl
#use DBI;
#use AppConfig qw(:expand :argcount);
use Net::OpenSSH;
use SOAP::Lite;
#use Data::Dumper;
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

my @styles = ($CSS_PATH.'w3.css', $CSS_DEFAULT, $CSS_PATH.'fullsize/fullsize.css');

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

U2_modules::U2_subs_1::standard_begin_html($q, $user->getName());

##end of Basic init
my $ABSOLUTE_HTDOCS_PATH = $config->ABSOLUTE_HTDOCS_PATH();
my $ANALYSIS_NGS_DATA_PATH = $config->ANALYSIS_NGS_DATA_PATH();
my $ANALYSIS_MISEQ_FILTER = $config->ANALYSIS_MISEQ_FILTER();
#specific args for remote login to RS
my $SSH_RACKSTATION_BASE_DIR = $config->SSH_RACKSTATION_BASE_DIR();
my $SSH_RACKSTATION_MINISEQ_BASE_DIR = $config->SSH_RACKSTATION_MINISEQ_BASE_DIR();
#my $SSH_RACKSTATION_IP = $config->SSH_RACKSTATION_IP();


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
	my %sample_hash = &build_sample_hash($q, $analysis, $filtered);
	
	#test mutalyzer
	if (U2_modules::U2_subs_1::test_mutalyzer() != 1) {U2_modules::U2_subs_1::standard_error('23', $q)}
	
	print $q->start_p({'class' => 'center'}), $q->start_big(), $q->span("Automatic treatment of run "), $q->strong("$run ($analysis)"), $q->span(":"), $q->end_big(), $q->end_p();
	
	## creates mutalyzer client object
	### old way to connect to mutalyzer deprecated September 2014
	#my $soap = SOAP::Lite->new(proxy => 'http://mutalyzer.nl/2.0/services');
	#$soap->defaul_ns('urn:https://mutalyzer.nl/services/?wsdl');
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
	my $ssh = U2_modules::U2_subs_1::nas_connexion('-', $q);
	
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
		$alignment_dir = $ssh->capture("grep -Eo \"AlignmentFolder>.+\\Alignment[0-9]*<\" $SSH_RACKSTATION_BASE_DIR/$run/CompletedJobInfo.xml");
		$alignment_dir =~ /\\(Alignment\d*)<$/o;
		$alignment_dir = $1;
		$alignment_dir = "$SSH_RACKSTATION_BASE_DIR/$run/Data/Intensities/BaseCalls/$alignment_dir";
	}
	elsif ($instrument eq 'miniseq') {
		#$alignment_dir = `grep -Eo \"AlignmentFolder>.+\\Alignment_?[0-9]*.+<\" $ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/data/$instrument_path/$run/CompletedJobInfo.xml`;
		#old fashioned replaced with autofs 21/12/2016
		$alignment_dir = $ssh->capture("grep -Eo \"AlignmentFolder>.+\\Alignment_?[0-9]*.+<\" $SSH_RACKSTATION_BASE_DIR/$run/CompletedJobInfo.xml");
		$alignment_dir =~ /\\(Alignment_?\d*.+)<$/o;
		$alignment_dir = $1;
		$alignment_dir =~ s/\\/\//og;
		$alignment_dir = "$SSH_RACKSTATION_BASE_DIR/$run/$alignment_dir";
	}
	#print $alignment_dir;exit;
	#old fashioned replaced with code above david 01/07/2016
	#my $alignment_dir = $ssh->capture("grep -Eo \"AlignmentFolder>.+\\Alignment[0-9]*<\" $SSH_RACKSTATION_BASE_DIR/$run/CompletedJobInfo.xml");
	#print "grep -Eo \"<AlignmentFolder>\\\\".$SSH_RACKSTATION_IP."\\data\\MiSeqDx\\".$run."\\Data\\Intensities\\BaseCalls\\Alignment\\d*<\/AlignmentFolder>\" $SSH_RACKSTATION_BASE_DIR/$run/CompletedJobInfo.xml";
	#$alignment_dir =~ /\\(Alignment\d*)<$/o;
	#$alignment_dir = $1;
	#old_fashioned replaced with code above 2014/08/25 david
	#my @dirlist = split(/\s/, $ssh->capture("ls -d $SSH_RACKSTATION_BASE_DIR/$run/Data/Intensities/BaseCalls/Alignment*"))
	#my $i = 0;
	#foreach (@dirlist) {
	#	if (/Alignment(\d+)$/) {if ($1 > $i) {$i = $1}}
	#}
	#my $alignment_dir = 'Alignment';
	#if ($i > 0) {$alignment_dir .= $i}
	
	#ERASE COMMENTED IF WORKS AND $location USELESS 02/08/2016	
	###TO BE CHANGED 4 MINISEQ
	### path to alignment dir under run root
	#my ($location, $report); 
	#if ($instrument eq 'miseq') {
		#$location = "$SSH_RACKSTATION_BASE_DIR/$run/Data/Intensities/BaseCalls/$alignment_dir/";
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
	my $success = $ssh->scp_get({glob => 1, copy_attrs => 1}, $alignment_dir.'/'.$report, "$ABSOLUTE_HTDOCS_PATH$ANALYSIS_NGS_DATA_PATH$analysis/$run/aggregate.report.pdf") or die $!;
	if ($success != 1) {U2_modules::U2_subs_1::standard_error('22', $q)}
	
	
	my ($manual, $not_inserted, $general, $mutalyzer_no_answer, $sample_end, $to_follow) = ('', '', '', '', '', '');#$manual will contain variants that cannot be delt automatically i.e. PTPRQ (at least in hg19), NR_, non mappable; $notinserted variants wt homozygous, $general global data for final email, $sample_end last treated patient for redirection $to_follow is to get info on certain variants that were buggy
	#my $inf = 100; #coverage limits #was used to generate bed but replaced with bedgraphs (but which do not deal with colors...)
	#my $sup = 150;
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
		print STDERR "\nInitiating $id$number...";
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
		my $success = $ssh->scp_get({glob => 1, copy_attrs => 1}, $alignment_dir.'/'.$coverage, "$ABSOLUTE_HTDOCS_PATH$ANALYSIS_NGS_DATA_PATH$analysis/$sampleid/$sampleid.coverage.tsv");
		if ($success == 1) {$success = $ssh->scp_get({glob => 1, copy_attrs => 1}, $alignment_dir.'/'.$enrichment, "$ABSOLUTE_HTDOCS_PATH$ANALYSIS_NGS_DATA_PATH$analysis/$sampleid/$sampleid.enrichment_summary.csv")}
		else {U2_modules::U2_subs_1::standard_error('22', $q)}
		if ($success == 1) {$success = $ssh->scp_get({glob => 1, copy_attrs => 1}, $alignment_dir.'/'.$gaps, "$ABSOLUTE_HTDOCS_PATH$ANALYSIS_NGS_DATA_PATH$analysis/$sampleid/$sampleid.gaps.tsv")}
		else {U2_modules::U2_subs_1::standard_error('22', $q)}
		if ($success == 1) {$success = $ssh->scp_get({glob => 1, copy_attrs => 1}, $alignment_dir.'/'.$vcf, "$ABSOLUTE_HTDOCS_PATH$ANALYSIS_NGS_DATA_PATH$analysis/$sampleid/$sampleid.vcf")}
		else {U2_modules::U2_subs_1::standard_error('22', $q)}
		$ssh->scp_get({glob => 1, copy_attrs => 1}, $alignment_dir.'/'.$sample_report, "$ABSOLUTE_HTDOCS_PATH$ANALYSIS_NGS_DATA_PATH$analysis/$sampleid/$sampleid.report.pdf");
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
		
		open(F, "$ABSOLUTE_HTDOCS_PATH$ANALYSIS_NGS_DATA_PATH$analysis/$sampleid/$sampleid.enrichment_summary.csv") or die $!;         
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
		
		print STDERR "Done gaps file...";
		
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
				#if rs and in U2 => ok insert into v2p => impossible a same rs can pooint 2 variants or more
				#if rs and not in U2 => mutalyzer snp_conv => genomic nom => mutalyzer deprecated takes too much time to get getdbSNPDescriptions results case 2 becomes case3
				#case 2bis if not case 1 but in U2 => ok insert direct for subs into v2p, after mutalyzer correction for indels
				#if not rs => built genom nom; if in U2 insert into v2p
				#else built genom nom => mutalyzer
				($var_chr, $var_pos, $rs_id, $var_ref, $var_alt, $null, $var_filter) = (shift(@list), shift(@list), shift(@list), shift(@list), shift(@list), shift(@list), shift(@list));
				my @format_list = split(/:/, pop(@list));

				#compute vf_index
				my @label_list = split(/:/, pop(@list));
				my $label_count = 0;
				my $vf_index = 7;
				foreach(@label_list) {
					if (/VF/o) {$vf_index = $label_count}
					$label_count ++;					
				}
				
				#my $vf_index = 7;
				#if ($instrument eq 'miseq') {$vf_index = 5}
				($var_dp, $var_vf) = ($format_list[2], $format_list[$vf_index]);
				
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
				if ($var_chr eq 'chrX') {
					my $query_hemi = "SELECT sexe FROM patient WHERE numero = '$number' AND identifiant = '$id';";
					my $res_hemi = $dbh->selectrow_hashref($query_hemi);
					if ($res_hemi->{'sexe'} eq 'M') {($status, $allele) = ('hemizygous', '2')}
				}
				
				
			
				
				#case1 & case2
				#WARNING rsid can concern several different variants, e.g. rs35689081, so useless as we need the genomic_var, treated below anyway with or without rs id	REMOVED 2014/09/30	
				#if ($rs_id ne '.') {
				#	#my $control = length($insert);
				#	$insert = &direct_submission('snp_id', $rs_id, $number, $id, $analysis, $status, $allele, $var_dp, $var_vf, $var_filter, $dbh, $genomic_var);
				#	if ($insert ne '') {
				#		$dbh->do($insert);
				#		$i++;
				#		next VCF;
				#	}
				#	
				#	#if (length($insert) > $control) {$i++;next VCF;}
				#	
				#	
				#	#$query = "SELECT nom, nom_gene FROM variant WHERE snp_id = '$rs_id';";
				#	#my $res = $dbh->selectrow_hashref($query);
				#	#if ($res) {
				#	#	#ok case1						
				#	#	$insert .= "INSERT INTO variant2patient (nom_c, num_pat, id_pat, nom_gene, type_analyse, statut, allele, depth, frequency, msr_filter) VALUES ('$res->{'nom'}', '$number', '$id', '{\"$res->{'nom_gene'}[0]\",\"$res->{'nom_gene'}[1]\"}', '$analysis', '$status', 'unknown', '$var_dp', '$var_vf', '$var_filter');<br/>";
				#	#	$i++;
				#	#	next;
				#	#}
				#	#else { looks really long, will try sthg else so case 2 disappears -- too bad
				#	#	#case 2
				#	#	##run getdbSNPDescriptions() webservice - gives hg38!! waiting for using that, we need to get NM then reconvert.
				#	#	$call = $soap->call('getdbSNPDescriptions',
				#	#			SOAP::Data->name('rs_id')->value($rs_id));
				#	#	print $rs_id."<br/>";
				#	#	my $nm;
				#	#	foreach ($call->result()->{'string'}) {
				#	#		foreach (@{$_}) {
				#	#			if (/(NM_\d+\.\d):(c\..+)/) {
				#	#				#check NM
				#	#				###
				#	#			}
				#	#			
				#	#			#print $_, "<br/>"
				#	#		}
				#	#	}
				#	#}
				#}
				
				
				#case 2bis&3&4
				my $genomic_var = &build_hgvs_from_illumina($var_chr, $var_pos, $var_ref, $var_alt);
				my $first_genomic_var = $genomic_var;
				my $known_bad_variant = 0;
				#check if variants known for bad annotation already exists
				#if ($first_genomic_var =~ /(del|ins)/o) {
				my $query_gs = "SELECT u2_name FROM gs2variant WHERE gs_name = '$first_genomic_var' AND (reason LIKE 'MiSeq_%' OR reason LIKE 'inv_nt');";
				my $res_gs = $dbh->selectrow_hashref($query_gs);
				if ($res_gs) {$known_bad_variant = 1;$genomic_var = $res_gs->{'u2_name'}}
				#}
				
								
				#for subs check if exists in U2
				#if ($genomic_var =~ /(>|del)/ || $known_bad_variant == 1) {#case 2bis part 1	+ bad annotated known indel + all dels anyway (those in strand - might already exist)	so nearly all variants
					#print "First Control $genomic_var<br/>";
					#my $control = length($insert);
					#$insert = &direct_submission('nom_g', $genomic_var, $number, $id, $analysis, $status, $allele, $var_dp, $var_vf, $var_filter, $dbh); #direct submission is now always nom_g 2014/09/30
					$insert = &direct_submission($genomic_var, $number, $id, $analysis, $status, $allele, $var_dp, $var_vf, $var_filter, $dbh);
					if ($insert ne '') {
						$dbh->do($insert);
						$i++;
						next VCF;
					}
					
					#we try to invert wt & mut
					
					if ($genomic_var =~ /(chr[\dXY]+:g\..+\d+)([ATGC])>([ATCG])/o) {
						my $inv_genomic_var = $1.$3.">".$2;
						$insert = &direct_submission($inv_genomic_var, $number, $id, $analysis, $status, $allele, $var_dp, $var_vf, $var_filter, $dbh);
						if ($insert ne '') {
							$dbh->do($insert);
							$i++;
							next VCF;
						}
					}
					
					
					
					#if (length($insert) > $control) {$i++;next VCF;}				
				#}
				#subs ok
				#dels
				#in genes in strand - looks ok
				#in genes in strand +, positions may need to be corrected get shift from mutalyzer warning => newpos-oldpos for begin and end positions an then correct chrom nomenclature then rerun mutalyzer as wt adn mut seq will be wrong
				#ins
				#in genes in strand - => pos ok but often dup instead of ins, should we shift before (and add duppled nuc as a check)??? NO
				#		if dup = 1 get dupos=insstart =>rename g
				#		if dup > 1 get keep pos just change ins/dup
				#in genes in strand + => pos not ok + dup and get new change e.g. TC becomes CT
				#for dups => if dup = 1 get dup position duppos-oldpos goldpos + diff => ok
				#	     if dup > 1 get dup positions dupstart-oldstart & dupend-oldend gstart+diffstart & gend+diffend
				#example messages strand +
				#Insertion of TC at position 596213_596214 was given, however, the HGVS notation prescribes that on the forward strand it should be an insertion of CT at position 596214_596215.
				#ok so we need a first round of mutalyzer positionconverter then runmutalyzer for indels, then correct the genomic nomenclature, then a position converter round for everybody, then the run mutalyzer.
				if ($genomic_var !~ />/) {
					
					##TRY OUR OWN POSITION CONVERTER DUE TO MUTALYZER BUG WITH PTPRQ AND POSSIBILITY TO REDUCE EXEC TIME (LESS NETWORK)
					##NO TOO HORRIBLE
					#tss has been added to tanscripts
					#just one for PTPRQ waiting for mutalyzer bug resolution
					#TODO HERE
					#NONONO PTPRQ to much a mess - waiting for hg38
					
					if ($genomic_var =~ /chr12:g\.(\d+)/o) {
						if ($1 > 80838126 && $1 < 81072802) {#hg19 coordinates
							#PTPRQ
							#put in manual list
							
							$manual .= "PTPRQ\t$id$number\t$genomic_var\t$analysis\t'$status', 'unknown', '$var_dp', '$var_vf', '$var_filter');\n";
							next VCF;
						}
						#elsif ($1 > 15771096 && $1 < 15942511) {#hg19 coordinates ##EPS8 does not yet have a NG_ removed 05/11/2015 david EPS8 has an NG_ to be tested
							#EPS8
							#put in manual list
						#	$manual .= "EPS8\t$id$number\t$genomic_var\t$analysis\t'$status', 'unknown', '$var_dp', '$var_vf', '$var_filter');\n";
						#	next VCF;
						#}						
					}
					
					
					
					#print "$genomic_var<br/>";
					##run numberConversion() webservice
					$call = $soap->call('numberConversion',
							SOAP::Data->name('build')->value('hg19'),
							SOAP::Data->name('variant')->value($genomic_var));
					if (!$call->result()) {$manual .= "MUTALYZER FAULT\t$id$number\t$genomic_var\t$analysis\t'$status', 'unknown', '$var_dp', '$var_vf', '$var_filter');\t$k\n";next VCF;}
					foreach ($call->result()->{'string'}) {
						my $tab_ref;
						if (ref($_) eq 'ARRAY') {$tab_ref = $_}
						else {$tab_ref->[0] = $_}
						#if (Dumper($_) =~ /\[/og) {$tab_ref = $_} ## multiple results: tab ref
						#else {$tab_ref->[0] = $_}
						
						POSCONV: foreach (@{$tab_ref}) {
							#print $_, "<br/>";
							if (/(NM_\d+)\.(\d):([cn]\..+)/og) {
								my $acc = $1;
								my $ver = $2;
								my $nom = $3;
								$query = "SELECT nom[1] as gene_name, acc_g, mutalyzer_acc, mutalyzer_version FROM gene WHERE nom[2] = '$acc' AND main = 't';";# AND acc_version = '$ver';";
								my $res3 = $dbh->selectrow_hashref($query);
								if ($res3) {#we've got the good one
									#print "<br/>$genomic_var"

									#1st getstrand
									my $strand_code = U2_modules::U2_subs_1::get_strand($res3->{'gene_name'}, $dbh);  #returns ASC for '+', DESC for '-', usually used to sort variants
									if (($genomic_var =~ /del/ && $strand_code eq 'ASC') || ($genomic_var =~ /ins/)) {
									#if (($genomic_var =~ /ins/ && $strand_code eq 'ASC')) { #for dev purpose
										
										
										#run mutalyzer and catch warning										
										$call = U2_modules::U2_subs_1::run_mutalyzer($soap, $res3->{'acc_g'}, $res3->{'gene_name'}, $nom, $res3->{'mutalyzer_version'}, $res3->{'mutalyzer_acc'});
										
										my $message;
														
										if ($call->result->{'messages'}) {	
											foreach ($call->result->{'messages'}->{'SoapMessage'}) {
												my $array_ref;
												#if (Dumper($_) =~ /\];/og) {$array_ref = $_} ## multiple results: tab ref}
												#else {$array_ref->[0] = $_}
												if (ref($_) eq 'ARRAY') {$array_ref = $_}
												else {$array_ref->[0] = $_}
												foreach (@{$array_ref}) {
													#print "\nMessage: ", $_->{'message'},"<br/>";
													if ($_->{'message'} =~ /Sequence|Insertion/) {$message = $_->{'message'}}
													#if ($_->{'errorcode'}) {push @errors, $_} ## if you want to deal with error and/or warning codes
												}	
											}
										}
										
										if ($genomic_var =~ /del/o) {
											#example
											#Sequence "T" at position 43035 was given, however, the HGVS notation prescribes that on the forward strand it should be "T" at position 43051.
											#Sequence "AAGAAG" at position 13252_13257 was given, however, the HGVS notation prescribes that on the forward strand it should be "AAGAAG" at position 13273_13278.
											if ($message =~ /Sequence\s"([ATGC]+)"\sat\sposition\s([\d_]+)\swas\sgiven,\showever,\sthe\sHGVS\snotation\sprescribes\sthat\son\sthe\sforward\sstrand\sit\sshould\sbe\s"([ATGC]+)"\sat\sposition\s([\d_]+)\./o) {
												my ($pos1, $pos2, $old_del, $new_del) = ($2, $4, $1, $3);
												my $diff;
												if ($pos1 !~ /_/o) {
													$diff = $pos2-$pos1;
													$genomic_var =~ /g\.(\d+)del/;
													my $new = $1+$diff;
													$genomic_var =~ s/g\.\d+/g\.$new/;
												}
												else {
													$pos1 =~ /(\d+)_\d+/o;
													$pos1 = $1;
													$pos2 =~ /(\d+)_\d+/o;
													$pos2 = $1;
													$diff = $pos2-$pos1;
													$genomic_var =~ /g\.(\d+)_(\d+)del/;
													my ($new1, $new2) = ($1+$diff, $2+$diff);
													#print "$diff $new1 $new2<br/>blabla<br/>";
													$genomic_var =~ s/g\.\d+/g\.$new1/;
													$genomic_var =~ s/_\d+/_$new2/;
													
												}
												if ($new_del ne $old_del) {$genomic_var =~ s/del$old_del/del$new_del/}
												#print "$genomic_var<br/>";
												last POSCONV;
											}
											else {print $message;}
											#we'll fill in the gs2variant table originally designed for Junior runs
											if ($genomic_var ne $first_genomic_var) {
												$genomic_var =~ /(^.+del)[ATGC]+/;
												$query_gs = "SELECT u2_name FROM gs2variant WHERE gs_name = '$first_genomic_var' AND (reason LIKE 'MiSeq_%' OR reason LIKE 'inv_nt');";
												$res_gs = $dbh->selectrow_hashref($query_gs);
												if ($res_gs) {$genomic_var = $res_gs->{'u2_name'}}												
												else {
													$insert = "INSERT INTO gs2variant (gs_name, u2_name, reason) VALUES ('$first_genomic_var', '$1', 'MiSeq_indel');";
													$dbh->do($insert);
												}
												last POSCONV;
											}
											
											
										}
										else {#ins
											#print "$genomic_var $strand_code<br/>";
											#strand -
											if ($strand_code eq 'DESC') {
												#check if dup then rename
												#example
												#Insertion of GA at position 354072_354073 was given, however, the HGVS notation prescribes that it should be a duplication of GA at position 354072_354073.
												#Insertion of G at position 47570_47571 was given, however, the HGVS notation prescribes that it should be a duplication of G at position 47570_47570.
												#Insertion of CGCAGC at position 25621_25622 was given, however, the HGVS notation prescribes that it should be a duplication of CGCAGC at position 25621_25626.
												if ($message =~ /Insertion\sof\s([ATGC]+)\sat\sposition\s([\d_]+)\swas\sgiven,\showever,\sthe\sHGVS\snotation\sprescribes\sthat\sit\sshould\sbe\sa\sduplication\sof\s([ATGC]+)\sat\sposition\s([\d_]+)\./o) {
													#my ($pos1, $pos2, $old_ins, $new_ins) = ($2, $4, $1, $3);
													my ($old_ins, $new_ins) = ($1, $3);
													my ($pos11, $pos12, $pos21, $pos22) = &get_detailed_pos($2, $4);
													#$pos1 =~ /(\d+)_(\d+)/o;
													#my ($pos11, $pos12) = ($1, $2);
													#$pos2 =~ /(\d+)_(\d+)/o;
													#my ($pos21, $pos22) = ($1, $2);
													if (($pos11 == $pos21) && ($pos12 == $pos22) && ($old_ins eq $new_ins)) {
														$genomic_var =~ s/ins/dup/o;
														#can be wrong still because of a mutalyzer issue
														$call->result->{'genomicDescription'} =~ /NG_\d+\.\d:g\.(\d+)_(\d+)dup/o;
														if ($1 != $pos21) {
															my ($diff1, $diff2) = ($pos11-$1, $pos12-$2);
															$genomic_var =~ /chr[\dX]+:g\.(\d+)_(\d+)dup[ATGC]+/o;
															my ($new1, $new2) = ($1 + $diff2, $2 + $diff1);
															$genomic_var =~ s/g\.\d+/g\.$new1/;
															$genomic_var =~ s/_\d+/_$new2/;
														}
														
													}#dup at same pos print 'case1<br/>';
													elsif (($pos11 == $pos21) && ($old_ins eq $new_ins) && ($pos22 == $pos21)) {#dup at single pos
														$genomic_var =~ /(chr[\dX]+:g\.)\d+_(\d+)ins([ATGC])/o;
														$genomic_var = "$1$2dup$3";
														#print 'case2<br/>';
													}
													elsif (($pos12 == $pos21) && ($old_ins eq $new_ins) && ($pos22 == $pos21)) {#dup at single pos
														$genomic_var =~ /(chr[\dX]+:g\.\d+)_\d+ins([ATGC])/o;
														$genomic_var = "$1dup$2";
														#print 'case2<br/>';
													}
													elsif (($pos11 == $pos21) && ($old_ins eq $new_ins) && ($pos22 != $pos21)) {
														$genomic_var =~ s/ins/dup/;														
														#bug in mutalyzer try NG_028030.1:c.2352_2353insCGCAGC
														#if bug fixed uncomment the 4 coming lines and comment else	18/08/2014
														#my $diff = $pos22-$pos21-1;
														#$genomic_var =~ /chr[\dX]+:g\.(\d+)_\d+dup[ATGC]+/o;
														#my $new = $1-$diff;
														#$genomic_var =~ s/g\.\d+/g\.$new/;
														#else
														$call->result->{'genomicDescription'} =~ /NG_\d+\.\d:g\.(\d+)_(\d+)dup/o;
														my ($diff1, $diff2) = ($pos11-$1, $pos12-$2);
														$genomic_var =~ /chr[\dX]+:g\.(\d+)_(\d+)dup[ATGC]+/o;
														my ($new1, $new2) = ($1 + $diff2, $2 + $diff1);
														$genomic_var =~ s/g\.\d+/g\.$new1/;
														$genomic_var =~ s/_\d+/_$new2/;
														#print 'case3<br/>';
														#if (length ($old_ins) == 2) {
														#	print "strand - $first_genomic_var - $genomic_var<br/>";
														#}
													}													
												}
												else {print $message;}
												#else {
												#	print "strand - $first_genomic_var - $genomic_var<br/>";
												#	print $message;
												#}
											}
											else {#strand +
												#example
												#Insertion of T at position 51055_51056 was given, however, the HGVS notation prescribes that it should be a duplication of T at position 51070_51070.
												#Insertion of TGAT at position 41946_41947 was given, however, the HGVS notation prescribes that it should be a duplication of ATTG at position 41952_41955.
												#Insertion of TC at position 596213_596214 was given, however, the HGVS notation prescribes that on the forward strand it should be an insertion of CT at position 596214_596215.
												if ($message =~ /Insertion\sof\s([ATGC]+)\sat\sposition\s([\d_]+)\swas\sgiven,\showever,\sthe\sHGVS\snotation\sprescribes\sthat\sit\sshould\sbe\sa\sduplication\sof\s([ATGC]+)\sat\sposition\s([\d_]+)\./o) {
													#my ($pos1, $pos2, $old_ins, $new_ins) = ($2, $4, $1, $3);
													my ($old_ins, $new_ins) = ($1, $3);
													my ($pos11, $pos12, $pos21, $pos22) = &get_detailed_pos($2, $4);
													#$pos1 =~ /(\d+)_(\d+)/o;
													#my ($pos11, $pos12) = ($1, $2);
													#$pos2 =~ /(\d+)_(\d+)/o;
													#my ($pos21, $pos22) = ($1, $2);
													if ($pos21 == $pos22) {
														#print 'case1<br/>';
														#print $call->result->{'genomicDescription'};
														#$genomic_var =~ s/ins/dup/o;
														my $diff = $pos21 - $pos11;
														$genomic_var =~ /(chr[\dX]+:g\.)(\d+)_\d+ins([ATGC])/o;
														my $new = $2 + $diff;
														$genomic_var = $1.$new."dup$3";													
													}
													elsif(($pos11 != $pos21) && ($pos12 != $pos22)) {
														#print 'case2<br/>';
														#the same as in strand - !!!! mutalyzer bug
														#uncomment the following line if resolved
														#check NM_014053.3:c.*2059_*2060insAC
														#my ($diff1, $diff2) = (($pos21 - $pos11), ($pos22 - $pos12));
														
														$call->result->{'genomicDescription'} =~ /NG_\d+\.\d:g\.(\d+)_(\d+)dup/o;
														my ($diff1, $diff2) = ($1 - $pos11, $2-$pos12);														
														$genomic_var =~ /(chr[\dX]+:g\.)(\d+)_(\d+)ins[ATGC]+/o;
														my ($new1, $new2) = ($2 + $diff1, $3 + $diff2);
														$genomic_var = $1.$new1."_".$new2."dup$new_ins";		
													}
													#if (length ($old_ins) == 2) {
													#	print "strand + $first_genomic_var - $genomic_var<br/>";
													#}
													
												}
												elsif ($message =~ /Insertion\sof\s([ATGC]+)\sat\sposition\s([\d_]+)\swas\sgiven,\showever,\sthe\sHGVS\snotation\sprescribes\sthat\son\sthe\sforward\sstrand\sit\sshould\sbe\san\sinsertion\sof\s([ATGC]+)\sat\sposition\s([\d_]+)\./o) {
													#print 'case3<br/>';
													my ($old_ins, $new_ins) = ($1, $3);
													my ($pos11, $pos12, $pos21, $pos22) = &get_detailed_pos($2, $4);
													#$pos1 =~ /(\d+)_(\d+)/o;
													#my ($pos11, $pos12) = ($1, $2);
													#$pos2 =~ /(\d+)_(\d+)/o;
													#my ($pos21, $pos22) = ($1, $2);
													#my ($diff1, $diff2) = ($pos21 - $pos11, $pos22 - $pos12);
													my $diff = $pos21 - $pos11;
													$genomic_var =~ /(chr[\dX]+:g\.)(\d+)_(\d+)ins([ATGC]+)/o;
													my ($new1, $new2) = ($2 + $diff, $3 + $diff);
													$genomic_var = $1.$new1."_".$new2."ins$new_ins";
													#$genomic_var =~ s/g\.\d+/g\.$new1/;
													#$genomic_var =~ s/_\d+/_$new2/;
													#if (length ($old_ins) == 2) {
													#	print "strand + $first_genomic_var - $genomic_var<br/>";
													#}
												}
												else {print $message;}
											}
											#print "$genomic_var<br/>";
											#we'll fill in the gs2variant table originally designed for Junior runs
											if ($genomic_var ne $first_genomic_var) {
												$query_gs = "SELECT u2_name FROM gs2variant WHERE gs_name = '$first_genomic_var' AND (reason LIKE 'MiSeq_%' OR reason LIKE 'inv_nt');";
												$res_gs = $dbh->selectrow_hashref($query_gs);
												if ($res_gs) {$genomic_var = $res_gs->{'u2_name'}}	
												else {
													if ($genomic_var =~ /(^.+dup)[ATGC]+/) {$insert = "INSERT INTO gs2variant (gs_name, u2_name, reason) VALUES ('$first_genomic_var', '$1', 'MiSeq_indel');"}
													else {$insert = "INSERT INTO gs2variant (gs_name, u2_name, reason) VALUES ('$first_genomic_var', '$genomic_var', 'MiSeq_indel');"}
													$dbh->do($insert);
												}
											}
											last POSCONV;
										}
									}
								}
								#else {print "<br/>$genomic_var"}
							}
							elsif (/NR_.+/) {#deal with NR for NR, a number conversion should be enough
								#$manual .= "NR_variant\t$id$number\t$genomic_var\t$analysis\t$status\t$var_dp\t$var_vf\t$var_filter\n";
								$manual .= "NR_variant\t$id$number\t$genomic_var\t$analysis\t'$status', 'unknown', '$var_dp', '$var_vf', '$var_filter');\n";
								
							}
						}
					}
						
					#old place for new dup del check
				}
				#ok indels are supposed to be corrected, now a numberconveriosn run for everybody then the run mutalyzer.
				#PTPRQ directly to the manual garbage (me)
				if ($genomic_var =~ /chr12:g\.(\d+)/o) {
					if ($1 > 80838126 && $1 < 81072802) {#hg19 coordinates
						#PTPRQ
						#$manual .= "PTPRQ\t$id$number\t$genomic_var\t$analysis\t$status\t$var_dp\t$var_vf\t$var_filter\n";
						$manual .= "PTPRQ\t$id$number\t$genomic_var\t$analysis\t'$status', 'unknown', '$var_dp', '$var_vf', '$var_filter');\n";
						
						next VCF;
					}						
				}
				
				if ($genomic_var !~ />/) {
					#just check new deldupins does not already exists				
					#print "Second Control $genomic_var<br/>";
					#my $control = length($insert);					
					#$insert = &direct_submission('nom_g', $genomic_var, $number, $id, $analysis, $status, $allele, $var_dp, $var_vf, $var_filter, $dbh);#direct submission is now always nom_g 2014/09/30
					$insert = &direct_submission($genomic_var, $number, $id, $analysis, $status, $allele, $var_dp, $var_vf, $var_filter, $dbh);
					if ($insert ne '') {
						$dbh->do($insert);
						$i++;
						next VCF;
					}
					#if (length($insert) > $control) {$i++;next VCF;}
				}
				
				
				
				
				#here do the job
				#get it from gsdot2u2.cgi
				
				my ($nom_ng, $nom_ivs, $nom_prot, $seq_wt, $seq_mt, $type_adn, $type_arn, $type_prot, $type_segment, $type_segment_end, $num_segment, $num_segment_end, $taille, $snp_id, $snp_common);
				($nom_prot, $nom_ivs) = ('NULL', 'NULL');
				
				my ($start, $end) = &get_start_end_pos($genomic_var);
				
					
				
				##run numberConversion() webservice
				$call = $soap->call('numberConversion',
						SOAP::Data->name('build')->value('hg19'),
						SOAP::Data->name('variant')->value($genomic_var));
				if ($call->result()) {
					foreach ($call->result()->{'string'}) {
						my $tab_ref;
						#if (Dumper($_) =~ /\[/og) { ## multiple results: tab ref
						#	$tab_ref = $_;
						#}
						#else {
						#	$tab_ref->[0] = $_;	
						#}
						if (ref($_) eq 'ARRAY') {$tab_ref = $_}
						else {$tab_ref->[0] = $_}
						my ($main, $treated, $nr) = (0, 0, '');
						
						POSCONV2: foreach (@{$tab_ref}) {
							#print $_, "<br/>";
							if (/(NM_\d+)\.(\d):([cn]\..+)/og && $treated == 0) {
								my $acc = $1;
								my $ver = $2;
								my $nom = $3;
								#print $nom, "<br/>";
								my $manual_temp .= "\t$id$number\t$first_genomic_var\t$genomic_var\t$analysis\t'$status', 'unknown', '$var_dp', '$var_vf', '$var_filter');\n";
								#if various errors, to do later
								my $stop = 0;
								my $query = "SELECT nom[1] as gene_name, acc_g, mutalyzer_version, mutalyzer_acc FROM gene WHERE nom[2] = '$acc' AND main = 't' AND acc_version = '$ver';";
								my $res3 = $dbh->selectrow_hashref($query);
								#patch 13/01/2017 when good accession number and not acc_g / coz mutalyzer position converter's seems a little bit outdated
								if (!$res3)	{
									my $query = "SELECT nom[1] as gene_name, acc_g, mutalyzer_version, mutalyzer_acc FROM gene WHERE nom[2] = '$acc' AND main = 't';";
									$res3 = $dbh->selectrow_hashref($query);
								}
								
								#print $query;
								if ($res3) {
									$main = 1;
									#if ($nom =~ /\*/o || $nom =~ /[cn]\..+d[^eu].+/o) {###TO DO wrong * does not mean 3UTR OK TO BE TESTED 18/09/2014
									#if ($nom =~ /[cn]\..+d[^eu].+/o) {
									#	$type_segment = '3UTR';
									#	my $query = "SELECT numero FROM segment WHERE nom_gene[1] = '$res3->{'gene_name'}' AND nom_gene[2] = '$acc' AND type = '3UTR';";
									#	my $res4 = $dbh->selectrow_hashref($query);
									#	$num_segment = $res4->{'numero'};
									#	#print $nom_g3UTR\n";
									#}
									##elsif ($nom =~ /[cn]\.-.+/o || $nom =~ /[cn]\..+u[^p].+/o) {$type_segment = '5UTR';$num_segment = '-1';} ##AND c.- does not mean 5UTR
									#elsif ($nom =~ /[cn]\..+u[^p].+/o) {$type_segment = '5UTR';$num_segment = '-1';}
									#elsif ($nom =~ /c.\d+[\+-]/o) {
									#	$type_segment = 'intron';
									#	if ($nom =~ /[cn]\.\d+[\+-][12]\D.+/o) {$type_arn = 'altered'}
									#}
									#else {
									#	$type_segment = 'exon';					
									#}
									#if (!$type_arn) {
									$type_arn = 'neutral';
									#}
									#if (!$num_segment) {
									my $query = "SELECT numero, type FROM segment WHERE nom_gene[2] = '$acc' AND '$start' BETWEEN SYMMETRIC $postgre_start_g AND $postgre_end_g AND '$end' BETWEEN SYMMETRIC $postgre_start_g AND $postgre_end_g;";
									#print $query\n";
									my $res4 = $dbh->selectrow_hashref($query);
									if ($res4) {$type_segment = $res4->{'type'};$num_segment = $res4->{'numero'};}
									else {
										my $query = "SELECT numero, type FROM segment WHERE nom_gene[2] = '$acc' AND '$start' BETWEEN SYMMETRIC $postgre_start_g AND $postgre_end_g;";
										my $res4 = $dbh->selectrow_hashref($query);
										if ($res4) {$type_segment = $res4->{'type'};$num_segment = $res4->{'numero'};}
										$query = "SELECT numero, type FROM segment WHERE nom_gene[2] = '$acc' AND '$end' BETWEEN SYMMETRIC $postgre_start_g AND $postgre_end_g;";
										$res4 = $dbh->selectrow_hashref($query);
										if ($res4) {$num_segment_end = $res4->{'numero'};$type_segment_end = $res4->{'type'};}
										else {$manual .= "SEGMENT ERROR$manual_temp";$stop = 1;}
									}
									#}
									if (!$num_segment_end) {$num_segment_end = $num_segment;$type_segment_end = $type_segment;}
									if ($nom =~ /[cn]\.\d+[\+-][12]\D.+/o) {$type_arn = 'altered'}
									##
									## Now we can run Mutalyzer...
									##
									#print "New variant: $res3->{'acc_g'}($res3->{'gene_name'}):$nom<br/>";
									#print STDERR "Sample $id$number Variant $res3->{'acc_g'}, $res3->{'gene_name'} $nom $genomic_var\n";
									$call = U2_modules::U2_subs_1::run_mutalyzer($soap, $res3->{'acc_g'}, $res3->{'gene_name'}, $nom, $res3->{'mutalyzer_version'}, $res3->{'mutalyzer_acc'});
									if ($call->fault()) {$stop = 1;$manual .= "MUTALYZER FAULT$manual_temp";next POSCONV2;}
									
									##10/07/2015
									##add possibility to use mutalyzer identifier (i.e. for RPGR)
									my $gid = 'NG';
									if ($res3->{'mutalyzer_acc'} && $res3->{'mutalyzer_acc'} ne '') {$gid = '[NU][GD]'}
									
									## Deal with warnings and errors
									## data types will be different depending on the number of results
									## we inelegantly use Data::Dumper to check
									
									
									#print "\n\nrunMutalyzer\n\n", $call->result->{'summary'}, "\n";
									my @errors;
									
									
									my $hgvs = 0;
									if ($call) {
										if ($call->result->{'messages'}) {	
											foreach ($call->result->{'messages'}->{'SoapMessage'}) {
												#print Dumper($_);
												my $tab_ref_message;
												#if (Dumper($_) =~ /\[/og) { ## multiple results: tab ref
												#	$tab_ref_message = $_;
												#}
												#else {
												#	$tab_ref_message->[0] = $_;	
												#}
												if (ref($_) eq 'ARRAY') {$tab_ref_message = $_}
												else {$tab_ref_message->[0] = $_}
												MESSAGE: foreach (@{$tab_ref_message}) {
													if ($_->{'message'} =~ /HGVS/o) {$stop = 1;$manual .= "HGVS$manual_temp";$treated = 1;last MESSAGE;}#&HGVS($_->{'message'}, $line, $nom_g);$stop = 1;$not_done .= "HGVS$var";last;}
													elsif ($_->{'message'} =~ /identical/o) {$stop = 1;$manual .= "Identical variant to reference$manual_temp";$treated = 1;last MESSAGE;}
													elsif ($_->{'message'} =~ /Position.+range/o) {$stop = 1;$manual .= "Out of range$manual_temp";$treated = 1;last MESSAGE;}
													elsif ($_->{'message'} =~ /position.+found\s([ATGC])\sinstead/o) {
														#check wt mut nt from genomic_var
														#if inverted and hemi/hetero, then rerun
														#if inverted and homo last;
														my $found = $1;												
														if ($nom =~/\d+([ATGC])>([ATCG])/o) {
															#my ($wt, $mt) = ($1, $2);
															if ($found eq $2) {
																if ($status ne 'homozygous') {
																	$nom =~ s/(\d+)([ATGC])>([ATCG])/$1$3>$2/;
																	$genomic_var =~ s/(\d+)([ATGC])>([ATCG])/$1$3>$2/;
																	
																	$call = U2_modules::U2_subs_1::run_mutalyzer($soap, $res3->{'acc_g'}, $res3->{'gene_name'}, $nom, $res3->{'mutalyzer_version'}, $res3->{'mutalyzer_acc'});
																	if ($call->fault()) {$stop = 1;$manual .= "MUTALYZER FAULT$manual_temp";last;}
																	$query_gs = "SELECT u2_name FROM gs2variant WHERE gs_name = '$first_genomic_var' AND (reason LIKE 'MiSeq_%' OR reason LIKE 'inv_nt');";
																	$res_gs = $dbh->selectrow_hashref($query_gs);
																	if ($res_gs) {$genomic_var = $res_gs->{'u2_name'}}
																	else {
																		$insert = "INSERT INTO gs2variant (gs_name, u2_name, reason) VALUES ('$first_genomic_var', '$genomic_var', 'MiSeq_inverted');";
																		$dbh->do($insert);
																	}
																	$treated = 1;
																	last MESSAGE;
																}
																else {$not_inserted .= "Not inserted because of homozygous wt$manual_temp";last MESSAGE}
															}
															else {$stop = 1;$manual .= "Bad wt nt$manual_temp";last MESSAGE;}
														}
														else {$stop = 1;$manual .= "Bad wt nt$manual_temp";last MESSAGE;}
														
													}#&bad_wt($line, $nom_g);$stop = 1;$not_done .= "bad wt nt$line";last;}
													elsif ($_->{'errorcode'} && $_->{'errorcode'} ne 'WSPLICE') {push @errors, $_} ## if you want to deal with error and/or warning codes
												}	
											}
										}
										foreach(@errors) {
											foreach my $key (keys %{$_}) {$manual .= $key.$_->{$key}.$manual_temp}
											#"$_\n";
										}
										if ($call->result->{'errors'} == 0 && $stop == 0) {
											## let's go
											## IVS name
											if ($type_segment eq 'intron') {
												#my $moins = $num_segment + 1;
												my $query = "SELECT nom FROM segment WHERE nom_gene[2] = '$acc' AND numero = '$num_segment';";
												my $res = $dbh->selectrow_hashref($query);
												my $nom_segment = $res->{'nom'};
												if ($nom =~ /c\.[-*]?(\d+[\+-].+_[-*]?\d+[\+-].+)/o){$nom_ivs = $1;$nom_ivs =~ s/\d+([\+-].+)_[-*]?\d+([\+-].+)/IVS$nom_segment$1_IVS$nom_segment$2/og;}
												elsif ($nom =~ /c\.[-*]?(\d+[\+-][^\+-]+)/o) {$nom_ivs = $1;$nom_ivs =~ s/\d+([\+-][^\+-]+)/IVS$nom_segment$1/og;}
											}
											#foreach my $key (keys(%{$call->result})) {print "$key\n".($call->result->{$key})."\n"}
											#exit;
											## variant sequence
											if ($call->result->{'rawVariants'}) {
												foreach ($call->result->{'rawVariants'}->{'RawVariant'}) {
													#print "\nDescription:\n",  $_->{'description'}, "\n";
													my @seq = split("\n", $_->{'visualisation'});
													$seq_wt = $seq[0];
													#print STDERR "$seq_wt\n$seq_mt\n";
													$seq_mt = $seq[1];
													if ($seq_wt =~ /[ATGC]\s([ATCG-]+)\s[ATGC]/o) {$taille = length($1)}
													elsif ($seq_mt =~ /[ATGC]\s([ATCG-]+)\s[ATGC]/o) {$taille = length($1)}
													#print "\nVisualisation:\n",  $_->{'visualisation'}, "\n";	
												}
											}
											## Genomic description
											#print "\nGenomic description: ", $call->result->{'genomicDescription'}, "\n";
											$call->result->{'genomicDescription'} =~ /($gid)_\d+\.?\d:(g\..+)/g;
											$nom_ng = $2;
											if ($nom_ng =~ />/o) {$type_adn = 'substitution'}
											elsif ($nom_ng =~ /delins/o) {$type_adn = 'indel'}
											elsif ($nom_ng =~ /ins/o) {$type_adn = 'insertion'}
											elsif ($nom_ng =~ /del/o) {$type_adn = 'deletion'}
											elsif ($nom_ng =~ /dup/o) {$type_adn = 'duplication'}
											
											#correct mutalyzer which places e.g. [16bp] instead of sequence
											if ($taille > 15) {
												if ($genomic_var =~ /.+[di][nu][sp]([ATCG]+)$/) {
													my $ins = $1;
													if ($seq_mt =~ /^[ATGC]+\s[ATCGbp\s\[\d\]]+\s[ATCG]+$/) {$seq_mt =~ s/^([ATGC]+\s)[ATCGbp\s\[\d\]]+(\s[ATCG]+)$/$1$ins$2/}												
												}
												elsif ($genomic_var =~ /.+del([ATCG]+)$/) {
													my $del = $1;
													#TTAATGAAATACCATTAAGAGGAAG AATACT [23bp] CTATAT ATTTCTACACTTTATATATATAAAC
													if ($seq_wt =~ /^[ATGC]+\s[ATCGbp\s\[\d\]]+\s[ATCG]+$/) {$seq_wt =~ s/^([ATGC]+\s)[ATCGbp\s\[\d\]]+(\s[ATCG]+)$/$1$del$2/}
												}
											}
											
											
											
											my $true_version = "";
											#GPR98 no longer works with mutalyzer
											#patch 23/10/2017
											my $gene = $res3->{'gene_name'};
											if ($gene eq 'GPR98') {$gene = 'ADGRV1'}
											## Transcript description (submission) get version of isoform
											if ($call->result->{'transcriptDescriptions'}) {
												foreach ($call->result->{'transcriptDescriptions'}->{'string'}) {
													my $tab_ref;
													if (ref($_) eq 'ARRAY') {$tab_ref = $_}
													else {$tab_ref->[0] = $_}
													
													#if (Dumper($_) =~ /\[/og) { ## multiple results: tab ref
													foreach(@{$tab_ref}) {
														#$_ =~ /NG_\d+\.\d\((\w+)\):(c\..+)/o;
														#BUG corrected 03/25/2015
														#when multiple genes on same NG, AND
														#last nom involves a "n."
														#then true_version was reset to uninitialize
														#if added
														#see test_mutalyzer_pde6a.pl on 158 for details
														
														if (/($gid)_\d+\.?\d\((\w+)\):(c\..+)/o) {
															my ($version, $variant) = ($2, $3);
															#print $version-$var-$nom-\n";
															if ($nom =~ /$variant/) {
																$version =~ /($gene)_v(\d{3})/;
																$true_version = $2;
																#print "\n$true_version\n";
															}
														}													
														#print "\nTranscript Description: ", $_, "\n"
													}
													#}
													#else {
													#	#print $_\n";
													#	$_ =~ /NG_\d+\.\d\((\w+)\):(c\..+)/o;
													#	
													#	my ($version, $variant) = ($1, $2);
													#	#print $version-$var-$nom-\n";
													#	if ($nom =~ /$variant/) {
													#		$version =~ /($res3->{'gene_name'})_v(\d{3})/;
													#		$true_version = $2;
													#		#print "\nONE$true_version\n";
													#	}
													#
													#	#print "\nTranscript Description: ", $_, "\n"
													#}
												}
											}
											## Protein description
											
											if ($call->result->{'proteinDescriptions'}) {
												foreach ($call->result->{'proteinDescriptions'}->{'string'}) {
													my $tab_ref;
													if (ref($_) eq 'ARRAY') {$tab_ref = $_}
													else {$tab_ref->[0] = $_}
													#$manual .= $tab_ref->[0]."\n";
													#if (Dumper($_) =~ /\[/og) { ## multiple results: tab ref
													foreach(@{$tab_ref}) {
														if ($_ =~ /($gene)_i$true_version\):(p\..+)/) {$nom_prot = $2}
														if ($gene =~ /(PDE6A|TECTA|CDH23|RPGR)/o) {
															$to_follow .= "$1 variant to check: $nom\t$_\ttrue version:$true_version\tigd:$gid\tnom_prot:$nom_prot\n"
														}
														
														#print "\nProtein Description: ", $_, "\n"
													}
													#}
													#else {
													#	if ($_ =~ /($res3->{'gene_name'})_i$true_version\):(p\..+)/) {$nom_prot = $2}
													#	#print "\nProtein Description: ", $_, "\n"
													#}
												}
												if ($nom_prot ne 'NULL') {
													if ($nom_prot =~ /fs/o) {$type_prot = 'frameshift'}
													elsif ($nom_prot =~ /\*/o) {$type_prot = 'nonsense'}
													elsif ($nom_prot =~ /del/o) {$type_prot = 'inframe deletion'}
													elsif ($nom_prot =~ /dup/o) {$type_prot = 'inframe duplication'}
													elsif ($nom_prot =~ /ins/o) {$type_prot = 'inframe insertion'}
													elsif ($nom =~ /c\.[123][ATGCdelupins_]/o) {$type_prot = 'start codon'}
													elsif ($nom_prot =~ /\*/o) {$type_prot = 'nonsense'}
													elsif ($nom_prot =~ /=/o && $type_segment eq 'exon') {$type_prot = 'silent'}
													elsif ($nom_prot =~ /=/o && $type_segment ne 'exon') {$type_prot = 'NULL'}
													elsif ($nom_prot =~ /[^\\^?^=]/o) {$type_prot = 'missense'}
												}
												else {$nom_prot = 'p.(=)';$type_prot = 'NULL';}
												#else {$type_prot = 'NULL'}
											}
											
											
											#snp
											($snp_id, $snp_common) = ('NULL', 'NULL');
											#my $sign = '=';
											#if ($variant =~ /(del|dup)/) {$sign = '~'}
											my $snp_query = "SELECT rsid, common FROM restricted_snp WHERE ng_var = '$res3->{'acc_g'}:$nom_ng';";
											if ($nom_ng =~ /d[eu][lp]/o) {$snp_query = "SELECT rsid, common FROM restricted_snp WHERE ng_var like '$res3->{'acc_g'}:$nom_ng%';"}
											
											my $res_snp = $dbh->selectrow_hashref($snp_query);
											if ($res_snp) {$snp_id  = $res_snp->{rsid};$snp_common = $res_snp->{common};}
											
											if (($type_adn =~ /(deletion|insertion|duplication)/o) && ($taille < 5) && ($nom =~ /(.+d[eu][lp])$/o)) {
												my $tosend = $seq_mt;
												if ($type_adn eq 'deletion') {$tosend = $seq_wt}								
												my $sequence = U2_modules::U2_subs_1::get_deleted_sequence($tosend);
												$nom .= $sequence;
												if ($nom_ivs ne 'NULL') {$nom_ivs .= $sequence}
											}										
											#
											### let's go
											#if ($nom =~ /(.+d[eu][lp])[ATCG]+$/) {$nom = $1} #we remove what is deleted or duplicated
											if ($genomic_var =~ /(.+d[eu][lp])[ATCG]+$/o) {$genomic_var = $1} #we remove what is deleted or duplicated
											my $classe = 'unknown';
											if ($var_vf =~ /R8/o) {$classe = 'R8'}
											
											$insert = "INSERT INTO variant (nom, nom_gene, nom_g, nom_ng, nom_ivs, nom_prot, type_adn, type_arn, type_prot, classe, type_segment, num_segment, num_segment_end, taille, snp_id, snp_common, commentaire, seq_wt, seq_mt, type_segment_end, creation_date, referee) VALUES ('$nom', '{\"$res3->{'gene_name'}\",\"$acc\"}', '$genomic_var', '$nom_ng', '$nom_ivs', '$nom_prot', '$type_adn', '$type_arn', '$type_prot', '$classe', '$type_segment', '$num_segment', '$num_segment_end', '$taille', '$snp_id', '$snp_common', 'NULL', '$seq_wt', '$seq_mt', '$type_segment_end', '$date', 'ushvam2');";
											print STDERR "$insert\n";
											$insert =~ s/'NULL'/NULL/og;
											#print "$insert_temp<br/>";
											$dbh->do($insert);
											#$insert.= "$insert_temp\n";										
											
											#$dbh->do("INSERT INTO variant2patient (nom_c, num_pat, id_pat, nom_gene, type_analyse, statut, allele, depth, frequency, msr_filter) VALUES ('$nom', '$number', '$id', '{\"$res3->{'gene_name'}\", \"$acc\"}', '$analysis', '$status', '$allele', '$depth', '$freq', '$filter');");
											$insert = "INSERT INTO variant2patient (nom_c, num_pat, id_pat, nom_gene, type_analyse, statut, allele, depth, frequency, msr_filter) VALUES ('$nom', '$number', '$id', '{\"$res3->{'gene_name'}\", \"$acc\"}', '$analysis', '$status', '$allele', '$var_dp', '$var_vf', '$var_filter');";
											#print $insert;
											$dbh->do($insert);
											$treated = 1;
											$i++;
											$j++;
											last POSCONV2;##not tested							
										}
									}
									else {$mutalyzer_no_answer .= "\t$id$number\t$first_genomic_var\t$genomic_var\t$analysis\t'$status', 'unknown', '$var_dp', '$var_vf', '$var_filter');\n\n"}
								}
								#else {$manual .= "UNUSUAL ACC_NO\t$manual_temp";}
							}
							elsif (/NR_.+/) {#deal with NR for NR, a number conversion should be enough
								$nr = "NR_variant\t$id$number\t$genomic_var\t$analysis\t'$status', 'unknown', '$var_dp', '$var_vf', '$var_filter');\n";
							}
						}		
						
						#if ($main == 0 && $treated == 0) {$manual .= "UNUSUAL ACC_NO\t$id$number\t$genomic_var\t$analysis\t$status\t$var_dp\t$var_vf\t$var_filter\n$nr"}#$treated is not mandatory here
						if ($main == 0 && $treated == 0) {$manual .= "UNUSUAL ACC_NO\t$id$number\t$genomic_var\t$analysis\t'$status', 'unknown', '$var_dp', '$var_vf', '$var_filter');\n$nr"}#$treated is not mandatory here
						
						#$not_done .= "$id$num\t$var\t$depth\t$freq\t".($fwd_tot-$fwd_var)."\t".($rev_tot-$rev_var)."\t$fwd_var\t$rev_var\n";
	
					}
				}
				else {
					$manual .= "MUTALYZER NO RESULT $genomic_var\n"
				}
				### end gsdot2u2.cgi
				
				
				
				
				
				
			}
			#elsif ($_ !~ /#/o) {#TODO do sthg with non mappable variants
			#	$manual .= "#NON MAPPABLE\n$_\n";
			#}
		}
		close F;
		#print "<br/><br/>Already known variants by rs: $i<br/>others known variants by u2: $j<br/>$insert";
		#$dbh->do($insert)
		#print $insert;
		#print $q->start_p(), $q->span("Insertion for "), $q->strong({'onclick' => "window.location = 'patient_file.pl?sample=$id$number'", 'class' => 'pointer'}, $id.$number), $q->span(":"), $q->start_ul(), "\n",
		#	$q->li("$i/$k variants (".(sprintf('%.2f', ($i/$k)*100))."%) have been automatically inserted,"), "\n",
		#	$q->li("including $j new variants that have been successfully created"), $q->end_ul(), $q->br(), $q->br(), "\n";
		$general .= "Insertion for $id$number:\n\n- $i/$k variants (".(sprintf('%.2f', ($i/$k)*100))."%) have been automatically inserted,\nincluding $j new variants that have been successfully created\n\n";
		my $valid = "UPDATE miseq_analysis SET valid_import = 't' WHERE id_pat = '$id' AND num_pat = '$number' AND type_analyse= '$analysis';";
		$dbh->do($valid);
		
	}
	#if ($manual ne '' || $not_inserted ne '') {U2_modules::U2_subs_2::send_manual_mail($user, $manual, $not_inserted, $run)}
	
	U2_modules::U2_subs_2::send_manual_mail($user, $manual, $not_inserted, $run, $general, $mutalyzer_no_answer, $to_follow);
	
	$q->redirect("patient_file.pl?sample=$sample_end"); 
	
}


##Basic end of USHVaM 2 perl scripts:

U2_modules::U2_subs_1::standard_end_html($q);

print $q->end_html();

exit();

##End of Basic end

##specific subs for current script

sub build_sample_hash {
	my ($q, $analysis, $filtered) = @_;
	#samples are grouped under the same name, and are like X_SUXXX
	#filters arrive independantly, as X_filter
	#X is the linker between both
	
	my @false_list = $q->param('sample');
	my %list;
	foreach (@false_list) {
		if (/(\d+)_(\w+)/o) {$list{join('', U2_modules::U2_subs_1::sample2idnum($2, $q))} = $1;}
	}
	if ($filtered == 1) {
		foreach my $key (keys(%list)) {
			if ($q->param($list{$key}.'_filter') =~ /^$ANALYSIS_MISEQ_FILTER$/) {$list{$key} = $1}
			else {U2_modules::U2_subs_1::standard_error('20', $q)}
		}
	}
	else {
		foreach my $key (keys(%list)) {$list{$key} = 'ALL'}
	}
	return %list
}

sub search_position {
	my ($chr, $pos) = @_;
	my $query = "SELECT a.nom, a.nom_gene, a.type FROM segment a, gene b WHERE a.nom_gene = b.nom AND b.chr = '$chr' AND '$pos' BETWEEN SYMMETRIC a.$postgre_start_g AND a.$postgre_end_g;";
	my $res = $dbh->selectrow_hashref($query);
	if ($res ne '0E0') {return "\t$res->{'nom_gene'}[0] - $res->{'nom_gene'}[1]\t$res->{'type'}\t$res->{'nom'}"}
	else {return "\tunknown position in U2\tunknown\tunknown"}
	
}

sub build_hgvs_from_illumina {
	my ($var_chr, $var_pos, $var_ref, $var_alt) = @_;
	#we keep only the first variants if more than 1 e.g. alt = TAA, TA
	if ($var_alt =~ /^([ATCG]+),/) {$var_alt = $1}
	
	#subs
	if ($var_ref =~ /^[ATGC]$/ && $var_alt =~ /^[ATGC]$/) {return "$var_chr:g.$var_pos$var_ref>$var_alt"}
	#dels
	elsif (length($var_ref) > length($var_alt)) {
		if (length($var_ref) == 2) {return "$var_chr:g.".($var_pos+1)."del".substr($var_ref, 1)}
		else {return "$var_chr:g.".($var_pos+1)."_".($var_pos+(length($var_ref)-1))."del".substr($var_ref, 1)}
	}
	#insdup
	elsif (length($var_alt) > length($var_ref)) {return "$var_chr:g.".($var_pos)."_".($var_pos+1)."ins".substr($var_alt, 1)}
}

sub direct_submission {
	#my ($toquery, $value, $number, $id, $analysis, $status, $allele, $var_dp, $var_vf, $var_filter, $dbh) = @_;
	
	my ($value, $number, $id, $analysis, $status, $allele, $var_dp, $var_vf, $var_filter, $dbh) = @_;
	#print STDERR $value."\n";
	if ($value =~ /(.+d[eu][lp])[ATCG]+$/) {$value = $1} #we remove what is deleted or duplicated	
	my $query = "SELECT nom, nom_gene FROM variant WHERE nom_g = '$value';";
	#print $query;
	my $res = $dbh->selectrow_hashref($query);
	if ($res) {
		return "INSERT INTO variant2patient (nom_c, num_pat, id_pat, nom_gene, type_analyse, statut, allele, depth, frequency, msr_filter) VALUES ('$res->{'nom'}', '$number', '$id', '{\"$res->{'nom_gene'}[0]\",\"$res->{'nom_gene'}[1]\"}', '$analysis', '$status', '$allele', '$var_dp', '$var_vf', '$var_filter');";
	}
	else {return ''}
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
	if ($var =~ /chr[\dXY]+:g\.(\d+)[dATCG][eu>][lpATCG].*/o) {return ($1, $1)}
	elsif ($var =~ /chr[\dXY]+:g\.(\d+)_(\d+)[di][enu][lsp].*/o) {return ($1, $2)}
}


#####
#####
#####
#The following subs have been implemented to try to deal with PTPRQ-hg19 issues. But the issues are too big with this gene in hg19. Hope will be fixed when we move on to hg38. However they work on strand + for a gene that starts with ATG in exon 1 (exon 1 +1 = ATG +1)
#####
#####
#####
#sub position_converter {
#	my $genomic_var = shift; #add $dbh if put in .pm
#	#print "$genomic_var<br/>";
#	if ($genomic_var =~ /chr12:g\.(\d+)([dATCG][e>][lATGC])/o) {
#		#my ($pos_geno, $consequence) = ($1, $2);
#		#print "$1 - $2<br/>";
#		return "NM_001145026.1:c.".&map_on_gene($1).$2;
#	}#chr12:g.80878181_80878182insT
#	elsif ($genomic_var =~ /chr12:g\.(\d+)_(\d+)(del|ins)([ATGC]+)/o) {
#		#my ($pos_geno1, $pos_geno2, $consequence) = ($1, $2, $3);
#		#print "$1 - $2 - $3 - $4<br/>";
#		return "NM_001145026.1:c.".&map_on_gene($1)."_".(&map_on_gene($2)).$3.$4;
#	}
#}
#
#sub map_on_gene {
#	my $pos_geno = shift;
#	my $query = "SELECT type, numero, start_g, end_g, taille FROM segment WHERE nom_gene[1] = 'PTPRQ' AND '$pos_geno' BETWEEN SYMMETRIC start_g AND end_g";
#	#print "$query<br/>";
#	my $res = $dbh->selectrow_hashref($query);
#	if ($res) {
#		my ($type, $num, $start_g, $end_g, $size) = ($res->{'type'}, $res->{'numero'}, $res->{'start_g'}, $res->{'end_g'}, $res->{'taille'});
#		$query = "SELECT SUM(taille) as taille FROM segment WHERE nom_gene[1] = 'PTPRQ' AND type = 'exon' AND numero < '$num';";
#		print "$query<br/>";
#		my $res = $dbh->selectrow_hashref($query);
#		if ($type eq 'exon') {return (($pos_geno - $start_g) + $res->{'taille'})}
#		else {
#			if (($pos_geno - $start_g) <= ($size/2)) {return "$res->{'taille'}+".($pos_geno - $start_g)}
#			else {return ($res->{'taille'}+1)."-".($end_g - $pos_geno)}
#		}
#	}
#}

