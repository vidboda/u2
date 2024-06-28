BEGIN {delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV', 'PATH'};}

use strict;
#use CGI;#in startup.pl
#use DBI;
#use AppConfig qw(:expand :argcount);
use File::Temp;
use List::Util qw(min max);
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
#		script to prioritize variants (missens or splicing)sfrom predictors and MAF

##EXTENDED init of USHVaM 2 perl scripts: jquery UI + databases PATH
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
my $EXE_PATH = $config->EXE_PATH();
my $CSS_PATH = $config->CSS_PATH();
my $CSS_DEFAULT = $config->CSS_DEFAULT();
my $JS_PATH = $config->JS_PATH();
my $JS_DEFAULT = $config->JS_DEFAULT();
my $HTDOCS_PATH = $config->HTDOCS_PATH();
my $DATABASES_PATH = $config->DATABASES_PATH();
# my $DALLIANCE_DATA_DIR_PATH = $config->DALLIANCE_DATA_DIR_PATH();
my $EXE_PATH = $config->EXE_PATH();
my $DBNSFP_V2 = $config->DBNSFP_V2();
my $DBNSFP_V3_PATH = $config->DBNSFP_V3_PATH();

$ENV{PATH} = $DATABASES_PATH;

my @styles = ($CSS_PATH.'font-awesome.min.css', $CSS_PATH.'w3.css', $CSS_DEFAULT, $CSS_PATH.'fullsize/fullsize.css', $CSS_PATH.'jquery.alerts.css', $CSS_PATH.'jquery-ui-1.12.1.min.css', $CSS_PATH.'datatables.min.css');

my $q = new CGI;

my $dbh = DBI->connect(    "DBI:Pg:database=$DB;host=$HOST;",
                        $DB_USER,
                        $DB_PASSWORD,
                        {'RaiseError' => 1}
                ) or die $DBI::errstr;


print $q->header(-type => 'text/html', -'cache-control' => 'no-cache'),
	$q->start_html(-title=>"Variants prioritization",
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
				-src => $JS_PATH.'jquery-ui-1.12.1.min.js', 'defer' => 'defer'},
				{-language => 'javascript',
				-src => $JS_PATH.'datatables.min.js', 'defer' => 'defer'},
				{-language => 'javascript',
				-src => $JS_PATH.'jquery.alerts.js', 'defer' => 'defer'},
                                {-language => 'javascript',
                                -src => $JS_PATH.'jquery.autocomplete.min.js', 'defer' => 'defer'},
                                {-language => 'javascript',
                                -src => $JS_DEFAULT, 'defer' => 'defer'}],
                        -encoding => 'ISO-8859-1');

my $user = U2_modules::U2_users_1->new();


U2_modules::U2_subs_1::standard_begin_html($q, $user->getName(), $dbh);

##end of Basic init


#we get a sample as param
my ($id, $number) = U2_modules::U2_subs_1::sample2idnum(uc($q->param('sample')), $q);

#need to get info on patients (for multiple samples)
my ($list, $list_context, $first_name, $last_name) = U2_modules::U2_subs_3::get_sampleID_list($id, $number, $dbh) or die "No sample info $!";

my $analysis = 'Missense';
if ($q->param('type') eq 'splicing') {$analysis = 'Splicing'}


#get missense list
#consider fiters
my $filter = U2_modules::U2_subs_3::get_filter_from_idlist($list, $dbh);


print $q->start_p({'class' => 'center'}), $q->start_big(), $q->span("Sample "), $q->strong({'onclick' => "window.location = 'patient_file.pl?sample=$id$number'", 'class' => 'pointer'}, $id.$number), $q->span(": $analysis prioritization for "), $q->strong("$first_name $last_name"), $q->end_big(), $q->end_p(), $q->br(), $q->br();


if ($analysis eq 'Missense') {

	my $query_missense = "SELECT a.nom, d.gene_symbol, d.refseq, a.nom_prot, a.nom_g, a.nom_g_38, b.statut, d.rp, d.dfn, d.usher FROM variant a, variant2patient b, patient c, gene d  WHERE a.nom = b.nom_c AND a.refseq = b.refseq AND b.num_pat = c.numero AND b.id_pat = c.identifiant AND b.refseq = d.refseq AND c.first_name = '$first_name' AND c.last_name = '$last_name' AND a.type_prot = 'missense' AND a.classe = 'unknown' AND (d.gene_symbol, a.num_segment) NOT IN (('DSPP', '5')) GROUP BY a.nom, d.gene_symbol, d.refseq, a.nom_prot, a.nom_g, a.nom_g_38, b.statut, d.rp, d.dfn, d.usher ORDER BY d.gene_symbol, a.nom_g;";
	#print $query_missense;
	my $sth2 = $dbh->prepare($query_missense);
	my $res2 = $sth2->execute();
	my $color = U2_modules::U2_subs_1::color_by_classe('unknown', $dbh);
	if ($res2 ne '0E0') {
		#we have some missense
		my $filtered_missense = 0;
		my $text = $q->span('You will find below a table ranking all ').$q->strong('unknown').$q->span(" missense variants reported for $first_name $last_name, except variants occuring in filtered genes AND variants occuring in DSPP exon 5.");
		print U2_modules::U2_subs_2::info_panel($text, $q);
		$text = $q->span('Up to Six items can be considered to prioritize the variants, 4 predictors, MAX MAF and Clinvar annotation').$q->br().
				$q->span(' The \'score\' column goes from 0 to 6 (the higher the more probably pathogenic), as well as the \'Pathogenic Ratio\', ').
				$q->span(' which is the ratio between the score and the total number of available items. To gain a point in the score column, variants must either:')."\n".
		$q->start_ul().
			$q->li('have a SIFT prediction below 0.05').
			$q->li('have a polyphen prediction being above 0.447').
			$q->li('have a FATHMM prediction below -1.5').
			$q->li('have a MetaLR prediction above 0.5').
			$q->li('be reported in ClinVar as \'likely pathogenic\' or \'pathogenic\'').
			$q->li('have a MAX_MAF below 0.005 (same for dominants and recessives), MAX_MAF being the maximum between ExAC, EVS_EA, EVS_AA and 1000 genomes MAFs.').
		$q->end_ul();
		print U2_modules::U2_subs_2::info_panel($text, $q);


		print $q->start_div({'class' => 'w3-container'}), $q->start_table({'class' => "technical great_table", 'id' => 'priorisation_table'}), $q->caption("Missense table:"), $q->start_thead(),
			$q->start_Tr(), "\n",
				$q->th({'class' => 'left_general'}, 'gene'), "\n",
				$q->th({'class' => 'left_general'}, 'DNA'), "\n",
				$q->th({'class' => 'left_general'}, 'Protein'), "\n",
				$q->th({'class' => 'left_general'}, 'Status'), "\n",
				$q->th({'class' => 'left_general'}, 'SIFT'), "\n",
				$q->th({'class' => 'left_general'}, 'Polyphen 2'), "\n",
				$q->th({'class' => 'left_general'}, 'FATHMM'), "\n",
				$q->th({'class' => 'left_general'}, 'MetaLR'), "\n",
				$q->th({'class' => 'left_general'}, 'ClinVar'), "\n",
				$q->th({'class' => 'left_general'}, 'MAX_MAF'), "\n",
				$q->th({'class' => 'left_general'}, 'Score'), "\n",
				$q->th({'class' => 'left_general'}, 'Pathogenic Ratio'), "\n",
				$q->end_Tr(), $q->end_thead(), $q->start_tbody(),  "\n";
		my $tempfile = File::Temp->new();
		my $hash;
		while (my $result2 = $sth2->fetchrow_hashref()) {
			if ($filter eq 'RP' && $result2->{'rp'} == 0) {$filtered_missense++;next;}
			elsif ($filter eq 'DFN' && $result2->{'dfn'} == 0) {$filtered_missense++;next;}
			elsif ($filter eq 'USH' && $result2->{'usher'} == 0) {$filtered_missense++;next;}
			elsif ($filter eq 'DFN-USH' && ($result2->{'dfn'} == 0 && $result2->{'usher'} == 0)) {$filtered_missense++;next;}
			elsif ($filter eq 'RP-USH' && ($result2->{'rp'} == 0 && $result2->{'usher'} == 0)) {$filtered_missense++;next;}
			elsif ($filter eq 'CHM' && $result2->{'gene_symbol'} ne 'CHM') {$filtered_missense++;next;}

			#ok we're done with boring stuff let's do some new things
			#my $tempfile = File::Temp->new(UNLINK => 1);
			my $semaph = 0;

			$result2->{'nom_g'} =~ /chr($U2_modules::U2_subs_1::CHR_REGEXP):g\.(\d+)([ATGC])>([ATGC])/o;
			my ($chr, $position, $ref, $alt) = ($1, $2, $3, $4);
			my @dbnsfp =  split(/\n/, `$EXE_PATH/tabix $DATABASES_PATH$DBNSFP_V2 $chr:$position-$position`);
			&dbnsfp2html(\@dbnsfp, $ref, $alt, 83, 93, 92, 101, 115, 26, 32, 44, 50, $result2->{'gene_symbol'}, $id, $number, $result2->{'refseq'}, $result2->{'nom'}, $result2->{'nom_prot'}, $result2->{'statut'});
      #dbnsfp, ref, alt, onekg, espea, espaa, exac_maf, clinvar, sift, polyphen, fathmm, metalr, gene, id_patient, number_patient, NM_accno, var c., var p., status
			if ($#dbnsfp > -1) {$semaph = 1}
			#}
		}
		print $q->end_tbody(), $q->end_table(), $q->end_div(), "\n", $q->br(), $q->br(), $q->br();

	}
	else {print $q->p('No unknown missense to test for this patient');}#$query_missense;}
}
elsif ($analysis eq 'Splicing') {
	my $query_splicing = "SELECT a.nom, a.nom_ivs, a.nom_prot, d.gene_symbol, d.refseq, a.nom_g, b.statut, d.rp, d.dfn, d.usher FROM variant a, variant2patient b, patient c, gene d  WHERE a.nom = b.nom_c AND a.refseq = b.refseq AND b.num_pat = c.numero AND b.id_pat = c.identifiant AND b.refseq = d.refseq AND c.first_name = '$first_name' AND c.last_name = '$last_name' AND a.classe = 'unknown' AND (d.gene_symbol, a.num_segment) NOT IN (('DSPP', '5')) GROUP BY a.nom, a.nom_ivs, a.nom_prot, d.gene_symbol, d.refseq, a.nom_g, b.statut, d.rp, d.dfn, d.usher ORDER BY d.gene_symbol, a.nom_g;";
	#print $query_missense;
	my $sth2 = $dbh->prepare($query_splicing);
	my $res2 = $sth2->execute();
	my $color = U2_modules::U2_subs_1::color_by_classe('unknown', $dbh);
	if ($res2 ne '0E0') {
		#we have some candidates
		my $filtered_missense = 0;
		my $text = $q->span('You will find below a table ranking all ').
			$q->strong('unknown').
			$q->span(" variants reported for $first_name $last_name, except variants occuring in filtered genes AND variants occuring in DSPP exon 5.");
		print U2_modules::U2_subs_2::info_panel($text, $q);

		$text = $q->span('They are ranked according to their ability to disturb proper splicing according to ').
			$q->a({'href' => 'https://www.cell.com/cell/fulltext/S0092-8674(18)31629-5', 'target' => '_blank'}, 'spliceAI').
			$q->span('.').
			$q->strong(' WARNING: ONLY CONSIDERS substitutions in exons and introns boundaries.')."\n";
		print U2_modules::U2_subs_2::info_panel($text, $q);
		my ($pos_list, $hash);#we need a position list for tabix such as chr1:1112554-1122554 and a hash to store variants
		while (my $result2 = $sth2->fetchrow_hashref()) {
			if ($filter eq 'RP' && $result2->{'rp'} == 0) {$filtered_missense++;next;}
			elsif ($filter eq 'DFN' && $result2->{'dfn'} == 0) {$filtered_missense++;next;}
			elsif ($filter eq 'USH' && $result2->{'usher'} == 0) {$filtered_missense++;next;}
			elsif ($filter eq 'DFN-USH' && ($result2->{'dfn'} == 0 && $result2->{'usher'} == 0)) {$filtered_missense++;next;}
			elsif ($filter eq 'RP-USH' && ($result2->{'rp'} == 0 && $result2->{'usher'} == 0)) {$filtered_missense++;next;}
			elsif ($filter eq 'CHM' && $result2->{'gene_symbol'} ne 'CHM') {$filtered_missense++;next;}

			#ok we're done with boring stuff let's do some new things

			my @hyphen = split(/-/, U2_modules::U2_subs_1::getExacFromGenoVar($result2->{'nom_g'}));
			my ($chr, $pos, $wt, $mt) = ($hyphen[0], $hyphen[1], $hyphen[2], $hyphen[3]);
			$pos_list .= " chr$chr:$pos-$pos";
			$hash->{$result2->{'nom_g'}} = [$result2->{'gene_symbol'}, $result2->{'refseq'}, $result2->{'statut'}, $result2->{'nom'}, $result2->{'nom_ivs'}, $result2->{'nom_prot'}];

		}

		#spliceAI results
		$pos_list =~ s/chr//og;
		#print $pos_list;
		print $q->start_div({'class' => 'w3-container'}), $q->start_table({'class' => 'technical great_table', 'id' => 'priorisation_splicing_table'}), $q->caption("spliceAI table:"), $q->start_thead(),
			$q->start_Tr(), "\n",
				$q->th({'class' => 'left_general'}, 'gene'), "\n",
				$q->th({'class' => 'left_general'}, 'DNA'), "\n",
				$q->th({'class' => 'left_general'}, 'IVS - Protein'), "\n",
				$q->th({'class' => 'left_general'}, 'Status'), "\n",
				$q->th({'class' => 'left_general'}, 'Donor gain'), "\n",
				$q->th({'class' => 'left_general'}, 'Donor loss'), "\n",
				$q->th({'class' => 'left_general'}, 'Acc gain'), "\n",
				$q->th({'class' => 'left_general'}, 'Acc loss'), "\n",
				$q->end_Tr(), $q->end_thead(), $q->start_tbody(), "\n";



		my @spiceai = split(/\n/, `$EXE_PATH/tabix $DATABASES_PATH/spliceAI/exome_spliceai_scores.vcf.gz $pos_list`);
		my $sortable_sai;
		foreach (@spiceai) {
			my @res = split(/\t/, $_);
			#print "chr$res[0]:g.$res[1]$res[3]>$res[4]", $q->br(), $_, $q->br(), $hash->{"chr$res[0]:g.$res[1]$res[3]>$res[4]"}, $q->br();
			if (exists($hash->{"chr$res[0]:g.$res[1]$res[3]>$res[4]"})) {
				my @spiceai_res = split(/;/, $res[7]);
				my @ds_ag = split(/=/, $spiceai_res[4]);
				my @ds_al = split(/=/, $spiceai_res[5]);
				my @ds_dg = split(/=/, $spiceai_res[6]);
				my @ds_dl = split(/=/, $spiceai_res[7]);
				#my ($ds, $al, $dg, $dl) = ($ds_ag[1],$ds_al[1],$ds_dg[1],$ds_dl[1]);
				my $top_score = max($ds_ag[1],$ds_al[1],$ds_dg[1],$ds_dl[1]);
				#print $top_score."---$res[7]";
				#print "$ds_ag[1]-$ds_al[1]-$ds_dg[1]-$ds_dl[1]";
				#undef $hash->{"chr$res[0]:g.$res[1]$res[3]>$res[4]"}[6];#removes previous spidex score - remove when removing spidex
				$sortable_sai->{"$top_score-chr$res[0]_$res[1]_$res[3]_$res[4]"} = $hash->{"chr$res[0]:g.$res[1]$res[3]>$res[4]"};
				push @{$sortable_sai->{"$top_score-chr$res[0]_$res[1]_$res[3]_$res[4]"}}, $ds_ag[1];
				push @{$sortable_sai->{"$top_score-chr$res[0]_$res[1]_$res[3]_$res[4]"}}, $ds_al[1];
				push @{$sortable_sai->{"$top_score-chr$res[0]_$res[1]_$res[3]_$res[4]"}}, $ds_dg[1];
				push @{$sortable_sai->{"$top_score-chr$res[0]_$res[1]_$res[3]_$res[4]"}}, $ds_dl[1];
			}
		}
		foreach my $spiceai_top (sort {$b <=> $a} keys %{$sortable_sai}) {
			my $class = 'one_quarter';
			$spiceai_top =~ /^([01]\.\d{4})-chr/o;
			my $spiceai_top_value = $1;
			if ($spiceai_top_value > 0.8) {$class = 'four_quarter'}
			elsif ($spiceai_top_value > 0.5) {$class = 'three_quarter'}
			elsif ($spiceai_top_value > 0.2) {$class = 'two_quarter'}
			print $q->start_Tr(), "\n",
				$q->start_td({'class' => $class}), $q->em({'onclick' => "gene_choice('$sortable_sai->{$spiceai_top}[0]');", 'class' => 'pointer', 'title' => 'click to get somewhere'}, $sortable_sai->{$spiceai_top}[0]), $q->end_td(), "\n",
				$q->td({'onclick' => "window.open('patient_genotype.pl?sample=$id$number&amp;gene=$sortable_sai->{$spiceai_top}[0]')", 'class' => "ital $class", 'title' => 'Go to the genotype page'}, $sortable_sai->{$spiceai_top}[3]), "\n",
				$q->td({'onclick' => "window.open('variant.pl?gene=".$sortable_sai->{$spiceai_top}[0]."&accession=".$sortable_sai->{$spiceai_top}[1]."&nom_c='+encodeURIComponent('".$sortable_sai->{$spiceai_top}[3]."')+'')", 'class' => "ital $class", 'title' => 'Go to the variant page'}, "$sortable_sai->{$spiceai_top}[4] - $sortable_sai->{$spiceai_top}[5]"), "\n",
				$q->td($sortable_sai->{$spiceai_top}[2]), "\n",
				$q->td($sortable_sai->{$spiceai_top}[6]), "\n",
				$q->td($sortable_sai->{$spiceai_top}[7]), "\n",
				$q->td($sortable_sai->{$spiceai_top}[8]), "\n",
				$q->td($sortable_sai->{$spiceai_top}[9]), "\n",
			$q->end_Tr(), "\n";
		}
		#print $pos_list;
		print $q->end_tbody(), $q->end_table(), $q->end_div(), "\n", $q->br(), $q->br();

	}
	else {print $q->p('No candidate variant to test.')}
}

#}

##Basic end of USHVaM 2 perl scripts:

U2_modules::U2_subs_1::standard_end_html($q);

print $q->end_html();

exit();

##End of Basic end

## specific subs

sub dbnsfp2html {
	my ($dbnsfp, $ref, $alt, $onekg, $espea, $espaa, $exac_maf, $clinvar, $sift, $polyphen, $fathmm, $metalr, $gene, $id, $number, $acc, $var, $prot, $status) = @_;
	my ($aa_ref, $aa_alt) = U2_modules::U2_subs_1::decompose_nom_p($prot);
	foreach (@{$dbnsfp}) {
		my @current = split(/\t/, $_);
		if (($current[2] eq $ref) && ($current[3] eq $alt) && ($current[4] eq $aa_ref) && ($current[5] eq $aa_alt)) {
			my ($sift_unic, $pph_unic, $fathmm_unic, $metalr_unic) = (U2_modules::U2_subs_2::most_damaging($current[$sift], 'min'), U2_modules::U2_subs_2::most_damaging($current[$polyphen], 'max'), U2_modules::U2_subs_2::most_damaging($current[$fathmm], 'min'), U2_modules::U2_subs_2::most_damaging($current[$metalr], 'max'));
			my $class = 'one_quarter';
			my ($max_maf, $score, $ratio) = &compute_ratio(\@current, $onekg, $espea, $espaa, $exac_maf, $clinvar, $sift_unic, $pph_unic, $fathmm_unic, $metalr_unic);
			if ($ratio >= 0.25 && $ratio < 0.5) {$class = 'two_quarter'}
			elsif ($ratio >= 0.5 && $ratio < 0.75) {$class = 'three_quarter'}
			elsif ($ratio >= 0.75) {$class = 'four_quarter'}

			print $q->start_Tr(), "\n",
				$q->start_td({'class' => $class}), $q->em({'onclick' => "gene_choice('$gene');", 'class' => 'pointer', 'title' => 'click to get somewhere'}, $gene), $q->end_td(), "\n",
				$q->td({'onclick' => "window.open('patient_genotype.pl?sample=$id$number&amp;gene=$gene')", 'class' => "ital $class", 'title' => 'Go to the genotype page'}, $var), "\n",
				$q->td({'onclick' => "window.open('variant.pl?gene=$gene&accession=$acc&nom_c='+encodeURIComponent('$var')+'')", 'class' => "ital $class", 'title' => 'Go to the variant page'}, $prot), "\n",
				$q->td($status), "\n",
				$q->td({'style' => 'color:'.U2_modules::U2_subs_1::sift_color($sift_unic)}, $sift_unic), "\n",
				$q->td({'style' => 'color:'.U2_modules::U2_subs_1::pph2_color2($pph_unic)}, $pph_unic), "\n",
				$q->td({'style' => 'color:'.U2_modules::U2_subs_1::fathmm_color($fathmm_unic)}, $fathmm_unic), "\n",
				$q->td({'style' => 'color:'.U2_modules::U2_subs_1::metalr_color($metalr_unic)}, $metalr_unic), "\n",
				$q->td(U2_modules::U2_subs_2::dbnsfp_clinvar2text($current[$clinvar])), "\n",
				$q->td(sprintf('%.4f',$max_maf)), "\n",
				$q->td({'class' => $class}, $score), "\n",
				$q->td({'class' => $class}, $ratio), "\n",
				$q->end_Tr();
		}
	}
}


sub compute_ratio {
	my ($values, $onekg, $espea, $espaa, $exac_maf, $clinvar, $sift, $polyphen, $fathmm, $metalr) = @_;
	my ($a, $b) = (0, 1);
	my $max_maf = max($values->[$onekg], $values->[$espea], $values->[$espaa], $values->[$exac_maf]);
	if ($max_maf < 0.005) {$a++}
	if ($sift ne '.'){$b++;if ($sift < $U2_modules::U2_subs_1::SIFT_THRESHOLD) {$a++}}
	if ($polyphen ne '.'){$b++;if ($polyphen > $U2_modules::U2_subs_1::PPH2_THRESHOLD) {$a++}}
	if ($fathmm ne '.'){$b++;if ($fathmm < $U2_modules::U2_subs_1::FATHMM_THRESHOLD) {$a++}}
	if ($metalr ne '.'){$b++;if ($metalr > $U2_modules::U2_subs_1::METALR_THRESHOLD) {$a++}}


	if (U2_modules::U2_subs_2::dbnsfp_clinvar2text($values->[$clinvar]) =~ /Pathogenic/) {$a++}
	if (U2_modules::U2_subs_2::dbnsfp_clinvar2text($values->[$clinvar]) ne 'not seen in Clinvar') {$b++}
	return ($max_maf, $a, sprintf('%.2f', ($a/$b)));
	#print $max_maf.$q->br();
}
