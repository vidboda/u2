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
my $CSS_PATH = $config->CSS_PATH();
my $CSS_DEFAULT = $config->CSS_DEFAULT();
my $JS_PATH = $config->JS_PATH();
my $JS_DEFAULT = $config->JS_DEFAULT();
my $HTDOCS_PATH = $config->HTDOCS_PATH();
my $DATABASES_PATH = $config->DATABASES_PATH();
my $DALLIANCE_DATA_DIR_PATH = $config->DALLIANCE_DATA_DIR_PATH();
my $EXE_PATH = $config->EXE_PATH();

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

my $query = "SELECT * FROM patient WHERE numero = '$number' AND identifiant = '$id';";

my $result = $dbh->selectrow_hashref($query);

if ($result) {
	my ($first_name, $last_name) = ($result->{'first_name'}, $result->{'last_name'});
	$first_name =~ s/'/''/og;
	$last_name =~ s/'/''/og;
	
	my $query2 = "SELECT numero, identifiant FROM patient WHERE first_name = '$first_name' AND last_name = '$last_name' AND numero <> '$number'";
	my $list = "('$id', '$number')";
	my $sth2 = $dbh->prepare($query2);
	my $res2 = $sth2->execute();
	if ($res2 ne '0E0') {
		while (my $result2 = $sth2->fetchrow_hashref()) {
			$list .= ", ('$result2->{'identifiant'}', '$result2->{'numero'}')";
		}
	}
	
	my $analysis = 'Missense';
	if ($q->param('type') eq 'splicing') {$analysis = 'Splicing'}
	
	
	#get missense list
	#consider fiters
	my $filter = 'ALL'; #for NGS stuff
	my $query_filter = "SELECT filter FROM miseq_analysis WHERE (id_pat, num_pat) IN ($list) AND filter <> 'ALL';";
	my $res_filter = $dbh->selectrow_hashref($query_filter);
	if ($res_filter) {$filter = $res_filter->{'filter'}}

	print $q->start_p({'class' => 'center'}), $q->start_big(), $q->span("Sample "), $q->strong({'onclick' => "window.location = 'patient_file.pl?sample=$id$number'", 'class' => 'pointer'}, $id.$number), $q->span(": $analysis prioritization for "), $q->strong("$first_name $last_name"), $q->end_big(), $q->end_p(), $q->br(), $q->br();
	
	
	if ($analysis eq 'Missense') {	
		#my $query_missense = "SELECT a.nom, a.nom_gene, a.nom_prot, a.nom_g, b.statut, d.rp, d.dfn, d.usher FROM variant a, variant2patient b, patient c, gene d  WHERE a.nom = b.nom_c AND a.nom_gene = b.nom_gene AND b.num_pat = c.numero AND b.id_pat = c.identifiant AND b.nom_gene = d.nom AND c.first_name = '$first_name' AND c.last_name = '$last_name' AND b.num_pat IN ($num_list) AND b.id_pat IN ($id_list) AND a.type_prot = 'missense' AND a.classe = 'unknown' AND (a.nom_gene[1], a.num_segment) NOT IN (('DSPP', '5')) GROUP BY a.nom, a.nom_gene, b.statut, d.rp, d.dfn, d.usher ORDER BY a.nom_gene, a.nom_g;";
		my $query_missense = "SELECT a.nom, a.nom_gene, a.nom_prot, a.nom_g, b.statut, d.rp, d.dfn, d.usher FROM variant a, variant2patient b, patient c, gene d  WHERE a.nom = b.nom_c AND a.nom_gene = b.nom_gene AND b.num_pat = c.numero AND b.id_pat = c.identifiant AND b.nom_gene = d.nom AND c.first_name = '$first_name' AND c.last_name = '$last_name' AND a.type_prot = 'missense' AND a.classe = 'unknown' AND (a.nom_gene[1], a.num_segment) NOT IN (('DSPP', '5')) GROUP BY a.nom, a.nom_gene, a.nom_prot, a.nom_g, b.statut, d.rp, d.dfn, d.usher ORDER BY a.nom_gene, a.nom_g;";
		#print $query_missense;
		$sth2 = $dbh->prepare($query_missense);
		$res2 = $sth2->execute();
		my $color = U2_modules::U2_subs_1::color_by_classe('unknown', $dbh);
		if ($res2 ne '0E0') {
			#we have some missense
			my $filtered_missense = 0;
			my $text = $q->span('You will find below a table ranking all ').$q->strong('unknown').$q->span(" missense variants reported for $first_name $last_name, except variants occuring in filtered genes AND variants occuring in DSPP exon 5.");
			print U2_modules::U2_subs_2::info_panel($text, $q);
			$text = $q->span('Up to Five items can be considered to prioritize the variants, 3 predictors, EVS MAF and Clinvar annotation').$q->br().
					$q->span(' The \'score\' column goes from 0 to 5 (the higher the more probably pathogenic), as well as the \'Pathogenic Ratio\', ').
					$q->span(' which is the ratio between the score and the total number of available items. To gain a point in the score column, variants must either:')."\n".
			$q->start_ul().
				$q->li('have a SIFT prediction below 0.05').
				$q->li('have a polyphen prediction being \'possibly_pathogenic\' or \'probably_pathogenic\'').
				$q->li('have a FATHMM prediction below -1.5').
				$q->li('be reported in ClinVar as \'likely pathogenic\' or \'pathogenic\'').
				$q->li('have a MAX_MAF below 0.005 (same for dominants and recessives), MAX_MAF being the maximum between ExAC, EVS_EA and EVS_AA MAFs.').
			$q->end_ul();
			print U2_modules::U2_subs_2::info_panel($text, $q);
			#print $q->start_p(), $q->span('You will find below a table ranking all '), $q->strong('unknown'), $q->span(" missense variants reported for $first_name $last_name, except variants occuring in filtered genes AND variants occuring in DSPP exon 5."), $q->end_p(), $q->br(), $q->br(), $q->p('Up to Five items can be considered to prioritize the variants, 3 predictors, EVS MAF and Clinvar annotation. The \'score\' column goes from 0 to 5 (the higher the more probably pathogenic), as well as the \'Pathogenic Ratio\', which is the ratio between the score and the total number of available items. To gain a point in the score column, variants must either:'), "\n",
			#$q->start_ul(),
			#	$q->li('have a SIFT prediction below 0.05'),
			#	$q->li('have a polyphen prediction being \'possibly_pathogenic\' or \'probably_pathogenic\''),
			#	$q->li('have a FATHMM prediction below -1.5'),
			#	$q->li('be reported in ClinVar as \'likely pathogenic\' or \'pathogenic\''),
			#	$q->li('have a MAX_MAF below 0.005 (same for dominants and recessives), MAX_MAF being the maximum between ExAC, EVS_EA and EVS_AA MAFs.'),
			#$q->end_ul(), $q->br(), $q->br(), "\n"; 
				
			print $q->start_div({'class' => 'container'}), $q->start_table({'class' => "technical great_table", 'id' => 'priorisation_table'}), $q->caption("Missense table:"), $q->start_thead(),
				$q->start_Tr(), "\n",
					$q->th({'class' => 'left_general'}, 'gene'), "\n",
					$q->th({'class' => 'left_general'}, 'DNA'), "\n",
					$q->th({'class' => 'left_general'}, 'Protein'), "\n",
					$q->th({'class' => 'left_general'}, 'Status'), "\n",
					$q->th({'class' => 'left_general'}, 'SIFT'), "\n",
					$q->th({'class' => 'left_general'}, 'Polyphen 2'), "\n",
					$q->th({'class' => 'left_general'}, 'FATHMM'), "\n",
					$q->th({'class' => 'left_general'}, 'M-CAP'), "\n",
					$q->th({'class' => 'left_general'}, 'ClinVar'), "\n",
					$q->th({'class' => 'left_general'}, 'MAX_MAF'), "\n",				
					$q->th({'class' => 'left_general'}, 'Score'), "\n",
					$q->th({'class' => 'left_general'}, 'Pathogenic Ratio'), "\n",
					$q->end_Tr(), $q->end_thead(), $q->start_tbody(),  "\n";	
			#print $q->end_table(), $q->end_div(), "\n", $q->br(), $q->br(), $q->br();
			my $tempfile = File::Temp->new();
			my $hash;
			while (my $result2 = $sth2->fetchrow_hashref()) {
				if ($filter eq 'RP' && $result2->{'rp'} == 0) {$filtered_missense++;next;}
				elsif ($filter eq 'DFN' && $result2->{'dfn'} == 0) {$filtered_missense++;next;}
				elsif ($filter eq 'USH' && $result2->{'usher'} == 0) {$filtered_missense++;next;}
				elsif ($filter eq 'DFN-USH' && ($result2->{'dfn'} == 0 && $result2->{'usher'} == 0)) {$filtered_missense++;next;}
				elsif ($filter eq 'RP-USH' && ($result2->{'rp'} == 0 && $result2->{'usher'} == 0)) {$filtered_missense++;next;}
				elsif ($filter eq 'CHM' && $result2->{'nom_gene'} ne 'CHM') {$filtered_missense++;next;}
				
				#ok we're done with boring stuff let's do some new things
				#my $tempfile = File::Temp->new(UNLINK => 1);
				$result2->{'nom_g'} =~ /chr([\dXY]+):g\.(\d+)([ATGC])>([ATGC])/o;
				my ($chr, $pos1, $wt, $mt) = ($1, $2, $3, $4);
				$hash->{$result2->{'nom_gene'}[0]."_".$chr."_".$pos1."_".$wt."/".$mt} = [$result2->{'nom_gene'}[1], $result2->{'nom'}, $result2->{'nom_prot'}, $result2->{'statut'}, 'no SIFT', 'no polyphen', 'no FATHMM', 'no M-CAP', 'no CLINSIG', 'no MAF', 0, 0];#[NM_, DAN, Prot, status, SIFT, polyphen, FATHMM, Clinvar, points, total points] points being number of 'causative' item (i.e. SIFT < 0.05), total points = total items
				print $tempfile "$chr $pos1 $pos1 $wt/$mt +\n";
				#MCAP results for missense on the fly
				my @mcap =  split(/\n/, `$EXE_PATH/tabix $DATABASES_PATH/mcap/mcap_v1_0.txt.gz $chr:$pos1-$pos1`);
				foreach (@mcap) {
					my @current = split(/\t/, $_);
					if (/\t$wt\t$mt\t/) {
						$hash->{$result2->{'nom_gene'}[0]."_".$chr."_".$pos1."_".$wt."/".$mt}[7] = $q->span({'style' => 'color:'.U2_modules::U2_subs_1::mcap_color($current[4])}, sprintf('%.4f', $current[4]))."\n";
						$hash->{$result2->{'nom_gene'}[0]."_".$chr."_".$pos1."_".$wt."/".$mt}[11]++;
						if (U2_modules::U2_subs_1::mcap_color($current[4]) eq '#FF0000') {$hash->{$result2->{'nom_gene'}[0]."_".$chr."_".$pos1."_".$wt."/".$mt}[10]++}
					}
				}
			}		
			if ($tempfile->filename() =~ /(\/tmp\/\w+)/o) {
				delete $ENV{PATH};
				my @results = split('\n', `$DATABASES_PATH/variant_effect_predictor_78/variant_effect_predictor.pl --fasta $DATABASES_PATH/.vep/homo_sapiens/75/Homo_sapiens.GRCh37.75.dna.primary_assembly.fa --offline --cache --compress "gunzip -c" --maf_esp --polyphen b --sift b --refseq --symbol --no_progress -q --fork 4 --no_stats --dir $DATABASES_PATH/.vep/ --force --filter coding_change -i $1 --plugin FATHMM,"python $DATABASES_PATH/.vep/Plugins/fathmm.py" --plugin ExAC,$DALLIANCE_DATA_DIR_PATH/exac/ExAC.r0.3.sites.vep.vcf.gz -o STDOUT`); ###VEP78
				#print "$DATABASES_PATH/variant_effect_predictor_78/variant_effect_predictor.pl --fasta $DATABASES_PATH/.vep/homo_sapiens/78_GRCh37/Homo_sapiens.GRCh37.75.dna.primary_assembly.fa --port 3337 --cache --compress \"gunzip -c\" --maf_esp --polyphen b --sift b --refseq --symbol --no_progress -q --fork 4 --no_stats --dir $DATABASES_PATH/.vep/ --force --filter coding_change -i $1 --plugin FATHMM,\"python $DATABASES_PATH/.vep/Plugins/fathmm.py\" -o STDOUT";
				foreach (@results) {
					if (/^#/o) {next}
					my @results_split = split(/\s/, $_);
					#print $results_split[13].$q->br();
					#my $a = my $b = 0;
					#print $results_split[6];
					if ($results_split[6] =~ /missense_variant/o && $results_split[13] =~ /SYMBOL=(\w+)/o) {
						my $symbol = $1;
						#$hash->{$results_split[0]}
						if ($results_split[13] =~ /SIFT=([^\)]+\))/o && $hash->{$symbol."_".$results_split[0]}[4] eq 'no SIFT') {
							$hash->{$symbol."_".$results_split[0]}[11]++;
							my $sift = $1;
							if ($sift =~ /deleterious/o) {$hash->{$symbol."_".$results_split[0]}[10]++}				
							$hash->{$symbol."_".$results_split[0]}[4] = $q->span({'style' => 'color:'.U2_modules::U2_subs_1::sift_color2($sift)}, $sift);
						}
						if ($results_split[13] =~ /PolyPhen=([\w\d\(\)\.^\)]+\))/o && $hash->{$symbol."_".$results_split[0]}[5] eq 'no polyphen') {
							my $polyphen = $1;
							if ($polyphen !~ /unknown/o) {
								$hash->{$symbol."_".$results_split[0]}[11]++;
								if ($polyphen =~ /damaging/o) {$hash->{$symbol."_".$results_split[0]}[10]++}
								#if ($polyphen !~ /unknown/o) {$hash->{$symbol."_".$results_split[0]}[10]++}
								$hash->{$symbol."_".$results_split[0]}[5] = $q->span({'style' => 'color:'.U2_modules::U2_subs_1::pph2_color($polyphen)}, $polyphen);
							}
						}
						if ($results_split[13] =~ /FATHMM=([\d\.-]+)\(/o && $hash->{$symbol."_".$results_split[0]}[6] eq 'no FATHMM') {
							my $fathmm = $1;
							if ($fathmm !~ /Sequence\(Record\)/o && $fathmm !~ /Prediction\(Available\)/o) {
								$hash->{$symbol."_".$results_split[0]}[11]++;
								if ($fathmm < -1.5) {$hash->{$symbol."_".$results_split[0]}[10]++}	
								$hash->{$symbol."_".$results_split[0]}[6] = $q->span({'style' => 'color:'.U2_modules::U2_subs_1::fathmm_color($fathmm)}, $fathmm);
							}
						}
						if ($results_split[13] =~ /CLIN_SIG=(\w+)/o && $hash->{$symbol."_".$results_split[0]}[8] eq 'no CLINSIG') {
							$hash->{$symbol."_".$results_split[0]}[11]++;
							my $clinvar = $1;
							if ($clinvar =~ /pathogenic/o) {$hash->{$symbol."_".$results_split[0]}[10]++}
							$hash->{$symbol."_".$results_split[0]}[8] = $clinvar
						}
						my $ea_maf = my $aa_maf = my $exac_maf = 0;
						if ($hash->{$symbol."_".$results_split[0]}[9] eq 'no MAF') {
							$hash->{$symbol."_".$results_split[0]}[11]++;
							if ($results_split[13] =~ /EA_MAF=[ATCG-]+:([\d\.]+);*/o) {$ea_maf = $1}
							if ($results_split[13] =~ /AA_MAF=[ATCG-]+:([\d\.]+);*/o) {$aa_maf = $1}
							#if ($ea_maf > $aa_maf) {$hash->{$symbol."_".$results_split[0]}[8] = $ea_maf}
							#else {$hash->{$symbol."_".$results_split[0]}[8] = $aa_maf}
							#if ($hash->{$symbol."_".$results_split[0]}[8] < 0.005) {$hash->{$symbol."_".$results_split[0]}[9]++}
							#### ESP replaced with ExAC 07/27/2015
							#print $results_split[13].$q->br();
							#if ($results_split[13] =~ /ExAC_AF=([\d\.e-]+);*/) {$hash->{$symbol."_".$results_split[0]}[8] = $1}
							if ($results_split[13] =~ /ExAC_AF=([\d\.e-]+);*/) {$exac_maf = $1}
							#my $max_maf = max [$ea_maf, $aa_maf, $exac_maf];
							$hash->{$symbol."_".$results_split[0]}[9] = max($ea_maf, $aa_maf, $exac_maf);
							if ($hash->{$symbol."_".$results_split[0]}[9] < 0.005) {$hash->{$symbol."_".$results_split[0]}[10]++}
						}
						#print $results_split[13].$q->br();
						#$hash->{$symbol."_".$results_split[0]}[9] = $a;
						#$hash->{$symbol."_".$results_split[0]}[10] = sprintf('%.2f', $a/$b);
						
					}
					#else {print $q->span("No symbol for $results_split[13]")}					
				}
				
				#print $q->start_ul();
				#foreach (@results) {print $q->li($_)}
				#print $q->end_ul();
			}	
				
			for (my $i = 6; $i >= 0; $i--) {
				foreach my $key (sort(keys(%{$hash}))) {
					#print $key;
					if ($hash->{$key}[10] == $i) {
						$key =~ /([^_]+)_\w+/o;
						my $gene = $1;
						my $class = 'one_quarter';
						my $ratio = 0;
						if ($hash->{$key}[11] != 0) {$ratio = sprintf('%.2f', ($hash->{$key}[10])/($hash->{$key}[11]))}
						if ($ratio >= 0.25 && $ratio < 0.5) {$class = 'two_quarter'}
						elsif ($ratio >= 0.5 && $ratio < 0.75) {$class = 'three_quarter'}
						elsif ($ratio >= 0.75) {$class = 'four_quarter'}
						
						print $q->start_Tr(), "\n",
							$q->start_td({'class' => $class}), $q->em({'onclick' => "gene_choice('$gene');", 'class' => 'pointer', 'title' => 'click to get somewhere'}, $gene), $q->end_td(), "\n",
							$q->td({'onclick' => "window.open('patient_genotype.pl?sample=$id$number&amp;gene=$gene')", 'class' => "ital $class", 'title' => 'Go to the genotype page'}, $hash->{$key}[1]), "\n",
							$q->td({'onclick' => "window.open('variant.pl?gene=$gene&accession=".$hash->{$key}[0]."&nom_c='+encodeURIComponent('".$hash->{$key}[1]."')+'')", 'class' => "ital $class", 'title' => 'Go to the variant page'}, $hash->{$key}[2]), "\n",
							$q->td($hash->{$key}[3]), "\n",
							$q->td($hash->{$key}[4]), "\n",
							$q->td($hash->{$key}[5]), "\n",
							$q->td($hash->{$key}[6]),"\n",
							$q->td($hash->{$key}[7]), "\n",
							$q->td($hash->{$key}[8]), "\n",
							$q->td($hash->{$key}[9]), "\n",
							$q->td({'class' => $class}, $hash->{$key}[10]), "\n",
							$q->td({'class' => $class}, $ratio), "\n",
							$q->end_Tr(), "\n";
						delete $hash->{$key}
					}				
				}		
			}
			
				
			print $q->end_tbody(), $q->end_table(), $q->end_div(), "\n", $q->br(), $q->br(), $q->br();
		
		}
		else {print $q->p('No unknown missense to test for this patient');}#$query_missense;}
	}	
	elsif ($analysis eq 'Splicing') {
		my $query_splicing = "SELECT a.nom, a.nom_ivs, a.nom_prot, a.nom_gene, a.nom_g, b.statut, d.rp, d.dfn, d.usher FROM variant a, variant2patient b, patient c, gene d  WHERE a.nom = b.nom_c AND a.nom_gene = b.nom_gene AND b.num_pat = c.numero AND b.id_pat = c.identifiant AND b.nom_gene = d.nom AND c.first_name = '$first_name' AND c.last_name = '$last_name' AND a.classe = 'unknown' AND (a.nom_gene[1], a.num_segment) NOT IN (('DSPP', '5')) GROUP BY a.nom, a.nom_ivs, a.nom_prot, a.nom_gene, a.nom_g, b.statut, d.rp, d.dfn, d.usher ORDER BY a.nom_gene, a.nom_g;";
		#print $query_missense;
		$sth2 = $dbh->prepare($query_splicing);
		$res2 = $sth2->execute();
		my $color = U2_modules::U2_subs_1::color_by_classe('unknown', $dbh);
		if ($res2 ne '0E0') {
			#we have some candidates
			my $filtered_missense = 0;
			my $text = $q->span('You will find below a table ranking all ').
				$q->strong('unknown').
				$q->span(" variants reported for $first_name $last_name, except variants occuring in filtered genes AND variants occuring in DSPP exon 5.");
			print U2_modules::U2_subs_2::info_panel($text, $q);
			$text = $q->span('They are ranked according to their ability to disturb proper splicing according to ').
				$q->a({'href' => 'http://tools.genes.toronto.edu/', 'target' => '_blank'}, 'SPANR').
				$q->span('.').
				$q->strong(' WARNING: does not work for variants located > 300 bp from exons AND ONLY CONSIDERS substitutions.')."\n";
			print U2_modules::U2_subs_2::info_panel($text, $q);
			
			#print $q->start_p(), $q->span('You will find below a table ranking all '), $q->strong('unknown'), $q->span(" variants reported for $first_name $last_name, except variants occuring in filtered genes AND variants occuring in DSPP exon 5."), $q->end_p(), $q->br(), $q->br(), $q->start_p(), $q->span('They are ranked according to their ability to disturb proper splicing according to '), $q->a({'href' => 'http://tools.genes.toronto.edu/', 'target' => '_blank'}, 'SPANR'), $q->span('.'), $q->strong(' WARNING: does not work for variants located > 300 bp from exons AND ONLY CONSIDERS substitutions.'), "\n", $q->br(), $q->br(), "\n"; 
				
			print $q->start_div({'class' => 'container'}), $q->start_table({'class' => 'technical great_table', 'id' => 'priorisation_table'}), $q->caption("Splicing table:"), $q->start_thead(),
				$q->start_Tr(), "\n",
					$q->th({'class' => 'left_general'}, 'gene'), "\n",
					$q->th({'class' => 'left_general'}, 'DNA'), "\n",
					$q->th({'class' => 'left_general'}, 'IVS - Protein'), "\n",
					$q->th({'class' => 'left_general'}, 'Status'), "\n",
					$q->th({'class' => 'left_general'}, 'dPSI (%)'), "\n",
					$q->th({'class' => 'left_general'}, 'dPSI z-score'), "\n",
					$q->end_Tr(), $q->end_thead(), $q->start_tbody(), "\n";	
			#print $q->end_table(), $q->end_div(), "\n", $q->br(), $q->br(), $q->br();
			#my $tempfile = File::Temp->new();
			my ($pos_list, $hash);#we need a position list for tabix such as chr1:1112554-1122554 and a hash to store variants
			while (my $result2 = $sth2->fetchrow_hashref()) {
				if ($filter eq 'RP' && $result2->{'rp'} == 0) {$filtered_missense++;next;}
				elsif ($filter eq 'DFN' && $result2->{'dfn'} == 0) {$filtered_missense++;next;}
				elsif ($filter eq 'USH' && $result2->{'usher'} == 0) {$filtered_missense++;next;}
				elsif ($filter eq 'DFN-USH' && ($result2->{'dfn'} == 0 && $result2->{'usher'} == 0)) {$filtered_missense++;next;}
				elsif ($filter eq 'RP-USH' && ($result2->{'rp'} == 0 && $result2->{'usher'} == 0)) {$filtered_missense++;next;}
				elsif ($filter eq 'CHM' && $result2->{'nom_gene'} ne 'CHM') {$filtered_missense++;next;}
				
				#ok we're done with boring stuff let's do some new things
				
				my @hyphen = split(/-/, U2_modules::U2_subs_1::getExacFromGenoVar($result2->{'nom_g'}));
				my ($chr, $pos, $wt, $mt) = ($hyphen[0], $hyphen[1], $hyphen[2], $hyphen[3]);
				$pos_list .= " chr$chr:$pos-$pos";
				$hash->{$result2->{'nom_g'}} = [$result2->{nom_gene}[0], $result2->{nom_gene}[1], $result2->{'statut'}, $result2->{'nom'}, $result2->{'nom_ivs'}, $result2->{'nom_prot'}];
				
			}

			
			my @spidex = split(/\n/, `$DATABASES_PATH/htslib-1.2.1/tabix $DATABASES_PATH/spidex_public_noncommercial_v1.0/spidex_public_noncommercial_v1_0.tab.gz $pos_list`);
			my $sortable;
			foreach (@spidex) {
				my @res = split(/\t/, $_);
				if (exists($hash->{"$res[0]:g.$res[1]$res[2]>$res[3]"})) {
					$sortable->{"$res[4]"} = $hash->{"$res[0]:g.$res[1]$res[2]>$res[3]"};
					push @{$sortable->{"$res[4]"}}, $res[5];
				}				
			}
			
			
			foreach my $dpsi (sort {$a <=> $b} keys %{$sortable}) {
				my $class = 'one_quarter';
				if ($dpsi < -20) {$class = 'four_quarter'}
				elsif ($dpsi < -10) {$class = 'three_quarter'}
				elsif ($dpsi < -5) {$class = 'two_quarter'}			
				
				
				print $q->start_Tr(), "\n",
					$q->start_td({'class' => $class}), $q->em({'onclick' => "gene_choice('$sortable->{$dpsi}[0]');", 'class' => 'pointer', 'title' => 'click to get somewhere'}, $sortable->{$dpsi}[0]), $q->end_td(), "\n",
					$q->td({'onclick' => "window.open('patient_genotype.pl?sample=$id$number&amp;gene=$sortable->{$dpsi}[0]')", 'class' => "ital $class", 'title' => 'Go to the genotype page'}, $sortable->{$dpsi}[3]), "\n",
					$q->td({'onclick' => "window.open('variant.pl?gene=".$sortable->{$dpsi}[0]."&accession=".$sortable->{$dpsi}[1]."&nom_c='+encodeURIComponent('".$sortable->{$dpsi}[3]."')+'')", 'class' => "ital $class", 'title' => 'Go to the variant page'}, "$sortable->{$dpsi}[4] - $sortable->{$dpsi}[5]"), "\n",
					$q->td($sortable->{$dpsi}[2]), "\n",
					$q->td(sprintf('%.2f', $dpsi)), "\n",
					$q->td(sprintf('%.2f', $sortable->{$dpsi}[6])), "\n",
				$q->end_Tr(), "\n";
			}
			
			print $q->end_tbody(), $q->end_table(), $q->end_div(), "\n", $q->br(), $q->br();
			$text = $q->start_ul().
				$q->li('dPSI: The delta PSI. This is the predicted change in percent-inclusion due to the variant, reported as the maximum across tissues (in percent).').
				$q->start_li().$q->span('dPSI z-score: This is the z-score of dpsi_max_tissue relative to the distribution of dPSI that are due to common SNP.').$q->br().$q->span('0 means dPSI equals to mean common SNP. A negative score means dPSI is less than mean common SNP dataset, positive greater.').
			$q->end_ul()."\n";
			print U2_modules::U2_subs_2::info_panel($text, $q);
			
		}
		else {print $q->p('No candidate variant to test.')}
	}

}

##Basic end of USHVaM 2 perl scripts:

U2_modules::U2_subs_1::standard_end_html($q);

print $q->end_html();

exit();

##End of Basic end

