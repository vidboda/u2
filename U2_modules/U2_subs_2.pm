package U2_modules::U2_subs_2;

use U2_modules::U2_init_1;
use U2_modules::U2_subs_1;
use U2_modules::U2_subs_3;
#use Apache::Reload;
#remove above line for production!!!
use List::Util qw(first max maxstr min minstr reduce shuffle sum);
use URI::Encode qw(uri_encode uri_decode);
# use Bio::DB::GenBank;
# use Bio::Graphics;
use Net::SSLGlue::SMTP;
use Authen::SASL;
#use Net::SMTP;
use strict;
use warnings;


#   This program is part of ushvam2, USHer VAriant Manager version 2
#    Copyright (C) 2012-2015  David Baux
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
#		general subroutines and variables

#subs for genotyping

my $config_file = U2_modules::U2_init_1->getConfFile();
my $config = U2_modules::U2_init_1->initConfig();
$config->file($config_file);# or die $!;
my $HTDOCS_PATH = $config->HTDOCS_PATH();
my $ABSOLUTE_HTDOCS_PATH = $config->ABSOLUTE_HTDOCS_PATH();
my $RS_BASE_DIR = $config->RS_BASE_DIR();
my $PATIENT_IDS = $config->PATIENT_IDS();
my $ANALYSIS_MISEQ_FILTER = $config->ANALYSIS_MISEQ_FILTER();
my $CLINICAL_EXOME_BASE_DIR = $config->CLINICAL_EXOME_BASE_DIR();
my $ANALYSIS_ILLUMINA_WG_REGEXP = $config->ANALYSIS_ILLUMINA_WG_REGEXP();
my $HOME_IP = $config->HOME_IP();
my $ANALYSIS_MINISEQ2 = $config->ANALYSIS_MINISEQ2();

#hg38 transition variable for postgresql 'start_g' segment field
my ($postgre_start_g, $postgre_end_g) = ('start_g', 'end_g');  #hg19 style

sub get_patient_name {
	my ($id, $number, $dbh) = @_;
	my $query = "SELECT first_name, last_name, date_of_birth FROM patient WHERE numero = '$number' and identifiant = '$id';";
	my $res = $dbh->selectrow_hashref($query);
	return ($res->{'first_name'}, $res->{'last_name'}, $res->{'date_of_birth'});
}

sub is_in_interval {
	my ($var, $mini, $maxi) = @_;
	#my $pos;
	$var->{'nom_g'} =~ /chr\w+:g\.(\d+)[^\d]+.+/o;
	my $pos = $1;
	if (($var->{'num_segment'} eq $var->{'num_segment_end'}) && ($pos >= $mini && $pos <= $maxi)) {return 1}
	else {return 0}
}

sub print_validation_table {
	my ($first_name, $last_name, $DoB, $gene, $q, $dbh, $user, $class) = @_;

	my $div_class = 'patient_file_frame';
	if ($class eq 'global') {$div_class = 'container'}
	print $q->start_div({'class' => $div_class}), $q->start_table({'class' => "technical great_table $class", 'id' => 'validation_table'}), $q->caption("Validation table:"), $q->start_thead(),
	$q->start_Tr(), "\n",
		$q->th('sample ID'), "\n";
	if ($gene eq '') {print $q->th('gene'), "\n";}
	print $q->th({'class' => 'left_general'}, 'Analysis type'), "\n",
		$q->th({'class' => 'left_general'}, 'technical'), "\n",
		$q->th({'class' => 'left_general'}, 'date'), "\n",
		$q->th({'class' => 'left_general'}, 'user'), "\n",
		$q->th({'class' => 'left_general'}, 'result'), "\n",
		$q->th({'class' => 'left_general'}, 'date'), "\n",
		$q->th({'class' => 'left_general'}, 'user'), "\n",
		$q->th({'class' => 'left_general'}, 'biological'), "\n",
		$q->th({'class' => 'left_general'}, 'date'), "\n",
		$q->th({'class' => 'left_general'}, 'user'), "\n";
	if ($user->isAnalyst() == 1) {print $q->th({'class' => 'print_hidden'},'access'), "\n";}
	print $q->end_Tr(), $q->end_thead(), $q->start_tbody(), "\n";

	my $sql_DoB = "'$DoB'";
	if ($DoB eq '') { $sql_DoB = 'NULL'}
	my $query = "SELECT *, c.gene_symbol as nom_gene FROM analyse_moleculaire a, patient b, gene c, valid_type_analyse d WHERE a.num_pat = b.numero AND a.id_pat = b.identifiant AND a.refseq = c.refseq AND a.type_analyse = d.type_analyse AND b.first_name = '$first_name' AND b.last_name = '$last_name' AND (b.date_of_birth = $sql_DoB OR b.date_of_birth IS NULL) AND c.gene_symbol = '$gene' AND c.main = 't' ORDER BY c.gene_symbol, a.type_analyse;";
	if ($gene eq '') {
		$query = "SELECT *, c.gene_symbol as nom_gene FROM analyse_moleculaire a, patient b, gene c, valid_type_analyse d  WHERE a.num_pat = b.numero AND a.id_pat = b.identifiant AND a.refseq = c.refseq AND a.type_analyse = d.type_analyse AND b.first_name = '$first_name' AND b.last_name = '$last_name' AND (b.date_of_birth = $sql_DoB OR b.date_of_birth IS NULL) AND c.main = 't' ORDER BY c.gene_symbol, a.type_analyse;";
	}
	# print STDERR "$query\n";

	my $sth = $dbh->prepare($query);
	my $res = $sth->execute();
	my ($id, $number);
	while (my $result = $sth->fetchrow_hashref()) {
		# filter for Illumina NGS
		my $display = 1;
		if ($result->{'filtering_possibility'}  == 1) {
			# get filter
			$display = &gene_to_display($result, $dbh);
		}
		# print STDERR "$display\n";
		if ($display == 1) {
			my ($alignement_file_path, $file_type) = ('', '');
			($id, $number) = ($result->{'id_pat'}, $result->{'num_pat'});
			#illumina
			my ($addin, $index_ext) = ('', 'bai');
			if ($result->{'manifest_name'} ne 'no_manifest' && $class ne 'global') {
				#get bam path
				($alignement_file_path, $file_type) = &get_alignement_path($result->{'identifiant'}, $result->{'numero'}, $result->{'type_analyse'}, $dbh);
				if ($result->{'type_analyse'} =~ /Mi/o) {$addin = '.bam'}
				#print $bam_path;
			}
			if ($file_type eq 'crumble.cram') {$index_ext = 'crai';$addin = ".$file_type"}
			elsif ($file_type eq 'cram') {$index_ext = 'crai';$addin = ".$file_type"}
			print $q->start_Tr(), "\n",
				$q->td($result->{'identifiant'}.$result->{'numero'}), "\n";
			if ($gene eq '') {print $q->start_td(), $q->em($result->{'nom_gene'}), $q->end_td(), "\n"}
			my $chr = U2_modules::U2_subs_1::get_chr_from_gene($gene, $dbh);
			if ($result->{'manifest_name'} eq 'no_manifest') {print $q->td($result->{'type_analyse'}), "\n"}
			elsif ($class ne 'global' && $chr ne 'M') {

				print $q->start_td(), $q->button({'id' => $result->{'type_analyse'}, 'title' => 'click to load BAM/CRAM file in IGV', 'onclick' => "igv.browser.loadTrack({url:'$alignement_file_path.$file_type', indexURL:'$alignement_file_path$addin.$index_ext', label:'$id$number-$result->{'type_analyse'}-$gene'});\$('#$result->{'type_analyse'}').removeClass('pointer');\$('#$result->{'type_analyse'}').removeAttr('onclick');\$('#$result->{'type_analyse'}').removeAttr('title');", 'class' => 'w3-button w3-ripple w3-blue', 'value' => $result->{'type_analyse'}}), $q->end_td(), "\n"
			}
			else {print $q->td($result->{'type_analyse'}), "\n"}

			print $q->start_td(), $q->span({'class' => U2_modules::U2_subs_1::translate_boolean_class($result->{'technical_valid'})}, U2_modules::U2_subs_1::translate_boolean($result->{'technical_valid'})), $q->end_td(), "\n",
				$q->td($result->{'date_analyse'}), "\n",
				$q->td($result->{'analyste'}), "\n",
				$q->start_td(), $q->span({'class' => U2_modules::U2_subs_1::translate_boolean_class($result->{'result'})}, U2_modules::U2_subs_1::translate_boolean($result->{'result'})), $q->end_td(), "\n",
				$q->td($result->{'date_result'}), "\n",
				$q->td($result->{'referee'}), "\n",
				$q->start_td(), $q->span({'class' => U2_modules::U2_subs_1::translate_boolean_class($result->{'valide'})}, U2_modules::U2_subs_1::translate_boolean($result->{'valide'})), $q->end_td(), "\n",
				$q->td($result->{'date_valid'}), "\n",
				$q->td($result->{'validateur'}), "\n";
			my $step = 3;
			if ($result->{'form'} == 1 && $result->{'manifest_name'} eq 'no_manifest') {$step = 2}
			if ($user->isAnalyst() == 1) {print $q->start_td({'class' => 'print_hidden'}), $q->button({'onclick' => "window.location='add_analysis.pl?step=$step&sample=$id$number&gene=".$result->{'nom_gene'}."&analysis=".$result->{'type_analyse'}."'", 'value' => 'modify', 'class' => 'w3-button w3-ripple w3-blue'}), $q->end_td(), "\n"}

			print $q->end_Tr(), "\n";
		}

	}
	print $q->end_tbody(), $q->end_table(), $q->end_div();

}

sub gene_to_display {
	my ($data, $dbh) = @_;
	my $query = "SELECT filter FROM miseq_analysis WHERE num_pat = '$data->{'num_pat'}' AND id_pat = '$data->{'id_pat'}' AND type_analyse = '$data->{'type_analyse'}';";
	my $res = $dbh->selectrow_hashref($query);

	if ($res->{'filter'} eq 'RP') {if ($data->{'rp'} == 1) {return 1}}
	if ($res->{'filter'} eq 'DFN') {if ($data->{'dfn'} == 1) {return 1}}
	if ($res->{'filter'} eq 'USH') {if ($data->{'usher'} == 1) {return 1}}
	if ($res->{'filter'} eq 'DFN-USH') {if ($data->{'dfn'} == 1 || $data->{'usher'} == 1) {return 1}}
	if ($res->{'filter'} eq 'RP-USH') {if ($data->{'rp'} == 1 || $data->{'usher'} == 1) {return 1}}
	if ($res->{'filter'} eq 'CHM') {if ($data->{'nom_gene'} eq 'CHM') {return 1}}
	if ($res->{'filter'} eq 'ALL') {return 1}
	return 0;
}

sub get_miniseq_id {
	my $run_id = shift;
	if ($run_id =~ /^\d{6}_([A-Z]{2}\d{5})_\d{4}_[A-Z0-9]{10}$/o) {
		return $1
	}
	return 'unknown instrument';
}

sub get_alignement_path {
	my ($id, $number, $analysis, $dbh) = @_;
	my ($instrument, $instrument_path) = ('miseq', 'MiSeqDx/USHER');
	my $query_manifest = "SELECT run_id FROM miseq_analysis WHERE num_pat = '$number' AND id_pat = '$id' AND type_analyse = '$analysis';";
	my $res_manifest = $dbh->selectrow_hashref($query_manifest);
	
	if ($analysis =~ /MiniSeq-\d+/o) {$instrument = 'miniseq';$instrument_path = 'MiniSeq'}
	elsif ($analysis =~ /NextSeq-.+/o) {$instrument = 'nextseq';$instrument_path = $CLINICAL_EXOME_BASE_DIR}
	my ($alignment_dir, $additional_path) = ('', '');
	my $run = $res_manifest->{'run_id'};
	if ($instrument eq 'miseq') {
		$alignment_dir = `grep -Eo \"AlignmentFolder>.+\\Alignment[0-9]*<\" $ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/data/$instrument_path/$run/CompletedJobInfo.xml`;
		#print $alignment_dir;
		$alignment_dir =~ /\\(Alignment\d*)<$/o;$alignment_dir = "/Data/Intensities/BaseCalls/$1";
		#print $alignment_dir;
	}
	elsif($instrument eq 'miniseq') {
		my $instrument = U2_modules::U2_subs_2::get_miniseq_id($run);
		if ($instrument eq $ANALYSIS_MINISEQ2) {$additional_path = "/$run"}
		$alignment_dir = `grep -Eo \"AlignmentFolder>.+\\Alignment_?[0-9]*.+<\" $ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/data/$instrument_path/$run$additional_path/CompletedJobInfo.xml`;
		$alignment_dir =~ /\\(Alignment_?\d*.+)<$/o;
		$alignment_dir = $1;
		$alignment_dir =~ s/\\/\//og;
	}
	#elsif($instrument eq 'nextseq') {
	#	my ($ana, $ana_id) = U2_modules::U2_subs_3::get_nenufaar_id($ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/data/$instrument_path/$res_manifest->{'run_id');
	#	#$ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/data/$CLINICAL_EXOME_BASE_DIR/$run
	#	$alignment_dir = $id.$number.$ana;
	#}
	##print $alignment_dir;

	my ($file, $file_type);
	if ($instrument ne 'nextseq') {
		my $file_list = `ls $ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/data/$instrument_path/$run$additional_path/$alignment_dir`;
		#print "ls $ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/data/$instrument_path/$run/$alignment_dir -- $bam_list";
		#print $run;
		# create a hash which looks like {"illumina_run_id" => 0}
		my %files = map {$_ => '0'} split(/\s/, $file_list);
		foreach my $file_name (keys(%files)) {
			#print $file_name;
			if ($file_name =~ /$id$number(_S\d+)\.?(c?r?u?m?b?l?e?\.c?[br]am)$/) {
				my $file_suffix = $1;
				$file = "$alignment_dir/$id$number$file_suffix";
				$file_type = $2;
				$file_type =~ s/^\.//o;
				#$bam_ftp = "$ftp_dir/$id$number$bam_file_suffix";
			}
		}
	}
	else {
		my ($ana, $ana_id) = U2_modules::U2_subs_3::get_nenufaar_id("$ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/data/$instrument_path/$run");
		$file = "$id$number/$ana_id/$id$number";
		if (-e "$ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/data/$instrument_path/$run/$id$number/$ana_id/$id$number.bam") {$file_type = 'bam'}
		elsif (-e "$ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/data/$instrument_path/$run/$id$number/$ana_id/$id$number.crumble.cram") {$file_type = 'crumble.cram'}
		elsif (-e "$ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/data/$instrument_path/$run/$id$number/$ana_id/$id$number.cram") {$file_type = 'cram'}
	}
	return ("$HTDOCS_PATH$RS_BASE_DIR/data/$instrument_path/$run$additional_path/$file", $file_type);
}

sub get_interval {
	my ($first_name, $last_name, $gene, $dbh) = @_;
	my ($mini, $maxi) = (-1, -1);
	my $query = "SELECT MIN(a.num_segment), a.nom_g as mini FROM variant a, variant2patient b, patient c, gene d WHERE a.nom = b.nom_c AND a.refseq = b.refseq AND b.refseq = d.refseq AND b.num_pat = c.numero AND b.id_pat = c.identifiant AND c.first_name = '$first_name' AND c.last_name = '$last_name' AND d.gene_symbol = '$gene' AND a.type_adn = 'deletion' AND a.num_segment <> a.num_segment_end GROUP BY a.nom_g;";

	my $res = $dbh->selectrow_hashref($query);
	if ($res) {$res->{'mini'} =~ /chr\w+:g\.(\d+)[^\d]+(\d+)[^\d]+/o;$mini = min($1, $2)}


	$query = "SELECT MAX(a.num_segment_end), a.nom_g as maxi from variant a, variant2patient b, patient c, gene d WHERE a.nom = b.nom_c AND a.refseq = b.refseq AND b.refseq = d.refseq AND b.num_pat = c.numero AND b.id_pat = c.identifiant AND c.first_name = '$first_name' AND c.last_name = '$last_name' AND d.gene_symbol = '$gene' AND a.type_adn = 'deletion' AND a.num_segment <> a.num_segment_end GROUP BY a.nom_g;";

	$res = $dbh->selectrow_hashref($query);
	if ($res) {$res->{'maxi'} =~ /chr\w+:g\.(\d+)[^\d]+(\d+)[^\d]+/o;$mini = max($1, $2)}
	return ($mini, $maxi);
}

sub get_direction {
	my ($gene, $dbh) = @_;
	#defines gene strand
	my $query = "SELECT brin, refseq, acc_g, acc_version FROM gene WHERE gene_symbol = '$gene' and main = 't';";
	my $res = $dbh->selectrow_hashref($query);
	my ($main_acc, $acc_g, $acc_v) = ($res->{'refseq'}, $res->{'acc_g'}, $res->{'acc_version'});
	my $direction = 'ASC';
	if ($res->{'brin'} eq '-') {$direction = 'DESC'}
	return ($direction, $main_acc, $acc_g, $acc_v);
}

sub print_filter {
	my $q = shift;
	print $q->start_p({'class' => 'print_hidden w3-margin'}), $q->strong('Show/Hide neutral/unknown variants according to:'), $q->end_p(),
	$q->start_ul({'class' => 'print_hidden w3-ul w3-padding-small'}), "\n";
	if (!$q->param('type')) {&add_filter_button($q, 'neutrals', 'neutral', 'neutral variants')}
	&add_filter_button($q, 'dbSNP rs ids', 'rs', 'dbSNP variants');
	&add_filter_button($q, 'dbSNP Common', 'common', 'dbSNP common variants (MAF > 0.01)');
	&add_filter_button($q, 'R8', 'r8', 'variants occuring in homopolymeric regions');
	&add_filter_button($q, 'MSR Filter', 'nopass', 'variants with MSR filter not equal to \'PASS\' (and not seen in Sanger)');
	&add_filter_button($q, 'UTR5', 'utr5', 'variants located in the 5\'UTR regions');
	&add_filter_button($q, 'After stop codon', 'afterstop', 'variants located 3\' of the stop codon');
	&add_filter_button($q, 'Deep introns', 'deepintron', 'variants located > 30 bp far from exons');
	&add_filter_button($q, 'U2 > 3', 'firstseen', 'variants recorded in more than three probands');
	print $q->start_li(), $q->button({'value' => 'Reset all filters', 'title' => 'Show all filtered variants', 'onclick' => 'reset_filters();', 'class' => 'w3-button w3-ripple w3-blue'}), $q->end_li();
	print $q->end_ul();
	#removed maf filter, the main page is now loaded without the information (mafs computed by ajax 04/09/2014) - put neutral filter instead
	#$q->start_li(), $q->span('MAF &gt; 0.01:&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'), $q->button({'id' => 'maf_hide_button', 'value' => 'Hide'}), $q->span('&nbsp;&nbsp;&nbsp;&nbsp;'), $q->button({'id' => 'maf_show_button', 'value' => 'Show'}), $q->span('&nbsp;&nbsp;&nbsp;&nbsp;(currently: '), $q->strong({'id' => 'maf_txt'}, 'shown'), $q->span(')'), $q->end_li(), "\n",
}

sub add_filter_button {
	my ($q, $category, $tag, $title_tag) = @_;
	print $q->start_li({'class' => 'w3-padding-small'}), $q->span({'class' => 'width_span_100'}, "$category:"),
			$q->button({'value' => 'Filter', 'title' => "Hide $title_tag", 'onclick' => "variant_hide('$tag');", 'class' => 'w3-button w3-ripple w3-blue w3-tiny  w3-padding-small'}),#'id' => $tag.'_hide_button',
			#$q->span('&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'),
			#$q->button({'value' => 'Show', 'title' => "Show $title_tag", 'onclick' => "variant_show('$tag');"}),#'id' => $tag.'_show_button',
			$q->span('&nbsp;&nbsp;&nbsp;&nbsp;(currently: '),
			$q->strong({'id' => $tag.'_txt', 'class' => 'green'}, 'shown'), $q->span(')'),
		$q->end_li(), "\n";
}


sub genotype_line_optimised { #prints a line in the genotype table
	my ($var, $mini, $maxi, $q, $dbh, $list, $main_acc, $nb, $acc_g, $global) = @_;
	my $gris = 0;
	if ($mini != -1 || $maxi != -1) {$gris = &is_in_interval($var, $mini, $maxi, $q)}
	my ($gene, $acc) = ($var->{'gene_symbol'}, $var->{'refseq'});


	#print a same variant only once but prints all the identifying analyses
	if ($list->{$var->{'nom'}} && $list->{$var->{'nom'}} >= 1) {return $var->{'nom'}}
	else {
		my $type_analyse;
		my ($firstname, $lastname) = ($var->{'first_name'}, $var->{'last_name'});
		$firstname =~ s/'/''/og;
		$lastname =~ s/'/''/og;
		my $query_analyse = "SELECT a.type_analyse FROM variant2patient a, patient b WHERE a.num_pat = b.numero AND a.id_pat = b.identifiant AND b.first_name ILIKE '$firstname' AND b.last_name ILIKE '$lastname' AND a.refseq = '$acc' AND nom_c = '$var->{'nom'}';";# AND num_pat = '$var->{'num_pat'}' AND id_pat = '$var->{'id_pat'}';";
		#print $query_analyse;exit;
		my $sth_analyse = $dbh->prepare($query_analyse);
		my $res_analyse = $sth_analyse->execute();
		my $display = 1;
		while (my $result = $sth_analyse->fetchrow_hashref()) {$type_analyse .= $result->{'type_analyse'}."/"}

		chop($type_analyse);

		my $color = U2_modules::U2_subs_1::color_by_classe($var->{'classe'}, $dbh);

		#get usual name for exon/intron
		my $nom_seg = $var->{'nom_seg'};

		#for LR
		my $bg_lr = 'transparent';
		if ($var->{'num_segment'} ne $var->{'num_segment_end'} && $var->{'nom'} =~ /(del|dup|ins)/o) {#Large rearrangement
			my $query_nom = "SELECT nom FROM segment WHERE refseq = '$acc' AND type = '$var->{'type_segment_end'}' AND numero = '$var->{'num_segment_end'}';";
			my $res_nom = $dbh->selectrow_hashref($query_nom);
			$nom_seg .= " => $res_nom->{'nom'}";
			$bg_lr = "#DDDDDD" if $var->{'nom'} =~ /del/o;
		}

		#define what will be printed depending on type of variant
		my $intermed = "";
		if ($var->{'nom_ivs'} && $var->{'nom_ivs'} ne '') {$intermed = $var->{'nom_ivs'}}
		elsif  ($var->{'nom_prot'} && $var->{'nom_prot'} ne '') {$intermed = $var->{'nom_prot'}}
		if ($var->{'taille'} > 100) {$intermed .= " - ".$q->strong("(".U2_modules::U2_subs_2::create_lr_name($var, $dbh).")")}


		#prepare for hemizygous
		my $bg_col_hemi = 'transparent';
		#my $color_hemi = '#FF6600'; #old ushvam
		if ($var->{'statut'} eq 'hemizygous') {$bg_col_hemi = '#DDDDDD';}#$color_hemi = '#DDDDDD';$bg_col_hemi = '#DDDDDD';}
		#elsif ($var->{'allele'} eq '2') {$color_hemi = '#990000'}

		#check acc no
		my $var_name = $var->{'nom'};
		if ($main_acc ne $acc) {$var_name = "$acc:$var_name"}

		my ($neutral_class, $rs_class, $common_class, $nopass_class, $utr5_class, $afterstop_class, $deepintron_class, $firstseen_class, $r8_class) = ('neutral_no_hide', 'rs_no_hide', 'common_no_hide', 'nopass_no_hide', 'utr5_no_hide', 'afterstop_no_hide', 'deepintron_no_hide', 'firstseen_no_hide', 'r8_no_hide');
		#, $doc_class , 'doc_no_hide'
		#we tag line if neutral
		if ($var->{'classe'} eq 'neutral') {$neutral_class = 'neutral_hide'}
		if ($var->{'classe'} eq 'R8') {$r8_class = 'r8_hide'}


		#idem for rs and common
		if (($var->{'snp_id'}) && ($var->{'classe'} eq 'neutral' || $var->{'classe'} eq 'unknown')) {
			$rs_class = 'rs_hide';
			#old fashion now common is copied into variant table for optimisation
			#my $common_query = "SELECT common FROM restricted_snp WHERE rsid = '$var->{'snp_id'}';";
			#my $common_res = $dbh->selectrow_hashref($common_query);
			#if ($common_res && $common_res->{'common'} == 1) {$common_class = 'common_hide'}
			if ($var->{snp_common} && $var->{snp_common} == 1) {$common_class = 'common_hide'}
		}

		if (($var->{'classe'} eq 'neutral' || $var->{'classe'} eq 'unknown')) {
			#for pass_hide
			if ($var->{'msr_filter'} &&  $var->{'msr_filter'} ne 'PASS' && $var->{'msr_filter'} ne '' && $type_analyse !~  /SANGER/o) {$nopass_class = 'nopass_hide'}
			#for 5UTR, efter stop codon and intron > 30 bp from exon
			if ($var->{'type_segment'} eq '5UTR' && $var->{'taille'} < 50) {$utr5_class = 'utr5_hide'}
			elsif ($var->{'nom'} =~ /c\.\*.+/o) {$afterstop_class = 'afterstop_hide'}
			elsif ($var->{'type_segment'} eq 'intron' && $var->{'taille'} < 50 && $var->{'nom'} =~ /c\.[\d]+[+-](\d+)_?[\d]*[+-]?(\d*)[a-zA-Z].+/o) {
				if (!$2 && $1 > 30) {$deepintron_class = 'deepintron_hide'}
				elsif ($2 && ($1 > 30 && $2 > 30)) {$deepintron_class = 'deepintron_hide'}
			}

			#filter for variants seen only once: there - modified for 3 times
			my $query_first = "SELECT COUNT(DISTINCT(a.num_pat)) as compte FROM variant2patient a, patient b WHERE a.num_pat = b.numero AND a.id_pat = b.identifiant AND a.refseq = '$acc' AND a.nom_c = '$var->{'nom'}' AND b.proband = 't';";
			my $res_first = $dbh->selectrow_hashref($query_first);

			if ($res_first->{'compte'} > 3) {$firstseen_class = 'firstseen_hide'}
		}

		#et pour doc < 10
		#if (($type_analyse !~ /SANGER/) && ($type_analyse =~ /454/) && ($var->{'depth'} < 10)) {$doc_class = 'doc_hide'}
		#if ($var->{'depth'} && $var->{'depth'} < 10) {$doc_class = 'doc_hide'}
		# 'onmouseover' => 'this.style.backgroundColor=\'#e4edf9\'', 'onmouseout' => 'this.style.backgroundColor=\'\''
		print $q->start_Tr({'class' => "table_line bright $neutral_class $rs_class $common_class $nopass_class $utr5_class $afterstop_class $deepintron_class $firstseen_class $r8_class"}), "\n";
		#For global view
		if ($global eq 't') {print $q->td({'class' => 'italique gras pointer', 'onclick' => "window.open('patient_genotype.pl?sample=".$var->{'id_pat'}.$var->{'num_pat'}."&gene=$gene')", 'title' => "Jump to $gene full genotype"}, $gene), "\n"}

		if ($global ne 't' && ($type_analyse =~ /Mi/o || $type_analyse =~ /Next/o) && $var->{'nom_g'} !~ /chrM:.+/o) {
			my ($chr, $pos1, $pos2) = U2_modules::U2_subs_1::extract_pos_from_genomic($var->{'nom_g'}, 'evs');
			my $igv_padding = 40;
			#my $igv_search = "chr$chr:".($pos1-$igv_padding)."-".($pos2+$igv_padding);
			print $q->start_td(),
				"<input type='button' onclick=\"igv.browser.search('chr$chr:".($pos1-$igv_padding)."-".($pos2+$igv_padding)."')\" title='Click to see in IGV loaded tracks; if no track is loaded, click on a NGS analysis type button in the validation table' value='$nom_seg' class='pointer w3-button w3-ripple w3-blue w3-padding-small w3-tiny'/>",
			$q->end_td(), "\n";
		}
		else {print $q->td($nom_seg), "\n";}

		#We use class and not id because of homozygous variants
		if (!$var->{'depth'}) {$var->{'depth'} = ''}
		foreach my $key (keys(%{$var})) {if (!$var->{$key}) {$var->{$key} = ''}}

		my ($escaped_first_name, $escaped_last_name) = ($var->{'first_name'}, $var->{'last_name'});
		$escaped_first_name =~ s/'/\\'/og;
		$escaped_last_name =~ s/'/\\'/og;
		my $js = "\n
		\$('.a$nb').mouseover(function(){
			setTimeout(function (){
				\$('#details').show();
				setTimeout(function (){
					\$.ajax({
					type: \"POST\",
					url: \"ajax.pl\",
					data: {asked: 'var_info', gene: '$gene', accession: '$acc', nom_c: '$var->{'nom'}', analysis_all: '$type_analyse', depth: '$var->{'depth'}', current_analysis: '$var->{'type_analyse'}', frequency: '$var->{'frequency'}', wt_f: '$var->{'wt_f'}', wt_r: '$var->{'wt_r'}', mt_f: '$var->{'mt_f'}', mt_r: '$var->{'mt_r'}', last_name: '$escaped_last_name', first_name: '$escaped_first_name', msr_filter: '$var->{'msr_filter'}', nb: '$nb'}
					})
					.done(function(msg) {
						\$('#details').html(msg);
						\$('#details').css('z-index', '10');
					});
				}, 200);
			}, 600);
		});
		\$('.a$nb').mouseout(function(){
			\$('#details').hide();
			\$('#details').html('<img src = \"".$HTDOCS_PATH."data/img/loading.gif\"  class = \"loading\"/>loading...');
		});";

		#my $tr_class = 'no_hide';

		##337AB7 blue
		##FF6600 orange
		##D0E3F0 lightblue
		##990000 deep red
		##F45B5B red
		my ($allele1, $allele2) = ('#F45B5B', '#337AB7');

		##tagged line if maf is > 0.01
		#	#print $var->{'allele'};
		if ($var->{'allele'} eq '1') {
			#print $q->start_td({'align' => 'right', 'bgcolor' => $bg_lr, 'onclick' => "window.open('variant.pl?gene=$gene&accession=$acc&nom_c='+encodeURIComponent('$var->{'nom'}')+'&maf='+encodeURIComponent('$maf_url')+'')", 'class' => 'ital'}), $q->font({'color' => $color, 'class' => "a$nb"}, "$var_name - $intermed"), $q->script({'type' => 'text/javascript'}, $js), $q->end_td(), "\n",
			print $q->start_td({'align' => 'right', 'bgcolor' => $bg_lr, 'onclick' => "window.open('variant.pl?gene=$gene&accession=$acc&nom_c='+encodeURIComponent('$var->{'nom'}')+'')", 'class' => 'ital'}), $q->font({'color' => $color, 'class' => "a$nb"}, "$var_name - $intermed"), $q->script({'type' => 'text/javascript'}, $js), $q->end_td(), "\n",
				$q->start_td({'bgcolor' => $allele1, 'align' => 'left'}), $q->start_big(), $q->start_strong(), $q->font({'color' => '#FFFFFF'}, '.'), $q->end_strong(), $q->end_big, $q->end_td(), "\n",
				$q->td({'bgcolor' => $allele2}, '&nbsp;'), "\n",
				$q->td({'bgcolor' => $bg_col_hemi}, '&nbsp;'), "\n",
				$q->td({'bgcolor' => $allele1}, '&nbsp;'), "\n",
				$q->td('&nbsp;'), $q->td({'bgcolor' => $allele2}, '&nbsp;'), "\n";
		}
		elsif ($var->{'allele'} eq '2') {
			print $q->td({'bgcolor' => $bg_col_hemi}, '&nbsp;'), "\n",
				$q->td({'bgcolor' => $allele1}, '&nbsp;'), "\n",
				$q->start_td({'bgcolor' => $allele2, 'align' => 'right'}), $q->start_big(), $q->start_strong(), $q->font({'color' => '#FFFFFF'}, '.'), $q->end_strong(), $q->end_big, $q->end_td(), "\n",
				$q->start_td({'align' => 'left', 'bgcolor' => $bg_lr, 'onclick' => "window.open('variant.pl?gene=$gene&accession=$acc&nom_c='+encodeURIComponent('$var->{'nom'}')+'')", 'class' => 'ital'}), $q->font({'color' => $color, 'class' => "a$nb"}, "$var_name - $intermed"), $q->script({'type' => 'text/javascript'}, $js), $q->end_td(), "\n",
				$q->td({'bgcolor' => $allele1}, '&nbsp;'), "\n",
				$q->td('&nbsp;'), $q->td({'bgcolor' => $allele2}, '&nbsp;'), "\n";
		}
		elsif ($var->{'allele'} eq 'unknown') {
			if ($var->{'statut'} ne 'hemizygous') {$bg_col_hemi = 'transparent'}
			if ($bg_lr eq '#DDDDDD') {$bg_col_hemi = $bg_lr}
			print $q->td('&nbsp;'), $q->td({'bgcolor' => $allele1}, '&nbsp;'), "\n",
			$q->td({'bgcolor' => $allele2}, '&nbsp;'), $q->td('&nbsp;'), "\n",
			$q->start_td({'bgcolor' => $allele1, 'align' => 'right'}), $q->font({'color' => '#FFFFFF'}, '?'), $q->end_td(), "\n",
			$q->start_td({'align' => 'center',  'bgcolor' => $bg_col_hemi, 'onclick' => "window.open('variant.pl?gene=$gene&accession=$acc&nom_c='+encodeURIComponent('$var->{'nom'}')+'')", 'class' => 'ital'}), $q->font({'color' => $color, 'class' => "a$nb"}, "$var_name - $intermed"), $q->script({'type' => 'text/javascript'}, $js), $q->end_td(), "\n",
			$q->start_td({'bgcolor' => $allele2, 'align' => 'left'}), $q->font({'color' => '#FFFFFF'}, '?'), $q->end_td(), "\n";
		}
		elsif ($var->{'allele'} eq 'both') {
			print $q->start_td({'align' => 'right', 'bgcolor' => $bg_lr, 'onclick' => "window.open('variant.pl?gene=$gene&accession=$acc&nom_c='+encodeURIComponent('$var->{'nom'}')+'')", 'class' => 'ital'}), $q->font({'color' => $color, 'class' => "a$nb"}, "$var_name - $intermed"), $q->script({'type' => 'text/javascript'}, $js), $q->end_td(), "\n",
				$q->start_td({'bgcolor' => $allele1, 'align' => 'left'}), $q->start_big(), $q->start_strong(), $q->font({'color' => '#FFFFFF'}, '.'), $q->end_strong(), $q->end_big, $q->end_td(), "\n",
				$q->start_td({'bgcolor' => $allele2, 'align' => 'right'}), $q->start_big(), $q->start_strong(), $q->font({'color' => '#FFFFFF'}, '.'), $q->end_strong(), $q->end_big, $q->end_td(), "\n",
				$q->start_td({'align' => 'left', 'bgcolor' => $bg_lr, 'onclick' => "window.open('variant.pl?gene=$gene&accession=$acc&nom_c='+encodeURIComponent('$var->{'nom'}')+'')", 'class' => 'ital'}), $q->font({'color' => $color, 'class' => "a$nb"}, "$var_name - $intermed"), $q->script({'type' => 'text/javascript'}, $js), $q->end_td(), "\n",
				$q->td({'bgcolor' => $allele1}, '&nbsp;'), $q->td('&nbsp;'), "\n",
				$q->td({'bgcolor' => $allele2}, '&nbsp;'), "\n";
		}
		my $denovo_txt = U2_modules::U2_subs_1::translate_boolean_denovo($var->{'denovo'});
		print $q->start_td().$q->span(lc($type_analyse)).$q->strong($denovo_txt).$q->end_td();
		if ($var->{'snp_id'}) {print $q->start_td(), $q->a({'href' => "http://www.ncbi.nlm.nih.gov/SNP/snp_ref.cgi?rs=$var->{'snp_id'}", 'target' => '_blank'}, $var->{'snp_id'}), $q->end_td()}
		else {print $q->td()}

		print $q->end_Tr();


		return $var->{'nom'};
	}
}


sub create_lr_name {
	my ($var, $dbh) = @_;
	#get names
	my $query = "SELECT nom FROM segment WHERE numero = '".($var->{'num_segment_end'})."' AND refseq  ='$var->{'refseq'}';";
	my $nom_seg_end = $dbh->selectrow_hashref($query);
	if ($var->{'type_segment'} eq 'intron') {
		$query = "SELECT nom FROM segment WHERE numero = '".($var->{'num_segment'}+1)."' AND refseq ='$var->{'refseq'}';";
		my $nom_seg = $dbh->selectrow_hashref($query);
		return "E".($nom_seg->{'nom'})."-$nom_seg_end->{'nom'}".substr($var->{'type_adn'}, 0, 3);
	}
	elsif ($var->{'type_segment'} eq '5UTR') {
		$query = "SELECT nom FROM segment WHERE numero = '1' AND refseq  ='$var->{'refseq'}';";
		my $nom_seg = $dbh->selectrow_hashref($query);
		return "E$nom_seg->{'nom'}-$nom_seg_end->{'nom'}".substr($var->{'type_adn'}, 0, 3);
	}
	else {
		$query = "SELECT nom FROM segment WHERE numero = '".($var->{'num_segment'})."' AND refseq  ='$var->{'refseq'}';";
		my $nom_seg = $dbh->selectrow_hashref($query);
		return "E$nom_seg->{'nom'}-$nom_seg_end->{'nom'}".substr($var->{'type_adn'}, 0, 3);
	}
}

#for home.pl, automated_class.pl

sub info_text {
	my ($q, $type) = @_;
	if ($type eq 'class') {
		return $q->start_li().$q->span('If you have validation permissions, unknown variants will be classified as \\\'').$q->span({'style' => 'color:green'}, 'neutral').$q->span('\\\' if:').
						$q->start_ul().$q->li('It is neither a frameshift nor a nonsense nor a splicing mutation OR it is undefined protein type').
								$q->li('It is present in the dbSNP common set (MAF > 0.01 in dbSNP) AND').
								$q->li('It has a MAF_SANGER OR a MAF_454 OR a MAF_MISEQ in our cohort all > 0.01 AND').
								$q->li('none of them is < 0.01 OR').
								$q->li('Both MAF_SANGER AND MAF_454 are unknown (particular cases 454-USH2A) AND MAF_454_USH2A > 0.16').
						$q->end_ul().
					$q->end_li().
					$q->start_li().$q->span('Unknown variants will be classified as \\\'').$q->span({'style' => 'color:red'}, 'pathogenic').$q->span('\\\' if it is a frameshift or a nonsense or a +1,+2,-1,-2 identified by SANGER').$q->end_li().
					$q->start_li().$q->span('Unknown variants will be classified as \\\'').$q->span({'style' => 'color:#9D0003'}, 'R8').$q->span('\\\' if it is located in an homopolymeric region of at least 8 identical nuleotides').$q->end_li().
					$q->start_li().$q->span('Unknown variants will be classified as \\\'').$q->span({'style' => 'color:#00663D'}, 'VUCS Class F').$q->span('\\\' if it is present in at least 7 probands and with an AF in ExAC > 0.005').$q->end_li().
					$q->start_li().$q->span('Unknown variants will be classified as \\\'').$q->span({'style' => 'color:#30EDD4'}, 'VUCS Class U').$q->span('\\\' if it is present in at least 7 probands and with an AF in ExAC < 0.005').$q->end_li();
	}
	elsif ($type eq 'neg') {
		return $q->p('If you have validation permissions, this script will automatically check genotypes and define experiences as negative or not using the following criteria:').
						$q->start_ul().$q->li('the technical validation value MUST be set to "Yes" (i.e. experience is finished) AND').
								$q->li('2 VUCS Class III, IV or pathogenic variants are reported for this gene, then result is set to "+" (which means positive) OR').
								$q->li('2 VUCS Class III, IV or pathogenic are reported for the patient in another gene AND the patient only carries neutral OR VUCS Class I in a given gene, then result is set to "-".').
						$q->end_ul();
	}
	else {return 'bad'}
}


#send email in import_illumina.pl

sub send_manual_mail {
	my ($user, $text, $text2, $run, $general, $mutalyzer_no_answer, $to_follow) = @_;
	#print "($user, $text, $text2, $run, $general, $mutalyzer_no_answer, $to_follow, $new_var)";
	my $config_file = U2_modules::U2_init_1->getConfFile();
	my $config = U2_modules::U2_init_1->initConfig();
	$config->file($config_file);# or die $!;
	my $ADMIN_EMAIL = $config->ADMIN_EMAIL();
	my $ADMIN_EMAIL_DEST = $config->ADMIN_EMAIL_DEST();
	my $EMAIL_SMTP = $config->EMAIL_SMTP();
	my $EMAIL_PORT = $config->EMAIL_PORT();
	my $EMAIL_PASSWORD = $config->EMAIL_PASSWORD();
	my $mailer = Net::SMTP->new (
		$EMAIL_SMTP,
		Hello   =>      $EMAIL_SMTP,
		Port    =>      $EMAIL_PORT);#, Debug => 1) or print STDERR  "Init Pb with gmail $ADMIN_EMAIL $EMAIL_PASSWORD";
		#User    =>      $ADMIN_EMAIL,
		#Password=>      $EMAIL_PASSWORD);
	$mailer->starttls();
	$mailer->auth(
		Authen::SASL->new(
			mechanism => 'PLAIN LOGIN',
			callback  => { user => $ADMIN_EMAIL, pass => $EMAIL_PASSWORD }
		)
	);
	# $mailer->auth($ADMIN_EMAIL, $EMAIL_PASSWORD);# or print STDERR  "Auth Pb with gmail $ADMIN_EMAIL $EMAIL_PASSWORD";
	$mailer->mail($ADMIN_EMAIL);
	$mailer->to($ADMIN_EMAIL_DEST);
	if ($user->getEmail() ne $ADMIN_EMAIL_DEST) {$mailer->to($user->getEmail())}
	$mailer->data();
	#my $subject = "Subject:Variants to deal manually for Illumina run $run\n\n";
	$mailer->datasend("Subject: [USHVaM 2]: Variants to deal manually for Illumina run $run\n\n");
	$mailer->datasend("Hi ".$user->getName().",\n\nYou have requested the import of an Illumina run. Please note the information below:\n\n$general");
	if ($text ne '') {
		$mailer->datasend("For various reasons the following variants could not be directly inserted into U2.\nYou can copy/paste them into the corresponding patients comment form, or your admin will do it by himself, and try to manually insert them.\n\n");
		$mailer->datasend($text);
	}
	if ($mutalyzer_no_answer ne '') {
		$mailer->datasend("\n\nIn addition, for unknown reasons mutalyzer gave no answer for the following variants:\n\n");
		$mailer->datasend($text2);
	}
	if ($to_follow ne '') {
		$mailer->datasend("\n\nThe following variants must be checked:\n\n");
		$mailer->datasend($to_follow);
	}
	if ($text2 ne '') {
		$mailer->datasend("\n\nThe following variants have not been considered:\n\n");
		$mailer->datasend($text2);
	}
	#if ($new_var ne '') {
	#	$mailer->datasend("\n\nThe following variants have been created:\n\n");
	#	$mailer->datasend($new_var);
	#}
	$mailer->datasend("\n\nBest regards.\n\nThe most advanced variant database system, USHVaM2\n\n");
	$mailer->dataend() or print STDERR " End Pb with gmail before sending: ".$mailer->message();
	$mailer->quit();
}

sub send_general_mail {
	my ($user, $subject, $text) = @_;
	#print "($user, $text, $text2, $run, $general, $mutalyzer_no_answer, $to_follow, $new_var)";
	my $config_file = U2_modules::U2_init_1->getConfFile();
	my $config = U2_modules::U2_init_1->initConfig();
	$config->file($config_file);# or die $!;
	my $ADMIN_EMAIL = $config->ADMIN_EMAIL();
	my $ADMIN_EMAIL_DEST = $config->ADMIN_EMAIL_DEST();
	my $EMAIL_SMTP = $config->EMAIL_SMTP();
	my $EMAIL_PORT = $config->EMAIL_PORT();
	my $EMAIL_PASSWORD = $config->EMAIL_PASSWORD();
	my $mailer = Net::SMTP->new (
		$EMAIL_SMTP,
		Hello   =>      $EMAIL_SMTP,
		Port    =>      $EMAIL_PORT);
	$mailer->starttls();
	#$mailer->auth($ADMIN_EMAIL, $EMAIL_PASSWORD);# or print STDERR  "Auth Pb with gmail $ADMIN_EMAIL $EMAIL_PASSWORD";
	$mailer->auth(
		Authen::SASL->new(
			mechanism => 'PLAIN LOGIN',
			callback  => { user => $ADMIN_EMAIL, pass => $EMAIL_PASSWORD }
		)
	);
	$mailer->mail($ADMIN_EMAIL);
	$mailer->to($user->getEmail());
	$mailer->data();
	$mailer->datasend("Subject: [USHVaM 2]: $subject\n\n");
	$mailer->datasend($text);

	$mailer->datasend("\n\nBest regards.\n\nThe most advanced variant database system, USHVaM2\n\n");
	$mailer->dataend() or print STDERR " End Pb with gmail before sending: ".$mailer->message();
	$mailer->quit();
}

sub request_variant_classification {
	my ($user, $var, $gene) = @_;
	my $config_file = U2_modules::U2_init_1->getConfFile();
	my $config = U2_modules::U2_init_1->initConfig();
	$config->file($config_file);# or die $!;
	my $ADMIN_EMAIL = $config->ADMIN_EMAIL();
	my $ADMIN_EMAIL_DEST = $config->ADMIN_EMAIL_DEST();
	my $EMAIL_SMTP = $config->EMAIL_SMTP();
	my $EMAIL_PORT = $config->EMAIL_PORT();
	my $EMAIL_PASSWORD = $config->EMAIL_PASSWORD();
	my $EMAIL_CLASS = $config->EMAIL_CLASS();
	#print $EMAIL_CLASS;
	#my @dest = split(/\s/, $EMAIL_CLASS);
	#print `perl -MNet::SMTP -e 'print "$Net::SMTP::VERSION\n"'`;
	my $mailer = Net::SMTP->new (
		$EMAIL_SMTP,
		Hello   =>      $EMAIL_SMTP,
		Port    =>      $EMAIL_PORT); #,
		# Debug	=>	1);#,
		# User    =>      $ADMIN_EMAIL,
		# Password=>      $EMAIL_PASSWORD);
	$mailer->starttls();
	$mailer->auth(
		Authen::SASL->new(
			mechanism => 'PLAIN LOGIN',
			callback  => { user => $ADMIN_EMAIL, pass => $EMAIL_PASSWORD }
		)
	);
	$mailer->mail($ADMIN_EMAIL);
	# $mailer->to($ADMIN_EMAIL_DEST);
	# foreach (@dest) {$mailer->to($_)}
	# $mailer->to('david.baux@inserm.fr');
	foreach my $key (%{$EMAIL_CLASS}) {$mailer->to($key)}
	# foreach my $adress (@$EMAIL_CLASS) {$mailer->to($adress)}
	if ($user->getEmail() ne $ADMIN_EMAIL_DEST) {$mailer->to($user->getEmail())}
	$mailer->data();

	$mailer->datasend("Subject: [USHVaM 2]: Request Variant Classification\n\n");
	$mailer->datasend("\n\nHello,\n".$user->getName()." has requested the classification of variant $var in gene $gene.\nPlease proceed as soon as possible.");
	$mailer->datasend("\n\nBest regards.\n\nThe most advanced variant database system, USHVaM2\n\n");
	$mailer->dataend();
	$mailer->quit();
}

#for add_analysis.pl, gene.pl => gene canvas with associated map

sub gene_canvas {
	my ($gene, $order, $dbh, $js_params) = @_;
	#create an exon radio table
	#or no a canvas!!!! HTML5
	#ok this is relou as canvas don't accept links, so I put a transparent picture above with a map
	if ($js_params->[1] eq "NULL") {$js_params->[1] = $order}

	my $query = "SELECT b.refseq, b.acc_g, a.numero as numero, a.nom as nom, a.type as type FROM segment a, gene b WHERE a.refseq = b.refseq AND b.gene_symbol = '$gene' AND b.main = 't' AND a.nom NOT LIKE '%bis' order by a.$postgre_start_g $order;";
	my $sth = $dbh->prepare($query);
	my $res = $sth->execute();
	my $js = "	var canvas = document.getElementById(\"exon_selection\");
			var context = canvas.getContext(\"2d\");
			//context.drawImage(document.getElementById('transparent_image'), 0, 0);
			context.fillStyle = \"#000000\";
			context.font = \"bold 14px sans-serif\";
			context.strokeStyle = \"#6C2945\";
		";#FF0000
	my $map = "\n<map name='segment'>\n";
	my ($main, $ng);
	my ($acc, $i, $x_txt_intron, $y_txt_intron, $x_line_intron, $x_intron_exon, $y_line_intron, $y_up_exon, $x_txt_exon, $y_txt_exon) = ('', 0, 125, 19.5, 100, 150, 25, 12.5, 170, 30);
	while (my $result = $sth->fetchrow_hashref()) {
		($main, $ng) = ($result->{'refseq'}, $result->{'acc_g'});
		if ($i == 20 || ($result->{'type'} eq 'intergenic' && $i == 10)) {$i = 0;$y_txt_intron += 50;$y_line_intron += 50;$y_txt_exon += 50;$y_up_exon += 50;$x_txt_intron = 125;$x_line_intron = 100;$x_intron_exon = 150;$x_txt_exon = 170;}
		if ($acc ne $result->{'refseq'}) {#new -> print acc
			$js.= "context.fillText(\"$result->{'refseq'}\", 0, $y_line_intron);";
			$acc = $result->{'refseq'};
		}
		if ($result->{'type'} ne 'exon') { #for intron, 5UTR, 3UTR=> print name of segment and a line + a map (left, top, right, bottom)
			#my $html_id = 'intron';
			if ($result->{'type'} ne 'intron') {$js .= "context.fillText(\"$result->{'nom'}\", ".($x_txt_intron-15).", $y_txt_intron);";}#$html_id =''}
			else {$js .= "\t\t\t\t\tcontext.fillText(\"$result->{'nom'}\", $x_txt_intron, $y_txt_intron);"}
			$js .= "context.moveTo($x_line_intron,$y_line_intron);
				context.lineTo($x_intron_exon,$y_line_intron);
				context.stroke();\n";
			#$map .= "<area shape = 'rect' coords = '".($x_line_intron-100).",".($y_line_intron-25).",".($x_line_intron-50).",".($y_line_intron+25)."' onclick = 'createForm(\"$result->{'type'}\", \"$result->{'nom'}\", \"$result->{'numero'}\", \"$gene\", \"$acc\", \"$id$number\", \"$analysis\");' href = 'javascript:;'/>\n";
			$map .= "<area shape = 'rect' coords = '".($x_line_intron-100).",".($y_line_intron-25).",".($x_line_intron-50).",".($y_line_intron+25)."' onclick = '$js_params->[0](\"$result->{'type'}\", \"$result->{'nom'}\", \"$result->{'numero'}\", \"$gene\", \"$acc\", \"$js_params->[1]\", \"$js_params->[2]\");' href = 'javascript:;'/>\n";
			$i++;
			$x_line_intron += 100;
			$x_txt_intron += 100;

		}
		elsif ($result->{'type'} eq 'exon') { #for exons print name of segment and a box + a map (left, top, right, bottom)
			$js .= "\t\t\t\t\tcontext.fillStyle = \"#D6A8CF\";
				context.fillRect($x_intron_exon,$y_up_exon,50,25);
				context.strokeRect($x_intron_exon,$y_up_exon,50,25);
				context.fillStyle = \"#000000\";
				context.fillText(\"$result->{'nom'}\", $x_txt_exon, $y_txt_exon);\n";
			$map .= "<area shape = 'rect' coords = '".($x_intron_exon-100).",".($y_line_intron-25).",".($x_intron_exon-50).",".($y_line_intron+25)."' onclick = '$js_params->[0](\"$result->{'type'}\", \"$result->{'nom'}\", \"$result->{'numero'}\", \"$gene\", \"$acc\", \"$js_params->[1]\", \"$js_params->[2]\");' href = 'javascript:;'/>\n";
			$i++;
			$x_intron_exon += 100;
			$x_txt_exon += 100;
		}
	}


	#secondary acc# 05/12/2016 put  ORDER BY b.nom, a.numero, a.type clause to query - was absent but od not know if it has ever been present...
	$query = "SELECT b.refseq, a.numero as numero, a.nom as nom, a.type as type FROM segment a, gene b WHERE a.refseq = b.refseq AND b.gene_symbol = '$gene' AND b.main = 'f' AND (a.$postgre_start_g NOT IN (SELECT a.$postgre_start_g FROM segment a, gene b WHERE a.refseq = b.refseq AND b.main = 't' AND b.gene_symbol = '$gene') OR a.$postgre_end_g NOT IN (SELECT a.$postgre_end_g FROM segment a, gene b WHERE a.refseq = b.refseq AND b.main = 't' AND b.gene_symbol = '$gene')) ORDER BY b.refseq, a.numero, a.type;";
	$sth = $dbh->prepare($query);
	$res = $sth->execute();
	#print $query;
	#reinitialize - change line - we need to check if exons follow
	($acc, $i, $x_txt_intron, $y_txt_intron, $x_line_intron, $x_intron_exon, $y_line_intron, $y_up_exon, $x_txt_exon, $y_txt_exon) = ('', 0, 125, $y_txt_intron, 100, 150, $y_line_intron, $y_up_exon, 170, $y_txt_exon);
	my ($num, $type);
	if ($res ne '0E0') {
		while (my $result = $sth->fetchrow_hashref()) {
			if (($result->{'type'} eq 'intron' && $result->{'numero'} > $num)) {###JUMP-non contiguous segment
				$x_intron_exon += 100;
				$x_txt_exon += 100;
				if ($type eq 'exon') {$x_txt_intron += 100;$x_line_intron += 100}
			}
			elsif ($result->{'type'} eq 'exon' && $type eq 'exon') {$x_txt_intron += 100;$x_line_intron += 100} #2 exons
			$num = $result->{'numero'};
			$type = $result->{'type'};
			if ($i == 20) {$i = 0;$y_txt_intron += 50;$y_line_intron += 50;$y_txt_exon += 50;$y_up_exon += 50;$x_txt_intron = 125;$x_line_intron = 100;$x_intron_exon = 150;$x_txt_exon = 170;}
			if ($acc ne $result->{'refseq'}) {#new -> print acc
				$i = 0;$y_txt_intron += 50;$y_line_intron += 50;$y_txt_exon += 50;$y_up_exon += 50;$x_txt_intron = 125;$x_line_intron = 100;$x_intron_exon = 150;$x_txt_exon = 170;
				$js.= "context.fillText(\"$result->{'refseq'}\", 0, $y_line_intron);";
				$acc = $result->{'refseq'};
			}
			if ($result->{'type'} ne 'exon') { #for intron, 5UTR, 3UTR=> print name of segment and a line + a map (left, top, right, bottom)
				if ($result->{'type'} ne 'intron') {$js .= "context.fillText(\"$result->{'nom'}\", ".($x_txt_intron-15).", $y_txt_intron);"}
				else {$js .= "\t\t\t\t\tcontext.fillText(\"$result->{'nom'}\", $x_txt_intron, $y_txt_intron);"}
				$js .= "context.moveTo($x_line_intron,$y_line_intron);
					context.lineTo($x_intron_exon,$y_line_intron);
					context.stroke();\n";
				$map .= "<area shape = 'rect' coords = '".($x_line_intron-100).",".($y_line_intron-25).",".($x_line_intron-50).",".($y_line_intron+25)."' onclick = '$js_params->[0](\"$result->{'type'}\", \"$result->{'nom'}\", \"$result->{'numero'}\", \"$gene\", \"$acc\", \"$js_params->[1]\", \"$js_params->[2]\");' href = 'javascript:;'/>\n";
				$i++;
				$x_line_intron += 100;
				$x_txt_intron += 100;
			}
			elsif ($result->{'type'} eq 'exon') { #for exons print name of segment and a box + a map (left, top, right, bottom) CBEDB9
				$js .= "\t\t\t\t\tcontext.fillStyle = \"#D6A8CF\";
					context.fillRect($x_intron_exon,$y_up_exon,50,25);
					context.strokeRect($x_intron_exon,$y_up_exon,50,25);
					context.fillStyle = \"#000000\";
					context.fillText(\"$result->{'nom'}\", $x_txt_exon, $y_txt_exon);\n";
				$map .= "<area shape = 'rect' coords = '".($x_intron_exon-100).",".($y_line_intron-25).",".($x_intron_exon-50).",".($y_line_intron+25)."' onclick = '$js_params->[0](\"$result->{'type'}\", \"$result->{'nom'}\", \"$result->{'numero'}\", \"$gene\", \"$acc\", \"$js_params->[1]\", \"$js_params->[2]\");' href = 'javascript:;'/>\n";
				$i++;
				###modified 21/10/2014 try to fix a bug when isoform begins with exon
				if ($i == 1) {$x_txt_intron += 100;$x_line_intron += 100}
				###end modified
				$x_intron_exon += 100;
				$x_txt_exon += 100;
			}
		}
	}

	$map .= "</map>\n";
	return ($js, $map, $main, $ng);
}

sub segment_canvas {
	my ($var, $seg1, $seg2, $seg3, $pos, $case, $seg_size, $label1, $label2, $score3, $score5) = @_;
	my $js = "	var canvas = document.getElementById(\"segment_drawing\");
			var context = canvas.getContext(\"2d\");
			context.fillStyle = \"#000000\";
			context.font = \"bold 14px sans-serif\";
			context.strokeStyle = \"#6C2945\";
		";
	#case a: exon or intronic flanking (<100 bp from exon)
	my ($L, $h) = (600, 150); #width, height of canvas
	if ($case eq 'a') {
		my $points = {
			'a' => [$L/6, $h/6], #Intron name x, y
			'b' => [$L/6, $h/2], #Intron start x, y
			'c' => [$L/3, $h/3], #square start x, y
			'd' => [($L/2)-25, $h/2], #Exon name x, y
			'e' => [$pos, ($h/6)-5], #Var name x, y
			'f' => [2*$L/3, $h/2], #Intron 2 start x, y
			'g' => [(5*$L/6), $h/6], #Intron 2 name x, y
			'h' => [($L/3)-25, 5*$h/6], #3' name x, y
			'i' => [2*$L/3, 5*$h/6], #5' name x, y
		};
		if ($pos < 200 || $pos > 400){#intronic variant
			$points->{'e'}[1] = ($h/3)-5;
			if ($var =~ /[^\.]-/o) {$score5->[0] = ''}
			else {$score3->[0] = ''}
		}
		if ($label1 ne 'Intron' && $label2 ne 'Intron') {($seg1, $seg3) = ('', '')}
		elsif ($label1 ne 'Intron') {$seg1 = ''}
		elsif ($label2 ne 'Intron') {$seg3 = ''}



		#texts and drawings
		$js .= "	context.fillText(\"$label1 $seg1\", $points->{'a'}[0], $points->{'a'}[1]);
				context.fillText(\"$var\", $points->{'e'}[0], $points->{'e'}[1]);
				context.fillText(\"$label2 $seg3\", $points->{'g'}[0], $points->{'g'}[1]);
				context.fillText(\"3'ss $score3->[0]\", $points->{'h'}[0], $points->{'h'}[1]);
				context.fillText(\"5'ss $score5->[0]\", $points->{'i'}[0], $points->{'i'}[1]);
				context.moveTo($points->{'b'}[0],$points->{'b'}[1]);
				context.lineTo(".($points->{'b'}[0]+100).",$points->{'b'}[1]);
				context.stroke();
				context.moveTo($points->{'e'}[0],$points->{'e'}[1]);
				context.lineTo($points->{'e'}[0],$points->{'e'}[1]+30);
				context.stroke();
				context.fillStyle = \"#D6A8CF\"
				context.fillRect($points->{'c'}[0],$points->{'c'}[1],200,50);
				context.strokeRect($points->{'c'}[0],$points->{'c'}[1],200,50);
				context.fillStyle = \"#000000\";
				context.fillText(\"Exon $seg2 ($seg_size bp)\", $points->{'d'}[0], $points->{'d'}[1]);
				context.moveTo($points->{'f'}[0],$points->{'f'}[1]);
				context.lineTo(".($points->{'f'}[0]+100).",$points->{'f'}[1]);
				context.stroke();
		";
	}
	elsif ($case eq 'b') {
		my $points = {
			'a' => [$L/6, $h/3], #Exon start x, y
			'b' => [($L/4)-25, $h/2], #Exon name x, y
			'c' => [$L/3, $h/2], #Intron start x, y
			'd' => [($L/2)-50, $h/6], #Intron name x, y
			'e' => [$pos, $h/3], #var name x, y
			'f' => [2*$L/3, $h/3], #Exon 2 start x, y
			'g' => [(5*$L/6)-75, $h/2], #Exon 2 name x, y
			'h' => [$L/3, 5*$h/6], #3' name x, y
			'i' => [(2*$L/3)-25, 5*$h/6], #5' name x, y
		};

		#texts and drawings
		$js .= "	context.fillText(\"$var\", $points->{'e'}[0], $points->{'e'}[1]);
				context.fillText(\"3'ss $score3->[0]\", $points->{'h'}[0], $points->{'h'}[1]);
				context.fillText(\"5'ss $score5->[0]\", $points->{'i'}[0], $points->{'i'}[1]);
				context.fillStyle = \"#D6A8CF\"
				context.fillRect($points->{'a'}[0],$points->{'a'}[1],100,50);
				context.strokeRect($points->{'a'}[0],$points->{'a'}[1],100,50);
				context.fillStyle = \"#000000\";
				context.moveTo($points->{'c'}[0],$points->{'c'}[1]);
				context.lineTo(".($points->{'c'}[0]+200).",$points->{'c'}[1]);
				context.stroke();
				context.fillStyle = \"#D6A8CF\"
				context.fillRect($points->{'f'}[0],$points->{'f'}[1],100,50);
				context.strokeRect($points->{'f'}[0],$points->{'f'}[1],100,50);
				context.fillStyle = \"#000000\";
				context.fillText(\"Exon $seg1\", $points->{'b'}[0], $points->{'b'}[1]);
				context.fillText(\"Exon $seg3\", $points->{'g'}[0], $points->{'g'}[1]);
				context.fillText(\"Intron $seg2 ($seg_size bp)\", $points->{'d'}[0], $points->{'d'}[1]);
				context.moveTo($points->{'e'}[0],$points->{'e'}[1]);
				context.lineTo($points->{'e'}[0],$points->{'e'}[1]+25);
				context.stroke();
		";
	}

	return $js;
}

sub get_js_graph {
	my ($labels, $data, $color, $id) = @_;
	return "\n// Get context with jQuery - using jQuery's .get() method.
		//Chart.defaults.global.responsive = true; //wether or not the chart should be responsive and resize when the browser does.
		var ctx = \$(\"#$id\").get(0).getContext(\"2d\");\n
		// This will get the first returned node in the jQuery collection.
		//var myNewChart = new Chart(ctx);
		var data = {
			labels: [$labels],
			datasets: [
				{
					//label: \"On target reads\",
					fillColor: \"rgba($color,0.5)\",
					strokeColor: \"rgba($color,0.8)\",
					highlightFill: \"rgba($color,0.75)\",
					highlightStroke: \"rgba($color,1)\",
					data: [$data]
				}
			]
		};\n
		var chart_$id = new Chart(ctx).Bar(data, {
			scaleBeginAtZero: false,
			animation: false
		});\n";
}
#originilly designed for stats_general_1.pl but lacks functionnalities, replaced with another js library (form Chart.js to highcharts.js)
sub get_chart_pie {
	my ($data, $id) = @_;
	return "\n// Get context with jQuery - using jQuery's .get() method.
		//Chart.defaults.global.responsive = true; //wether or not the chart should be responsive and resize when the browser does.
		var ctx = \$(\"#$id\").get(0).getContext(\"2d\");\n
		// This will get the first returned node in the jQuery collection.
		//var myNewChart = new Chart(ctx);
		var data = $data\n
		var chart_$id = new Chart(ctx).Pie(data);\n";
}



#in stats_general.pl, gene_graphs.pl (highcharts.js graphs)
sub graph_pie {
	my ($p_collpase_id, $a_text, $p_body_id, $query, $query2, $text, $date, $short, $base_url, $type, $bool, $collapse, $label, $q, $dbh) = @_;
	my $html;
	print		$q->start_div({'class' => 'panel panel-default'}), "\n",
			$q->start_div({'class' => 'panel-heading'}), "\n",
				$q->start_h4({'class' => 'panel-title'}), "\n",
					$q->a({'data-toggle' => 'collapse', 'data-parent' => '#graphs_pv', 'href' => "#$p_collpase_id"}, $a_text), "\n",
				$q->end_h4(), "\n",
			$q->end_div(), "\n",
			$q->start_div({'id' => $p_collpase_id, 'class' => "panel-collapse collapse$collapse"}), "\n",
				$q->start_div({'class' => 'panel-body', 'id' => $p_body_id, 'style' => 'height:600px;width:1000px;'}), "\n";
	my ($data, $total);
	#RNA-variant type case
	if ($query eq '') {($data, $total) = ($label, $query2)}	#in this case data are passed via $label and total via $query2
	elsif ($query2 eq '') {($data, $total) = &get_data_pathos($query, $dbh)}#patients relates data/variants with no frequency
	else {($data, $total) = &get_data_variants($query, $query2, $label, $dbh)}#variants with frequency
	$text =~ s/X/$total/g;
	my $js = &get_highcharts_pie($data, $p_body_id, $text, $date, $short, $base_url, $type, $bool);

	print				$q->end_div(), "\n",
					$q->script({'type' => 'text/javascript'}, $js),
				$q->end_div(), "\n",
			$q->end_div(), "\n";
}

#in stats_general.pl, gene_graphs.pl (highcharts.js graphs)
sub get_highcharts_pie {
	my ($data, $id, $title, $date, $short, $base_url, $type, $animation) = @_;
	my ($add, $add2) = ('', '');
	if ($base_url ne '') {
		$add = '
						point: {
							events: {
								click: function() {
									window.open(\''.$base_url.'\' + this.name);
								}
							}
						}
		';
		$add2 = '<br/>Click to open a detailed list of '.$type;
	}

	return '
		$(function () {
			$(\'#'.$id.'\').highcharts({
				chart: {
					plotBackgroundColor: null,
					plotBorderWidth: null,
					plotShadow: false,
				},
				title: {
					text: \''.$title.'<br/>'.$date.'\'
				},
				tooltip: {
					pointFormat: \'{series.name}: <b>{point.y}</b>.'.$add2.'\'
				},
				plotOptions: {
					pie: {
						allowPointSelect: true,
						animation: '.$animation.',
						cursor: \'pointer\',
						dataLabels: {
							enabled: true,
							format: \'<b>{point.name}</b>: {point.percentage:.1f} %\',
							style: {
								color: (Highcharts.theme && Highcharts.theme.contrastTextColor) || \'black\'
							}
						},
						'.$add.'
					}
				},
				series: [{
					type: \'pie\',
					name: \''.$short.'\',
					data: [
						'.$data.'
					],
				}]
			});
		});
	';
}



#in stats_general.pl, gene_graphs.pl (highcharts.js graphs)
sub get_data_pathos {
	my ($query, $dbh) = @_;
	my $sth = $dbh->prepare($query);
	my $res = $sth->execute();

	my ($data, $total);
	while (my $result = $sth->fetchrow_hashref()) {
		$data .= "\t\t\t\t\t['$result->{'label'}', $result->{'num'}],\n";
		$total += $result->{'num'};
	}
	return ($data, $total);
}
#in stats_general.pl, gene_graphs.pl (highcharts.js graphs)
sub get_data_variants {
	my ($query1, $query2, $label, $dbh) = @_;
	my $sth = $dbh->prepare($query1);
	my $res = $sth->execute();
	my ($data, $total) = ('', 0);
	while (my $result = $sth->fetchrow_hashref()) {
		if ($result->{'label'} eq '' && $label eq 'RNA-altered') {$result->{'label'} = 'RNA-altered?'}
		$data .= "\t\t\t\t\t['$result->{'label'}', $result->{'num'}],\n";$total += $result->{'num'};
	}
	$res = $dbh->selectrow_hashref($query2);
	$data .= "\t\t\t\t\t['$label', $res->{'others'}],\n";
	$total += $res->{'others'};
	#for gene specific graphs=>type of alterations, need to discriminate LR from others
	if ($label eq 'RNA-altered') {
		$query2 =~ s/< 100/> 100/o;
		$res = $dbh->selectrow_hashref($query2);
		$data .= "\t\t\t\t\t['large rearrangements', $res->{'others'}],\n";
		$total += $res->{'others'};
	}

	return ($data, $total);
}
#in stats_general.pl, gene_graphs.pl (highcharts.js graphs)
sub RNA_pie {
	my ($query, $date, $q, $dbh) = @_;
	my $sth = $dbh->prepare($query);
	my $res = $sth->execute();
	my ($raw_data, $gene);
	if ($res ne '0E0') {
		while (my $result = $sth->fetchrow_hashref()) {
			if ($gene eq '' && $query =~ /nom_gene\[1\]\s=/o) {$gene = $result->{'nom_gene'}[0]}
			$raw_data->{U2_modules::U2_subs_1::get_interpreted_position($result, $dbh)}++;

		}
		my ($data, $i);
		foreach my $label (sort keys %{$raw_data}) {$data .= "\t\t\t\t\t['$label', $raw_data->{$label}],\n";$i += $raw_data->{$label}}
		my $base_url = $HOME_IP.'/perl/U2/engine.pl?search=RNA&dynamic=';
		if ($query =~ /gene_symbol\s=/o) {$base_url = "$HOME_IP./perl/U2/gene.pl?gene=$gene&info=all_vars&sort=type_arn&dynamic="}#called from gene sepcific page}

		U2_modules::U2_subs_2::graph_pie('rna-variant-type', 'Variants causing RNA alterations', 'variant_rna_pie_chart', '', $i, "Alteration types causing RNA variations among pathogenic variants<br/>(Total: X variants)", $date, "variant types", $base_url, 'variant', 'false', '', $data, $q, $dbh);
	}
}

#sub to display info panel

sub info_panel {
	my ($text, $q) = @_;
	return $q->start_div({'class' => 'w3-margin w3-panel w3-sand w3-leftbar w3-display-container'}).$q->span({'onclick' => 'this.parentElement.style.display=\'none\'', 'class' => 'w3-button w3-ripple w3-display-topright w3-large'}, 'X').$q->p($text).$q->end_div()."\n";
}

sub mini_info_panel {
	my ($text, $q) = @_;
	return $q->start_div({'class' => 'w3-margin w3-panel w3-sand w3-leftbar'}).$q->p($text).$q->end_div()."\n";
}

sub danger_panel {
	my ($text, $q) = @_;
	return $q->start_div({'class' => 'w3-margin w3-panel w3-pale-red w3-leftbar w3-display-container'}).$q->span({'onclick' => 'this.parentElement.style.display=\'none\'', 'class' => 'w3-button w3-ripple w3-display-topright w3-large'}, 'X').$q->start_p().$q->strong($text).$q->end_p().$q->end_div()."\n";
}

sub cnil_disclaimer {
	my $q = shift;
	return info_panel('Les données collectées dans la zone de texte libre doivent être pertinentes, adéquates et non excessives au regard de la finalité du traitement.'.$q->br().'Elles ne doivent pas comporter d\'appréciations subjectives, ni directement ou indirectement, permettre l\'identification d\'un patient, ni faire apparaitre des données dites "sensibles" au sens de l\'article 8 de la loi n°78-17 du 6 janvier 1978 relative à l\'informatique, aux fichiers et aux libertés.', $q);
}

# in add_analysis.pl, add_clinical_exome.pl

sub check_ngs_samples {
	my ($patients, $analysis, $dbh) = @_;
	# select patients/analysis not already recorded for this type of run (e.g. MiSeq-28), $query AND who is already basically recorded in U2, $query2
	my $query = "SELECT num_pat, id_pat FROM analyse_moleculaire WHERE type_analyse = '$analysis' AND ("; # num_pat = '$number' AND id_pat = '$id' GROUP BY num_pat, id_pat;";
	my $query2 = "SELECT numero, identifiant FROM patient WHERE ";
	my $count_hash = 0;
	foreach my $totest (keys(%{$patients})) {
		$totest =~ /^$PATIENT_IDS\s*(\d+)$/o;
		$query .= "(num_pat = '$2' AND id_pat = '$1') ";
		$query2 .= "(numero = '$2' AND identifiant = '$1') ";
		$count_hash++;
		if ($count_hash < keys(%{$patients})) {$query .= "OR ";$query2 .= "OR ";}
	}
	$query .= ") GROUP BY num_pat, id_pat;";
	$query2 .= ";";
	my $sth = $dbh->prepare($query2);
	my $res = $sth->execute();
	# modify hash

	while (my $result = $sth->fetchrow_hashref()) {
		$patients->{$result->{'identifiant'}.$result->{'numero'}} = 1; #tag existing patients
	}
	$sth = $dbh->prepare($query);
	$res = $sth->execute();
	# cleanup hash
	while (my $result = $sth->fetchrow_hashref()) {
		if (exists($patients->{$result->{'id_pat'}.$result->{'num_pat'}})) {$patients->{$result->{'id_pat'}.$result->{'num_pat'}} = 2} # remove patients with that type of analysis already recorded
	}
	return $patients;
}

sub get_filtering_and_manifest {
	my ($analysis, $dbh) = @_;
	my $query = "SELECT manifest_name, filtering_possibility FROM valid_type_analyse WHERE type_analyse = '$analysis';";
	my $res = $dbh->selectrow_hashref($query);
	my $manifest = $res->{'manifest_name'};
	my $filtered = $res->{'filtering_possibility'};
	return ($manifest, $filtered);
}

sub print_clinical_exome_criteria {
	my $q = shift;
	return info_panel($q->start_div({'class' => 'w3-container w3-padding-16'}).
		$q->span('Criteria for FAIL:')."\n".
		$q->start_ul({'class' => 'w3-ul w3-hoverable', 'style' => 'width:30%'})."\n".
			$q->li('% 20X bp < '.$U2_modules::U2_subs_1::PC20X_CE)."\n".
			$q->li('Ts/Tv ratio < '.$U2_modules::U2_subs_1::TITV_CE)."\n".
			$q->li('mean DOC < '.$U2_modules::U2_subs_1::MDOC_CE)."\n".
		$q->end_ul().$q->end_div()."\n", $q);
}

sub print_panel_criteria {
	my ($q, $analysis) = @_;
	my $text = $q->start_div({'class' => 'w3-container w3-padding-16'}).
		$q->span('Criteria for FAIL:')."\n".
		$q->start_ul({'class' => 'w3-ul w3-hoverable', 'style' => 'width:30%'})."\n".
			$q->li('% Q30 < '.$U2_modules::U2_subs_1::Q30)."\n";
	if ($analysis =~ /$ANALYSIS_ILLUMINA_WG_REGEXP/o) {
		$text .= $q->li('% 50X bp < '.$U2_modules::U2_subs_1::PC50X_WG)."\n".
			$q->li('Ts/Tv ratio < '.$U2_modules::U2_subs_1::TITV_WG)."\n";
	}
	else {
		$text .= $q->li('% 50X bp < '.$U2_modules::U2_subs_1::PC50X)."\n".
			$q->li('Ts/Tv ratio < '.$U2_modules::U2_subs_1::TITV)."\n";
	}
	$text .= $q->li('mean DOC < '.$U2_modules::U2_subs_1::MDOC)."\n".
		$q->end_ul().$q->end_div()."\n";
	return info_panel($text, $q);
}

sub build_ngs_form {
	my ($id, $number, $analysis, $run, $filtered, $patients, $script, $step, $q, $data_dir, $ssh, $summary_file, $instrument) = @_;

	my $info =  "In addition to $id$number, I have found ".(keys(%{$patients})-1)." other patients eligible for import in U2 for this run ($run).".$q->br()."Please select those you are interested in";
	if ($filtered == 1) {$info .= " and specify your filtering options for each of them"}
	$info .= ".";
	my $form = &info_panel($info, $q);
	$info = 'You may not be able to select some patients. This means either that they are already recorded for that type of analysis or that they are not recorded in U2 yet.'.$q->br().'In this case, please insert them via the Excel file and reload the page.';

	$form .= &danger_panel($info, $q).$q->br();

	# Filtering or not?
	my $filter = '';
	if ($filtered == '1') {$filter = U2_modules::U2_subs_1::check_filter($q)}


	$form .= $q->start_div({'align' => 'center'}).
		$q->start_div({'class' => 'w3-container w3-card-4 w3-light-grey w3-text-blue w3-margin', 'style' => 'width:50%'}).
			$q->h3({'class' => 'w3-center w3-padding-16'}, 'Import '.ucfirst($analysis).' data')."\n".
			$q->button({'id' => "select_all_illumina_form_$run", 'value' => 'Unselect all', 'onclick' => "select_toggle('illumina_form_$run');", 'class' => 'w3-button w3-ripple w3-blue w3-hover-white'}).$q->br().
			$q->start_form({'action' => $script, 'method' => 'post', 'id' => "illumina_form_$run", 'onsubmit' => 'return illumina_form_submit();', 'enctype' => &CGI::URL_ENCODED})."\n".
			$q->input({'type' => 'hidden', 'name' => 'step', 'value' => $step, form => "illumina_form_$run"})."\n".
			$q->input({'type' => 'hidden', 'name' => 'analysis', 'value' => $analysis, form => "illumina_form_$run"})."\n".
			$q->input({'type' => 'hidden', 'name' => 'run_id', 'value' => $run, form => "illumina_form_$run"})."\n".
			$q->input({'type' => 'hidden', 'name' => 'sample', 'value' => "1_$id$number", form => "illumina_form_$run"})."\n";
	if ($filter ne '') {$form .=  $q->input({'type' => 'hidden', 'name' => '1_filter', 'value' => "$filter", form => "illumina_form_$run"})."\n"}

	my $i = 2;
	foreach my $sample (sort keys(%{$patients})) {
		if (($sample ne $id.$number) && ($patients->{$sample} == 1)) {# other eligible patients
			$form .=  $q->start_div({'class' => 'w3-row w3-section w3-bottombar w3-border-light-grey w3-hover-border-blue'}).
					$q->start_div({'class' => 'w3-quarter w3-large w3-left-align'}).
						$q->input({'type' => 'checkbox', 'name' => "sample", 'class' => 'sample_checkbox', 'value' => $i."_$sample", 'checked' => 'checked', form => "illumina_form_$run"}, "&nbsp;&nbsp;$sample");
			if ($filtered == '1') {
				$form .=   $q->end_div().
						$q->start_div({'class' => 'w3-quarter w3-large'}).
							$q->span({'for' => 'filter'}, 'Filter:')."\n".
						$q->end_div()."\n".
					$q->start_div({'class' => 'w3-quarter'})."\n";
				$form .=   U2_modules::U2_subs_1::select_filter($q, $i.'_filter', "illumina_form_$run");
				$form .=   $q->end_div();
			}
			else {$form .=   $q->end_div();}
			if ($analysis =~ /Min?i?Seq-\d+/o){$form .=  &get_raw_data($data_dir, $sample, $ssh, $summary_file, $instrument, $q, $analysis)}
			else {$form .=  &get_raw_data_ce($sample, $run, $data_dir, $q)}
			$form .=   $q->end_div();
		}
		elsif (($sample ne $id.$number) && ($patients->{$sample} == 0)) {# unknown patient
			$form .=  $q->start_div({'class' => 'w3-row w3-section w3-bottombar w3-border-light-grey w3-hover-border-blue'}).
					$q->start_div({'class' => 'w3-large w3-quarter w3-left-align'}).
						$q->input({'type' => 'checkbox', 'name' => "sample", 'value' => $i."_$sample", 'disabled' => 'disabled', form => "illumina_form_$run"}, "&nbsp;&nbsp;$sample").
					$q->end_div().
					$q->div({'class' => 'w3-rest w3-medium'}, " not yet recorded in U2. Please proceed if you want to import Illumina data.")."\n".
				$q->end_div();
		}
		elsif (($sample ne $id.$number) && ($patients->{$sample} == 2)) {# patient with a run already recorded
			$form .=  $q->start_div({'class' => 'w3-row w3-section w3-bottombar w3-border-light-grey w3-hover-border-blue'}).
					$q->start_div({'class' => 'w3-large w3-quarter w3-left-align'}).
						$q->input({'type' => 'checkbox', 'name' => "sample", 'value' => $i."_$sample", 'disabled' => 'disabled', form => "illumina_form_$run"}, "&nbsp;&nbsp;$sample").
					$q->end_div().
					$q->div({'class' => 'w3-rets w3-medium'}, " has already a run recorded as $analysis.")."\n".$q->end_div();
		}
		else {# original patient
			$form .=  $q->start_div({'class' => 'w3-row w3-section w3-bottombar w3-border-light-grey w3-hover-border-blue'}).
					$q->div({'class' => 'w3-quarter w3-large w3-left-align'}, $sample)."\n";
			if ($filtered == '1') {
				$form .=   $q->div({'class' => 'w3-quarter w3-large'}, "Filter:").
					$q->div({'class' => 'w3-quarter w3-large w3-left-align'}, "$filter")."\n";
			}
			if ($analysis =~ /Min?i?Seq-\d+/o){$form .=  &get_raw_data($data_dir, $sample, $ssh, $summary_file, $instrument, $q, $analysis)}
			else {$form .= &get_raw_data_ce($sample, $run, $data_dir, $q)}
			$form .=   $q->end_div();
		}
		$i++;
	}
	$form .= $q->submit({'value' => 'Import', 'class' => 'w3-button w3-ripple w3-blue w3-hover-white', form => "illumina_form_$run"}).
		$q->br().$q->br()."\n".
		$q->end_form().
		$q->end_div().
		$q->end_div()."\n";
	return $form;
}

sub get_raw_data_ce {
	my ($sample, $run,$data_dir, $q) = @_;
	#we want
	#Target coverage at 20X:,
	#SNV Ts/Tv ratio:,
	#Mean region coverage depth:,

	my ($x20_expr, $tstv_expr, $doc_expr) = ('PCT_TARGET_BASES_20X', 'known_titv', 'MEAN_TARGET_COVERAGE');

	my $x20 = &get_raw_detail_ce($data_dir, $run, $sample, $x20_expr, 'multiqc_data/multiqc_picard_HsMetrics.txt');
	my $tstv = &get_raw_detail_ce($data_dir, $run, $sample, $tstv_expr, 'multiqc_data/multiqc_gatk_varianteval.txt');
	my $doc = &get_raw_detail_ce($data_dir, $run, $sample, $doc_expr, 'multiqc_data/multiqc_picard_HsMetrics.txt');


	my $criteria = '';
	if ($x20 < $U2_modules::U2_subs_1::PC20X_CE) {$criteria .= ' (20X % &le; '.$U2_modules::U2_subs_1::PC20X_CE.') '}
	if ($tstv < $U2_modules::U2_subs_1::TITV_CE) {$criteria .= ' (Ts/Tv &le; '.$U2_modules::U2_subs_1::TITV_CE.') '}
	if ($doc < $U2_modules::U2_subs_1::MDOC_CE) {$criteria .= ' (mean DOC &le; '.$U2_modules::U2_subs_1::MDOC_CE.') '}
	if ($criteria ne '') {return $q->div({'class' => 'w3-red w3-quarter'}, "FAILED $criteria")}
	else {return $q->div({'class' => 'w3-green w3-quarter'}, 'PASS')}
}

sub get_raw_detail_ce {
	my ($dir, $run, $sample, $criteria, $file) = @_;
	my $value;

	open F, "$dir/$run/$file" or die "File $dir/$run/$file not found $!";
	my $index = 0;
	while (<F>) {
		chomp;
		if (/Sample/o) {#1st line look for good col
			my @cols = split(/\t/, $_);
			my $i = 0;
			foreach(@cols) {
				#print "-$_-$criteria-<br/>";
				if ($_ eq $criteria) {$index = $i}
				$i++
			}
		}
		elsif (/$sample/) {
			my @values = split(/\t/, $_);
			if ($criteria =~ /UQ_/o) {
				#my $value = (100-($values[$index]*100));
				return sprintf('%.1f', (100-($values[$index]*100)))
			}
			elsif ($criteria =~ /PCT_/o) {return sprintf('%.1f', $values[$index]*100)}
			elsif ($criteria =~ /BASES/o) {return sprintf('%u', $values[$index])}
			elsif ($criteria =~ /MEAN_/o) {return sprintf('%u', $values[$index])}
			elsif ($criteria =~ /titv/o) {return sprintf('%.1f', $values[$index])}
			else {return $values[$index]}
		}
	}
	close F;
	return 'undef';
}

sub get_raw_detail_ce_qualimap {
	my ($dir, $run, $sample, $criteria, $file) = @_;
	my $value;
	open F, "$dir/$run/$file" or die "File $dir/$run/$file not found $!";
	my $index = 0;
	while (<F>) {
		chomp;
		if (/$criteria\s=\s([\d,]+)/) {
			my $value = $1;
			$value =~ s/,//og;
			return $value;
		}
	}
	close F;
	return 'undef';
}

#subs for panel, add_analysis.pl
sub get_raw_data {
	my ($dir, $sample, $ssh, $file, $instrument, $q, $analysis) = @_;
	#we want - miseq
	#Percent Q30:,
	#Target coverage at 50X:,
	#SNV Ts/Tv ratio:,
	#Mean region coverage depth:,
	my ($q30_expr, $x50_expr, $tstv_expr, $doc_expr, $num_reads);

	if ($instrument eq 'miseq') {
		($q30_expr, $x50_expr, $tstv_expr, $doc_expr, $num_reads) = ('Percent Q30:,', 'Target coverage at 50X:,', 'SNV Ts/Tv ratio:,', 'Mean region coverage depth:,', 'Padded target aligned reads:,');
	}
	elsif ($instrument eq 'miniseq') {
		($q30_expr, $x50_expr, $tstv_expr, $doc_expr, $num_reads) = ('Percent Q30,', 'Target coverage at 50X,', 'SNV Ts/Tv ratio,', 'Mean region coverage depth,', 'Targeted aligned reads,');
	}

	my $q30 = &get_raw_detail($dir, $sample, $ssh, $q30_expr, $file);
	my $x50 = &get_raw_detail($dir, $sample, $ssh, $x50_expr, $file);
	my $tstv = &get_raw_detail($dir, $sample, $ssh, $tstv_expr, $file);
	my $doc = &get_raw_detail($dir, $sample, $ssh, $doc_expr, $file);
	my $ontarget_reads = &get_raw_detail($dir, $sample, $ssh, $num_reads, $file);
	#return ($q30, $x50, $tstv, $doc);
	my $criteria = '';
	if ($q30 < $U2_modules::U2_subs_1::Q30) {$criteria .= ' (Q30 &le; '.$U2_modules::U2_subs_1::Q30.') '}
	if ($analysis =~ /$ANALYSIS_ILLUMINA_WG_REGEXP/o) {
		#Whole genes
		if ($x50 < $U2_modules::U2_subs_1::PC50X_WG) {$criteria .= ' (50X % &le; '.$U2_modules::U2_subs_1::PC50X_WG.') '}
		if ($tstv < $U2_modules::U2_subs_1::TITV_WG) {$criteria .= ' (Ts/Tv &le; '.$U2_modules::U2_subs_1::TITV_WG.') '}
	}
	else {
		if ($x50 < $U2_modules::U2_subs_1::PC50X) {$criteria .= ' (50X % &le; '.$U2_modules::U2_subs_1::PC50X.') '}
		if ($tstv < $U2_modules::U2_subs_1::TITV) {$criteria .= ' (Ts/Tv &le; '.$U2_modules::U2_subs_1::TITV.') '}
	}
	if ($doc < $U2_modules::U2_subs_1::MDOC) {$criteria .= ' (mean DOC &le; '.$U2_modules::U2_subs_1::MDOC.') '}
	if ($ontarget_reads < $U2_modules::U2_subs_1::NUM_ONTARGET_READS) {$criteria .= ' (on target reads &lt; '.$U2_modules::U2_subs_1::NUM_ONTARGET_READS.') '}
	if ($criteria ne '') {return $q->div({'class' => 'w3-red w3-quarter'}, "FAILED $criteria")}
	else {return $q->div({'class' => 'w3-green w3-quarter'}, 'PASS')}
}

sub get_raw_detail {
	my ($dir, $sample, $ssh, $expr, $file) = @_;
	#print "grep -e \"$expr\" $dir/".$sample."_S*.$file";
	my $data;
	# if ($access_method eq 'autofs') {
	my $path = "$dir/".$sample."_S*.$file";
	$data = `grep -e "$expr" $path`;
	# }
	# else {$data = $ssh->capture("grep -e \"$expr\" $dir/".$sample."_S*.$file")}
	#my $data = $ssh->capture("grep -e \"$expr\" $dir/".$sample."_S*.$file"
	#print "-$data-<br/>";
	if ($data =~ /$expr([\d\.]+)[%\s]{0,2}$/) {$data = $1}
	else {print "pb with $expr:$data:"}
	#print "_".$data."_<br/>";
	return $data,;
}

#in add_clinical_exome.pl, import_illumina.pl

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

sub dbnsfp_clinvar2text {
	my $code = shift;
	my @list = split(/\|/, $code);
	my $trad = '';
	foreach (@list) {
		#print $_;
		if ($_ eq '.') {$trad = 'not seen in Clinvar'}
		elsif ($_ < 0) {if ($trad =~ /score for ref allele;/){next}else{$trad .= 'score for ref allele;'}}
		elsif ($_ == 2) {if ($trad =~ /Benign;/){next}else{$trad .=  'Benign;'}}
		elsif ($_ == 3) {if ($trad =~ /Likely benign;/){next}else{$trad .=  'Likely benign;'}}
		elsif ($_ == 4) {if ($trad =~ /Likely pathogenic;/){next}else{$trad .=  'Likely pathogenic;'}}
		elsif ($_ == 5) {if ($trad =~ /Pathogenic;/){next}else{$trad .=  'Pathogenic;'}}
		elsif ($_ == 6) {if ($trad =~ /drug response;/){next}else{$trad .=  'drug response;'}}
		elsif ($_ == 7) {if ($trad =~ /histocompatibility;/){next}else{$trad .=  'histocompatibility;'}}
		else {if ($trad =~ /unknown code;/){next}else{$_ .=  'unknown code;'}}
	}
	return $trad;

}

sub gnomadAF {
	my ($tabix, $file, $type, $chr, $pos, $ref, $alt, $q) = @_;
	my @gnomad =  split(/\n/, `$tabix $file $chr:$pos-$pos`);
	#print $gnomad[0];
	foreach (@gnomad) {
		my @current = split(/\t/, $_);
		if (($current[3] eq $ref) && ($current[4] eq $alt)) {
		#if (/\t$ref\t$alt\t/) {
			return $q->start_li().$q->span({'onclick' => 'window.open(\'http://gnomad.broadinstitute.org/\')', 'class' => 'pointer'}, "gnomAD $type").$q->span(" AF: $current[5]").$q->span().$q->end_li()."\n";
		}
	}
}

sub most_damaging {
	my ($score, $direction) = @_;
	my @scores = split(/;/, $score);
	if ($direction eq 'min') {return min @scores}
	else {return max @scores}
}


1;
