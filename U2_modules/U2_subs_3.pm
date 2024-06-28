package U2_modules::U2_subs_3;
BEGIN {delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV', 'PATH'};}
use strict;
use warnings;
use Data::Dumper;
use U2_modules::U2_init_1;
use U2_modules::U2_subs_1;
use REST::Client;
use JSON;

#hg38 transition variable for postgresql 'start_g' segment field
my ($postgre_start_g, $postgre_end_g) = ('start_g_38', 'end_g_38');  #hg19 style
my $config_file = U2_modules::U2_init_1->getConfFile();
my $config = U2_modules::U2_init_1->initConfig();
$config->file($config_file);# or die $!;
my $ANALYSIS_ILLUMINA_PG_REGEXP = $config->ANALYSIS_ILLUMINA_PG_REGEXP();
my $ABSOLUTE_HTDOCS_PATH = $config->ABSOLUTE_HTDOCS_PATH();
my $PYTHON = $config->PYTHON_PATH();
# my $PYTHON3 = $config->PYTHON3_PATH();
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
	#print STDERR "$PYTHON $path/liftover$way.py chr$chr $pos";
	#my ($chr_tmp2, $s) = split(/,/, `$PYTHON $path/liftover$way.py "chr$chr" $pos`);
	my ($chr_tmp2, $s) = split(/,/, `$PYTHON $path/liftover.py $path/$chain "chr$chr" $pos`);
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
				my $query = "SELECT gene_symbol as gene_name, acc_g, mutalyzer_acc, mutalyzer_version FROM gene WHERE refseq = '$acc' AND main = 't' AND acc_version = '$ver';";
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

sub build_hgvs_from_illumina {
	my ($var_chr, $var_pos, $var_ref, $var_alt) = @_;
	# we keep only the first variants if more than 1 e.g. alt = TAA, TA
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

	my ($value, $genome_version, $number, $id, $analysis, $status, $allele, $var_dp, $var_vf, $var_filter, $dbh) = @_;
	#print STDERR $value."\n";
	if ($value =~ /(.+d[eu][lp])[ATCG]+$/) {$value = $1} # we remove what is deleted or duplicated
	my $nom_g = $genome_version eq 'hg19' ? 'nom_g' : 'nom_g_38';
	my $query = "SELECT a.nom, b.refseq FROM variant a, gene b WHERE a.refseq = b.refseq AND a.$nom_g = '$value' AND b.\"$analysis\" = 't';";
	# my $query = "SELECT nom, refseq FROM variant WHERE $nom_g = '$value';";
	# print STDERR "Query for direct submission (inside): $query\n";
	my $res = $dbh->selectrow_hashref($query);
	if ($res) {
		# print STDERR "Direct submission res (inside): $res->{'nom'}\n";
		my $last_check = "SELECT nom_c FROM variant2patient WHERE id_pat = '$id' AND num_pat = '$number' AND type_analyse = '$analysis' AND nom_c = '$res->{'nom'}' AND refseq = '".$res->{'refseq'}."';";
		# print STDERR "last check l790 U2_sbs_3.pm $last_check\n";
		my $res_last_check = $dbh->selectrow_hashref($last_check);
		# print STDERR "Last check direct submission l792 U2_sbs_3.pm : $res_last_check\n";
		if (!$res_last_check || $res_last_check eq '0E0') {
			return "INSERT INTO variant2patient (nom_c, num_pat, id_pat, refseq, type_analyse, statut, allele, depth, frequency, msr_filter) VALUES ('$res->{'nom'}', '$number', '$id', '$res->{'refseq'}', '$analysis', '$status', '$allele', '$var_dp', '$var_vf', '$var_filter');";
		}
		else {
			# variant already there
			# print STDERR "WARNING: variant already recorded: $nom_g - l797\n";
			return 'WARNING: variant already recorded';
		}
	}
	else {
		# print STDERR "INFO unknown variant $nom_g - l802\n";
		return '';
	}
}

sub direct_submission_prepare {
	# https://docstore.mik.ua/orelly/linux/dbi/ch05_05.htm
	my ($value, $genome_version, $number, $id, $analysis, $dbh) = @_;
	if ($value =~ /(.+d[eu][lp])[ATCG]+$/) {$value = $1} # we remove what is deleted or duplicated
	my $nom_g = $genome_version eq 'hg19' ? 'nom_g' : 'nom_g_38';
	my $query = "SELECT a.nom, b.refseq, b.gene_symbol FROM variant a, gene b WHERE a.refseq = b.refseq AND a.$nom_g = '$value' AND b.\"$analysis\" = 't';";
	# print STDERR "Query for direct submission (inside): $query-l132\n";
	my $res = $dbh->selectrow_hashref($query);
	if ($res) {
		my $last_check = "SELECT nom_c FROM variant2patient WHERE id_pat = '$id' AND num_pat = '$number' AND type_analyse = '$analysis' AND nom_c = '$res->{'nom'}' AND refseq = '".$res->{'refseq'}."';";
		my $res_last_check = $dbh->selectrow_hashref($last_check);
		if (!$res_last_check || $res_last_check eq '0E0') {
			return ($res->{'nom'}, $res->{'gene_symbol'}, $res->{'refseq'})
		}
		else {return '';}
	}
	else {return '';}
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

sub build_roi {
	my ($dbh, $start, $end) = @_;
	##we built a hash with 'start, stop' => chr for each gene
	# SELECT a.chr, MIN(LEAST(b.start_g, b.end_g)) as min, MAX(GREATEST(b.start_g, b.end_g)) as max FROM gene a, segment b WHERE a.nom[1] = b.nom_gene[1] AND a.ns_gene = 't' AND (b.type LIKE '%UTR' OR b.type = 'intergenic') GROUP BY a.nom[1], a.chr ORDER BY a.chr, min ASC;";
	# my $query = "SELECT a.chr, MIN(LEAST(b.$start, b.$end)) as min, MAX(GREATEST(b.$start, b.$end)) as max FROM gene a, segment b WHERE a.refseq = b.refseq AND a.ns_gene = 't' AND (b.type LIKE '%UTR' OR b.type = 'intergenic') GROUP BY a.gene_symbol, a.chr ORDER BY a.chr, min ASC;";
	# exclude outside gene regions
	my $query = "SELECT a.chr, MIN(LEAST(b.$start, b.$end)) as min, MAX(GREATEST(b.$start, b.$end)) as max FROM gene a, segment b WHERE a.refseq = b.refseq AND a.ns_gene = 't' AND (b.type NOT LIKE '%UTR' OR b.type = 'intergenic') GROUP BY a.gene_symbol, a.chr ORDER BY a.chr, min ASC;";
	my $sth = $dbh->prepare($query);
	my $res = $sth->execute();

	my %intervals;
	while (my $result = $sth->fetchrow_hashref()) {$intervals{"$result->{'min'}-$result->{'max'}"} = $result->{'chr'}}
	return \%intervals;
}

sub compute_approx_panel_size {
	my ($dbh, $analysis_type) = shift;
	my $query = "SELECT SUM(a.end_g - a.start_g + 1) FROM segment a, gene b WHERE a.refseq = b.refseq AND b.ns_gene = 't' AND b.\"$analysis_type\" = 't' and b.main = 't';";
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

	my @colors = ('sand', 'khaki', 'yellow', 'amber', 'orange', 'deep-orange', 'red', 'pink', 'purple', 'deep-purple', 'indigo', 'blue', 'light-blue','sand', 'khaki', 'yellow', 'amber', 'orange', 'deep-orange', 'red', 'pink', 'purple', 'deep-purple', 'indigo', 'blue', 'light-blue');

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
		my $list_context = "('$id', '$number', 'original sample')";
		my $sth2 = $dbh->prepare($query2);
		my $res2 = $sth2->execute();
		if ($res2 ne '0E0') {
			while (my $result2 = $sth2->fetchrow_hashref()) {
				if ($dob =~ /^\d{4}-\d{2}-\d{2}$/o && $result2->{'date_of_birth'} =~ /^\d{4}-\d{2}-\d{2}$/o) {
					if ($dob eq $result2->{'date_of_birth'}) {
						$list_context .= ", ('$result2->{'identifiant'}', '$result2->{'numero'}', 'Valid DoB')";
						$list .= ", ('$result2->{'identifiant'}', '$result2->{'numero'}')";
					}
				}
				else {
					$list_context .= ", ('$result2->{'identifiant'}', '$result2->{'numero'}', 'No DoB')";
					$list .= ", ('$result2->{'identifiant'}', '$result2->{'numero'}')";
				}
			}
		}
		return $list, $list_context, $first_name, $last_name;
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
								$q->input({'type' => 'text', 'name' => 'new_variant', 'id' => 'new_variantblue', 'value' => 'c.', 'size' => '20', 'maxlength' => '100'})."\n".
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
	# print STDERR Dumper($vv_results);
	my $error = '';
	foreach my $key (keys %{$vv_results}) {
		# print STDERR "$key\n";
		# if ($key ne 'metadata' && $key ne 'flag' && ($key eq $vvkey || $key =~ /validation_warning/o )) {
		my $valid_key;
		if ($key ne 'metadata' && $key ne 'flag' && ($key =~ /^$acc_no\.$acc_ver:c\.[\dACGTdienulpsv_>\+\*-]+$/ || $key =~ /validation_warning/o )) {
			# print STDERR $key."-$vv_results->{$key}-\n";
			if (ref($vv_results->{$key}) eq ref {}) {
				foreach my $key2 (keys(%{$vv_results->{$key}})) {
					# print STDERR $key2."\n";
					if ($key2 eq 'validation_warnings') {
						my $text = '';
						foreach my $warning (@{$vv_results->{$key}->{$key2}}) {
							# print STDERR "WARNING: $vvkey : $warning : $calling\n";
							if ($warning eq "$acc_no.$acc_ver:$cdna") {
								#bad wt  nt sometimes validation_warnings = key directly
								$text = "VariantValidator error: $warning".$vv_results->{$key}->{'validation_warnings'}[1];
							}
							elsif ($warning =~ /length must be/o) {$text .= "VariantValidator error for $cdna : $warning"}
							elsif ($warning =~ /RefSeqGene record not available/o) {$nom_ng = 'NULL'}
							elsif ($warning =~ /does not agree with reference/o) {$text .= "VariantValidator error for $cdna ($warning): ".$vv_results->{$key}->{'validation_warnings'}[0]}
							elsif ($warning =~ /automapped to $acc_no\.$acc_ver:(c\..+)/g) {
								if ($calling eq 'web') {
									$text .= $q->span("VariantValidator reports that your variant should be $1 instead of $cdna");
									# print STDERR "WARNING: $vvkey : $warning : $text\n";
								}
								elsif($calling =~ /background/o) {$text .= "VariantValidator error for $cdna : $warning"}
							}
						}
						if ($text ne '') {
							if ($calling eq 'web') {
								# print STDERR "WARNING: $vvkey : $text\n";
								print U2_modules::U2_subs_2::danger_panel($text, $q);
								exit;
							}
							elsif($calling =~ /background/o) {$error .= "ERROR: $text\n"; return $error}
						}
					}
				}
			}
		}

		if ($calling eq 'web' && !$vv_results->{$vvkey}) {#VV changed variant name (ex with delAGinsT)
			if (ref($vv_results->{$key}) eq ref {} && $vv_results->{$key}->{'submitted_variant'} eq $vvkey) {$vvkey = $key;print "<br/>".$vv_results->{$key}->{'submitted_variant'}."<br/>"}
		}


	}
	#print $vv_results->{$vvkey}->{'primary_assembly_loci'}->{'hg19'}->{'hgvs_genomic_description'}."--<br/>";#->{'hgvs_genomic_description'}
	my @full_nom_g_38 = split(/:/, $vv_results->{$vvkey}->{'primary_assembly_loci'}->{'hg38'}->{'hgvs_genomic_description'});
	if ($full_nom_g_38[0] =~ /NC_0+([^0]{1,2}0?)\.\d{1,2}$/o) {
		$chr = $1;
		if ($chr == 23) {$chr = 'X'}
		elsif ($chr == 24) {$chr = 'Y'}
		$nom_g_38 = "chr$chr:".pop(@full_nom_g_38);
	}
	else {
		my $text = "There has been an issue with VariantValidator. Please double check your variant and resubmit. If this issue persists, contact an admin. \nDEBUG: ".$full_nom_g_38[0].":".$full_nom_g_38[1]."-\$vvresults:".Dumper($vv_results);
		if ($calling eq 'web') {
			print U2_modules::U2_subs_2::danger_panel($text, $q);
			exit;
		}
		elsif($calling =~ /background(.+)/o) {$error .= "ERROR: $text-$vvkey-$1\n"; return $error}
	}#"Pb with variantvalidator full_nom_g_19: $full_nom_g_19[0]"}
	#print "<br/>".$nom_g."<br/>";

	if (defined($vv_results->{$vvkey}->{'primary_assembly_loci'}->{'hg19'}->{'hgvs_genomic_description'}) && $vv_results->{$vvkey}->{'primary_assembly_loci'}->{'hg19'}->{'hgvs_genomic_description'} ne '') {
		$nom_g = "chr$chr:".(split(/:/, $vv_results->{$vvkey}->{'primary_assembly_loci'}->{'hg19'}->{'hgvs_genomic_description'}))[1];
		#print $nom_g_38."<br/>";
	}
	else {#SLOW
		print STDERR "Liftovering variant $nom_g\n";
		my $chr_tmp = "chr$chr";
		if ($nom_g_38 =~ /g\.(\d+)_(\d+)([^\d]+)$/o) {
			my ($s38, $e38, $rest) = ($1, $2, $3);
			my $s19 = U2_modules::U2_subs_3::liftover($s38, $chr_tmp, $ABSOLUTE_HTDOCS_PATH, $U2_modules::U2_subs_3::HG38TOHG19CHAIN);
			my $e19 = U2_modules::U2_subs_3::liftover($e38, $chr_tmp, $ABSOLUTE_HTDOCS_PATH, $U2_modules::U2_subs_3::HG38TOHG19CHAIN);
			if ($s19 eq 'f' || $e19 eq 'f') {$nom_g = 'NULL'}
			else {$nom_g = "$chr_tmp:g.".$s19."_$e19$rest"}
		}
		elsif ($nom_g_38 =~ /g\.(\d+)([^\d]+)$/o) {
			my ($s38, $rest) = ($1, $2);
			my $s19 = U2_modules::U2_subs_3::liftover($s38, $chr_tmp, $ABSOLUTE_HTDOCS_PATH, $U2_modules::U2_subs_3::HG38TOHG19CHAIN);
			if ($s19 eq 'f') {$nom_g = 'NULL'}
			else {$nom_g = "$chr_tmp:g.$s19$rest"}
		}
	}
	#print $nom_g_38."<br/>";

	if ($nom_g_38 =~ />/o) {$type_adn = 'substitution'}
	elsif ($nom_g_38 =~ /delins/o) {$type_adn = 'indel'}
	elsif ($nom_g_38 =~ /del/o) {$type_adn = 'deletion'}
	elsif ($nom_g_38 =~ /ins/o) {$type_adn = 'insertion'}
	elsif ($nom_g_38 =~ /dup/o) {$type_adn = 'duplication'}
	elsif ($nom_g_38 =~ /inv/o) {$type_adn = 'inversion'}
	#print $type_adn."<br/>";
	#my @full_nom_ng = split(/:/, $vv_results->{"$acc_no.$acc_ver:$cdna"}->{'hgvs_refseqgene_variant'});
	#$nom_ng = pop(@full_nom_ng);
	if ($vv_results->{$vvkey}->{'hgvs_refseqgene_variant'} ne '') {$nom_ng = (split(/:/, $vv_results->{$vvkey}->{'hgvs_refseqgene_variant'}))[1]};
	if (!defined($nom_g)) {$nom_ng = 'NULL'}
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
	# if ($nom_prot =~ /Ter/o) {$nom_prot =~ s/Ter/\*/o}
	#print $nom_prot."<br/>";
	#print $type_prot."<br/>";
	my $res;
	#taille num, type segment + end
	if ($nom_g_38 =~ /^chr\w+:g\.(\d+)_(\d+)[^\d]+$/o) {
		#>1bp event
		my ($start, $end) = ($1, $2);
		$taille = $end-$start+1;
		my $query = "SELECT numero, type FROM segment WHERE refseq = '$acc_no' AND $start BETWEEN SYMMETRIC $postgre_start_g AND $postgre_end_g AND $end BETWEEN SYMMETRIC $postgre_start_g AND $postgre_end_g;";
		#print STDERR "$query\n";
		$res = $dbh->selectrow_hashref($query);
		if ($res) {$num_segment_end = $num_segment = $res->{'numero'};$type_segment_end = $type_segment = $res->{'type'};}
		else {
			my $strand = U2_modules::U2_subs_1::get_strand($gene, $dbh);#strand is ASC (+) or DESC (-)
			my $query = "SELECT numero, type FROM segment WHERE refseq = '$acc_no' AND $start BETWEEN SYMMETRIC $postgre_start_g AND $postgre_end_g;";

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
			$query = "SELECT numero, type FROM segment WHERE refseq = '$acc_no' AND $end BETWEEN SYMMETRIC $postgre_start_g AND $postgre_end_g;";
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
	elsif ($nom_g_38 =~ /^chr\w+:g\.(\d+)[^\d]+$/o) {
		#1bp event
		my $pos = $1;
		$taille = 1;
		my $query = "SELECT numero, type FROM segment WHERE refseq = '$acc_no' AND $pos BETWEEN SYMMETRIC $postgre_start_g AND $postgre_end_g;";
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
		my $query = "SELECT nom FROM segment WHERE refseq = '$acc_no' AND numero = '$num_segment';";
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
	if (!defined($nom_ng)) {$nom_ng = 'NULL'}
	if ($nom_ng ne 'NULL') {
		my $snp_query = "SELECT rsid, common FROM restricted_snp WHERE ng_var = '$ng_accno:$nom_ng';";
		if ($nom_ng =~ /d[eu][lp]/o) {$snp_query = "SELECT rsid, common FROM restricted_snp WHERE ng_var like '$ng_accno:$nom_ng%';"}
		my $res_snp = $dbh->selectrow_hashref($snp_query);
		if ($res_snp) {$snp_id  = $res_snp->{rsid};$snp_common = $res_snp->{common};}
		# elsif (U2_modules::U2_subs_1::test_myvariant() == 1) {
		# 	# myvariant runs hg19 (https://myvariant.info/v1/api#/variant/get_variant__id_)
		# 	my $myvariant = U2_modules::U2_subs_1::run_myvariant($nom_g, 'dbsnp.rsid', $user->getEmail());
		# 	if ($myvariant && exists $myvariant->{'dbsnp'}->{'rsid'} && $myvariant->{'dbsnp'}->{'rsid'} ne '') {$snp_id = $myvariant->{'dbsnp'}->{'rsid'}}
		# }
	}
	if ($snp_id eq 'NULL' && $nom_ng eq 'NULL') {
		if (U2_modules::U2_subs_1::test_myvariant() == 1) {
			# myvariant runs hg19 (https://myvariant.info/v1/api#/variant/get_variant__id_)
			my $myvariant = U2_modules::U2_subs_1::run_myvariant($nom_g, 'dbsnp.rsid', $user->getEmail());
			if ($myvariant && exists $myvariant->{'dbsnp'}->{'rsid'} && $myvariant->{'dbsnp'}->{'rsid'} ne '') {$snp_id = $myvariant->{'dbsnp'}->{'rsid'}}
		}
	}
	my $date = U2_modules::U2_subs_1::get_date();

	# print $snp_id."<br/>";

	# need to run toogows to get seq_wt and seq_mt OR use togows such as in splicing calc
	if ($taille < 50) {
		# get positions
		my ($pos1, $pos2) = &get_start_end_pos($nom_g_38);
		# UCSC => $pos1 - 26 (0-based)
		# togows => $pos1 - 25
		my ($x, $y) = ($pos1 - 26, $pos2 + 25);
		my $strand = U2_modules::U2_subs_1::get_strand($gene, $dbh);

		######## startbugfix david 20210215 - del/dups on strand- could get bad sequences
		if ($strand eq 'DESC' && $nom_g_38 !~ /\dins([ATGC]+)/o && $cdna !~ />([ATCG])$/o) {
			# not for true ins or substitutions
			# on strand - need to maybe switch sequence
			# get VV genomic VCF pos
			# "grch37": {
			#	"hgvs_genomic_description": "NC_000010.10:g.55892721_55892724del", # => HGVS en 3'
			#	"vcf": {
			#	  "alt": "T",
			#	  "chr": "10",
			#	  "pos": "55892718",
			# and add the length of del/dup (0-based)
			my $pos_vcf = $vv_results->{$vvkey}->{'primary_assembly_loci'}->{'hg38'}->{'vcf'}->{'pos'};
			if ($cdna =~ /delins([ATGC]+)/o) {$pos_vcf--}
			($x, $y) = ($pos_vcf - 25, $pos_vcf + $taille + 25);
		}
		######## endbugfix
		my @seq = `$PYTHON $ABSOLUTE_HTDOCS_PATH/getTwoBitSeq.py chr$chr $x $y hg38`;
		chomp(@seq);
		#my ($i, $j) = (0, $#seq-25);
		# UCSC
		# if ($ucsc_response->{'dna'} =~ /^[ATGCatgc]+$/o) {
			# print STDERR "create_variant_vv: UCSC-1 get sequence: $ucsc_response";
		# togows
		# if ($client->responseContent() =~ /^[ATGC]+$/o) {
			# togows
			# push my @seq, $client->responseContent();
			# UCSC
			# my $intermediary_seq = uc($ucsc_response->{'dna'});
			# push my (@seq), $intermediary_seq;

		#print "--$strand--<br/>";
		if ($strand eq 'DESC') {
			my $seqrev = reverse $seq[0];
			$seqrev =~ tr/acgtACGT/tgcaTGCA/;
			$seq[0] = $seqrev;
		}
		#print $seq[0].'<br/>';
		my ($begin, $middle, $end);
		my $marker = 25;
		if ($type_adn eq 'insertion') {$marker = 26}
		($begin, $middle, $end) = (substr($seq[0], 0, $marker), substr($seq[0], $marker, $#seq-$marker), substr($seq[0], $#seq-$marker));
		#print "$begin-$middle-$end<br/>";

		if ($cdna =~ />([ATCG])$/o) {#substitutions
			$seq_wt = "$begin $middle $end";
			$seq_mt = "$begin $1 $end";
		}
		elsif ($cdna =~ /delins([ATGC]+)/o) {
			my $exp = '';
			my $seqins = $1;
			my $exp_size = abs(length($middle)-length($seqins));
			for (my $i=0;$i<$exp_size;$i++) {$exp.='-'}

			if (length($middle) > length($seqins)) {
				$seq_wt = "$begin $middle $end";
				$seq_mt = "$begin $seqins$exp $end";
			}
			else {
				$seq_wt = "$begin $middle$exp $end";
				$seq_mt = "$begin $seqins $end";
			}
		}
		elsif ($cdna =~ /ins([ATGC]+)/o) {
			my $exp = '';
			my $seqins = $1;
			for (my $i=0;$i<length($seqins);$i++) {$exp.='-'}
			$seq_wt = "$begin $exp $end";

			$seq_mt = "$begin $seqins $end";
		}
		elsif ($nom_g_38 =~ /del/o) {
			$seq_wt = "$begin $middle $end";
			my $exp;
			for (my $i=0;$i<$taille;$i++) {$exp.='-'}
			$seq_mt = "$begin $exp $end";
		}
		elsif ($nom_g_38 =~ /dup/o) {
			my $exp;
			for (my $i=0;$i<$taille;$i++) {$exp.='-'}
			$seq_wt = "$begin $middle$exp $end";
			$seq_mt = "$begin $middle$middle $end";
		}

	}
	#to get seq back - requires seq_wt
	if (($type_adn =~ /(deletion|insertion|duplication)/o) && ($taille < 5) && ($cdna =~ /(.+d[eu][lp])$/o)) {
		my $tosend = $seq_mt;
		if ($type_adn eq 'deletion') {$tosend = $seq_wt}
		my $sequence = U2_modules::U2_subs_1::get_deleted_sequence($tosend);
		if ($cdna =~ /dup/o) {$cdna .= substr($sequence, 0, $taille)}
		else {$cdna .= $sequence}
		if ($nom_ivs ne 'NULL') {
			if ($cdna =~ /dup/o) {$nom_ivs .= substr($sequence, 0, $taille)}
			else {$nom_ivs .= $sequence}
		}
	}
	#print "$cdna<br/>";
	#check for the last time if the variant exists (may be an interpretation difference between VV and mutalyzer)
	my $last_check = "SELECT nom_g_38 FROM variant WHERE nom = '$cdna' and refseq = '$acc_no';";
	my $res_last_check = $dbh->selectrow_hashref($last_check);
	if ($res_last_check->{'nom_g_38'}) {
		# print STDERR "Last check U2:".$res_last_check->{'nom_g'}."-VV:$nom_g-\n";
		if ($res_last_check->{'nom_g_38'} ne $nom_g_38) {
			$error .= "ERROR Mutalyzer/VV difference for variant $cdna in gene $gene: mutalyzer nom_g_38: '".$res_last_check->{'nom_g_38'}."', new vv: '$nom_g_38' - UPDATE U2 with new c_name from VV\n";
			# UPDATE and return no error 
			my $update = "UPDATE variant SET nom_g_38 = '$nom_g_38', nom_g = '$nom_g' WHERE refseq = '$acc_no' AND nom = '$cdna'";
			$error .= "NEWVAR: $update\n";
			$dbh->do($update) or die "Update impossible, there must be a mistake somewhere $!";
			return ($error, $type_segment, $classe, $cdna);
		}
		else {

		}
	}

	my $insert = "INSERT INTO variant(nom, refseq, nom_g, nom_ng, nom_ivs, nom_prot, type_adn, type_arn, type_prot, classe, type_segment, num_segment, num_segment_end, taille, snp_id, snp_common, commentaire, seq_wt, seq_mt, type_segment_end, creation_date, referee, nom_g_38, defgen_export) VALUES ('$cdna', '$acc_no', '$nom_g', '$nom_ng', '$nom_ivs', '$nom_prot', '$type_adn', '$type_arn', '$type_prot', '$classe', '$type_segment', '$num_segment', '$num_segment_end', '$taille', '$snp_id', '$snp_common', 'NULL', '$seq_wt', '$seq_mt', '$type_segment_end', '$date', '".$user->getName()."', '$nom_g_38', '$defgen_export');";
	$insert =~ s/'NULL'/NULL/og;
	#die $insert;
	# print STDERR "$insert\n";
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
