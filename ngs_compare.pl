BEGIN {delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV', 'PATH'};}

use strict;
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


##Extended init of USHVaM 2 perl scripts - loaded: Charts.min.js, timeline JS (storyjs-embed.js)
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
my $ANALYSIS_ILLUMINA_REGEXP = $config->ANALYSIS_ILLUMINA_REGEXP();

my @styles = ($CSS_PATH.'font-awesome.min.css', $CSS_PATH.'w3.css', $CSS_DEFAULT, $CSS_PATH.'fullsize/fullsize.css', $CSS_PATH.'jquery.alerts.css', $CSS_PATH.'datatables.min.css');

my $q = new CGI;

my $dbh = DBI->connect(    "DBI:Pg:database=$DB;host=$HOST;",
                        $DB_USER,
                        $DB_PASSWORD,
                        {'RaiseError' => 1}
                ) or die $DBI::errstr;

my $loading = U2_modules::U2_subs_2::info_panel('Loading...', $q);
chomp($loading);
$loading =~ s/'/\\'/og;

my $js = "
	i = 1;
	function show_vs_table(analysis_value) {
		if (i <= 6) {
			//\$(\'#match_container\').append('$loading');
			\$(\'#page\').css(\'cursor\', \'progress\');
			\$(\'.w3-button\').css(\'cursor\', \'progress\');
			\$.ajax({
				type: \"POST\",
				url: \"ajax.pl\",
				data: {vs_table: 1, analysis: analysis_value, round: i}
			})
			.done(function(content) {
				if (i == 1) {\$(\'#vs_table\').css('display', 'none');\$(\'#vs_table\').html(content);\$(\'#vs_table\').fadeIn();}
				else {
					//k = 100/i;
					//alert(content);
					//each 1st child or sthg like .css('width', 'width:k;')
					\$(\'#match_\' + i).css(\'display\', \'none\');
					\$(\'#match_container\').append(content);
					\$(\'#match_\' + i).fadeIn();
					//\$(\'#match_i\').css('width', function (i) {
					//	return 100 / i;
					//});
				}
				i += 1;
				\$(\'#page\').css(\'cursor\', \'default\');
				\$(\'.w3-button\').css(\'cursor\', \'default\');
			});
		}
		else {
			//document.getElementById('modal1').style.display='block;';
			\$(\'#modal1\').fadeIn();
		}
	}
	function reset() {
		\$(\'#match_container\').fadeOut();
		//\$(\'#match_container\').html('');
		i = 1;
	}
";



print $q->header(-type => 'text/html', -'cache-control' => 'no-cache'),
	$q->start_html(-title=>"U2 Illumina stats",
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
				-src => $JS_PATH.'jquery.validate.min.js', 'defer' => 'defer'},
				{-language => 'javascript',
				-src => $JS_PATH.'datatables.min.js', 'defer' => 'defer'},
				{-language => 'javascript',
				-src => $JS_PATH.'jquery.alerts.js', 'defer' => 'defer'},
				#{-language => 'javascript',
				#-src => $JS_PATH.'timeline/js/storyjs-embed.js', 'defer' => 'defer'},
                                {-language => 'javascript',
                                -src => $JS_PATH.'jquery.autocomplete.min.js', 'defer' => 'defer'},
				$js,
                                {-language => 'javascript',
                                -src => $JS_DEFAULT, 'defer' => 'defer'}],		
                        -encoding => 'ISO-8859-1');

my $user = U2_modules::U2_users_1->new();


U2_modules::U2_subs_1::standard_begin_html($q, $user->getName(), $dbh);

##end of Basic init

my $ANALYSIS_ILLUMINA_PG_REGEXP = $config->ANALYSIS_ILLUMINA_PG_REGEXP();
#1st specific page with mean values for a run

print U2_modules::U2_subs_3::display_page_header('the amazing competition', 'show_vs_table', 'vs_table', $q, $dbh);

print	$q->start_div({'class' => 'w3-modal', 'id' => 'modal1'}), "\n", 
		$q->start_div({'class' => 'w3-modal-content'}), "\n", 
			$q->start_div({'class' => 'w3-container w3-teal'}), "\n", 
				$q->span({'onclick' => 'document.getElementById(\'modal1\').style.display=\'none\';', 'class' => 'w3-button w3-display-topright'}, '&times;'), "\n", 
				$q->h2('Analyses are limited to 6 for comparison').
			$q->end_div(), "\n",
			$q->start_div({'class' => 'w3-container'}),
				$q->p('Please reset and then proceed again if you want to compare other types of run.'), "\n", $q->br(),
			$q->end_div(),
		$q->end_div(), "\n", 
	$q->end_div(), "\n", 
	$q->start_div({'class' => 'w3-container w3-center'}), "\n", 
		$q->span({'class' => 'w3-button w3-ripple w3-blue', 'onclick' => 'reset();'}, 'Reset'), "\n", 
	$q->end_div(), "\n";








##Basic end of USHVaM 2 perl scripts:

U2_modules::U2_subs_1::standard_end_html($q);

print $q->end_html();

exit();

##End of Basic end


##specific subs for current script