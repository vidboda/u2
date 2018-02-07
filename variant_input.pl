BEGIN {delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV', 'PATH'};}

use strict;
#use CGI; #in startup.pl
#use DBI;
#use AppConfig qw(:expand :argcount);
use URI::Encode qw(uri_encode uri_decode);
#use LWP::UserAgent;
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

#get params
my ($type, $nom, $num_seg, $technique);
my ($id, $number) = ('', '');
my $step = U2_modules::U2_subs_1::check_step($q);
if ($step == 1 || $q->param('sample')) {
	my ($id, $number) = U2_modules::U2_subs_1::sample2idnum(uc($q->param('sample')), $q);
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
	
	#get id for li at the end
	my $j;
	if ($q->param('j') && $q->param('j') =~ /(\d+)/o) {$j = $1}
	
	my $semaph == 0;
	
	if ($q->param('new_variant') && $q->param('new_variant') =~ /(c\.[>\w\*\-\+\?_]+)/o) {
		###OUCH need to create variant with mutalyzer
		my $cdna = $1;
		$cdna =~ tr/atgc/ATGC/;
		$cdna = lcfirst($cdna);
		
		my ($denovo, $status, $allele);
		if ($id ne '') {
			$denovo = U2_modules::U2_subs_1::check_denovo($q);
			$status = U2_modules::U2_subs_1::check_status($q);
			$allele = U2_modules::U2_subs_1::check_allele($q);
		}
		
		###1st check variant does not exist
		my $query = "SELECT nom FROM variant WHERE nom = '$cdna' AND nom_gene[1] = '$gene' AND nom_gene[2] = '$acc_no';";
		my $res = $dbh->selectrow_hashref($query);
		#print $cdna;
		if (!$res->{'nom'}) {			
			my $ng_accno;
			if ($q->param('ng_accno') &&  $q->param('ng_accno') =~ /(NG_\d+\.\d)/o) {$ng_accno = $1}
			### WE NEED cDNA ok nom_gene OK nom_g nom_ng nom_ivs nom_prot type_adn type_arn type_prot classe type_segment num_segment num_segment_end taille snp_id seq_wt seq_mt type_segment_end
			
			#1st genomic nomenclature
			#go to mutalyzer
			#test mutalyzer
			#my $mutalyzer = 0;		
			#my $ua = LWP::UserAgent->new();
			#my $request = $ua->get('http://mutalyzer.nl/2.0/services');
			#my $content = $request->content();
			#if ($content !~ /XML/o) {$mutalyzer = 1}
			## creates client object
			if (U2_modules::U2_subs_1::test_mutalyzer() == 1) {
				### old way to connect to mutalyzer deprecated September 2014
				#my $soap = SOAP::Lite->new(proxy => 'http://mutalyzer.nl/2.0/services');
				#$soap->defaul_ns('urn:https://mutalyzer.nl/services/?wsdl');
				my $soap = SOAP::Lite->uri('http://mutalyzer.nl/2.0/services')->proxy('https://mutalyzer.nl/services/?wsdl');
				
				my ($call, $http_mutalyzer);
				
				my ($nom_g, $nom_ng, $nom_ivs, $nom_prot, $seq_wt, $seq_mt, $type_adn, $type_arn, $type_prot, $type_segment, $type_segment_end, $num_segment, $num_segment_end, $taille, $snp_id, $snp_common, $classe, $variant);
				($nom_prot, $nom_ivs, $type_arn, $classe) = ('NULL', 'NULL', 'neutral', 'unknown');
				#get NM_ acc version for mutalyzer
				my $query = "SELECT acc_version, mutalyzer_version, mutalyzer_acc FROM gene where nom[2] = '$acc_no';";
				my $res = $dbh->selectrow_hashref($query);
				my ($acc_ver, $mutalyzer_version, $mutalyzer_acc) = ($res->{'acc_version'}, $res->{'mutalyzer_version'}, $res->{'mutalyzer_acc'});
				
				##run numberConversion() webservice
				my $semaph_error = 0;
				
				#we need to get rid of nom/num for segments and intronic variants, e.g. in cdh23 if asked: c.IVS45+1G>A in fact we want IVS46+1G>A
				my $mutalyzer_name = $cdna;
				if ($num_seg ne $nom && $cdna =~ /IVS/) {
					$mutalyzer_name =~ s/$nom/$num_seg/g;
				}
				
				#print "$acc_no.$acc_ver:$mutalyzer_name";
				$call = $soap->call('numberConversion',
						SOAP::Data->name('build')->value('hg19'),
						SOAP::Data->name('variant')->value("$acc_no.$acc_ver:$mutalyzer_name"),
						SOAP::Data->name('gene')->value($gene));

				foreach ($call->result()->{'string'}) {
					my $tab_ref;
					if (ref($_) eq 'ARRAY') {$tab_ref = $_}
					else {$tab_ref->[0] = $_}
					my $not_done = $q->start_strong()."WARNING: ";
					#if (Dumper($_) =~ /\[/og) { ## multiple results: tab ref
					#	$tab_ref = $_;
					#}
					#else {
					#	$tab_ref->[0] = $_;	
					#}
					if ($_) {					
						foreach (@{$tab_ref}) {
							#print $_, "\n";
							#parse genomic
							/^NC_0+(\w+)\.\d+:(g\.\d+.+)$/o;
							my ($chr_tmp, $g_var) = ($1, $2);
							if ($chr_tmp == 23) {$chr_tmp = 'X'}
							elsif ($chr_tmp == 24) {$chr_tmp = 'Y'}
							$nom_g = "chr$chr_tmp:$g_var";
							#print $nom_g;
							#ok we have cDNA and genomic nomenclature
							#so before mutalyzer, we can fix a number of params
							#taille num, type segment + end
							if ($nom_g =~ /chr\w+:g\.(\d+)_(\d+)[^\d]+/o) {
								#>1bp event
								my ($start, $end) = ($1, $2);
								$taille = $end-$start+1;
								my $query = "SELECT numero, type FROM segment WHERE nom_gene[2] = '$acc_no' AND $start BETWEEN SYMMETRIC $postgre_start_g AND $postgre_end_g AND $end BETWEEN SYMMETRIC $postgre_start_g AND $postgre_end_g;";
								$res = $dbh->selectrow_hashref($query);
								if ($res) {$num_segment_end = $num_segment = $res->{'numero'};$type_segment_end = $type_segment = $res->{'type'};}
								else {
									my $strand = U2_modules::U2_subs_1::get_strand($gene, $dbh);#strand is ASC (+) or DESC (-)
									my $query = "SELECT numero, type FROM segment WHERE nom_gene[2] = '$acc_no' AND $start BETWEEN SYMMETRIC $postgre_start_g AND $postgre_end_g;";
									
									###if nom_c contains ? => intron
									
									$res = $dbh->selectrow_hashref($query);
									if ($res) {
										if ($strand eq 'ASC' && $cdna =~ /\?/o && $res->{'type'} ne '5UTR') {
											$num_segment = $res->{'numero'}-1;
											$type_segment = 'intron';
										}
										elsif ($strand eq 'ASC') {$num_segment = $res->{'numero'};$type_segment = $res->{'type'}}
										elsif ($strand eq 'DESC' && $cdna =~ /\?/o && $res->{'type'} ne '3UTR') {
											$num_segment_end = $res->{'numero'};
											$type_segment_end = 'intron';
										}
										else {$num_segment_end = $res->{'numero'};$type_segment_end = $res->{'type'};}
									}
									$query = "SELECT numero, type FROM segment WHERE nom_gene[2] = '$acc_no' AND $end BETWEEN SYMMETRIC $postgre_start_g AND $postgre_end_g;";
									$res = $dbh->selectrow_hashref($query);
									if ($res) {
										if ($strand eq 'ASC' && $cdna =~ /\?/o && $res->{'type'} ne '3UTR') {
											$num_segment_end = $res->{'numero'};
											$type_segment_end = 'intron';
										}
										elsif ($strand eq 'ASC') {$num_segment_end = $res->{'numero'};$type_segment_end = $res->{'type'}}
										elsif ($strand eq 'DESC' && $cdna =~ /\?/o && $res->{'type'} ne '5UTR') {
											$num_segment = $res->{'numero'}-1;
											$type_segment = 'intron';
										}
										else {$num_segment = $res->{'numero'};$type_segment = $res->{'type'}}
									}
									else {print 'segment error';exit;}
								}
							}
							elsif ($nom_g =~ /chr\w+:g\.(\d+)[^\d]+/o) {
								#1bp event
								my $pos = $1;
								$taille = 1;
								$query = "SELECT numero, type FROM segment WHERE nom_gene[2] = '$acc_no' AND $pos BETWEEN SYMMETRIC $postgre_start_g AND $postgre_end_g;";
								$res = $dbh->selectrow_hashref($query);
								if ($res) {$num_segment_end = $num_segment = $res->{'numero'};$type_segment_end = $type_segment = $res->{'type'};}
							}
							
							
							### WE STILL NEED nom_ng nom_ivs nom_prot type_adn type_arn type_prot classe snp_id seq_wt seq_mt
		
							##
							## Now we can run Mutalyzer...
							##
							
							$call = U2_modules::U2_subs_1::run_mutalyzer($soap, $ng_accno, $gene, $mutalyzer_name, $mutalyzer_version, $mutalyzer_acc);
							
														
							#if ($gene ne 'USH1C') {
							#	$call = $soap->call('runMutalyzer', SOAP::Data->name('variant')->value("$ng_accno($gene):$mutalyzer_name"))
							#}
							#else {
							#	$call = $soap->call('runMutalyzer', SOAP::Data->name('variant')->value("$ng_accno(".$gene."_v002):$mutalyzer_name"))
							#}
							
							if ($call->fault()) {
								#print $q->span("$ng_accno(".$gene."_v002):$cdna");
								my $danger_text = $q->start_strong().$q->span("WARNING: Sorry, mutalyzer runMutalyzer method failed, I cannot create any variant, please report.").$q->end_strong();
								print U2_modules::U2_subs_2::danger_panel($danger_text, $q);
								exit;
							}
							
							
							##10/07/2015
							##add possibility to use mutalyzer identifier (i.e. for RPGR)
							my $gid = 'NG';
							if ($mutalyzer_acc && $mutalyzer_acc ne '') {$gid = '[NU][GD]'}
							
							
							#die $call->faultstring() if ($call->fault());
							## Deal with warnings and errors
							## data types will be different depending on the number of results
							## we inelegantly use Data::Dumper to check
							
							my (@errors, $stop);
							
							#print "\n\nrunMutalyzer\n\n", $call->result->{'summary'}, "\n";
													
							my $hgvs = 0;
							
							#my $tolerated_errors = {
							#	'UNKNOWNOFFSET'	=> '1',
							#	'WOVERSPLICE'	=> '1',
							#	'DELSPLICE'	=> '1',
							#};
							
							if ($call->result->{'messages'}) {	
								foreach ($call->result->{'messages'}->{'SoapMessage'}) {
									my $tab_ref;
									if (ref($_) eq 'ARRAY') {$tab_ref = $_}
									else {$tab_ref->[0] = $_}

									foreach (@{$tab_ref}) {
										#print "\nMessage: ", $_->{'message'},"\n";
										if ($_->{'message'} =~ /HGVS/o && $cdna !~ /c\.\d+-\?_\d+\+?\w+/o) {$stop = 1;$not_done .= "HGVS error $cdna $type $nom";last;}
										elsif ($_->{'message'} =~ /identical/o) {$stop = 1;$not_done .= "Identical variant to reference $cdna $type $nom";last;}
										elsif ($_->{'message'} =~ /Position.+range/o) {$stop = 1;$not_done .= "out of range $cdna $type $nom";next;}
										elsif ($_->{'message'} =~ /position.+instead/o) {$stop = 1;$not_done .= "bad wild type nucleotide $cdna $type $nom";last;}
										if ($_->{'errorcode'}) {
											#deal with tolerated error codes
											#if ($tolerated_errors->{$_} == 1) {
											#	$call->result->{'errors'} == 0
											#}
											#else {
											#	$call->result->{'errors'} == 1;
											#	push @errors, $_
											#}
											push @errors, $_ ## if you want to deal with error and/or warning codes
										}
									}	
								}
							}
							foreach(@errors) {foreach my $key (keys %{$_}) {$not_done .= $key.$_->{$key}}}
							if ($call->result->{'errors'} == 0 && $stop == 0) {
							#for PCDH15 uncomment following
							#if ($stop == 0) {
								## let's go
								## IVS name & type_arn
								if ($type_segment eq 'intron') {
									#my $moins = $num_segment + 1;
									$query = "SELECT nom FROM segment WHERE nom_gene[2] = '$acc_no' AND numero = '$num_segment';";
									$res = $dbh->selectrow_hashref($query);
									my $nom_segment = $res->{'nom'};
									$query = "SELECT nom FROM segment WHERE nom_gene[2] = '$acc_no' AND numero = '$num_segment_end';";
									$res = $dbh->selectrow_hashref($query);
									my $nom_segment_end = $res->{'nom'};
									
									if ($cdna =~ /c\.(\d+[\+-].+_\d+[\+-].+)/o){$nom_ivs = $1;$nom_ivs =~ s/\d+([\+-].+)_\d+([\+-].+)/IVS$nom_segment$1_IVS$nom_segment_end$2/og;}
									elsif ($cdna =~ /c\.(\d+[\+-][^\+-]+)/o) {$nom_ivs = $1;$nom_ivs =~ s/\d+([\+-][^\+-]+)/IVS$nom_segment$1/og;}
									elsif ($cdna =~ /c\.(IVS.+)/o) {$nom_ivs = $1}
									if ($nom_ivs =~ /IVS\d+[\+-][12][^\d].+/) {$type_arn = 'altered';$classe = 'pathogenic';$nom_prot = 'p.(?)';$type_prot = 'NULL';}
								}	
								## variant sequence
								if ($call->result->{'rawVariants'}) {
									foreach ($call->result->{'rawVariants'}->{'RawVariant'}) {
										#print "\nDescription:\n",  $_->{'description'}, "\n";
										my @seq = split("\n", $_->{'visualisation'});
										$seq_wt = $seq[0];
										$seq_mt = $seq[1];
										#$seq_wt =~ /[ATGC]\s([ATCG-]+)\s[ATGC]/o;
										#$taille = length($1);								
										#print "\nVisualisation:\n",  $_->{'visualisation'}, "\n";	
									}
								}
								## Genomic description
								#print "\nGenomic description: ", $call->result->{'genomicDescription'}, "\n";
								$call->result->{'genomicDescription'} =~ /($gid)_\d+\.?\d:(g\..+)/og;
								$nom_ng = $2;
								if ($nom_ng =~ />/o) {$type_adn = 'substitution'}
								elsif ($nom_ng =~ /delins/o) {$type_adn = 'indel'}
								elsif ($nom_ng =~ /ins/o) {$type_adn = 'insertion'}
								elsif ($nom_ng =~ /del/o) {$type_adn = 'deletion'}
								elsif ($nom_ng =~ /dup/o) {$type_adn = 'duplication'}
								
								
								
								#correct mutalyzer which places e.g. [16bp] instead of sequence
								if ($taille > 15) {
									
									if ($nom_g =~ /.+[di][nu][sp]$/) {
										if ($seq_mt =~ /^[ATGC]+\s[ATCG]+\s[bp\[\d\]]+\s[ATCG]+\s[ATCG]+$/o) {$seq_mt =~ s/^([ATGC]+\s[ATCG]+\s)[bp\[\d\]]+(\s[ATCG]+\s[ATCG]+)$/$1- -$2/}
									}
									elsif ($nom_g =~ /.+del$/) {
										#TTAATGAAATACCATTAAGAGGAAG AATACT [23bp] CTATAT ATTTCTACACTTTATATATATAAAC
										if ($seq_wt =~ /^[ATGC]+\s[ATCG]+\s[bp\[\d\]]+\s[ATCG]+\s[ATCG]+$/o) {$seq_wt =~ s/^([ATGC]+\s[ATCG]+\s)[bp\[\d\]]+(\s[ATCG]+\s[ATCG]+)$/$1- -$2/}
										#print $q->start_Tr(), $q->td({'colspan' => '7'}, "-$seq_wt-"), $q->end_Tr();;exit;
									}
								}
								if ($taille > 50) {
									$seq_wt = 'NULL';
									$seq_mt = 'NULL';
									$nom_ng =~ s/\(//og;
									$nom_ng =~ s/\)//og;
		  
								}
								#print $q->start_Tr(), $q->td({'colspan' => '7'}, "-$seq_wt-"), $q->end_Tr();;exit;
								
								## Transcript description (submission) get version of isoform
								my $true_version = "";
								if ($call->result->{'transcriptDescriptions'}) {
									foreach ($call->result->{'transcriptDescriptions'}->{'string'}) {
										my $tosearch = $gene."_v";
										my $tab_ref;
										if (ref($_) eq 'ARRAY') {$tab_ref = $_}
										else {$tab_ref->[0] = $_}
										#my $gene_ver = '_v001';
										#if ($gene eq 'USH1C') {$gene_ver = '_v002'}										
										#if (Dumper($_) =~ /\[/og) { ## multiple results: tab ref
										foreach(@{$tab_ref}) {
											#BUG corrected 03/25/2015
											#when mutliple genes on same NG, AND
											#last nom involves a "n."
											#then true_version was reset to uninitialize
											#if added
											#NOTE this part of code slightly differs from import_illumina but basically does the same
											#OK it's because here intronic variants can be submitted as IVS17+2C>T, etc, which is not the case in import_illumina
											#see test_mutalyzer_pde6a.pl on 158 for details
											if (/($gid)_\d+\.?\d\((\w+)\):(c\..+)/) {
												my ($version, $temp_var);
												($version, $temp_var) = ($2, $3);
												$temp_var =~ s/\?/\\?/og;
												if ($cdna =~ /^$temp_var/) {#for exonic variants
													$temp_var =~ s/\\//og;
													$variant = $temp_var;
													$version =~ /$tosearch(\d{3})/;
													$true_version = $1;
												}
												elsif ($version =~ /$gene$mutalyzer_version/) {#for intronic variant
													$temp_var =~ s/\\//og;
													$variant = $temp_var;
												}
											}
											#$_ =~ /NG_\d+\.\d\((\w+)\):(c\..+)/o;
											#my ($version, $temp_var);
											#($version, $temp_var) = ($1, $2);
											#if ($cdna =~ /$temp_var/) {#for exonic variants
											#	$variant = $temp_var;
											#	$version =~ /$tosearch(\d{3})/;
											#	$true_version = $1;
											#}
											#elsif ($version =~ /$gene$gene_ver/) {#for intronic variants
											#elsif ($version =~ /$gene$mutalyzer_version/) {#for intronic variant
											#	$variant = $temp_var;
											#}
										}
										#}
										#else {
										#	$_ =~ /NG_\d+\.\d\((\w+)\):(c\..+)/o;
										#	my $version;
										#	($version, $variant) = ($1, $2);
										#	if ($cdna =~ /$variant/) {#for exonic variants
										#		$version =~ /$tosearch(\d{3})/;
										#		$true_version = $1;
										#	}
										#}
									}
								}
								## Protein description
								if ($call->result->{'proteinDescriptions'} && $nom_prot eq 'NULL') {
									foreach ($call->result->{'proteinDescriptions'}->{'string'}) {
										my $tosearch = $gene."_i";
										my $tab_ref;
										if (ref($_) eq 'ARRAY') {$tab_ref = $_}
										else {$tab_ref->[0] = $_}
										#if (Dumper($_) =~ /\[/og) { ## multiple results: tab ref
										foreach(@{$tab_ref}) {
											if ($_ =~ /$tosearch$true_version\):(p\..+)/) {$nom_prot = $1}
										}
										#}
										#else {
										#	if ($_ =~ /$tosearch$true_version\):(p\..+)/) {$nom_prot = $1}
										#}
									}
									if ($nom_prot ne 'NULL') {
										if ($nom_prot =~ /fs/o) {$type_prot = 'frameshift';$classe = 'pathogenic';}
										elsif ($nom_prot =~ /\*/o) {$type_prot = 'nonsense';$classe = 'pathogenic';}
										elsif ($nom_prot =~ /del/o) {$type_prot = 'inframe deletion';}
										elsif ($nom_prot =~ /ins/o) {$type_prot = 'inframe insertion';}
										elsif ($nom_prot =~ /dup/o) {$type_prot = 'inframe duplication';}
										elsif ($nom_prot =~ /=/o && $type_segment eq 'exon') {$type_prot = 'silent'}
										elsif ($nom_prot =~ /=/o && $type_segment ne 'exon') {$type_prot = 'NULL'}
										elsif ($nom_prot =~ /[^\\^?^=]/o) {$type_prot = 'missense'}
									}
									else {$nom_prot = 'p.(=)';$type_prot = 'NULL';}
								}
								if ($taille > 50) {$nom_prot = 'p.?'}
								
								#snp
								($snp_id, $snp_common) = ('NULL', 'NULL');
								#my $sign = '=';
								#if ($variant =~ /(del|dup)/) {$sign = '~'}
								
								my $snp_query = "SELECT rsid, common FROM restricted_snp WHERE ng_var = '$ng_accno:$nom_ng';";
								if ($nom_ng =~ /d[eu][lp]/o) {$snp_query = "SELECT rsid, common FROM restricted_snp WHERE ng_var like '$ng_accno:$nom_ng%';"}
								my $res_snp = $dbh->selectrow_hashref($snp_query);
								if ($res_snp) {$snp_id  = $res_snp->{rsid};$snp_common = $res_snp->{common};}
								
								my $date = U2_modules::U2_subs_1::get_date();
								
								if (($type_adn =~ /(deletion|insertion|duplication)/o) && ($taille < 5) && ($nom =~ /(.+d[eu][lp])$/o)) {
								#if (($type_adn =~ /(deletion|insertion|duplication)/o) && ($taille < 5)) {
									my $tosend = $seq_mt;
									if ($type_adn eq 'deletion') {$tosend = $seq_wt}								
									my $sequence = U2_modules::U2_subs_1::get_deleted_sequence($tosend);
									$variant .= $sequence;
									if ($nom_ivs ne 'NULL') {$nom_ivs .= $sequence}
								}
								
								
								## let's go
											
								my $insert = "INSERT INTO variant(nom, nom_gene, nom_g, nom_ng, nom_ivs, nom_prot, type_adn, type_arn, type_prot, classe, type_segment, num_segment, num_segment_end, taille, snp_id, snp_common, commentaire, seq_wt, seq_mt, type_segment_end, creation_date, referee) VALUES ('$variant', '{\"$gene\",\"$acc_no\"}', '$nom_g', '$nom_ng', '$nom_ivs', '$nom_prot', '$type_adn', '$type_arn', '$type_prot', '$classe', '$type_segment', '$num_segment', '$num_segment_end', '$taille', '$snp_id', '$snp_common', 'NULL', '$seq_wt', '$seq_mt', '$type_segment_end', '$date', '".$user->getName()."');";
								$insert =~ s/'NULL'/NULL/og;
								#print $insert;exit;
								$dbh->do($insert) or die "Variant already recorded, there must be a mistake somewhere $!";
								
								if ($id ne '') {
									$insert = "INSERT INTO variant2patient (nom_c, num_pat, id_pat, nom_gene, type_analyse, statut, allele, denovo) VALUES ('$variant', '$number', '$id', '{\"$gene\",\"$acc_no\"}', '$technique', '$status', '$allele', '$denovo');\n";
								
									#print $insert;
									$dbh->do($insert) or die "Variant already recorded for the patient, there must be a mistake somewhere $!";
								}
							}
							else {
								$semaph_error = 1;
								$not_done .= $q->end_strong();
								$http_mutalyzer = "https://mutalyzer.nl/check?name=$ng_accno($gene$mutalyzer_version):$cdna&standalone=1";
								#if ($gene eq 'USH1C') {$http_mutalyzer = "https://mutalyzer.nl/check?name=$ng_accno(".$gene."_v002):$cdna&standalone=1"}
								$not_done .= $q->span("&nbsp;&nbsp").$q->a({'href' => $http_mutalyzer, 'target' => '_blank'}, 'Launch Mutalyzer');
								if ($id ne '') {print $q->start_Tr(), $q->td({'colspan' => '7'}, U2_modules::U2_subs_2::danger_panel($not_done, $q)), $q->end_Tr()}
								else {print U2_modules::U2_subs_2::danger_panel($not_done, $q)}
							}
						}
					}
					else {
						$semaph_error = 1;
						$not_done .= "HGVS ERROR for $cdna".$q->end_strong();
						$http_mutalyzer = "https://mutalyzer.nl/check?name=$ng_accno($gene$mutalyzer_version):$cdna&standalone=1";
						#if ($gene eq 'USH1C') {$http_mutalyzer = "https://mutalyzer.nl/check?name=$ng_accno(".$gene."_v002):$cdna&standalone=1"}
						$not_done .= $q->span("&nbsp;&nbsp").$q->a({'href' => $http_mutalyzer, 'target' => '_blank'}, 'Launch Mutalyzer');
						if ($id ne '') {print $q->start_Tr(), $q->td({'colspan' => '7'}, $not_done), $q->end_Tr()}
						else {print U2_modules::U2_subs_2::danger_panel($not_done, $q)}
						
					}				
				}
				#print "NEW VARIANT $variant, $status, allele: $allele";
				if ($semaph_error == 0) {
					#print $q->span("Added: ".ucfirst($type_segment)." $nom: $variant, $status, allele: $allele, class: ").$q->span({'style' => 'color:#969696;'}, "unknown&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;").$q->img({'src' => $HTDOCS_PATH.'data/img/buttons/delete.png', 'class' => 'pointer text_img', 'width' => '15', height => '15', 'onclick' => "delete_var('$id$number', '$gene', '$technique', '".uri_encode($variant)."', 'v$j');"});
					if ($id ne '') {
						if ($denovo eq 'true') {$denovo = '_denovo'}
						else {$denovo = ''}
						print $q->td("Added: ".ucfirst($type_segment)." ".$nom).
							$q->td($variant).$q->td({'id' => "wstatus$j"}, $status).
							$q->td({'id' => "wallele$j"}, $allele.$denovo).
							$q->td({'style' => "color:".U2_modules::U2_subs_1::color_by_classe($classe, $dbh).";"}, $classe).
							$q->start_td().
								$q->img({'src' => $HTDOCS_PATH.'data/img/buttons/delete.png', 'class' => 'pointer text_img', 'width' => '15', height => '15', 'onclick' => "delete_var('$id$number', '$gene', '$technique', '".uri_encode($variant)."', 'v$j');"}).
							$q->end_td().
							$q->start_td().
								$q->a({'href' => 'javascript:;', 'title' => 'click to modifiy status and/or alleles', 'onclick' => "createFormStatus('".uri_encode($variant)."', '$gene', '$id$number', '$technique', 'v$j', '$status', '$allele');"}, 'Modify').
							$q->end_td();
					}
					else {
						my $text = $q->span('Newly created variant: ').$q->a({'href' => "variant.pl?gene=$gene&amp;accession=$acc_no&nom_c=".uri_encode($variant)}, $variant);
						print U2_modules::U2_subs_2::info_panel($text, $q);
					}
					#print $q->span("Added: ".ucfirst($type_segment)." $nom: $variant, ").$q->span({'id' => "w$j"}, "$status, allele: $allele, class: ").$q->span({'style' => "color:".U2_modules::U2_subs_1::color_by_classe($classe, $dbh).";"}, "$classe&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;").$q->img({'src' => $HTDOCS_PATH.'data/img/buttons/delete.png', 'class' => 'pointer text_img', 'width' => '15', height => '15', 'onclick' => "delete_var('$id$number', '$gene', '$technique', '".uri_encode($variant)."', 'v$j');"}).$q->span("&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;").$q->start_a({'href' => 'javascript:;', 'title' => 'click to modifiy status and/or alleles', 'onclick' => "createFormStatus('".uri_encode($variant)."', '$gene', '$id$number', '$technique', 'v$j', '$status', '$allele');\$(\"#dialog-form-status\").dialog(\"open\");"}).$q->span({'class' => 'list'}, "Status&nbsp;").$q->img({'src' => $HTDOCS_PATH.'data/img/link_small.png', 'border' => '0', 'width' =>'15'}).$q->end_a();
				}
			}
			else {
				my $danger_text = $q->start_strong().$q->span("WARNING: Sorry, mutalyzer is not available, I cannot create any variant today.").$q->end_strong();
				print U2_modules::U2_subs_2::danger_panel($danger_text, $q);
			}
		}
		else {
			$semaph = 1;
		}
	}
	if (($q->param('existing_variant') && $q->param('existing_variant') =~ /c\..+/o) || ($semaph == 1)) {
		my $cdna = U2_modules::U2_subs_1::check_nom_c($q, $dbh);
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
			#print $q->span("Added: ".ucfirst($type)." $nom: $cdna, $status, allele: $allele, class: ").$q->span({'style' => "color:".U2_modules::U2_subs_1::color_by_classe($res_classe->{'classe'}, $dbh).";"}, $res_classe->{'classe'}."&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;").$q->img({'src' => $HTDOCS_PATH.'data/img/buttons/delete.png', 'class' => 'pointer text_img', 'width' => '15', height => '15', 'onclick' => "delete_var('$id$number', '$gene', '$technique', '".uri_encode($cdna)."', 'v$j');"});
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
			#print $q->span("Added: ".ucfirst($type)." $nom: $cdna, ").$q->span({'id' => "w$j"}, "$status, allele: $allele, class: ").$q->span({'style' => "color:".U2_modules::U2_subs_1::color_by_classe($res_classe->{'classe'}, $dbh).";"}, $res_classe->{'classe'}."&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;").$q->img({'src' => $HTDOCS_PATH.'data/img/buttons/delete.png', 'class' => 'pointer text_img', 'width' => '15', height => '15', 'onclick' => "delete_var('$id$number', '$gene', '$technique', '".uri_encode($cdna)."', 'v$j');"}).$q->span("&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;").$q->start_a({'href' => 'javascript:;', 'title' => 'click to modifiy status and/or alleles', 'onclick' => "createFormStatus('".uri_encode($cdna)."', '$gene', '$id$number', '$technique', 'v$j', '$status', '$allele');"}).$q->span({'class' => 'list'}, "Status&nbsp;").$q->img({'src' => $HTDOCS_PATH.'data/img/link_small.png', 'border' => '0', 'width' =>'15'}).$q->end_a();
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

