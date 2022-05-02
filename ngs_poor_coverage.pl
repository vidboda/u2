BEGIN {delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV', 'PATH'};}

use strict;
#use CGI;
#use DBI;
#use AppConfig qw(:expand :argcount);
use U2_modules::U2_users_1;
use U2_modules::U2_init_1;
use U2_modules::U2_subs_1;
use U2_modules::U2_subs_2;
use U2_modules::U2_subs_3;

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


##Basic init of USHVaM 2 perl scripts
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

my $ABSOLUTE_HTDOCS_PATH = $config->ABSOLUTE_HTDOCS_PATH();
my $RS_BASE_DIR = $config->RS_BASE_DIR();
my $CLINICAL_EXOME_SHORT_BASE_DIR = $config->CLINICAL_EXOME_SHORT_BASE_DIR();
my $CLINICAL_EXOME_BASE_DIR = $config->CLINICAL_EXOME_BASE_DIR();
my $CLINICAL_EXOME_ANALYSES = $config->CLINICAL_EXOME_ANALYSES();
my $SSH_RACKSTATION_FTP_BASE_DIR = $config->SSH_RACKSTATION_FTP_BASE_DIR();
my $SSH_RACKSTATION_MINISEQ_FTP_BASE_DIR = $config->SSH_RACKSTATION_MINISEQ_FTP_BASE_DIR();
#my $REF_GENE_URI = $config->REF_GENE_URI();

my @styles = ($CSS_PATH.'font-awesome.min.css', $CSS_PATH.'w3.css', $CSS_DEFAULT, $CSS_PATH.'fullsize/fullsize.css', $CSS_PATH.'jquery.alerts.css', $CSS_PATH.'datatables.min.css', $CSS_PATH.'jquery-ui-1.12.1.min.css');
#$CSS_PATH.'igv-1.0.5.css',
my $q = new CGI;

my $dbh = DBI->connect(    "DBI:Pg:database=$DB;host=$HOST;",
                        $DB_USER,
                        $DB_PASSWORD,
                        {'RaiseError' => 1}
                ) or die $DBI::errstr;



print $q->header(-type => 'text/html', -'cache-control' => 'no-cache'),
	$q->start_html(-title=>"NGS poor coverage",
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
				-src => $JS_PATH.'datatables.min.js', 'defer' => 'defer'},
                                {-language => 'javascript',
                                -src => $JS_PATH.'jquery.autocomplete.min.js', 'defer' => 'defer'},
				{-language => 'javascript',
				-src => $JS_PATH.'jquery-ui-1.12.1.min.js', 'defer' => 'defer'},
				#{-language => 'javascript',
				#-src => $JS_PATH.'igv-1.0.5.min.js', 'defer' => 'defer'},
				{-language => 'javascript',
				-src => 'https://cdn.jsdelivr.net/npm/igv@2.10.0/dist/igv.min.js', 'defer' => 'defer'},
                                {-language => 'javascript',
                                -src => $JS_DEFAULT}],
                        -encoding => 'ISO-8859-1', 'defer' => 'defer');

my $user = U2_modules::U2_users_1->new();


U2_modules::U2_subs_1::standard_begin_html($q, $user->getName(), $dbh);

##end of Basic init

#hg38 transition variable for postgresql 'start_g' segment field
my ($postgre_start_g, $postgre_end_g) = ('start_g', 'end_g');  #hg19 style

#we get a sample as param
my ($id, $number) = U2_modules::U2_subs_1::sample2idnum(uc($q->param('sample')), $q);

my $run_id = U2_modules::U2_subs_1::check_illumina_run_id($q);
my ($interval, $poor_coverage_absolute_path, $nenufaar_ana, $nenufaar_id, $ali_path, $index_ext, $file_type, $file_ext);
if ($q->param('type') && $q->param('type') eq 'ce') {
	#1st get poor coverage file
	($nenufaar_ana, $nenufaar_id) = U2_modules::U2_subs_3::get_nenufaar_id("$ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/data/$CLINICAL_EXOME_BASE_DIR/$run_id");
	$poor_coverage_absolute_path = "$ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/data/$CLINICAL_EXOME_BASE_DIR/$run_id/$id$number/$nenufaar_id/".$id.$number."_poor_coverage.txt";
	$ali_path = "$RS_BASE_DIR/data/$CLINICAL_EXOME_BASE_DIR/$run_id/$id$number/$nenufaar_id/".$id.$number;
	#create roi hash
	$interval = U2_modules::U2_subs_3::build_roi($dbh);
}
elsif ($q->param('type') && $q->param('type') =~ /(MiSeq-\d+)/o) {
	#1st get poor coverage file
	#MiSeq
	my $nenufaar_ana_tmp = $1;
	# look for mobidl analysis
	if (-e "$ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR$SSH_RACKSTATION_FTP_BASE_DIR/$run_id/MobiDL/$id$number/panelCapture/coverage/".$id.$number."_poor_coverage.tsv") {
        # print STDERR "MobiDL\n";
		$poor_coverage_absolute_path = "$ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR$SSH_RACKSTATION_FTP_BASE_DIR/$run_id/MobiDL/$id$number/panelCapture/coverage/".$id.$number."_poor_coverage.tsv";
		$ali_path = "$RS_BASE_DIR$SSH_RACKSTATION_FTP_BASE_DIR/$run_id/MobiDL/$id$number/panelCapture/".$id.$number;
    }
	else { # get nenufaar analysis
		($nenufaar_ana, $nenufaar_id) = U2_modules::U2_subs_3::get_nenufaar_id("$ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR$SSH_RACKSTATION_FTP_BASE_DIR/$run_id/nenufaar/$run_id");
		$poor_coverage_absolute_path = "$ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR$SSH_RACKSTATION_FTP_BASE_DIR/$run_id/nenufaar/$run_id/$id$number/$nenufaar_id/".$id.$number."_poor_coverage.txt";
		$ali_path = "$RS_BASE_DIR$SSH_RACKSTATION_FTP_BASE_DIR/$run_id/nenufaar/$run_id/$id$number/$nenufaar_id/".$id.$number;
	}
	$nenufaar_ana = $nenufaar_ana_tmp;
}
elsif ($q->param('type') && $q->param('type') =~ /(MiniSeq-\d+)/o) {
	#1st get poor coverage file
	#MiniSeq
	my $nenufaar_ana_tmp = $1;
	# look for mobidl analysis
	if (-e "$ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR$SSH_RACKSTATION_MINISEQ_FTP_BASE_DIR/$run_id/MobiDL/$id$number/panelCapture/coverage/".$id.$number."_poor_coverage.tsv") {
        # print STDERR "MobiDL\n";
		$poor_coverage_absolute_path = "$ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR$SSH_RACKSTATION_MINISEQ_FTP_BASE_DIR/$run_id/MobiDL/$id$number/panelCapture/coverage/".$id.$number."_poor_coverage.tsv";
		$ali_path = "$RS_BASE_DIR$SSH_RACKSTATION_MINISEQ_FTP_BASE_DIR/$run_id/MobiDL/$id$number/panelCapture/".$id.$number;
    }
    else { # get nenufaar analysis
		($nenufaar_ana, $nenufaar_id) = U2_modules::U2_subs_3::get_nenufaar_id("$ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR$SSH_RACKSTATION_MINISEQ_FTP_BASE_DIR/$run_id/nenufaar/$run_id");
		$poor_coverage_absolute_path = "$ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR$SSH_RACKSTATION_MINISEQ_FTP_BASE_DIR/$run_id/nenufaar/$run_id/$id$number/$nenufaar_id/".$id.$number."_poor_coverage.txt";
		$ali_path = "$RS_BASE_DIR$SSH_RACKSTATION_MINISEQ_FTP_BASE_DIR/$run_id/nenufaar/$run_id/$id$number/$nenufaar_id/".$id.$number;
	}
	$nenufaar_ana = $nenufaar_ana_tmp;
}
else {
	U2_modules::U2_subs_1::standard_error ('16', $q);
}


if (-e "$ABSOLUTE_HTDOCS_PATH$ali_path.bam") {
	$index_ext = '.bai';
	$file_type = 'bam';
	$file_ext = '.bam'
}
elsif (-e "$ABSOLUTE_HTDOCS_PATH$ali_path.crumble.cram") {
	$index_ext = '.crumble.cram.crai';
	$file_type = 'cram';
	$file_ext = '.crumble.cram'
}
elsif (-e "$ABSOLUTE_HTDOCS_PATH$ali_path.cram") {
	$index_ext = '.cram.crai';
	$file_type = 'cram';
	$file_ext = '.cram'
}


my $text = $q->span('You will find below a table ranking all ').
			$q->strong('genomic regions').
			$q->span(" poorly covered during the $nenufaar_ana NGS experiment for $id$number.").
			$q->br().$q->span('Click on a blue square to load the region in IGV.');
print U2_modules::U2_subs_2::info_panel($text, $q);

print $q->start_div({'class' => 'w3-container'}), $q->start_table({'class' => 'technical great_table', 'id' => 'gene_table'}), $q->caption("Poorly covered regions table:"), $q->start_thead(),
			$q->start_Tr(), "\n",
				$q->th({'class' => 'left_general'}, 'Chr'), "\n",
				$q->th({'class' => 'left_general'}, 'Start'), "\n",
				$q->th({'class' => 'left_general'}, 'End'), "\n",
				$q->th({'class' => 'left_general'}, 'Region'), "\n",
				$q->th({'class' => 'left_general'}, 'Size (bp)'), "\n",
				$q->th({'class' => 'left_general'}, 'Type'), "\n",
				$q->th({'class' => 'left_general'}, 'UCSC link'), "\n",
				$q->end_Tr(), $q->end_thead(), $q->start_tbody(), "\n";

open F, $poor_coverage_absolute_path or die $poor_coverage_absolute_path, $!;

my $igv_padding = 0;

while (<F>) {
	if ($_ !~ /^#/o) {
		#print "$_<br/>";
		my @line = split(/\t/);
		my ($region, $size);
		#$line[0] =~ /chr([\dXY]{1,2})/o;
		$line[0] =~ /chr($U2_modules::U2_subs_1::CHR_REGEXP)/o;
		my $u2_chr = $1;
		if ($q->param('type') eq 'ce') {
			my $interest = 0;
			foreach my $key (keys %{$interval}) {
				$key =~ /(\d+)-(\d+)/o;
				if ($line[1] >= $1 && $line[2] <= $2) {#good interval, check good chr
					if ($line[0] eq "chr$interval->{$key}") {
						$interest = 1;
						#$line[0] = /chr([\dXY]{1,2})/o;
						last;
					}
				}
			}
			if ($interest == 0) {next}
		}
		my $query = "SELECT a.nom_gene, a.type, a.numero, a.nom FROM segment a, gene b WHERE a.nom_gene = b.nom AND b.chr = '$u2_chr' AND b.main = 't' AND (($line[1] BETWEEN SYMMETRIC $postgre_start_g AND $postgre_end_g) OR ($line[2] BETWEEN SYMMETRIC $postgre_start_g AND $postgre_end_g));";
		my $sth = $dbh->prepare($query);
		my $res = $sth->execute();
		my ($gene, $nm, @type, @nom);
		if ($res ne '0E0') {
			while (my $result = $sth->fetchrow_hashref()) {
				($gene, $nm) = ($result->{'nom_gene'}[0], $result->{'nom_gene'}[1]);
				if ($#type > 0 && ($result->{'nom'} eq $nom[0] && $result->{'type'} eq $type[0])) {last}
				push @type, $result->{'type'};
				if ($result->{'nom'} !~ /UTR/o) {push @nom, $result->{'nom'}}
				else {push @nom, ''}

			}
		}
		else {
			$query = "SELECT a.nom_gene, a.type, a.numero, a.nom FROM segment a, gene b WHERE a.nom_gene = b.nom AND b.chr = '$u2_chr' AND b.main = 'f' AND (($line[1] BETWEEN SYMMETRIC $postgre_start_g AND $postgre_end_g) OR ($line[2] BETWEEN SYMMETRIC $postgre_start_g AND $postgre_end_g));";
			$sth = $dbh->prepare($query);
			$res = $sth->execute();
			while (my $result = $sth->fetchrow_hashref()) {
				($gene, $nm) = ($result->{'nom_gene'}[0], $result->{'nom_gene'}[1]);
				if ($#type > 0 && ($result->{'nom'} eq $nom[0] && $result->{'type'} eq $type[0])) {last}
				push @type, $result->{'type'};
				if ($result->{'nom'} !~ /UTR/o) {push @nom, $result->{'nom'}}
				else {push @nom, ''}
				if ($#type > 1) {last}
			}
		}
		$region = "$gene:$nm:".shift(@type)." ".shift(@nom)." - ".shift(@type)." ".shift(@nom);
		$size = $q->button({'onclick' => "igv.browser.search('$line[0]:".($line[1]-$igv_padding)."-".($line[2]+$igv_padding)."')", 'class' => 'pointer', 'title' => 'Click to see in IGV track', 'value' => $line[4], 'class' => 'w3-button w3-blue w3-padding-small w3-tiny'});
		#}
		#else {
		#	$region = $line[3];
		#}
		print $q->start_Tr(), "\n",
				$q->td($line[0]), "\n",
				$q->td($line[1]), "\n",
				$q->td($line[2]), "\n",
				$q->td($region), "\n",
				$q->start_td(), $size, $q->end_td(), "\n",
				$q->td($line[5]), "\n",
				$q->start_td(), $q->a({'href' => "$line[6]", 'target' => '_blank'}, 'UCSC'), $q->end_td(), "\n",
				$q->end_Tr();
		#print "$line[6]<br/>";
	}
}
close F;
print $q->end_tbody(), $q->end_table(), $q->end_div(), $q->br(), $q->br();

my $igv_script = '
$(document).ready(function () {
	var div = $("#igv_div"),
	options = {
	    showNavigation: true,
	    showRuler: true,
	    genome: "hg19",
	    tracks: [
			{
				name: "'.$id.$number.' '.$nenufaar_ana.' '.$file_type.' file",
				type: "alignment",
				sourceType: "file",
				format: "'.$file_type.'",
				url: "'.$HTDOCS_PATH.$ali_path.$file_ext.'",
				indexURL: "'.$HTDOCS_PATH.$ali_path.$index_ext.'",
			}
	    ]
	};

	//igv.createBrowser(div, options);
	igv.createBrowser(div, options).
		then(function (browser) {
			igv.browser = browser;
		});
    });
';
print $q->div({'id' => 'igv_div', 'class' => 'container', 'style' => 'padding:5px; border:1px solid lightgray'}), $q->script({'type' => 'text/javascript'}, $igv_script);


#{
#		    name: "Genes",
#		    type: "annotation",
#		    format: "bed",
#		    sourceType: "file",
#		    url: "'.$REF_GENE_URI.'",
#		    indexURL: "'.$REF_GENE_URI.'.tbi",
#		    order: Number.MAX_VALUE,
#		    visibilityWindow: 300000000,
#		    displayMode: "EXPANDED"
#		},
#my $interest = 0;
#foreach my $key (keys %{$intervals}) {
#	$key =~ /(\d+)-(\d+)/o;
#	if ($var_pos >= $1 && $var_pos <= $2) {#good interval, check good chr
#		if ($var_chr eq $intervals->{$key}) {$interest = 1;last;}
#	}
#}





##Basic end of USHVaM 2 perl scripts:

U2_modules::U2_subs_1::standard_end_html($q);

print $q->end_html();

exit();

##End of Basic end
