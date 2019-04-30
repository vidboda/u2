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


if ($step == 1) { #insert form and possibility to create variants.
	
	#build query

	#get strand - NG acc no
	my $query = "SELECT brin, chr, acc_g FROM gene WHERE nom[2] = '$acc_no';";
	my $res = $dbh->selectrow_hashref($query);
	my $order = 'ASC';
	if ($res->{'brin'} eq '-'){$order = 'DESC';}
	#get patient gender => if M and chrX => hemizygous
	my ($default_status, $default_allele) = ('heterozygous', 'unknown');
	if ($res->{'chr'} eq 'X') {
		$query = "SELECT sexe FROM patient WHERE numero = '$number' AND identifiant = '$id';";
		my $res2 = $dbh->selectrow_hashref($query);		
		if ($res2->{'sexe'} eq 'M') {$default_status = 'hemizygous';$default_allele = '2';}
	}
	my $ng_accno = $res->{'acc_g'};
	#select name to query
	my $name = 'nom_prot';
	if ($type ne 'exon') {$name = 'nom_ivs'}
	
	#$query = "SELECT nom, $name as nom2, classe FROM variant WHERE nom_gene[2] = '$acc_no' AND num_segment = '$num_seg' AND type_segment = '$type' AND nom NOT IN (SELECT nom_c FROM variant2patient WHERE num_segment = '$num_seg' AND type_segment = '$type' AND type_analyse = '$technique' AND nom_gene[2] = '$acc_no' AND num_pat = '$number' AND id_pat = '$id') ORDER BY nom_g $order;";
	$query = "SELECT nom, $name as nom2, classe FROM variant WHERE nom_gene[2] = '$acc_no' AND num_segment = '$num_seg' AND type_segment = '$type' ORDER BY nom_g $order;";
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
	my $js = "if (\$(\"#status\").val() === 'homozygous') {\$(\"#allele\").val('both')}else {\$(\"#allele\").val('unknown')}";
	print $q->end_Select(), $q->end_li(), $q->br(), $q->br(), "\n",
		$q->start_li(), "\n",
			$q->label({'for' => 'new_variant'}, 'New variant (cDNA):'), "\n",
			$q->textfield(-name => 'new_variant', -id => 'new_variant', -value => 'c.', -size => '20', -maxlength => '50'), "\n",
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
		my $query = "SELECT nom FROM variant WHERE (nom = '$cdna' OR (nom = '$truncated' AND type_adn IN ('deletion','duplication')) OR (nom ~ '^".$cdna."[ATCG]+\$' AND type_adn IN ('deletion','duplication'))) AND nom_gene[1] = '$gene' AND nom_gene[2] = '$acc_no';";
		#print "$query<br/>";
		my $res = $dbh->selectrow_hashref($query);
		#print $cdna;
		if (!$res->{'nom'}) {			
			my $ng_accno;
			if ($q->param('ng_accno') &&  $q->param('ng_accno') =~ /(NG_\d+\.\d)/o) {$ng_accno = $1}
#			my ($nom_g, $nom_ng, $nom_g_38, $nom_ivs, $nom_prot, $seq_wt, $seq_mt, $type_adn, $type_arn, $type_prot, $type_segment, $type_segment_end, $num_segment, $num_segment_end, $taille, $snp_id, $snp_common, $classe, $variant, $defgen_export, $chr);
#			($nom_prot, $nom_ivs, $type_arn, $classe, $defgen_export, $nom_g_38, $snp_id, $snp_common, $seq_wt, $seq_mt) = ('NULL', 'NULL', 'neutral', 'unknown', 'f', 'NULL', 'NULL', 'NULL', 'NULL', 'NULL');
			#get NM_ acc version for mutalyzer
			my $query = "SELECT acc_version FROM gene where nom[2] = '$acc_no';";
			my $res = $dbh->selectrow_hashref($query);
			my $acc_ver = $res->{'acc_version'};
			
			##run numberConversion() webservice
			#my $semaph_error = 0;
			#remove nts in dups before submitting
			if ($cdna =~ /dup[ATGC]+/o) {$cdna =~ s/dup[ATGC]+/dup/o}
			my $vv_results = decode_json(U2_modules::U2_subs_1::run_vv_cdna('GRCh38', "$acc_no.$acc_ver", $cdna));
			#run variantvalidator API
			my $vvkey = "$acc_no.$acc_ver:$cdna";
			if ($vv_results ne '0') {
				my $message;#not used here but in import_illumina_vv.pl
				($message, $type_segment, $classe, $var_final) = U2_modules::U2_subs_3::create_variant_vv($vv_results, $vvkey, $gene, $cdna, $acc_no, $acc_ver, $ng_accno, $user, $q, $dbh, 'web');
				print STDERR $message;
			
			#	print Dumper($vv_results);				
			#	foreach my $key (keys %{$vv_results}) {
			#		#print $key;
			#		#bad wt nt => sometimes key = new NMvar (autoremapped) ->{'validation_warnings}
			#		if ($key =~ /NM_.+/o &&  $vv_results->{$key}->{'validation_warnings'}[0] =~ /automapped to $acc_no\.$acc_ver:(c\..+)/g) {
			#			my $text = $q->span("VariantValidator reports that your variant should be $1 instead of $cdna");
			#			print U2_modules::U2_subs_2::danger_panel($text, $q);
			#			exit;
			#		}
			#		elsif ($key =~ /validation_warning/) {
			#			#print $vv_results->{$key}->{'validation_warnings'}[0];
			#			my $text = '';
			#			if ($vv_results->{$key}->{'validation_warnings'}[0] eq "$acc_no.$acc_ver:$cdna") {
			#				#bad wt  nt sometimes validation_warnings = key directly
			#				$text = "VariantValidator error: ".$vv_results->{$key}->{'validation_warnings'}[1];
			#			}
			#			elsif ($vv_results->{$key}->{'validation_warnings'}[0] =~ /length must be/o) {
			#				$text = "VariantValidator error for $cdna : ".$vv_results->{$key}->{'validation_warnings'}[0];
			#			}
			#			if ($text ne '') {
			#				print U2_modules::U2_subs_2::danger_panel($text, $q);
			#				exit;
			#			}
			#		}
			#		if (!$vv_results->{$vvkey}) {#VV changed variant name (ex with delAGinsT)
			#			if (ref($vv_results->{$key}) eq ref {} && $vv_results->{$key}->{'submitted_variant'} eq $vvkey) {$vvkey = $key;print "<br/>".$vv_results->{$key}->{'submitted_variant'}."<br/>"}
			#		}
			#	}
			#	
			#	print $vv_results->{$vvkey}->{'primary_assembly_loci'}->{'hg19'}->{'hgvs_genomic_description'}."--<br/>";#->{'hgvs_genomic_description'}
			#	my @full_nom_g_19 = split(/:/, $vv_results->{$vvkey}->{'primary_assembly_loci'}->{'hg19'}->{'hgvs_genomic_description'});
			#	if ($full_nom_g_19[0] =~ /NC_0+([^0]{1,2}0?)\.\d{1,2}$/o) {
			#		$chr = $1;
			#		if ($chr == 23) {$chr = 'X'}
			#		elsif ($chr == 24) {$chr = 'Y'}
			#		$nom_g = "chr$chr:".pop(@full_nom_g_19);
			#	}
			#	else {
			#		my $text = "There has been an issue with VariantValidator. Please double check your variant and resubmit. If this issue persists, contact an admin.";
			#		print U2_modules::U2_subs_2::danger_panel($text, $q);
			#		exit;
			#	}#"Pb with variantvalidator full_nom_g_19: $full_nom_g_19[0]"}
			#	print "<br/>".$nom_g."<br/>";
			#	
			#	if ($vv_results->{$vvkey}->{'primary_assembly_loci'}->{'hg38'}->{'hgvs_genomic_description'} ne '') {				
			#		$nom_g_38 = (split(/:/, $vv_results->{$vvkey}->{'primary_assembly_loci'}->{'hg38'}->{'hgvs_genomic_description'}))[1];
			#		#print $nom_g_38."<br/>";
			#	}
			#	else {#SLOW
			#		my $chr_tmp = "chr$chr";
			#		if ($nom_g =~ /g\.(\d+)_(\d+)([^\d]+)$/o) {
			#			my ($s19, $e19, $rest) = ($1, $2, $3);
			#			my $s38 = U2_modules::U2_subs_3::liftover($s19, $chr_tmp, $ABSOLUTE_HTDOCS_PATH, $U2_modules::U2_subs_3::HG19TOHG38CHAIN);
			#			my $e38 = U2_modules::U2_subs_3::liftover($e19, $chr_tmp, $ABSOLUTE_HTDOCS_PATH, $U2_modules::U2_subs_3::HG19TOHG38CHAIN);
			#			if ($s38 eq 'f' || $e38 eq 'f') {$nom_g_38 = 'NULL'}
			#			else {$nom_g_38 = "$chr_tmp:g.".$s38."_$e38$rest"}
			#		}
			#		elsif ($nom_g =~ /g\.(\d+)([^\d]+)$/o) {
			#			my ($s19, $rest) = ($1, $2);
			#			my $s38 = U2_modules::U2_subs_3::liftover($s19, $chr_tmp, $ABSOLUTE_HTDOCS_PATH, $U2_modules::U2_subs_3::HG38TOHG19CHAIN);
			#			if ($s38 eq 'f') {$nom_g_38 = 'NULL'}
			#			else {$nom_g_38 = "$chr_tmp:g.$s38$rest"}
			#		}
			#	}
			#	print $nom_g_38."<br/>";
			#	
			#	if ($nom_g =~ />/o) {$type_adn = 'substitution'}
			#	elsif ($nom_g =~ /delins/o) {$type_adn = 'indel'}
			#	elsif ($nom_g =~ /del/o) {$type_adn = 'deletion'}
			#	elsif ($nom_g =~ /ins/o) {$type_adn = 'insertion'}
			#	elsif ($nom_g =~ /dup/o) {$type_adn = 'duplication'}
			#	elsif ($nom_g =~ /inv/o) {$type_adn = 'inversion'}
			#	print $type_adn."<br/>";
			#	#my @full_nom_ng = split(/:/, $vv_results->{"$acc_no.$acc_ver:$cdna"}->{'hgvs_refseqgene_variant'});
			#	#$nom_ng = pop(@full_nom_ng);
			#	$nom_ng = (split(/:/, $vv_results->{$vvkey}->{'hgvs_refseqgene_variant'}))[1];
			#	print $nom_ng."<br/>"; 
			#	
			#	$nom_prot = (split(/:/, $vv_results->{$vvkey}->{'hgvs_predicted_protein_consequence'}->{'tlr'}))[1];
			#	print $nom_prot."<br/>";
			#	if ($nom_prot =~ /=/o) {$type_prot = 'silent'}
			#	elsif ($nom_prot =~ /^[A_Z][a-z]{2}\d+Ter$/o) {$type_prot = 'nonsense';$classe = 'pathogenic';$defgen_export = 't'}
			#	elsif ($nom_prot =~ /^[A_Z][a-z]{2}\d+[A-Z][a-z]{2}$/o) {$type_prot = 'missense'}
			#	elsif ($nom_prot =~ /fsTer/o) {$type_prot = 'frameshift';$classe = 'pathogenic';$defgen_export = 't'}
			#	elsif ($nom_prot =~ /Met1?/o) {$type_prot = 'start codon'}
			#	elsif ($nom_prot =~ /ext/o) {$type_prot = 'stop codon'}
			#	elsif ($type_adn eq 'deletion' && $nom_prot =~ /del/o) {$type_prot = 'inframe deletion'}
			#	elsif ($type_adn eq 'insertion' && $nom_prot =~ /ins/o) {$type_prot = 'inframe insertion'}
			#	elsif ($type_adn eq 'duplication' && $nom_prot =~ /ins/o) {$type_prot = 'inframe duplication'}
			#	#elsif ($nom_prot =~ /\?/o) {$type_prot = 'unknown'}
			#	else {$type_prot = 'unknown'}
			#	
			#	#replace nom_prot for variants after stop codon and before start
			#	if ($cdna =~ /c\.\*/o) {$nom_prot = 'p.(=)'}
			#	elsif ($cdna =~ /c\.-[^-\+]+/o) {$nom_prot = 'p.(=)'}
			#	
			#	if ($vv_results->{$vvkey}->{'refseqgene_context_intronic_sequence'} ne '') {
			#		$nom_ivs = (split(/:/, $vv_results->{$vvkey}->{'refseqgene_context_intronic_sequence'}))[1];
			#		$type_prot = 'NULL';
			#	}				
			#	print $nom_ivs."<br/>";
			#	
			#	
			#	#replace Ter with *
			#	if ($nom_prot =~ /Ter/o) {$nom_prot =~ s/Ter/\*/o}
			#	print $nom_prot."<br/>";
			#	print $type_prot."<br/>";
			#	
			#	#taille num, type segment + end
			#	if ($nom_g =~ /chr\w+:g\.(\d+)_(\d+)[^\d]+/o) {
			#		#>1bp event
			#		my ($start, $end) = ($1, $2);
			#		$taille = $end-$start+1;
			#		my $query = "SELECT numero, type FROM segment WHERE nom_gene[2] = '$acc_no' AND $start BETWEEN SYMMETRIC $postgre_start_g AND $postgre_end_g AND $end BETWEEN SYMMETRIC $postgre_start_g AND $postgre_end_g;";
			#		$res = $dbh->selectrow_hashref($query);
			#		if ($res) {$num_segment_end = $num_segment = $res->{'numero'};$type_segment_end = $type_segment = $res->{'type'};}
			#		else {
			#			my $strand = U2_modules::U2_subs_1::get_strand($gene, $dbh);#strand is ASC (+) or DESC (-)
			#			my $query = "SELECT numero, type FROM segment WHERE nom_gene[2] = '$acc_no' AND $start BETWEEN SYMMETRIC $postgre_start_g AND $postgre_end_g;";
			#			
			#			###if nom_c contains ? => intron
			#			
			#			$res = $dbh->selectrow_hashref($query);
			#			if ($res) {
			#				if ($strand eq 'ASC' && $cdna =~ /\?/o && $res->{'type'} ne '5UTR') {
			#					$num_segment = $res->{'numero'}-1;
			#					$type_segment = 'intron';
			#				}
			#				elsif ($strand eq 'ASC') {$num_segment = $res->{'numero'};$type_segment = $res->{'type'}}
			#				elsif ($strand eq 'DESC' && $cdna =~ /\?/o && $res->{'type'} ne '3UTR') {
			#					$num_segment_end = $res->{'numero'};
			#					$type_segment_end = 'intron';
			#				}
			#				else {$num_segment_end = $res->{'numero'};$type_segment_end = $res->{'type'};}
			#			}
			#			$query = "SELECT numero, type FROM segment WHERE nom_gene[2] = '$acc_no' AND $end BETWEEN SYMMETRIC $postgre_start_g AND $postgre_end_g;";
			#			$res = $dbh->selectrow_hashref($query);
			#			if ($res) {
			#				if ($strand eq 'ASC' && $cdna =~ /\?/o && $res->{'type'} ne '3UTR') {
			#					$num_segment_end = $res->{'numero'};
			#					$type_segment_end = 'intron';
			#				}
			#				elsif ($strand eq 'ASC') {$num_segment_end = $res->{'numero'};$type_segment_end = $res->{'type'}}
			#				elsif ($strand eq 'DESC' && $cdna =~ /\?/o && $res->{'type'} ne '5UTR') {
			#					$num_segment = $res->{'numero'}-1;
			#					$type_segment = 'intron';
			#				}
			#				else {$num_segment = $res->{'numero'};$type_segment = $res->{'type'}}
			#			}
			#			else {print 'segment error';exit;}
			#		}
			#	}
			#	elsif ($nom_g =~ /chr\w+:g\.(\d+)[^\d]+/o) {
			#		#1bp event
			#		my $pos = $1;
			#		$taille = 1;
			#		$query = "SELECT numero, type FROM segment WHERE nom_gene[2] = '$acc_no' AND $pos BETWEEN SYMMETRIC $postgre_start_g AND $postgre_end_g;";
			#		$res = $dbh->selectrow_hashref($query);
			#		if ($res) {$num_segment_end = $num_segment = $res->{'numero'};$type_segment_end = $type_segment = $res->{'type'};}
			#	}
			#	print "$num_segment-$type_segment-$num_segment_end-$type_segment_end-$taille<br/>";
			#	
			#	if ($taille > 50) {$nom_prot = 'p.?'}
			#	#print $q->td({'colspan' => '7'}, "$nom_prot-$type_prot-$gene-$true_version-");exit;
			#	#snp
			#
			#	my $snp_query = "SELECT rsid, common FROM restricted_snp WHERE ng_var = '$ng_accno:$nom_ng';";
			#	if ($nom_ng =~ /d[eu][lp]/o) {$snp_query = "SELECT rsid, common FROM restricted_snp WHERE ng_var like '$ng_accno:$nom_ng%';"}
			#	my $res_snp = $dbh->selectrow_hashref($snp_query);
			#	if ($res_snp) {$snp_id  = $res_snp->{rsid};$snp_common = $res_snp->{common};}
			#	elsif (U2_modules::U2_subs_1::test_myvariant() == 1) {
			#		my $myvariant = U2_modules::U2_subs_1::run_myvariant($nom_g, 'dbsnp.rsid', $user->getEmail());
			#		if ($myvariant && $myvariant->{'dbsnp'}->{'rsid'} ne '') {$snp_id = $myvariant->{'dbsnp'}->{'rsid'}}
			#	}
			#	
			#	my $date = U2_modules::U2_subs_1::get_date();
			#	
			#	print $snp_id."<br/>";
			#	
			#	#need to run toogows to get seq_wt and seq_mt OR use togows such as in splicing calc
			#	if ($taille < 50) {
			#		#get positions
			#		my ($pos1, $pos2) = U2_modules::U2_subs_3::get_start_end_pos($nom_g);
			#		my ($x, $y) = ($pos1 - 25, $pos2 + 25);
			#		my $client = REST::Client->new();
			#		print "http://togows.org/api/ucsc/hg19/$chr:$x-$y<br/>";
			#		#exit;
			#		$client->GET("http://togows.org/api/ucsc/hg19/chr$chr:$x-$y");
			#		
			#		#my ($i, $j) = (0, $#seq-25);
			#		
			#		
			#		if ($client->responseContent() =~ /^[ATGC]+$/o) {
			#			push my @seq, $client->responseContent();
			#			my $strand = U2_modules::U2_subs_1::get_strand($gene, $dbh);
			#			#print "--$strand--<br/>";
			#			if ($strand eq 'DESC') {
			#				my $seqrev = reverse $seq[0];
			#				$seqrev =~ tr/acgtACGT/tgcaTGCA/;
			#				$seq[0] = $seqrev;
			#			}
			#			#print $seq[0].'<br/>';
			#			my ($begin, $middle, $end) ;
			#			($begin, $middle, $end) = (substr($seq[0], 0, 25), substr($seq[0], 25, $#seq-25), substr($seq[0], $#seq-25));
			#			#print "$begin-$middle-$end<br/>";
			#			
			#			if ($cdna =~ />([ATCG])$/o) {#substitutions
			#				$seq_wt = "$begin $middle $end";
			#				$seq_mt = "$begin $1 $end";
			#			}
			#			elsif ($nom_g =~ /ins([ATGC]+)/) {
			#				my $exp;
			#				for (my $i=0;$i<$taille;$i++) {$exp.='-'}
			#				$seq_wt = "$begin $exp $end";
			#				$seq_mt = "$begin $1 $end";
			#			}
			#			elsif ($nom_g =~ /del/o) {
			#				$seq_wt = "$begin $middle $end";
			#				my $exp;
			#				for (my $i=0;$i<$taille;$i++) {$exp.='-'}
			#				$seq_mt = "$begin $exp $end";
			#			}
			#		}
			#		print "$seq_wt<br/>";
			#		print "$seq_mt<br/>";
			#	}
			#	#to get seq back - requires seq_wt
			#	if (($type_adn =~ /(deletion|insertion|duplication)/o) && ($taille < 5) && ($cdna =~ /(.+d[eu][lp])$/o)) {
			#		my $tosend = $seq_mt;
			#		if ($type_adn eq 'deletion') {$tosend = $seq_wt}								
			#		my $sequence = U2_modules::U2_subs_1::get_deleted_sequence($tosend);
			#		$cdna .= $sequence;
			#		if ($nom_ivs ne 'NULL') {$nom_ivs .= $sequence}
			#	}
			#	print "$cdna<br/>";
			#	my $insert = "INSERT INTO variant(nom, nom_gene, nom_g, nom_ng, nom_ivs, nom_prot, type_adn, type_arn, type_prot, classe, type_segment, num_segment, num_segment_end, taille, snp_id, snp_common, commentaire, seq_wt, seq_mt, type_segment_end, creation_date, referee, nom_g_38, defgen_export) VALUES ('$cdna', '{\"$gene\",\"$acc_no\"}', '$nom_g', '$nom_ng', '$nom_ivs', '$nom_prot', '$type_adn', '$type_arn', '$type_prot', '$classe', '$type_segment', '$num_segment', '$num_segment_end', '$taille', '$snp_id', '$snp_common', 'NULL', '$seq_wt', '$seq_mt', '$type_segment_end', '$date', '".$user->getName()."', '$nom_g_38', '$defgen_export');";
			#	$insert =~ s/'NULL'/NULL/og;
			#	#die $insert;
			#	print STDERR $insert;
			#	#print $q->td({'colspan' => '7'}, $insert);exit;
			#	$dbh->do($insert) or die "Variant already recorded, there must be a mistake somewhere $!";
			#	
				if ($id ne '') {									
					my $insert = "INSERT INTO variant2patient (nom_c, num_pat, id_pat, nom_gene, type_analyse, statut, allele, denovo) VALUES ('$var_final', '$number', '$id', '{\"$gene\",\"$acc_no\"}', '$technique', '$status', '$allele', '$denovo');\n";
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
			my $query = "SELECT nom_c FROM variant2patient WHERE nom_c = '$cdna' AND nom_gene[1] = '$gene' AND nom_gene[2] = '$acc_no' AND num_pat = '$number' AND id_pat = '$id' AND type_analyse = '$technique';";
			my $res = $dbh->selectrow_hashref($query);
			if (!$res->{'nom_c'}) {
				my $insert = "INSERT INTO variant2patient (nom_c, num_pat, id_pat, nom_gene, type_analyse, statut, allele, denovo) VALUES ('$cdna', '$number', '$id', '{\"$gene\", \"$acc_no\"}', '$technique', '$status', '$allele', '$denovo');";
				my $query = "SELECT classe FROM variant WHERE nom = '$cdna' AND nom_gene[1] = '$gene';";
				my $res_classe = $dbh->selectrow_hashref($query);
				$dbh->do($insert) or die "Variant already recorded for the patient, there must be a mistake somewhere $!";
				##update 05/12/2015 add allele and status should modifiy existing e.g. if allele already exists as 'unknown' post to miseq sequencing and we here add an allele 1 by Sanger, should change miseq allele
				## not relevant by definition when creating new variants above
				my $update = "UPDATE variant2patient SET statut = '$status', allele = '$allele', denovo = '$denovo' WHERE nom_c = '$cdna' AND id_pat = '$id' AND num_pat = '$number' AND nom_gene[1] = '$gene';";
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
	my $delete = "DELETE FROM variant2patient WHERE num_pat = '$number' AND id_pat = '$id' AND nom_gene[1] = '$gene' AND type_analyse = '$technique' AND nom_c = '$var';";
	$dbh->do($delete) or die "Error when deleting the analysis, there must be a mistake somewhere $!";
	#print "$var deleted";	
}


##specific subs for current script

