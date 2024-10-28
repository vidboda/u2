BEGIN {delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV', 'PATH'};}

use strict;
#use CGI;#in startup.pl
#use DBI;
#use AppConfig qw(:expand :argcount);
#do "U2_modules/U2_users_1.pm";## do forces reload
#do "U2_modules/U2_init_1.pm";## in production
#do "U2_modules/U2_subs_1.pm";## replace with use
use U2_modules::U2_users_1;
use U2_modules::U2_init_1;
use U2_modules::U2_subs_1;
use U2_modules::U2_subs_2;
use Encode qw(encode decode);
use URI::Encode qw(uri_encode uri_decode);
use Encode::Guess;

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
#		generates a form to get patient's info


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

my @styles = ($CSS_PATH.'font-awesome.min.css', $CSS_PATH.'w3.css', $CSS_DEFAULT, $CSS_PATH.'form.css');


my $q = new CGI;

my $dbh = DBI->connect(    "DBI:Pg:database=$DB;host=$HOST;",
                        $DB_USER,
                        $DB_PASSWORD,
                        {'RaiseError' => 1}
                ) or die $DBI::errstr;

print $q->header(-type => 'text/html', -'cache-control' => 'no-cache'),
	$q->start_html(-title=>"Insert a patient",
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
				-src => $JS_DEFAULT, 'defer' => 'defer'}],		
                        -encoding => 'ISO-8859-1');

my $user = U2_modules::U2_users_1->new();

U2_modules::U2_subs_1::standard_begin_html($q, $user->getName(), $dbh);

##end of Basic init


##Init of specific cgi params

my $step = U2_modules::U2_subs_1::check_step($q);

my $PATIENT_IDS = $config->PATIENT_IDS();
my $PATIENT_FAMILY_IDS = $config->PATIENT_FAMILY_IDS();
my $PATIENT_PHENOTYPE = $config->PATIENT_PHENOTYPE();
#my $PATIENT_PHENOTYPE_LIST = $config->PATIENT_PHENOTYPE_LIST();
my $ACCENTS = $config->PERL_ACCENTS();

my $enc = 'utf-8';

my ($sample, $family, $last_name, $first_name);

#simple case: first sample for the patient
if ($q->param('sample') && $q->param('sample') =~ /^$PATIENT_IDS\s*\d+$/o && $q->param('family') && $q->param('family') =~ /^$PATIENT_FAMILY_IDS\s*\d+$/o) {
	($sample, $family) = ($q->param('sample'), $q->param('family'));	
	#print $q->p('ok, this will work. Excel fixed.');
}
elsif ($q->param('sample') && ($q->param('family') && $q->param('family') =~ /^($PATIENT_FAMILY_IDS\d+)[-=\/]($PATIENT_FAMILY_IDS\d+)$/o)) { #case of a nth sample and reattribution of a family ID (error)
	($sample, $family) = ($q->param('sample'), $1);
}
else {&insert_error('ID')}
#get last name and name and check if exists
if (($q->param('last_name') && decode($enc,$q->param('last_name')) =~ /([A-Z-\s\.a-z']+)\s*\(?(ep\.|ep\/|née|ép\.|ép\/|njf|ep.\/)*/o)) {
	$last_name = $1;
	if ($last_name =~ /(.+)\s$/o) {$last_name = $1}
	if ($q->param('first_name')) {
		my $coded_fname;
		if (ref(guess_encoding($q->param('first_name'))) =~ /utf8/o) {$coded_fname = decode($enc, uri_decode($q->param('first_name')))}
		else {$coded_fname = uri_decode($q->param('first_name'))}
		if ($q->param('first_name') && $coded_fname =~ /^([\w-\s$ACCENTS]+)$/o) {$first_name = $1;}
		else {&insert_error('first name')}
		
		#code until october 2013
		#my $decoded_name = decode($enc, uri_decode($q->param('first_name')));
		#if ($q->param('first_name') && $coded_fname =~ /^([\w-\s$ACCENTS]+)$/o) {$first_name = $1}
		#else {&insert_error('first name')}
	}
	#check if exists
	my ($id, $num) = U2_modules::U2_subs_1::sample2idnum($sample, $q);
	my $query = "SELECT last_name, first_name FROM patient WHERE numero = '$num' AND identifiant = '$id';";
	my $res = $dbh->selectrow_hashref($query);
	if ($res ne '') {
		#print $query."-".$res."-";
		#print $q->start_div({"class" => "w3-panel w3-display-container w3-red w3-padding-16"}),
		#	$q->start_p({"class" => "w3-large"},), $q->span("Sorry, the sample $id$num is already recorded under the name of $res->{'last_name'} $res->{'first_name'}. You can check the page by following this link: "),
		#	$q->a({"class" => "w3-white", "href" => "patient_file.pl?sample=$id$num"}, $id.$num), $q->end_p(), $q->end_div();
		print U2_modules::U2_subs_2::danger_panel($q->span("Sorry, the sample $id$num is already recorded under the name of $res->{'last_name'} $res->{'first_name'}. You can check the page by following this link: ").$q->a({"class" => "w3-white", "href" => "patient_file.pl?sample=$id$num"}, $id.$num), $q);
		U2_modules::U2_subs_1::standard_end_html($q);
		print $q->end_html();
		exit();
	}
	#check if family exists
	$query = "SELECT numero, identifiant FROM patient WHERE famille = '$family';";
	my $sth = $dbh->prepare($query);
	$res = $sth->execute();
	if ($res ne '0E0') {
		#print $q->start_div({"class" => "w3-panel w3-display-container w3-red w3-padding-16"}),
		#	$q->span({"class" => "w3-button w3-display-topright w3-xlarge", "onclick" => "this.parentElement.style.display='none'"}, 'X'),
		#		$q->start_p({"class" => "w3-large"}),
		my $text = $q->span("This family number is known by U2 in sample(s) ");
		while (my $results = $sth->fetchrow_hashref()) {
			$text.=  $q->a({"class" => "w3-white", "href" => "patient_file.pl?sample=$results->{'identifiant'}.$results->{'numero'}"}, $results->{'identifiant'}.$results->{'numero'}.' ');
		}
		print U2_modules::U2_subs_2::danger_panel($text, $q);
		#print $q->end_p(), $q->end_div();
	}
	
}
else {&insert_error('last name')}

##end of init of specific CGI params


if ($step == 1) {
	my %gender = ('M' => 'Male', 'F' => 'Female', 'X' => 'Unknown');
	my %proband = ('t' => 'Yes', 'f' => 'No');
	print U2_modules::U2_subs_2::info_panel($q->span("The system understands that you are trying to record the following sample:").
		$q->start_ul({'class' => 'w3-ul w3-hoverable', 'style' => 'width:30%'}).
			$q->li("Sample ID: $sample")."\n".
			$q->li("Family ID: $family")."\n".
			$q->li("Last Name: $last_name")."\n".
			$q->li("Name: $first_name")."\n".
		$q->end_ul()."\n".
		$q->span('I need a couple of additional information. Please fill in the form below:'), $q);
	print $q->br(), $q->start_div({'align' => 'center'});
		#print "<form action = \"insert_sample.pl\" method = \"post\" class = \"u2form\" id = \"patient_form\">";
		print #$q->start_form(-action => 'insert_sample.pl', -method => 'get', -class => 'u2form', -id => 'patient_form', -enctype => 'multipart/form-data'),
			#$q->start_form({'action' => 'insert_sample.pl', 'method' => 'post', 'class' => 'u2form', 'id' => 'patient_form', 'enctype' => 'application/x-www-form-urlencoded'}),
			$q->start_form({'action' => '', 'method' => 'post', 'class' => 'w3-container w3-card-4 w3-light-grey w3-text-blue w3-margin', 'id' => 'patient_form', 'enctype' => &CGI::URL_ENCODED, 'style' => 'width:50%'}),
			$q->input({'type' => 'hidden', 'name' => 'step', 'value' => '2'}), "\n",
			$q->input({'type' => 'hidden', 'name' => 'sample', 'value' => $sample}), "\n",
			$q->input({'type' => 'hidden', 'name' => 'family', 'value' => $family}), "\n",
			$q->input({'type' => 'hidden', 'name' => 'last_name', 'value' => $last_name}), "\n",
			$q->input({'type' => 'hidden', 'name' => 'first_name', 'value' => $first_name}), "\n",
			#$q->hidden(-name => 'step', -default => '2'), "\n",
			#$q->hidden(-name => 'sample', -default => $sample), "\n",
			#$q->hidden(-name => 'family', -default => $family), "\n",
			#$q->hidden(-name => 'last_name', -default => $last_name), "\n",
			#$q->hidden(-name => 'first_name', -default => $first_name), "\n",
			
			
			#$q->start_fieldset({'class' => 'w3-card w3-margin'}),
				$q->h2({'class' => 'w3-center w3-padding-32'},'Sample details'),
				$q->start_div({'class' => 'w3-row w3-section w3-padding-16'}), "\n",
					$q->start_div({'class' => 'w3-col w3-right-align',  'style' => 'width:30%'}),
						$q->span({'for' => 'phenotype', 'class' => 'w3-large'}, 'Phenotype:&nbsp;&nbsp;'),
					$q->end_div(), "\n",
					$q->start_div({'class' => 'w3-rest'});
	U2_modules::U2_subs_1::select_phenotype($q);
	print 				$q->end_div(), "\n",
				$q->end_div(), "\n",
				$q->start_div({'class' => 'w3-row w3-section w3-padding-16'}), "\n",
					$q->start_div({'class' => 'w3-col w3-right-align',  'style' => 'width:30%'}),
						$q->span({'class' => 'w3-large'}, 'Gender:&nbsp;&nbsp;'),
					$q->end_div(), "\n",
					$q->start_div({'class' => 'w3-rest'}), "\n",
							$q->radio_group(-name => 'gender', -values => [keys %gender], -labels => \%gender, -columns => 1, -defaults => '', -class => 'w3-radio'),
					$q->end_div(), "\n",
				$q->end_div(),
				$q->start_div({'class' => 'w3-row w3-section w3-padding-16'}), "\n",
					$q->start_div({'class' => 'w3-col w3-right-align',  'style' => 'width:30%'}),
						$q->span({'class' => 'w3-large'}, 'Geographic origin:&nbsp;&nbsp;'),
					$q->end_div(), "\n",
					$q->start_div({'class' => 'w3-rest'}), "\n";
	U2_modules::U2_subs_1::select_origin($q);
	print				$q->end_div(), "\n",
				$q->end_div(),
				$q->start_div({'class' => 'w3-row w3-section w3-padding-16'}), "\n",
					$q->start_div({'class' => 'w3-col w3-right-align',  'style' => 'width:30%'}),
						$q->span({'class' => 'w3-large'}, 'Index Case:&nbsp;&nbsp;'),
					$q->end_div(), "\n",
					$q->start_div({'class' => 'w3-rest'}), "\n",
							$q->radio_group(-name => 'proband', -values => [keys %proband], -labels => \%proband, -columns => 1, -defaults => '', -class => 'w3-radio'),
					$q->end_div(), "\n",
				$q->end_div(),
				$q->start_div({'class' => 'w3-row w3-section w3-padding-16'}), "\n",
							$q->input({'class' => 'w3-input w3-animate-input', 'type' => 'text', 'style' => 'width:30%', 'placeholder' => 'Comments', 'name' => 'comment'}),
				$q->end_div(),
					
					
			#$q->end_fieldset(),
			
			
	#		$q->start_fieldset({'class' => 'w3-card w3-margin'}),
	#			$q->h2({'class' => 'w3-center'},'Sample details'),
	#			$q->start_ol(), "\n",
	#				$q->start_li({'class' => 'w3-padding-16'}),
	#					$q->label({'for' => 'phenotype'}, 'Phenotype:');
	#U2_modules::U2_subs_1::select_phenotype($q);
	#print 					$q->br(), "\n",
	#				$q->end_li(), "\n",
	#				$q->start_li({'class' => 'w3-padding-16'}),
	#					$q->start_fieldset(),
	#						$q->legend('Gender:'),
	#						$q->radio_group(-name => 'gender', -values => [keys %gender], -labels => \%gender, -columns => 1, -defaults => '', -class => 'w3-radio'),
	#					$q->end_fieldset(), $q->br(),
	#				$q->end_li(), "\n",
	#				$q->start_li({'class' => 'w3-padding-16'}),
	#					$q->label({'for' => 'origin'}, 'Geographic origin:');
	##					$q->start_Select({'id' => 'origin', 'name' => 'origin'}); "\n",
	#U2_modules::U2_subs_1::select_origin($q);
	##print					$q->end_Select(),
	#print 					$q->br(), "\n",
	#				$q->end_li(), "\n",
	#				$q->start_li({'class' => 'w3-padding-16'}),
	#					$q->start_fieldset(),
	#						$q->legend('Index Case:'),
	#						$q->radio_group(-name => 'proband', -values => [keys %proband], -labels => \%proband, -columns => 1, -defaults => '', -class => 'w3-radio'),
	#					$q->end_fieldset(), $q->br(),
	#				$q->end_li(), "\n",
	#				$q->start_li({'class' => 'w3-padding-16'}),
	#					$q->label({'for' => 'comment'}, 'Comments:'),
	#					$q->textarea({'name' => 'comment', 'rows' => '7', 'cols' => '30'}), $q->br(), "\n",
	#				$q->end_li(), "\n",
	#			$q->end_ol(),
	#		$q->end_fieldset(),
			$q->br(),
			$q->submit({'value' => 'Perform record', 'class' => 'w3-button w3-blue w3-hover-white'}), $q->br(), $q->br(), "\n",
		$q->end_form(), $q->end_div(), "\n", $q->br(), $q->br(),
		$q->start_div();
		print U2_modules::U2_subs_2::cnil_disclaimer($q);

}
elsif ($step == 2) {
	#check params integrity
	#@U2_modules::U2_subs_1::COUNTRY donne la liste des pays valides
	my ($phenotype, $gender, $country, $proband, $comment, $id, $num);
	($id, $num) = U2_modules::U2_subs_1::sample2idnum($sample, $q);	
	if ($q->param('phenotype') && $q->param('phenotype') =~ /^$PATIENT_PHENOTYPE$/o) {$phenotype = $1}
	else {&insert_error('phenotype')}
	if ($q->param('gender') && $q->param('gender') =~ /^(M|F|X)$/o) {$gender = $1}
	else {&insert_error('gender')}
	if ($q->param('origin') && $q->param('origin') =~ /([a-zA-Z.'\s]+)/o) {
		if (grep (/$1/, @U2_modules::U2_subs_1::COUNTRY)) {$country = $1}
		else {&insert_error('origin')}
	}
	else {&insert_error('origin')}
	if ($q->param('proband') && $q->param('proband') =~ /^(t|f)$/o) {$proband = $1}
	else {&insert_error('proband')}
	if ($q->param('comment') && $q->param('comment') =~ /([^\\]+)/o) {$comment = $1}
	
	$last_name =~ s/'/''/og;
	$first_name =~ s/'/''/og;
	$comment =~ s/'/''/og;
		
	my $query = "INSERT INTO patient (numero, identifiant, famille, pathologie, sexe, commentaire, origine, proband, last_name, first_name, date_creation) VALUES ('$num', '$id', '$family', '$phenotype', '$gender', '$comment', '$country', '$proband', '$last_name', '$first_name', '".U2_modules::U2_subs_1::get_date()."');";
	$query = U2_modules::U2_subs_1::accent2html($query);
	#print $query;
	$dbh->do($query);
	print $q->redirect("patient_file.pl?sample=$id$num");
}



##Basic end of USHVaM 2 perl scripts:

U2_modules::U2_subs_1::standard_end_html($q);

print $q->end_html();

exit();

##End of Basic end

##specific subs for current script

sub insert_error {
	my $reason = shift;
	print $q->p("Sorry USHVaM 2 cannot accept this patient because of a $reason error. Please contact admin.");
	U2_modules::U2_subs_1::standard_end_html($q);
	print $q->end_html();
	exit();
}

exit();
