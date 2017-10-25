BEGIN {delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV', 'PATH'};}

use strict;
#use CGI;#in startup.pl
#use DBI;
#use AppConfig qw(:expand :argcount);
use Net::OpenSSH;
use U2_modules::U2_users_1;
use U2_modules::U2_init_1;
use U2_modules::U2_subs_1;

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
#		central page of patient's information


##EXTENDED Basic init of USHVaM 2 perl scripts: INCLUDES easy-comments, jQueryUI
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
my $ABSOLUTE_HTDOCS_PATH = $config->ABSOLUTE_HTDOCS_PATH();
my $RS_BASE_DIR = $config->RS_BASE_DIR();


my @styles = ($CSS_PATH.'w3.css', $CSS_DEFAULT, $CSS_PATH.'jquery-ui-1.10.3.custom.min.css');

my $q = new CGI;

my $dbh = DBI->connect(    "DBI:Pg:database=$DB;host=$HOST;",
                        $DB_USER,
                        $DB_PASSWORD,
                        {'RaiseError' => 1}
                ) or die $DBI::errstr;

#my $js = "   #####too many quotes imbricated - put in .js file
#	function getDefGenVariants(id, num) {
#		\$.ajax({
#			type: 'POST',
#			url: 'ajax.pl',
#			data: {asked: 'defgen', sample: id+num}
#			})
#		.done(function(msg) {
#			\$('#defgen').html('<div class=\"w3-modal-content w3-card-4\"><header class=\"w3-container w3-teal\"><span onclick=\"\$(\'#defgen\').hide();\" class=\"w3-button w3-display-topright\">&times;</span><h2>Export to DEFGEN:</h2></header><div class=\"w3-container\"><p class=\"w3-large\">\"+msg+\"</p></div></div>');
#			\$('#defgen').show();
#			//setDialog(msg);
#		});	
#	}
#	function setDialog(msg, type, nom) {
#		var \$dialog = \$('<div></div>')
#			.html(msg)
#			.dialog({
#			    autoOpen: false,
#			    title: \'Export to DEFGEN:\',
#			    width: 450,
#			});
#		\$dialog.dialog(\'open\');
#		\$(\'.ui-dialog\').zIndex(\'1002\');
#	}
#";

print $q->header(-type => 'text/html', -'cache-control' => 'no-cache'),
	$q->start_html(-title=>"U2 patient file",
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
				-src => $JS_PATH.'jquery-1.7.2.min.js'},
				{-language => 'javascript',
				-src => $JS_PATH.'jquery.fullsize.pack.js'},
				{-language => 'javascript',
				-src => $JS_PATH.'jquery.validate.min.js'},
				{-language => 'javascript',
				-src => $JS_PATH.'easy-comment/jquery.easy-comment.min.js'},
				{-language => 'javascript',
				-src => $JS_PATH.'jquery.alerts.js'},
				{-language => 'javascript',
				-src => $JS_PATH.'jquery-ui-1.10.3.custom.min.js'},				
				{-language => 'javascript',
				-src => $JS_PATH.'jquery.autocomplete.min.js'},
				{-language => 'javascript',
				-src => $JS_DEFAULT}],
                        -encoding => 'ISO-8859-1');

my $user = U2_modules::U2_users_1->new();


U2_modules::U2_subs_1::standard_begin_html($q, $user->getName());

##end of Basic init

my ($id, $number) = U2_modules::U2_subs_1::sample2idnum(uc($q->param('sample')), $q);
my $ACCENTS = $config->PERL_ACCENTS();
my $ANALYSIS_GRAPHS_ELIGIBLE = $config->ANALYSIS_GRAPHS_ELIGIBLE();
my $ANALYSIS_NGS_DATA_PATH = $config->ANALYSIS_NGS_DATA_PATH();
my $ABSOLUTE_HTDOCS_PATH  = $config->ABSOLUTE_HTDOCS_PATH();
my $HOME_IP = $config->HOME_IP();
my $DATABASES_PATH = $config->DATABASES_PATH();
#do not exactly need home, just IP
$HOME_IP =~ /(https*:\/\/[\d\.]+)\/.+/o;
$HOME_IP = $1;
#specific args for remote login to RS
my $SSH_RACKSTATION_BASE_DIR = $config->SSH_RACKSTATION_BASE_DIR();
my $SSH_RACKSTATION_MINISEQ_BASE_DIR = $config->SSH_RACKSTATION_MINISEQ_BASE_DIR();
#my $SSH_RACKSTATION_IP = $config->SSH_RACKSTATION_IP();
#my $validator = U2_modules::U2_users_1::isValidator($user);
#SSH style params for remote ftp
my $SSH_RACKSTATION_IP = $config->SSH_RACKSTATION_IP();
my $SSH_RACKSTATION_LOGIN = $config->SSH_RACKSTATION_LOGIN();
my $SSH_RACKSTATION_PASSWORD = $config->SSH_RACKSTATION_PASSWORD();
my $SSH_RACKSTATION_FTP_BASE_DIR = $config->SSH_RACKSTATION_FTP_BASE_DIR();
my $SSH_RACKSTATION_MINISEQ_FTP_BASE_DIR = $config->SSH_RACKSTATION_MINISEQ_FTP_BASE_DIR();
my $RS_BASE_DIR = $config->RS_BASE_DIR(); #RS mounted using autofs - meant to replace ssh and ftps in future versions




#get infos for patient, analysis

my $query = "SELECT * FROM patient WHERE numero = '$number' AND identifiant = '$id';";

my $result = $dbh->selectrow_hashref($query);

if ($result) {
	#while (my $result = $sth->fetchrow_hashref()) {
	my $proband = 'no';
	if ($result->{'proband'} == 1) {$proband = 'yes'}
	my $last_analysis = 'not recorded';
	###use analyse_moleculaire to get most recent analysis!!! date_last_analyse is useless in patient
	my $query_date_analyse = "SELECT date_analyse FROM analyse_moleculaire WHERE num_pat = '$number' AND id_pat = '$id' AND date_analyse IS NOT NULL ORDER BY date_analyse DESC LIMIT 1;";
	my $res = $dbh->selectrow_hashref($query_date_analyse);
	if ($res) {$last_analysis = $res->{'date_analyse'}}	
	#if ($result->{'date_last_analyse'} ne '') {$last_analysis = $result->{'date_last_analyse'}}
	
	
	
	###frame1
	
	print $q->start_div(), $q->start_p({'class' => 'center'}), $q->start_big(), $q->strong($result->{'identifiant'}.$result->{'numero'}), $q->span(": Sample from "), $q->strong("$result->{'first_name'} $result->{'last_name'}"), $q->end_big(), $q->end_p(), "\n";
	if ($result->{'commentaire'} ne 'NULL' && $result->{'commentaire'} ne '') {print $q->span({'class' => 'color1'}, 'Comments: '), $q->span("$result->{'commentaire'}")};
	print $q->br(), $q->br(), $q->start_div({'class' => 'container'}), "\n",
		$q->start_table({'class' => 'great_table technical'}), "\n",
			$q->start_Tr(), "\n",
				$q->th({'class' => 'left_general'}, 'Family ID'),
				$q->th({'class' => 'left_general'}, 'Phenotype'),
				$q->th({'class' => 'left_general'}, 'Gender'),
				$q->th({'class' => 'left_general'}, 'Origin'),
				$q->th({'class' => 'left_general'}, 'Index case'),
				$q->th({'class' => 'left_general'}, 'Created'),
				$q->th({'class' => 'left_general'}, 'Last analysis'),
				$q->th({'class' => 'left_general'}, 'Other sample(s)'),
			$q->end_Tr(), "\n",
			$q->start_Tr(), "\n",
				$q->start_td(), $q->span({'class' => 'pointer', 'onclick' => "window.open('engine.pl?search=$result->{'famille'}', '_blank')"}, $result->{'famille'}), $q->end_td(), "\n",
				$q->start_td(), $q->span({'class' => 'pointer', 'onclick' => "window.open('patients.pl?phenotype=$result->{'pathologie'}', '_blank')"}, $result->{'pathologie'}), $q->end_td(), "\n",
				$q->td($result->{'sexe'}), "\n",
				$q->td($result->{'origine'}), "\n",
				$q->td($proband), "\n",
				$q->td($result->{'date_creation'}), "\n",
				$q->td($last_analysis), "\n",
				$q->start_td();

	
	#$q->start_ul(),
	#$q->start_li(), $q->span({'class' => 'color1'}, 'Family ID: '), $q->span({'class' => 'pointer', 'onclick' => "window.open('engine.pl?search=$result->{'famille'}', '_blank')"}, $result->{'famille'}), $q->end_li(),
	#$q->start_li(), $q->span({'class' => 'color1'}, 'Phenotype: '), $q->strong({'id' => 'pathos'}, $result->{'pathologie'}), $q->end_li(),
	#$q->start_li(), $q->span({'class' => 'color1'}, 'Gender: '), $q->span($result->{'sexe'}), $q->end_li(),
	#$q->start_li(), $q->span({'class' => 'color1'}, 'Origin: '), $q->span($result->{'origine'}), $q->end_li(),
	#$q->start_li(), $q->span({'class' => 'color1'}, 'Index case: '), $q->span($proband), $q->end_li(),
	#$q->start_li(), $q->span({'class' => 'color1'}, 'Created: '), $q->span($result->{'date_creation'}), $q->end_li(),
	#$q->start_li(), $q->span({'class' => 'color1'}, 'Last analysis: '), $q->span($last_analysis), $q->end_li();
	#if ($result->{'commentaire'} ne 'NULL') {print $q->start_li(), $q->span({'class' => 'color1'}, 'Comments: '), $q->span($result->{'commentaire'}), $q->end_li()}
	#looks for other sample
	my ($first_name, $last_name) = ($result->{'first_name'}, $result->{'last_name'});
	$first_name =~ s/'/''/og;
	$last_name =~ s/'/''/og;
	
	my $query2 = "SELECT numero, identifiant FROM patient WHERE first_name = '$first_name' AND last_name = '$last_name' AND numero <> '$number'";
	my ($num_list, $id_list) = ("'$number'", "'$id'");
	#print $query2;
	my $sth2 = $dbh->prepare($query2);
	my $res2 = $sth2->execute();
	#print $q->start_li(), $q->span({'class' => 'color1'}, 'Other sample(s): ');
	if ($res2 ne '0E0') {
		while (my $result2 = $sth2->fetchrow_hashref()) {
			print $q->span('&nbsp;'), $q->a({'href' => "patient_file.pl?sample=$result2->{'identifiant'}$result2->{'numero'}"}, "$result2->{'identifiant'}$result2->{'numero'}"), $q->span(';');
			($num_list, $id_list) .= (", '$result2->{'numero'}'", ", '$result2->{'identifiant'}'");
		}
	}
	else {print $q->span("No")}
	print $q->end_td(), $q->end_Tr(), "\n", $q->end_table(), $q->end_div(), $q->br(), $q->br(), "\n";
	#print $q->end_li(), $q->end_ul(), $q->end_div(), "\n";
	
	### end frame1
	
	###frame 2
	
	my $filter = 'ALL'; #for NGS stuff
	my $valid_import = '';
	my $illumina_semaph = 0;
	my $query_filter = "SELECT filter, valid_import FROM miseq_analysis WHERE num_pat IN ($num_list) AND id_pat IN ($id_list) AND filter <> 'ALL';";
	my $res_filter = $dbh->selectrow_hashref($query_filter);
	if ($res_filter) {$filter = $res_filter->{'filter'};$valid_import = $res_filter->{'valid_import'}}
	print $q->start_div({'id' => 'defgen', 'class' => 'w3-modal'}), $q->end_div();
	print $q->start_div({'class' => 'in_line patient_file_frame'}),
		#$q->start_p(), $q->start_big(), $q->strong('Investigation summary:'), $q->end_big(), $q->end_p(),
		$q->p({'class' => 'title'}, 'Investigation summary:'),
		$q->start_ul(); #summary of the results => mutations, analysis
		
	#we need to consider filtering options
		
	my $important = "SELECT DISTINCT(a.nom_c), a.statut, b.classe, b.nom_gene[1], d.rp, d.dfn, d.usher FROM variant2patient a, variant b, patient c, gene d WHERE a.nom_c = b.nom AND a.nom_gene = b.nom_gene AND a.num_pat = c.numero AND a.id_pat = c.identifiant AND a.nom_gene = d.nom AND c.first_name = '$first_name' AND c.last_name = '$last_name' AND b.classe IN ('VUCS class III', 'VUCS class IV', 'pathogenic');";	
	my $sth3 = $dbh->prepare($important);
	my $res_important = $sth3->execute();
	if ($res_important ne '0E0') {
		while (my $result_important = $sth3->fetchrow_hashref()) {
			if ($filter eq 'RP' && $result_important->{'rp'} == 0) {next}
			elsif ($filter eq 'DFN' && $result_important->{'dfn'} == 0) {next}
			elsif ($filter eq 'USH' && $result_important->{'usher'} == 0) {next}
			elsif ($filter eq 'DFN-USH' && ($result_important->{'dfn'} == 0 && $result_important->{'usher'} == 0)) {next}
			elsif ($filter eq 'RP-USH' && ($result_important->{'rp'} == 0 && $result_important->{'usher'} == 0)) {next}
			elsif ($filter eq 'CHM' && $result_important->{'nom_gene'} ne 'CHM') {next}
			
			#if ($filter eq 'RP' && $result_important->{'dfn'} == 1) {next}
			#elsif ($filter eq 'DFN' && $result_important->{'rp'} == 1) {next}
			my $color = U2_modules::U2_subs_1::color_by_classe($result_important->{'classe'}, $dbh);
			print $q->start_li(), $q->font({'color' => $color}, $result_important->{'classe'}), $q->span( ", $result_important->{'statut'} variant identified in "), $q->start_em(), $q->a({'href' => "patient_genotype.pl?sample=$id$number&amp;gene=$result_important->{'nom_gene'}", 'target' => '_blank'}, $result_important->{'nom_gene'}), $q->end_em(), $q->end_li(), $q->br();
		}
		print $q->start_li(), $q->button({'onclick' => "getDefGenVariants('$id', '$number');", 'value' => 'DefGen genotype', 'class' => 'w3-button w3-blue w3-border w3-border-blue'}), $q->end_li(), $q->br();
	}
	else {
		print $q->li('No pathogenic variations reported so far.'), $q->br();
	}
	#look for unknown fs nonsense or +1+2-1-2 start codon
	#my $unknown_important = "SELECT DISTINCT(a.nom), a.type_prot, a.nom_gene[1], b.id_pat, b.num_pat, b.statut, d.rp, d.dfn FROM variant a, variant2patient b, patient c, gene d  WHERE a.nom = b.nom_c AND a.nom_gene = b.nom_gene AND b.num_pat = c.numero AND b.id_pat = c.identifiant AND b.nom_gene = d.nom AND c.first_name = '$first_name' AND c.last_name = '$last_name' AND a.classe = 'unknown' AND ((a.type_prot IN ('frameshift', 'nonsense', 'no protein', 'start codon')) OR (a.nom ~ 'c\..+[\+-][12][ATCGdelins>]+\$'));";    , 'inframe deletion', 'inframe duplication', 'inframe insertion'
	
	
	#Changed CONCAT function (appears in postgre 9.1) to comply with previous versions. 24/11/2014
	#my $unknown_important = "SELECT DISTINCT(a.nom), a.type_prot, a.nom_gene[1], b.id_pat, b.num_pat, b.statut, d.rp, d.dfn FROM variant a, variant2patient b, patient c, gene d  WHERE a.nom = b.nom_c AND a.nom_gene = b.nom_gene AND b.num_pat = c.numero AND b.id_pat = c.identifiant AND b.nom_gene = d.nom AND c.first_name = '$first_name' AND c.last_name = '$last_name' AND a.classe = 'unknown' AND (((a.type_prot IN ('frameshift', 'nonsense', 'no protein')) OR (a.nom ~ 'c\..+[\+-][12][ATCGdelins>]+\$')) OR (a.type_prot = 'start codon' AND a.snp_id NOT IN (SELECT rsid FROM restricted_snp WHERE common = 't' AND ng_var = CONCAT(d.acc_g, ':', a.nom_ng))));";
	#my $unknown_important = "SELECT DISTINCT(a.nom), a.type_prot, a.nom_gene[1], b.id_pat, b.num_pat, b.statut, d.rp, d.dfn, d.usher FROM variant a, variant2patient b, patient c, gene d  WHERE a.nom = b.nom_c AND a.nom_gene = b.nom_gene AND b.num_pat = c.numero AND b.id_pat = c.identifiant AND b.nom_gene = d.nom AND c.first_name = '$first_name' AND c.last_name = '$last_name' AND a.classe = 'unknown' AND (((a.type_prot IN ('frameshift', 'nonsense', 'no protein')) OR (a.nom ~ 'c\..+[\+-][12][ATCGdelins>]+\$') OR (a.nom ~ 'c\.\d+_\d+[\+-]\d+.+') OR (a.nom ~ 'c\.\d+[\+-]\d+_\d+[ATCGdelins>]+\$')) OR (a.type_prot = 'start codon' AND a.snp_id NOT IN (SELECT rsid FROM restricted_snp WHERE common = 't' AND ng_var = d.acc_g||':'||a.nom_ng)));";
	my $unknown_important = 'SELECT DISTINCT(a.nom), a.type_prot, a.nom_gene[1], b.id_pat, b.num_pat, b.statut, d.rp, d.dfn, d.usher FROM variant a, variant2patient b, patient c, gene d  WHERE a.nom = b.nom_c AND a.nom_gene = b.nom_gene AND b.num_pat = c.numero AND b.id_pat = c.identifiant AND b.nom_gene = d.nom AND c.first_name = \''.$first_name.'\' AND c.last_name = \''.$last_name.'\' AND a.classe = \'unknown\' AND (((a.type_prot IN (\'frameshift\', \'nonsense\', \'no protein\')) OR (a.nom ~ \'c\..+[\+-][12][ATCGdelins>]+$\') OR (a.nom ~ \'c\.\d+_\d+[\+-]\d+.+\') OR (a.nom ~ \'c\.\d+[\+-]\d+_\d+[ATCGdelins>]+$\')) OR (a.type_prot = \'start codon\' AND a.snp_id NOT IN (SELECT rsid FROM restricted_snp WHERE common = \'t\' AND ng_var = d.acc_g||\':\'||a.nom_ng)));';
	
	#ajout msr_filter?????
	#print $unknown_important;
	my $sth3 = $dbh->prepare($unknown_important);
	my $res_unknown = $sth3->execute();
	if ($res_unknown ne '0E0') {
		my ($text, $sem) = ($q->start_li().$q->span('You can check the following ').$q->strong('unknown variants').$q->span(':').$q->start_ul(), 0);
		#print $q->start_li(), $q->span('You can check the following '), $q->strong('unknown variants'), $q->span(':'), $q->start_ul();
		while (my $result_unknown = $sth3->fetchrow_hashref()) {
			if ($filter eq 'RP' && $result_unknown->{'rp'} == 0) {next}
			elsif ($filter eq 'DFN' && $result_unknown->{'dfn'} == 0) {next}
			elsif ($filter eq 'USH' && $result_unknown->{'usher'} == 0) {next}
			elsif ($filter eq 'DFN-USH' && ($result_unknown->{'dfn'} == 0 && $result_unknown->{'usher'} == 0)) {next}
			elsif ($filter eq 'RP-USH' && ($result_unknown->{'rp'} == 0 && $result_unknown->{'usher'} == 0)) {next}
			elsif ($filter eq 'CHM' && $result_unknown->{'nom_gene'} ne 'CHM') {next}
			
			#if ($filter eq 'RP' && $result_unknown->{'dfn'} == 1) {next}
			#elsif ($filter eq 'DFN' && $result_unknown->{'rp'} == 1) {next}
			if ($result_unknown->{'type_prot'}) {
				$text .= $q->start_li().$q->span(ucfirst($result_unknown->{'statut'})." $result_unknown->{'type_prot'} variant reported in ").$q->start_em().$q->a({'href' => "patient_genotype.pl?sample=$result_unknown->{'id_pat'}$result_unknown->{'num_pat'}&amp;gene=$result_unknown->{'nom_gene'}", 'target' => '_blank'}, $result_unknown->{'nom_gene'}).$q->end_em().$q->end_li();
				$sem = 1;
				#print $q->start_li(), $q->span(ucfirst($result_unknown->{'statut'})." $result_unknown->{'type_prot'} variant reported in "), $q->start_em(), $q->a({'href' => "patient_genotype.pl?sample=$result_unknown->{'id_pat'}$result_unknown->{'num_pat'}&amp;gene=$result_unknown->{'nom_gene'}", 'target' => '_blank'}, $result_unknown->{'nom_gene'}), $q->end_em(), $q->end_li()
			}
			else {
				$text .= $q->start_li().$q->span(ucfirst($result_unknown->{'statut'})." splice variant reported in ").$q->start_em().$q->a({'href' => "patient_genotype.pl?sample=$result_unknown->{'id_pat'}$result_unknown->{'num_pat'}&amp;gene=$result_unknown->{'nom_gene'}", 'target' => '_blank'}, $result_unknown->{'nom_gene'}).$q->end_em().$q->end_li();
				$sem = 1;
				#print $q->start_li(), $q->span(ucfirst($result_unknown->{'statut'})." splice variant reported in "), $q->start_em(), $q->a({'href' => "patient_genotype.pl?sample=$result_unknown->{'id_pat'}$result_unknown->{'num_pat'}&amp;gene=$result_unknown->{'nom_gene'}", 'target' => '_blank'}, $result_unknown->{'nom_gene'}), $q->end_em(), $q->end_li()
			}		
		}
		$text .= $q->end_ul().$q->end_li().$q->br()."\n";
		if ($sem == 1) {print $text}
		else {print $q->li("No notable unknown variant (fs, stop or splice) to check."), $q->br()}
		
		#print $q->end_ul(), $q->end_li(), $q->br();
	}
	#print $q->start_li(), $q->button({'onclick' => "window.open('missense_prioritize.pl?sample=$id$number')", 'value' => 'Prioritize missense'}), $q->end_li(), $q->br();
	#my $analysis_type = U2_modules::U2_subs_1::get_analysis_hash($dbh);
	
	my @eligible = split(/;/, $ANALYSIS_GRAPHS_ELIGIBLE);
	my $done  = "SELECT DISTINCT(a.type_analyse), a.num_pat, a.id_pat, c.manifest_name FROM analyse_moleculaire a, patient b, valid_type_analyse c WHERE a.num_pat = b.numero AND a.id_pat = b.identifiant AND a.type_analyse = c.type_analyse AND b.first_name = '$first_name' AND b.last_name = '$last_name';";
	my $sth4 = $dbh->prepare($done);
	my $res_done = $sth4->execute();
	if ($res_done ne '0E0') {
		print $q->start_li(), $q->strong("Analyses: "), $q->start_ul(), "\n";
		my $analysis_count = 0;
		while (my $result_done = $sth4->fetchrow_hashref()) {
			my ($analysis, $id_tmp, $num_tmp, $manifest) = ($result_done->{'type_analyse'}, $result_done->{'id_pat'}, $result_done->{'num_pat'}, $result_done->{'manifest_name'});
			if (grep(/$analysis/, @eligible) || $manifest ne 'no_manifest') {
				if (-d $ABSOLUTE_HTDOCS_PATH.$ANALYSIS_NGS_DATA_PATH.$analysis.'/'.$id_tmp.$num_tmp) {
					#reinitialize in case of changed because of MiniSeq analysis
					$SSH_RACKSTATION_BASE_DIR = $config->SSH_RACKSTATION_BASE_DIR();
					$SSH_RACKSTATION_FTP_BASE_DIR = $config->SSH_RACKSTATION_FTP_BASE_DIR();
					my $partial_path = $HTDOCS_PATH.$ANALYSIS_NGS_DATA_PATH.$analysis.'/'.$id_tmp.$num_tmp.'/'.$id_tmp.$num_tmp;
					my ($raw_data, $bam_file, $bam_file_suffix, $bam_ftp);
					my $width = '500';
					my $raw_filter = '';
					if ($manifest eq 'no_manifest') {
						$width = '1250';
						$raw_data = $q->start_ul().
								$q->start_li().$q->a({'href' => $partial_path.'_AliInfo.txt', 'target' => '_blank'}, 'Get AliInfo file').$q->end_li().
								$q->start_li().$q->a({'href' => $partial_path.'_vcf.vcf', 'target' => '_blank'}, 'Get variant VCF file').$q->end_li().
								$q->start_li().$q->a({'href' => $partial_path.'_coverage.bed', 'target' => '_blank'}, 'Get coverage BED file').$q->end_li().
							$q->end_ul().
							$q->start_table({'class' => 'zero_table'}).
								$q->start_Tr().
									$q->start_td().$q->img({'src' => $partial_path."_graph1.png"}).$q->end_td().
									$q->start_td().$q->img({'src' => $partial_path."_graph2.png"}).$q->end_td().
								$q->end_Tr.
							$q->end_table();
					}
					else {
						#my $bam_file;
						$analysis_count ++; #only for analysis which can be filtered
						my $query_manifest = "SELECT * FROM miseq_analysis WHERE num_pat = '$num_tmp' AND id_pat = '$id_tmp' AND type_analyse = '$analysis';";
						my $res_manifest = $dbh->selectrow_hashref($query_manifest);
						$raw_data = $q->start_ul().
								$q->start_li().
									$q->span('Run id: ').$q->a({'href' => "stats_ngs.pl?run=$res_manifest->{'run_id'}", 'target' => '_blank'}, $res_manifest->{'run_id'}).
								$q->end_li();
						if ($user->isValidator != 1) {$raw_data .= $q->li("Filter: $res_manifest->{'filter'}")}
						#if ($user->getName() ne 'david') {$raw_data .= $q->li("Filter: $res_manifest->{'filter'}")}
						elsif ($user->isValidator == 1) {#we build a form to change filter for validators							
							#not ajax
							$raw_data .= $q->start_li().$q->start_form({'action' => 'ajax.pl', 'method' => 'post', 'id' => "run_filter_form$analysis_count", 'enctype' => &CGI::URL_ENCODED});
							chomp($raw_data);
							$raw_data .= $q->input({'type' => 'hidden', 'name' => 'asked', 'value' => 'change_filter', 'form' => "run_filter_form$analysis_count"}).
									$q->input({'type' => 'hidden', 'name' => 'sample', 'value' => $id_tmp.$num_tmp, 'form' => "run_filter_form$analysis_count"}).
									$q->input({'type' => 'hidden', 'name' => 'analysis', 'value' => $analysis, 'form' => "run_filter_form$analysis_count"}).
									$q->span("Filter: ").$q->span("&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;").
									U2_modules::U2_subs_1::select_filter($q, 'filter', "run_filter_form$analysis_count", $res_manifest->{'filter'}).
									$q->span("&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;").
									$q->submit({'value' => 'Change', 'class' => 'submit', 'form' => "run_filter_form$analysis_count"}).
									$q->end_form().
									$q->end_li();
							$raw_data =~ s/$\///og;
							
							
							#ajax way but does not work (embedded js)
							#$raw_data .= $q->start_li().$q->span("Filter: ").$q->span("&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;").U2_modules::U2_subs_1::select_filter($q, 'filter_select', 'fake_form', $res_manifest->{'filter'}).$q->span("&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;").$q->button({'id' => 'change_filter_button', 'value' => 'Change'}).$q->end_form().$q->end_li();
							#$raw_data =~ s/$\///og;
							#my $js_filter = "jQuery(document).ready(function() {		
							#	\$(\"#change_filter_button\").click(function() {
							#		alert(\"ok\");
							#	});
							#});";							
							#$raw_data .= $q->script({'type' => 'text/javascript'}, $js_filter);
							#$raw_data =~ s/$\///og;
							#\$.ajax({
							#			type: \"POST\",
							#			url: \"ajax.pl\",
							#			data: {sample: \"".$id_tmp.$num_tmp."\", analysis: \"$analysis\", filter: \$(\"#filter_select\").val(), asked: \"change_filter\"}
							#		})
							#		.done(function() {
							#			location.reload();
							#		});
						}
						#we need to get bam file name on rackstation - does not work was intended to download bam from igv
						#connect to NAS
						
						my $ssh = U2_modules::U2_subs_1::nas_connexion('-', $q);
						
						#MINISEQ change get instrument type
						my ($instrument, $instrument_path) = ('miseq', 'MiSeqDx/USHER');
						if ($analysis =~ /MiniSeq-\d+/o) {$instrument = 'miniseq';$instrument_path = 'MiniSeq';$SSH_RACKSTATION_BASE_DIR = $SSH_RACKSTATION_MINISEQ_BASE_DIR;$SSH_RACKSTATION_FTP_BASE_DIR = $SSH_RACKSTATION_MINISEQ_FTP_BASE_DIR}
						
						my ($alignment_dir, $ftp_dir);
						if ($instrument eq 'miseq'){
							#$alignment_dir = `grep -Eo \"AlignmentFolder>.+\\Alignment[0-9]*<\" $ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/data/$instrument_path/$res_manifest->{'run_id'}/CompletedJobInfo.xml`;
							#old fashioned replaced with autofs 21/12/2016
							$alignment_dir = $ssh->capture("grep -Eo \"AlignmentFolder>.+\\Alignment[0-9]*<\" $SSH_RACKSTATION_BASE_DIR/$res_manifest->{'run_id'}/CompletedJobInfo.xml");
							$alignment_dir =~ /\\(Alignment\d*)<$/o;$alignment_dir = $1;
							$ftp_dir = "$SSH_RACKSTATION_FTP_BASE_DIR/$res_manifest->{'run_id'}/Data/Intensities/BaseCalls/$alignment_dir";
							$alignment_dir = "$SSH_RACKSTATION_BASE_DIR/$res_manifest->{'run_id'}/Data/Intensities/BaseCalls/$alignment_dir";
						}
						elsif($instrument eq 'miniseq'){
							#$alignment_dir = `grep -Eo \"AlignmentFolder>.+\\Alignment_?[0-9]*.+<\" $ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/data/$instrument_path/$res_manifest->{'run_id'}/CompletedJobInfo.xml`;
							$alignment_dir = $ssh->capture("grep -Eo \"AlignmentFolder>.+\\Alignment_?[0-9]*.+<\" $SSH_RACKSTATION_BASE_DIR/$res_manifest->{'run_id'}/CompletedJobInfo.xml");
							$alignment_dir =~ /\\(Alignment_?\d*.+)<$/o;
							$alignment_dir = $1;
							$alignment_dir =~ s/\\/\//og;
							$ftp_dir = "$SSH_RACKSTATION_FTP_BASE_DIR/$res_manifest->{'run_id'}/$alignment_dir";
							$alignment_dir = "$SSH_RACKSTATION_BASE_DIR/$res_manifest->{'run_id'}/$alignment_dir";						
						}
						
						#OLD fashioned 03/08/2016
						#my $alignment_dir = $ssh->capture("grep -Eo \"AlignmentFolder>.+\\Alignment[0-9]*<\" $SSH_RACKSTATION_BASE_DIR/$res_manifest->{'run_id'}/CompletedJobInfo.xml");
						#print $alignment_dir;
						#$alignment_dir =~ /\\(Alignment\d*)<$/o;
						#print $alignment_dir;
						#$alignment_dir = $1;
						#print "$alignment_dir";
						#print "$SSH_RACKSTATION_BASE_DIR/$res_manifest->{'run_id'}/Data/Intensities/BaseCalls/$alignment_dir/";exit;
						#print "$alignment_dir--";exit;
						#my $bam_list = $ssh->capture("cd $SSH_RACKSTATION_BASE_DIR/$res_manifest->{'run_id'}/Data/Intensities/BaseCalls/$alignment_dir/ && ls") or die "remote command failed: " . $ssh->error();
						my $bam_list = $ssh->capture("cd $alignment_dir && ls") or die "remote command failed: " . $ssh->error();
						#my $bam_list = `ls $ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/$ftp_dir`;
						#old fashioned replaced with autofs 21/12/2016
						#my $bam_list = $ssh->capture("cd $alignment_dir && ls") or die "remote command failed: " . $ssh->error();
						#print $res_manifest->{'run_id'};
						#create a hash which looks like {"illumina_run_id" => 0}
						my %files = map {$_ => '0'} split(/\s/, $bam_list);
						foreach my $file_name (keys(%files)) {
							if ($file_name =~ /$id_tmp$num_tmp(_S\d+\.bam)/) {
								$bam_file_suffix = $1;
								#$bam_file = "/Data/Intensities/BaseCalls/$alignment_dir/$id_tmp$num_tmp$bam_file_suffix";
								$bam_file = "$alignment_dir/$id_tmp$num_tmp$bam_file_suffix";
								$bam_ftp = "$ftp_dir/$id_tmp$num_tmp$bam_file_suffix";
							}								
						}	
						$raw_data .= $q->li("Aligned bases: $res_manifest->{'aligned_bases'}").
								$q->li("Ontarget bases: $res_manifest->{'ontarget_bases'} (".(sprintf('%.2f', ($res_manifest->{'ontarget_bases'}/$res_manifest->{'aligned_bases'})*100))."%)").
								$q->li("Aligned reads: $res_manifest->{'aligned_reads'}").
								$q->li("Ontarget reads: $res_manifest->{'ontarget_reads'} (".(sprintf('%.2f', ($res_manifest->{'ontarget_reads'}/$res_manifest->{'aligned_reads'})*100))."%) ").
								$q->li("Duplicate reads: $res_manifest->{'duplicates'}%").
								$q->li("Median insert size: $res_manifest->{'insert_size_median'} bp").
								$q->li("Mean Doc: $res_manifest->{'mean_doc'}").
								$q->li("Doc > 20X: $res_manifest->{'twentyx_doc'} % bp").
								$q->li("Doc > 50X: $res_manifest->{'fiftyx_doc'} % bp").
								$q->li("Ts/Tv: $res_manifest->{'snp_tstv'}").
								$q->li("# of identified SNVs: $res_manifest->{'snp_num'}").
								$q->li("# of identified indels: $res_manifest->{'indel_num'}");
						if (-e $ABSOLUTE_HTDOCS_PATH.$ANALYSIS_NGS_DATA_PATH.$analysis.'/'.$id_tmp.$num_tmp.'/'.$id_tmp.$num_tmp.'.report.pdf') {
							$raw_data .= $q->start_li().$q->a({'href' => $partial_path.'.report.pdf', 'target' => '_blank'}, 'Get Illumina sample summary').$q->end_li()
						}
						if (-e $ABSOLUTE_HTDOCS_PATH.$ANALYSIS_NGS_DATA_PATH.$analysis.'/'.$res_manifest->{'run_id'}.'/aggregate.report.pdf') {
							$raw_data .= $q->start_li().$q->a({'href' => $HTDOCS_PATH.$ANALYSIS_NGS_DATA_PATH.$analysis.'/'.$res_manifest->{'run_id'}.'/aggregate.report.pdf', 'target' => '_blank'}, 'Get Illumina run summary').$q->end_li()
						}
						$raw_data .= 	
								$q->start_li().$q->a({'href' => $partial_path.'.coverage.tsv', 'target' => '_blank'}, 'Get coverage file').$q->end_li().
								$q->start_li().$q->a({'href' => $partial_path.'.enrichment_summary.csv', 'target' => '_blank'}, 'Get enrichment summary file').$q->end_li().
								$q->start_li().$q->a({'href' => $partial_path.'.gaps.tsv', 'target' => '_blank'}, 'Get gaps file').$q->end_li().
								$q->start_li().$q->a({'href' => $partial_path.'.'.$analysis.'.bedgraph', 'target' => '_blank'}, 'Get coverage bedgraph file (use as UCSC track)').$q->end_li().
								$q->start_li().$q->a({'href' => $partial_path.'.vcf', 'target' => '_blank'}, 'Get original vcf file').$q->end_li().
								$q->start_li().$q->a({'href' => 'http://localhost:60151/load?file='.$HOME_IP.$partial_path.'.vcf&genome=hg19'}, 'Open VCF in IGV (on configurated computers only)').
								$q->start_li().$q->a({'href' => 'http://localhost:60151/load?file='.$HOME_IP.$HTDOCS_PATH.$RS_BASE_DIR.$bam_ftp.'&genome=hg19'}, 'Open BAM in IGV (on configurated computers only)').
								$q->start_li().$q->a({'href' => "ftps://$SSH_RACKSTATION_LOGIN:$SSH_RACKSTATION_PASSWORD\@$SSH_RACKSTATION_IP$bam_ftp", 'target' => '_blank'}, 'Download BAM file').
								$q->start_li().$q->a({'href' => "ftps://$SSH_RACKSTATION_LOGIN:$SSH_RACKSTATION_PASSWORD\@$SSH_RACKSTATION_IP$bam_ftp.bai", 'target' => '_blank'}, 'Download indexed BAM file');
								#$q->start_li().$q->a({'href' => "ftps://$SSH_RACKSTATION_LOGIN:$SSH_RACKSTATION_PASSWORD\@$SSH_RACKSTATION_IP$SSH_RACKSTATION_FTP_BASE_DIR$res_manifest->{'run_id'}$bam_file", 'target' => '_blank'}, 'Download BAM file');
								#$q->start_li().$q->a({'href' => "ftps://$SSH_RACKSTATION_LOGIN:$SSH_RACKSTATION_PASSWORD\@$SSH_RACKSTATION_IP$SSH_RACKSTATION_FTP_BASE_DIR$res_manifest->{'run_id'}$bam_file.bai", 'target' => '_blank'}, 'Download indexed BAM file');
								#$q->start_li().$q->a({'href' => 'http://localhost:60151/load?file=~/Downloads/'.$id_tmp.$num_tmp.$bam_file_suffix.'&genome=hg19'}, 'Open BAM in IGV (on configurated computers only -- TEST)').
						if (-e $ABSOLUTE_HTDOCS_PATH.$ANALYSIS_NGS_DATA_PATH.'reanalysis/'.$id_tmp.$num_tmp.'.pdf') {
							$raw_data .= $q->start_li().$q->a({'href' => $HTDOCS_PATH.$ANALYSIS_NGS_DATA_PATH."reanalysis/$id_tmp$num_tmp.pdf", 'target' => '_blank'}, 'Get NENUFAAR reanalysis summary').$q->end_li()
						}
						if (-e "$ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/data/$instrument_path/$res_manifest->{'run_id'}/nenufaar/$res_manifest->{'run_id'}/$id_tmp$num_tmp/$id_tmp$num_tmp.pdf") {
							$raw_data .= $q->start_li().$q->a({'href' => "$HTDOCS_PATH$RS_BASE_DIR/data/$instrument_path/$res_manifest->{'run_id'}/nenufaar/$res_manifest->{'run_id'}/$id_tmp$num_tmp/$id_tmp$num_tmp.pdf", 'target' => '_blank'}, 'Get autoNENUFAAR reanalysis summary').$q->end_li()
						}
						if (-e "$ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/data/$instrument_path/$res_manifest->{'run_id'}/nenufaar/$res_manifest->{'run_id'}/$res_manifest->{'run_id'}_multiqc.html") {
							$raw_data .= $q->start_li().$q->a({'href' => "$HTDOCS_PATH$RS_BASE_DIR/data/$instrument_path/$res_manifest->{'run_id'}/nenufaar/$res_manifest->{'run_id'}/$res_manifest->{'run_id'}_multiqc.html", 'target' => '_blank'}, 'View MultiQC run report');
							my @nenuf_id = split (/\s/,`ls $ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/data/$instrument_path/$res_manifest->{'run_id'}/nenufaar/$res_manifest->{'run_id'}/$id_tmp$num_tmp/`);
							$nenuf_id[0] =~ s/\s//g;
							#my $nenuf_id;
							#print "$ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/data/$instrument_path/$res_manifest->{'run_id'}/nenufaar/$res_manifest->{'run_id'}/$id_tmp$num_tmp/$nenuf_id[0]/".$id_tmp.$num_tmp."_poor_coverage.txt";
							if (-e "$ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/data/$instrument_path/$res_manifest->{'run_id'}/nenufaar/$res_manifest->{'run_id'}/$id_tmp$num_tmp/$nenuf_id[0]/".$id_tmp.$num_tmp."_poor_coverage.xlsx") {
								$raw_data .= $q->start_li().$q->a({'href' => "$HTDOCS_PATH$RS_BASE_DIR/data/$instrument_path/$res_manifest->{'run_id'}/nenufaar/$res_manifest->{'run_id'}/$id_tmp$num_tmp/$nenuf_id[0]/".$id_tmp.$num_tmp."_poor_coverage.xlsx", 'target' => '_blank'}, 'Download poor coverage file (Excel)');
							}
							if (-e "$ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/data/$instrument_path/$res_manifest->{'run_id'}/nenufaar/$res_manifest->{'run_id'}/$id_tmp$num_tmp/$nenuf_id[0]/".$id_tmp.$num_tmp."_poor_coverage.txt") {
								$raw_data .= $q->start_li().$q->a({'href' => "$HTDOCS_PATH$RS_BASE_DIR/data/$instrument_path/$res_manifest->{'run_id'}/nenufaar/$res_manifest->{'run_id'}/$id_tmp$num_tmp/$nenuf_id[0]/".$id_tmp.$num_tmp."_poor_coverage.txt", 'target' => '_blank'}, 'View poor coverage file (txt)');
							}
							if (-e "$ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/data/$instrument_path/$res_manifest->{'run_id'}/nenufaar/$res_manifest->{'run_id'}/$id_tmp$num_tmp/$nenuf_id[0]/".$id_tmp.$num_tmp.".final.vcf.final.xlsx") {
								$raw_data .= $q->start_li().$q->a({'href' => "$HTDOCS_PATH$RS_BASE_DIR/data/$instrument_path/$res_manifest->{'run_id'}/nenufaar/$res_manifest->{'run_id'}/$id_tmp$num_tmp/$nenuf_id[0]/".$id_tmp.$num_tmp.".final.vcf.final.xlsx", 'target' => '_blank'}, 'Download Nenufaar variant file (Excel)');
							}
							#if (-e "$ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/data/$instrument_path/$res_manifest->{'run_id'}/nenufaar/$res_manifest->{'run_id'}/$id_tmp$num_tmp/$nenuf_id[0]/".$id_tmp.$num_tmp.".final.vcf.final.txt") {
							#	$raw_data .= $q->start_li().$q->a({'href' => "$HTDOCS_PATH$RS_BASE_DIR/data/$instrument_path/$res_manifest->{'run_id'}/nenufaar/$res_manifest->{'run_id'}/$id_tmp$num_tmp/$nenuf_id[0]/".$id_tmp.$num_tmp.".final.vcf.final.txt", 'target' => '_blank'}, 'Download Nenufaar variant file (txt)');
							#}
						}
						
						#else {
						#	$raw_data .= $q->li("$ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/data/$instrument_path/$res_manifest->{'run_id'}/nenufaar/$res_manifest->{'run_id'}/$res_manifest->{'run_id'}_multiqc.html")
						#}
						$raw_data .= $q->start_li().$q->a({'href' => "search_controls.pl?step=3&iv=1&run=$res_manifest->{'run_id'}&sample=$id_tmp$num_tmp", 'target' => '_blank'}, "Sample tracking: get private SNPs").$q->end_li();
						$raw_data .=  $q->end_li().$q->end_ul();
								#.$q->start_li().$q->a({'href' => 'http://localhost:60151/load?file=https://194.167.35.158/USHER/'.$res_manifest->{'run_id'}.$bam_file.'&genome=hg19'}, 'Open BAM in IGV (on configurated computers only -- TEST)').$q->end_li().$q->end_ul();;
								
								#.$q->a({'href' => 'http://localhost:60151/load?file=ftp://194.167.35.140/data/MiSeqDx/USHER/'.$res_manifest->{'run_id'}.$bam_file.',ftp://194.167.35.140/data/MiSeqDx/USHER/'.$res_manifest->{'run_id'}.$bam_file.'.bai&genome=hg19'}, 'Open BAM in IGV (on configurated computers only -- TEST)').$q->end_li().$q->end_ul();
						$filter = $res_manifest->{'filter'}; #in case of bug of code l190 we rebuild $filter
						$raw_filter = $q->span({'class' => 'green'}, 'PASS');
						my $criteria = '';
						if ($res_manifest->{'mean_doc'} < $U2_modules::U2_subs_1::MDOC) {$criteria .= ' (mean DOC &le; '.$U2_modules::U2_subs_1::MDOC.') '}
						if ($res_manifest->{'fiftyx_doc'} < $U2_modules::U2_subs_1::PC50X) {$criteria .= ' (50X % &le; '.$U2_modules::U2_subs_1::PC50X.') '}
						if ($res_manifest->{'snp_tstv'} < $U2_modules::U2_subs_1::TITV) {$criteria .= ' (Ts/Tv &le; '.$U2_modules::U2_subs_1::TITV.') '}
						if ($res_manifest->{'ontarget_reads'} < $U2_modules::U2_subs_1::NUM_ONTARGET_READS) {$criteria .= ' (on target reads &lt; '.$U2_modules::U2_subs_1::NUM_ONTARGET_READS.') '}
						if ($criteria ne '') {$raw_filter = $q->span({'class' => 'red'}, "FAILED $criteria")}						
						$illumina_semaph = 1;
						
						
					}
					#my $raw_data = $q->start_ul().$q->start_li().$q->a({'href' => $HTDOCS_PATH.$ANALYSIS_NGS_DATA_PATH.$analysis.'/'.$id_tmp.$num_tmp.'/'.$id_tmp.$num_tmp.'_AliInfo.txt', 'target' => '_blank'}, 'Get AliInfo file').$q->end_li().$q->start_li().$q->a({'href' => $HTDOCS_PATH.$ANALYSIS_NGS_DATA_PATH.$analysis.'/'.$id_tmp.$num_tmp.'/'.$id_tmp.$num_tmp.'_vcf.vcf', 'target' => '_blank'}, 'Get variant VCF file').$q->end_li().$q->start_li().$q->a({'href' => $HTDOCS_PATH.$ANALYSIS_NGS_DATA_PATH.$analysis.'/'.$id_tmp.$num_tmp.'/'.$id_tmp.$num_tmp.'_coverage.bed', 'target' => '_blank'}, 'Get coverage BED file').$q->end_li().$q->end_ul().$q->start_table({'class' => 'zero_table'}).$q->start_Tr().$q->start_td().$q->img({'src' => $partial_path."_graph1.png"}).$q->end_td().$q->start_td().$q->img({'src' => $partial_path."_graph2.png"}).$q->end_td().$q->end_Tr.$q->end_table();
					my $js = "jQuery(document).ready(function() {
							var \$dialog = \$('<div></div>')
								.html('$raw_data')
								.dialog({
								    autoOpen: false,
								    title: 'Raw data for $analysis ($id_tmp$num_tmp):',
								    width: $width
								});					
							\$('#$analysis').click(function() {
							    \$dialog.dialog('open');
							    // prevent the default action, e.g., following a link
							    return false;
							});
						});";
					print $q->script({'type' => 'text/javascript'}, $js), $q->start_li(), $q->button({'id' => "$analysis", 'value' => "$analysis", 'class' => 'w3-button w3-teal w3-border w3-border-blue'});
					
					if ($raw_filter ne '') {print $q->span('&nbsp;&nbsp;&nbsp;&nbsp;'), $raw_filter, $q->span('&nbsp;*')}
					if ($valid_import eq '1') {print $q->span({'class' => 'green'}, '&nbsp;&nbsp;-&nbsp;&nbsp;IMPORT VALIDATED')}
					print  $q->end_li(), "\n";#$q->span('&nbsp;&nbsp;,&nbsp;&nbsp;');
				}
				else{print $q->li("$result_done->{'type_analyse'}");}
			}
			else{print $q->li("$result_done->{'type_analyse'}");}
		}
		print $q->end_ul(), $q->end_li();
	}
	print $q->end_ul(), $q->end_div(), "\n";
	
	###end frame 2
	
	#Add analysis #######removed 29/08/2014
	#if ($user->isAnalyst() == 1) {
	#	print $q->start_li(), $q->start_form({'action' => 'add_analysis.pl', 'method' => 'post', 'class' => 'u2form', 'id' => 'add_analysis', 'enctype' => &CGI::URL_ENCODED}),
	#					$q->input({'type' => 'hidden', 'name' => 'step', 'value' => '1'}), "\n",
	#					$q->input({'type' => 'hidden', 'name' => 'sample', 'value' => $id.$number, 'id' => 'sample', 'form' => 'add_analysis'}), "\n",
	#					$q->submit({'form' => 'add_analysis', 'value' => 'Add/Modify analyses'}), $q->end_form(),
	#		$q->end_li();
	#}
	#print		$q->start_li(), $q->start_form({'action' => 'patient_global.pl', 'method' => 'post', 'class' => 'u2form', 'id' => 'global_analysis_view', 'enctype' => &CGI::URL_ENCODED}),
	#					$q->input({'type' => 'hidden', 'name' => 'type', 'value' => 'analyses', 'form' => 'global_analysis_view'}), "\n",
	#					$q->input({'type' => 'hidden', 'name' => 'sample', 'value' => $id.$number, 'id' => 'sample', 'form' => 'global_analysis_view'}), "\n",
	#					$q->submit({'form' => 'global_analysis_view', 'value' => 'Jump to global analyses view'}), $q->end_form(),
	#		$q->end_li(),
	#		$q->start_li(), $q->start_form({'action' => 'patient_global.pl', 'method' => 'post', 'class' => 'u2form', 'id' => 'global_genotype_view', 'enctype' => &CGI::URL_ENCODED}),
	#					$q->input({'type' => 'hidden', 'name' => 'type', 'value' => 'genotype', 'form' => 'global_genotype_view'}), "\n",
	#					$q->input({'type' => 'hidden', 'name' => 'sample', 'value' => $id.$number, 'id' => 'sample', 'form' => 'global_genotype_view'}), "\n",
	#					$q->submit({'form' => 'global_genotype_view', 'value' => 'Jump to global genotype view'}), $q->end_form(),
	#		$q->end_li(),
	#		$q->end_ul(), $q->end_div(), "\n";
	#######end removed
	
	###frame 3
	
	if ($user->isAnalyst() == 1) {
		#print $q->start_div({'class' => 'in_line'}), $q->start_p(), $q->start_big(), $q->strong('Validations and negatives shortcuts:'), $q->end_big(), $q->end_p();#,#Validation
		print $q->start_div({'class' => 'in_line'}), $q->p({'class' => 'title min_height_50'}, 'Validations and negatives shortcuts:');#
		#	$q->start_ul(), "\n";
		#print U2_modules::U2_subs_1::valid($user, $number, $id, $dbh, $q);
		print U2_modules::U2_subs_1::valid_table($user, $number, $id, $dbh, $q);
		
		#print $q->end_ul(), $q->end_div(), "\n";
		print $q->end_div(), "\n";
		
		if ($illumina_semaph == 1) {
			print $q->start_div('class' => 'in_line'), $q->br(), $q->span('*NGS raw data must fulfill the following criteria to pass:'), "\n",
			$q->ul(), "\n",
				$q->li('Mean DOC &ge; '.$U2_modules::U2_subs_1::MDOC.','), "\n",
				$q->li('% of bp with covearge at least 50X &ge; '.$U2_modules::U2_subs_1::PC50X.','), "\n",
				$q->li('SNP Transition to Transversion ratio &ge; '.$U2_modules::U2_subs_1::TITV.','), "\n",
				$q->li('and the number of on target reads is &gt; '.$U2_modules::U2_subs_1::NUM_ONTARGET_READS), "\n",
			$q->end_ul(), $q->end_div(), "\n"
		}
	}
	else {print $q->end_div(), "\n"}
	### frame
	
	##Validation
	#print $q->start_div({'class' => 'in_line'}), $q->start_p(), $q->start_big(), $q->strong('Validations and negatives shortcuts:'), $q->end_big(), $q->end_p(),
	#	$q->start_ul(), "\n";
	#
	#print U2_modules::U2_subs_1::valid($user, $number, $id, $dbh, $q);
	#
	#
	#print $q->end_ul(), $q->end_div(), "\n";
		
	
	
	#TODO: link to modify patients info? or not?
	
	
	#display analyses
	
	print $q->br(), $q->start_div({'class' => 'text_line'}), $q->hr({'width' => '80%'}), $q->br();#, $q->start_p({'class' => 'center'}), $q->start_big(), $q->strong('Analyses performed:'), $q->end_big(), $q->end_p(), $q->br();#, $q->start_p(), $q->span('Click on one gene to expand ('), $q->a({'href' => 'javascript:;', 'onclick' => '$(\'.hidden\').show(\'slow\')'}, 'Show all'), $q->span(' / '), $q->a({'href' => 'javascript:;', 'onclick' => '$(\'.hidden\').hide(\'slow\')'}, 'Hide all'),$q->span(') or on an arrow to access to the corresponding genotypes,'),  $q->end_p(), $q->end_div(), "\n";
	
	#######removed
	#print $q->start_p(), $q->span('You can directy go to a group by clicking on the name:&nbsp;&nbsp;&nbsp;&nbsp;');
	#
	#&create_group(\@U2_modules::U2_subs_1::USHER, 'USHER');
	#&create_group(\@U2_modules::U2_subs_1::USH1, 'USH1');
	#&create_group(\@U2_modules::U2_subs_1::USH2, 'USH2');
	#&create_group(\@U2_modules::U2_subs_1::USH3, 'USH3');
	#&create_group(\@U2_modules::U2_subs_1::CHM, 'CHM');
	#&create_group(\@U2_modules::U2_subs_1::DFNB, 'DFNB');
	#&create_group(\@U2_modules::U2_subs_1::DFNA, 'DFNA');
	#&create_group(\@U2_modules::U2_subs_1::DFNX, 'DFNX');
	#&create_group(\@U2_modules::U2_subs_1::NSRP, 'NSRP');
	#&create_group(\@U2_modules::U2_subs_1::LCA, 'LCA');
	#
	#print $q->end_p(), $q->br(), $q->br(), "\n";######## all above removed 28/08/2014
	#######end removed
	
	#######new 29/08/2014
	#print $q->start_div({'class' => 'patient_file_frame mother appear', 'id' => 'tag'}), $q->start_big(), $q->start_strong(), $q->p({'class' => 'title'}, "Jump to the following pages:"), $q->end_strong(), $q->end_big(), $q->br(), "\n";
	print $q->start_div({'class' => 'patient_file_frame mother appear', 'id' => 'tag'}), $q->p({'class' => 'title'}, "Jump to the following pages:"), $q->br(), "\n";
	if ($user->isAnalyst() == 1) {
		print $q->strong({'class' => 'patient_file_frame daughter pointer frame_text frame1', 'onclick' => '$(location).attr(\'href\', \'add_analysis.pl?step=1&sample='.$id.$number.'\');'}, 'Add an analysis'), "\n"
	}
	#print $q->strong({'class' => 'patient_file_frame daughter pointer frame_text frame1', 'onclick' => '$(location).attr(\'href\', \'patient_global.pl?type=analyses&sample='.$id.$number.'\');'}, 'Global analyses view'), "\n",
	#	$q->strong({'class' => 'patient_file_frame daughter pointer frame_text frame1', 'onclick' => '$(location).attr(\'href\', \'patient_global.pl?type=genotype&sample='.$id.$number.'\');'}, 'Global genotype view'), "\n",
	#	$q->strong({'class' => 'patient_file_frame daughter pointer frame_text frame1', 'onclick' => '$(location).attr(\'href\', \'variant_prioritize.pl?type=missense&sample='.$id.$number.'\');'}, 'Prioritize missense'), "\n",
	#	$q->strong({'class' => 'patient_file_frame daughter pointer frame_text frame1', 'onclick' => '$(location).attr(\'href\', \'variant_prioritize.pl?type=splicing&sample='.$id.$number.'\');'}, 'Prioritize splicing'), "\n",
	print $q->strong({'class' => 'patient_file_frame daughter pointer frame_text frame1', 'onclick' => 'window.open(\'patient_global.pl?type=analyses&sample='.$id.$number.'\');'}, 'Global analyses view'), "\n",
		$q->strong({'class' => 'patient_file_frame daughter pointer frame_text frame1', 'onclick' => 'window.open(\'patient_global.pl?type=genotype&sample='.$id.$number.'\');'}, 'Global genotype view'), "\n",
		$q->strong({'class' => 'patient_file_frame daughter pointer frame_text frame1', 'onclick' => 'window.open(\'variant_prioritize.pl?type=missense&sample='.$id.$number.'\');'}, 'Prioritize missense'), "\n",
		$q->strong({'class' => 'patient_file_frame daughter pointer frame_text frame1', 'onclick' => 'window.open(\'variant_prioritize.pl?type=splicing&sample='.$id.$number.'\');'}, 'Prioritize splicing'), "\n",
		$q->end_div(), $q->start_div({'class' => 'invisible'}), $q->br(), $q->br(), $q->end_div(), "\n";
	

	
	
	my $javascript = 'function show_gene_group(group) {
				if ($("#USHER").length) {$("#USHER").hide();}
				if ($("#USH1").length) {$("#USH1").hide();}
				if ($("#USH2").length) {$("#USH2").hide();}
				if ($("#USH3").length) {$("#USH3").hide();}
				if ($("#DFNA").length) {$("#DFNA").hide();}
				if ($("#DFNB").length) {$("#DFNB").hide();}
				if ($("#NSRP").length) {$("#NSRP").hide();}
				if ($("#DFNX").length) {$("#DFNX").hide();}
				if ($("#LCA").length) {$("#LCA").hide();}
				if ($("#CHM").length) {$("#CHM").hide();}
				
				//$(location).attr(\'href\', \'#tag\');
				var screentop = $(\'html\').offset().top;
				var tagtop = $(\'#tag\').offset().top;
				if (Math.abs(screentop.toFixed(0)-(tagtop.toFixed(0))) > 200) {
					//#alert(screentop.toFixed(0)+"---"+(tagtop.toFixed(0)-1))
					$(\'html, body\').animate({
						scrollTop: tagtop
					}, 1000);
				}
				if ($("#"+group).length) {$("#"+group).fadeTo(1000, 1);$("#help_div").html(\'<br/>\')}
				else {$("#help_div").html(\'<br/><strong>No analyses performed for this group of gene yet</strong>\');}
			}';
	
	print $q->script({'type' => 'text/javascript'}, $javascript), $q->start_div({'class' => 'patient_file_frame mother appear'}), $q->p({'class' => 'title'}, "Or click on a group to see genes and then on genes to display:"), $q->br(), "\n";
	
	if ($filter eq 'ALL') {
		&create_group(\@U2_modules::U2_subs_1::USHER, 'USHER');
		&create_group(\@U2_modules::U2_subs_1::USH1, 'USH1');
		&create_group(\@U2_modules::U2_subs_1::USH2, 'USH2');
		&create_group(\@U2_modules::U2_subs_1::USH3, 'USH3');
		&create_group(\@U2_modules::U2_subs_1::CHM, 'CHM');
		&create_group(\@U2_modules::U2_subs_1::DFNB, 'DFNB');
		&create_group(\@U2_modules::U2_subs_1::DFNA, 'DFNA');
		&create_group(\@U2_modules::U2_subs_1::DFNX, 'DFNX');
		&create_group(\@U2_modules::U2_subs_1::NSRP, 'NSRP');
		&create_group(\@U2_modules::U2_subs_1::LCA, 'LCA');
	}
	elsif ($filter eq 'RP') {
		&create_group(\@U2_modules::U2_subs_1::NSRP, 'NSRP');
		&create_group(\@U2_modules::U2_subs_1::LCA, 'LCA');
		&create_group(\@U2_modules::U2_subs_1::CHM, 'CHM');
	}
	elsif ($filter eq 'DFN') {
		&create_group(\@U2_modules::U2_subs_1::DFNB, 'DFNB');
		&create_group(\@U2_modules::U2_subs_1::DFNA, 'DFNA');
		&create_group(\@U2_modules::U2_subs_1::DFNX, 'DFNX');
	}
	elsif ($filter eq 'USH') {
		&create_group(\@U2_modules::U2_subs_1::USHER, 'USHER');
		&create_group(\@U2_modules::U2_subs_1::USH1, 'USH1');
		&create_group(\@U2_modules::U2_subs_1::USH2, 'USH2');
		&create_group(\@U2_modules::U2_subs_1::USH3, 'USH3');
	}
	elsif ($filter eq 'DFN-USH') {
		&create_group(\@U2_modules::U2_subs_1::USHER, 'USHER');
		&create_group(\@U2_modules::U2_subs_1::USH1, 'USH1');
		&create_group(\@U2_modules::U2_subs_1::USH2, 'USH2');
		&create_group(\@U2_modules::U2_subs_1::USH3, 'USH3');
		&create_group(\@U2_modules::U2_subs_1::DFNB, 'DFNB');
		&create_group(\@U2_modules::U2_subs_1::DFNA, 'DFNA');
		&create_group(\@U2_modules::U2_subs_1::DFNX, 'DFNX');
	}
	elsif ($filter eq 'RP-USH') {
		&create_group(\@U2_modules::U2_subs_1::USHER, 'USHER');
		&create_group(\@U2_modules::U2_subs_1::USH1, 'USH1');
		&create_group(\@U2_modules::U2_subs_1::USH2, 'USH2');
		&create_group(\@U2_modules::U2_subs_1::USH3, 'USH3');
		&create_group(\@U2_modules::U2_subs_1::NSRP, 'NSRP');
		&create_group(\@U2_modules::U2_subs_1::LCA, 'LCA');
		&create_group(\@U2_modules::U2_subs_1::CHM, 'CHM');
	}
	elsif ($filter eq 'CHM') {
		&create_group(\@U2_modules::U2_subs_1::CHM, 'CHM')
	}
	
	
	#&create_group(\@U2_modules::U2_subs_1::USHER, 'USHER');
	#&create_group(\@U2_modules::U2_subs_1::USH1, 'USH1');
	#&create_group(\@U2_modules::U2_subs_1::USH2, 'USH2');
	#&create_group(\@U2_modules::U2_subs_1::USH3, 'USH3');
	#&create_group(\@U2_modules::U2_subs_1::CHM, 'CHM');
	#if ($filter ne 'RP') {
	#	&create_group(\@U2_modules::U2_subs_1::DFNB, 'DFNB');
	#	&create_group(\@U2_modules::U2_subs_1::DFNA, 'DFNA');
	#	&create_group(\@U2_modules::U2_subs_1::DFNX, 'DFNX');
	#}
	#if ($filter ne 'DFN') {
	#	&create_group(\@U2_modules::U2_subs_1::NSRP, 'NSRP');
	#	&create_group(\@U2_modules::U2_subs_1::LCA, 'LCA');
	#}
	
	
	
	
	
	print $q->end_div(), $q->start_div({'class' => 'invisible', 'id' => 'help_div'}), $q->br(), $q->end_div(), "\n";
	#######end new
	
	#my $current_gene;
	#first only analyses validated by the technician
	#$query2 = "SELECT a.num_pat as num, a.id_pat as id, a.nom_gene[1] as gene, a.type_analyse as type, a.technical_valid as tv, a.valide as v, a.result as n FROM analyse_moleculaire a, patient b WHERE a.num_pat = b.numero AND a.id_pat = b.identifiant AND b.first_name = '$result->{'first_name'}' AND b.last_name = '$result->{'last_name'}' AND a.technical_valid = 't' ORDER BY a.nom_gene;";
	
	#######modified 28/08/2014
	#$query2 = "SELECT a.*, c.second_name FROM analyse_moleculaire a, patient b, gene c WHERE a.num_pat = b.numero AND a.id_pat = b.identifiant AND a.nom_gene = c.nom AND b.first_name = '$first_name' AND b.last_name = '$last_name' AND a.technical_valid = 't' AND c.main = 't' ORDER BY a.nom_gene;";
	#######end modified
	
	#######new 28/08/2014
	my ($list);
	#######end new
	
	$query2 = "SELECT DISTINCT(a.nom_gene), c.second_name, a.num_pat, a.id_pat FROM analyse_moleculaire a, patient b, gene c WHERE a.num_pat = b.numero AND a.id_pat = b.identifiant AND a.nom_gene = c.nom AND b.first_name = '$first_name' AND b.last_name = '$last_name' AND a.technical_valid = 't' AND c.main = 't' ORDER BY a.nom_gene;";
	my $sth2 = $dbh->prepare($query2);
	my $res2 = $sth2->execute();
	if ($res2 ne '0E0') {
		while (my $result2 = $sth2->fetchrow_hashref()) {
			
			#######new 28/08/2014 get a list of genes
			$list->{$result2->{'nom_gene'}->[0]} = ['', $result2->{'id_pat'}, $result2->{'num_pat'}];
			if ($result2->{'second_name'}) {$list->{$result2->{'nom_gene'}->[0]} = [$result2->{'second_name'}, $result2->{'id_pat'}, $result2->{'num_pat'}]}
			#######end new
			
			
			
			#######removed 29/08/2014
			##treat by gene -> send results to specific subs.
			##we must print gene once then detail the analysis
			#if ($current_gene ne $result2->{'nom_gene'}->[0]) {#new gene
			#	if ($current_gene ne '') {print $q->end_div(), "\n"}
			#	$current_gene = $result2->{'nom_gene'}->[0];
			#	print $q->start_p(), $q->start_p({'class' => 'title pointer', 'onclick' => "window.open('patient_genotype.pl?sample=$result2->{'id_pat'}$result2->{'num_pat'}&gene=$result2->{'nom_gene'}->[0]');"}), $q->start_em(), $q->strong($current_gene);
			#	if ($result2->{'second_name'}) {print $q->span("&nbsp;&nbsp;($result2->{'second_name'})")}
			#	print $q->end_em(), $q->end_p();
			#	
			#	#######removed 28/08/2014
			#	#print $q->start_p(), $q->start_p({'class' => 'title pointer', 'onclick' => '$(\'#'.$current_gene.'\').toggle(\'slow\');'}), $q->start_em(), $q->strong($current_gene);
			#	#if ($result2->{'second_name'}) {print $q->span("&nbsp;&nbsp;($result2->{'second_name'})")}				
			#	#print $q->end_em(), $q->end_p(), $q->start_div ({'class' => 'hidden', 'id' => $result2->{'nom_gene'}->[0]}), $q->start_p({'class' => 'center'}), $q->start_a({'href' => "patient_genotype.pl?sample=$result2->{'id_pat'}$result2->{'num_pat'}&gene=$result2->{'nom_gene'}->[0]", 'title' => "Access to $result2->{'nom_gene'}->[0] genotype.", 'target' => '_blank'}), $q->span('genotype&nbsp;&nbsp;'), $q->img({'src' => $HTDOCS_PATH.'data/img/link_small.png', 'border' => '0', 'width' =>'15'}), $q->end_a(), $q->end_p();
			#	
			#	
			#	#print $q->start_p({'class' => 'title pointer', 'onclick' => '$(\'#'.$current_gene.'\').toggle(\'slow\');'}), $q->em($current_gene), $q->span("&nbsp;&nbsp;"), $q->start_a({'href' => "patient_genotype.pl?sample=$result2->{'id_pat'}$result2->{'num_pat'}&gene=$result2->{'nom_gene'}->[0]", 'title' => "Access to $result2->{'nom_gene'}->[0] genotype.", 'target' => '_blank'}), $q->img({'src' => $HTDOCS_PATH.'data/img/link_small.png', 'border' => '0', 'width' =>'15'}), $q->end_a(), $q->end_p(), $q->start_div ({'class' => 'hidden', 'id' => $result2->{'nom_gene'}->[0]});
			#	#######end removed
			#	
			#	
			#}
			#if ($result2->{'type_analyse'} eq 'CGH') {&lr($result2)}
			#######removed
			####### gain 10x if commented => no analysis details we'll test and if someone complains, we put it back 28/08/2014
			#######or can be fetched by ajax on a popup
			#if ($result2->{'type_analyse'} =~ /del/) {&seq($result2)}
			#elsif ($result2->{'type_analyse'} eq 'HAP') {&hap($result2)}
			#elsif ($result2->{'type_analyse'} =~ /(MLPA|CGH|QMPSF|PCR-MULTIPLEX)/o) {&lr($result2)}
			#elsif ($result2->{'type_analyse'} =~ /454-/o || $result2->{'type_analyse'} eq 'SANGER' || $result2->{'type_analyse'} =~ /MiSeq-/o) {&seq($result2)}
			#######end removed
			
			
			
			#elsif () {&seq($result2)}
			
		}
	}
	else {print $q->span('No technically validated analyses performed yet.')}
	#TODO: not validated analysis
	#}
	
	#######new 28/08/2014
	#now we have got the list, we check if we have to build the group, if yes, we just do it
	#try with Usher
	print $q->start_div();
	&create_frame(\@U2_modules::U2_subs_1::USHER, 'USHER', $list);
	&create_frame(\@U2_modules::U2_subs_1::USH1, 'USH1', $list);
	&create_frame(\@U2_modules::U2_subs_1::USH2, 'USH2', $list);
	&create_frame(\@U2_modules::U2_subs_1::USH3, 'USH3', $list);
	&create_frame(\@U2_modules::U2_subs_1::CHM, 'CHM', $list);
	&create_frame(\@U2_modules::U2_subs_1::DFNB, 'DFNB', $list);
	&create_frame(\@U2_modules::U2_subs_1::DFNA, 'DFNA', $list);
	&create_frame(\@U2_modules::U2_subs_1::DFNX, 'DFNX', $list);
	&create_frame(\@U2_modules::U2_subs_1::NSRP, 'NSRP', $list);
	&create_frame(\@U2_modules::U2_subs_1::LCA, 'LCA', $list);
	print $q->end_div(), $q->start_div({'class' => 'invisible'}), $q->end_div(), "\n";
	#######end new
		
	#if ($illumina_semaph == 1) {
	#	print $q->start_div(), $q->br(), $q->span('*Raw data must fulfill the following criteria to pass:'), "\n",
	#		$q->ul(), "\n",
	#			$q->li('Mean DOC &ge; 100X,'), "\n",
	#			$q->li('% of bp with covearge at least 50X &ge; 95%,'), "\n",
	#			$q->li('and SNP Transition to Transversion ratio &ge; 2.5'), "\n",
	#		$q->end_ul(), $q->end_div(), "\n"
	#}
	
	
	##easy-comment
	my $ec = $result->{'last_name'}.$result->{'first_name'};
	$ec =~ s/[^\w]/_/og;
	$ec =~ s/$ACCENTS/_/og;
	
	my $js = "jQuery(document).ready(function(){
	   \$(\"#$ec\").EasyComment({
	      path:\"/javascript/u2/easy-comment/\"
	   });
	   \$(\"[name='name']\").val('".$user->getName()."');
	});";
	
	print $q->script({'type' => 'text/javascript'}, $js), $q->start_div({'id' => $ec, 'class' => 'comments'}), $q->end_div();

}
else {U2_modules::U2_subs_1::standard_error('11', $q)}


##Basic end of USHVaM 2 perl scripts:

print $q->start_div(), $q->p('Les données collectées dans la zone de texte libre doivent être pertinentes, adéquates et non excessives au regard de la finalité du traitement. Elles ne doivent pas comporter d\'appréciations subjectives, ni directement ou indirectement, permettre l\'identification d\'un patient, ni faire apparaitre des données dites « sensibles » au sens de l\'article 8 de la loi n°78-17 du 6 janvier 1978 relative à l\'informatique, aux fichiers et aux libertés.');

U2_modules::U2_subs_1::standard_end_html($q);

print $q->end_html();

exit();

##End of Basic end

##specific subs for current script

sub create_frame {
	my ($tab, $name, $list) = @_;
	my $semaph = 0;
	my $html;
	foreach (@{$tab}) {if (exists $list->{$_}) {$semaph = 1;last;}}
	if ($semaph == 1) {
		#build frame
		print $q->start_div({'id' => $name, 'class' => 'patient_file_frame mother hidden'}), $q->start_big(), $q->start_strong(), $q->p({'class' => 'title'}, $name), $q->end_strong(), $q->end_big(), $q->br(), "\n";
		foreach (@{$tab}) {
			if (exists $list->{$_}) {
				print $q->start_strong({'class' => 'patient_file_frame daughter pointer frame_text frame2', 'onclick' => "window.open('patient_genotype.pl?sample=$list->{$_}[1]$list->{$_}[2]&gene=$_');"}), $q->em($_), $q->span(" ($list->{$_}[0])"), $q->end_strong(), "\n";
			}
		}
		print $q->end_div(), "\n";#, $q->start_div({'class' => 'invisible'}), $q->br(), $q->br(), $q->end_div(), "\n";
	}	
}


sub create_group {
	my ($tab, $name) = @_;
	#my ($show, $hide);
	#foreach (@{$tab}) {$show .= "if (\$('#$_').length){\$('#$_').show('slow');};"; $hide .= "if (\$('#$_').length){\$('#$_').hide('slow');};";} modified 29/08/2014
	#print $q->strong({'id' => $name}, "&nbsp;&nbsp;&nbsp;$name&nbsp;"), $q->span('('), $q->a({'href' => 'javascript:;', 'onclick' => $show}, 'Show'), $q->span(' / '), $q->a({'href' => 'javascript:;', 'onclick' => $hide}, 'Hide'), $q->span(')');
	#print $q->start_strong(), $q->span({'id' => "l$name", 'class' => 'pointer', 'onclick' => '$(location).attr(\'href\', \'#'.$name.'\');'}, "&nbsp;&nbsp;&nbsp;$name&nbsp;"), $q->end_strong();
	print $q->strong({'id' => "l$name", 'class' => 'patient_file_frame daughter pointer frame_text frame1', 'onclick' => 'show_gene_group(\''.$name.'\');'}, $name), "\n";
}


sub DFNB1_del {
	my $data = shift;
	
}

sub hap {
	my $data = shift;
	
}

sub lr {
	my $data = shift;
	print $q->start_ul({'class' => 'hor_li'}), $q->start_li(), $q->strong($data->{'type_analyse'}), $q->end_li();
	if ($data->{'analyste'} ne ''){&human($data->{'analyste'})}
	if ($data->{'date_analyse'} ne ''){&date($data->{'date_analyse'})}
	&validated($data);
	&negative($data);
	print $q->end_ul(), "\n";
}

sub seq {
	my $data = shift;
	
	print $q->start_ul({'class' => 'hor_li'}), $q->start_li(), $q->strong($data->{'type_analyse'}), $q->end_li();
	if ($data->{'analyste'} ne ''){&human($data->{'analyste'})}
	if ($data->{'date_analyse'} ne ''){&date($data->{'date_analyse'})}
	&validated($data);
	&negative($data);
	#get summary from results
	my $query = "SELECT COUNT(nom_c) as number FROM variant2patient WHERE num_pat = '".$data->{'num_pat'}."' AND id_pat = '".$data->{'id_pat'}."' AND type_analyse = '".$data->{'type_analyse'}."' AND nom_gene[1] = '".$data->{'nom_gene'}->[0]."';";
	my $res = $dbh->selectrow_hashref($query);
	print $q->li(" - $res->{'number'} variants including ");
	
	#get number of unknown
	my $query = "SELECT COUNT(a.nom_c) as number FROM variant2patient a, variant b WHERE a.nom_c = b.nom AND a.nom_gene = b.nom_gene AND a.num_pat = '".$data->{'num_pat'}."' AND a.id_pat = '".$data->{'id_pat'}."' AND a.type_analyse = '".$data->{'type_analyse'}."' AND a.nom_gene[1] = '".$data->{'nom_gene'}->[0]."' AND b.classe = 'unknown';";
	my $res = $dbh->selectrow_hashref($query);
	print $q->start_li(), $q->strong(" $res->{'number'} unknown and&nbsp;"), $q->end_li();
	
	#get number of UV3-4-mut
	my $query = "SELECT COUNT(a.nom_c) as number FROM variant2patient a, variant b WHERE a.nom_c = b.nom AND a.nom_gene = b.nom_gene AND a.num_pat = '".$data->{'num_pat'}."' AND a.id_pat = '".$data->{'id_pat'}."' AND a.type_analyse = '".$data->{'type_analyse'}."' AND a.nom_gene[1] = '".$data->{'nom_gene'}->[0]."' AND b.classe IN ('VUCS class III', 'VUCS class IV', 'pathogenic');";
	my $res = $dbh->selectrow_hashref($query);
	print $q->start_li(), $q->strong(" $res->{'number'} likely pathogenic."), $q->end_li();
	#print $q->start_li(), $q->strong(" $res->{'number'} likely pathogenic.&nbsp;&nbsp;"), $q->start_a({'href' => "patient_genotype.pl?sample=$data->{'id_pat'}$data->{'num_pat'}&gene=$data->{'nom_gene'}->[0]", 'title' => "Access to $data->{'nom_gene'}->[0] genotype.", 'target' => '_blank'}), $q->img({'src' => $HTDOCS_PATH.'data/img/link_small.png', 'border' => '0', 'width' =>'15'}), $q->end_a(), $q->end_li();
	
	
	print $q->end_ul(), "\n";
}





#sub sub

sub validated {
	my $data = shift;
	if ($data->{'valide'} == 1) {
		print $q->li(" - biologically validated");
		if ($data->{'validateur'} ne ''){&human($data->{'validateur'})}
		if ($data->{'date_valid'} ne ''){&date($data->{'date_valid'})}
	}
	else {print $q->li(" - not biologically validated")} #TODO: add link to validate 
}

sub negative {
	my $data = shift;
	if ($data->{'negatif'} ne '') {
		if ($data->{'negatif'} != 1) {
			print $q->li(" - negative");
			if ($data->{'validateur'} ne ''){&human($data->{'validateur'})}
			if ($data->{'date_result'} ne ''){&date($data->{'date_result'})}
		}
		else {print $q->li(" - positive")} #TODO: add link to change negative status
	}
}

#sub sub sub

sub date {
	my $date = $_[0];
	print $q->span(" ($date) ");
}

sub human {
	my $name = $_[0];
	print $q->span(" by $name ");
}
