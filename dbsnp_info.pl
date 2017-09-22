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
#		Info page for dbSNP


##extended init of USHVaM 2 perl scripts: loaded chart.js
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

my @styles = ($CSS_DEFAULT, $CSS_PATH.'fullsize/fullsize.css', $CSS_PATH.'jquery.alerts.css');

my $q = new CGI;

my $dbh = DBI->connect(    "DBI:Pg:database=$DB;host=$HOST;",
                        $DB_USER,
                        $DB_PASSWORD,
                        {'RaiseError' => 1}
                ) or die $DBI::errstr;


print $q->header(-type => 'text/html', -'cache-control' => 'no-cache'),
	$q->start_html(-title=>"dbSNP info",
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
                                -src => $JS_PATH.'Chart.min.js', 'defer' => 'defer'},
                                {-language => 'javascript',
                                -src => $JS_PATH.'jquery.autocomplete.min.js', 'defer' => 'defer'},
                                {-language => 'javascript',
                                -src => $JS_DEFAULT, 'defer' => 'defer'}],		
                        -encoding => 'ISO-8859-1');

my $user = U2_modules::U2_users_1->new();


U2_modules::U2_subs_1::standard_begin_html($q, $user->getName());

##end of Basic init

print $q->br(), $q->start_p(), $q->span('When UshVam2 encounters a new variant, it checks in this parallel database of SNP restricted to our regions of interest whether a rs id exists. Until May, 2015, the version of dbSNP used in U2 was 137.'), $q->p('As of May, 2015, we have version 142, the last version compatible with hg19.'), $q->br(), $q->p('U2 uses a local database build from dbSNP but restricted to our regions of interest (121 loci).');

my $query = 'SELECT COUNT(rsid) as rsid FROM restricted_snp;';
my $res = $dbh->selectrow_hashref($query);
my $rs = $res->{'rsid'};

$query = 'SELECT COUNT(rsid) as rsid FROM restricted_snp WHERE common = \'t\';';
$res = $dbh->selectrow_hashref($query);
my $rs_com = $res->{'rsid'};

$query = 'SELECT COUNT(nom) as nom FROM variant WHERE snp_id IS NOT NULL;';
$res = $dbh->selectrow_hashref($query);
my $rs_our = $res->{'nom'};

$query = 'SELECT COUNT(a.nom) as nom FROM variant a, restricted_snp b WHERE a.snp_id = b.rsid AND b.common = \'t\';';
$res = $dbh->selectrow_hashref($query);
my $rs_our_com = $res->{'nom'};

$query = 'SELECT COUNT(nom) as nom FROM variant;';
$res = $dbh->selectrow_hashref($query);
my $var = $res->{'nom'};


print $q->start_div({'class' => 'container'}), $q->start_table({'class' => 'great_table center technical'}),
	$q->start_Tr(),
		$q->th({'class' => 'left_general'}, 'Number of rs ids...'),
		$q->th({'class' => 'left_general'}, 'dbSNP 137'),
		$q->th({'class' => 'left_general'}, 'dbSNP 142'),
	$q->end_th(),
	$q->start_Tr(),
		$q->td('...total for our 121 regions'),
		$q->td('275732'),
		$q->td($rs),
	$q->end_Tr(),
	$q->start_Tr(),
		$q->td('...total common (MAF > 1%)'),
		$q->td('59017'),
		$q->td($rs_com),
	$q->end_Tr(),
	$q->start_Tr(),
		$q->td('...concerning our variants'),
		$q->td("6668 (".sprintf('%.1f', (6668/$var)*100)."%)"),
		$q->td("$rs_our (".sprintf('%.1f', ($rs_our/$var)*100)."%)"),
	$q->end_Tr(),
	$q->start_Tr(),
		$q->td('...common concerning our variants'),
		$q->td('?*'),
		$q->td("$rs_our_com (".sprintf('%.1f', ($rs_our_com/$var)*100)."%)"),
	$q->end_Tr(),
	$q->start_Tr(),
		$q->td('total variants in U2'),
		$q->td({'colspan' => '2'}, $var),
	$q->end_Tr(),
	$q->end_table(), $q->br(), $q->span('*(forgot to count)'), $q->end_div(), $q->br(), "\n<canvas class=\"ambitious\" width = \"1500\" height = \"500\" id=\"dbSNP142_U2\">Change web browser for a more recent please!</canvas>";


#$q->span('Concerning the 121 genes of interest at this date, we had 275,732 variants annotated (6,668 of our variants). ') It includes 537,241 annotated variants (69,514 common, and 7,317 of our variants) in our same 121 genes of interest.'), $q->p('Below is a graph representing the number of SNP IDs per gene locus:'), $q->br(), $q->br(), "\n<canvas class=\"ambitious\" width = \"1500\" height = \"500\" id=\"dbSNP142_U2\">Change web browser for a more recent please!</canvas>";

my %data = (
	"NG_007083.1" => "22678",
	"NG_007882.1" => "658",
	"NG_008116.1" => "878",
	"NG_008126.1" => "2032",
	"NG_008139.1" => "2370",
	"NG_008211.2" => "1020",
	"NG_008213.1" => "11612",
	"NG_008309.1" => "501",
	"NG_008323.1" => "901",
	"NG_008358.1" => "617",
	"NG_008407.1" => "374",
	"NG_008472.1" => "1247",
	"NG_008483.1" => "8033",
	"NG_008489.1" => "2743",
	"NG_008835.1" => "18616",
	"NG_008994.1" => "3108",
	"NG_009033.1" => "1080",
	"NG_009073.1" => "6574",
	"NG_009077.1" => "930",
	"NG_009086.1" => "4701",
	"NG_009093.1" => "1232",
	"NG_009102.1" => "3943",
	"NG_009106.1" => "945",
	"NG_009107.1" => "644",
	"NG_009110.1" => "567",
	"NG_009113.1" => "706",
	"NG_009115.1" => "631",
	"NG_009116.1" => "2001",
	"NG_009168.1" => "2160",
	"NG_009191.1" => "43128",
	"NG_009193.1" => "3127",
	"NG_009497.1" => "32658",
	"NG_009553.1" => "1242",
	"NG_009834.1" => "652",
	"NG_009839.1" => "2996",
	"NG_009840.1" => "933",
	"NG_009874.1" => "2568",
	"NG_009934.1" => "6620",
	"NG_009936.2" => "151",
	"NG_009937.1" => "5286",
	"NG_011433.1" => "869",
	"NG_011589.1" => "1609",
	"NG_011593.1" => "3050",
	"NG_011594.1" => "4055",
	"NG_011595.1" => "771",
	"NG_011596.1" => "11220",
	"NG_011607.1" => "5416",
	"NG_011610.1" => "1858",
	"NG_011628.1" => "662",
	"NG_011629.1" => "1754",
	"NG_011633.1" => "3953",
	"NG_011634.1" => "3270",
	"NG_011635.1" => "11543",
	"NG_011636.1" => "753",
	"NG_011645.1" => "5125",
	"NG_011696.1" => "5285",
	"NG_011697.1" => "375",
	"NG_011700.1" => "2760",
	"NG_011777.1" => "5320",
	"NG_011883.1" => "2701",
	"NG_011884.1" => "5295",
	"NG_011885.1" => "383",
	"NG_011971.1" => "7481",
	"NG_012068.1" => "507",
	"NG_012104.1" => "1214",
	"NG_012149.1" => "645",
	"NG_012184.1" => "1056",
	"NG_012186.1" => "750",
	"NG_012278.1" => "5764",
	"NG_012857.1" => "4111",
	"NG_012973.1" => "2813",
	"NG_015866.1" => "2019",
	"NG_016274.1" => "2742",
	"NG_016342.1" => "5918",
	"NG_016351.1" => "4393",
	"NG_016411.1" => "1404",
	"NG_016646.1" => "7622",
	"NG_016700.1" => "4750",
	"NG_016702.1" => "1062",
	"NG_017201.1" => "1214",
	"NG_021175.1" => "2756",
	"NG_021178.1" => "5084",
	"NG_021183.1" => "2379",
	"NG_021423.1" => "1442",
	"NG_021427.1" => "1013",
	"NG_023044.1" => "3037",
	"NG_023055.1" => "3890",
	"NG_023385.1" => "537",
	"NG_023441.1" => "6789",
	"NG_023443.1" => "81607",
	"NG_027692.1" => "1350",
	"NG_027718.1" => "6036",
	"NG_027801.1" => "744",
	"NG_028030.1" => "1387",
	"NG_028108.1" => "2145",
	"NG_028125.1" => "1488",
	"NG_028131.1" => "2109",
	"NG_028170.1" => "1701",
	"NG_028219.1" => "529",
	"NG_028284.1" => "3758",
	"NG_028987.1" => "3234",
	"NG_029459.1" => "1273",
	"NG_029718.1" => "805",
	"NG_029786.1" => "1580",
	"NG_030040.1" => "3228",
	"NG_031870.1" => "1593",
	"NG_031916.1" => "730",
	"NG_031943.1" => "735",
	"NG_031965.1" => "8056",
	"NG_032158.1" => "1002",
	"NG_032692.2" => "835",
	"NG_032693.1" => "17327",
	"NG_032804.1" => "1255",
	"NG_032982.1" => "508",
	"NG_033006.1" => "1329",
	"NG_033008.1" => "6712",
	"NG_033191.1" => "4580",
	"NG_034052.1" => "9131",
	"NG_034161.1" => "860",
	"NG_034198.1" => "6332"
);


my %transformed;
#my $query;
foreach my $ng (keys(%data)) {
	$query = "SELECT nom[1] as nom FROM gene WHERE acc_g = '$ng';";
	my $res = $dbh->selectrow_hashref($query);
	$transformed{$res->{'nom'}} = $data{$ng};	
}

my ($data, $labels);

foreach my $gene (sort keys(%transformed)) {
	#($data, $labels) .= ("'$transformed{$gene}', ", "'$gene', ");
	$data .= "'$transformed{$gene}', ";
	$labels .= "'$gene', ";
}


chop($data);
chop($labels);

my $js = U2_modules::U2_subs_2::get_js_graph($labels, $data, '151,187,205', 'dbSNP142_U2');


print $q->script({'type' => 'text/javascript'}, $js);


##Basic end of USHVaM 2 perl scripts:

U2_modules::U2_subs_1::standard_end_html($q);

print $q->end_html();

exit();

##End of Basic end



