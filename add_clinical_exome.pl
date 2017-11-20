BEGIN {delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV', 'PATH'};}

use strict;
#use CGI; #in startup.pl
#use DBI;
#use AppConfig qw(:expand :argcount);
use URI::Encode qw(uri_encode uri_decode);
use Net::OpenSSH;
use U2_modules::U2_users_1;
use U2_modules::U2_init_1;
use U2_modules::U2_subs_1;
#use U2_modules::U2_subs_2;

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
#
#	The script creates an HTML5 canvas to draw each exon/intron/UTR of each gene + different exons/introns/UTRs in alternative isoforms
#	In adition it creates an image map superposed on the canvas which creates squares of 50*50 px which can be clicked to get
#	a JqueryUI modal popup which includes a specific form built using AJAX
#	This script is also used to create a form and check feaseability of Illumina data import. This form will launch the Illumina_import script.

##MODIFIED init of USHVaM 2 perl scripts: INCLUDES JqueryUI, CSS for forms AND JS SCRIPT FOR POPUP WINDOW TO ADD A VARIANT TO AN ANALYSIS
##MODIFIED also calls ssh parameters for remote login to RackStation
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
my $PATIENT_IDS = $config->PATIENT_IDS();

#specific args for browsing RS
my $ABSOLUTE_HTDOCS_PATH = $config->ABSOLUTE_HTDOCS_PATH();
my $RS_BASE_DIR  = $config->RS_BASE_DIR();
my $CLINICAL_EXOME_BASE_DIR = $config->CLINICAL_EXOME_BASE_DIR();
my $CLINICAL_EXOME_METRICS_SOURCES = $config->CLINICAL_EXOME_METRICS_SOURCES();

#end

my @styles = ($CSS_PATH.'w3.css', $CSS_DEFAULT, $CSS_PATH.'form.css');

my $q = new CGI;

my $dbh = DBI->connect(    "DBI:Pg:database=$DB;host=$HOST;",
                        $DB_USER,
                        $DB_PASSWORD,
                        {'RaiseError' => 1}
                ) or die $DBI::errstr;



print $q->header(-type => 'text/html', -'cache-control' => 'no-cache'),
	$q->start_html(
		-title=>"U2 Analysis wizard",
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
                        -src => $JS_PATH.'jquery.autocomplete.min.js', 'defer' => 'defer'},
                        {-language => 'javascript',
                        -src => $JS_DEFAULT, 'defer' => 'defer'}],		
                -encoding => 'ISO-8859-1');

my $user = U2_modules::U2_users_1->new();


U2_modules::U2_subs_1::standard_begin_html($q, $user->getName());

##end of MODIFIED init


### core script which will be used to add new clinical exomes


if ($user->isAnalyst() == 1) {
	my ($id, $number) = U2_modules::U2_subs_1::sample2idnum(uc($q->param('sample')), $q);
	
	my $step = U2_modules::U2_subs_1::check_step($q);
	#step 2 => form with possible samples to import per run
	if ($step == 2) {
		my @run_list = `find $ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/data/$CLINICAL_EXOME_BASE_DIR -maxdepth 1 -type d -exec basename '{}' \\; | grep -E '^[0-9]{6}_.*'`;
		#print $q->p($run_list[0]);
		foreach my $run (@run_list) {
			chomp($run);
			my @samples = `find $ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/data/$CLINICAL_EXOME_BASE_DIR/$run -maxdepth 1 -type d -exec basename '{}' \\; | grep -E '^[SR]U?.*'`;
			if (grep(/$id$number/, @samples)) {
				#we've got a match
				#print $q->p("$run/$id$number")
				#build forms to porpose import
				
			}
		}
	}
	#step 3 => actual import
	
	#to do in part 3
				#get log's number
				#my $nenufaar_log = `ls $ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/data/$CLINICAL_EXOME_BASE_DIR/$run/*.log | xargs basename`;
				#$nenufaar_log =~ /_(\d+).log/og;
				#my $nenufaar_id = $1;
				#my $data_path = "$ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/data/$CLINICAL_EXOME_BASE_DIR/$run/$id$number/$nenufaar_id/";
				#print `ls $data_path`;		
	
}
else {U2_modules::U2_subs_1::standard_error('13', $q)}

##Basic end of USHVaM 2 perl scripts:

U2_modules::U2_subs_1::standard_end_html($q);

print $q->end_html();

exit();

##End of Basic end


##specific subs for current script