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
my $ANALYSIS_ILLUMINA_WG_REGEXP = $config->ANALYSIS_ILLUMINA_WG_REGEXP();

#specific args for remote login to RS

my $SSH_RACKSTATION_BASE_DIR = $config->SSH_RACKSTATION_BASE_DIR();
my $SSH_RACKSTATION_MINISEQ_BASE_DIR = $config->SSH_RACKSTATION_MINISEQ_BASE_DIR();
#use automount to replace ssh
my $ABSOLUTE_HTDOCS_PATH = $config->ABSOLUTE_HTDOCS_PATH();
my $RS_BASE_DIR = $config->RS_BASE_DIR();
my $SSH_RACKSTATION_FTP_BASE_DIR = $config->SSH_RACKSTATION_FTP_BASE_DIR();
my $SSH_RACKSTATION_MINISEQ_FTP_BASE_DIR = $config->SSH_RACKSTATION_MINISEQ_FTP_BASE_DIR();
$SSH_RACKSTATION_FTP_BASE_DIR = $ABSOLUTE_HTDOCS_PATH.$RS_BASE_DIR.$SSH_RACKSTATION_FTP_BASE_DIR;
$SSH_RACKSTATION_MINISEQ_FTP_BASE_DIR = $ABSOLUTE_HTDOCS_PATH.$RS_BASE_DIR.$SSH_RACKSTATION_MINISEQ_FTP_BASE_DIR;
#end

my @styles = ($CSS_PATH.'font-awesome.min.css', $CSS_PATH.'w3.css', $CSS_DEFAULT, $CSS_PATH.'form.css', $CSS_PATH.'jquery-ui-1.12.1.min.css', $CSS_PATH.'jquery.alerts.css');

my $q = new CGI;

my $dbh = DBI->connect(    "DBI:Pg:database=$DB;host=$HOST;",
	$DB_USER,
	$DB_PASSWORD,
	{'RaiseError' => 1}
) or die $DBI::errstr;

### Creation of a pop up with form
#my $analysis_filtered = 'MiSeq-112';
#my $analysis_simple = 'MiSeq-28';

my $js = "
	//\$(function() {
	function setDialogForm() {
		//allFields = \$([]).add(\$(\"#fill_in\")),
		\$(\"#dialog-form\").dialog({
		       autoOpen: false,
		       resizable: true,
		       height: 500,
		       width: 650,
		       modal: true,
		       //close: function() {
		       //	allFields.val(\"\").removeClass(\"ui-state-error\");
		       //},
		       buttons: {
			       \"Add a variant\": function() {
				       var nom_c = \$(\"#new_variant\").val();
				       if (\$(\"#existing_variant\").val() !== '') {nom_c = \$(\"#existing_variant\").val()};
				       var j = \$(\".var\").length+1;
				       \$(\"#title_form_var\").append(\"&nbsp;&nbsp;&nbsp;&nbsp;PLEASE WAIT WHILE CREATING VARIANT\");
				       \$(\"#analysis_form :input\").prop(\"disabled\", true);
				       \$.ajax({
					       type: \"POST\",
					       url: \"variant_input.pl\",
					       data: {type: \$(\"#type\").val(), nom: \$(\"#nom\").val(), numero: \$(\"#numero\").val(), gene: \$(\"#gene\").val(), accession: \$(\"#acc_no\").val(), step: 2, sample: \$(\"#sample\").val(), analysis: \$(\"#technique\").val(), existing_variant: \$(\"#existing_variant\").val(), new_variant: \$(\"#new_variant\").val(), nom_c: nom_c, status: \$(\"#status\").val(), allele: \$(\"#allele\").val(), ng_accno: \$(\"#ng_accno\").val(), j: j, denovo: \$(\"#denovo\").prop('checked')}
					       })
				       .done(function(msg) {
						if (msg !== '') {\$(\"#genotype tr:last\").after('<tr id=\"v'+j+'\" class=\"var\">'+msg+'</tr>')};
						//if (msg !== '') {\$(\"#genotype\").append('<li id=\"v'+j+'\" class=\"var\">'+msg+'</li>')};
						//\$(\"#dialog-form\").dialog(\"close\"); //DOES NOT WANT TO CLOSE
						//\$(this).remove();
						\$(\".ui-dialog-content\").dialog(\"close\"); //YES - CLOSE ALL DIALOGS
				       });
				       //\$(this).dialog(\"close\");
				       //\$(this).dialog(\"destroy\");
				       //\$(this).remove();
			       },
			       Cancel: function() {
				       \$(this).dialog(\"close\");
				       //\$(this).hide();
			       }
		       }
		});
		\$(\"#dialog-form\").dialog(\"open\");
	}
	function setDialogFormStatus() {
		//allFields = \$([]).add(\$(\"#fill_in_status\")),
		\$(\"#dialog-form-status\").dialog({
		       autoOpen: false,
		       resizable: true,
		       height: 400,
		       width: 650,
		       modal: true,
		       buttons: {
			       \"Modify status and allele\": function() {
				       var j = \$(\"#j\").val();
				       //alert('ok');
				       \$.ajax({
					       type: \"POST\",
					       url: \"modify_variant_status.pl\",
					       data: {nom_c: \$(\"#nom_c\").val(), gene: \$(\"#gene\").val(), step: 2, sample: \$(\"#sample\").val(), analysis: \$(\"#technique\").val(), status_modify: \$(\"#status_modify\").val(), allele_modify: \$(\"#allele_modify\").val(), j: j, denovo_modify: \$(\"#denovo_modify\").prop('checked')}
					       })
				       .done(function(msg) {
					       //alert(j);
					       //if (msg !== '') {\$(\"#w\"+j).html(msg);};
					       //if (msg.match(/^(\\w+)-(\\w+)\$/g)) {alert(\$1);\$(\"#wstatus\"+j).html(\$1);\$(\"#wallele\"+j).html(\$2);}
					       var mat = msg.match(/^(\\w+)-(\\w+)\$/);
					       \$(\"#wstatus\"+j).html(mat[1]);
					       \$(\"#wallele\"+j).html(mat[2]);
					       //if (msg !== '') {\$(\"#wstatus\"+j).html(status);\$(\"#wallele\"+j).html(allele);};
					       //\$(this).dialog(\"close\"); //DOES NOT WANT TO CLOSE
					       \$(\".ui-dialog-content\").dialog(\"close\"); //YES - CLOSE ALL DIALOGS
				       });
				       //\$(this).dialog(\"close\");
				       //\$(this).hide();
			       },
			       Cancel: function() {
				       \$(this).dialog(\"close\");
				       //\$(this).hide();
			       }
		       }
		});
		\$(\"#dialog-form-status\").dialog(\"open\");
	}
	//});
	function createForm(type, nom, numero, gene, acc_no, sample, technique) {
		\$.ajax({
			type: \"POST\",
			url: \"variant_input_vv.pl\",
			data: {type: type, nom: nom, numero: numero, gene: gene, accession: acc_no, step: 1, sample: sample, analysis: technique}
			})
		.done(function(msg) {
			\$(\"#fill_in\").html(msg);
		});
		//\$(\"#fill_in\").text(type+\" - \"+nom+\" - \"+acc_no);
		setDialogForm();
	}
	function createFormStatus(nom_c, gene, sample, technique, html_id) {
		\$.ajax({
			type: \"POST\",
			url: \"modify_variant_status.pl\",
			data: {nom_c: nom_c, gene: gene, step: 1, sample: sample, analysis: technique, j: html_id}
			})
		.done(function(msg) {
			\$(\"#fill_in_status\").html(msg);
		});
		setDialogFormStatus();		
	}
	function delete_var(sample, gene, technique, variant, html_id) {
		\$.ajax({
			type: \"POST\",
			url: \"variant_input.pl\",
			data: {type: 'exon', nom: 'delete', numero: 1, gene: gene, accession: 'NM_000001.1', step: 3, sample: sample, analysis: technique, nom_c: variant}
			})
		.done(function() {
			//\$(\"#genotype\").append('<li>'+msg+'</li>')
			//\$(\"#\"+html_id).text(msg);
			\$(\"#\"+html_id).hide();
		});
	}
	function delete_analysis(sample, analysis, gene) {
		\$(\"#dialog-confirm\").dialog({
			resizable: false,
			height: 200,
			width: 350,
			modal: true,
			buttons: {
				\"Yes\": function() {
					\$.ajax({
						type: \"POST\",
						url: \"validate_analysis.pl\",
						data: {sample: sample, analysis: analysis, gene: gene, delete: '1'}
						})
					.done(function() {
						window.location='patient_file.pl?sample='+sample;
					});
					\$(this).dialog(\"close\");
				},
				Cancel: function() {
					\$(this).dialog(\"close\");
				}
			}
		});
	}
	function validate(sample, gene, analysis, type) {
		\$.ajax({
			type: \"POST\",
			url: \"validate_analysis.pl\",
			data: {sample: sample, gene: gene, analysis: analysis, type: type}
			})
		.done(function(msg) {
			//alert(msg);
			if (type === 'positif' || type === 'negatif') {type = 'result'}
			\$(\"#\"+type).attr('class', 'yes');
			if (msg === '-') {\$(\"#\"+type).attr('class', 'no');}
			\$(\"#\"+type).html(msg);
			\$(\"#\"+type+\"_2\").hide();
		});
	}
	function associate_gene() {
		var gjb2 = /DFNB1/;
		var gjb6 = /GJB6/;
		var filtered = /Min?i?Seq-1./;
		var simple = /Min?i?Seq-(3|2|28)/;
		var bigger = /NextSeq-ClinicalExome/;
		var biggest = /xome/;
		//var analysis = \$('input[name=analysis]').filter(':checked').val(); //4 radio button style
		var analysis = \$('#analysis').val();
		if (gjb2.test(analysis)) {
			\$(\"#gene_selection\").show();
			\$(\"#illumina_filter_selection\").hide();
			\$(\"#genes\").val('GJB2');
		}
		else if (gjb6.test(analysis)) {
			\$(\"#gene_selection\").show();
			\$(\"#illumina_filter_selection\").hide();
			\$(\"#genes\").val('GJB6');
		}
		else if (filtered.test(analysis) || bigger.test(analysis)){
			//Gene must disappear and a Filter menu must appear
			\$(\"#gene_selection\").hide();
			\$(\"#illumina_filter_selection\").show();
			if (bigger.test(analysis)){
				\$(\"#analysis_form\").attr(\"action\", \"add_clinical_exome.pl\");
			}
			//\$(\"#illumina_filter_selection\").
		}
		else if (simple.test(analysis)){
			//Gene must disappear
			\$(\"#gene_selection\").hide();
			\$(\"#analysis_form\").attr(\"action\", \"import_nenufaar.pl\");
		}
		else if (biggest.test(analysis)){			
			//genes param value = all
			\$(\"#genes\").val('all');
			//Gene and filter selection must disappear
			\$(\"#gene_selection\").hide();
			\$(\"#illumina_filter_selection\").hide();
			// alert(\$(\"#genes\").val());
		}
		else {
			\$(\"#gene_selection\").show();
			\$(\"#illumina_filter_selection\").hide();
			\$(\"#genes\").val('');
		}
		if (!bigger.test(analysis)){
			\$(\"#analysis_form\").attr(\"action\", \"\");
		}
	}
	// function illumina_form_submit() {
	//	jAlert('Please wait a few minutes while the run is being imported into U2');
	//	return true;
	// }
	// function select_toggle(form_id) {
	//	if (\$('#select_all_' + form_id).val() === 'Unselect all') {
	//		\$('#' + form_id + ' .sample_checkbox').prop('checked', false);
	//		\$('#select_all_' + form_id).val('Select all');
	//	}
	//	else {
	//		\$('#' + form_id + ' .sample_checkbox').prop('checked', true);
	//		\$('#select_all_' + form_id).val('Unselect all');
	//	}
	//}
	";


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
                        -src => $JS_PATH.'jquery.fullsize.pack.js', 'defer' => 'defer'},
						{-language => 'javascript',
                        -src => $JS_PATH.'jquery.validate.min.js', 'defer' => 'defer'},
						{-language => 'javascript',
                        -src => $JS_PATH.'jquery.alerts.js', 'defer' => 'defer'},
						{-language => 'javascript',
                        -src => $JS_PATH.'jquery-ui-1.12.1.min.js', 'defer' => 'defer'},
                        {-language => 'javascript',
                        -src => $JS_PATH.'jquery.autocomplete.min.js', 'defer' => 'defer'},
			$js,
                        {-language => 'javascript',
                        -src => $JS_DEFAULT, 'defer' => 'defer'}],		
                -encoding => 'ISO-8859-1');

my $user = U2_modules::U2_users_1->new();


U2_modules::U2_subs_1::standard_begin_html($q, $user->getName(), $dbh);

##end of MODIFIED init


### core script which will be used to add new analyses and variants

if ($user->isAnalyst() == 1) {
	my ($id, $number) = U2_modules::U2_subs_1::sample2idnum(uc($q->param('sample')), $q);
	
	my $step = U2_modules::U2_subs_1::check_step($q);

	if ($step == 1) {#form to create analysis
		my $query = "SELECT pathologie FROM patient WHERE numero = '$number' and identifiant = '$id';";
		my $res_patho = $dbh->selectrow_hashref($query);
		print $q->start_p({'class' => 'title'}), $q->start_big(), $q->start_strong(), $q->span("Access/create an analysis for "), $q->span({'onclick' => "window.location = 'patient_file.pl?sample=$id$number'", 'class' => 'pointer'}, $id.$number), $q->span(" ($res_patho->{'pathologie'}):"), $q->end_strong(), $q->end_big(),
				$q->end_p(), "\n",
				$q->start_div({'align' => 'center'}), "\n",
				$q->start_form({'action' => '', 'method' => 'post', 'class' => 'w3-container w3-card-4 w3-light-grey w3-text-blue w3-margin', 'id' => 'analysis_form', 'enctype' => &CGI::URL_ENCODED, 'style' => 'width:50%'}), "\n",
				$q->input({'type' => 'hidden', 'name' => 'step', 'value' => '2', 'form' => 'analysis_form'}), "\n",
				$q->input({'type' => 'hidden', 'name' => 'sample', 'value' => $id.$number, 'form' => 'analysis_form'}), "\n",
				$q->h2({'class' => 'w3-center w3-padding-32'}, 'Analysis details'),
				$q->start_div({'class' => 'w3-row w3-section w3-padding-16'}), "\n",
					$q->start_div({'class' => 'w3-col w3-right-align',  'style' => 'width:40%'}),
						#$q->start_fieldset(),label behind was previously legend, no 'for', with radio button preceeding style
						$q->span({'for' => 'analysis', 'class' => 'w3-large'}, 'Analysis type:&nbsp;&nbsp;'),
					$q->end_div(),
					$q->start_div({'class' => 'w3-rest'});
	print U2_modules::U2_subs_1::select_analysis($q, $dbh, 'analysis_form');
	print					#$q->end_fieldset(), $q->br(),
					$q->end_div(),
				$q->end_div(), "\n",
				$q->start_div({'class' => 'w3-row w3-section w3-padding-16', 'id' => 'gene_selection'}), "\n",
					$q->start_div({'class' => 'w3-col w3-right-align',  'style' => 'width:40%'}),
						#$q->start_fieldset(),label behind was previously legend, no 'for', with radio button preceeding style
						$q->span({'for' => 'gene', 'class' => 'w3-large'}, 'Gene:&nbsp;&nbsp;'),
					$q->end_div(),
					$q->start_div({'class' => 'w3-rest'});
	U2_modules::U2_subs_1::select_genes_grouped($q, 'genes', 'analysis_form');
	print					#$q->end_fieldset(), $q->br(),
					$q->end_div(),
				$q->end_div(), "\n",
				$q->start_div({'class' => 'w3-row w3-section w3-padding-16', 'id' => 'illumina_filter_selection', 'style' => 'display:none;'}), "\n",
					$q->start_div({'class' => 'w3-col w3-right-align',  'style' => 'width:40%'}),
						#$q->start_fieldset(),label behind was previously legend, no 'for', with radio button preceeding style
						$q->span({'for' => 'filter', 'class' => 'w3-large'}, 'Filter:&nbsp;&nbsp;'),
					$q->end_div(),
					$q->start_div({'class' => 'w3-rest'});
	print U2_modules::U2_subs_1::select_filter($q, 'filter', 'analysis_form');
	print					#$q->end_fieldset(), $q->br(),
					$q->end_div(),
				$q->end_div(), "\n",				
				$q->br(),
				$q->submit({'value' => 'Confirm', 'class' => 'w3-btn w3-blue', 'form' => 'analysis_form'}), $q->br(), $q->br(), "\n", $q->br(),
			$q->end_form(), $q->end_div(), "\n";
	}
	elsif ($step == 2 || $step == 3) {
		my $analysis;
		if ($step == 2) {$analysis = U2_modules::U2_subs_1::check_analysis($q, $dbh, 'form')}
		elsif ($step == 3) {$analysis = U2_modules::U2_subs_1::check_analysis($q, $dbh, 'basic')}
		my $link = $q->start_p().$q->a({'href' => "patient_file.pl?sample=$id$number"}, $id.$number).$q->end_p();
		
		if ($analysis =~ /Min?i?Seq-\d+/o && $step == 2) {
			#Illumina panel experiment
			#will ssh to RackStation
			#check paths and find patient in samplesheet (and check analysis type using valid_type_analysis)
			#check other patients status in U2 and propose import
			#go to step 4
			
			#MINISEQ change get instrument type
			my ($instrument, $instrument_path) = ('miseq', 'MiSeqDx/USHER');
			if ($analysis =~ /MiniSeq-\d+/o) {$instrument = 'miniseq';$instrument_path = 'MiniSeq';$SSH_RACKSTATION_BASE_DIR = $SSH_RACKSTATION_MINISEQ_BASE_DIR;$SSH_RACKSTATION_FTP_BASE_DIR=$SSH_RACKSTATION_MINISEQ_FTP_BASE_DIR}
			#but first get manifets name for validation purpose
			my ($manifest, $filtered) = U2_modules::U2_subs_2::get_filtering_and_manifest($analysis, $dbh);
			#my $query = "SELECT manifest_name, filtering_possibility FROM valid_type_analyse WHERE type_analyse = '$analysis';";
			#my $res = $dbh->selectrow_hashref($query);
			#my $manifest = $res->{'manifest_name'};
			#my $filtered = $res->{'filtering_possibility'};
			my $ssh;
			
			#we're in!!!
			#$ssh->system('cd ../../data/MiSeqDx/');
			#my $run_list = `ls $ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/data/$instrument_path/`;
			#old fashioned replaced with autofs 21/12/2016
			#my $run_list = $ssh->capture("cd $SSH_RACKSTATION_BASE_DIR && ls") or die "remote command failed: " . $ssh->error();
			#my $run_list = `ls $SSH_RACKSTATION_FTP_BASE_DIR`;
			opendir (DIR, $SSH_RACKSTATION_FTP_BASE_DIR);#first attempt to wake up autofs in case of unmounted
			my $run_list;
			my $access_method = 'autofs';
			opendir (DIR, $SSH_RACKSTATION_FTP_BASE_DIR) or $access_method = 'ssh';
			if ($access_method eq 'autofs') {
							while(my $under_dir = readdir(DIR)) {$run_list .= $under_dir." "}
							closedir(DIR)
			}
			else {
							$ssh = U2_modules::U2_subs_1::nas_connexion($link, $q);
							$run_list = $ssh->capture("cd $SSH_RACKSTATION_BASE_DIR && ls") or die "remote command failed: " . $ssh->error()
			}
			#print STDERR $access_method."\n";
			#if automunt fails, use SSH
			#print "$run_list<br/>";
			#$run_list = $ssh->capture("cd $SSH_RACKSTATION_BASE_DIR && ls") or die "remote command failed: " . $ssh->error()

			#create a hash which looks like {"illumina_run_id" => 0}
			my %runs = map {$_ => '0'} split(/\s/, $run_list);
			my $query = "SELECT * FROM illumina_run;";
			my $sth = $dbh->prepare($query);
			my $res = $sth->execute();
			#print "--$run_list--".$q->br();exit;
			if ($res) {
				while (my $result = $sth->fetchrow_hashref()) {#0 if unknown, 2 if complete, 1 otherwise
					if (exists($runs{$result->{'id'}})) {$runs{$result->{'id'}} = 1}
					if ($result->{'complete'} == 1) {
						#$runs{$result->{'id'}} = 2
						#print "-".$result->{'id'}."-".$q->br();
						delete $runs{$result->{'id'}};
					}
				}
			}
			#now create unknown runs in U2 AND seek for our patient
			my ($semaph, $ok) = (0, 0);
			while (my ($run, $value) = each %runs) {
                                                               # print "$run<br/>";
				#if ($run eq '@eaDir') {next}   #specific synology dirs => ignore
				if ($run !~ /^\d{6}_[A-Z]{1}\d{5}_\d{4}_0{9}-[A-Z0-9]{5}$/o && $run !~ /^\d{6}_[A-Z]{2}\d{5}_\d{4}_[A-Z0-9]{10}$/o) {next}
				
				###TO BE CHANGED 4 MINISEQ
				### path to alignment dir under run root
				my $alignment_dir;
				if ($instrument eq 'miseq'){
					#$alignment_dir = `grep -Eo \"AlignmentFolder>.+\\Alignment[0-9]*<\" $ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/data/$instrument_path/$run/CompletedJobInfo.xml`;
					#old fashioned replaced with autofs 21/12/2016
					#21/11/2018 reattempt with auofs
					if ($access_method eq 'autofs') {
									if (-f "$SSH_RACKSTATION_FTP_BASE_DIR/$run/CompletedJobInfo.xml") {
													$alignment_dir = `grep -Eo "AlignmentFolder>.+\\Alignment[0-9]*<" $SSH_RACKSTATION_FTP_BASE_DIR/$run/CompletedJobInfo.xml`;
													$alignment_dir =~ /\\(Alignment\d*)<$/o;$alignment_dir = $1;
													$alignment_dir = "$SSH_RACKSTATION_FTP_BASE_DIR/$run/Data/Intensities/BaseCalls/$alignment_dir";
									}
					}
					else {
									$alignment_dir = $ssh->capture("grep -Eo \"AlignmentFolder>.+\\Alignment[0-9]*<\" $SSH_RACKSTATION_BASE_DIR/$run/CompletedJobInfo.xml");
									$alignment_dir =~ /\\(Alignment\d*)<$/o;$alignment_dir = $1;
									$alignment_dir = "$SSH_RACKSTATION_BASE_DIR/$run/Data/Intensities/BaseCalls/$alignment_dir";
					}
					#$alignment_dir = $ssh->capture("grep -Eo \"AlignmentFolder>.+\\Alignment[0-9]*<\" $SSH_RACKSTATION_BASE_DIR/$run/CompletedJobInfo.xml");
                                                                                
					#print "grep -Eo \"AlignmentFolder>.+\\Alignment[0-9]*<\" $SSH_RACKSTATION_BASE_DIR/$run/CompletedJobInfo.xml".$alignment_dir;exit;
					
				}
				elsif($instrument eq 'miniseq'){
					#$alignment_dir = `grep -Eo \"AlignmentFolder>.+\\Alignment_?[0-9]*.+<\" $ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/data/$instrument_path/$run/CompletedJobInfo.xml`;
					#old fashioned replaced with autofs 21/12/2016
					#21/11/2018 reattempt with autofs
					if ($access_method eq 'autofs') {
						if (-f "$SSH_RACKSTATION_FTP_BASE_DIR/$run/CompletedJobInfo.xml") {$alignment_dir = `grep -Eo "AlignmentFolder>.+\\Alignment_?[0-9]*.+<" $SSH_RACKSTATION_FTP_BASE_DIR/$run/CompletedJobInfo.xml`}
					}
					else {$alignment_dir = $ssh->capture("grep -Eo \"AlignmentFolder>.+\\Alignment_?[0-9]*.+<\" $SSH_RACKSTATION_BASE_DIR/$run/CompletedJobInfo.xml")}
					#$alignment_dir = $ssh->capture("grep -Eo \"AlignmentFolder>.+\\Alignment_?[0-9]*.+<\" $SSH_RACKSTATION_BASE_DIR/$run/CompletedJobInfo.xml");
					#print "$SSH_RACKSTATION_BASE_DIR/$run/CompletedJobInfo.xml-$alignment_dir-";
					$alignment_dir =~ /\\(Alignment_?\d*.+)<$/o;
					$alignment_dir = $1;
					$alignment_dir =~ s/\\/\//og;
					#print "$alignment_dir-";
                                                                                if ($access_method eq 'autofs'){$alignment_dir = "$SSH_RACKSTATION_FTP_BASE_DIR/$run/$alignment_dir"}
					else {$alignment_dir = "$SSH_RACKSTATION_BASE_DIR/$run/$alignment_dir"}
					#print "$alignment_dir-";
				}
				my ($sentence, $location, $stat_file, $samplesheet, $summary_file) = ('Copying Remaining Files To Network', "$SSH_RACKSTATION_BASE_DIR/$run/AnalysisLog.txt", 'EnrichmentStatistics.xml', "$SSH_RACKSTATION_BASE_DIR/$run/SampleSheet.csv", 'enrichment_summary.csv');
                if ($access_method eq 'autofs') {$samplesheet = "$SSH_RACKSTATION_FTP_BASE_DIR/$run/SampleSheet.csv"}
				if ($instrument eq 'miniseq') {
                    ($sentence, $location, $stat_file, $samplesheet, $summary_file) = ('Saving Completed Job Information to', "$SSH_RACKSTATION_BASE_DIR/$run/AnalysisLog.txt", 'EnrichmentStatistics.xml', "$alignment_dir/SampleSheetUsed.csv", 'summary.csv');
                    $samplesheet = "$alignment_dir/SampleSheetUsed.csv";
                }		
				
				
				
				#unknown in U2
				if ($value == 0) {
					#1st check MSR analysis is finished:
					#look for 'Copying Remaining Files To Network' in AnalysisLog.txt
					
					###TO BE CHANGED 4 MINISEQ
					### path to analysis log file under alignment folder - and sentence to look for changed
					### and check for Metrics....
					my $test_file = '';
                                                                                if ($access_method eq 'autofs') {
                                                                                                if (-f "$SSH_RACKSTATION_FTP_BASE_DIR/$run/AnalysisLog.txt"){$test_file = `grep -e '$sentence' $SSH_RACKSTATION_FTP_BASE_DIR/$run/AnalysisLog.txt`}
                                                                                }
                                                                                else {$test_file = $ssh->capture("grep -e '$sentence' $location")}
					#print $ssh->capture("grep -e '$sentence' $location");exit;
					#if ($ssh->capture("grep -e '$sentence' $location") ne '') {
                                                                                if ($test_file ne ''){
					
						#DONE import cluster stats from enrichment_stats.xml and put it into illumina_run
						#modify database before -done added:
						#noc_pf   | usmallint             | default NULL::smallint	NumberOfClustersPF
						#noc_raw  | usmallint             | default NULL::smallint	NumberOfClustersRaw
						#nodc     | usmallint             | default NULL::smallint	NumberOfDuplicateClusters
						#nouc     | usmallint             | default NULL::smallint	NumberOfUnalignedClusters
						#nouc_pf  | usmallint             | default NULL::smallint	NumberOfUnalignedClustersPF
						#nouic    | usmallint             | default NULL::smallint	NumberOfUnindexedClusters
						#nouic_pf | usmallint             | default NULL::smallint	NumberOfUnindexedClustersPF
						#in illumina_run
						#with a grep -Eo ex:
						#my $alignment_dir = $ssh->capture("grep -Eo \"AlignmentFolder>.+\\Alignment[0-9]*<\" $SSH_RACKSTATION_BASE_DIR/$run/CompletedJobInfo.xml");
						#$alignment_dir =~ /\\(Alignment\d*)<$/o;
						#<NumberOfClustersPF>18329931</NumberOfClustersPF>
						#<NumberOfClustersRaw>21256323</NumberOfClustersRaw>
						#<NumberOfDuplicateClusters>2351136</NumberOfDuplicateClusters>
						#<NumberOfUnalignedClusters>2295956</NumberOfUnalignedClusters>
						#<NumberOfUnalignedClustersPF>161076</NumberOfUnalignedClustersPF>
						#<NumberOfUnindexedClusters>1359663</NumberOfUnindexedClusters>
						#<NumberOfUnindexedClustersPF>568151</NumberOfUnindexedClustersPF>
						#
						
						
						my $noc_pf = &getMetrics("NumberOfClustersPF>[0-9]+<", $alignment_dir, $ssh, $stat_file, $access_method);
						my $noc_raw = &getMetrics("NumberOfClustersRaw>[0-9]+<", $alignment_dir, $ssh, $stat_file, $access_method);
						my $nodc = &getMetrics("NumberOfDuplicateClusters>[0-9]+<", $alignment_dir, $ssh, $stat_file, $access_method);
						my $nouc = &getMetrics("NumberOfUnalignedClusters>[0-9]+<", $alignment_dir, $ssh, $stat_file, $access_method);
						my $nouc_pf = &getMetrics("NumberOfUnalignedClustersPF>[0-9]+<", $alignment_dir, $ssh, $stat_file, $access_method);
						my $nouic = &getMetrics("NumberOfUnindexedClusters>[0-9]+<", $alignment_dir, $ssh, $stat_file, $access_method);
						my $nouic_pf = &getMetrics("NumberOfUnindexedClustersPF>[0-9]+<", $alignment_dir, $ssh, $stat_file, $access_method);
						#my $grep = $ssh->capture("grep -Eo \"NumberOfClustersPF>[0-9]+<\" $SSH_RACKSTATION_BASE_DIR/$run/Data/Intensities/BaseCalls/$alignment_dir/EnrichmentStatistics.xml");
						#$grep =~ />(\d+)<$/o;
						#my $noc_pf = $1;
						#
						
						
						my $insert = "INSERT INTO illumina_run VALUES ('$run', 'f', '$noc_pf', '$noc_raw', '$nodc', '$nouc', '$nouc_pf', '$nouic', '$nouic_pf');";
						
						
						#my $insert = "INSERT INTO illumina_run VALUES ('$run', 'f');";
						$dbh->do($insert);
					}
					else {next}
				}
				#seek for patient
				#if ($value != 2) {
				#we grep for patient ID in the samplesheets
				#if succeeded, we must check whether this run is already recorded for the patient
				#print "grep -e '$id$number' $SSH_RACKSTATION_BASE_DIR/$run/SampleSheet.csv", $q->br();
				#print "grep -e '$id$number' $samplesheet";
				my $test_samplesheet = '';
				if ($access_method eq 'autofs') {if (-f $samplesheet) {$test_samplesheet = `grep -e '$id$number' $samplesheet`}}
				else {$test_samplesheet = $ssh->capture("grep -e '$id$number' $samplesheet")}
				#print "1-$run-$manifest-$samplesheet-$test_samplesheet<br/>";
				if ($test_samplesheet ne '') {
				#if ($ssh->capture("grep -e '$id$number' $samplesheet") ne '') {
					$semaph = 1;
					#$query = "SELECT num_pat, id_pat FROM miseq_analysis WHERE run_id = '$run' AND num_pat = '$number' AND id_pat = '$id' GROUP BY num_pat, id_pat;";
					$query = "SELECT num_pat, id_pat FROM miseq_analysis WHERE type_analyse = '$analysis' AND num_pat = '$number' AND id_pat = '$id' GROUP BY num_pat, id_pat;";
					$res = $dbh->selectrow_hashref($query);
					if ($res) {print $link;U2_modules::U2_subs_1::standard_error('14', $q);}
					else {
						#we can proceed
						#validate analysis type
                                                                                                $test_samplesheet = '';
                                                                                                if ($access_method eq 'autofs') {$test_samplesheet = `grep -e '$manifest' $samplesheet`}
                                                                                                else {$test_samplesheet = $ssh->capture("grep -e '$manifest' $samplesheet")}
                                                                                                #print "2-$run-$manifest-$samplesheet-$test_samplesheet<br/>";
                                                                                                if ($test_samplesheet ne '') {
						#if ($ssh->capture("grep -e '$manifest' $samplesheet")) {
							#ok
							$ok = 1;
							#search other patients in the samplesheet
							#print "grep -E \"^$PATIENT_IDS[0-9]+,\" $SSH_RACKSTATION_BASE_DIR/$key/SampleSheet.csv";
							my $char = ',';
							if ($instrument eq 'miniseq') {$char = '-'}
							#if ($instrument eq 'miseq') {
                                                                                                                my $patient_list;
                                                                                                                if ($access_method eq 'autofs') {
                                                                                                                                my $regexp = '^'.$PATIENT_IDS.'[0-9]+'.$char;
                                                                                                                                $patient_list = `grep -Eo "$regexp" $samplesheet`;
                                                                                                                                #$patient_list = `grep -Eo \"^".$PATIENT_IDS."[0-9]+$char\" $samplesheet`;
                                                                                                                }
							else {$patient_list = $ssh->capture("grep -Eo \"^".$PATIENT_IDS."[0-9]+$char\" $samplesheet")}
                                                                                                                #my $patient_list = $ssh->capture("grep -Eo \"^".$PATIENT_IDS."[0-9]+$char\" $samplesheet");
							$patient_list =~ s/\n//og;
							my %patients = map {$_ => 0} split(/$char/, $patient_list);
							%patients = %{U2_modules::U2_subs_2::check_ngs_samples(\%patients, $analysis, $dbh)};
												
							
							
							#foreach my $keys (sort keys (%patients)) {print $keys.$patients{$keys}.$q->br();}
							
							#build form
							print U2_modules::U2_subs_2::build_ngs_form($id, $number, $analysis, $run, $filtered, \%patients, 'import_illumina_vv.pl', '2', $q, $alignment_dir, $ssh, $summary_file, $instrument, $access_method);
							print $q->br().U2_modules::U2_subs_2::print_panel_criteria($q, $analysis);


						}
					}
					
				}
				#else {print $id.$number;U2_modules::U2_subs_1::standard_error('18', $q);}
				#}
				
				
			}
			if ($semaph == 0) {print $link;U2_modules::U2_subs_1::standard_error('18', $q);}
			if ($ok == 0) {print $link;U2_modules::U2_subs_1::standard_error('19', $q);}
			
			delete $ENV{PATH};
		}
		else {
		
			my ($gene, $second_name) = U2_modules::U2_subs_1::check_gene($q, $dbh);
			my $date = U2_modules::U2_subs_1::get_date();
			# print STDERR "step: $step; analysis: $analysis; gene:$gene\n";
			if ($analysis =~ /xome$/o && $step == 2 && $gene eq 'all') {
				# Analysis to signal that an exome has been performed on the sample
				# ($number, $id, $gene, $analysis, $date, $name, $neg, $dbh)
				my $date = U2_modules::U2_subs_1::get_date();
				&insert_analysis($number, $id, '*', $analysis, $date, $user->getName(), 'f', $dbh);
				print $q->br(), $q->p("Analysis $analysis has been added to $id$number for all genes."), $q->br(), "\n",
					$q->br(), $q->button({'class' => 'w3-btn w3-blue w3padding-16', 'onclick' => 'window.open("patient_file.pl?sample='.$id.$number.'","_self");', 'value' => "Go back to $id$number page"});
			}
			else {
			
				#record analysis
				#1st, check if experience already exists
				my ($tech_val, $tech_val_class, $result_ana, $result_ana_class, $bio_val, $bio_val_class);
				my $query = "SELECT num_pat, analyste, date_analyse, technical_valid, result, valide FROM analyse_moleculaire WHERE num_pat = '$number' AND id_pat = '$id' AND nom_gene[1] = '$gene' AND type_analyse = '$analysis';";
				my $res = $dbh->selectrow_hashref($query);
				#my ($to_fill, $order, $to_fill_table) = ('', 'ASC', '');
				my $fented_class = 'fented_noleft';
				if ($analysis =~ /Min?i?Seq-\d+/o) {$fented_class=''}			
				my ($order, $to_fill_table) = ('ASC', $q->start_div({'class' => "$fented_class container"}).$q->start_table({'class' => 'great_table technical', 'id' => 'genotype'}));
				
				if ($step == 2) {$order = U2_modules::U2_subs_1::get_strand($gene, $dbh)}
				if ($res->{'num_pat'} ne '') { #print variants already recorded
	
					if ($res->{'analyste'} ne '') {$to_fill_table .= $q->caption("$analysis by $res->{'analyste'}, $res->{'date_analyse'}")."\n"}
					$to_fill_table .= $q->start_Tr().
								$q->th({'class' => 'left_general'}, 'Position').
								$q->th({'class' => 'left_general'}, 'Variant').
								$q->th({'class' => 'left_general'}, 'Status').
								$q->th({'class' => 'left_general'}, 'Allele').
								$q->th({'class' => 'left_general'}, 'Class').
								$q->th({'class' => 'left_general'}, 'Delete').
								$q->th({'class' => 'left_general'}, 'Status Link').
							$q->end_Tr()."\n";
					$query = "SELECT a.nom_c, a.statut, a.allele, a.denovo, b.type_segment, b.classe, c.nom FROM variant2patient a, variant b, segment c WHERE a.nom_c = b.nom AND a.nom_gene = b.nom_gene AND b.nom_gene = c.nom_gene AND b.num_segment = c.numero AND b.type_segment = c.type AND a.num_pat = '$number' AND a.id_pat = '$id' AND a.nom_gene[1] = '$gene' AND a.type_analyse = '$analysis' ORDER by b.nom_g $order;";	
					my $sth = $dbh->prepare($query);
					my $res2 = $sth->execute();
					my $j;
					while (my $result = $sth->fetchrow_hashref()) {
						$j++;
						#$to_fill .= $q->start_li({'id' => "v$j", 'class' => 'var'});
						$to_fill_table .= $q->start_Tr({'id' => "v$j", 'class' => 'var'}).$q->start_td();#.$q->td().$q->td().$q->td().$q->td().$q->td().$q->td().$q->td().$q->end_Tr();
						#if ($result->{'type_segment'} =~ /on/o) {$to_fill .= $q->span(ucfirst($result->{'type_segment'}));$to_fill_table .= $q->span(ucfirst($result->{'type_segment'}));}
						if ($result->{'type_segment'} =~ /on/o) {$to_fill_table .= $q->span(ucfirst($result->{'type_segment'}));}
	
						my $denovo_txt = U2_modules::U2_subs_1::translate_boolean_denovo($result->{'denovo'});
						#if ($result->{'denovo'} == 1) {$denovo_txt = '_denovo'}
						$to_fill_table .= $q->span(" $result->{'nom'}").
							$q->end_td().
							$q->td($result->{'nom_c'}).
							$q->td({'id' => "wstatus$j"}, $result->{'statut'}).
							$q->td({'id' => "wallele$j"}, $result->{'allele'}.$denovo_txt).
							$q->td({'style' => "color:".U2_modules::U2_subs_1::color_by_classe($result->{'classe'}, $dbh).";"}, $result->{'classe'}).
							$q->start_td().
								$q->img({'src' => $HTDOCS_PATH.'data/img/buttons/delete.png', 'class' => 'pointer text_img', 'width' => '15', height => '15', 'onclick' => "delete_var('$id$number', '$gene', '$analysis', '".uri_encode($result->{'nom_c'})."', 'v$j');"}).
							$q->end_td().
							$q->start_td().
								$q->a({'href' => 'javascript:;', 'title' => 'click to modifiy status and/or alleles', 'onclick' => "createFormStatus('".uri_encode($result->{'nom_c'})."', '$gene', '$id$number', '$analysis', 'v$j');"}, "Modify").
							$q->end_td().
						$q->end_Tr()."\n";
					}
					#$to_fill .= $q->br();
					$to_fill_table .= $q->end_table().$q->end_div();
					
					$tech_val = U2_modules::U2_subs_1::translate_boolean($res->{'technical_valid'});
					$tech_val_class = U2_modules::U2_subs_1::translate_boolean_class($res->{'technical_valid'});
					$result_ana = U2_modules::U2_subs_1::translate_boolean($res->{'result'});
					$result_ana_class = U2_modules::U2_subs_1::translate_boolean_class($res->{'result'});
					$bio_val = U2_modules::U2_subs_1::translate_boolean($res->{'valide'});
					$bio_val_class = U2_modules::U2_subs_1::translate_boolean_class($res->{'valide'});
					
					
					#print $res->{'result'};
				}
				else {	
					#if not aCGH, insert for one gene
					if ($analysis ne 'aCGH') {
						&insert_analysis($number, $id, $gene, $analysis, $date, $user->getName(), 'f', $dbh);
						$tech_val = U2_modules::U2_subs_1::translate_boolean('0');
						$tech_val_class = U2_modules::U2_subs_1::translate_boolean_class('0');
						##2nd, get #acc for all isoforms;
						#$query = "SELECT nom FROM gene WHERE nom[1] = '$gene';";
						#my $sth = $dbh->prepare($query);
						#my $res = $sth->execute();
						#while (my $result = $sth->fetchrow_hashref()) {
						#	my $insert = "INSERT INTO analyse_moleculaire VALUES ('$number', '$id', '{\"$result->{'nom'}[0]\",\"$result->{'nom'}[1]\"}', '$analysis', 'f', NULL, '$date', NULL, NULL, '".$user->getName()."', NULL, NULL, 'f');";
						#	$dbh->do($insert);
						#	#print $insert;
						#}
					}
					else {
						#insert for all genes in aCGH
						foreach (@U2_modules::U2_subs_1::ACGH) {
							&insert_analysis($number, $id, $_, $analysis, $date, $user->getName(), 't', $dbh);
							$tech_val = U2_modules::U2_subs_1::translate_boolean('1');
							$tech_val_class = U2_modules::U2_subs_1::translate_boolean_class('0');
							#$tech_val = '+';
						}
					}				
					$result_ana = U2_modules::U2_subs_1::translate_boolean();
					$result_ana_class = U2_modules::U2_subs_1::translate_boolean_class();
					$bio_val = U2_modules::U2_subs_1::translate_boolean('0');
					$bio_val_class = U2_modules::U2_subs_1::translate_boolean_class('0');
					$to_fill_table .= $q->start_Tr().
								$q->th({'class' => 'left_general'}, 'Position').
								$q->th({'class' => 'left_general'}, 'Variant').
								$q->th({'class' => 'left_general'}, 'Status').
								$q->th({'class' => 'left_general'}, 'Allele').
								$q->th({'class' => 'left_general'}, 'Class').
								$q->th({'class' => 'left_general'}, 'Delete').
								$q->th({'class' => 'left_general'}, 'Status Link').
							$q->end_Tr()."\n";
				}
					
				print $q->start_p({'class' => 'title'}), $q->start_big(), $q->start_strong(), $q->em($gene), $q->span(" $analysis for "),
					$q->span({'onclick' => "window.location = 'patient_file.pl?sample=$id$number'", 'class' => 'pointer'}, $id.$number), $q->span(':'), $q->end_strong(), $q->end_big(), $q->end_p(), "\n";
					
				if ($step == 2) {
					my $text =  $q->button({'value' => 'Delete analysis', 'onclick' => "delete_analysis('$id$number', '$analysis', '$gene');", 'class' => 'w3-button w3-ripple w3-blue'}).$q->span("&nbsp;&nbsp;&nbsp;&nbsp;WARNING: this will also delete associated variants.")."\n";
					print U2_modules::U2_subs_2::danger_panel($text, $q);			
					
					print $q->start_div({'id' => 'dialog-confirm', 'title' => 'Delete Analysis?', 'class' => 'hidden'}), $q->start_p(), $q->span('By clicking on the "Yes" button, you will delete permanently the complete analysis and the associated variants.'), $q->end_p(), $q->end_div(), $q->br(), $q->br(), "\n";
	
					
					my @js_params = ('createForm', $id.$number, $analysis);
					my ($js, $map) = U2_modules::U2_subs_2::gene_canvas($gene, $order, $dbh, \@js_params);
				
	
					print $q->start_div({'class' => 'container'}), $map, "\n<canvas class=\"ambitious\" width = \"1100\" height = \"500\" id=\"exon_selection\">Change web browser for a more recent please!</canvas>", $q->img({'src' => $HTDOCS_PATH.'data/img/transparency.png', 'usemap' => '#segment', 'class' => 'fented', 'id' => 'transparent_image'}), $q->end_div(), "\n", $q->script({'type' => 'text/javascript'}, $js), "\n",
						$q->start_div({'id' => 'dialog-form', 'title' => 'Add a variant'}), $q->p({'id' => 'fill_in'}), $q->end_div(), "\n";
				
				}
				print $q->start_div({'id' => 'dialog-form-status', 'title' => 'modify status and allele'}), $q->p({'id' => 'fill_in_status'}), $q->end_div(), "\n";
				#if ($step == 2) {print $q->start_div({'class' => 'fented'})}
				if ($step == 3) {print $q->start_div()}
				
				#print $q->start_ul({'id' => 'genotype'}), $to_fill,
				#		$q->end_ul(),
				#	$q->end_div(), "\n";
				print $to_fill_table;
				#technical validation & result
				
				if ($step == 2) {print $q->start_div({'class' => 'fented_noleft container'})}
				elsif ($step == 3) {print $q->start_div({'class' => 'container'})}
				
				print $q->start_table({'class' => 'technical great_table'}), "\n",
					$q->start_Tr(), "\n",
						$q->th({'class' => 'left_general'}, 'Technical validation'), "\n",
						$q->th({'class' => 'left_general'}, 'Analysis results'), "\n",
						$q->th({'class' => 'left_general'}, 'Biological validation'), "\n",
						$q->th({'class' => 'left_general'}, 'Link'), "\n",
					$q->end_Tr(), "\n",
					$q->start_Tr(), "\n",
						$q->start_td({'class' => 'td_border'}), "\n",
							$q->span({'id' => 'technical_valid', 'class' => $tech_val_class}, $tech_val), "\n";
				
	
				if ($tech_val ne '+') {
					print $q->span("&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"), $q->button({'id' => 'technical_valid_2', 'value' => 'Validate', 'onclick' => "validate('$id$number', '$gene', '$analysis', 'technical_valid');", 'class' => 'w3-button w3-ripple w3-blue'});
				}
				print
						$q->end_td(), "\n",
						$q->start_td({'class' => 'td_border'}), "\n",
							$q->span({'id' => 'result', 'class' => $result_ana_class}, $result_ana), "\n";
	
				if ($user->isReferee() == 1) {
					if ($result_ana eq 'UNDEFINED') {
						print $q->start_span({'id' => 'result_2'}), $q->span("&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"), $q->button({'value' => 'Negative', 'onclick' => "validate('$id$number', '$gene', '$analysis', 'negatif');", 'class' => 'w3-button w3-ripple w3-blue'}), $q->span("&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"), $q->button({'value' => 'Positive', 'onclick' => "validate('$id$number', '$gene', '$analysis', 'positif');", 'class' => 'w3-button w3-ripple w3-blue'}),  $q->end_span();
					}
				}
				print
						$q->end_td(), "\n",
						$q->start_td({'class' => 'td_border'}), "\n",
							$q->span({'id' => 'valide', 'class' => $bio_val_class}, $bio_val), "\n";
	
				if ($user->isValidator() == 1) {
					if ($bio_val ne '+') {
						print $q->span("&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"), $q->button({'id' => 'valide_2', 'value' => 'Validate', 'onclick' => "validate('$id$number', '$gene', '$analysis', 'valide');", 'class' => 'w3-button w3-ripple w3-blue'});
					}
				}
				print
						$q->end_td(), "\n",
						$q->start_td({'class' => 'td_border'}), "\n",
							$q->button({'value' => 'Jump to genotype view', 'onclick' => "window.location = 'patient_genotype.pl?sample=$id$number&gene=$gene';", 'class' => 'w3-button w3-ripple w3-blue'}),
						$q->end_td(), "\n",
					$q->end_Tr(), "\n",
				$q->end_table(), "\n",
				$q->end_div(), "\n";
			}
			
		}

	}

}
else {U2_modules::U2_subs_1::standard_error('13', $q)}

##Basic end of USHVaM 2 perl scripts:

U2_modules::U2_subs_1::standard_end_html($q);

print $q->end_html();

exit();

##End of Basic end


##specific subs for current script




sub insert_analysis {
	my ($number, $id, $gene, $analysis, $date, $name, $neg, $dbh) = @_;
	#get #acc for all isoforms;
	my $query = "SELECT nom FROM gene WHERE nom[1] = '$gene';";
	if ($gene eq '*') { # exome: all genes
		$query = "SELECT nom FROM gene ;";
	}
	my $sth = $dbh->prepare($query);
	my $res = $sth->execute();
	while (my $result = $sth->fetchrow_hashref()) {
		my $insert = "INSERT INTO analyse_moleculaire VALUES ('$number', '$id', '{\"$result->{'nom'}[0]\",\"$result->{'nom'}[1]\"}', '$analysis', 'f', NULL, '$date', NULL, NULL, '".$name."', NULL, NULL, '$neg');";
		$dbh->do($insert);
		#print $insert;
	}
}

sub getMetrics {
	my ($reg, $alignment_dir, $ssh, $file, $access_method) = @_;	
	#my $grep = $ssh->capture("grep -Eo -m 1 \"$reg\" $SSH_RACKSTATION_BASE_DIR/$run/Data/Intensities/BaseCalls/$alignment_dir/EnrichmentStatistics.xml");
	#print "grep -Eo -m 1 \"$reg\" $alignment_dir/$file";
                my $grep;
                if ($access_method eq 'autofs') {$grep = `grep -Eo -m 1 \"$reg\" $alignment_dir/$file`}
	else {$grep = $ssh->capture("grep -Eo -m 1 \"$reg\" $alignment_dir/$file")}
	$grep =~ />(\d+)<$/o;
	return $1;
}
