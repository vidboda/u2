BEGIN {delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV', 'PATH'};}

use strict;
use File::Temp;
#use CGI; #in startup.pl
#use DBI;
#use AppConfig qw(:expand :argcount);
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
#		This script implements automated features, accessible to a restricted class of users,
#		and will assign a class to the variants or define an analysis as negative or positive
#

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
my $CSS_DEFAULT = $config->CSS_DEFAULT();
my $CSS_PATH = $config->CSS_PATH();
my $JS_PATH = $config->JS_PATH();
my $JS_DEFAULT = $config->JS_DEFAULT();
my $HTDOCS_PATH = $config->HTDOCS_PATH();

my $DATABASES_PATH = $config->DATABASES_PATH();
my $DALLIANCE_DATA_DIR_PATH = $config->DALLIANCE_DATA_DIR_PATH();

my @styles = ($CSS_PATH.'font-awesome.min.css', $CSS_PATH.'w3.css', $CSS_DEFAULT);

my $q = new CGI;

my $dbh = DBI->connect(    "DBI:Pg:database=$DB;host=$HOST;",
                        $DB_USER,
                        $DB_PASSWORD,
                        {'RaiseError' => 1}
                ) or die $DBI::errstr;




print $q->header(-type => 'text/html', -'cache-control' => 'no-cache'),
	$q->start_html(-title=>" U2 Automated classification",
                        -lang => 'en',
                        -style => {-src => \@styles},
                        -head => [
				-$q->Link({-rel => 'icon',
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


U2_modules::U2_subs_1::standard_begin_html($q, $user->getName(), $dbh);

##end of Basic init


#restricted page to user with validation rights

if ($user->isValidator() == 1) {
	if ($q->param('class') && $q->param('class') == 1) {
		my ($i, $j, $k) = (0, 0, 0);

		print $q->p('This script automatically classifies variants using the following criteria:'),
			$q->start_ul();
			my $info_text = U2_modules::U2_subs_2::info_text($q, 'class');
			$info_text =~ s/\\\'/\'/og;
			print $info_text, "\n",

			$q->end_ul(),$q->br(), $q->br(), "\n",
			$q->start_ul();
		#classify neutral based on SNP common and labo MAF

		#script off waiting for sufficient miseq patients
		#print $q->p("This script is desactivated until a sufficient number of patients have been run through the MiSeq.");
		#exit;
		#end script off


		#neutral
		my $query = "SELECT a.nom, c.gene_symbol, c.refseq FROM variant a, restricted_snp b, gene c WHERE a.snp_id = b.rsid AND a.refseq = c.refseq AND b.common = 't' AND a.classe IN ('unknown', 'VUCS Class F', 'VUCS Class U') AND ((a.type_prot IS NULL) OR (a.type_prot NOT IN ('frameshift', 'nonsense')) OR (a.type_arn <> 'altered'));";
		my $sth = $dbh->prepare($query);
		my $res = $sth->execute();
		while (my $result = $sth->fetchrow_hashref()) {
			$i++;
			my ($var, $gene, $acc) = ($result->{'nom'}, $result->{'gene_symbol'}, $result->{'refseq'});
			my ($maf_sanger, $maf_454, $maf_MiSeq) = ('NA', 'NA', 'NA');
			$maf_sanger = U2_modules::U2_subs_1::maf($dbh, $gene, $acc, $var, 'SANGER');#print $maf_sanger;
			$maf_454 = U2_modules::U2_subs_1::maf($dbh, $gene, $acc, $var, '454-\d+');#print "-$maf_454-$i-$j-$var<br/>";
			$maf_MiSeq = U2_modules::U2_subs_1::maf($dbh, $gene, $acc, $var, 'MiSeq-\d+');
			if ($maf_sanger eq 'NA' && $maf_454 eq 'NA' && $maf_MiSeq eq 'NA') {
				my $maf_USH2A = U2_modules::U2_subs_1::maf($dbh, $gene, $acc, $var, '454-USH2A');
				if ($maf_USH2A ne 'NA' && $maf_USH2A > 0.16) {$j++;&update($var, $gene, $acc, 'neutral');}
				else {$k++}
			}
			elsif (($maf_sanger ne 'NA' && $maf_sanger < 0.01) || ($maf_454 ne 'NA' && $maf_454 < 0.01) || ($maf_MiSeq ne 'NA' && $maf_MiSeq < 0.01)) {next}
			elsif (($maf_454 ne 'NA' && $maf_454 > 0.01) || ($maf_sanger ne 'NA' && $maf_sanger > 0.01) || ($maf_MiSeq ne 'NA' && $maf_MiSeq > 0.01)) {$j++;&update($var, $gene, $acc, 'neutral');}
			#else {$k++}
		}
		#classify stop and fs identified by sanger
		$query = "SELECT DISTINCT(a.nom) as var, c.gene_symbol, c.refseq FROM variant a, variant2patient b, gene c WHERE a.nom = b.nom_c AND a.refseq = b.refseq AND b.refseq = c.refseq AND b.type_analyse = 'SANGER' AND a.classe = 'unknown' AND (a.type_prot = 'nonsense' OR a.type_prot = 'frameshift');";
		$sth = $dbh->prepare($query);
		$res = $sth->execute();
		if ($res ne '0E0') {
			while (my $result = $sth->fetchrow_hashref()) {&update($result->{'var'}, $result->{'gene_symbol'}, $result->{'refseq'}, 'pathogenic');$i++;$j++;}
		}

		#classifiy +1,+2,-1,-2
		$query = "SELECT DISTINCT(a.nom) as var, c.gene_symbol, c.refseq FROM variant a, variant2patient b, gene c WHERE a.nom = b.nom_c AND a.refseq = b.refseq AND b.refseq = c.refseq AND a.classe = 'unknown' AND b.type_analyse = 'SANGER' AND a.nom_ivs ~ 'IVS\\d+[\\+-][12][^\\d].+';";
		$sth = $dbh->prepare($query);
		$res = $sth->execute();
		if ($res ne '0E0') {
			while (my $result = $sth->fetchrow_hashref()) {
				&update($result->{'var'}, $result->{'gene_symbol'}, $result->{'refseq'}, 'pathogenic');$i++;$j++;
				&update_type_arn($result->{'var'}, $result->{'gene_symbol'}, $result->{'refseq'});
			}
		}

		#classify R8
		$query = "SELECT DISTINCT(a.nom) as var, c.gene_symbol, c.refseq, a.nom_g FROM variant a, variant2patient b, gene c WHERE a.nom = b.nom_c AND a.refseq = b.refseq AND b.refseq = c.refseq AND a.classe = 'unknown' AND b.msr_filter ~ 'R8';";
		$sth = $dbh->prepare($query);
		$res = $sth->execute();
		if ($res ne '0E0') {
			while (my $result = $sth->fetchrow_hashref()) {
				&update($result->{'var'}, $result->{'gene_symbol'}, $result->{'refseq'}, 'R8');$i++;$j++;
			}
		}

		#classify VUCS Class F Exac < 0,5% and present 7 times in probands
		# $query = "SELECT a.nom as var, d.gene_symbol, d.refseq, a.nom_g, a.type_adn FROM variant a, variant2patient b, patient c, gene d WHERE a.nom = b.nom_c AND a.refseq = b.refseq AND b.refseq = d.refseq AND b.num_pat = c.numero AND b.id_pat = c.identifiant AND a.taille < '20' AND a.classe = 'unknown' AND c.proband = 't' GROUP BY a.nom, d.gene_symbol HAVING COUNT(nom_c) > 7 ORDER BY a.nom;";
		$query = "SELECT a.nom as var, d.gene_symbol, d.refseq, a.nom_g, a.type_adn FROM variant a, variant2patient b, patient c, gene d WHERE a.nom = b.nom_c AND a.refseq = b.refseq AND b.refseq = d.refseq AND b.num_pat = c.numero AND b.id_pat = c.identifiant AND a.taille < '20' AND a.classe = 'unknown' AND c.proband = 't' GROUP BY a.nom, d.refseq, a.nom_g, a.type_adn HAVING COUNT(nom_c) > 7 ORDER BY a.nom;";
		$sth = $dbh->prepare($query);
		$res = $sth->execute();
		my ($p, $r) = (0, 0);
		if ($res ne '0E0') {
			while (my $result = $sth->fetchrow_hashref()) {
				$i++;
				&update($result->{'var'}, $result->{'gene_symbol'}, $result->{'refseq'}, 'VUCS Class F');$j++;$p++;
				my $af_cutoff = 0.005;
				#subs => direct exac
				if ($result->{'type_adn'} eq 'substitution') {
					my @details = split(/-/, U2_modules::U2_subs_1::getExacFromGenoVar($result->{nom_g}));
					my ($chr, $pos, $ref, $alt) = (shift(@details), shift(@details), shift(@details), shift(@details));
					my @exac = split(/\t/, `$DATABASES_PATH/htslib-1.2.1/tabix $DALLIANCE_DATA_DIR_PATH/exac/ExAC.r0.3.sites.vep.vcf.gz $chr:$pos-$pos`);
					if ($exac[3] eq $ref) {
						if ($exac[4] eq $alt) {
							if ($exac[7] =~ /;AF=([^;]+);/o) {
								if ($1 > $af_cutoff) {
									&update($result->{'var'}, $result->{'gene_symbol'}, $result->{'refseq'}, 'VUCS Class F');$j++;$p++;
								}
								else {&update($result->{'var'}, $result->{'gene_symbol'}, $result->{'refseq'}, 'VUCS Class U');$j++;$r++;}
							}
						}
						elsif ($exac[4] =~/,/o) {#multiallelic site
							my @alts = split(/,/, $exac[4]);
							my $index = 0;
							foreach (@alts) {
								if ($_ eq $alt) {last}
								$index++;
							}
							if ($exac[7] =~ /;AF=([^;]+);/o) {
								my @afs = split(/,/, $1);
								if ($afs[$index] > $af_cutoff) {
									&update($result->{'var'}, $result->{'gene_symbol'}, $result->{'refseq'}, 'VUCS Class F');$j++;$p++
								}
								else {&update($result->{'var'}, $result->{'gene_symbol'}, $result->{'refseq'}, 'VUCS Class U');$j++;$r++;}
							}
						}

					}

				}
				# else {#indels => VEP
				# 	my $tempfile = File::Temp->new(UNLINK => 1);
				# 	if ($result->{'nom_g'} =~ /chr(.+)$/o) {
				# 		print $tempfile "$1\n";
				# 	}
				# 	else {print "pb with variant $result->{'nom_g'} with VEP"}
				# 	if ($tempfile->filename() =~ /(\/tmp\/\w+)/o) {
				# 		delete $ENV{PATH};
				# 		my @results = split('\n', `$DATABASES_PATH/variant_effect_predictor_81/variant_effect_predictor.pl --fasta $DATABASES_PATH/.vep/homo_sapiens/75/Homo_sapiens.GRCh37.75.dna.primary_assembly.fa --port 3337 --cache --compress "gunzip -c" --gmaf --refseq --no_progress -q --fork 4 --no_stats --dir $DATABASES_PATH/.vep/ --force -i $1 --plugin ExAC,$DALLIANCE_DATA_DIR_PATH/exac/ExAC.r0.3.sites.vep.vcf.gz -o STDOUT`); ###VEP81;
				# 		if ($result->{'gene'}[1] =~ /(N[MR]_\d+)/o) {
				# 			my @good_line = grep(/$1/, @results);
				# 			my $not_good_alt = 0;
				# 			if ($good_line[0] =~ /GMAF=([ATCG-]+):([\d\.]+);*/o) {#1000g
				# 				my ($nuc, $score) = ($1, $2);
				# 				if ($nuc eq '-') {
				# 					if ($score > $af_cutoff) {
				# 						&update($result->{'var'}, $result->{'gene_symbol'}, $result->{'refseq'}, 'VUCS Class F');$j++;$p++;
				# 					}
				# 					else {&update($result->{'var'}, $result->{'gene_symbol'}, $result->{'refseq'}, 'VUCS Class U');$j++;$r++;}
				# 				}
				# 				else {$not_good_alt = 1}
				# 			}
				# 			elsif ($good_line[0] =~ /ExAC_AF=([\d\.e-]+);*/o && $not_good_alt == 0) {
				# 				if ($1 > $af_cutoff) {
				# 					&update($result->{'var'}, $result->{'gene_symbol'}, $result->{'refseq'}, 'VUCS Class F');$j++;$p++;
				# 				}
				# 				else {&update($result->{'var'}, $result->{'gene_symbol'}, $result->{'refseq'}, 'VUCS Class U');$j++;$r++;}
				# 			}
				# 		}
				# 	}
				# 	else {print "pb with vtemp file for VEP"}
				# }
			}
		}

		print $q->li("$i candidates and $j effectives ($p Class F, $r Class U) and $k NA NA USH2A < 0.16."), $q->end_ul();
	}
	elsif ($q->param('neg') && $q->param('neg') == 1) {
		my $date = U2_modules::U2_subs_1::get_date();
		my ($i, $j, $k) = (0, 0, 0);
		print $q->start_ul();
			my $info_text = U2_modules::U2_subs_2::info_text($q, 'class');
			$info_text =~ s/\\\'/\'/og;
			print $info_text, "\n",
						$q->end_ul(), "\n";

		print $q->br(), $q->br(), "\n",
			$q->start_ul();
		my $query = "SELECT a.*, b.*, c.gene_symbol FROM analyse_moleculaire a, valid_type_analyse b, gene c WHERE a.type_analyse = b.type_analyse AND a.refseq = c.refseq a.technical_valid = 't' AND a.result IS NULL AND b.form = 't';";
		my $sth = $dbh->prepare($query);
		my $res = $sth->execute();
		$i = $res;
		while (my $result = $sth->fetchrow_hashref()) {
			my $query_no = "SELECT a.nom_c, a.statut FROM variant2patient a, variant b WHERE a.nom_c = b.nom AND a.refseq = b.refseq AND a.type_analyse = '$result->{'type_analyse'}'AND a.num_pat = '$result->{'num_pat'}' AND a.id_pat = '$result->{'id_pat'}' AND a.refseq = '$result->{'refseq'}' AND b.classe IN ('VUCS class III', 'VUCS class IV', 'pathogenic');";
			#print $query_no;
			my $sth_no = $dbh->prepare($query_no);
			my $res_no = $sth_no->execute();
			my $count_mut = 0;
			my $gene_het;
			if ($res_no ne '0E0') {
				while (my $result_no = $sth_no->fetchrow_hashref()) {
					if ($result_no->{'statut'} eq 'homozygous') {
						&positive($result->{'id_pat'}, $result->{'num_pat'}, $result->{'type_analyse'}, $result->{'gene_symbol'}, $date);
						$k = &negative($result->{'id_pat'}, $result->{'num_pat'}, $result->{'type_analyse'}, $result->{'gene_symbol'}, $k, $date);
						$j++;
						last;
					}
					else {
						$count_mut++;
						$gene_het->{$result->{'nom_gene'}[0]}++;
						if ($gene_het->{$result->{'nom_gene'}[0]} == 2) {
							&positive($result->{'id_pat'}, $result->{'num_pat'}, $result->{'type_analyse'}, $result->{'gene_symbol'}, $date);
							$k = &negative($result->{'id_pat'}, $result->{'num_pat'}, $result->{'type_analyse'}, $result->{'gene_symbol'}, $k, $date);
							$j++;
							last;
						}
					}
				}
			}

		}
		#summary
		print $q->li("$i analyses examined and $j set as positives, $k set as negatives."), $q->end_ul();
	}
}
else {print $q->p($user->getName().", you are not allowed to launch this script. I am sorry.")}



##Basic end of USHVaM 2 perl scripts:

U2_modules::U2_subs_1::standard_end_html($q);

print $q->end_html();

exit();

##End of Basic end

##specific subs for current script

sub update {
	my ($var, $gene, $acc, $classe) = @_;
	my $update = "UPDATE variant SET classe = '$classe' WHERE nom = '$var' AND refseq = '$acc';";
	print $q->start_li().$q->span("$var set as $classe for ").$q->em($gene).$q->span(" ($acc)").$q->end_li().$q->br();
	#print $update."<br/>";
	$dbh->do($update);
}

sub update_type_arn {
	my ($var, $gene, $acc) = @_;
	my $update = "UPDATE variant SET type_arn = 'altered' WHERE nom = '$var' AND refseq = '$acc';";
	$dbh->do($update);
}

sub positive {
	my ($id, $num, $type, $gene, $date) = @_;
	my $pos = "UPDATE analyse_moleculaire  SET result = 't', referee = 'ushvam2', date_result = '$date' FROM gene b WHERE analyse_moleculaire.refseq = b.refseq AND analyse_moleculaire.id_pat = '$id' AND analyse_moleculaire.num_pat = '$num' AND analyse_moleculaire.type_analyse = '$type' AND b.gene_symbol = '$gene';";
	print $q->start_li().$q->span("$id$num set as positive for ").$q->em($gene).$q->span(" ($type)").$q->end_li();
	#print $pos.$q->br();
	$dbh->do($pos);
}

sub negative {
	my ($id, $num, $type, $gene, $k, $date) = @_;
	#query to get experiences only recording UV1 or neutral
	my $query = "SELECT DISTINCT(b.gene_symbol) as gene, a.type_analyse FROM variant2patient a, gene b WHERE a.refseq = b.refseq AND a.num_pat = '$num' AND a.id_pat = '$id' AND ROW(b.gene_symbol, a.type_analyse) NOT IN (ROW('$gene', '$type')) AND ROW(b.gene_symbol, a.type_analyse) NOT IN (SELECT c.gene_symbol, a.type_analyse FROM variant2patient a, variant b, gene c WHERE a.nom_c = b.nom AND a.refseq = b.refseq AND b.refseq = c.refseq AND a.num_pat = '$num' AND a.id_pat ='$id' AND ROW(c.gene_symbol, a.type_analyse) NOT IN (ROW('$gene', '$type')) AND b.classe NOT IN ('neutral', 'VUCS class I'));";
	my $sth = $dbh->prepare($query);
	my $res = $sth->execute();
	if ($res ne '0E0') {
		while (my $result = $sth->fetchrow_hashref()) {
			#print $result->{'gene'}."-".$result->{'type_analyse'}.$q->br();
			my $neg = "UPDATE analyse_moleculaire a SET a.result = 'f', a.referee = 'ushvam2', a.date_result = '$date' FROM gene b WHERE a.refseq = b.refseq AND a.id_pat = '$id' AND a.num_pat = '$num' AND a.type_analyse = '$result->{'type_analyse'}' AND b.gene_symbol = '$result->{'gene'}';";
			#print $neg.$q->br();
			print $q->start_li().$q->span("$id$num set as negative for ").$q->em($result->{'gene'}).$q->span(" ($result->{'type_analyse'})").$q->end_li();
			$dbh->do($neg);
			$k++;
		}
	}
	return $k;
	#SELECT DISTINCT(nom_gene[1], type_analyse) FROM variant2patient WHERE num_pat = '2554' AND id_pat = 'SU' AND ROW(nom_gene[1], type_analyse) NOT IN (ROW('GPR98', 'SANGER')) AND ROW(nom_gene[1], type_analyse) NOT IN (SELECT a.nom_gene[1], a.type_analyse FROM variant2patient a, variant b WHERE a.nom_c = b.nom AND a.nom_gene = b.nom_gene AND a.num_pat = '2554' AND a.id_pat ='SU' AND ROW(a.nom_gene[1], a.type_analyse) NOT IN (ROW('GPR98', 'SANGER')) AND b.classe NOT IN ('neutral', 'VUCS class I'));
}
