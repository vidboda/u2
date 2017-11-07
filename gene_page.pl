BEGIN {delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV', 'PATH'};}

use strict;
#use CGI;#in startup.pl
#use DBI;
#use AppConfig qw(:expand :argcount);
use URI::Escape;
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


##Custom init of USHVaM 2 perl scripts: slightly modified with jquery ui and headers are printed later for redirection purpose
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
my $PERL_SCRIPTS_HOME = $config->PERL_SCRIPTS_HOME();

my @styles = ($CSS_PATH.'w3.css', $CSS_DEFAULT, $CSS_PATH.'jquery-ui-1.10.3.custom.min.css', $CSS_PATH.'datatables.min.css');

my $q = new CGI;

my $dbh = DBI->connect(    "DBI:Pg:database=$DB;host=$HOST;",
                        $DB_USER,
                        $DB_PASSWORD,
                        {'RaiseError' => 1}
                ) or die $DBI::errstr;


my $js = 'function chooseSortingType(gene) {
		var $dialog = $(\'<div></div>\')
			.html("<p>Choose how your variants will be sorted:</p><ul><li><a href = \'gene.pl?gene="+gene+"&info=all_vars&sort=classe\' target = \'_blank\'>Pathogenic class</a></li><li><a href = \'gene.pl?gene="+gene+"&info=all_vars&sort=type_adn\' target = \'_blank\'>DNA type (subs, indels...)</a></li><li><a href = \'gene.pl?gene="+gene+"&info=all_vars&sort=type_prot\' target = \'_blank\'>Protein type (missense, silent...)</a></li><li><a href = \'gene.pl?gene="+gene+"&info=all_vars&sort=type_arn\' target = \'_blank\'>RNA type (neutral / altered)</a></li><li><a href = \'gene.pl?gene="+gene+"&info=all_vars&sort=taille\' target = \'_blank\'>Variant size (get only large rearrangements)</a></li><li><a href = \'https://194.167.35.158/perl/led/engine.pl?research="+gene+"\' target = \'_blank\'>LED rare variants</a></li></ul>")
			.dialog({
			    autoOpen: false,
			    title: \'U2 choice\',
			    width: 450,
			});
		$dialog.dialog(\'open\');
		$(\'.ui-dialog\').zIndex(\'1002\');
	}';


my $user = U2_modules::U2_users_1->new();




##end of Basic init

if ($q->param('sort') && $q->param('sort') =~ /(ALL|USHER|DFNB|DFNA|DFNX|CHM|LCA|NSRP)/o) {
	my $sort = $1;
	#if ($sort eq 'CHM') {
	#	my $url = 'gene.pl?gene=CHM&info=general';
	#	print $q->redirect("$PERL_SCRIPTS_HOME$url");
	#}
	#else {
		print $q->header(-type => 'text/html', -'cache-control' => 'no-cache'),
			$q->start_html(-title=>"U2 Gene page",
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
					-src => $JS_PATH.'jquery-ui-1.10.3.custom.min.js', 'defer' => 'defer'},
					{-language => 'javascript',
					-src => $JS_PATH.'datatables.min.js', 'defer' => 'defer'},
					$js,
					{-language => 'javascript',
					-src => $JS_PATH.'jquery.autocomplete.min.js', 'defer' => 'defer'},
					{-language => 'javascript',
					-src => $JS_DEFAULT, 'defer' => 'defer'}],		
				-encoding => 'ISO-8859-1');
			
		U2_modules::U2_subs_1::standard_begin_html($q, $user->getName());
		my @list;
		if ($sort eq 'ALL') {
			my $query = 'SELECT DISTINCT(nom[1]) FROM gene ORDER BY nom[1];';
			@list = @{$dbh->selectcol_arrayref($query)};
		}
		elsif ($sort eq 'USHER') {@list = @U2_modules::U2_subs_1::USHER}
		elsif ($sort eq 'DFNB') {@list = @U2_modules::U2_subs_1::DFNB}
		elsif ($sort eq 'DFNA') {@list = @U2_modules::U2_subs_1::DFNA}
		elsif ($sort eq 'DFNX') {@list = @U2_modules::U2_subs_1::DFNX}
		elsif ($sort eq 'CHM') {@list = @U2_modules::U2_subs_1::CHM}
		elsif ($sort eq 'LCA') {@list = @U2_modules::U2_subs_1::LCA}
		elsif ($sort eq 'NSRP') {@list = @U2_modules::U2_subs_1::NSRP}		
		print $q->start_p({'class' => 'center title'}), $q->start_big(), $q->strong("Gene group: $sort (".($#list+1)." genes)"), $q->end_big(), $q->end_p(), "\n",
			$q->p('Click on a link to go to the detailed page:');
		#	$q->start_ul(), "\n";
		
		print $q->start_div({'class' => 'fitin container'}), $q->start_table({'class' => 'great_table technical', 'id' => 'gene_table', 'data-page-length' => '25'}), $q->caption("Genes table:"), $q->start_thead(),
					$q->start_Tr(), "\n",
					$q->th({'class' => 'left_general'}, 'Genes'), "\n",
					#$q->th({'colspan' => '5', 'class' => 'left_general'}, 'Links'), "\n",
					$q->th({'class' => 'left_general'}, 'Links'), $q->th(), $q->th(), $q->th(), $q->th(), "\n",
					$q->end_Tr(),
					#$q->start_Tr(), "\n",
					#$q->th(), $q->th(), $q->th(), $q->th(), $q->th(), "\n",
					#$q->end_Tr(),
					$q->end_thead(), $q->start_tbody(), "\n";			 
		
		foreach (@list) {
			print $q->start_Tr(),
				$q->start_td(), $q->em($_), $q->end_td(),
				$q->start_td(), $q->a({'href' => "gene.pl?gene=$_&info=general", 'target' => '_blank'}, 'General info'), $q->end_td(),
				$q->start_td(), $q->a({'href' => "gene.pl?gene=$_&info=structure", 'target' => '_blank'}, 'Structure'), $q->end_td(),
				$q->start_td(), $q->a({'href' => "#", 'onclick' => "chooseSortingType('$_');"}, 'All variants'), $q->end_td(),
				$q->start_td(), $q->a({'href' => "gene.pl?gene=$_&info=genotype", 'target' => '_blank'}, 'Genotypes'), $q->end_td(),
				$q->start_td(), $q->a({'href' => "gene_graphs.pl?gene=$_", 'target' => '_blank'}, 'Graphs'), $q->end_td(),
			$q->end_Tr();
				
		}
		print $q->end_tbody(), $q->end_table(), $q->end_div();
		#foreach (@list) {print $q->start_li({'class' => 'pointer', 'onclick' => "window.open('gene.pl?gene=$_&info=general');"}), $q->em($_), $q->end_li()}
		#print $q->end_ul();
	#}
}





##Basic end of USHVaM 2 perl scripts:

U2_modules::U2_subs_1::standard_end_html($q);

print $q->end_html();

exit();

##End of Basic end