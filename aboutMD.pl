BEGIN {delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV', 'PATH'};}

use strict;
#use CGI;
#use DBI;
#use AppConfig qw(:expand :argcount);
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


my @styles = ($CSS_PATH.'font-awesome.min.css', $CSS_PATH.'w3.css', $CSS_DEFAULT);

my $q = new CGI;

#custom js for aboutMD.pl
my $js = "
	function accord(id) {
		//alert(\$('#'+id).css('display'));
		if (\$('#'+id).css('display') == 'block') {\$('#'+id).hide();}
		else {\$('#'+id).show();}
	}
";

print $q->header(-type => 'text/html', -'cache-control' => 'no-cache'),
	$q->start_html(-title=>"MobiDetails: about",
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
                                -src => $JS_PATH.'jquery.autocomplete.min.js', 'defer' => 'defer'},
								$js,
                                {-language => 'javascript',
                                -src => $JS_DEFAULT, 'defer' => 'defer'}],		
                        -encoding => 'ISO-8859-1');

my $user = U2_modules::U2_users_1->new();

my $dbh = DBI->connect(    "DBI:Pg:database=$DB;host=$HOST;",
                        $DB_USER,
                        $DB_PASSWORD,
                        {'RaiseError' => 1}
                ) or die $DBI::errstr;

U2_modules::U2_subs_1::public_begin_html($q, $user->getName(), $dbh);

##end of Basic init


print $q->br(), $q->br(),
	$q->start_div({'class' => 'w3-button w3-block w3-blue', 'onclick' => "accord('whatyouwillget');"}), "\n",
		$q->h1('What you will get with MobiDetails'), "\n",
	$q->end_div(), "\n",
	$q->start_div({'class' => 'w3-container w3-padding-64 w3-center', 'style' => 'display:none', 'id' => 'whatyouwillget'}), "\n",
		$q->img({'src' => $HTDOCS_PATH.'data/img/MD1.png', 'width' => '80%'}), "\n",
	$q->end_div(), "\n",
	$q->start_div({'class' => 'w3-button w3-block w3-blue', 'onclick' => "accord('whatyouneed');"}), "\n",
		$q->h1('What you need to run MobiDetails'), "\n",
	$q->end_div(), "\n",
	$q->start_div({'class' => 'w3-container w3-padding-64 w3-center', 'style' => 'display:none', 'id' => 'whatyouneed'}), "\n",
		$q->span('Internet, a web browser, a gene and a variant of interest (HGVS c. nomenclature). That\'s all.'), "\n",
	$q->end_div(), "\n",
	$q->start_div({'class' => 'w3-button w3-block w3-blue', 'onclick' => "accord('video1');"}), "\n",
		$q->h1('Check out the general video tutorial'), "\n",
	$q->end_div(), "\n",
	$q->start_div({'class' => 'w3-container w3-padding-64 w3-center', 'style' => 'display:none', 'id' => 'video1'}), "\n",
		"<video controls = 'controls' width = '60%' name = 'MD tutorial' src = '".$HTDOCS_PATH."data/videos/MD1.mp4'></video>", "\n",
	$q->end_div(), "\n",
	$q->start_div({'class' => 'w3-button w3-block w3-blue', 'onclick' => "accord('video2');"}), "\n",
		$q->h1('How to find relevant publications'), "\n",
	$q->end_div(), "\n",
	$q->start_div({'class' => 'w3-container w3-padding-64 w3-center', 'style' => 'display:none', 'id' => 'video2'}), "\n",
		"<video controls = 'controls' width = '60%' name = 'MD tutorial' src = '".$HTDOCS_PATH."data/videos/MD_pubmed.mp4'></video>", "\n",
	$q->end_div(), "\n",
	$q->start_div({'class' => 'w3-button w3-block w3-blue', 'onclick' => "accord('blacklist');"}), "\n",
		$q->h1('MD Gene Black List:'), "\n",
	$q->end_div(), "\n",
	$q->start_div({'class' => 'w3-container w3-padding-64', 'style' => 'display:none', 'id' => 'blacklist'}), "\n",
		$q->p('The following genes do not work properly in MD at the time:'), "\n",
		$q->start_ul(), "\n",
			$q->start_li(), $q->em('COL6A2'), $q->span(': NM accession issues between MD and Mutalyzer'), $q->end_li(), "\n",
			$q->start_li(), $q->em('COX20'), $q->span(': main transcript unknown in Mutalyzer PositionConverter'), $q->end_li(), "\n",
			$q->start_li(), $q->em('HOXA10'), $q->span(': crashes Mutalyzer'), $q->end_li(), "\n",
			$q->start_li(), $q->em('MYO18B'), $q->span(': main transcript unknown in Mutalyzer PositionConverter'), $q->end_li(), "\n",
			$q->start_li(), $q->em('MAPK8'), $q->span(': main transcript unknown in Mutalyzer PositionConverter'), $q->end_li(), "\n",
			$q->start_li(), $q->em('MAPT'), $q->span(': NM accession issues between MD and Mutalyzer'), $q->end_li(), "\n",
			$q->start_li(), $q->em('PTRH2'), $q->span(': main transcript unknown in Mutalyzer PositionConverter'), $q->end_li(), "\n",
			$q->start_li(), $q->em('SELENON'), $q->span(': Mutalyzer issue: translation not performed'), $q->end_li(), "\n",
			$q->start_li(), $q->em('SLC30A9'), $q->span(': unknown issue'), $q->end_li(), "\n",
			$q->start_li(), $q->em('THBS4'), $q->span(': main transcript unknown in Mutalyzer PositionConverter'), $q->end_li(), "\n",
			$q->start_li(), $q->em('VARS2'), $q->span(': NM accession issues betewen MD and Mutalyzer'), $q->end_li(), "\n",
		$q->end_ul(), "\n",
		$q->p('Please note that these genes are expected to work properly in future versions of MD.'), "\n", 
	$q->end_div(), "\n";





##Basic end of USHVaM 2 perl scripts:

U2_modules::U2_subs_1::public_end_html($q);

print $q->end_html();

exit();

##End of Basic end
