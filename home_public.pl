BEGIN {delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV', 'PATH'};}

use strict;
#use CGI;
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
#
#		Home page of U2


##Basic init of USHVaM 2 perl scripts: slightly modified with custom js
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


my @styles = ($CSS_PATH.'font-awesome.min.css', $CSS_PATH.'w3.css', $CSS_DEFAULT, $CSS_PATH.'fullsize/fullsize.css', $CSS_PATH.'jquery.alerts.css');

my $q = new CGI;

my $dbh = DBI->connect(    "DBI:Pg:database=$DB;host=$HOST;",
                        $DB_USER,
                        $DB_PASSWORD,
                        {'RaiseError' => 1}
                ) or die $DBI::errstr;

#custom js for home.pl
my $js = "
	function info(type) {
		if (type === 'class') {jAlert('<ul>".U2_modules::U2_subs_2::info_text($q, 'class')."</ul>', 'Information box');}
		else if (type === 'neg') {jAlert('<ul>".U2_modules::U2_subs_2::info_text($q, 'neg')."</ul>', 'Information box');}
	}
"; 
#end custom js

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
				-src => $JS_PATH.'jquery.alerts.js', 'defer' => 'defer'},
                                {-language => 'javascript',
                                -src => $JS_PATH.'jquery.autocomplete.min.js', 'defer' => 'defer'},
				$js,
                                {-language => 'javascript',
                                -src => $JS_DEFAULT, 'defer' => 'defer'}],		
                        -encoding => 'ISO-8859-1');

my $user = U2_modules::U2_users_1->new();


U2_modules::U2_subs_1::public_begin_html($q, $user->getName(), $dbh);

##end of Basic init


#1st query to the database - basic statistics

my $query = "SELECT COUNT(DISTINCT(nom[1])) as a, COUNT(nom[2]) as b FROM gene;";
my $res = $dbh->selectrow_hashref($query);

#my $user = users->new();

#print $q->start_div({'align' => 'center'}), $q->img({'src' => $HTDOCS_PATH.'data/img/U2.png', 'alt' => 'U2'}), $q->start_p(), $q->big($user->getName().", Welcome to USHVaM 2. The system currently records $res->{'a'} different variants collected in $res->{'b'} genes corresponding to $res->{'c'} different isoforms."), $q->end_p(), "\n",
#	$q->p("You ".$user->isAnalystToString()." and ".$user->isValidatorToString()." and ".$user->isRefereeToString()), "\n";

print $q->start_div({'class' => 'w3-container w3-center w3-padding-32'}), $q->img({'src' => $HTDOCS_PATH.'data/img/U2.png', 'alt' => 'U2'}), $q->p({'class' => 'w3-large'}, ucfirst($user->getName()).", Welcome to MobiDetails: You can create and investigate variants in "), "\n",
$q->start_div(), "\n",
	$q->span({'class' => 'w3-badge w3-jumbo w3-blue'}, $res->{'a'}), $q->span (' genes '), $q->span({'class' => 'w3-badge w3-jumbo w3-red'}, $res->{'b'}), $q->span (' isoforms '), "\n",
$q->end_div(), "\n";


#$query = "SELECT COUNT(nom) as a FROM variant;";
$query = "SELECT COUNT(a.nom_g) as a FROM variant a LEFT JOIN variant2patient b ON a.nom = b.nom_c AND a.nom_gene = b.nom_gene WHERE b.nom_c IS NULL;";
$res = $dbh->selectrow_hashref($query);

print $q->start_div(), $q->start_p(), $q->span(' You currently have already '), $q->span({'class' => 'w3-badge w3-xxlarge w3-teal'}, $res->{'a'}), $q->span(' variants that can be investigated');

print $q->end_p(), $q->end_div(), $q->end_div(), "\n",
	$q->start_div({'align' => 'center'}), "\n",
		$q->start_form({'action' => '/perl/U2/engine_public.pl', 'id' => 'main', 'method' => 'POST', 'enctype' => &CGI::URL_ENCODED}), "\n",
			$q->start_div({'class' => 'w3-margin-16 w3-container', 'style' => 'width:50%'}), "\n",
				$q->input({'type' => 'text', 'name' => 'search', 'id' => 'main_engine', 'size' => '50', 'maxlength' => '40', 'placeholder' => ' Ask USHVaM 2:', 'class' => 'w3-input w3-light-grey w3-animate-input', 'style' => 'width:30%'}), "\n", $q->br(), $q->br(),
				$q->input({'type' => 'submit', 'value' => 'Submit', 'class' => 'w3-button w3-blue'}),
			$q->end_div(), "\n",
		$q->end_form(), "\n",
	$q->end_div(), "\n",$q->br(), $q->start_div({'id' => 'farside', 'class' => 'appear center'}), $q->end_div(), "\n",
	$q->br(), $q->br(), $q->start_div({'align' => 'center'}),
	#$q->p('At the time, menu:'),
	#$q->start_ul(),
	#	$q->start_li(), $q->span('Patients is '), $q->font({'color' => 'green'}, 'active'), $q->end_li(),
	#	$q->start_li(), $q->span('Genes is '), $q->font({'color' => 'green'}, 'active'), $q->end_li(),
	#	$q->start_li(), $q->span('Advanced is '), $q->font({'color' => 'green'}, 'active'), $q->end_li(),
	#	$q->start_li(), $q->span('Search engine is '), $q->font({'color' => 'green'}, 'active'), $q->end_li(),
	#	$q->start_li(), $q->span('Statistics is '), $q->font({'color' => 'green'}, 'active'), $q->end_li(),
	#	#$q->start_li(), $q->span('Variants is '), $q->font({'color' => 'red'}, 'inactive'), $q->end_li(),
	#	
	#$q->end_ul(),	
	$q->end_div();
	#$q->start_div(),
	my $text = $q->span('Example research for search engine:').
		$q->start_ul().
			$q->li('\'p.(Arg34*)\', \'p.Arg34*\', \'p.R34*\', \'p.R34X\', \'R34X\' will look for variants linked to these protein name').
			$q->li('\'chr1:g.216595579G>A\', \'g.6160C>T\', \'c.100C>T\', \'100C>T\', \'IVS15+35G>A\' will look for variants linked to these DNA name').
			$q->li('Partial names for variants can be used e.g. \'c.100\' or \'IVS15\' will look for variants begining with c.100 or IVS15').
			$q->li('Special: IVSX+3 will look for any \'+3\' variant').
			$q->li('And, last but not least, typing a number will seek for variants (DNA c. and protein)!').
		$q->end_ul()."\n";
	print U2_modules::U2_subs_2::info_panel($text, $q);
	#$q->span('Example research for search engine:'), 
	#	$q->start_ul(),
	#		$q->li('\'SU1034\', \'su1034\', \'CHM52\', \'chm52\' will look for a patient ID'),
	#		$q->li('\'p.(Arg34*)\', \'p.Arg34*\', \'p.R34*\', \'p.R34X\', \'R34X\' will look for variants linked to these protein name'),
	#		$q->li('\'chr1:g.216595579G>A\', \'g.6160C>T\', \'c.100C>T\', \'100C>T\', \'IVS15+35G>A\' will look for variants linked to these DNA name'),
	#		$q->li('Partial names for variants can be used e.g. \'c.100\' or \'IVS15\' will look for variants begining with c.100 or IVS15'),
	#		$q->li('Special: IVSX+3 will look for any \'+3\' variant'),
	#		$q->li('Large rearrangements can be found using \'E11-12del\' or \'E11-12\' or \'E11\', however, for diverse reasons e.g. \'E11\' will look for rearrangements beginning or ending in introns 10 to 12 of each gene'),
	#		$q->li('\'ROYO\', \'royo\' will look for last name'),
	#		$q->li('\'U283\', \'u283\' will look for family ID'),
	#		$q->li('And, last but not least, typing a number will seek for patient, family, variants (DNA c. and protein)!'),
	#	$q->end_ul(),
	#$q->end_div(),
	print $q->br(), $q->br(),
	$q->start_div({'align' => 'center'}),
		$q->start_a({'href' => 'http://perl.apache.org/', 'target' => '_blank'}), $q->img({'src' => $HTDOCS_PATH.'data/img/mod_perl.png', 'width' => '100', 'height' => '20'}), $q->end_a(),
		$q->span('&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'),
		$q->start_a({'href' => 'http://www.postgresql.org/', 'target' => '_blank'}), $q->img({'src' => $HTDOCS_PATH.'data/img/Postgresql.gif', 'width' => '75', 'height' => '50'}), $q->end_a(),
		$q->span('&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'),
		$q->start_a({'href' => 'http://httpd.apache.org/docs/2.2/mod/mod_ssl.html', 'target' => '_blank'}), $q->img({'src' => $HTDOCS_PATH.'data/img/mod_ssl.jpg', 'width' => '62', 'height' => '30'}), $q->end_a(),
	$q->end_div();


##Basic end of USHVaM 2 perl scripts:

U2_modules::U2_subs_1::standard_end_html($q);

print $q->end_html();

exit();

##End of Basic end
