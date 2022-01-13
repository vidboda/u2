BEGIN {delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV', 'PATH'};}

use strict;
use File::Copy;
use U2_modules::U2_users_1;
use U2_modules::U2_init_1;
use U2_modules::U2_subs_1;
use U2_modules::U2_subs_2;

#    This program is part of ushvam2, USHer VAriant Manager version 2
#    Copyright (C) 2012-2020  David Baux
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
#		Script to propose a list of genes to submit to covreport java software http://jdotsoft.com/CovReport.php


## Basic init of USHVaM 2 perl scripts: slightly modified with custom js
#	env variables
#	get config infos
#	initialize DB connection
#	initialize HTML (change page title if needed, as well as CSS files and JS)
#	Load standard JS, CSS and fixed html
#	identify users
#	just copy at the beginning of each script

$CGI::POST_MAX = 1024*10; #* 100;  # max 1K posts
$CGI::DISABLE_UPLOADS = 1;



my $config_file = U2_modules::U2_init_1->getConfFile();
my $config = U2_modules::U2_init_1->initConfig();
$config->file($config_file);# or die $!;
my $DB = $config->DB();
my $HOST = $config->HOST();
my $HOME = $config->HOME_IP();
my $DB_USER = $config->DB_USER();
my $DB_PASSWORD = $config->DB_PASSWORD();
my $CSS_PATH = $config->CSS_PATH();
my $CSS_DEFAULT = $config->CSS_DEFAULT();
my $JS_PATH = $config->JS_PATH();
my $JS_DEFAULT = $config->JS_DEFAULT();
my $HTDOCS_PATH = $config->HTDOCS_PATH();
my $ABSOLUTE_HTDOCS_PATH = $config->ABSOLUTE_HTDOCS_PATH();
my $PERL_SCRIPTS_HOME = $config->PERL_SCRIPTS_HOME();

my @styles = ($CSS_PATH.'font-awesome.min.css', $CSS_PATH.'w3.css', $CSS_DEFAULT, $CSS_PATH.'fullsize/fullsize.css', $CSS_PATH.'jquery.alerts.css');

my $q = new CGI;

my $dbh = DBI->connect(    "DBI:Pg:database=$DB;host=$HOST;",
        $DB_USER,
        $DB_PASSWORD,
        {'RaiseError' => 1}
) or die $DBI::errstr;


my $user = U2_modules::U2_users_1->new();

my $js = "
	function unselect_checkboxes() {
			\$('[type=\"checkbox\"].w3-check').prop('checked', false);
	}
";

print $q->header(-type => 'text/html', -'cache-control' => 'no-cache'),
	$q->start_html(-title=>"USHVaM 2",
                        -lang => 'en',
                        -style => {-src => \@styles},
                        -head => [
				$q->Link({-rel => 'icon',
					-type => 'image/gif',
					-href => $HTDOCS_PATH.'data/img/animated_favicon1.gif'}),
				$q->Link({-rel => 'search',
					-type => 'application/opensearchdescription+xml',
					-title => 'U2 CovReport',
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
								-src => $JS_PATH.'jquery.alerts.js', 'defer' => 'defer'},
								$js,
                                {-language => 'javascript',
                                -src => $JS_PATH.'jquery.autocomplete.min.js', 'defer' => 'defer'},
                                {-language => 'javascript',
                                -src => $JS_DEFAULT, 'defer' => 'defer'}],
                        -encoding => 'ISO-8859-1');

if ($user->isPublic()) {$q->redirect("home_public.pl");exit;}
else {U2_modules::U2_subs_1::standard_begin_html($q, $user->getName(), $dbh)}

## end of Basic init

## We require a sample ID, an analysis (NGS), a filter, a step number and an alignment file absolute path
my ($id, $number) = U2_modules::U2_subs_1::sample2idnum(uc($q->param('sample')), $q);
my $analysis = U2_modules::U2_subs_1::check_analysis($q, $dbh, 'filtering');
my $filter = U2_modules::U2_subs_1::check_filter($q);
my $step = U2_modules::U2_subs_1::check_step($q);
if ($q->param ('align_file') =~ /\/ushvam2\/RS_data\/data\//o && $step == 1) {

	my ($dfn, $rp, $usher) = &assign_values($filter);
	my $filter_subquery = '';
	# print $filter;
	# if ($filter eq 'DFN') {$filter_subquery = "((dfn = '$dfn' AND rp = '$rp' AND usher = '$usher') OR nom[1] = 'CIB2') AND"}
	if ($filter eq 'DFN') {$filter_subquery = "(dfn = '$dfn' AND rp = '$rp' AND usher = '$usher') AND"}
	elsif ($filter eq 'DFN-USH') {$filter_subquery = "(dfn = '$dfn' OR usher = '$usher') AND rp = '$rp' AND"}
	elsif ($filter eq 'USH') {$filter_subquery = " usher = '$usher' AND"}
	# elsif ($filter eq 'RP') {$filter_subquery = "(rp = '$rp' OR nom[1] in ('USH2A', 'CLRN1')) AND nom[1] <> 'CHM' AND"}
  elsif ($filter eq 'RP') {$filter_subquery = "(rp = '$rp' OR nom[1]) AND nom[1] <> 'CHM' AND"}
	elsif ($filter eq 'RP-USH') {$filter_subquery = "(rp = '$rp' OR usher = '$usher') AND dfn = '$dfn' AND"}
	elsif ($filter eq 'CHM') {$filter_subquery = "nom[1] = 'CHM' AND "}

	my $query = "SELECT nom[1] AS gene_name, nom[2] AS nm, diag FROM gene WHERE $filter_subquery \"$analysis\" = 't' AND main = 't' AND nom[1] <> 'CEVA' ORDER BY nom[1];";
	# print $query;
	my $sth = $dbh->prepare($query);
	my $res = $sth->execute();

	print $q->start_p({'class' => 'center title'}), $q->start_big(), $q->strong("$id$number ($filter) CovReport Genes Selection"), $q->end_big(), $q->end_p(), "\n";
	my $text = "Analyse: $analysis - $res genes eligible";
	print U2_modules::U2_subs_2::info_panel($text, $q);
	$text = $q->span("<br />You will find below a list of genes included in the sample's filter. Unselect those that you want to remove. An email will be sent to ".$user->getEmail()." when the report is ready but do not close the window!!");
	print U2_modules::U2_subs_2::info_panel($text, $q);
	print $q->br(),
		$q->start_div({'class' => 'w3-center'}), $q->span({'class' => 'w3-btn w3-blue w3-center', 'onclick' => 'unselect_checkboxes();'}, 'Unselect all'), $q->end_div(), "\n",
		$q->br(), "\n",
		$q->start_div({'align' => 'center'}), "\n",
			$q->start_form({'action' => 'patient_covreport.pl', 'method' => 'post', 'class' => 'w3-container w3-card-4 w3-light-grey w3-text-blue w3-margin', 'id' => 'covreport_form', 'enctype' => &CGI::URL_ENCODED, 'style' => 'width:70%', 'onsubmit' => '$("html").css("cursor","progress");$("#CVsubmit").prop("disabled",true);'}), "\n",
				$q->input({'type' => 'hidden', 'name' => 'filter', 'value' => $filter, 'form' => 'covreport_form'}), "\n",
				$q->input({'type' => 'hidden', 'name' => 'step', 'value' => 2, 'form' => 'covreport_form'}), "\n",
				$q->input({'type' => 'hidden', 'name' => 'sample', 'value' => $id.$number, 'form' => 'covreport_form'}), "\n",
				$q->input({'type' => 'hidden', 'name' => 'analysis', 'value' => $analysis, 'form' => 'covreport_form'}), "\n",
				$q->input({'type' => 'hidden', 'name' => 'align_file', 'value' => $q->param('align_file'), 'form' => 'covreport_form'}), "\n",
				$q->h3({'class' => 'w3-center w3-padding-16'}, 'Uncheck the genes you don\'t want in the report:');
				my $i = 0;
				while (my $result = $sth->fetchrow_hashref()) {
					if ($i == 0) {print $q->start_div({'class' => 'w3-row-padding w3-section w3-padding-8 w3-left-align'}), "\n"}
					if ($i%4 == 0 && $i > 0) {
						print $q->end_div(),
							$q->start_div({'class' => 'w3-row-padding w3-section w3-padding-8 w3-left-align'}), "\n";
					}
					#my $check = 'false';
					#if ($result->{'diag'} == 1) {$check = 'true'}
					#print $result->{'diag'};
					print $q->start_div({'class' => 'w3-quarter'}), "\n";
					if ($result->{'diag'} == 1) {
						print $q->input({'class' => 'w3-check', 'type' => 'checkbox', 'name' => 'transcript', 'value' => $result->{'nm'}, 'id' => $result->{'nm'}, 'form' => 'covreport_form' , 'checked' => 'true'}), "\n";
					}
					else {
						print $q->input({'class' => 'w3-check', 'type' => 'checkbox', 'name' => 'transcript', 'value' => $result->{'nm'}, 'id' => $result->{'nm'}, 'form' => 'covreport_form'}), "\n";
					}

							#"<input class='w3-check' form='covreport_form' id='".$result->{'nm'}."' name='transcript' type='checkbox' value='".$result->{'nm'}."'  />\n",
							#$q->input({'class' => 'w3-check', 'type' => 'checkbox', 'name' => 'transcript', 'value' => $result->{'nm'}, 'id' => $result->{'nm'}, 'form' => 'covreport_form' , 'checked' => $check}), "\n",
							#$q->checkbox({'class' => 'w3-check', 'name' => 'transcript', 'value' => $result->{'nm'}, 'id' => $result->{'nm'}, 'form' => 'covreport_form', 'checked' => 'true'}), "\n",
					print		$q->label({'for' => $result->{'nm'}}, $result->{'gene_name'}),
						$q->end_div(), "\n";
					$i++;
				}
				print $q->end_div(), $q->br(), "\n",
				$q->submit({'value' => 'Launch CovReport', 'id' => 'CVsubmit', 'class' => 'w3-btn w3-blue', 'form' => 'covreport_form'}), $q->br(), $q->br(), "\n", $q->br(), "\n",,
			$q->end_form(),
		$q->end_div(), $q->br(), $q->br(), "\n";
}
elsif ($q->param ('align_file') =~ /\/ushvam2\/RS_data\/data\//o && $step == 2) {
	my $align_file = $q->param ('align_file');
	my $cov_report_dir = $ABSOLUTE_HTDOCS_PATH.'CovReport/';
	my $cov_report_sh = $cov_report_dir.'covreport.sh';
	#remove previous file
	if (-f $cov_report_dir."CovReport/pdf-results/".$id.$number."-".$analysis."-".$filter."-custom_coverage.pdf") {
		unlink $cov_report_dir."CovReport/pdf-results/".$id.$number."-".$analysis."-".$filter."-custom_coverage.pdf"
	}
	# set up a gene list file with the genes of interest and launch covreport
	my @transcripts = $q->param('transcript');
	mkdir $cov_report_dir."tmp_dir_$id$number-$analysis-$filter-custom";
	open(F, ">".$cov_report_dir."tmp_dir_$id$number-$analysis-$filter-custom/$id$number-$analysis-$filter-genelist.txt") or die $!;
	foreach (@transcripts) {
		# create a gene list
		print F "$_\n";
	}
	close F;

	print STDERR "cd $cov_report_dir && /bin/sh $cov_report_sh -out $id$number-$analysis-$filter-custom -bam $align_file -bed u2_beds/$analysis.bed -NM tmp_dir_$id$number-$analysis-$filter-custom/$id$number-$analysis-$filter-genelist.txt -f $filter\n";
	`cd $cov_report_dir && /bin/sh $cov_report_sh -out $id$number-$analysis-$filter-custom -bam $align_file -bed u2_beds/$analysis.bed -NM tmp_dir_$id$number-$analysis-$filter-custom/$id$number-$analysis-$filter-genelist.txt -f $filter`;

	if (-e $ABSOLUTE_HTDOCS_PATH."CovReport/CovReport/pdf-results/".$id.$number."-".$analysis."-".$filter."-custom_coverage.pdf") {
		print $q->start_div({'class' => 'w3-center'}), $q->start_p().$q->a({'class' => 'w3-btn w3-blue', 'href' => $HTDOCS_PATH."DS_data/covreport/".$id.$number."/".$id.$number."-".$analysis."-".$filter."-custom_coverage.pdf", 'target' => '_blank'}, 'Download CovReport').$q->end_p(), $q->end_div();
    # print $q->start_div({'class' => 'w3-center'}), $q->start_p().$q->a({'class' => 'w3-btn w3-blue', 'href' => $HTDOCS_PATH."CovReport/CovReport/pdf-results/".$id.$number."-".$analysis."-".$filter."-custom_coverage.pdf", 'target' => '_blank'}, 'Download CovReport').$q->end_p(), $q->end_div();
		U2_modules::U2_subs_2::send_general_mail($user, "Custom CovReport ready for $id$number-$analysis-$filter\n\n", "\nHi ".$user->getName().",\nYou can download the custom CovReport file here:\n$HOME/ushvam2/DS_data/covreport/$id$number/$id$number-$analysis-".$filter."-custom_coverage.pdf\n");
		# attempt to trigger autoFS
		open HANDLE, ">>".$ABSOLUTE_HTDOCS_PATH."DS_data/covreport/touch.txt";
		sleep 3;
		close HANDLE;
		mkdir($ABSOLUTE_HTDOCS_PATH."DS_data/covreport/".$id.$number);
		move($ABSOLUTE_HTDOCS_PATH."CovReport/CovReport/pdf-results/".$id.$number."-".$analysis."-".$filter."-custom_coverage.pdf", $ABSOLUTE_HTDOCS_PATH."DS_data/covreport/".$id.$number) or die $!;
	}
	else {
		print $q->span('Failed to generate coverage file');
		U2_modules::U2_subs_2::send_general_mail($user, "Custom CovReport failed for $id$number-$analysis-$filter\n\n", "\nHi ".$user->getName().",\nUnfortunately, your custom CovReport generation failed. You can forward this message to David for debugging.\nGene list:\n$HOME/ushvam2/CovReport/tmp_dir_$id$number-$analysis-$filter-custom/$id$number-$analysis-$filter-genelist.txt");
	}

}


##Basic end of USHVaM 2 perl scripts:


U2_modules::U2_subs_1::standard_end_html($q);

print $q->end_html();

exit();

##End of Basic end


sub assign_values {
	my $filter = shift;
	my $dfn = my $rp = my $usher = 'f';
	# print $filter;
	if ($filter =~ /DFN/o) {$dfn = 't'}
	if ($filter =~ /USH/o) {$usher = 't'}
	if ($filter =~ /RP/o) {$rp = 't'}
	if ($filter =~ /ALL/o) {$rp = 't', $dfn = 't', $usher = 't'}
	return $dfn, $rp, $usher;
}

exit 0;
