package U2_modules::U2_subs_3;

use strict;
use warnings;
use Data::Dumper;
use U2_modules::U2_init_1;
use U2_modules::U2_subs_1;
use REST::Client;
use JSON;

#hg38 transition variable for postgresql 'start_g' segment field
my ($postgre_start_g, $postgre_end_g) = ('start_g', 'end_g');  #hg19 style
my $config_file = U2_modules::U2_init_1->getConfFile();
my $config = U2_modules::U2_init_1->initConfig();
$config->file($config_file);# or die $!;
my $ANALYSIS_ILLUMINA_PG_REGEXP = $config->ANALYSIS_ILLUMINA_PG_REGEXP();
my $ABSOLUTE_HTDOCS_PATH = $config->ABSOLUTE_HTDOCS_PATH();
our $HG19TOHG38CHAIN = 'hg19ToHg38.over.chain.gz';
our $HG38TOHG19CHAIN = 'hg38ToHg19.over.chain.gz';

sub liftover {
	#my ($pos, $chr, $path, $way) = @_;
	my ($pos, $chr, $path, $chain) = @_;
	chop($path);
	#way =19238 or 38219
	#liftover.py is 0-based
	$pos = $pos-1;
	if ($chr =~ /chr([\dXYM]{1,2})/o) {$chr = $1}
	#my $ret =  or die "hg38 gene mutalyzer gene only and $!";
	#print STDERR "/usr/local/bin/python $path/liftover$way.py chr$chr $pos";
	#my ($chr_tmp2, $s) = split(/,/, `/usr/local/bin/python $path/liftover$way.py "chr$chr" $pos`);
	my ($chr_tmp2, $s) = split(/,/, `/usr/local/bin/python $path/liftover.py $path/$chain "chr$chr" $pos`);
	$s =~ s/\)//g;	
	$s =~ s/ //g;
	$s =~ s/'//g;
	if ($s =~ /^\d+$/o) {return $s+1}
	else {return 'f'}
}

sub check_nm_number_conversion {
	my ($call, $dbh, $nm_variant, $id, $number, $genomic_var, $analysis, $status, $var_dp, $var_vf, $var_filter) = @_;
	my ($acc, $ver, $nom, $tmp, $res3) = ('', '', '', '', '');
	if (!$call || $call->result() eq '') {return ('', '', '', '0', '', '')}
	#elsif ($call->result() eq '') {}
	#if ($call == 1) {print STDERR "$nm_variant-$genomic_var-$var_filter"}
	#print STDERR "$call-\n";
	foreach ($call->result()->{'string'}) {
		my $tab_ref;
		if (ref($_) eq 'ARRAY') {$tab_ref = $_}		
		else {$tab_ref->[0] = $_}
		POSCONV: foreach (@{$tab_ref}) {
			if (/(NM_\d+)\.(\d):([cn]\..+)/og) {
				($acc, $ver, $nom) = ($1, $2, $3);
				my $query = "SELECT nom[1] as gene_name, acc_g, mutalyzer_acc, mutalyzer_version FROM gene WHERE nom[2] = '$acc' AND main = 't' AND acc_version = '$ver';";
				$res3 = $dbh->selectrow_hashref($query);
				if (!$res3) {next POSCONV}#try again
				else {
					#we've got THE good one
					$nm_variant = 1;
					last POSCONV;
				}
			}
			elsif (/NR_.+/) {#deal with NR for NR, a number conversion should be enough - same for chrM
				$tmp .= "MANUAL NR_variant\t$id$number\t$genomic_var\t$analysis\t'$status', 'unknown', '$var_dp', '$var_vf', '$var_filter');\n";
			}
			elsif (/NC_012920.+/) {
				$tmp .= "MANUAL chrM_variant\t$id$number\t$genomic_var\t$analysis\t'$status', 'unknown', '$var_dp', '$var_vf', '$var_filter');\n";
			}
		}
	}
	return ($acc, $ver, $nom, $nm_variant, $tmp, $res3);
}


sub insert_variant {
	my ($list, $vf_tag, $dbh, $instrument, $number, $id, $analysis, $intervals, $soap, $date, $user) = @_;
	my ($var_chr, $var_pos, $rs_id, $var_ref, $var_alt, $null, $var_filter) = (shift(@{$list}), shift(@{$list}), shift(@{$list}), shift(@{$list}), shift(@{$list}), shift(@{$list}), shift(@{$list}));
	my ($var_dp, $var_vf);
	my @format_list = split(/:/, pop(@{$list}));
		
	#compute vf_index
	my @label_list = split(/:/, pop(@{$list}));
	my $label_count = 0;
	my ($vf_index, $dp_index, $ad_index) = (7, 2, 3);#LRM values
	my ($dp_tag, $ad_tag) = ('DP', 'AD');
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
	
	##we could query each variant but takes some time
	#my $query = "SELECT b.nom, a.nom[1] as gene FROM gene a, segment b WHERE a.nom = b.nom_gene AND a.chr = '$var_chr' AND $var_pos BETWEEN SYMMETRIC b.$postgre_start_g AND b.$postgre_end_g;";
	#my $sth = $dbh->prepare($query);
	#my $res = $sth->execute();
	#print "$query<br/>";
	#if ($res ne '0E0') {
	#	while (my $result = $sth->fetchrow_hashref()) {
	#		print "$var_chr-$var_pos-$result->{'gene'}-$result->{'nom'}<br/>"
	#	}
	#}
	#else {
	#	print "$var_chr-$var_pos-not in ushvam2<br/>"
	#}
	
	my $interest = 0;
	foreach my $key (keys %{$intervals}) {
		$key =~ /(\d+)-(\d+)/o;
		if ($var_pos >= $1 && $var_pos <= $2) {#good interval, check good chr			
			if ($var_chr eq $intervals->{$key}) {$interest = 1;last;}
		}
	}
	if ($interest == 0) {
		if ($analysis =~ /Min?i?Seq-\d+/o) {
			return "MANUAL OUT OF U2 ROI chr$var_chr $var_pos\n"
		}
		else {
			return 2
		}
	}#we deal only with variants located in genes u2 knows about
	#deal with the status case
	my ($status, $allele) = ('heterozygous', 'unknown');
	if ($var_vf >= 0.8) {($status, $allele) = ('homozygous', 'both')}
	if ($instrument eq 'miniseq' && $var_vf < 0.2) {###TO BE REMOVED IF LRM CORRECTED
		if ($var_filter eq 'PASS') {$var_filter = 'LowVariantFreq'}
		else {$var_filter .= ';LowVariantFreq'}
		if ($list->[0] =~ /HRun=(\d+);/o) {
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
	#elsif ($var_chr eq 'M') {($status, $allele) = ('hemizygous', '2')}
	
	my $genomic_var = &build_hgvs_from_illumina($var_chr, $var_pos, $var_ref, $var_alt);
	#print "$genomic_var<br/>";
	my $first_genomic_var = $genomic_var;
	my $known_bad_variant = 0;
	#check if variants known for bad annotation already exists
	#if ($first_genomic_var =~ /(del|ins)/o) {
	my $query_gs = "SELECT u2_name FROM gs2variant WHERE gs_name = '$first_genomic_var' AND (reason LIKE 'MiSeq_%' OR reason LIKE 'inv_nt');";
	my $res_gs = $dbh->selectrow_hashref($query_gs);
	if ($res_gs) {$known_bad_variant = 1;$genomic_var = $res_gs->{'u2_name'}}
	
	my $insert = &direct_submission($genomic_var, $number, $id, $analysis, $status, $allele, $var_dp, $var_vf, $var_filter, $dbh);
	if ($insert ne '') {
		#print "$insert<br/>";
		#################UNCOMMENT WHEN READY
		$dbh->do($insert);		
		return 1;
	}
	#still here? we try to invert wt & mut
	#if ($genomic_var =~ /(chr[\dXYM]+:g\..+\d+)([ATGC])>([ATCG])/o) {
	if ($genomic_var =~ /(chr$U2_modules::U2_subs_1::CHR_REGEXP:g\..+\d+)([ATGC])>([ATCG])/o) {
		my $inv_genomic_var = $1.$3.">".$2;
		$insert = &direct_submission($inv_genomic_var, $number, $id, $analysis, $status, $allele, $var_dp, $var_vf, $var_filter, $dbh);
		if ($insert ne '') {
			#print "INV-$insert<br/>";
			#################UNCOMMENT WHEN READY
			$dbh->do($insert);
			return 1;
		}
	}
	#allright, new variant
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
	##########REMOVE IF POSSIBLE
	#my ($manual, $not_inserted, $general, $mutalyzer_no_answer, $sample_end, $to_follow) = ('', '', '', '', '', '');#$manual will contain variants that cannot be delt automatically i.e. PTPRQ (at least in hg19), NR_, non mappable; $notinserted variants wt homozygous, $general global data for final email, $sample_end last treated patient for redirection $to_follow is to get info on certain variants that were buggy
	#my $nm_variant = 0;
	#my ($acc, $ver, $nom, $tmp, $res3);
	my $tmp;
	if ($genomic_var !~ />/) {
		if ($genomic_var =~ /chr12:g\.(\d+)/o) {
			if ($1 > 80838126 && $1 < 81072802) {#hg19 coordinates#PTPRQ put in manual list
				return "MANUAL PTPRQ\t$id$number\t$genomic_var\t$analysis\t'$status', 'unknown', '$var_dp', '$var_vf', '$var_filter');\n"
			}
		}
		#HERE if we want to return chrM values
		##run numberConversion() webservice
		my $call = $soap->call('numberConversion',
				SOAP::Data->name('build')->value('hg19'),
				SOAP::Data->name('variant')->value($genomic_var));
		#if (!$call->result()) {return "MANUAL MUTALYZER FAULT\t$id$number\t$genomic_var\t$analysis\t'$status', 'unknown', '$var_dp', '$var_vf', '$var_filter'); $var_chr $var_pos in VCF"}
		
		#try ultimate fix for hg19 => we check for exact NM+version ; if not found, we liftover genomic positions to hg38 then second number conversion round and look for exact NM+version; then we move on
		my $nm_variant = 0;
		my ($acc, $ver, $nom, $tmp, $res3);
		($acc, $ver, $nom, $nm_variant, $tmp, $res3) = &check_nm_number_conversion($call, $dbh, $nm_variant, $id, $number, $genomic_var, $analysis, $status, $var_dp, $var_vf, $var_filter);
		#if ($genomic_var eq 'chrX:g.44918222delT') {print STDERR "1-$first_genomic_var-$genomic_var-$nom\n"}
		#foreach ($call->result()->{'string'}) {
		#	my $tab_ref;
		#	if (ref($_) eq 'ARRAY') {$tab_ref = $_}
		#	my ($acc, $ver, $nom);
		#	else {$tab_ref->[0] = $_}
		#	POSCONV: foreach (@{$tab_ref}) {
		#		if (/(NM_\d+)\.(\d):([cn]\..+)/og) {
		#			($acc, $ver, $nom) = ($1, $2, $3);
		#			my $query = "SELECT nom[1] as gene_name, acc_g, mutalyzer_acc, mutalyzer_version FROM gene WHERE nom[2] = '$acc' AND main = 't' AND acc_version = '$ver';";
		#			my $res3 = $dbh->selectrow_hashref($query);
		#			if (!$res3) {next POSCONV}#try again
		#			else {
		#				#we've got THE good one
		#				$nm_variant = 1;
		#				last POSCONV;
		#			}
		#		}
		#		elsif (/NR_.+/) {#deal with NR for NR, a number conversion should be enough - same for chrM
		#			$tmp .= "MANUAL NR_variant\t$id$number\t$genomic_var\t$analysis\t'$status', 'unknown', '$var_dp', '$var_vf', '$var_filter');\n";
		#		}
		#		elsif (/NC_012920.+/) {
		#			$tmp .= "MANUAL chrM_variant\t$id$number\t$genomic_var\t$analysis\t'$status', 'unknown', '$var_dp', '$var_vf', '$var_filter');\n";
		#		}
		#	}
		#}
		if ($nm_variant != 1) {#let's try hg38
			#liftover
			my $hg38_pos = &liftover($var_pos, $var_chr, $ABSOLUTE_HTDOCS_PATH, $HG19TOHG38CHAIN);
			if ($hg38_pos eq 'f') {return "MANUAL INDEL NO MATCHING NM\t$id$number\t$genomic_var\t$analysis\t'$status', 'unknown', '$var_dp', '$var_vf', '$var_filter'); $var_chr $var_pos in VCF\n"}
			
			my $hg38_genomic_var = &build_hgvs_from_illumina($var_chr, $hg38_pos, $var_ref, $var_alt);		
			
			$call = $soap->call('numberConversion',
				SOAP::Data->name('build')->value('hg38'),
				SOAP::Data->name('variant')->value($hg38_genomic_var));
			
			if (!$call->result()) {return "MANUAL HG38 INDEL MUTALYZER FAULT\t$id$number\t$genomic_var\t$analysis\t'$status', 'unknown', '$var_dp', '$var_vf', '$var_filter'); $var_chr $var_pos in VCF\n"}
			($acc, $ver, $nom, $nm_variant, $tmp, $res3) = &check_nm_number_conversion($call, $dbh, $nm_variant, $id, $number, $genomic_var, $analysis, $status, $var_dp, $var_vf, $var_filter);
			#if ($genomic_var eq 'chrX:g.44918222delT') {print STDERR "2-$first_genomic_var-$genomic_var-$nom\n"}
		}
		
		
		
		
		
		if ($nm_variant == 1) {
			$tmp = '';#reset error messages
		#foreach ($call->result()->{'string'}) {
		#	my $tab_ref;
		#	if (ref($_) eq 'ARRAY') {$tab_ref = $_}
		#	else {$tab_ref->[0] = $_}
		#	POSCONV: foreach (@{$tab_ref}) {
		#		if (/(NM_\d+)\.(\d):([cn]\..+)/og) {
		#			my $acc = $1;
		#			#patch for TMEM132E - mutalyzer bug uses a deprecated NM 10/10/2018
		#			#same for KDM6A - discrepancies between acc nos between posconverter and name checker
		#			#+ patch for TPRN whih returns 2 same acc with 2 different gene names
		#			#https://www.mutalyzer.nl/position-converter?assembly_name_or_alias=GRCh37&description=chr9%3Ag.140094473G%3EA
		#			#13/11/2018
		#			my $ver = $2;
		#			my $nom = $3;
		#			if ($acc eq 'NM_207313') {$acc = 'NM_001304438'}
		#			elsif ($acc eq 'NM_021140') {$acc = 'NM_001291415'}
		#			#elsif ($acc eq 'NM_001128228' && $ver == 1) {next POSCONV}
		#			#my $query = "SELECT nom[1] as gene_name, acc_g, mutalyzer_acc, mutalyzer_version FROM gene WHERE nom[2] = '$acc' AND main = 't';";# AND acc_version = '$ver';";
		#			#13/11/2018 genes acc no and version should be synchrnized with mutalyzer pos conv - no permissivity we MUST find the right acc no + version
		#			my $query = "SELECT nom[1] as gene_name, acc_g, mutalyzer_acc, mutalyzer_version FROM gene WHERE nom[2] = '$acc' AND main = 't' AND acc_version = '$ver';";
		#			my $res3 = $dbh->selectrow_hashref($query);
			if ($res3) {#we've got the good one
				#1st getstrand
				my $strand_code = U2_modules::U2_subs_1::get_strand($res3->{'gene_name'}, $dbh);  #returns ASC for '+', DESC for '-', usually used to sort variants
				if (($genomic_var =~ /del/ && $strand_code eq 'ASC') || ($genomic_var =~ /ins/)) {
				#if (($genomic_var =~ /ins/ && $strand_code eq 'ASC')) { #for dev purpose
					#run mutalyzer and catch warning										
					$call = U2_modules::U2_subs_1::run_mutalyzer($soap, $res3->{'acc_g'}, $res3->{'gene_name'}, $nom, $res3->{'mutalyzer_version'}, $res3->{'mutalyzer_acc'});
					#if ($genomic_var eq 'chrX:g.44918222delT') {print STDERR "2,5-$first_genomic_var-$genomic_var-$nom\n"}
					my $message;									
					if ($call->result->{'messages'}) {	
						foreach ($call->result->{'messages'}->{'SoapMessage'}) {
							my $array_ref;
							if (ref($_) eq 'ARRAY') {$array_ref = $_}
							else {$array_ref->[0] = $_}
							foreach (@{$array_ref}) {
								if ($_->{'message'} =~ /Sequence|Insertion/) {$message = $_->{'message'}}
								#if ($_->{'errorcode'}) {push @errors, $_} ## if you want to deal with error and/or warning codes
							}	
						}
					}
					
					if ($genomic_var =~ /del/o) {
						#example
						#Sequence "T" at position 190800 was given, however, the HGVS notation prescribes that on the forward strand it should be "T" at position 190813.
						#Sequence "T" at position 43035 was given, however, the HGVS notation prescribes that on the forward strand it should be "T" at position 43051.
						#Sequence "AAGAAG" at position 13252_13257 was given, however, the HGVS notation prescribes that on the forward strand it should be "AAGAAG" at position 13273_13278.
						if ($message && $message =~ /Sequence\s"([ATGC\[\]\dbp\s]+)"\sat\sposition\s([\d_]+)\swas\sgiven,\showever,\sthe\sHGVS\snotation\sprescribes\sthat\son\sthe\sforward\sstrand\sit\sshould\sbe\s"([ATGC\[\]\dbp\s]+)"\sat\sposition\s([\d_]+)\./o) {
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
							if (length($old_del) > 25) {$genomic_var =~ s/del$old_del/del/}
							elsif ($new_del ne $old_del) {$genomic_var =~ s/del$old_del/del$new_del/}
							#last POSCONV;
						}
						elsif ($message) {print $message;}
						#we'll fill in the gs2variant table originally designed for Junior runs
						if ($genomic_var ne $first_genomic_var) {
							my $new_name = $genomic_var;
							if ($genomic_var =~ /(^.+del)[ATGC]+/) {$new_name = $1}
							$query_gs = "SELECT u2_name FROM gs2variant WHERE gs_name = '$first_genomic_var' AND (reason LIKE 'MiSeq_%' OR reason LIKE 'inv_nt');";
							$res_gs = $dbh->selectrow_hashref($query_gs);
							if ($res_gs) {$genomic_var = $res_gs->{'u2_name'}}												
							else {
								$insert = "INSERT INTO gs2variant (gs_name, u2_name, reason) VALUES ('$first_genomic_var', '$new_name', 'MiSeq_indel');";
								$dbh->do($insert);
							}
							#last POSCONV;
						}
						#if ($first_genomic_var eq 'chrX:g.44918222delT') {print STDERR "2,6-$first_genomic_var-$genomic_var-$nom\n"}
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
							if ($message && $message =~ /Insertion\sof\s([ATGC\[\]\dbp\s]+)\sat\sposition\s([\d_]+)\swas\sgiven,\showever,\sthe\sHGVS\snotation\sprescribes\sthat\sit\sshould\sbe\sa\sduplication\sof\s([ATGC\[\]\dbp\s]+)\sat\sposition\s([\d_]+)\./o) {
								my ($old_ins, $new_ins) = ($1, $3);
								my ($pos11, $pos12, $pos21, $pos22) = &get_detailed_pos($2, $4);
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
							elsif ($message) {print $message;}
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
							if ($message && $message =~ /Insertion\sof\s([ATGC]+)\sat\sposition\s([\d_]+)\swas\sgiven,\showever,\sthe\sHGVS\snotation\sprescribes\sthat\sit\sshould\sbe\sa\sduplication\sof\s([ATGC]+)\sat\sposition\s([\d_]+)\./o) {
								my ($old_ins, $new_ins) = ($1, $3);
								my ($pos11, $pos12, $pos21, $pos22) = &get_detailed_pos($2, $4);
								if ($pos21 == $pos22) {
									#print 'case1<br/>';
									#print $call->result->{'genomicDescription'};
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
							elsif ($message && $message =~ /Insertion\sof\s([ATGC\[\]\dbp\s]+)\sat\sposition\s([\d_]+)\swas\sgiven,\showever,\sthe\sHGVS\snotation\sprescribes\sthat\son\sthe\sforward\sstrand\sit\sshould\sbe\san\sinsertion\sof\s([ATGC\[\]\dbp\s]+)\sat\sposition\s([\d_]+)\./o) {
								#print 'case3<br/>';
								my ($old_ins, $new_ins) = ($1, $3);
								my ($pos11, $pos12, $pos21, $pos22) = &get_detailed_pos($2, $4);
								my $diff = $pos21 - $pos11;
								$genomic_var =~ /(chr[\dX]+:g\.)(\d+)_(\d+)ins([ATGC]+)/o;
								my ($new1, $new2) = ($2 + $diff, $3 + $diff);
								$genomic_var = $1.$new1."_".$new2."ins$new_ins";
								#if (length ($old_ins) == 2) {
								#	print "strand + $first_genomic_var - $genomic_var<br/>";
								#}
							}
							elsif ($message) {print $message;}
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
						#last POSCONV;
					}
				}
			}
				#}
				#elsif (/NR_.+/) {#deal with NR for NR, a number conversion should be enough - same for chrM
				#	$tmp .= "MANUAL NR_variant\t$id$number\t$genomic_var\t$analysis\t'$status', 'unknown', '$var_dp', '$var_vf', '$var_filter');\n";
				#}
				#elsif (/NC_012920.+/) {
				#	$tmp .= "MANUAL chrM_variant\t$id$number\t$genomic_var\t$analysis\t'$status', 'unknown', '$var_dp', '$var_vf', '$var_filter');\n";
				#}
			#}			
		}
	}
	
	#ok indels are supposed to be corrected, now a numberconveriosn run for everybody then the run mutalyzer.
	#PTPRQ directly to the manual garbage (me)
	if ($genomic_var =~ /chr12:g\.(\d+)/o) {
		if ($1 > 80838126 && $1 < 81072802) {#hg19 coordinates#PTPRQ
			return "MANUAL PTPRQ\t$id$number\t$genomic_var\t$analysis\t'$status', 'unknown', '$var_dp', '$var_vf', '$var_filter');\n";
		}						
	}	
	if ($genomic_var !~ />/) {
		#just check new deldupins does not already exists				
		$insert = &direct_submission($genomic_var, $number, $id, $analysis, $status, $allele, $var_dp, $var_vf, $var_filter, $dbh);
		if ($insert ne '') {
			#######UNCOMMENT WHEN READY
			$dbh->do($insert);
			return 1;
		}
	}
	#if ($first_genomic_var eq 'chrX:g.44918222delT') {print STDERR "2,7-$first_genomic_var-$genomic_var\n"}
	
	#here do the job
	#got it from import_illumina got from gsdot2u2.cgi	
	my ($nom_ng, $nom_ivs, $nom_prot, $seq_wt, $seq_mt, $type_adn, $type_arn, $type_prot, $type_segment, $type_segment_end, $num_segment, $num_segment_end, $taille, $snp_id, $snp_common);
	($nom_prot, $nom_ivs) = ('NULL', 'NULL');	
	my ($start, $end) = &get_start_end_pos($genomic_var);
	##run numberConversion() webservice
	my $call = $soap->call('numberConversion',
			SOAP::Data->name('build')->value('hg19'),
			SOAP::Data->name('variant')->value($genomic_var));
	#if (!$call->result()) {
	
	my $nm_variant = 0;
	my ($acc, $ver, $nom, $res3);
	#if ($genomic_var =~ />/o) {#we move on with SNVs
	($acc, $ver, $nom, $nm_variant, $tmp, $res3) = &check_nm_number_conversion($call, $dbh, $nm_variant, $id, $number, $genomic_var, $analysis, $status, $var_dp, $var_vf, $var_filter);
	#if ($first_genomic_var eq 'chrX:g.44918222delT') {print STDERR "3-$first_genomic_var-$genomic_var-$nom-$nm_variant\n"}
	
	if ($nm_variant != 1) {#let's try hg38
	#liftover
		my $hg38_pos;
		if ($first_genomic_var eq $genomic_var) {$hg38_pos = &liftover($var_pos, $var_chr, $ABSOLUTE_HTDOCS_PATH, $HG19TOHG38CHAIN);}
		else {#if genomic pos has moved!!!
			my ($hg19_pos, $ghost) = &get_start_end_pos($genomic_var);
			$hg38_pos = &liftover($hg19_pos, $var_chr, $ABSOLUTE_HTDOCS_PATH, $HG19TOHG38CHAIN);
			if ($genomic_var =~ /del/) {$hg38_pos--}#simulate VCF position for dels
			#if ($first_genomic_var eq 'chrX:g.44918222delT') {print STDERR "4-$first_genomic_var-$genomic_var-$nom-$hg38_pos-$hg19_pos\n"}
		}
		#my $hg38_pos = &liftover($var_pos, $var_chr, $ABSOLUTE_HTDOCS_PATH, '19238');
		if ($hg38_pos eq 'f') {return "MANUAL SUBSTITUTION NO MATCHING NM\t$id$number\t$genomic_var\t$analysis\t'$status', 'unknown', '$var_dp', '$var_vf', '$var_filter'); $var_chr $var_pos in VCF\n"}
		
		my $hg38_genomic_var = &build_hgvs_from_illumina($var_chr, $hg38_pos, $var_ref, $var_alt);		
		undef $call;
		$call = $soap->call('numberConversion',
			SOAP::Data->name('build')->value('hg38'),
			SOAP::Data->name('variant')->value($hg38_genomic_var));
		
		if (!$call->result()) {return "MANUAL HG38 SUBSTITUTION MUTALYZER FAULT\t$id$number\t$genomic_var\t$hg38_genomic_var\t$analysis\t'$status', 'unknown', '$var_dp', '$var_vf', '$var_filter'); $var_chr $var_pos in VCF\n"}
		($acc, $ver, $nom, $nm_variant, $tmp, $res3) = &check_nm_number_conversion($call, $dbh, $nm_variant, $id, $number, $genomic_var, $analysis, $status, $var_dp, $var_vf, $var_filter);
		if ($first_genomic_var eq 'chrX:g.44918222delT') {print STDERR "5-$first_genomic_var-$genomic_var-$nom-$hg38_pos-$hg38_genomic_var\n"}
	}
	#}
	
	if ($nm_variant == 1) {
		$tmp = '';#reset error messages
	#if ($call->result()) {
	#	foreach ($call->result()->{'string'}) {
	#		my $tab_ref;
	#		if (ref($_) eq 'ARRAY') {$tab_ref = $_}
	#		else {$tab_ref->[0] = $_}
		my ($main, $treated, $nr) = (0, 0, '');
	#		
	#		POSCONV2: foreach (@{$tab_ref}) {
	#			if (/(NM_\d+)\.(\d):([cn]\..+)/og && $treated == 0) {
	#				my $acc = $1;
	#				#patch 20185/10/10 for TMEM132E => mutalyzer posconv returns only a deprecated NM
	#				#+ patch for TPRN whih returns 2 same acc with 2 different gene names
	#				#https://www.mutalyzer.nl/position-converter?assembly_name_or_alias=GRCh37&description=chr9%3Ag.140094473G%3EA
	#				#13/11/2018
	#				my $ver = $2;
	#				my $nom = $3;
	#				if ($acc eq 'NM_207313') {$acc = 'NM_001304438'}
	#				elsif ($acc eq 'NM_021140') {$acc = 'NM_001291415'}
	#				#elsif ($acc eq 'NM_001128228' && $ver == 1) {next POSCONV2}
	#				
	#				#print $nom, "<br/>";
		my $manual_temp .= "\t$id$number\t$first_genomic_var\t$genomic_var\t$analysis\t'$status', 'unknown', '$var_dp', '$var_vf', '$var_filter');\n";
		#if various errors, to do later
		my $stop = 0;
	#				my $query = "SELECT nom[1] as gene_name, acc_g, mutalyzer_version, mutalyzer_acc FROM gene WHERE nom[2] = '$acc' AND main = 't' AND acc_version = '$ver';";
	#				my $res3 = $dbh->selectrow_hashref($query);
	#				#patch 13/01/2017 when good accession number and not acc_g / coz mutalyzer position converter's seems a little bit outdated
	#				#if (!$res3)	{
	#				#	my $query = "SELECT nom[1] as gene_name, acc_g, mutalyzer_version, mutalyzer_acc FROM gene WHERE nom[2] = '$acc' AND main = 't';";
	#				#	$res3 = $dbh->selectrow_hashref($query);
	#				#}
					#13/11/2018 genes acc no and version should be synchrnized with mutalyzer pos conv - no permissivity we MUST find the right acc no + versions
		if ($res3) {
			$main = 1;
			$type_arn = 'neutral';
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
				else {if ($var_pos == 88886963 || $var_pos == 88887724 || $var_pos == 88888215) {print "here we are!<br/>"};return "MANUAL SEGMENT ERROR $manual_temp"}#;$stop = 1;}
			}
			if (!$num_segment_end) {$num_segment_end = $num_segment;$type_segment_end = $type_segment;}
			if ($nom =~ /[cn]\.\d+[\+-][12]\D.+/o) {$type_arn = 'altered';$nom_prot = 'p.(?)';$type_prot = 'NULL';}
			##
			## Now we can run Mutalyzer...
			##
			#print "New variant: $res3->{'acc_g'}($res3->{'gene_name'}):$nom<br/>";
			#print STDERR "Sample $id$number Variant $res3->{'acc_g'}, $res3->{'gene_name'} $nom $genomic_var\n";
			undef $call;
			$call = U2_modules::U2_subs_1::run_mutalyzer($soap, $res3->{'acc_g'}, $res3->{'gene_name'}, $nom, $res3->{'mutalyzer_version'}, $res3->{'mutalyzer_acc'});
			$manual_temp .= "$res3->{'acc_g'}($res3->{'gene_name'}$res3->{'mutalyzer_version'}):$nom";
			if (defined $res3->{'mutalyzer_acc'}) {$manual_temp .= $res3->{'mutalyzer_acc'}}
			$manual_temp .= "\n";
			#if ($call->fault()) {$stop = 1;return "MANUAL MUTALYZER FAULT$manual_temp";next POSCONV2;}
			if ($call->fault()) {return  " MUTALYZER RUN  FAILED $manual_temp"}
			#$to_follow .= "\n\nMutalyzer run: $res3->{'acc_g'}, $res3->{'gene_name'}, $nom, $res3->{'mutalyzer_version'}, $res3->{'mutalyzer_acc'}\n";
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
						my $tab_ref_message;
						if (ref($_) eq 'ARRAY') {$tab_ref_message = $_}
						else {$tab_ref_message->[0] = $_}
						MESSAGE: foreach (@{$tab_ref_message}) {
							#if ($_->{'message'} =~ /HGVS/o) {$stop = 1;return "MANUAL HGVS$manual_temp"}#&HGVS($_->{'message'}, $line, $nom_g);$stop = 1;$not_done .= "HGVS$var";last;}
							#elsif ($_->{'message'} =~ /identical/o) {$stop = 1;return "MANUAL Identical variant to reference$manual_temp"}
							#elsif ($_->{'message'} =~ /Position.+range/o) {$stop = 1;return "MANUAL Out of range$manual_temp"}
							if ($_->{'message'} =~ /HGVS/o) {return "MANUAL HGVS $_->{'message'} $manual_temp"}#&HGVS($_->{'message'}, $line, $nom_g);$stop = 1;$not_done .= "HGVS$var";last;}
							elsif ($_->{'message'} =~ /identical/o) {return "MANUAL $_->{'message'} Identical variant to reference$manual_temp"}
							elsif ($_->{'message'} =~ /Position.+range/o) {return "MANUAL $_->{'message'} Out of range$manual_temp"}
							elsif ($_->{'message'} =~ /position.+found\s([ATGC])\sinstead/o) {
								my $message = $_->{'message'};
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
											#if ($call->fault()) {$stop = 1;return "MANUAL MUTALYZER FAULT$manual_temp";last;}
											if ($call->fault()) {return "MANUAL MUTALYZER FAULT$manual_temp"}
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
										else {return "NOTINSERTED $message because of homozygous wt$manual_temp"}
									}
									#else {$stop = 1;return "MANUAL Bad wt nt$manual_temp"}
									else {return "MANUAL $message Bad wt nt$manual_temp"}
								}
								#else {$stop = 1;return "MANUAL Bad wt nt$manual_temp";}
								else {return "MANUAL $message Bad wt nt$manual_temp";}
								
							}#&bad_wt($line, $nom_g);$stop = 1;$not_done .= "bad wt nt$line";last;}
							elsif ($_->{'errorcode'} && $_->{'errorcode'} ne 'WSPLICE' && $_->{'errorcode'} ne 'WSTART' && $_->{'errorcode'} ne 'WOVERSPLICE' && $_->{'errorcode'} ne 'WSPLICE_OTHER') {push @errors, $_} ## if you want to deal with error and/or warning codes
						}	
					}
				}
				#my $tmp;
				foreach(@errors) {
					foreach my $key (keys %{$_}) {$tmp .= "MANUAL $key $_->{$key}$manual_temp"}
					#return $tmp;
				}							
				if ($call->result->{'errors'} == 0 && $stop == 0) {
					## let's go
					## IVS name
					if ($type_segment eq 'intron') {
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
					
											
					my $true_version = '';
					#GPR98 no longer works with mutalyzer
					#patch 23/10/2017
					my $gene = $res3->{'gene_name'};
					if ($gene eq 'GPR98') {$gene = 'ADGRV1'}
					## Transcript description (submission) get version of isoform
					if ($call->result->{'transcriptDescriptions'}) {
						foreach ($call->result->{'transcriptDescriptions'}->{'string'}) {
							my $tosearch = $gene."_v";
							my $tab_ref;
							if (ref($_) eq 'ARRAY') {$tab_ref = $_}
							else {$tab_ref->[0] = $_}
							#$tmp .= "$call->result->{'transcriptDescriptions'}->{'string'}\n";
							#if (Dumper($_) =~ /\[/og) { ## multiple results: tab ref
							foreach(@{$tab_ref}) {
								#$_ =~ /NG_\d+\.\d\((\w+)\):(c\..+)/o;
								#$tmp .= "$_\n";
								#BUG corrected 03/25/2015
								#when multiple genes on same NG, AND
								#last nom involves a "n."
								#then true_version was reset to uninitialize
								#if added
								#see test_mutalyzer_pde6a.pl on 158 for details
								#$to_follow .= "\nTranscript Description: $_\n";
								my $expr = $_;
								
								#UD_154212779600(RPGR_v005):c.2341G>A
								if ($expr =~ /($gid)_\d+\.?\d\((\w+)\):(c\..+)/) {
								#if ($expr =~ /(UD|NG)_\d+\.?\d\((\w+)\):(c\..+)/) {
									my ($version, $temp_var) = ($2, $3);
									$temp_var =~ s/\?/\\?/og;
									if ($nom =~ /^$temp_var/) {#for exonic variants
										$temp_var =~ s/\\//og;
										$nom = $temp_var;
										$version =~ /$tosearch(\d{3})/;
										$true_version = $1;
									}
									#if ($gene eq 'RPGR') {
									#	$tmp .= "RPGR v2 $expr:$version:$temp_var:$nom:$true_version"
									#}
									##my ($version, $variant) = ($2, $3);
									#$to_follow .= "version: $version variant: $variant\n";
									#$tmp .= "$version-$variant-$nom-$gene\n";
									##if ($nom =~ /$variant/) {
									##	$version =~ /($gene)_v(\d{3})/;
									##	$true_version = $2;
										#$to_follow .= "true version: $true_version\n";
										#print "\n$true_version\n";
									##}
								}
								#else {print "FUCKED-$expr-$gid-<br/>";}
								
							}
						}
					}
					#else {$tmp .= 'No transcriptDescription!!!!!'}
					## Protein description
					
					if ($call->result->{'proteinDescriptions'}) {
						foreach ($call->result->{'proteinDescriptions'}->{'string'}) {
							my $tosearch = $gene."_i";
							my $tab_ref;
							if (ref($_) eq 'ARRAY') {$tab_ref = $_}
							else {$tab_ref->[0] = $_}
							#$manual .= $tab_ref->[0]."\n";
							#if (Dumper($_) =~ /\[/og) { ## multiple results: tab ref
							foreach(@{$tab_ref}) {
								if ($_ =~ /($gene)_i$true_version\):(p\..+)/) {$nom_prot = $2}
								##if ($_ =~ /$tosearch$true_version\):(p\..+)/) {$nom_prot = $1}
								if ($gene =~ /(PDE6A|TECTA|CDH23|RPGR|PLS1)/o) {
									$tmp .= "FOLLOW $1 variant to check: $nom\t$_\ttrue version:$true_version\tgid:$gid\tnom_prot:$nom_prot\n"
								}											
								#print "\nProtein Description: ", $_, "\n"
							}
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
							elsif ($nom_prot =~ /[^\\^\?^=]/o) {$type_prot = 'missense'}
						}
						else {$nom_prot = 'p.(=)';$type_prot = 'NULL';}
					}
					
					
					#snp
					($snp_id, $snp_common) = ('NULL', 'NULL');
					my $snp_query = "SELECT rsid, common FROM restricted_snp WHERE ng_var = '$res3->{'acc_g'}:$nom_ng';";
					if ($nom_ng =~ /d[eu][lp]/o) {$snp_query = "SELECT rsid, common FROM restricted_snp WHERE ng_var like '$res3->{'acc_g'}:$nom_ng%';"}
					
					my $res_snp = $dbh->selectrow_hashref($snp_query);
					if ($res_snp) {$snp_id  = $res_snp->{rsid};$snp_common = $res_snp->{common};}
					elsif (U2_modules::U2_subs_1::test_myvariant() == 1) {
						#use myvariant.info REST API  http://myvariant.info/
						my $myvariant = U2_modules::U2_subs_1::run_myvariant($genomic_var, 'dbsnp.rsid', $user->getEmail());
						if ($myvariant && $myvariant->{'dbsnp'}->{'rsid'} ne '') {$snp_id = $myvariant->{'dbsnp'}->{'rsid'}}
					}
					
					if (($type_adn =~ /(deletion|insertion|duplication)/o) && ($taille < 5) && ($nom =~ /(.+d[eu][lp])$/o)) {
						my $tosend = $seq_mt;
						if ($type_adn eq 'deletion') {$tosend = $seq_wt}								
						my $sequence = U2_modules::U2_subs_1::get_deleted_sequence($tosend);
						$nom .= $sequence;
						#if ($nom_ivs ne 'NULL') {$nom_ivs .= $sequence}
					}										
					#
					### let's go
					#if ($nom =~ /(.+d[eu][lp])[ATCG]+$/) {$nom = $1} #we remove what is deleted or duplicated
					if ($genomic_var =~ /(.+d[eu][lp])[ATCG]+$/o) {$genomic_var = $1} #we remove what is deleted or duplicated
					my $classe = 'unknown';
					if ($var_vf =~ /R8/o) {$classe = 'R8'}
					
					$insert = "INSERT INTO variant (nom, nom_gene, nom_g, nom_ng, nom_ivs, nom_prot, type_adn, type_arn, type_prot, classe, type_segment, num_segment, num_segment_end, taille, snp_id, snp_common, commentaire, seq_wt, seq_mt, type_segment_end, creation_date, referee) VALUES ('$nom', '{\"$res3->{'gene_name'}\",\"$acc\"}', '$genomic_var', '$nom_ng', '$nom_ivs', '$nom_prot', '$type_adn', '$type_arn', '$type_prot', '$classe', '$type_segment', '$num_segment', '$num_segment_end', '$taille', '$snp_id', '$snp_common', 'NULL', '$seq_wt', '$seq_mt', '$type_segment_end', '$date', 'ushvam2');";
					#print STDERR "$insert\n";
					$insert =~ s/'NULL'/NULL/og;
					#print "$insert<br/>";
					###########UNCOMMENT WHEN READY
					$dbh->do($insert);
					$tmp .= "NEWVAR $insert\n";
					
					$insert = "INSERT INTO variant2patient (nom_c, num_pat, id_pat, nom_gene, type_analyse, statut, allele, depth, frequency, msr_filter) VALUES ('$nom', '$number', '$id', '{\"$res3->{'gene_name'}\", \"$acc\"}', '$analysis', '$status', '$allele', '$var_dp', '$var_vf', '$var_filter');";
					#print "$insert<br/>";
					###########UNCOMMENT WHEN READY
					$dbh->do($insert);
					#$treated = 1;
					if ($tmp && $tmp ne '') {return $tmp}
					else {return 3}
					#last POSCONV2;##not tested							
				}
			}
			else {return "MUTALYZER NO ANSWER\t$id$number\t$first_genomic_var\t$genomic_var\t$analysis\t'$status', 'unknown', '$var_dp', '$var_vf', '$var_filter');\n\n"}
		#}
				#else {$manual .= "UNUSUAL ACC_NO\t$manual_temp";}
		#	}
		#	elsif (/NR_.+/) {#deal with NR for NR, a number conversion should be enough
		#		$tmp .= "MANUAL NR_variant\t$id$number\t$genomic_var\t$analysis\t'$status', 'unknown', '$var_dp', '$var_vf', '$var_filter');\n";
		#	}
		#}		
		if ($main == 0) {return "MANUAL UNUSUAL ACC_NO\t$id$number\t$genomic_var\t$analysis\t'$status', 'unknown', '$var_dp', '$var_vf', '$var_filter');\n$nr"}#$treated is not mandatory here
		if ($treated == 0) {if ($tmp && $tmp ne '') {return $tmp}}
		}
	}
	else {
		return "MANUAL MUTALYZER NO RESULT OR UNUSUAL ACC NO t$id$number\t$genomic_var\n"
	}
	
	### end gsdot2u2.cgi
	
	#return 1;
}


sub search_position {
	my ($chr, $pos, $dbh) = @_;
	my $query = "SELECT a.nom, a.nom_gene, a.type FROM segment a, gene b WHERE a.nom_gene = b.nom AND b.chr = '$chr' AND '$pos' BETWEEN SYMMETRIC a.$postgre_start_g AND a.$postgre_end_g;";
	my $res = $dbh->selectrow_hashref($query);
	if ($res ne '0E0') {return "\t$res->{'nom_gene'}[0] - $res->{'nom_gene'}[1]\t$res->{'type'}\t$res->{'nom'}"}
	else {return "\tunknown position in U2\tunknown\tunknown"}
	
}

sub build_hgvs_from_illumina {
	my ($var_chr, $var_pos, $var_ref, $var_alt) = @_;
	#we keep only the first variants if more than 1 e.g. alt = TAA, TA
	if ($var_alt =~ /^([ATCG]+),/) {$var_alt = $1}
	#if ($var_chr =~ /^([\dXYM]{1,2})/o) {$var_chr = "chr$1"}
	if ($var_chr =~ /^($U2_modules::U2_subs_1::CHR_REGEXP)/o) {$var_chr = "chr$1"}
	my $hgvs_pref = 'g.';
	if ($var_chr eq 'chrM') {$hgvs_pref = 'm.'}
	
	#subs
	if ($var_ref =~ /^[ATGC]$/ && $var_alt =~ /^[ATGC]$/) {return "$var_chr:$hgvs_pref$var_pos$var_ref>$var_alt"}
	#dels
	elsif (length($var_ref) > length($var_alt)) {
		if (length($var_ref) == 2) {return "$var_chr:$hgvs_pref".($var_pos+1)."del".substr($var_ref, 1)}
		else {return "$var_chr:$hgvs_pref".($var_pos+1)."_".($var_pos+(length($var_ref)-1))."del".substr($var_ref, 1)}
	}
	#insdup
	elsif (length($var_alt) > length($var_ref)) {return "$var_chr:$hgvs_pref".($var_pos)."_".($var_pos+1)."ins".substr($var_alt, 1)}
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
	#if ($var =~ /chr[\dXY]+:g\.(\d+)[dATCG][eu>][lpATCG].*/o) {return ($1, $1)}
	#elsif ($var =~ /chr[\dXY]+:g\.(\d+)_(\d+)[di][enu][lsp].*/o) {return ($1, $2)}
	if ($var =~ /chr$U2_modules::U2_subs_1::CHR_REGEXP:g\.(\d+)[dATCG][eu>][lpATCG].*/o) {return ($1, $1)}
	elsif ($var =~ /chr$U2_modules::U2_subs_1::CHR_REGEXP:g\.(\d+)_(\d+)[di][enu][lsp].*/o) {return ($1, $2)}
}

sub build_roi {
	my $dbh = shift;
	##we built a hash with 'start, stop' => chr for each gene
	#select min(least(start_g, end_g)), max(greatest(start_g,end_g)) from segment where nom_gene[1] = 'USH2A' and type LIKE '%UTR';
	my $query = "SELECT a.chr, MIN(LEAST(b.start_g, b.end_g)) as min, MAX(GREATEST(b.start_g, b.end_g)) as max FROM gene a, segment b WHERE a.nom[1] = b.nom_gene[1] AND a.ns_gene = 't' AND (b.type LIKE '%UTR' OR b.type = 'intergenic') GROUP BY a.nom[1], a.chr ORDER BY a.chr, min ASC;";
	my $sth = $dbh->prepare($query);
	my $res = $sth->execute();
	
	my %intervals;
	while (my $result = $sth->fetchrow_hashref()) {$intervals{"$result->{'min'}-$result->{'max'}"} = $result->{'chr'}}
	return \%intervals;
}

sub compute_approx_panel_size {
	my ($dbh, $analysis_type) = shift;
	my $query = "SELECT SUM(a.end_g - a.start_g + 1) FROM segment a, gene b WHERE a.nom_gene = b.nom AND b.ns_gene = 't' AND b.\"$analysis_type\" = 't' and b.main = 't';";
}

sub get_nenufaar_id {#get nenufaar id of the analysis => needs path to log file ($ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/data/$CLINICAL_EXOME_BASE_DIR/$run)
	my $path = shift;
	my $nenufaar_log = `ls $path/*.log | xargs basename`;
	$nenufaar_log =~ /(.+)_(\d+).log/og;
	return ($1, $2);
}

sub u2class2acmg {
	my ($u2_class, $dbh) = @_;
	my $query = "SELECT acmg_class FROM valid_classe WHERE classe = '$u2_class';";
	my $res = $dbh->selectrow_hashref($query);
	return $res->{'acmg_class'};
	#if ($u2_class eq 'neutral') {return 'ACMG class I'}
	#elsif ($u2_class eq 'VUCS class I' || $u2_class eq 'VUCS class II') {return 'ACMG class II'}
	#elsif ($u2_class eq 'VUCS class IV') {return 'ACMG class IV'}
	#elsif ($u2_class eq 'pathogenic') {return 'ACMG class V'}
	#else {return 'ACMG class III'}
}

sub acmg_color_by_classe {
	my ($acmg_class, $dbh) = @_;
	my $query = "SELECT acmg_html_code FROM valid_classe WHERE acmg_class = '$acmg_class';";
	my $res = $dbh->selectrow_hashref($query);
	return $res->{'acmg_html_code'};
}

sub get_defgen_allele {
	my $u2_allele = shift;
	if ($u2_allele eq 'unknown') {return ('unknown', 'unknown')}
	elsif ($u2_allele == '1') {return ('yes', 'no')}
	elsif ($u2_allele == '1') {return ('no', 'yes')}
	elsif ($u2_allele == '1') {return ('yes', 'yes')}
}

sub get_total_samples {
	my ($analysis, $dbh) = @_;	
	my $query;
	if ($analysis eq 'all') {$query = "SELECT COUNT(DISTINCT(num_pat, id_pat)) AS a FROM analyse_moleculaire WHERE type_analyse ~ \'$ANALYSIS_ILLUMINA_PG_REGEXP\';"}
	else {$query = "SELECT COUNT(DISTINCT(num_pat, id_pat)) AS a FROM analyse_moleculaire WHERE type_analyse = '$analysis';"}
	my $res = $dbh->selectrow_hashref($query);
	return "$res->{'a'} samples";
}
sub get_total_runs {
	my ($analysis, $dbh) = @_;	
	my $query;
	if ($analysis eq 'all') {$query = "SELECT COUNT(DISTINCT(id)) AS id FROM illumina_run a, miseq_analysis b WHERE a.id = b.run_id AND b.type_analyse ~ \'$ANALYSIS_ILLUMINA_PG_REGEXP\';"}
	else {$query = "SELECT COUNT(DISTINCT(id)) AS id FROM illumina_run a, miseq_analysis b WHERE a.id = b.run_id AND b.type_analyse = '$analysis';"}
	my $res = $dbh->selectrow_hashref($query);
	return "$res->{'id'} runs";
}

sub get_labels {
	my ($tag, $dbh) = @_;
	my ($query, $labels, $run_id, $run_type);
	if ($tag eq 'global' || $tag eq 'all') {$query = "SELECT DISTINCT(run_id), type_analyse FROM miseq_analysis ORDER BY run_id DESC;";$run_type = '';}# type_analyse DESC,
	#if ($run eq 'global') {$query = "SELECT DISTINCT(run_id), type_analyse FROM miseq_analysis ORDER BY type_analyse DESC, run_id DESC;"}# type_analyse DESC, 
	elsif ($tag =~ /$ANALYSIS_ILLUMINA_PG_REGEXP/) {$query = "SELECT DISTINCT(run_id), type_analyse FROM miseq_analysis WHERE type_analyse = '$tag' ORDER BY run_id DESC;"}
	else {$query = "SELECT id_pat, num_pat, type_analyse FROM miseq_analysis WHERE run_id = '$tag' ORDER BY id_pat, num_pat;"}
	my $sth = $dbh->prepare($query);
	my $res = $sth->execute();
	while (my $result = $sth->fetchrow_hashref()) {
		if ($result->{'id_pat'} && $result->{'id_pat'} ne '') {$labels .= "\"$result->{'id_pat'}$result->{'num_pat'}\", ";$run_id = '';$run_type = $result->{'type_analyse'};}
		elsif ($result->{'run_id'} =~ /^(\d+)_\w+-(\w+)$/o) {$labels .= "\"$1_$2";$result->{'type_analyse'} =~ /-(\d+)/o;$labels .= "_$1\", ";$run_id .= "$result->{'run_id'},"}
		elsif ($result->{'run_id'} =~ /^(\d+)_\w+_\d+_(\w+)$/o) {$labels .= "\"$1_$2";$result->{'type_analyse'} =~ /-(\d+)/o;$labels .= "_$1\", ";$run_id .= "$result->{'run_id'},"}	
	}
	chop($labels);
	chop($labels);
	chop($run_id);
	return $labels, $run_id, $run_type;
}

sub get_data_mean {
	my ($run, $type, $num, $table, $dbh) = @_;
	my $query;
	if ($run eq 'global') {$query = "SELECT AVG($type) AS a FROM $table"}
	elsif ($run =~ /$ANALYSIS_ILLUMINA_PG_REGEXP/) {
		$query = "SELECT AVG($type) AS a FROM $table WHERE type_analyse = '$run';";
		if ($table eq 'illumina_run') {$query = "SELECT AVG($type) AS a FROM $table a, miseq_analysis b WHERE a.id = b.run_id AND b.type_analyse = '$run';"}
	}
	else {$query = "SELECT AVG($type) AS a FROM $table WHERE run_id = '$run';"}
	my $res = $dbh->selectrow_hashref($query);
	return sprintf('%.'.$num.'f', $res->{'a'});
}

sub get_data {
	my ($run, $type, $math, $num, $cluster, $dbh) = @_;
	my ($query, $data);
	if (!$num) {$num = '0'}
	if ($run eq 'global') {
		if ($cluster eq 'cluster') {$query = "SELECT $type AS a FROM illumina_run ORDER BY id DESC;";}##### BEWARE OF THE ORDER COMPARING TO LABELS!!!!!!!!!
		#else {$query = "SELECT $math($type) AS a FROM miseq_analysis GROUP BY run_id, type_analyse ORDER BY type_analyse DESC, run_id DESC;"}
		else {$query = "SELECT $math($type) AS a FROM miseq_analysis GROUP BY run_id, type_analyse ORDER BY run_id DESC;"}#type_analyse DESC, 
	}
	elsif ($run =~ /$ANALYSIS_ILLUMINA_PG_REGEXP/) {
		if ($cluster eq 'cluster') {$query = "SELECT DISTINCT($type) AS a, a.id FROM illumina_run a, miseq_analysis b WHERE a.id = b.run_id AND b.type_analyse = '$run' ORDER BY a.id DESC;";}##### BEWARE OF THE ORDER COMPARING TO LABELS!!!!!!!!!
		else {$query = "SELECT $math($type) AS a FROM miseq_analysis WHERE type_analyse = '$run' GROUP BY run_id, type_analyse ORDER BY run_id DESC;"}#type_analyse DESC, 
	}
	else {
		if ($cluster eq 'cluster') {$query = "SELECT $type FROM illumina_run WHERE id = '$run';"}
		else {$query = "SELECT $type AS a FROM miseq_analysis WHERE run_id = '$run' ORDER BY id_pat, num_pat;"}
	}
	#print $query;
	my $sth = $dbh->prepare($query);
	my $res = $sth->execute();
	while (my $result = $sth->fetchrow_hashref()) {
		if ($run ne 'global' && $run !~ /$ANALYSIS_ILLUMINA_PG_REGEXP/ && $cluster eq 'cluster') {
			$data .= $result->{'noc_raw'}.', '.$result->{'noc_pf'}.', '.$result->{'nodc'}.', '.$result->{'nouc'}.', '.$result->{'nouc_pf'}.', '.$result->{'nouic'}.', '.$result->{'nouic_pf'}.', '.$result->{'a'}.', ';
		}
		else {$data .= sprintf('%.'.$num.'f', $result->{'a'}).', '}
	}
	chop($data);
	chop($data);
	return $data;
}
#in stats_ngs.pl, ngs_compare.pl
sub display_page_header {
	my ($txt, $js_fn, $div_id, $q, $dbh) = @_;
	my $text = 'Please choose some kind of NGS experiment below to display '.$txt;
	my $data = U2_modules::U2_subs_2::info_panel($text, $q);
	
	$data .= $q->start_div({'class' => 'w3-container'})."\n";
	
	my @colors = ('sand', 'khaki', 'yellow', 'amber', 'orange', 'deep-orange', 'red', 'pink', 'purple', 'deep-purple', 'indigo', 'blue', 'light-blue');
	
	my $query = "SELECT type_analyse FROM valid_type_analyse WHERE manifest_name <> 'no_manifest' ORDER BY type_analyse;";
	my $sth = $dbh->prepare($query);
	my $res = $sth->execute();
	while (my $result = $sth->fetchrow_hashref()) {
		#print $q->strong({'class' => 'w3-button w3-ripple w3-'.(shift(@colors)).' w3-hover-light-grey w3-hover-shadow w3-padding-32 w3-margin w3-round', 'onclick' => 'window.open(\'stats_ngs.pl?analysis='.$result->{'type_analyse'}.'&amp;time=1\');'}, $result->{'type_analyse'}), "\n";
		$data .=  $q->strong({'class' => 'w3-button w3-ripple w3-'.(shift(@colors)).' w3-hover-light-grey w3-hover-shadow w3-padding-32 w3-margin w3-round', 'onclick' => ''.$js_fn.'(\''.$result->{'type_analyse'}.'\');'}, $result->{'type_analyse'})."\n";
	}
	#print $q->strong({'class' => 'w3-button w3-ripple w3-'.(shift(@colors)).' w3-hover-light-grey w3-hover-shadow w3-padding-32 w3-margin w3-round', 'onclick' => 'window.open(\'stats_ngs.pl?analysis=all&amp;time=1\');'}, 'All analyses'), "\n",
	$data .=  $q->strong({'class' => 'w3-button w3-ripple w3-'.(shift(@colors)).' w3-hover-light-grey w3-hover-shadow w3-padding-32 w3-margin w3-round', 'onclick' => ''.$js_fn.'(\'all\');'}, 'All analyses')."\n".
		$q->end_div().$q->br().
		$q->start_div({'style' => 'height:7px;overflow:hidden;', 'class' => 'w3-margin w3-deep-orange'}).
		$q->end_div()."\n".
		$q->start_div({'id' => $div_id}).$q->end_div();
	return $data;
}

sub defgen_status_html {
	my ($status, $q) = @_;
	if ($status == 1) {return $q->span({'style' => 'color:#00A020'},'Yes')}
	else {return $q->span({'style' => 'color:#FF0000'},'No')}
}
#in variant_prioritize, ajax(defgen)
sub get_sampleID_list {
	my ($id, $number, $dbh) = @_;
	my $query = "SELECT * FROM patient WHERE numero = '$number' AND identifiant = '$id';";
	my $result = $dbh->selectrow_hashref($query);
	if ($result) {
		my ($first_name, $last_name, $dob) = ($result->{'first_name'}, $result->{'last_name'}, $result->{'date_of_birth'});
		$first_name =~ s/'/''/og;
		$last_name =~ s/'/''/og;
		
		my $query2 = "SELECT numero, identifiant, date_of_birth FROM patient WHERE LOWER(first_name) = LOWER('$first_name') AND LOWER(last_name) = LOWER('$last_name') AND numero <> '$number' ORDER BY identifiant, numero";
		my $list = "('$id', '$number')";
		my $sth2 = $dbh->prepare($query2);
		my $res2 = $sth2->execute();
		if ($res2 ne '0E0') {
			while (my $result2 = $sth2->fetchrow_hashref()) {
				if ($dob =~ /^\d{4}-\d{2}-\d{2}$/o && $result2->{'date_of_birth'} =~ /^\d{4}-\d{2}-\d{2}$/o) {
					if ($dob eq $result2->{'date_of_birth'}) {
						$list .= ", ('$result2->{'identifiant'}', '$result2->{'numero'}')"
					}
				}
				else {$list .= ", ('$result2->{'identifiant'}', '$result2->{'numero'}')"}
			}
		}
		return $list, $first_name, $last_name;
	}
}

sub get_filter_from_idlist {
	my ($list, $dbh) = @_;
	my $filter = 'ALL'; #for NGS stuff
	my $query_filter = "SELECT filter FROM miseq_analysis WHERE (id_pat, num_pat) IN ($list) AND filter <> 'ALL';";
	my $res_filter = $dbh->selectrow_hashref($query_filter);
	if ($res_filter) {$filter = $res_filter->{'filter'}}
	return $filter;
}
#in gene.pl
sub add_variant_button {
	my ($q, $gene, $acc, $ng) = @_;
	my $js = "function create_var(url) {
				//alert(\$(\"#new_variant\").val());
				var begin = \$('#main_text\').html();
				if (\$(\"#new_variantblue\").val() !== 'c.') {
					\$(\'html\').css(\'cursor\', \'progress\');
					\$(\'.w3-btn\').css(\'cursor\', \'progress\');
					var nom_c = \$(\"#new_variantblue\").val();
					\$(\"#main_text\").append(\"&nbsp;Please Wait While Creating Variant\");
					\$(\"#creation_form :input\").prop(\"disabled\", true);					
					\$.ajax({
							type: \"POST\",
							url: url,
							data: {type: \$(\"#typeblue\").val(), nom: \$(\"#nomblue\").val(), numero: \$(\"#numeroblue\").val(), gene: \$(\"#geneblue\").val(), accession: \$(\"#acc_noblue\").val(), step: 2, new_variant: \$(\"#new_variantblue\").val(), nom_c: nom_c, ng_accno: \$(\"#ng_accnoblue\").val(), single_var: \'y\'}
					})
					.done(function(msg) {
						if (msg !== '') {\$(\'#created_variant\').append(msg)};
						\$(\'.w3-btn\').css(\'cursor\', \'default\');
						\$(\'html\').css(\'cursor\', \'default\');
						\$(\'#main_modal\').hide();
						\$(\'#main_text\').html(begin);
						\$(\"#new_variantblue\").val(\'c.\');
						\$(\'#creation_form :input\').prop(\'disabled\', false);
						
					});
				}
			}";
	
	my $html = $q->script({'type' => 'text/javascript'}, $js)."\n".
		$q->button({'id' => 'add_var', 'type' => 'button', 'value' => 'Create a variant', 'class' => 'w3-button w3-ripple w3-blue w3-border w3-border-blue', 'onclick' => "document.getElementById('main_modal').style.display='block';\$(\'#creation_form :input\').prop(\'disabled\', false);"})."\n".
		$q->start_div({'id' => 'main_modal', 'class' => 'w3-modal', 'style' => 'z-index:1000'})."\n".
			$q->start_div({'class' => 'w3-modal-content w3-card-4 w3-display-middle'})."\n".
				$q->start_div({'class' => 'w3-container w3-blue'}).$q->span({'onclick' => "document.getElementById('main_modal').style.display='none'", 'class' => 'w3-button w3-display-topright w3-xlarge'}, '&times;').$q->h2({'id' => 'main_text'}, "Create a variant ($acc)").$q->end_div()."\n".
				$q->start_div({'class' => 'w3-container'})."\n".
					$q->start_form({'id' => 'creation_form', 'class' => 'u2_form', 'method'=> 'post', 'action' => '', 'enctype' => &CGI::URL_ENCODED})."\n".
						$q->input({'type' => 'hidden', 'form' => 'creation_form', 'name' => 'gene', 'id' => 'geneblue', 'value' => "$gene"})."\n".
						$q->input({'type' => 'hidden', 'form' => 'creation_form', 'name' => 'acc_no', 'id' => 'acc_noblue', 'value' => "$acc"})."\n".
						$q->input({'type' => 'hidden', 'form' => 'creation_form', 'name' => 'type', 'id' => 'typeblue', 'value' => 'exon'})."\n".
						$q->input({'type' => 'hidden', 'form' => 'creation_form', 'name' => 'numero', 'id' => 'numeroblue', 'value' => '1'})."\n".
						$q->input({'type' => 'hidden', 'form' => 'creation_form', 'name' => 'nom', 'id' => 'nomblue', 'value' => '1'})."\n".
						$q->input({'type' => 'hidden', 'form' => 'creation_form', 'name' => 'ng_accno', 'id' => 'ng_accnoblue', 'value' => "$ng"})."\n".
							$q->start_div({'class' => 'w3-panel w3-large'})."\n".
								$q->label({'for' => 'new_variantblue'}, 'New variant (HGVS DNA):')."\n".'&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'.
								$q->input({'type' => 'text', 'name' => 'new_variant', 'id' => 'new_variantblue', 'value' => 'c.', 'size' => '20', 'maxlength' => '50'})."\n".
							$q->end_div()."\n".
							$q->start_div({'class' => 'w3-panel w3-large w3-center'})."\n".
								$q->button({'name' => 'submit', 'type' => 'submit', 'for' => 'creation_form', 'value' => 'Use Mutalyzer', 'class' => 'w3-btn w3-blue', 'onclick' => 'create_var(\'variant_input.pl\');'})."\n".
								$q->button({'name' => 'submit', 'type' => 'submit', 'for' => 'creation_form', 'value' => 'Use VariantValidator', 'class' => 'w3-btn w3-blue', 'onclick' => 'create_var(\'variant_input_vv.pl\');'})."\n".
							$q->end_div()."\n".
					$q->end_form()."\n".
				$q->end_div()."\n".
			$q->end_div()."\n".
		$q->end_div()."\n";
	return $html;
	
}
#variant_input_vv.pl
sub create_variant_vv {
	my ($vv_results, $vvkey, $gene, $cdna, $acc_no, $acc_ver, $ng_accno, $user, $q, $dbh, $calling) = @_;
	my ($nom_g, $nom_ng, $nom_g_38, $nom_ivs, $nom_prot, $seq_wt, $seq_mt, $type_adn, $type_arn, $type_prot, $type_segment, $type_segment_end, $num_segment, $num_segment_end, $taille, $snp_id, $snp_common, $classe, $variant, $defgen_export, $chr);
	($nom_prot, $nom_ivs, $type_arn, $classe, $defgen_export, $nom_g_38, $snp_id, $snp_common, $seq_wt, $seq_mt) = ('NULL', 'NULL', 'neutral', 'unknown', 'f', 'NULL', 'NULL', 'NULL', 'NULL', 'NULL');
	#print Dumper($vv_results);
	my $error = '';
	foreach my $key (keys %{$vv_results}) {
		if ($key ne 'metadata' && $key ne 'flag' && ($key eq $vvkey || $key =~ /validation_warning/o )) {
			#print STDERR $key."-$vv_results->{$key}-\n";
			if (ref($vv_results->{$key}) eq ref {}) {
				foreach my $key2 (keys(%{$vv_results->{$key}})) {
					#print STDERR $key2."\n";
					if ($key2 eq 'validation_warnings') {
						my $text = '';
						foreach my $warning (@{$vv_results->{$key}->{$key2}}) {
							#print STDERR "WARNING: $vvkey : $warning : $calling\n";
							if ($warning eq "$acc_no.$acc_ver:$cdna") {
								#bad wt  nt sometimes validation_warnings = key directly
								$text = "VariantValidator error: $warning".$vv_results->{$key}->{'validation_warnings'}[1];
							}
							elsif ($warning =~ /length must be/o) {$text .= "VariantValidator error for $cdna : $warning"}
							elsif ($warning =~ /RefSeqGene record not available/o) {$nom_ng = 'NULL'}
							elsif ($warning =~ /does not agree with reference/o) {$text .= "VariantValidator error for $cdna ($warning): ".$vv_results->{$key}->{'validation_warnings'}[1]}
							elsif ($warning =~ /automapped to $acc_no\.$acc_ver:(c\..+)/g) {
								if ($calling eq 'web') {
									$text .= $q->span("VariantValidator reports that your variant should be $1 instead of $cdna");
								}
								elsif($calling =~ /background/o) {$text .= "VariantValidator error for $cdna : $warning"}
							}
						}
						if ($text ne '') {
							if ($calling eq 'web') {
								print U2_modules::U2_subs_2::danger_panel($text, $q);
								exit;
							}
							elsif($calling =~ /background/o) {$error .= "ERROR: $text\n"; return $error}
						}
					}
				}
			}
		}
		#bad wt nt => sometimes key = new NMvar (autoremapped) ->{'validation_warnings}
		#if ($key =~ /NM_.+/o) {
		#	if (defined($vv_results->{$key}->{'validation_warnings'}[0]) && $vv_results->{$key}->{'validation_warnings'}[0] =~ /automapped to $acc_no\.$acc_ver:(c\..+)/g) {
		#		if ($calling eq 'web') {
		#			my $text = $q->span("VariantValidator reports that your variant should be $1 instead of $cdna");
		#			print U2_modules::U2_subs_2::danger_panel($text, $q);
		#			exit;
		#		}
		#		elsif($calling = 'background') {$error .= "ERROR: $vv_results->{$key}->{'validation_warnings'}[0]\n"; return $error}
		#	}
		#}
		#elsif ($vv_results->{$key} =~ /validation_warning/) {
		#	#print STDERR "1- ".$vv_results->{$key}->{'validation_warnings'}[0]."\n";
		#	my $text = '';
		#	foreach my $warning (@{$vv_results->{$key}->{'validation_warnings'}}) {
		#		if ($warning eq "$acc_no.$acc_ver:$cdna") {
		#			#bad wt  nt sometimes validation_warnings = key directly
		#			$text = "VariantValidator error: $_".$vv_results->{$key}->{'validation_warnings'}[1];
		#		}
		#		elsif ($warning =~ /length must be/o) {$text = "VariantValidator error for $cdna : $_"}
		#		elsif ($warning =~ /RefSeqGene record not available/o) {$nom_ng = 'NULL'}
		#		elsif ($warning =~ /does not agree with reference/o) {$text = "VariantValidator error for $cdna ($_): ".$vv_results->{$key}->{'validation_warnings'}[1]}
		#		else {$text = $warning}
		#		#print STDERR $warning."\n";
		#	}
		#	if ($text ne '') {
		#		if ($calling eq 'web') {
		#			print U2_modules::U2_subs_2::danger_panel($text, $q);
		#			exit;
		#		}
		#		elsif($calling = 'background') {$error .= "ERROR: $text\n"; return $error}
		#	}
		#}
		#if ($calling eq 'web' && !$vv_results->{$vvkey}) {#VV changed variant name (ex with delAGinsT)
		#	if (ref($vv_results->{$key}) eq ref {} && $vv_results->{$key}->{'submitted_variant'} eq $vvkey) {$vvkey = $key;print "<br/>".$vv_results->{$key}->{'submitted_variant'}."<br/>"}
		#}
		
		#if (($key =~ /NM_.+/o || $key =~ /validation_warning/o) && defined($vv_results->{$key}->{'validation_warnings'}[0])) {#there is a warning
		#	my $text = '';
		#	foreach my $warning (@{$vv_results->{$key}->{'validation_warnings'}}) {
		#		if ($warning eq "$acc_no.$acc_ver:$cdna") {
		#			#bad wt  nt sometimes validation_warnings = key directly
		#			$text = "VariantValidator error: $_".$vv_results->{$key}->{'validation_warnings'}[1];
		#		}
		#		elsif ($warning =~ /length must be/o) {$text .= "VariantValidator error for $cdna : $warning"}
		#		elsif ($warning =~ /RefSeqGene record not available/o) {$nom_ng = 'NULL'}
		#		elsif ($warning =~ /does not agree with reference/o) {$text .= "VariantValidator error for $cdna ($warning): ".$vv_results->{$key}->{'validation_warnings'}[1]}
		#		elsif ($warning =~ /automapped to $acc_no\.$acc_ver:(c\..+)/g) {
		#			if ($calling eq 'web') {
		#				$text .= $q->span("VariantValidator reports that your variant should be $1 instead of $cdna");
		#			}
		#			elsif($calling = 'background') {$text .= "VariantValidator error for $cdna : $warning"}
		#		}
		#	}
		#	if ($text ne '') {
		#		if ($calling eq 'web') {
		#			print U2_modules::U2_subs_2::danger_panel($text, $q);
		#			exit;
		#		}
		#		elsif($calling = 'background') {$error .= "ERROR: $text\n"; return $error}
		#	}
		#}
		if ($calling eq 'web' && !$vv_results->{$vvkey}) {#VV changed variant name (ex with delAGinsT)
			if (ref($vv_results->{$key}) eq ref {} && $vv_results->{$key}->{'submitted_variant'} eq $vvkey) {$vvkey = $key;print "<br/>".$vv_results->{$key}->{'submitted_variant'}."<br/>"}
		}
		
		
	}
	#print $vv_results->{$vvkey}->{'primary_assembly_loci'}->{'hg19'}->{'hgvs_genomic_description'}."--<br/>";#->{'hgvs_genomic_description'}
	my @full_nom_g_19 = split(/:/, $vv_results->{$vvkey}->{'primary_assembly_loci'}->{'hg19'}->{'hgvs_genomic_description'});
	if ($full_nom_g_19[0] =~ /NC_0+([^0]{1,2}0?)\.\d{1,2}$/o) {
		$chr = $1;
		if ($chr == 23) {$chr = 'X'}
		elsif ($chr == 24) {$chr = 'Y'}
		$nom_g = "chr$chr:".pop(@full_nom_g_19);
	}
	else {
		my $text = "There has been an issue with VariantValidator. Please double check your variant and resubmit. If this issue persists, contact an admin. \nDEBUG: ".$full_nom_g_19[0].":".$full_nom_g_19[1];
		if ($calling eq 'web') {
			print U2_modules::U2_subs_2::danger_panel($text, $q);
			exit;
		}
		elsif($calling =~ /background(.+)/o) {$error .= "ERROR: $text-$vvkey-$1\n"; return $error}
	}#"Pb with variantvalidator full_nom_g_19: $full_nom_g_19[0]"}
	#print "<br/>".$nom_g."<br/>";
	
	if (defined($vv_results->{$vvkey}->{'primary_assembly_loci'}->{'hg38'}->{'hgvs_genomic_description'}) && $vv_results->{$vvkey}->{'primary_assembly_loci'}->{'hg38'}->{'hgvs_genomic_description'} ne '') {				
		$nom_g_38 = "chr$chr:".(split(/:/, $vv_results->{$vvkey}->{'primary_assembly_loci'}->{'hg38'}->{'hgvs_genomic_description'}))[1];
		#print $nom_g_38."<br/>";
	}
	else {#SLOW
		my $chr_tmp = "chr$chr";
		if ($nom_g =~ /g\.(\d+)_(\d+)([^\d]+)$/o) {
			my ($s19, $e19, $rest) = ($1, $2, $3);
			my $s38 = U2_modules::U2_subs_3::liftover($s19, $chr_tmp, $ABSOLUTE_HTDOCS_PATH, $U2_modules::U2_subs_3::HG19TOHG38CHAIN);
			my $e38 = U2_modules::U2_subs_3::liftover($e19, $chr_tmp, $ABSOLUTE_HTDOCS_PATH, $U2_modules::U2_subs_3::HG19TOHG38CHAIN);
			if ($s38 eq 'f' || $e38 eq 'f') {$nom_g_38 = 'NULL'}
			else {$nom_g_38 = "$chr_tmp:g.".$s38."_$e38$rest"}
		}
		elsif ($nom_g =~ /g\.(\d+)([^\d]+)$/o) {
			my ($s19, $rest) = ($1, $2);
			my $s38 = U2_modules::U2_subs_3::liftover($s19, $chr_tmp, $ABSOLUTE_HTDOCS_PATH, $U2_modules::U2_subs_3::HG19TOHG38CHAIN);
			if ($s38 eq 'f') {$nom_g_38 = 'NULL'}
			else {$nom_g_38 = "$chr_tmp:g.$s38$rest"}
		}
	}
	#print $nom_g_38."<br/>";
	
	if ($nom_g =~ />/o) {$type_adn = 'substitution'}
	elsif ($nom_g =~ /delins/o) {$type_adn = 'indel'}
	elsif ($nom_g =~ /del/o) {$type_adn = 'deletion'}
	elsif ($nom_g =~ /ins/o) {$type_adn = 'insertion'}
	elsif ($nom_g =~ /dup/o) {$type_adn = 'duplication'}
	elsif ($nom_g =~ /inv/o) {$type_adn = 'inversion'}
	#print $type_adn."<br/>";
	#my @full_nom_ng = split(/:/, $vv_results->{"$acc_no.$acc_ver:$cdna"}->{'hgvs_refseqgene_variant'});
	#$nom_ng = pop(@full_nom_ng);
	if ($vv_results->{$vvkey}->{'hgvs_refseqgene_variant'} ne '') {$nom_ng = (split(/:/, $vv_results->{$vvkey}->{'hgvs_refseqgene_variant'}))[1]};
	#print $nom_ng."<br/>"; 
	
	$nom_prot = (split(/:/, $vv_results->{$vvkey}->{'hgvs_predicted_protein_consequence'}->{'tlr'}))[1];
	#print "-$nom_prot-<br/>";
	if ($nom_prot =~ /=/o) {$type_prot = 'silent'}
	elsif ($nom_prot =~ /^p\.\([A-Z][a-z]{2}\d+Ter\)$/o) {$type_prot = 'nonsense';$classe = 'pathogenic';$defgen_export = 't'}
	elsif ($nom_prot =~ /^p\.\([A-Z][a-z]{2}\d+[A-Z][a-z]{2}\)$/o) {$type_prot = 'missense'}
	elsif ($nom_prot =~ /fsTer/o) {$type_prot = 'frameshift';$classe = 'pathogenic';$defgen_export = 't'}
	elsif ($nom_prot =~ /Met1\?/o) {$type_prot = 'start codon'}
	elsif ($nom_prot =~ /ext/o) {$type_prot = 'stop codon'}
	elsif ($type_adn eq 'deletion' && $nom_prot =~ /del/o) {$type_prot = 'inframe deletion'}
	elsif ($type_adn eq 'insertion' && $nom_prot =~ /ins/o) {$type_prot = 'inframe insertion'}
	elsif ($type_adn eq 'duplication' && $nom_prot =~ /dup/o) {$type_prot = 'inframe duplication'}
	#elsif ($nom_prot =~ /\?/o) {$type_prot = 'unknown'}
	else {$type_prot = 'unknown'}
	if ($cdna =~ /[cn]\.\d+[\+-][12]\D.+/o) {$type_arn = 'altered';$nom_prot = 'p.(?)';$type_prot = 'NULL';}
	#replace nom_prot for variants after stop codon and before start
	if ($cdna =~ /c\.\*/o) {$nom_prot = 'p.(=)'}
	elsif ($cdna =~ /c\.-[^-\+]+/o) {$nom_prot = 'p.(=)'}
	
	if ($vv_results->{$vvkey}->{'refseqgene_context_intronic_sequence'} ne '') {
		$nom_ivs = (split(/:/, $vv_results->{$vvkey}->{'refseqgene_context_intronic_sequence'}))[1];
		$type_prot = 'NULL';
	}				
	#print $nom_ivs."<br/>";
	
	
	#replace Ter with *
	if ($nom_prot =~ /Ter/o) {$nom_prot =~ s/Ter/\*/o}
	#print $nom_prot."<br/>";
	#print $type_prot."<br/>";
	my $res;
	#taille num, type segment + end
	if ($nom_g =~ /^chr\w+:g\.(\d+)_(\d+)[^\d]+$/o) {
		#>1bp event
		my ($start, $end) = ($1, $2);
		$taille = $end-$start+1;
		my $query = "SELECT numero, type FROM segment WHERE nom_gene[2] = '$acc_no' AND $start BETWEEN SYMMETRIC $postgre_start_g AND $postgre_end_g AND $end BETWEEN SYMMETRIC $postgre_start_g AND $postgre_end_g;";
		#print STDERR "$query\n";
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
			else {
				if ($calling eq 'web') {
					my $text = "Segment error with $cdna. Contact an admin"; print U2_modules::U2_subs_2::danger_panel($text, $q); exit;
				}
				elsif ($calling =~ /background(.+)/o) {$error = "Segment error with $cdna-$1"; return $error}
			}
		}
	}
	elsif ($nom_g =~ /^chr\w+:g\.(\d+)[^\d]+$/o) {
		#1bp event
		my $pos = $1;
		$taille = 1;
		my $query = "SELECT numero, type FROM segment WHERE nom_gene[2] = '$acc_no' AND $pos BETWEEN SYMMETRIC $postgre_start_g AND $postgre_end_g;";
		#print STDERR "$query\n";
		$res = $dbh->selectrow_hashref($query);
		if ($res) {$num_segment_end = $num_segment = $res->{'numero'};$type_segment_end = $type_segment = $res->{'type'};}
		else {
			if ($calling eq 'web') {
				my $text = "Segment error with $cdna. Contact an admin"; print U2_modules::U2_subs_2::danger_panel($text, $q); exit;
			}
			elsif ($calling =~ /background(.+)/o) {$error = "Segment error with $cdna-$1"; return $error}
		}
	}
	#else {
	#	print STDERR "$nom_g - last\n";
	#}
	#print STDERR "$num_segment-$type_segment-$num_segment_end-$type_segment_end-$taille<br/>\n";
	#fix IVS name when no NG
	if ($type_segment eq 'intron' && ($nom_ivs eq 'NULL' || $nom_ivs !~ /IVS/o)) {
		my $query = "SELECT nom FROM segment WHERE nom_gene[2] = '$acc_no' AND numero = '$num_segment';";
		my $res = $dbh->selectrow_hashref($query);
		my $nom_segment = $res->{'nom'};
		if ($cdna =~ /c\.[-*]?(\d+[\+-].+_[-*]?\d+[\+-].+)/o){$nom_ivs = $1;$nom_ivs =~ s/\d+([\+-].+)_[-*]?\d+([\+-].+)/IVS$nom_segment$1_IVS$nom_segment$2/og;}
		elsif ($cdna =~ /c\.[-*]?(\d+[\+-][^\+-]+)/o) {$nom_ivs = $1;$nom_ivs =~ s/\d+([\+-][^\+-]+)/IVS$nom_segment$1/og;}
	}
	if ($type_segment eq 'intron' && $type_arn ne 'altered') {
		$nom_prot = 'p.(=)';
	}
	
	
	
	
	if ($taille > 50) {$nom_prot = 'p.?'}
	#print $q->td({'colspan' => '7'}, "$nom_prot-$type_prot-$gene-$true_version-");exit;
	#snp
	if ($nom_ng ne 'NULL') {
		my $snp_query = "SELECT rsid, common FROM restricted_snp WHERE ng_var = '$ng_accno:$nom_ng';";
		if ($nom_ng =~ /d[eu][lp]/o) {$snp_query = "SELECT rsid, common FROM restricted_snp WHERE ng_var like '$ng_accno:$nom_ng%';"}
		my $res_snp = $dbh->selectrow_hashref($snp_query);
		if ($res_snp) {$snp_id  = $res_snp->{rsid};$snp_common = $res_snp->{common};}
		elsif (U2_modules::U2_subs_1::test_myvariant() == 1) {
			my $myvariant = U2_modules::U2_subs_1::run_myvariant($nom_g, 'dbsnp.rsid', $user->getEmail());
			if ($myvariant && exists $myvariant->{'dbsnp'}->{'rsid'} && $myvariant->{'dbsnp'}->{'rsid'} ne '') {$snp_id = $myvariant->{'dbsnp'}->{'rsid'}}
		}
	}
	my $date = U2_modules::U2_subs_1::get_date();
	
	#print $snp_id."<br/>";
	
	#need to run toogows to get seq_wt and seq_mt OR use togows such as in splicing calc
	if ($taille < 50) {
		#get positions
		my ($pos1, $pos2) = U2_modules::U2_subs_3::get_start_end_pos($nom_g);
		#UCSC => $pos1 - 26 (0-based)
		#togows => $pos1 - 25
		my ($x, $y) = ($pos1 - 26, $pos2 + 25);
		my $client = REST::Client->new();
		#print "http://togows.org/api/ucsc/hg19/$chr:$x-$y<br/>";
		#exit;
		
		$client->GET("https://genome-euro.ucsc.edu/cgi-bin/hubApi/getData/sequence?genome=hg19;chrom=chr$chr;start=$x;end=$y");
		#print STDERR $client;
		my $ucsc_response = decode_json($client->responseContent());
		#$client->GET("http://togows.org/api/ucsc/hg19/chr$chr:$x-$y");
		
		#my ($i, $j) = (0, $#seq-25);
		if ($ucsc_response->{'dna'} =~ /^[ATGCatgc]+$/o) {
			# print STDERR "create_variant_vv: UCSC-1 get sequence: $ucsc_response";
		#if ($client->responseContent() =~ /^[ATGC]+$/o) {
			#push my @seq, $client->responseContent();
			my $intermediary_seq = uc($ucsc_response->{'dna'});
			push my (@seq), $intermediary_seq;
			my $strand = U2_modules::U2_subs_1::get_strand($gene, $dbh);
			#print "--$strand--<br/>";
			if ($strand eq 'DESC') {
				my $seqrev = reverse $seq[0];
				$seqrev =~ tr/acgtACGT/tgcaTGCA/;
				$seq[0] = $seqrev;
			}
			#print $seq[0].'<br/>';
			my ($begin, $middle, $end) ;
			($begin, $middle, $end) = (substr($seq[0], 0, 25), substr($seq[0], 25, $#seq-25), substr($seq[0], $#seq-25));
			#print "$begin-$middle-$end<br/>";
			
			if ($cdna =~ />([ATCG])$/o) {#substitutions
				$seq_wt = "$begin $middle $end";
				$seq_mt = "$begin $1 $end";
			}
			elsif ($nom_g =~ /delins([ATGC]+)/) {
				my $exp = '';
				my $exp_size = abs(length($middle)-length($1));
				for (my $i=0;$i<$exp_size;$i++) {$exp.='-'}
				if (length($middle) > length($1)) {
					$seq_wt = "$begin $middle $end";
					$seq_mt = "$begin $1$exp $end";
				}
				else {
					$seq_wt = "$begin $middle$exp $end";
					$seq_mt = "$begin $1 $end";
				}
			}
			elsif ($nom_g =~ /ins([ATGC]+)/) {
				my $exp;
				for (my $i=0;$i<length($1);$i++) {$exp.='-'}
				$seq_wt = "$begin $exp $end";
				$seq_mt = "$begin $1 $end";
			}
			elsif ($nom_g =~ /del/o) {
				$seq_wt = "$begin $middle $end";
				my $exp;
				for (my $i=0;$i<$taille;$i++) {$exp.='-'}
				$seq_mt = "$begin $exp $end";
			}
			elsif ($nom_g =~ /dup/o) {				
				my $exp;
				for (my $i=0;$i<$taille;$i++) {$exp.='-'}
				$seq_wt = "$begin $middle$exp $end";
				$seq_mt = "$begin $middle$middle $end";
			}
		}
		#else {
		#	print STDERR "create_variant_vv: UCSC get sequence: $ucsc_response";
		#}
		#print "$seq_wt<br/>";
		#print "$seq_mt<br/>";
	}
	#to get seq back - requires seq_wt
	if (($type_adn =~ /(deletion|insertion|duplication)/o) && ($taille < 5) && ($cdna =~ /(.+d[eu][lp])$/o)) {
		my $tosend = $seq_mt;
		if ($type_adn eq 'deletion') {$tosend = $seq_wt}								
		my $sequence = U2_modules::U2_subs_1::get_deleted_sequence($tosend);
		if ($cdna =~ /dup/o) {$cdna .= substr($sequence, 0, $taille)}
		else {$cdna .= $sequence}
		if ($nom_ivs ne 'NULL') {$nom_ivs .= $sequence}
	}
	#print "$cdna<br/>";
	my $insert = "INSERT INTO variant(nom, nom_gene, nom_g, nom_ng, nom_ivs, nom_prot, type_adn, type_arn, type_prot, classe, type_segment, num_segment, num_segment_end, taille, snp_id, snp_common, commentaire, seq_wt, seq_mt, type_segment_end, creation_date, referee, nom_g_38, defgen_export) VALUES ('$cdna', '{\"$gene\",\"$acc_no\"}', '$nom_g', '$nom_ng', '$nom_ivs', '$nom_prot', '$type_adn', '$type_arn', '$type_prot', '$classe', '$type_segment', '$num_segment', '$num_segment_end', '$taille', '$snp_id', '$snp_common', 'NULL', '$seq_wt', '$seq_mt', '$type_segment_end', '$date', '".$user->getName()."', '$nom_g_38', '$defgen_export');";
	$insert =~ s/'NULL'/NULL/og;
	#die $insert;
	#print STDERR $insert;
	$error .= "NEWVAR: $insert\n";
	#print $q->td({'colspan' => '7'}, $insert);exit;
	$dbh->do($insert) or die "Variant already recorded, there must be a mistake somewhere $!";
	return ($error, $type_segment, $classe, $cdna);
	#if ($id ne '') {									
	#	$insert = "INSERT INTO variant2patient (nom_c, num_pat, id_pat, nom_gene, type_analyse, statut, allele, denovo) VALUES ('$cdna', '$number', '$id', '{\"$gene\",\"$acc_no\"}', '$technique', '$status', '$allele', '$denovo');\n";
	#	print $insert;
	#	$dbh->do($insert) or die "Variant already recorded for the patient, there must be a mistake somewhere $!";
	#}
}


1;