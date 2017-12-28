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

my @styles = ($CSS_PATH.'font-awesome.min.css', $CSS_PATH.'w3.css', $CSS_DEFAULT, $CSS_PATH.'fullsize/fullsize.css', $CSS_PATH.'jquery.alerts.css', $CSS_PATH.'datatables.min.css');

my $q = new CGI;

my $dbh = DBI->connect(    "DBI:Pg:database=$DB;host=$HOST;",
                        $DB_USER,
                        $DB_PASSWORD,
                        {'RaiseError' => 1}
                ) or die $DBI::errstr;


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
                                -src => $JS_PATH.'Chart.min.js', 'defer' => 'defer'},
				{-language => 'javascript',
				-src => $JS_PATH.'jquery.alerts.js', 'defer' => 'defer'},
				{-language => 'javascript',
				-src => $JS_PATH.'timeline/js/storyjs-embed.js', 'defer' => 'defer'},
                                {-language => 'javascript',
                                -src => $JS_PATH.'jquery.autocomplete.min.js', 'defer' => 'defer'},
                                {-language => 'javascript',
                                -src => $JS_DEFAULT, 'defer' => 'defer'}],		
                        -encoding => 'ISO-8859-1');

my $user = U2_modules::U2_users_1->new();


U2_modules::U2_subs_1::standard_begin_html($q, $user->getName(), $dbh);

##end of Basic init

my $ANALYSIS_ILLUMINA_PG_REGEXP = $config->ANALYSIS_ILLUMINA_PG_REGEXP();
#1st specific page with mean values for a run

if ($q->param('run') && $q->param('run') =~ /([\w-]+)/o){
	my $run_id = $1;
	my $current_tab = 'ontarget_percent_';
	if ($q->param('current') && $q->param('current') =~ /(\w+)/o) {$current_tab = $1}
	#current tab for clusters
	if ($current_tab =~ /clusters/o) {$current_tab = 'clusters_'}
	
	print $q->start_div(), $q->start_p({'class' => 'center'}), $q->start_big();
	
	if ($run_id eq 'global') {print $q->strong('Statistics for all Illumina runs:')}
	else {print $q->strong("Statistics for run $run_id:")}
	
	my $js = "
		function change_tab(name)	{
			if (\$('#'+name+'tab').attr('class') !== \$('#'+current_tab).attr('class')) {
			
				\$('#'+current_tab).attr('class', 'tab tab_other');
				\$('#'+name+'tab').attr('class', 'tab tab_current');
				
				//\$('#'+name+'tab_content').css('display','block');
				//\$('#'+current_tab+'_content').css('display','none');
				
				\$('#'+name+'tab_content').show('slow');
				\$('#'+current_tab+'_content').hide('slow');
				
				current_tab = name+'tab';
				//changes a tags in page with current tab
				\$(\"[href*='current=']\").attr(\"href\", function(i,v){
					regurl = /current=\\w+\$/g;
					//alert(regurl);
					return v.replace(regurl, \"current=\"+name);
					//return v.replace('current=', name);
				});
				//changes current url
				//var re = new RegExp(\"run=[^&]+\");
				//var m = re.exec(\$(location).attr('href'));
				//alert(m);
				//if (m !== null) {\$(location).attr('href', 'https://194.167.35.158/perl/U2/stats_ngs.pl?'+m+'&current='+name);}
				//alert(\$(location).attr('href'));
				//var data = 'data'+name+'tab';
				// Get context with jQuery - using jQuery's .get() method.
				//Chart.defaults.global.responsive = true; //wether or not the chart should be responsive and resize when the browser does.
				//var ctx = \$(\"#canvas_graph\").get(0).getContext(\"2d\");\n
				//
				//var chart = new Chart(ctx).Bar(data, {
				//	scaleBeginAtZero: false
				//});
			}
		}
	\n";
	
	print "\n", $q->script({'type' => 'text/javascript', 'defer' => 'defer'}, $js), "\n";
	
	
	my ($labels, $full_id, $analysis_type) = &get_labels($run_id);
	my (@tags, $label_txt);
	if ($run_id eq 'global') {
		@tags = split(',', $full_id);		
		$label_txt = ' runs - '.&get_total_samples().')'		
	}
	else {@tags = split(',', $labels);$label_txt = ' samples)';}
	### $tags+1 = number of data points
	my $width = '800'; ## default width
	if ($#tags+1 < 8) {$width = '400'}
	elsif ($#tags+1 > 100) {$width = '2400'}
	elsif ($#tags+1 > 80) {$width = '2000'}
	elsif ($#tags+1 > 50) {$width = '1600'}
	elsif ($#tags+1 > 30) {$width = '1200'}
	
	
	
	print $q->span('('.($#tags+1).$label_txt), $q->end_big(), $q->end_p(), "\n",
		$q->start_div(), "\n",
			$q->start_div(), "\n", #tabs for graphs: spans are tab, divs under are tab-content, a js function shows/hides elements, adapted from http://www.supportduweb.com/scripts_tutoriaux-code-source-48-systeme-d-039-onglets-en-javascript-x-html-et-css-dans-la-meme-page.html
				$q->span({'class' => 'tab tab_other', 'id' => 'ontarget_percent_tab', 'onclick' => 'change_tab(\'ontarget_percent_\');'}, 'On target %'), "\n",
				$q->span({'class' => 'tab tab_other', 'id' => 'ontarget_reads_tab', 'onclick' => 'change_tab(\'ontarget_reads_\');'}, 'On target reads'), "\n",
				$q->span({'class' => 'tab tab_other', 'id' => 'duplicate_reads_tab', 'onclick' => 'change_tab(\'duplicate_reads_\');'}, 'Duplicate reads'), "\n",
				$q->span({'class' => 'tab tab_other', 'id' => 'mean_doc_tab', 'onclick' => 'change_tab(\'mean_doc_\');'}, 'Mean DOC'), "\n",
				$q->span({'class' => 'tab tab_other', 'id' => 'fiftyx_doc_tab', 'onclick' => 'change_tab(\'fiftyx_doc_\');'}, '50X %'), "\n",
				$q->span({'class' => 'tab tab_other', 'id' => 'snv_number_tab', 'onclick' => 'change_tab(\'snv_number_\');'}, 'SNVs'), "\n",
				$q->span({'class' => 'tab tab_other', 'id' => 'snv_tstv_tab', 'onclick' => 'change_tab(\'snv_tstv_\');'}, 'SNVs Ts/Tv'), "\n",
				$q->span({'class' => 'tab tab_other', 'id' => 'indel_number_tab', 'onclick' => 'change_tab(\'indel_number_\');'}, 'Indels'), "\n",
				$q->span({'class' => 'tab tab_other', 'id' => 'insert_size_tab', 'onclick' => 'change_tab(\'insert_size_\');'}, 'Insert size'), "\n",
				$q->span({'class' => 'tab tab_other', 'id' => 'insert_size_sd_tab', 'onclick' => 'change_tab(\'insert_size_sd_\');'}, 'Insert size SD'), "\n",
				$q->span({'class' => 'tab tab_other', 'id' => 'clusters_tab', 'onclick' => 'change_tab(\'clusters_\');'}, 'Raw Clusters'), "\n",;
	if ($run_id eq 'global') {
		print	$q->span({'class' => 'tab tab_other', 'id' => 'clusters_us_tab', 'onclick' => 'change_tab(\'clusters_us_\');'}, 'Usable Clusters'), "\n",
			$q->span({'class' => 'tab tab_other', 'id' => 'clusters_dup_tab', 'onclick' => 'change_tab(\'clusters_dup_\');'}, 'Duplicate Clusters'), "\n",
			$q->span({'class' => 'tab tab_other', 'id' => 'clusters_un_tab', 'onclick' => 'change_tab(\'clusters_un_\');'}, 'Unaligned Clusters'), "\n",
			$q->span({'class' => 'tab tab_other', 'id' => 'clusters_uni_tab', 'onclick' => 'change_tab(\'clusters_uni_\');'}, 'Unindexed Clusters'), "\n";
	}
	print	$q->end_div(), "\n",
			$q->start_div(), "\n", #tab contents				
				$q->start_div({'class' => 'tab_content', 'id' => 'ontarget_percent_tab_content'}), "\n", #ontarget %
					$q->big('Percentage of on target reads'), $q->br(), $q->br(), $q->span('Mean: '),
					$q->span(&get_data_mean($run_id, '(cast(ontarget_reads as float)/cast(aligned_reads as float))*100', '2', 'miseq_analysis')." %", 'on target'), $q->br(), $q->br(), "\n<canvas class=\"ambitious\" width = \"$width\" height = \"500\" id=\"ontarget_percent_tab_graph\">Change web browser for a more recent please!</canvas>";
	my $data = &get_data($run_id, '(cast(ontarget_reads as float)/cast(aligned_reads as float))*100', 'AVG', '2', 'no_cluster');
	$js = U2_modules::U2_subs_2::get_js_graph($labels, $data, '151,187,205', 'ontarget_percent_tab_graph');
	print 				$q->script({'type' => 'text/javascript'}, $js),	
				$q->end_div(), "\n",
				$q->start_div({'class' => 'tab_content', 'id' => 'ontarget_reads_tab_content'}), "\n", #ontarget reads
					$q->big('Number of reads that aligned to the target'), $q->br(), $q->br(), $q->span('Mean: '),
					$q->span(&get_data_mean($run_id, 'ontarget_reads', '0', 'miseq_analysis')." reads"), $q->br(), $q->br(), "\n<canvas class=\"ambitious\" width = \"$width\" height = \"500\" id=\"ontarget_reads_tab_graph\">Change web browser for a more recent please!</canvas>";
	$data = &get_data($run_id, 'ontarget_reads', 'SUM', '0', 'no_cluster');
	$js = U2_modules::U2_subs_2::get_js_graph($labels, $data, '88,42,114', 'ontarget_reads_tab_graph');
	print 				$q->script({'type' => 'text/javascript'}, $js),			
				$q->end_div(), "\n",
				$q->start_div({'class' => 'tab_content', 'id' => 'duplicate_reads_tab_content'}), "\n", #duplicate reads
					$q->big('Percentage of paired reads that have duplicates'), $q->br(), $q->br(), $q->span('Mean: '),
					$q->span(&get_data_mean($run_id, 'duplicates', '2', 'miseq_analysis')." %"), $q->br(), $q->br(), "\n<canvas class=\"ambitious\" width = \"$width\" height = \"500\" id=\"duplicate_reads_tab_graph\">Change web browser for a more recent please!</canvas>";
	$data = &get_data($run_id, 'duplicates', 'AVG', '2', 'no_cluster');
	$js = U2_modules::U2_subs_2::get_js_graph($labels, $data, '10,5,94', 'duplicate_reads_tab_graph');
	print 				$q->script({'type' => 'text/javascript'}, $js),	
				$q->end_div(), "\n",
				$q->start_div({'class' => 'tab_content', 'id' => 'mean_doc_tab_content'}), "\n", #mean DOC
					$q->big('Mean Depth Of Coverage'), $q->br(), $q->br(), $q->span('Mean: '),
					$q->span(&get_data_mean($run_id, 'mean_doc', '0', 'miseq_analysis')), $q->br(), $q->br(), "\n<canvas class=\"ambitious\" width = \"$width\" height = \"500\" id=\"mean_doc_tab_graph\">Change web browser for a more recent please!</canvas>";
	$data = &get_data($run_id, 'mean_doc', 'AVG', '0', 'no_cluster');
	$js = U2_modules::U2_subs_2::get_js_graph($labels, $data, '161,34,34', 'mean_doc_tab_graph');
	print 				$q->script({'type' => 'text/javascript'}, $js),	
				$q->end_div(), "\n",
				$q->start_div({'class' => 'tab_content', 'id' => 'fiftyx_doc_tab_content'}), "\n", #mean 50X coverage
					$q->big('Percentage of targets with coverage greater than 50X'), $q->br(), $q->br(), $q->span('Mean: '),
					$q->span(&get_data_mean($run_id, 'fiftyx_doc', '2', 'miseq_analysis')." %"), $q->br(), $q->br(), "\n<canvas class=\"ambitious\" width = \"$width\" height = \"500\" id=\"fiftyx_doc_tab_graph\">Change web browser for a more recent please!</canvas>";
	$data = &get_data($run_id, 'fiftyx_doc', 'AVG', '2', 'no_cluster');
	$js = U2_modules::U2_subs_2::get_js_graph($labels, $data, '220,126,0', 'fiftyx_doc_tab_graph');
	print 				$q->script({'type' => 'text/javascript'}, $js),	
				$q->end_div(), "\n",
				$q->start_div({'class' => 'tab_content', 'id' => 'snv_number_tab_content'}), "\n", #number of variants
					$q->big('Total number of SNVs present in the dataset and pass the quality filters'), $q->br(), $q->br(), $q->span('Mean: '),
					$q->span(&get_data_mean($run_id, 'snp_num', '0', 'miseq_analysis')), $q->br(), $q->br(), "\n<canvas class=\"ambitious\" width = \"$width\" height = \"500\" id=\"snv_number_tab_graph\">Change web browser for a more recent please!</canvas>";
	$data = &get_data($run_id, 'snp_num', 'AVG', '0', 'no_cluster');
	$js = U2_modules::U2_subs_2::get_js_graph($labels, $data, '170,146,55', 'snv_number_tab_graph');
	print 				$q->script({'type' => 'text/javascript'}, $js),	
				$q->end_div(), "\n",
				$q->start_div({'class' => 'tab_content', 'id' => 'snv_tstv_tab_content'}), "\n", #number of ts/tv
					$q->big('Transition rate of SNVs that pass the quality filters / Transversion rate of SNVs that pass the quality filter'), $q->br(), $q->br(), $q->span('Mean: '),
					$q->span(&get_data_mean($run_id, 'snp_tstv', '2', 'miseq_analysis')), $q->br(), $q->br(), "\n<canvas class=\"ambitious\" width = \"$width\" height = \"500\" id=\"snv_tstv_tab_graph\">Change web browser for a more recent please!</canvas>";
	$data = &get_data($run_id, 'snp_tstv', 'AVG', '2', 'no_cluster');
	$js = U2_modules::U2_subs_2::get_js_graph($labels, $data, '220,188,0', 'snv_tstv_tab_graph');
	print 				$q->script({'type' => 'text/javascript'}, $js),	
				$q->end_div(), "\n",
				$q->start_div({'class' => 'tab_content', 'id' => 'indel_number_tab_content'}), "\n", #number of indeks
					$q->big('Total number of indels present in the dataset that pass the quality filters'), $q->br(), $q->br(), $q->span('Mean: '),
					$q->span(&get_data_mean($run_id, 'indel_num', '0', 'miseq_analysis')), $q->br(), $q->br(), "\n<canvas class=\"ambitious\" width = \"$width\" height = \"500\" id=\"indel_number_tab_graph\">Change web browser for a more recent please!</canvas>";
	$data = &get_data($run_id, 'indel_num', 'AVG', '0', 'no_cluster');
	$js = U2_modules::U2_subs_2::get_js_graph($labels, $data, '76,194,0', 'indel_number_tab_graph');
	print 				$q->script({'type' => 'text/javascript'}, $js),	
				$q->end_div(), "\n",
				$q->start_div({'class' => 'tab_content', 'id' => 'insert_size_tab_content'}), "\n", #median insert size
					$q->big('Median length of the sequenced fragment'), $q->br(), $q->br(), $q->span('Mean: '),
					$q->span(&get_data_mean($run_id, 'insert_size_median', '0', 'miseq_analysis')), $q->br(), $q->br(), "\n<canvas class=\"ambitious\" width = \"$width\" height = \"500\" id=\"insert_size_tab_graph\">Change web browser for a more recent please!</canvas>";
	$data = &get_data($run_id, 'insert_size_median', 'AVG', '0', 'no_cluster');
	$js = U2_modules::U2_subs_2::get_js_graph($labels, $data, '38,113,88', 'insert_size_tab_graph');
	print 				$q->script({'type' => 'text/javascript'}, $js),	
				$q->end_div(), "\n",
				$q->start_div({'class' => 'tab_content', 'id' => 'insert_size_sd_tab_content'}), "\n", #insert size sd
					$q->big('Standard deviation of the lengths of the sequenced fragment'), $q->br(), $q->br(), $q->span('Mean: '),
					$q->span(&get_data_mean($run_id, 'insert_size_sd', '0', 'miseq_analysis')), $q->br(), $q->br(), "\n<canvas class=\"ambitious\" width = \"$width\" height = \"500\" id=\"insert_size_sd_tab_graph\">Change web browser for a more recent please!</canvas>";
	$data = &get_data($run_id, 'insert_size_sd', 'AVG', '0', 'no_cluster');
	$js = U2_modules::U2_subs_2::get_js_graph($labels, $data, '34,103,100', 'insert_size_sd_tab_graph');
	
	
	if ($run_id eq 'global') {
		### clusters data type
		print 				$q->script({'type' => 'text/javascript'}, $js),	
					$q->end_div(), "\n",
					$q->start_div({'class' => 'tab_content', 'id' => 'clusters_tab_content'}), "\n", #raw clusters
						$q->big('Raw number of Clusters'), $q->br(), $q->br(), $q->span('Mean: '),
						$q->span(&get_data_mean('global', 'noc_raw', '0', 'illumina_run')), $q->br(), $q->br(), "\n<canvas class=\"ambitious\" width = \"$width\" height = \"500\" id=\"clusters_tab_graph\">Change web browser for a more recent please!</canvas>";
		$data = &get_data('global', 'noc_raw', '', '0', 'cluster');
		$js = U2_modules::U2_subs_2::get_js_graph($labels, $data, '151,187,205', 'clusters_tab_graph');
		print 				$q->script({'type' => 'text/javascript'}, $js),	
					$q->end_div(), "\n",
					$q->start_div({'class' => 'tab_content', 'id' => 'clusters_us_tab_content'}), "\n", #usable clusters pf / raw clusters (usable = pf-dup-unaligned-unindexd/total)
						$q->big('Proportion of Usable Clusters (= (Clusters passing filter - (duplicates+unaligned+unindexed)) / total)*100)'), $q->br(), $q->br(), $q->span('Mean: '),
						$q->span(&get_data_mean('global', '((noc_pf-(nodc+nouc_pf+nouic_pf))::FLOAT/noc_raw)*100', '2', 'illumina_run')." %"), $q->br(), $q->br(), "\n<canvas class=\"ambitious\" width = \"$width\" height = \"500\" id=\"clusters_us_tab_graph\">Change web browser for a more recent please!</canvas>";
		$data = &get_data('global', '((noc_pf-(nodc+nouc_pf+nouic_pf))::FLOAT/noc_raw)*100', '', '0', 'cluster');
		$js = U2_modules::U2_subs_2::get_js_graph($labels, $data, '88,42,114', 'clusters_us_tab_graph');
		print 				$q->script({'type' => 'text/javascript'}, $js),	
					$q->end_div(), "\n",
					$q->start_div({'class' => 'tab_content', 'id' => 'clusters_dup_tab_content'}), "\n", #duplicates clusters / raw clusters
						$q->big('Proportion of Clusters having duplicates'), $q->br(), $q->br(), $q->span('Mean: '),
						$q->span(&get_data_mean('global', '(nodc::FLOAT/noc_raw)*100', '2', 'illumina_run')." %"), $q->br(), $q->br(), "\n<canvas class=\"ambitious\" width = \"$width\" height = \"500\" id=\"clusters_dup_tab_graph\">Change web browser for a more recent please!</canvas>";
		$data = &get_data('global', '(nodc::FLOAT/noc_raw)*100', '', '0', 'cluster');
		$js = U2_modules::U2_subs_2::get_js_graph($labels, $data, '10,5,94', 'clusters_dup_tab_graph');
		print 				$q->script({'type' => 'text/javascript'}, $js),	
					$q->end_div(), "\n",
					$q->start_div({'class' => 'tab_content', 'id' => 'clusters_un_tab_content'}), "\n", #unaligned clusters / raw clusters
						$q->big('Proportion of unaligned Clusters'), $q->br(), $q->br(), $q->span('Mean: '),
						$q->span(&get_data_mean('global', '(nouc::FLOAT/noc_raw)*100', '2', 'illumina_run')." %"), $q->br(), $q->br(), "\n<canvas class=\"ambitious\" width = \"$width\" height = \"500\" id=\"clusters_un_tab_graph\">Change web browser for a more recent please!</canvas>";
		$data = &get_data('global', '(nouc::FLOAT/noc_raw)*100', '', '0', 'cluster');
		$js = U2_modules::U2_subs_2::get_js_graph($labels, $data, '161,34,34', 'clusters_un_tab_graph');
		print 				$q->script({'type' => 'text/javascript'}, $js),	
					$q->end_div(), "\n",
					$q->start_div({'class' => 'tab_content', 'id' => 'clusters_uni_tab_content'}), "\n", #unindexed clusters / raw clusters
						$q->big('Proportion of unindexed Clusters'), $q->br(), $q->br(), $q->span('Mean: '),
						$q->span(&get_data_mean('global', '(nouic::FLOAT/noc_raw)*100', '2', 'illumina_run')." %"), $q->br(), $q->br(), "\n<canvas class=\"ambitious\" width = \"$width\" height = \"500\" id=\"clusters_uni_tab_graph\">Change web browser for a more recent please!</canvas>";
		$data = &get_data('global', '(nouic::FLOAT/noc_raw)*100', '', '0', 'cluster');
		$js = U2_modules::U2_subs_2::get_js_graph($labels, $data, '220,126,0', 'clusters_uni_tab_graph');
	}
	else {
		#clusters raw data for specific run
		print 				$q->script({'type' => 'text/javascript'}, $js),	
					$q->end_div(), "\n",
					$q->start_div({'class' => 'tab_content', 'id' => 'clusters_tab_content'}), "\n", #unindexed clusters / raw clusters
						$q->big('Clusters complete raw data'), $q->br(), $q->br(),
						$q->br(), $q->br(), "\n<canvas class=\"ambitious\" width = \"800\" height = \"500\" id=\"clusters_tab_graph\">Change web browser for a more recent please!</canvas>";
		$data = &get_data($run_id, 'noc_raw, noc_pf, nodc, nouc, nouc_pf, nouic, nouic_pf, (noc_pf-(nodc+nouc_pf+nouic_pf)) AS a', '', '0', 'cluster');
		my $label_c = '"Total Clusters", "Passing Filters (PF)", "Duplicates", "Unaligned", "Unaligned PF", "Unindexed", "Unindexed PF", "Usable Clusters"';
		$js = U2_modules::U2_subs_2::get_js_graph($label_c, $data, '151,187,205', 'clusters_tab_graph');
	}
	
	
	print 				$q->script({'type' => 'text/javascript'}, $js),	
				$q->end_div(), "\n",
			$q->end_div(), "\n";
			
	$js = "
	\n	var current_tab = '$current_tab';
	change_tab(current_tab);
	\n";
	print $q->script({'type' => 'text/javascript'}, $js), $q->end_div();
	
	$labels =~ s/"//og;
	
	if ($run_id eq 'global') {
		#my @tags = split(',', $full_id);		
		print $q->p('X-axis legend: date_reagent_genes with date being yymmdd.');
		print $q->br(), $q->br(), $q->p('Get stats for a particular run:'), $q->start_ul(), "\n";		
		foreach (@tags) {print $q->start_li(), $q->a({'href' => "stats_ngs.pl?run=$_&current=$current_tab", 'title' => "Get stats for run $_"}, $_), $q->end_li(), "\n"}
	}
	else {
		@tags = split(', ', $labels);  #resplit because of "" => needed by charts.js
		my $files = '['; #list of all coverage files of the run => need to know the run type and the sample IDs to build the urls
		print $q->br(), $q->br(), $q->p('List of Samples:'), $q->start_ul(), "\n";
		foreach (@tags) {
			print $q->start_li(), $q->a({'href' => "patient_file.pl?sample=$_", 'target' => '_blank', 'title' => 'Go to the patient\'s page'}, $_), $q->end_li(), "\n";
			$files .= "'https://194.167.35.158/ushvam2/data/ngs/$analysis_type/$_/$_.coverage.tsv',"
		}
		chop $files;
		$files .= ']';
		print $q->start_li(), $q->a({'href' => "stats_ngs.pl?run=global&current=$current_tab", 'title' => 'Get stats for all runs'}, 'global analysis'), $q->end_li(), "\n",
			$q->start_li(), $q->a({'href' => "search_controls.pl?iv=1&step=3&run=$run_id", 'title' => 'Get private SNPs for each sample'}, 'Sample tracking'), $q->end_li(), "\n",
			$q->start_li(), $q->a({'href' => '#', 'onclick' => "download_files($files);"},'Download all coverage files of the run'), $q->end_li(), "\n";
			#$q->start_li(), $q->a({'href' => "https://194.167.35.158/ushvam2/data/ngs/MiSeq-121/R582/R582.coverage.tsv.download"}, 'test2'), $q->end_li(), "\n";
	}
	print $q->end_ul(), "\n";	
}
else {
	my ($total_runs, $total_samples) = (&get_total_runs(), &get_total_samples());
	print $q->start_div(), $q->start_p({'class' => 'center'}), $q->start_big(), $q->strong("Illumina runs stats page: ($total_runs - $total_samples)"), $q->end_big(), $q->end_p(), "\n";
	#my $ul = $q->p('please click a run id below or click \'global\' for an overview of all runs.').$q->ul().$q->start_li().$q->a({'href' => 'stats_ngs.pl?run=global'}, 'global analysis').$q->end_li();#deprecated
	#, 'data-order' => '[[ 0, "desc" ]]' defined in js
	my $new_style = $q->start_div({'class' => 'container'}).$q->start_table({'class' => 'great_table technical', 'id' => 'illumina_runs_table'}).$q->start_caption().$q->span('Illumina runs table (').$q->a({'href' => 'stats_ngs.pl?run=global', 'target' => '_blank'}, 'See all runs analysis').$q->span('):').$q->start_thead().
		$q->start_Tr()."\n".
			$q->th({'class' => 'left_general'}, 'Run ID')."\n".
			$q->th({'class' => 'left_general'}, 'Analysis type')."\n".
			$q->th({'class' => 'left_general'}, 'Run number')."\n".
		$q->end_Tr().$q->end_thead().$q->start_tbody()."\n";
	
	my $query = 'SELECT DISTINCT(a.run_id), a.type_analyse, b.filtering_possibility FROM miseq_analysis a, valid_type_analyse b WHERE a.type_analyse = b.type_analyse ORDER BY a.type_analyse DESC, a.run_id;';
	my $dates = "\"date\": [
	";
	my ($i, $j, $k, $l, $m, $n, $o, $p, $r) = (0, 0, 0, 0, 0, 0, 0, 0, 0);
	my $sth = $dbh->prepare($query);
	my $res = $sth->execute();
	while (my $result = $sth->fetchrow_hashref()) {
		#timeline
		my $title = '';
		my $thumbnail = 'miseq_thumb.jpg';

		my $analysis_date = U2_modules::U2_subs_1::date_pg2tjs(U2_modules::U2_subs_1::get_run_date($result->{'run_id'}));
		my $text = "Run ID: <a href = 'stats_ngs.pl?run=$result->{'run_id'}' target = '_blank'>$result->{'run_id'}</a>";
		
		if ($result->{'type_analyse'} eq 'MiSeq-28') {$i++;$text .= "<br/>Run Number: $i";$title = "Run $i";}
		elsif ($result->{'type_analyse'} eq 'MiSeq-112') {$j++;$text .= "<br/>Run Number: $j";$title = "Run $j";}
		elsif ($result->{'type_analyse'} eq 'MiSeq-121') {$k++;$text .= "<br/>Run Number: $k";$title = "Run $k";}
		elsif ($result->{'type_analyse'} eq 'MiSeq-3') {$l++;$text .= "<br/>Run Number: $l";$title = "Run $l";}
		elsif ($result->{'type_analyse'} eq 'MiSeq-132') {$o++;$text .= "<br/>Run Number: $o";$title = "Run $o";}
		elsif ($result->{'type_analyse'} eq 'MiniSeq-121') {$m++;$text .= "<br/>Run Number: $m";$title = "Run $m";$thumbnail = 'miniseq_thumb.jpg';}
		elsif ($result->{'type_analyse'} eq 'MiniSeq-132') {$n++;$text .= "<br/>Run Number: $n";$title = "Run $n";$thumbnail = 'miniseq_thumb.jpg';}
		elsif ($result->{'type_analyse'} eq 'MiniSeq-3') {$p++;$text .= "<br/>Run Number: $p";$title = "Run $p";$thumbnail = 'miniseq_thumb.jpg';}
		elsif ($result->{'type_analyse'} eq 'NextSeq-ClinicalExome') {$r++;$text .= "<br/>Run Number: $r";$title = "Run $r";$thumbnail = 'nextseq_thumb.jpg';}
		$text .= "<br/><a href='search_controls.pl?step=3&iv=1&run=$result->{'run_id'}'>Sample tracking</a>";
		
		
		
		#my $text = "<br/>Analyst: ".ucfirst($result->{'analyste'})."<br/> Run: <a href = 'stats_ngs.pl?run=$result->{'run_id'}' target = '_blank'>$result->{'run_id'}</a>";
		$dates .= "			
			{
			    \"startDate\":\"$analysis_date\",
			    \"endDate\":\"$analysis_date\",
			    \"headline\":\"$result->{'type_analyse'} $title\",
			    //\"tag\":\"$result->{'type_analyse'}\",
			    \"text\":\"<p>$text</p>\",
			    \"asset\": {
				//\"media\":\"".$HTDOCS_PATH."data/img/$thumbnail\",
				\"thumbnail\":\"".$HTDOCS_PATH."data/img/$thumbnail\",
			    }
			},
		";	
		
		#text
		#my $subst = '6';
		#if ($result->{'type_analyse'} =~ /Mini/o) {$subst = '8'}
		
		$new_style .= $q->start_Tr().$q->start_td().$q->a({'href' => "stats_ngs.pl?run=$result->{'run_id'}"}, $result->{'run_id'}).$q->end_td().
				$q->td($result->{'type_analyse'}." genes");
				#$q->td(substr($result->{'type_analyse'}, $subst)." genes");
		#$ul .= $q->start_li().$q->a({'href' => "stats_ngs.pl?run=$result->{'run_id'}"}, $result->{'run_id'}).$q->span(" - ".substr($result->{'type_analyse'}, 6)." genes");
		#if ($result->{'type_analyse'} eq 'MiSeq-28') {$ul .= " - Run $i";$new_style .= $q->td("Run $i");}
		#elsif ($result->{'type_analyse'} eq 'MiSeq-112') {$ul .= " - Run $j";$new_style .= $q->td("Run $j");}
		#elsif ($result->{'type_analyse'} eq 'MiSeq-121') {$ul .= " - Run $k";$new_style .= $q->td("Run $k");}
		#elsif ($result->{'type_analyse'} eq 'MiSeq-3') {$ul .= " - Run $l";$new_style .= $q->td("Run $l");}
		#elsif ($result->{'type_analyse'} eq 'MiniSeq-121') {$ul .= " - Run $m";$new_style .= $q->td("Run $m");}
		if ($result->{'type_analyse'} eq 'MiSeq-28') {$new_style .= $q->td("Run $i")}
		elsif ($result->{'type_analyse'} eq 'MiSeq-112') {$new_style .= $q->td("Run $j")}
		elsif ($result->{'type_analyse'} eq 'MiSeq-121') {$new_style .= $q->td("Run $k")}
		elsif ($result->{'type_analyse'} eq 'MiSeq-3') {$new_style .= $q->td("Run $l")}
		elsif ($result->{'type_analyse'} eq 'MiSeq-132') {$new_style .= $q->td("Run $o")}
		elsif ($result->{'type_analyse'} eq 'MiniSeq-121') {$new_style .= $q->td("Run $m")}
		elsif ($result->{'type_analyse'} eq 'MiniSeq-132') {$new_style .= $q->td("Run $n")}
		elsif ($result->{'type_analyse'} eq 'MiniSeq-3') {$new_style .= $q->td("Run $p")}
		elsif ($result->{'type_analyse'} eq 'NextSeq-ClinicalExome') {$new_style .= $q->td("Run $r")}
		
		#$ul .= $q->end_li();
		$new_style .= $q->end_Tr()
	}
	#$ul .= $q->end_ul();
	$new_style .= $q->end_tbody().$q->end_table().$q->end_div();
	
	$dates .= "
	],";
	my $timeline = "
	storyjs_jsonp_data = {
		\"timeline\":
		{
		    \"headline\":\"Illumina Analysis\",
		    \"type\":\"default\",
		    \"text\":\"<p>$total_runs, $total_samples</p>\",
		    \"asset\": {
			\"media\":\"$HTDOCS_PATH/data/img/U2.png\",
			//\"credit\":\"Credit Name Goes Here\",
			\"caption\":\"USHVaM 2 using Timeline JS\"
		    },
		    $dates	    
		}
	};
	\$(document).ready(function() {
                createStoryJS({
                    type:       'timeline',
                    width:      '100%',
                    height:     '400',
                    source:     storyjs_jsonp_data,
                    embed_id:   'patient-timeline',
		    font:	'NixieOne-Ledger',
		    start_zoom_adjust:	'-1',
		    start_at_end:	'true'
                });
            });
	";
	
	
	print $q->script($timeline), $q->start_div({'id' => 'patient-timeline', 'defer' => 'defer'}), $q->end_div(), $q->br(), $q->br(), $new_style;
	
	
	
	
	
}


##Basic end of USHVaM 2 perl scripts:

U2_modules::U2_subs_1::standard_end_html($q);

print $q->end_html();

exit();

##End of Basic end


##specific subs

sub get_labels {
	my $run = shift;
	my ($query, $labels, $run_id, $run_type);
	if ($run eq 'global') {$query = "SELECT DISTINCT(run_id), type_analyse FROM miseq_analysis ORDER BY run_id DESC;";$run_type = '';}# type_analyse DESC,
	#if ($run eq 'global') {$query = "SELECT DISTINCT(run_id), type_analyse FROM miseq_analysis ORDER BY type_analyse DESC, run_id DESC;"}# type_analyse DESC, 
	else {$query = "SELECT id_pat, num_pat, type_analyse FROM miseq_analysis WHERE run_id = '$run' ORDER BY id_pat, num_pat;"}
	my $sth = $dbh->prepare($query);
	my $res = $sth->execute();
	while (my $result = $sth->fetchrow_hashref()) {
		if ($result->{'id_pat'} && $result->{'id_pat'} ne '') {$labels .= "\"$result->{'id_pat'}$result->{'num_pat'}\", ";$run_id = '';$run_type = $result->{'type_analyse'};}
		elsif ($result->{'run_id'} =~ /^(\d+)_\w+-(\w+)$/o) {$labels .= "\"$1_$2";$result->{'type_analyse'} =~ /-(\d+)/o;$labels .= "_$1\", ";$run_id .= "$result->{'run_id'},"}
		elsif ($result->{'run_id'} =~ /^(\d+)_\w+_\d+_(\w+)$/o) {$labels .= "\"$1_$2";$result->{'type_analyse'} =~ /-(\d+)/o;$labels .= "_$1\", ";$run_id .= "$result->{'run_id'},"}	
	}
	chop($labels);
	chop($labels);
	chop($run_id);
	return $labels, $run_id, $run_type;
}

sub get_data_mean {
	my ($run, $type, $num, $table) = @_;
	my $query;
	if ($run eq 'global') {$query = "SELECT AVG($type) AS a FROM $table"}
	else {$query = "SELECT AVG($type) AS a FROM $table WHERE run_id = '$run';"}
	my $res = $dbh->selectrow_hashref($query);
	return sprintf('%.'.$num.'f', $res->{'a'});
}

sub get_data {
	my ($run, $type, $math, $num, $cluster) = @_;
	my ($query, $data);
	if ($run eq 'global') {
		if ($cluster eq 'cluster') {$query = "SELECT $type AS a FROM illumina_run ORDER BY id DESC;";}##### BEWARE OF THE ORDER COMPARING TO LABELS!!!!!!!!!
		#else {$query = "SELECT $math($type) AS a FROM miseq_analysis GROUP BY run_id, type_analyse ORDER BY type_analyse DESC, run_id DESC;"}
		else {$query = "SELECT $math($type) AS a FROM miseq_analysis GROUP BY run_id, type_analyse ORDER BY run_id DESC;"}#type_analyse DESC, 
	}
	else {
		if ($cluster eq 'cluster') {$query = "SELECT $type FROM illumina_run WHERE id = '$run';"}
		else {$query = "SELECT $type AS a FROM miseq_analysis WHERE run_id = '$run' ORDER BY id_pat, num_pat;"}
	}
	#print $query;
	my $sth = $dbh->prepare($query);
	my $res = $sth->execute();
	while (my $result = $sth->fetchrow_hashref()) {
		if ($run ne 'global' && $cluster eq 'cluster') {
			$data .= $result->{'noc_raw'}.', '.$result->{'noc_pf'}.', '.$result->{'nodc'}.', '.$result->{'nouc'}.', '.$result->{'nouc_pf'}.', '.$result->{'nouic'}.', '.$result->{'nouic_pf'}.', '.$result->{'a'}.', ';
		}
		else {$data .= sprintf('%.'.$num.'f', $result->{'a'}).', '}
	}
	chop($data);
	chop($data);
	return $data;
}

sub get_total_samples {
	my $query = "SELECT COUNT(DISTINCT(num_pat, id_pat)) AS a FROM analyse_moleculaire WHERE type_analyse ~ \'$ANALYSIS_ILLUMINA_PG_REGEXP\';";
	my $res = $dbh->selectrow_hashref($query);
	return "$res->{'a'} samples";
}
sub get_total_runs {
	my $query = 'SELECT COUNT(DISTINCT(id)) AS a FROM illumina_run;';
	my $res = $dbh->selectrow_hashref($query);
	return "$res->{'a'} runs";
}

