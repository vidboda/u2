BEGIN {delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV', 'PATH'};}

use strict;
#use CGI; #in startup.pl
#use DBI;
#use AppConfig qw(:expand :argcount);
use URI::Encode qw(uri_encode uri_decode);
use URI::Escape;
#use LWP::UserAgent;
use SOAP::Lite;
use JSON;
#use Data::Dumper;
#use REST::Client;

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
#		script called by AJAX to create/insert variants in U2


## Minimal init of USHVaM 2 perl scripts: script called by AJAX, minimal init
#	env variables
#	get MINIMAL config infos
#	initialize DB connection
#	identify users

$CGI::POST_MAX = 1024; #* 100;  # max 1K posts
$CGI::DISABLE_UPLOADS = 1;

my $config_file = U2_modules::U2_init_1->getConfFile();
my $config = U2_modules::U2_init_1->initConfig();
$config->file($config_file);# or die $!;
my $DB = $config->DB();
my $HOST = $config->HOST();
my $DB_USER = $config->DB_USER();
my $DB_PASSWORD = $config->DB_PASSWORD();
my $HTDOCS_PATH = $config->HTDOCS_PATH();
my $ABSOLUTE_HTDOCS_PATH  =$config->ABSOLUTE_HTDOCS_PATH();


my $q = new CGI;

my $dbh = DBI->connect(    "DBI:Pg:database=$DB;host=$HOST;",
                        $DB_USER,
                        $DB_PASSWORD,
                        {'RaiseError' => 1}
                ) or die $DBI::errstr;


my $user = U2_modules::U2_users_1->new();


#U2_modules::U2_subs_1::standard_begin_html($q, $user->getName(), $dbh);

##end of Minimal init

#hg38 transition variable for postgresql 'start_g' segment field
my ($postgre_start_g, $postgre_end_g) = ('start_g', 'end_g');  #hg19 style
#print Dumper($q);
#get params
my ($type, $nom, $num_seg, $technique);
my ($id, $number) = ('', '');
my $step = U2_modules::U2_subs_1::check_step($q);
if ($step == 1 || $q->param('sample')) {
	($id, $number) = U2_modules::U2_subs_1::sample2idnum(uc($q->param('sample')), $q);
	$technique = U2_modules::U2_subs_1::check_analysis($q, $dbh, 'form');
}
if ($q->param('type') && $q->param('type') =~ /(exon|intron|5UTR|3UTR)/o) {$type = $1}
else {print 1;U2_modules::U2_subs_1::standard_error(15, $q)}
if ($q->param('nom') && $q->param('nom') =~ /(\w+)/o || $q->param('nom') == '0') {$nom = '0';if ($1) {$nom = $1}}
else {print 2;U2_modules::U2_subs_1::standard_error(15, $q)}
if ($q->param('numero') && $q->param('numero') =~ /([\d-]+)/o) {$num_seg = $1}
else {print 3;U2_modules::U2_subs_1::standard_error(15, $q)}
my ($gene, $second_name) = U2_modules::U2_subs_1::check_gene($q, $dbh);
my $acc_no = U2_modules::U2_subs_1::check_acc($q, $dbh);
#if ($q->param('acc_no') && $q->param('acc_no') =~ /(NM_\d+)/o) {$acc_no = $1}
#else {print $q->param('acc_no');U2_modules::U2_subs_1::standard_error(15, $q)}


#if ($q->param('technique') && $q->param('technique') =~ /(MLPA|QMPSF|SANGER|aCGH)/o) {$technique = $1}
#else {print 5;U2_modules::U2_subs_1::standard_error(15, $q)}
print $q->header();

if ($step == 1) { #insert form and possibility to create variants.

	#build query

	#get strand - NG acc no
	my $query = "SELECT brin, chr, acc_g FROM gene WHERE refseq = '$acc_no';";
	my $res = $dbh->selectrow_hashref($query);
	my $order = 'ASC';
	if ($res->{'brin'} eq '-'){$order = 'DESC';}
	#get patient gender => if M and chrX => hemizygous
	my ($default_status, $default_allele) = ('heterozygous', 'unknown');
	my $chr = $res->{'chr'};
	if ($chr eq 'X') {
		$query = "SELECT sexe FROM patient WHERE numero = '$number' AND identifiant = '$id';";
		my $res2 = $dbh->selectrow_hashref($query);
		if ($res2->{'sexe'} eq 'M') {$default_status = 'hemizygous';$default_allele = '2';}
	}
	if ($chr eq 'M') {$default_status = 'heteroplasmic';$default_allele = '2'}
	my $ng_accno = $res->{'acc_g'};
	#select name to query
	my $name = 'nom_prot';
	if ($type ne 'exon') {$name = 'nom_ivs'}


	$query = "SELECT nom, $name as nom2, classe FROM variant WHERE refseq = '$acc_no' AND num_segment = '$num_seg' AND type_segment = '$type' ORDER BY nom_g $order;";
	my $sth = $dbh->prepare($query);
	$res = $sth->execute();

	print $q->p({'class' => 'title', 'id' => 'title_form_var'}, $id.$number);

	print $q->start_form({'action' => '', 'method' => 'post', 'class' => 'u2form', 'id' => 'analysis_form', 'enctype' => &CGI::URL_ENCODED}),
					#$q->input({'type' => 'hidden', 'name' => 'step', 'value' => '2'}), "\n",
					$q->input({'type' => 'hidden', 'name' => 'sample', 'value' => $id.$number, 'id' => 'sample', 'form' => 'analysis_form'}), "\n",
					$q->input({'type' => 'hidden', 'name' => 'gene', 'value' => $gene, 'id' => 'gene', 'form' => 'analysis_form'}), "\n",
					$q->input({'type' => 'hidden', 'name' => 'acc_no', 'value' => $acc_no, 'id' => 'acc_no', 'form' => 'analysis_form'}), "\n",
					$q->input({'type' => 'hidden', 'name' => 'technique', 'value' => $technique, 'id' => 'technique', 'form' => 'analysis_form'}), "\n",
					$q->input({'type' => 'hidden', 'name' => 'type', 'value' => $type, 'id' => 'type', 'form' => 'analysis_form'}), "\n",
					$q->input({'type' => 'hidden', 'name' => 'numero', 'value' => $num_seg, 'id' => 'numero', 'form' => 'analysis_form'}), "\n",
					$q->input({'type' => 'hidden', 'name' => 'nom', 'value' => $nom, 'id' => 'nom', 'form' => 'analysis_form'}), "\n",
					$q->input({'type' => 'hidden', 'name' => 'ng_accno', 'value' => $ng_accno, 'id' => 'ng_accno', 'form' => 'analysis_form'}), "\n",
					$q->start_fieldset(),
						$q->legend("Variants in $type $nom ($acc_no):"), $q->start_ol(), $q->br(), $q->br(), "\n",
						$q->start_li(), "\n",
							$q->label({'for' => 'existing_variants'}, 'Existing variants:'), "\n",
							$q->start_Select({'name' => 'nom_c', 'id' => 'existing_variant', 'form' => 'analysis_form'}), "\n",
								$q->option({'selected' => 'selected', 'value' => ''}), "\n";
	while (my $result = $sth->fetchrow_hashref()) {
		my $color = U2_modules::U2_subs_1::color_by_classe($result->{'classe'}, $dbh);
		print $q->option({'value' => $result->{'nom'}, 'style' => "color:$color"}, "$result->{'nom'} - $result->{'nom2'}"), $q->end_option(), "\n";
	}

	my @status = ('heterozygous', 'homozygous', 'hemizygous');
	my @alleles = ('unknown', 'both', '1', '2');
	if ($chr eq 'M') {
		@status = ('heteroplasmic', 'homoplasmic');
		@alleles = ('2');
	}
	my $js = "if (\$(\"#status\").val() === 'homozygous') {\$(\"#allele\").val('both')}else {\$(\"#allele\").val('unknown')}";
	print $q->end_Select(), $q->end_li(), $q->br(), $q->br(), "\n",
		$q->start_li(), "\n",
			$q->label({'for' => 'new_variant'}, 'New variant (cDNA):'), "\n",
			$q->textfield(-name => 'new_variant', -id => 'new_variant', -value => 'c.', -size => '20', -maxlength => '100'), "\n",
		$q->end_li(), $q->br(), $q->br(), "\n",
		$q->start_li(), "\n",
			$q->label({'for' => 'status'}, 'Status:'), "\n",
			$q->popup_menu(-name => 'status', -id => 'status', -values => \@status, -onchange => $js, -default => $default_status, required => 'required'), "\n",
		$q->end_li(), $q->br(), $q->br(), "\n",
		$q->start_li(), "\n",
			$q->label({'for' => 'allele'}, 'Allele:'), "\n",
			$q->popup_menu(-name => 'allele', -id => 'allele', -values => \@alleles, -default => $default_allele, required => 'required'), "\n",
		$q->end_li(), "\n", $q->br(),
		$q->start_li(), "\n",
			$q->label({'for' => 'denovo'}, 'De novo:'), "\n",
			$q->input({'type' => 'checkbox', 'name' => 'denovo', 'id' => 'denovo'}), "\n",
		$q->end_li(), "\n",
		$q->end_ol(), $q->end_fieldset(), $q->end_form();
}
elsif ($step == 2) { #insert variant and print
	#print "$step 1 ".$q->param('new_variant')."<br/>";
	#get id for li at the end
	my $j;
	if ($q->param('j') && $q->param('j') =~ /(\d+)/o) {$j = $1}

	my $semaph == 0;
	my $cdna;

	if ($q->param('new_variant') && $q->param('new_variant') =~ /(c\.[>\w\*\-\+\?_]+)/o) {
		###OUCH need to create variant with variantvalidator
		#print $step." 2 $acc_no - ".$q->param('accession')."<br/>";
		$cdna = $1;
		$cdna =~ tr/atgc/ATGC/;
		$cdna = lcfirst($cdna);

		my ($denovo, $status, $allele);
		if ($id ne '') {
			$denovo = U2_modules::U2_subs_1::check_denovo($q);
			$status = U2_modules::U2_subs_1::check_status($q);
			$allele = U2_modules::U2_subs_1::check_allele($q);
		}

		###1st check variant does not exist
		##double check del - dups
		my $truncated = $cdna;
		if ($cdna =~ /(c\..+d[eu][lp])[ATCG]+$/o) {$truncated = $1}
		#elsif ($cdna =~ /(c\..+d[eu][lp])$/o) {}
		my ($type_segment, $classe, $var_final);
		my $query = "SELECT nom FROM variant WHERE (nom = '$cdna' OR (nom = '$truncated' AND type_adn IN ('deletion','duplication')) OR (nom ~ '^".$cdna."[ATCG]+\$' AND type_adn IN ('deletion','duplication'))) AND refseq = '$acc_no';";
		#print "$query<br/>";
		my $res = $dbh->selectrow_hashref($query);
		#print $cdna;
		if (!$res->{'nom'}) {
			my $ng_accno;
			if ($q->param('ng_accno') &&  $q->param('ng_accno') =~ /(NG_\d+\.\d)/o) {$ng_accno = $1}
#			my ($nom_g, $nom_ng, $nom_g_38, $nom_ivs, $nom_prot, $seq_wt, $seq_mt, $type_adn, $type_arn, $type_prot, $type_segment, $type_segment_end, $num_segment, $num_segment_end, $taille, $snp_id, $snp_common, $classe, $variant, $defgen_export, $chr);
#			($nom_prot, $nom_ivs, $type_arn, $classe, $defgen_export, $nom_g_38, $snp_id, $snp_common, $seq_wt, $seq_mt) = ('NULL', 'NULL', 'neutral', 'unknown', 'f', 'NULL', 'NULL', 'NULL', 'NULL', 'NULL');
			#get NM_ acc version for mutalyzer
			my $query = "SELECT acc_version FROM gene where refseq = '$acc_no';";
			my $res = $dbh->selectrow_hashref($query);
			my $acc_ver = $res->{'acc_version'};

			##run numberConversion() webservice
			#my $semaph_error = 0;
			#remove nts in dups before submitting
			if ($cdna =~ /dup[ATGC]+/o) {$cdna =~ s/dup[ATGC]+/dup/o}
			if ($cdna =~ /c.-?(\d+)[+-][\?\d]+_(\d+)[+-][\?\d][di][eun][lps].*/o) {#LR not handled by VV (server timeout)
					if ($2-$1 > 100) {
						my $text = "Large rearrangements are not yet handled by VV. Please try using Mutalyzer.";
						print U2_modules::U2_subs_2::danger_panel($text, $q);
						exit;
					}
			}
			my $vv_results = decode_json(U2_modules::U2_subs_1::run_vv('GRCh38', "$acc_no.$acc_ver", $cdna, 'cdna'));
      if ($vv_results eq '0' || exists($vv_results->{'url_error'})) {
			# if ($vv_results == 500 || $vv_results =~/^VVERROR/o) {
				my $text = "VariantValidator returned an internal server error. You may try again to submit your variant or try mutalyzer.";
				print STDERR $vv_results;
				print U2_modules::U2_subs_2::danger_panel($text, $q);
				exit;
			}
			#run variantvalidator API
			my $vvkey = "$acc_no.$acc_ver:$cdna";
			if ($vv_results ne '0') {
				my $message;#not used here but in import_illumina_vv.pl
				($message, $type_segment, $classe, $var_final) = U2_modules::U2_subs_3::create_variant_vv($vv_results, $vvkey, $gene, $cdna, $acc_no, $acc_ver, $ng_accno, $user, $q, $dbh, 'web');
				print STDERR $message;

				if ($id ne '') {
					my $insert = "INSERT INTO variant2patient (nom_c, num_pat, id_pat, refseq, type_analyse, statut, allele, denovo) VALUES ('$var_final', '$number', '$id', '$acc_no', '$technique', '$status', '$allele', '$denovo');\n";
					print $insert;
					$dbh->do($insert) or die "Variant already recorded for the patient, there must be a mistake somewhere $!";
				}
			}

			#print "NEW VARIANT $variant, $status, allele: $allele";
			#my $variant = $cdna;
			if ($id ne '') {
				if ($denovo eq 'true') {$denovo = '_denovo'}
				else {$denovo = ''}
				print $q->td("Added: ".ucfirst($type_segment)." ".$nom).
					$q->td($var_final).$q->td({'id' => "wstatus$j"}, $status).
					$q->td({'id' => "wallele$j"}, $allele.$denovo).
					$q->td({'style' => "color:".U2_modules::U2_subs_1::color_by_classe($classe, $dbh).";"}, $classe).
					$q->start_td().
						$q->img({'src' => $HTDOCS_PATH.'data/img/buttons/delete.png', 'class' => 'pointer text_img', 'width' => '15', height => '15', 'onclick' => "delete_var('$id$number', '$gene', '$technique', '".uri_encode($var_final)."', 'v$j');"}).
					$q->end_td().
					$q->start_td().
						$q->a({'href' => 'javascript:;', 'title' => 'click to modifiy status and/or alleles', 'onclick' => "createFormStatus('".uri_encode($var_final)."', '$gene', '$id$number', '$technique', 'v$j', '$status', '$allele');"}, 'Modify').
					$q->end_td();
			}
			else {
				my $text = $q->span('Newly created variant: ').$q->a({'href' => "variant.pl?gene=$gene&amp;accession=$acc_no&nom_c=".uri_escape($var_final)}, $var_final);
				print U2_modules::U2_subs_2::info_panel($text, $q);
			}
		}
		else {
			$cdna = $res->{'nom'};
			$semaph = 1;
		}
	}
	if (($q->param('existing_variant') && $q->param('existing_variant') =~ /[nc]\..+/o) || ($semaph == 1)) {
		if ($semaph != 1) {$cdna = U2_modules::U2_subs_1::check_nom_c($q, $dbh)}
		if ($q->param('single_var') && $q->param('single_var') eq 'y') {
			my $text = $q->span('Variant already recorded: ').$q->a({'href' => "variant.pl?gene=$gene&amp;accession=$acc_no&nom_c=".uri_escape($cdna)}, $cdna);
			print U2_modules::U2_subs_2::info_panel($text, $q);
		}
		else {
			my $status = U2_modules::U2_subs_1::check_status($q);
			my $allele = U2_modules::U2_subs_1::check_allele($q);
			my $denovo = U2_modules::U2_subs_1::check_denovo($q);
			my $query = "SELECT nom_c FROM variant2patient WHERE nom_c = '$cdna' AND refseq = '$acc_no' AND num_pat = '$number' AND id_pat = '$id' AND type_analyse = '$technique';";
			my $res = $dbh->selectrow_hashref($query);
			if (!$res->{'nom_c'}) {
				my $insert = "INSERT INTO variant2patient (nom_c, num_pat, id_pat, refseq, type_analyse, statut, allele, denovo) VALUES ('$cdna', '$number', '$id', '$acc_no', '$technique', '$status', '$allele', '$denovo');";
				my $query = "SELECT classe FROM variant WHERE nom = '$cdna' AND refseq = '$acc_no';";
				my $res_classe = $dbh->selectrow_hashref($query);
				$dbh->do($insert) or die "Variant already recorded for the patient, there must be a mistake somewhere $!";
				##update 05/12/2015 add allele and status should modifiy existing e.g. if allele already exists as 'unknown' post to miseq sequencing and we here add an allele 1 by Sanger, should change miseq allele
				## not relevant by definition when creating new variants above
				my $update = "UPDATE variant2patient SET statut = '$status', allele = '$allele', denovo = '$denovo' WHERE nom_c = '$cdna' AND id_pat = '$id' AND num_pat = '$number' AND refseq = '$acc_no';";
				$dbh->do($update) or die "Error when updating the analysis, there must be a mistake somewhere $!";

				if ($type !~ /on/o) {$type = ''}
				if ($denovo eq 'true') {$denovo = '_denovo'}
				else {$denovo = ''}
				print $q->td("Added: ".ucfirst($type)." ".$nom).
					$q->td($cdna).$q->td({'id' => "wstatus$j"}, $status).
					$q->td({'id' => "wallele$j"}, $allele.$denovo).
					$q->td({'style' => "color:".U2_modules::U2_subs_1::color_by_classe($res_classe->{'classe'}, $dbh).";"}, $res_classe->{'classe'}).
					$q->start_td().
						$q->img({'src' => $HTDOCS_PATH.'data/img/buttons/delete.png', 'class' => 'pointer text_img', 'width' => '15', height => '15', 'onclick' => "delete_var('$id$number', '$gene', '$technique', '".uri_encode($cdna)."', 'v$j');"}).
					$q->end_td().
					$q->start_td().
						$q->a({'href' => 'javascript:;', 'title' => 'click to modifiy status and/or alleles', 'onclick' => "createFormStatus('".uri_encode($cdna)."', '$gene', '$id$number', '$technique', 'v$j');"}, 'Modify').
					$q->end_td();
			}
		}
	}
}
elsif ($step == 3) { #delete variant
	my $var = U2_modules::U2_subs_1::check_nom_c($q, $dbh);
	my $delete = "DELETE FROM variant2patient WHERE num_pat = '$number' AND id_pat = '$id' AND refseq = '$acc_no' AND type_analyse = '$technique' AND nom_c = '$var';";
	$dbh->do($delete) or die "Error when deleting the analysis, there must be a mistake somewhere $!";
	#print "$var deleted";
}


##specific subs for current script
