BEGIN {delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV', 'PATH'};}

use strict;
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
#		page to display patients for a given phenotype


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

my @styles = ($CSS_PATH.'font-awesome.min.css', $CSS_PATH.'w3.css', $CSS_DEFAULT, $CSS_PATH.'datatables.min.css');

my $q = new CGI;

my $dbh = DBI->connect(    "DBI:Pg:database=$DB;host=$HOST;",
                        $DB_USER,
                        $DB_PASSWORD,
                        {'RaiseError' => 1}
                ) or die $DBI::errstr;

print $q->header(-type => 'text/html', -'cache-control' => 'no-cache'),
	$q->start_html(-title=>"U2 patients",
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
				-src => $JS_PATH.'datatables.min.js', 'defer' => 'defer'},
				{-language => 'javascript',
				-src => $JS_PATH.'jquery.autocomplete.min.js', 'defer' => 'defer'},
				{-language => 'javascript',
				-src => $JS_DEFAULT, 'defer' => 'defer'}],		
                        -encoding => 'ISO-8859-1');

my $user = U2_modules::U2_users_1->new();


U2_modules::U2_subs_1::standard_begin_html($q, $user->getName(), $dbh);

##end of Basic init

my $phenotype;

if ($q->param('phenotype') eq 'all') {$phenotype = '%'}
elsif ($q->param('phenotype') eq 'USHER') {$phenotype = '%USH%'}
else {$phenotype = U2_modules::U2_subs_1::check_phenotype($q)}

#general infos
my $text = $phenotype;
if ($text eq '%') {$text = 'All'}
$text =~ s/%//og;

my ($query1, $query2, $query3, $query4);


$query1 = "SELECT COUNT(numero) as a FROM patient WHERE pathologie LIKE '$phenotype'";
$query2 = "SELECT COUNT(distinct(first_name, last_name)) as a FROM patient WHERE pathologie LIKE '$phenotype'";
$query3 = "SELECT COUNT(distinct(first_name, last_name)) as a FROM patient WHERE proband = 't' AND pathologie LIKE '$phenotype'";
$query4 = "SELECT numero, identifiant, pathologie, proband FROM patient WHERE pathologie LIKE '$phenotype' ORDER BY identifiant, numero;";


my $sam = $dbh->selectrow_hashref($query1);
my $pat = $dbh->selectrow_hashref($query2);
my $pro = $dbh->selectrow_hashref($query3);

print $q->start_big(), $q->p("$text samples ($sam->{'a'}) registered in U2 ($pat->{'a'} patients including $pro->{'a'} proband):"), $q->end_big(),
	$q->span('('), $q->a({'href' => '#', 'onclick' => '$(\'.hidden\').show(\'slow\')'}, 'Show all'), $q->span(' / '), $q->a({'href' => '#', 'onclick' => '$(\'.hidden\').hide(\'slow\')'}, 'Hide all'),$q->span(').');


my $sth = $dbh->prepare($query4);
my $res = $sth->execute();
my ($i, $j) = (0, 0);
my ($semaph, $init) = ('', '');


#display patients grouped by numbering (0 -> 99, 100 -> 199..) and identifier (CHM, then SU)
print $q->start_div({'class' => 'container'});
while (my $result  = $sth->fetchrow_hashref()) {
	#get infos
	my ($number, $id, $pathologie) = ($result->{'numero'}, $result->{'identifiant'}, $result->{'pathologie'});
	my $proband = 'relative';
	if ($result->{'proband'} == 1) {$proband = 'proband'}
	
	#first line only
	if ($semaph eq '') {
		#if ($number <= 99) {print $q->p({'class' => 'title pointer', 'onclick' => '$(\'#'.$id.$i.'\').toggle(\'slow\');'}, "--$id 0 to 99"), $q->start_ul({'class' => 'hidden', 'id' => $id.$i})}
		#else {print $q->start_ul()}#initiates empty ul to respect <ul></ul> (ul closed line 140)
		#if ($number <= 99) {print $q->p({'class' => 'title pointer', 'onclick' => '$(\'#'.$id.$i.'\').toggle(\'slow\');'}, "--$id 0 to 99");&initiare_table();, $q->start_table({'class' => 'hidden great_table technical', 'id' => $id.$i})}
		if ($number <= 99) {print $q->p({'class' => 'title pointer', 'onclick' => '$(\'#'.$id.$i.'\').toggle(\'slow\');'}, "--$id 0 to 99");&initiate_table($q, "$id$i");}
		else {&initiate_table($q, "$id$i")}
		#else {print $q->start_table({'class' => 'hidden great_table technical', 'id' => $id.$i})}#initiates empty table to respect <ul></ul>
		
	}
	#initiates new identifier
	if ($j == 0) {$semaph = $id;$j = 1;}
	if ($semaph ne $id) {
		($i, $j, $semaph) = (0, 0, $id);
		#print  $q->end_ul(), $q->p({'class' => 'title pointer', 'onclick' => '$(\'#'.$id.$i.'\').toggle(\'slow\');'}, "--$id 0 to 99"), $q->start_ul({'class' => 'hidden', 'id' => $id.$i});
		#print  $q->end_table, $q->end_div(), $q->p({'class' => 'title pointer', 'onclick' => '$(\'#'.$id.$i.'\').toggle(\'slow\');'}, "--$id 0 to 99"), $q->start_table({'class' => 'hidden hidden great_table technical', 'id' => $id.$i});
		print  $q->end_tbody(), $q->end_table, $q->p({'class' => 'title pointer', 'onclick' => '$(\'#'.$id.$i.'\').toggle(\'slow\');'}, "--$id 0 to 99");
		&initiate_table($q, "$id$i");
	}
	#display patients
	if ($number > $i && $number < ($i+100)) {
		&fill_table("$id$number", $proband, $pathologie)
	}
		#print $q->start_Tr(), $q->start_td({'class' => 'center'}), $q->start_a({'href' => "patient_file.pl?sample=$id$number", 'title' => 'Access to patient\'s details'}), $q->span({'class' => 'list'}, "$id$number&nbsp;"), $q->img({'src' => $HTDOCS_PATH.'data/img/link_small.png', 'border' => '0', 'width' =>'15'}), $q->end_a(), $q->span("&nbsp;, $proband ($pathologie)"), $q->end_td(), $q->end_Tr(), "\n";}
	elsif ($number >= ($i+100)) {
		while ($number >= $i+100) {
			$i = $i+100				
		}
		#print $q->end_ul(), $q->p({'class' => 'title pointer', 'onclick' => '$(\'#'.$id.$i.'\').toggle(\'slow\');'}, "--$result->{'identifiant'} $i to ".($i+99)), $q->start_ul({'class' => 'hidden', 'id' => $id.$i}), $q->start_li({'class' => 'center'}),
		#		$q->start_a({'href' => "patient_file.pl?sample=$id$number"}), $q->span({'class' => 'list'}, "$id$number&nbsp;"), $q->img({'src' => $HTDOCS_PATH.'data/img/link_small.png', 'border' => '0', 'width' =>'15', 'class' => 'text_img'}), $q->end_a(), $q->span("&nbsp;, $proband ($pathologie)"), $q->end_li(), "\n";
		#print $q->end_table(), $q->p({'class' => 'title pointer', 'onclick' => '$(\'#'.$id.$i.'\').toggle(\'slow\');'}, "--$result->{'identifiant'} $i to ".($i+99)), $q->start_table({'class' => 'hidden hidden great_table technical', 'id' => $id.$i}), $q->start_Tr(), $q->start_td({'class' => 'center'}),
		#		$q->start_a({'href' => "patient_file.pl?sample=$id$number"}), $q->span({'class' => 'list'}, "$id$number&nbsp;"), $q->img({'src' => $HTDOCS_PATH.'data/img/link_small.png', 'border' => '0', 'width' =>'15', 'class' => 'text_img'}), $q->end_a(), $q->span("&nbsp;, $proband ($pathologie)"), $q->end_td(), $q->end_Tr(), "\n";
		print $q->end_tbody(), $q->end_table(), $q->p({'class' => 'title pointer', 'onclick' => '$(\'#'.$id.$i.'\').toggle(\'slow\');'}, "--$result->{'identifiant'} $i to ".($i+99));
		&initiate_table($q, "$id$i");
		&fill_table("$id$number", $proband, $pathologie);
		#print		$q->start_Tr(), $q->start_td({'class' => 'center'}),
		#		$q->start_a({'href' => "patient_file.pl?sample=$id$number"}), $q->span({'class' => 'list'}, "$id$number&nbsp;"), $q->img({'src' => $HTDOCS_PATH.'data/img/link_small.png', 'border' => '0', 'width' =>'15', 'class' => 'text_img'}), $q->end_a(), $q->span("&nbsp;, $proband ($pathologie)"), $q->end_td(), $q->end_Tr(), "\n";
	}
}

print $q->end_table(), $q->end_div();

#print "</ul>";





##Basic end of USHVaM 2 perl scripts:

U2_modules::U2_subs_1::standard_end_html($q);

print $q->end_html();

exit();

##End of Basic end

##specific subs for current script  , 'data-page-length' => '25'


sub initiate_table() {
	my ($q, $id) = @_;
	#my $table_js = "\$('#$id').DataTable({
	#	paging: false,
	#	//scrollY: 400
	#});
	#\$('#".$id."_info').hide();
	#//\$('#".$id."-wrapper').hide();
	#//\$('.odd').hide();";
	#print ;
	#print $q->start_div({'class' => 'hidden', 'id' => "div_$id"}, ), $q->start_table({'class' => 'great_table technical', 'id' => $id}), $q->start_thead(), "\n",
	print $q->start_table({'class' => 'hidden great_table technical', 'id' => $id}), $q->start_thead(), "\n",
		$q->start_Tr(), "\n",
			$q->th({'class' => 'left_general'}, 'Sample ID'), "\n",
			$q->th({'class' => 'left_general'}, 'Family status'), "\n",
			$q->th({'class' => 'left_general'}, 'Phenotype'), "\n",
		$q->end_Tr(), $q->end_thead(), $q->start_tbody(), "\n";#, $q->script({'type' => 'text/javascript', 'defer' => 'defer'}, $table_js), "\n";
}

sub fill_table {
	my ($sample, $proband, $pathologie) = @_;
	print $q->start_Tr(), "\n",
		$q->start_td({'class' => 'center'}), "\n",
			$q->a({'href' => "patient_file.pl?sample=$sample", 'title' => 'Access to patient\'s details'}, $sample), "\n",
		$q->end_td(), "\n",
		$q->td($proband), "\n",
		$q->td($pathologie), "\n",
	,$q->end_Tr(), "\n";
}
