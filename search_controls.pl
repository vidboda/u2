BEGIN {delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV', 'PATH'};}

use strict;
#use CGI;#in startup.pl
#use DBI;
#use AppConfig qw(:expand :argcount);
use URI::Escape::XS qw/uri_escape uri_unescape/;
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
#		this script creates a list of exons/genes with patients that do not carry variants in it


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



my @styles = ($CSS_PATH.'font-awesome.min.css', $CSS_PATH.'w3.css', $CSS_DEFAULT, $CSS_PATH.'form.css', $CSS_PATH.'jquery-ui-1.12.1.min.css', $CSS_PATH.'datatables.min.css');

my $q = new CGI;

my $dbh = DBI->connect(    "DBI:Pg:database=$DB;host=$HOST;",
                        $DB_USER,
                        $DB_PASSWORD,
                        {'RaiseError' => 1}
                ) or die $DBI::errstr;


print $q->header(-type => 'text/html', -'cache-control' => 'no-cache'),
	$q->start_html(-title=>"U2 search controls tool",
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
				-src => $JS_PATH.'jquery-ui-1.12.1.min.js', 'defer' => 'defer'},
				{-language => 'javascript',
				-src => $JS_PATH.'datatables.min.js', 'defer' => 'defer'},
				{-language => 'javascript',
				-src => $JS_DEFAULT, 'defer' => 'defer'}],
                        -encoding => 'ISO-8859-1');

my $user = U2_modules::U2_users_1->new();


U2_modules::U2_subs_1::standard_begin_html($q, $user->getName(), $dbh);

##end of Basic init


##Init of specific cgi params
my $step = U2_modules::U2_subs_1::check_step($q);




if ($step == 1) {
	#build form
	my $text = $q->span('This function will alow you to select candidates controls based on the following rules:').$q->br().
		$q->start_ul({'class' => 'w3-ul w3-hoverable'}).
				$q->li({'class' => 'w3-padding-8 w3-hover-light-grey'}, "The patient MUST be a proband AND").
				$q->li({'class' => 'w3-padding-8 w3-hover-light-grey'}, "MUST have been sequenced either by Sanger or NGS in the specified gene OR").
				$q->li({'class' => 'w3-padding-8 w3-hover-light-grey'}, "Only by NGS for UTRs AND").
				$q->li({'class' => 'w3-padding-8 w3-hover-light-grey'}, "The sequencing analyses MUST NOT report variants in the selected exon and flanking introns AND").
				$q->li({'class' => 'w3-padding-8 w3-hover-light-grey'}, "For genes included in USHVaM (USH genes mainly), the exon MUST NOT be reported as not analysed.").
		$q->end_ul().$q->br().
		$q->span('Fill in the form below by choosing a gene and an exon:');
	print $q->start_div({'style' => 'width:70%'}).U2_modules::U2_subs_2::info_panel($text, $q).$q->end_div();

	print 	$q->start_div({'align' => 'center'}),
			$q->start_form({'action' => '', 'method' => 'post', 'class' => 'w3-container w3-card-4 w3-light-grey w3-text-blue w3-margin w3-large', 'id' => 'exon_form', 'enctype' => &CGI::URL_ENCODED, 'style' => 'width:50%'}),
			$q->input({'type' => 'hidden', 'name' => 'step', 'value' => '2'}), "\n",
			#$q->start_fieldset(),
			$q->h2('Please Select:'), $q->br(),
			$q->start_div({'class' => 'w3-row w3-section w3-padding-16'}),
				$q->start_div({'class' => 'w3-col w3-right-align',  'style' => 'width:40%'}),
					$q->span({'for' => 'gene'}, 'Gene:&nbsp;&nbsp;'),
				$q->end_div(), "\n",
				$q->start_div({'class' => 'w3-rest'});
U2_modules::U2_subs_1::select_genes_grouped($q, 'genes_select', 'exon_form');
print 				$q->end_div(), "\n",
			$q->end_div(), "\n",

			$q->start_div({'class' => 'w3-row w3-section w3-padding-16'}),
				$q->start_div({'class' => 'w3-col w3-right-align',  'style' => 'width:40%'}),
					$q->span({'for' => 'exons'}, 'Exon:&nbsp;&nbsp;'),
				$q->end_div(), "\n",
				$q->start_div({'class' => 'w3-rest'}),
						$q->span({'id' => 'ajax_exons'}),
				$q->end_div(), "\n",
			$q->end_div(), "\n",
			$q->br(),
			$q->submit({'value' => 'Search!', 'form' => 'exon_form', 'class' => 'w3-btn w3-blue'}), $q->br(), $q->br(), "\n", $q->br(),
		$q->end_form(), $q->end_div(), "\n";
}
elsif ($step == 2) {
	#perform actual search
	my ($gene, $second_name) = U2_modules::U2_subs_1::check_gene($q, $dbh);
	my $exon;
	if ($q->param('exons') && $q->param('exons') =~ /([\w-]{1,2})/o) {$exon = $1;}
	else {die 'bad exon param'}
	my $nom_seg = U2_modules::U2_subs_1::get_nom_segment_main($exon, $gene, $dbh);
	my $techniques = "'SANGER', '454-19', '454-28'";
	if ($nom_seg =~ /UTR/) {$techniques = "'454-19', '454-28'"}

	my $query = "SELECT numero, identifiant FROM patient WHERE proband = 't' AND (ROW(numero, identifiant) IN (SELECT a.num_pat, a.id_pat FROM analyse_moleculaire a, gene b WHERE a.refseq = b.refseq AND a.type_analyse IN ($techniques) AND b.gene_symbol = '$gene')) AND (ROW (numero, identifiant) NOT IN (SELECT a.num_pat, a.id_pat FROM variant2patient a, variant b, gene c WHERE a.nom_c = b.nom AND a.refseq = b.refseq AND b.refseq = c.refseq AND c.gene_symbol = '$gene' AND (b.num_segment = '$exon' OR b.num_segment = '".($exon+1)."'))) AND (ROW(numero, identifiant) NOT IN (SELECT a.num_pat, a.id_pat FROM segment_non_analyse a, gene b WHERE a.refseq = b.refseq AND b.gene_symbol = '$gene' AND a.num_segment = '$exon')) ORDER BY identifiant, numero;";
	my $sth = $dbh->prepare($query);
	my $res = $sth->execute();

	if ($res ne '0E0') {
		my $text = $q->span("Please consider the $res candidate samples below as controls for Amplicon $nom_seg in ").$q->em($gene).$q->span(':');
		print U2_modules::U2_subs_2::info_panel($text, $q);
		#print $q->start_p({'class' => 'w3-margin'}), $q->span("Please consider the $res candidate samples below as controls for Amplicon $nom_seg in "), $q->em($gene), $q->end_p(),
		print $q->start_div({'class' => 'w3-container', 'style' => 'width:50%'}), $q->start_ul({'class' => 'w3-ul w3-hoverable'}), "\n";
		while (my $result = $sth->fetchrow_hashref()) {
			print $q->start_li({'class' => 'w3-padding-8 w3-hover-light-grey'}), $q->a({'href' => "patient_genotype.pl?sample=".$result->{'identifiant'}.$result->{'numero'}."&amp;gene=$gene", 'target' => '_blank'}, $result->{'identifiant'}.$result->{'numero'}), $q->end_li();
		}
	}
	else {
		print U2_modules::U2_subs_2::danger_panel("Sorry, no candidate sample found.", $q);
	}
	print $q->end_ul(), $q->end_div(), $q->br(), $q->br(),
		$q->start_p({'class' => 'w3-margin'}), $q->span("Try another "), $q->a({'href' => 'search_controls.pl?step=1'}, "exon"), $q->end_p();
}
if ($q->param('iv') && $q->param('iv') == 1 && $step == 3) {
	#identitovigilance
	if ($q->param('run') && $q->param('run') =~ /([\w-]+)/o) {
		my $run_id = $1;
		&intro_text($q, $run_id);
		#get all runs of the same analysis type
		my ($run_list, $run_list_html) = ('', '');
		if ($q->param('analysis')) {
			my $analysis = U2_modules::U2_subs_1::check_analysis($q, $dbh, 'filtering');
			my $query_runs = "SELECT DISTINCT(run_id) FROM miseq_analysis WHERE type_analyse = '$analysis' AND run_id <> '$run_id' ORDER BY run_id;";
			my $sth = $dbh->prepare($query_runs);
			my $res = $sth->execute();
			if ($res ne '0E0') {
				$run_list_html = $q->h3('Select one or more runs to add to the query:');
				while (my $result = $sth->fetchrow_hashref()) {
					$run_list_html .= $q->input({'class' => 'w3-check', 'type' => 'checkbox', 'name' => 'run_ids', 'value' => $result->{'run_id'}}) .
										$q->label($result->{'run_id'}) .
									$q->br();
				}
				$run_list_html .= $q->end_p();
			}
		}

		#get patients for the run
		print $q->start_ul();
		if ($q->param('sample')) {
			my ($id, $number) = U2_modules::U2_subs_1::sample2idnum(uc($q->param('sample')), $q);
			&get_patient_table($id, $number, $run_id, '0', $run_list, $run_list_html, '0');
		}
		else {
			my $query = "SELECT num_pat, id_pat FROM miseq_analysis WHERE run_id = '$run_id';";
			my $sth = $dbh->prepare($query);
			my $res = $sth->execute();
			while (my $result = $sth->fetchrow_hashref()) {
				#build patient list
				&get_patient_table($result->{'id_pat'}, $result->{'num_pat'}, $run_id, '0', $run_list, $run_list_html, '1');
			}
		}
	}

}
if ($q->param('iv') && $q->param('iv') == 2 && $step == 4) {
	#print $q->param('run_ids');
	my @runs = $q->param('run_ids');
	if ($q->param('run_id') && $q->param('run_id') =~ /([\w-]+)/o) {
		my $run_id = $1;
		my $run_list_sql = '(';
		foreach (@runs) {
			$run_list_sql .= "'".$_."', "
		}
		$run_list_sql .= "'".$run_id."')";
		my $run_list_html = '';
		#print $run_list_sql;
		&intro_text($q, $run_id);
		#get patients for the run
		print $q->start_ul();
		if ($q->param('sample')) {
			my ($id, $number) = U2_modules::U2_subs_1::sample2idnum(uc($q->param('sample')), $q);
			&get_patient_table($id, $number, $run_id, '1', $run_list_sql, $run_list_html, '0');
		}
		else {
			my $query = "SELECT num_pat, id_pat FROM miseq_analysis WHERE run_id = '$run_id';";
			my $sth = $dbh->prepare($query);
			my $res = $sth->execute();
			while (my $result = $sth->fetchrow_hashref()) {
				#build patient list
				&get_patient_table($result->{'id_pat'}, $result->{'num_pat'}, $run_id, '1', $run_list_sql, $run_list_html, '1');
			}
		}
	}
}



##Basic end of USHVaM 2 perl scripts:

U2_modules::U2_subs_1::standard_end_html($q);

print $q->end_html();

exit();

##End of Basic end

##specific subs for current script

sub get_patient_table {
	my ($id, $num, $run_id, $multiple_run, $run_list, $run_list_html, $multiple_sample) = @_;
	my $query_snp = "SELECT DISTINCT(a.nom_c), c.gene_symbol, c.refseq, a.statut FROM variant2patient a, variant b, gene c WHERE a.nom_c = b.nom AND a.refseq = b.refseq AND b.refseq = c.refseq AND a.num_pat = '$num' AND a.id_pat = '$id' AND a.msr_filter = 'PASS' AND b.type_adn = 'substitution' AND b.classe NOT IN ('VUCS Class III', 'VUCS Class IV', 'pathogenic') AND (a.nom_c, a.refseq) NOT IN (SELECT a.nom_c, a.refseq FROM variant2patient a, miseq_analysis b WHERE a.num_pat = b.num_pat AND a.id_pat = b.id_pat AND a.type_analyse = b.type_analyse AND b.run_id = '$run_id' AND (b.id_pat || b.num_pat) <> '$id$num') ORDER BY c.gene_symbol, a.nom_c;";
	if ($multiple_run == 1) {#multiple runs processed at the same time (automated library prep)
		$query_snp = "SELECT DISTINCT(a.nom_c), c.gene_symbol, c.refseq, a.statut FROM variant2patient a, variant b, gene c WHERE a.nom_c = b.nom AND a.refseq = b.refseq AND b.refseq = c.refseq AND a.num_pat = '$num' AND a.id_pat = '$id' AND a.msr_filter = 'PASS' AND b.type_adn = 'substitution' AND b.classe NOT IN ('VUCS Class III', 'VUCS Class IV', 'pathogenic') AND (a.nom_c, a.refseq) NOT IN (SELECT a.nom_c, a.refseq FROM variant2patient a, miseq_analysis b WHERE a.num_pat = b.num_pat AND a.id_pat = b.id_pat AND a.type_analyse = b.type_analyse AND b.run_id IN $run_list AND (b.id_pat || b.num_pat) <> '$id$num') ORDER BY c.gene_symbol, a.nom_c;";
	}

	my $sth_snp = $dbh->prepare($query_snp);
	my $res_snp = $sth_snp->execute();

	my $table_js = "\$('#".$id.$num."_table').DataTable({
		aaSorting:[],
		paging: false
		//scrollY: 400
	});";
	print $q->start_li(), "\n",
			$q->start_big({'name' => "$id$num"}), "\n",
				$q->a({'href' => "patient_file.pl?sample=$id$num", 'target' => '_blank'}, "$id$num"), "\n", "&nbsp;&nbsp;&nbsp;&nbsp;";
	if ($multiple_run == 0){
		print $q->span({'onclick' => '$("#run_list").toggle();', 'class' => 'w3-button w3-ripple w3-blue w3-rest w3-hover-light-grey'}, 'Click to add one or several runs to the analysis')
	}
	print		$q->end_big(), "\n", $q->br(), $q->br(), "\n";
	if ($multiple_run == 0) {
		print	$q->start_div({'style' => 'display:none;width:50%;', 'class' => 'w3-margin w3-container', 'id' => 'run_list'}), "\n",
				$q->start_form({'class' => 'w3-container w3-card-4', 'id' => 'multiple_runs', 'name' => 'multiple_runs', 'action' => 'search_controls.pl', 'method' => 'get'}), "\n",
					$q->input({'type' => 'hidden', 'name' => 'iv', 'value' => '2', 'form' => 'multiple_runs'}), "\n";
		if ($multiple_sample != 1) {print $q->input({'type' => 'hidden', 'name' => 'sample', 'value' => $id.$num, 'form' => 'multiple_runs'}), "\n"}
			print			$q->input({'type' => 'hidden', 'name' => 'step', 'value' => '4', 'form' => 'multiple_runs'}), "\n",
					$q->input({'type' => 'hidden', 'name' => 'run_id', 'value' => $run_id, 'form' => 'multiple_runs'}), "\n",
					$run_list_html, "\n",
					$q->input({'type' => 'submit', 'onclick' => '$("html").css("cursor", "progress");$(".w3-button").css("cursor", "progress");$("#submit_btn").css("disabled","disabled");', 'class' => 'w3-button w3-ripple w3-blue w3-rest w3-hover-light-grey', 'value' => 'Multiple run tracking', 'id' => 'submit_btn', 'form' => 'multiple_runs'}), $q->br(), $q->br(), "\n",
				$q->end_form(), "\n",
			$q->end_div(), "\n", $q->br(), "\n",
			$q->br(), "\n";
	}
	print	$q->end_li(), "\n",
		$q->start_div({'class' => 'container'}), $q->start_table({'class' => 'technical great_table', 'id' => $id.$num.'_table'});
	if ($multiple_run == 0) {
		print $q->caption("Private SNPs of $id$num in run $run_id:"), $q->start_thead(), "\n";
	}
	else {
		print $q->caption("Private SNPs of $id$num in run $run_list:"), $q->start_thead(), "\n";
	}
	print		$q->start_Tr(), "\n",
				$q->th({'class' => 'left_general'}, "$res_snp Variants"), "\n",
				$q->th({'class' => 'left_general'}, 'Gene / Transcript'), "\n",
				$q->th({'class' => 'left_general'}, 'Status'), "\n",
			$q->end_Tr(), "\n",
			$q->end_thead(), "\n",
			$q->start_tbody(), "\n";
	while (my $result_snp = $sth_snp->fetchrow_hashref()) {
		print $q->start_Tr(), "\n",
			$q->start_td(), $q->a({'href' => "variant.pl?nom_c=".uri_escape($result_snp->{'nom_c'})."&gene=$result_snp->{'gene_symbol'}&accession=$result_snp->{'refseq'}", 'target' => '_blank', 'title' => 'Click to open variant page in new tab'}, $result_snp->{'nom_c'}),$q->end_td(), "\n",
			$q->start_td(), $q->em({'onclick' => "gene_choice('$result_snp->{'gene_symbol'}');", 'class' => 'pointer', 'title' => 'click to get somewhere'}, $result_snp->{'gene_symbol'}), $q->span(" / "), $q->a({'href' => "http://www.ncbi.nlm.nih.gov/nuccore/$result_snp->{'refseq'}", 'target' => '_blank', 'title' => 'Click to open GenBank in new tab'}, $result_snp->{'refseq'}),$q->end_td(), "\n",
			$q->td($result_snp->{'statut'}), "\n",
		$q->end_Tr();
	}
	print $q->end_tbody(), $q->end_table(), $q->end_div(), $q->end_li(), $q->script({'type' => 'text/javascript', 'defer' => 'defer'}, $table_js);

}

sub intro_text {
	my ($q, $run_id) = @_;
	my $query_robot = "SELECT robot FROM illumina_run WHERE id = '$run_id';";
	my $res_robot = $dbh->selectrow_hashref($query_robot);
	my $text_robot = '';
	if ($res_robot->{'robot'} == 1) {$text_robot =  $q->span({'class' => 'red'}, 'prepared with the robot (Load the other runs!)')}
	print $q->start_div(), $q->start_p({'class' => 'center'}), $q->start_big(), $q->strong('Sample Tracking'), $q->end_strong(), $q->end_big(), $q->end_p(), $q->end_div(), "\n";
		print $q->br(), $q->start_p(), $q->span("This function will allow you to select candidates SNP for the patients of run $run_id $text_robot based on the following rules:"), $q->start_ul(),
			$q->li("The variants have to be substitutions AND "),
			$q->li("must have a filter 'PASS' AND "),
			$q->li("must not be classified as VUCS Class III, IV or pathogenic AND"),
			$q->li("must not be carried by another patient in the same run."),
			$q->end_ul(), $q->end_p(), "\n";
}
