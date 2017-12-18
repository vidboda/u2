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

#specific args for remote login to RS

my $SSH_RACKSTATION_BASE_DIR = $config->SSH_RACKSTATION_BASE_DIR();
my $SSH_RACKSTATION_MINISEQ_BASE_DIR = $config->SSH_RACKSTATION_MINISEQ_BASE_DIR();

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
					       data: {type: \$(\"#type\").val(), nom: \$(\"#nom\").val(), numero: \$(\"#numero\").val(), gene: \$(\"#gene\").val(), accession: \$(\"#acc_no\").val(), step: 2, sample: \$(\"#sample\").val(), analysis: \$(\"#technique\").val(), existing_variant: \$(\"#existing_variant\").val(), new_variant: \$(\"#new_variant\").val(), nom_c: nom_c, status: \$(\"#status\").val(), allele: \$(\"#allele\").val(), ng_accno: \$(\"#ng_accno\").val(), j: j}
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
					       data: {nom_c: \$(\"#nom_c\").val(), gene: \$(\"#gene\").val(), step: 2, sample: \$(\"#sample\").val(), analysis: \$(\"#technique\").val(), status_modify: \$(\"#status_modify\").val(), allele_modify: \$(\"#allele_modify\").val(), j: \$(\"#j\").val()}
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
			url: \"variant_input.pl\",
			data: {type: type, nom: nom, numero: numero, gene: gene, accession: acc_no, step: 1, sample: sample, analysis: technique}
			})
		.done(function(msg) {
			\$(\"#fill_in\").html(msg);
		});
		//\$(\"#fill_in\").text(type+\" - \"+nom+\" - \"+acc_no);
		setDialogForm();
	 }
	 function createFormStatus(nom_c, gene, sample, technique, html_id, status, allele) {
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
		var simple = /Min?i?Seq-(3|28)/;
		var bigger = /NextSeq-ClinicalExome/;
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
		print $q->br(), $q->br(), $q->start_p({'class' => 'title'}), $q->start_big(), $q->start_strong(), $q->span("Access/create an analysis for "), $q->span({'onclick' => "window.location = 'patient_file.pl?sample=$id$number'", 'class' => 'pointer'}, $id.$number), $q->span(" ($res_patho->{'pathologie'}):"), $q->end_strong(), $q->end_big(),
				$q->end_p(), $q->br(), $q->br(), "\n",
				$q->start_div({'align' => 'center'}), "\n",
				$q->start_form({'action' => '', 'method' => 'post', 'class' => 'w3-container w3-card-4 w3-light-grey w3-text-blue w3-margin', 'id' => 'analysis_form', 'enctype' => &CGI::URL_ENCODED, 'style' => 'width:50%'}), "\n",
				$q->input({'type' => 'hidden', 'name' => 'step', 'value' => '2', form => 'analysis_form'}), "\n",
				$q->input({'type' => 'hidden', 'name' => 'sample', 'value' => $id.$number, form => 'analysis_form'}), "\n",
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
		#				$q->start_li({'id' => 'gene_selection', 'class' => 'w3-padding-16'}),
		#					$q->label({'for' => 'gene', 'class' => 'w3-padding-16'}, 'Gene:');
		#U2_modules::U2_subs_1::select_genes_grouped($q, 'genes', 'analysis_form');
		#print 					$q->br(), "\n",
		#				$q->end_li(), "\n",
		#				$q->start_li({'id' => 'illumina_filter_selection', 'style' => 'display:none;', 'class' => 'w3-padding-16'}),
		#					$q->label({'for' => 'filter', 'class' => 'w3-padding-16'}, 'Filter:');
		#print U2_modules::U2_subs_1::select_filter($q, 'filter', 'analysis_form');
		#print 					$q->br(), "\n",
		#				$q->end_li(), "\n",
		#			$q->end_div(),
		#		$q->end_fieldset(),
				
				
				
		#		$q->start_fieldset(),
		#			$q->legend('Analysis details'),
		#			$q->start_ol(), "\n",
		#				$q->start_li({'class' => 'w3-padding-16'}),
		#					#$q->start_fieldset(),label behind was previously legend, no 'for', with radio button preceeding style
		#						$q->label({'for' => 'analysis', 'class' => 'w3-padding-16'}, 'Analysis type:');
		#print U2_modules::U2_subs_1::select_analysis($q, $dbh, 'analysis_form');
		#print					#$q->end_fieldset(), $q->br(),
		#				$q->end_li(), "\n",
		#				$q->start_li({'id' => 'gene_selection', 'class' => 'w3-padding-16'}),
		#					$q->label({'for' => 'gene', 'class' => 'w3-padding-16'}, 'Gene:');
		#U2_modules::U2_subs_1::select_genes_grouped($q, 'genes', 'analysis_form');
		#print 					$q->br(), "\n",
		#				$q->end_li(), "\n",
		#				$q->start_li({'id' => 'illumina_filter_selection', 'style' => 'display:none;', 'class' => 'w3-padding-16'}),
		#					$q->label({'for' => 'filter', 'class' => 'w3-padding-16'}, 'Filter:');
		#print U2_modules::U2_subs_1::select_filter($q, 'filter', 'analysis_form');
		#print 					$q->br(), "\n",
		#				$q->end_li(), "\n",
		#			$q->end_ol(),
		#		$q->end_fieldset(),
				
				
				$q->br(),
				$q->submit({'value' => 'Confirm', 'class' => 'w3-btn w3-blue', form => 'analysis_form'}), $q->br(), $q->br(), "\n", $q->br(),
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
			if ($analysis =~ /MiniSeq-\d+/o) {$instrument = 'miniseq';$instrument_path = 'MiniSeq';$SSH_RACKSTATION_BASE_DIR = $SSH_RACKSTATION_MINISEQ_BASE_DIR}
			#but first get manifets name for validation purpose
			my ($manifest, $filtered) = U2_modules::U2_subs_2::get_filtering_and_manifest($analysis, $dbh);
			#my $query = "SELECT manifest_name, filtering_possibility FROM valid_type_analyse WHERE type_analyse = '$analysis';";
			#my $res = $dbh->selectrow_hashref($query);
			#my $manifest = $res->{'manifest_name'};
			#my $filtered = $res->{'filtering_possibility'};
			
			my $ssh = U2_modules::U2_subs_1::nas_connexion($link, $q);
			
			#we're in!!!
			#$ssh->system('cd ../../data/MiSeqDx/');
			#my $run_list = `ls $ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/data/$instrument_path/`;
			#old fashioned replaced with autofs 21/12/2016
			my $run_list = $ssh->capture("cd $SSH_RACKSTATION_BASE_DIR && ls") or die "remote command failed: " . $ssh->error();
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
				#if ($run eq '@eaDir') {next}   #specific synology dirs => ignore
				if ($run !~ /^\d{6}_[A-Z]{1}\d{5}_\d{4}_0{9}-[A-Z0-9]{5}$/o && $run !~ /^\d{6}_[A-Z]{2}\d{5}_\d{4}_[A-Z0-9]{10}$/o) {next}
				
				###TO BE CHANGED 4 MINISEQ
				### path to alignment dir under run root
				my $alignment_dir;
				if ($instrument eq 'miseq'){
					#$alignment_dir = `grep -Eo \"AlignmentFolder>.+\\Alignment[0-9]*<\" $ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/data/$instrument_path/$run/CompletedJobInfo.xml`;
					#old fashioned replaced with autofs 21/12/2016
					$alignment_dir = $ssh->capture("grep -Eo \"AlignmentFolder>.+\\Alignment[0-9]*<\" $SSH_RACKSTATION_BASE_DIR/$run/CompletedJobInfo.xml");
					#print "grep -Eo \"AlignmentFolder>.+\\Alignment[0-9]*<\" $SSH_RACKSTATION_BASE_DIR/$run/CompletedJobInfo.xml".$alignment_dir;exit;
					$alignment_dir =~ /\\(Alignment\d*)<$/o;$alignment_dir = $1;
					$alignment_dir = "$SSH_RACKSTATION_BASE_DIR/$run/Data/Intensities/BaseCalls/$alignment_dir";
				}
				elsif($instrument eq 'miniseq'){
					#$alignment_dir = `grep -Eo \"AlignmentFolder>.+\\Alignment_?[0-9]*.+<\" $ABSOLUTE_HTDOCS_PATH$RS_BASE_DIR/data/$instrument_path/$run/CompletedJobInfo.xml`;
					#old fashioned replaced with autofs 21/12/2016
					$alignment_dir = $ssh->capture("grep -Eo \"AlignmentFolder>.+\\Alignment_?[0-9]*.+<\" $SSH_RACKSTATION_BASE_DIR/$run/CompletedJobInfo.xml");
					#print "$SSH_RACKSTATION_BASE_DIR/$run/CompletedJobInfo.xml-$alignment_dir-";
					$alignment_dir =~ /\\(Alignment_?\d*.+)<$/o;
					$alignment_dir = $1;
					$alignment_dir =~ s/\\/\//og;
					#print "$alignment_dir-";
					$alignment_dir = "$SSH_RACKSTATION_BASE_DIR/$run/$alignment_dir";
					#print "$alignment_dir-";
				}
				my ($sentence, $location, $stat_file, $samplesheet, $summary_file) = ('Copying Remaining Files To Network', "$SSH_RACKSTATION_BASE_DIR/$run/AnalysisLog.txt", 'EnrichmentStatistics.xml', "$SSH_RACKSTATION_BASE_DIR/$run/SampleSheet.csv", 'enrichment_summary.csv');
				if ($instrument eq 'miniseq') {($sentence, $location, $stat_file, $samplesheet, $summary_file) = ('Saving Completed Job Information to', "$SSH_RACKSTATION_BASE_DIR/$run/AnalysisLog.txt", 'EnrichmentStatistics.xml', "$alignment_dir/SampleSheetUsed.csv", 'summary.csv')}		
				
				
				
				#unknown in U2
				if ($value == 0) {
					#1st check MSR analysis is finished:
					#look for 'Copying Remaining Files To Network' in AnalysisLog.txt
					
					###TO BE CHANGED 4 MINISEQ
					### path to analysis log file under alignment folder - and sentence to look for changed
					### and check for Metrics....
					
					#print $ssh->capture("grep -e '$sentence' $location");exit;
					if ($ssh->capture("grep -e '$sentence' $location") ne '') {
					
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
						
						#my $alignment_dir = $ssh->capture("grep -Eo \"AlignmentFolder>.+\\Alignment[0-9]*<\" $SSH_RACKSTATION_BASE_DIR/$run/CompletedJobInfo.xml");
						#$alignment_dir =~ /\\(Alignment\d*)<$/o;
						#$alignment_dir = $1;
						#
						#my $noc_pf = &getMetrics("NumberOfClustersPF>[0-9]+<", $alignment_dir, $SSH_RACKSTATION_BASE_DIR, $run, $ssh);
						#my $noc_raw = &getMetrics("NumberOfClustersRaw>[0-9]+<", $alignment_dir, $SSH_RACKSTATION_BASE_DIR, $run, $ssh);
						#my $nodc = &getMetrics("NumberOfDuplicateClusters>[0-9]+<", $alignment_dir, $SSH_RACKSTATION_BASE_DIR, $run, $ssh);
						#my $nouc = &getMetrics("NumberOfUnalignedClusters>[0-9]+<", $alignment_dir, $SSH_RACKSTATION_BASE_DIR, $run, $ssh);
						#my $nouc_pf = &getMetrics("NumberOfUnalignedClustersPF>[0-9]+<", $alignment_dir, $SSH_RACKSTATION_BASE_DIR, $run, $ssh);
						#my $nouic = &getMetrics("NumberOfUnindexedClusters>[0-9]+<", $alignment_dir, $SSH_RACKSTATION_BASE_DIR, $run, $ssh);
						#my $nouic_pf = &getMetrics("NumberOfUnindexedClustersPF>[0-9]+<", $alignment_dir, $SSH_RACKSTATION_BASE_DIR, $run, $ssh);
						
						my $noc_pf = &getMetrics("NumberOfClustersPF>[0-9]+<", $alignment_dir, $ssh, $stat_file);
						my $noc_raw = &getMetrics("NumberOfClustersRaw>[0-9]+<", $alignment_dir, $ssh, $stat_file);
						my $nodc = &getMetrics("NumberOfDuplicateClusters>[0-9]+<", $alignment_dir, $ssh, $stat_file);
						my $nouc = &getMetrics("NumberOfUnalignedClusters>[0-9]+<", $alignment_dir, $ssh, $stat_file);
						my $nouc_pf = &getMetrics("NumberOfUnalignedClustersPF>[0-9]+<", $alignment_dir, $ssh, $stat_file);
						my $nouic = &getMetrics("NumberOfUnindexedClusters>[0-9]+<", $alignment_dir, $ssh, $stat_file);
						my $nouic_pf = &getMetrics("NumberOfUnindexedClustersPF>[0-9]+<", $alignment_dir, $ssh, $stat_file);
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
				if ($ssh->capture("grep -e '$id$number' $samplesheet") ne '') {
					$semaph = 1;
					#$query = "SELECT num_pat, id_pat FROM miseq_analysis WHERE run_id = '$run' AND num_pat = '$number' AND id_pat = '$id' GROUP BY num_pat, id_pat;";
					$query = "SELECT num_pat, id_pat FROM miseq_analysis WHERE type_analyse = '$analysis' AND num_pat = '$number' AND id_pat = '$id' GROUP BY num_pat, id_pat;";
					$res = $dbh->selectrow_hashref($query);
					if ($res) {print $link;U2_modules::U2_subs_1::standard_error('14', $q);}
					else {
						#we can proceed
						#validate analysis type
						if ($ssh->capture("grep -e '$manifest' $samplesheet")) {
							#ok
							$ok = 1;
							#search other patients in the samplesheet
							#print "grep -E \"^$PATIENT_IDS[0-9]+,\" $SSH_RACKSTATION_BASE_DIR/$key/SampleSheet.csv";
							my $char = ',';
							if ($instrument eq 'miniseq') {$char = '-'}
							#if ($instrument eq 'miseq') {							
							my $patient_list = $ssh->capture("grep -Eo \"^".$PATIENT_IDS."[0-9]+$char\" $samplesheet");
							$patient_list =~ s/\n//og;
							my %patients = map {$_ => 0} split(/$char/, $patient_list);
							%patients = %{U2_modules::U2_subs_2::check_ngs_samples(\%patients, $analysis, $dbh)};
							#above command replaces the whole block below
							##select patients/analysis not already recorded for this type of run (e.g. MiSeq-28), $query AND who is already basically recorded in U2, $query2
							#$query = "SELECT num_pat, id_pat FROM analyse_moleculaire WHERE type_analyse = '$analysis' AND ("; #num_pat = '$number' AND id_pat = '$id' GROUP BY num_pat, id_pat;";
							#my $query2 = "SELECT numero, identifiant FROM patient WHERE ";
							#my $count_hash = 0;
							#foreach my $totest (keys(%patients)) {
							#	$totest =~ /^$PATIENT_IDS\s*(\d+)$/o;						
							#	$query .= "(num_pat = '$2' AND id_pat = '$1') ";
							#	$query2 .= "(numero = '$2' AND identifiant = '$1') ";
							#	$count_hash++;
							#	if ($count_hash < keys(%patients)) {$query .= "OR ";$query2 .= "OR ";}								
							#}
							#$query .= ") GROUP BY num_pat, id_pat;";
							#$query2 .= ";";
							##print $query2;exit;
							#$sth = $dbh->prepare($query2);
							#$res = $sth->execute();
							##modify hash
							#
							#while (my $result = $sth->fetchrow_hashref()) {
							#	$patients{$result->{'identifiant'}.$result->{'numero'}} = 1; #tag existing patients
							#}
							#$sth = $dbh->prepare($query);
							#$res = $sth->execute();
							##cleanup hash
							#while (my $result = $sth->fetchrow_hashref()) {
							#	if (exists($patients{$result->{'id_pat'}.$result->{'num_pat'}})) {$patients{$result->{'id_pat'}.$result->{'num_pat'}} = 2} #remove patients with that type of analysis already recorded
							#}
							
							
							
							#foreach my $keys (sort keys (%patients)) {print $keys.$patients{$keys}.$q->br();}
							
							#build form
							print U2_modules::U2_subs_2::build_ngs_form($id, $number, $analysis, $run, $filtered, \%patients, 'import_illumina.pl', '2', $q, $alignment_dir, $ssh, $summary_file, $instrument);
							print $q->br().U2_modules::U2_subs_2::print_panel_criteria($q);
							#print $q->p("In addition to $id$number, I have found ".(keys(%patients)-1)." other patients eligible for import in U2 for this run ($run)."), $q->start_p(), $q->span("Please select those you are interested in"), "\n";
							#if ($filtered == '1') {print $q->span(" and specify your filtering options for each of them")}
							#print $q->span("."), $q->end_p();
							#
							#print $q->start_p(), $q->strong('You may not be able to select some patients. This means either that they are already recorded for that type of analysis or that they are not recorded in U2 yet. In this case, please insert them via the Excel file and reload the page.'), $q->end_p();
							#
							##Filtering or not?
							#my $filter = '';
							#if ($filtered == '1') {$filter = U2_modules::U2_subs_1::check_filter($q)}
							#	
							#
							#print 					$q->br(), $q->br(), $q->start_div({'align' => 'center'}), "\n",
							#	$q->button({'id' => "select_all_illumina_form_$run", 'value' => 'Unselect all', 'onclick' => "select_toggle('illumina_form_$run');"}), $q->br(), $q->br(),
							#	$q->start_form({'action' => 'import_illumina.pl', 'method' => 'post', 'class' => 'u2form', 'id' => "illumina_form_$run", 'onsubmit' => 'return illumina_form_submit();', 'enctype' => &CGI::URL_ENCODED}), "\n",
							#	$q->input({'type' => 'hidden', 'name' => 'step', 'value' => '2', form => "illumina_form_$run"}), "\n",
							#	$q->input({'type' => 'hidden', 'name' => 'analysis', 'value' => $analysis, form => "illumina_form_$run"}), "\n",
							#	$q->input({'type' => 'hidden', 'name' => 'run_id', 'value' => $run, form => "illumina_form_$run"}), "\n",
							#	$q->input({'type' => 'hidden', 'name' => 'sample', 'value' => "1_$id$number", form => "illumina_form_$run"}), "\n";
							#if ($filter ne '') {print $q->input({'type' => 'hidden', 'name' => '1_filter', 'value' => "$filter", form => "illumina_form_$run"}), "\n"}								
							#	
							#print					$q->start_fieldset(),
							#		$q->legend('Import '.ucfirst($instrument).' data'),
							#		$q->start_ol(), "\n";
							#		
							##new implementation to get an idea of the sequencing quality per patient
							##get last alignment dir
							##my $alignment_dir = $ssh->capture("grep -Eo \"AlignmentFolder>.+\\Alignment[0-9]*<\" $SSH_RACKSTATION_BASE_DIR/$run/CompletedJobInfo.xml");
							##$alignment_dir =~ /\\(Alignment\d*)<$/o;
							##$alignment_dir = "$SSH_RACKSTATION_BASE_DIR/$run/$1";
							#
							#
							#my $i = 2;
							#foreach my $sample (sort keys(%patients)) {
							#	#$sample =~ s/\n//og;
							#	if (($sample ne $id.$number) && ($patients{$sample} == 1)) {#other eligible patients
							#		print 					$q->start_li(), $q->start_div({'class' => 'container_div'}), $q->start_div({'class' => 'fixed'}), $q->input({'type' => 'checkbox', 'name' => "sample", 'class' => 'sample_checkbox', 'value' => $i."_$sample", 'checked' => 'checked', form => "illumina_form_$run"}, $sample), $q->end_div(), "\n";
							#		if ($filtered == '1') {
							#			print $q->start_div({'class' => 'fixed'}), "\n",
							#				$q->label({'for' => 'filter'}, 'Filter:'), "\n", $q->end_div(), $q->start_div({'class' => 'fixed'}), "\n",;
							#			print U2_modules::U2_subs_1::select_filter($q, $i.'_filter', "illumina_form_$run");
							#			print $q->end_div();
							#		}
							#		print &get_raw_data($alignment_dir, $sample, $ssh, $summary_file, $instrument), $q->end_div(), "\n";
							#	}
							#	elsif (($sample ne $id.$number) && ($patients{$sample} == 0)) {#unknown patient
							#		print 					$q->start_li(), $q->input({'type' => 'checkbox', 'name' => "sample", 'value' => $i."_$sample", 'disabled' => 'disabled', form => "illumina_form_$run"}, "$sample not yet recorded in U2. Please proceed if you want to import Illumina data."), "\n";
							#	}
							#	elsif (($sample ne $id.$number) && ($patients{$sample} == 2)) {#patient with a run already recorded
							#		print 					$q->start_li(), $q->input({'type' => 'checkbox', 'name' => "sample", 'value' => $i."_$sample", 'disabled' => 'disabled', form => "illumina_form_$run"}, "$sample has already a run recorded as $analysis."), "\n";
							#	}
							#	else {#original patient									
							#		print 					$q->start_li(), $q->div({'class' => 'fixed'}, $sample), "\n";
							#		if ($filtered == '1') {
							#			print $q->div({'class' => 'fixed'}, "Filter:"), $q->div({'class' => 'fixed'}, $filter), "\n",
							#		}
							#		print &get_raw_data($alignment_dir, $sample, $ssh, $summary_file, $instrument), "\n";
							#	}
							#	print	$q->end_li(), "\n";
							#	$i++;
							#}
							#
							#print		$q->end_ol(),
							#	$q->end_fieldset(),
							#	$q->br(),
							#	$q->submit({'value' => 'Import', 'class' => 'submit', form => "illumina_form_$run"}), $q->br(), $q->br(), "\n",
							#$q->end_form(), $q->end_div(), "\n",
							#$q->span('Criteria for FAIL:'), "\n",
							#$q->start_ul(), "\n",
							#	$q->li('% Q30 < '.$U2_modules::U2_subs_1::Q30), "\n",
							#	$q->li('% 50X bp < '.$U2_modules::U2_subs_1::PC50X), "\n",
							#	$q->li('Ts/Tv ratio < '.$U2_modules::U2_subs_1::TITV), "\n",
							#	$q->li('mean DOC < '.$U2_modules::U2_subs_1::MDOC), "\n",
							#$q->end_ul(), "\n";

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
				#$to_fill_table = $q->start_div({'class' => 'fented_noleft container'}).$q->start_table({'class' => 'great_table technical', 'id' => 'genotype'});
				#if ($res->{'analyste'} ne '') {$to_fill = $q->li("$analysis by $res->{'analyste'}, $res->{'date_analyse'}");$to_fill_table .= $q->caption("$analysis by $res->{'analyste'}, $res->{'date_analyse'}")."\n";}
				if ($res->{'analyste'} ne '') {$to_fill_table .= $q->caption("$analysis by $res->{'analyste'}, $res->{'date_analyse'}")."\n"}
				$to_fill_table .= $q->start_Tr().$q->th({'class' => 'left_general'}, 'Position').$q->th({'class' => 'left_general'}, 'Variant').$q->th({'class' => 'left_general'}, 'Status').$q->th({'class' => 'left_general'}, 'Allele').$q->th({'class' => 'left_general'}, 'Class').$q->th({'class' => 'left_general'}, 'Delete').$q->th({'class' => 'left_general'}, 'Status Link').$q->end_Tr()."\n";
				$query = "SELECT a.nom_c, a.statut, a.allele, b.type_segment, b.classe, c.nom FROM variant2patient a, variant b, segment c WHERE a.nom_c = b.nom AND a.nom_gene = b.nom_gene AND b.nom_gene = c.nom_gene AND b.num_segment = c.numero AND b.type_segment = c.type AND a.num_pat = '$number' AND a.id_pat = '$id' AND a.nom_gene[1] = '$gene' AND a.type_analyse = '$analysis' ORDER by b.nom_g $order;";	
				my $sth = $dbh->prepare($query);
				my $res2 = $sth->execute();
				my $j;
				while (my $result = $sth->fetchrow_hashref()) {
					$j++;
					#$to_fill .= $q->start_li({'id' => "v$j", 'class' => 'var'});
					$to_fill_table .= $q->start_Tr({'id' => "v$j", 'class' => 'var'}).$q->start_td();#.$q->td().$q->td().$q->td().$q->td().$q->td().$q->td().$q->td().$q->end_Tr();
					#if ($result->{'type_segment'} =~ /on/o) {$to_fill .= $q->span(ucfirst($result->{'type_segment'}));$to_fill_table .= $q->span(ucfirst($result->{'type_segment'}));}
					if ($result->{'type_segment'} =~ /on/o) {$to_fill_table .= $q->span(ucfirst($result->{'type_segment'}));}
					#$to_fill .= $q->span(" $result->{'nom'}: $result->{'nom_c'}, ").$q->span({'id' => "w$j"}, "$result->{'statut'}, allele: $result->{'allele'}, class: ").$q->span({'style' => "color:".U2_modules::U2_subs_1::color_by_classe($result->{'classe'}, $dbh).";"}, $result->{'classe'}."&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;").$q->img({'src' => $HTDOCS_PATH.'data/img/buttons/delete.png', 'class' => 'pointer text_img', 'width' => '15', height => '15', 'onclick' => "delete_var('$id$number', '$gene', '$analysis', '".uri_encode($result->{'nom_c'})."', 'v$j');"}).$q->span("&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;").$q->start_a({'href' => 'javascript:;', 'title' => 'click to modifiy status and/or alleles', 'onclick' => "createFormStatus('".uri_encode($result->{'nom_c'})."', '$gene', '$id$number', '$analysis', 'v$j', '$result->{'statut'}', '$result->{'allele'}');"}).$q->span({'class' => 'list'}, "Status&nbsp;").$q->img({'src' => $HTDOCS_PATH.'data/img/link_small.png', 'border' => '0', 'width' =>'15'}).$q->end_a().$q->end_li()."\n";
					$to_fill_table .= $q->span(" $result->{'nom'}").$q->end_td().$q->td($result->{'nom_c'}).$q->td({'id' => "wstatus$j"}, $result->{'statut'}).$q->td({'id' => "wallele$j"}, $result->{'allele'}).$q->td({'style' => "color:".U2_modules::U2_subs_1::color_by_classe($result->{'classe'}, $dbh).";"}, $result->{'classe'}).$q->start_td().$q->img({'src' => $HTDOCS_PATH.'data/img/buttons/delete.png', 'class' => 'pointer text_img', 'width' => '15', height => '15', 'onclick' => "delete_var('$id$number', '$gene', '$analysis', '".uri_encode($result->{'nom_c'})."', 'v$j');"}).$q->end_td().$q->start_td().$q->a({'href' => 'javascript:;', 'title' => 'click to modifiy status and/or alleles', 'onclick' => "createFormStatus('".uri_encode($result->{'nom_c'})."', '$gene', '$id$number', '$analysis', 'v$j', '$result->{'statut'}', '$result->{'allele'}');"}, "Modify").$q->end_td().$q->end_Tr()."\n";
				}
				#$to_fill .= $q->br();
				$to_fill_table .= $q->end_table().$q->end_div();
				
				$tech_val = U2_modules::U2_subs_1::translate_boolean($res->{'technical_valid'});
				$tech_val_class = U2_modules::U2_subs_1::translate_boolean_class($res->{'technical_valid'});
				$result_ana = U2_modules::U2_subs_1::translate_boolean($res->{'result'});
				$result_ana_class = U2_modules::U2_subs_1::translate_boolean_class($res->{'result'});
				$bio_val = U2_modules::U2_subs_1::translate_boolean($res->{'valide'});
				$bio_val_class = U2_modules::U2_subs_1::translate_boolean_class($res->{'valide'});
				
				#if ($res->{'technical_valid'} == 1) {$tech_val = '+'}
				#if ($res->{'result'} == 1) {$result_ana = '+'}
				#elsif ($res->{'result'}  eq '') {$result_ana = 'UNDEFINED'}
				#elsif ($res->{'result'} == 0) {$result_ana = '-'}			
				#if ($res->{'valide'} == 1) {$bio_val = '+'}
				
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
				$to_fill_table .= $q->start_Tr().$q->th({'class' => 'left_general'}, 'Position').$q->th({'class' => 'left_general'}, 'Variant').$q->th({'class' => 'left_general'}, 'Status').$q->th({'class' => 'left_general'}, 'Allele').$q->th({'class' => 'left_general'}, 'Class').$q->th({'class' => 'left_general'}, 'Delete').$q->th({'class' => 'left_general'}, 'Status Link').$q->end_Tr()."\n";
			}
				
			print $q->br(), $q->br(), $q->start_p({'class' => 'title'}), $q->start_big(), $q->start_strong(), $q->em($gene), $q->span(" $analysis for "),
				$q->span({'onclick' => "window.location = 'patient_file.pl?sample=$id$number'", 'class' => 'pointer'}, $id.$number), $q->span(':'), $q->end_strong(), $q->end_big(), $q->end_p(), $q->br(), $q->br(), "\n";
				
			if ($step == 2) {
				print $q->start_p(), $q->button({'value' => 'Delete analysis', 'onclick' => "delete_analysis('$id$number', '$analysis', '$gene');", 'class' => 'w3-button w3-blue'}), $q->span("&nbsp;&nbsp;&nbsp;&nbsp;WARNING: this will also delete associated variants."), $q->end_p(), "\n",
				$q->start_div({'id' => 'dialog-confirm', 'title' => 'Delete Analysis?', 'class' => 'hidden'}), $q->start_p(), $q->span('By clicking on the "Yes" button, you will delete permanently the complete analysis and the associated variants.'), $q->end_p(), $q->end_div(), $q->br(), $q->br(), "\n";
			
						
			
			
			
				my @js_params = ('createForm', $id.$number, $analysis);
				my ($js, $map) = U2_modules::U2_subs_2::gene_canvas($gene, $order, $dbh, \@js_params);
			
				###create an exon radio table
				###or no a canvas!!!! HTML5
				###ok this is relou as canvas don't accept links, so I put a transparent picture above with a map
				##
				##$query = "SELECT b.nom as gene, a.numero as numero, a.nom as nom, a.type as type FROM segment a, gene b WHERE a.nom_gene = b.nom AND b.nom[1] = '$gene' AND b.main = 't' AND a.nom NOT LIKE '%bis' order by a.start_g $order;";
				##my $sth = $dbh->prepare($query);
				##my $res = $sth->execute();
				##my $js = "	var canvas = document.getElementById(\"exon_selection\");
				##		var context = canvas.getContext(\"2d\");
				##		//context.drawImage(document.getElementById('transparent_image'), 0, 0);
				##		context.fillStyle = \"#000000\";
				##		context.font = \"bold 14px sans-serif\";
				##		context.strokeStyle = \"#FF0000\";
				##	";
				##my $map = "\n<map name='segment'>\n";
				##my ($acc, $i, $x_txt_intron, $y_txt_intron, $x_line_intron, $x_intron_exon, $y_line_intron, $y_up_exon, $x_txt_exon, $y_txt_exon) = ('', 0, 125, 19.5, 100, 150, 25, 12.5, 170, 30);
				##while (my $result = $sth->fetchrow_hashref()) {
				##	if ($i == 20) {$i = 0;$y_txt_intron += 50;$y_line_intron += 50;$y_txt_exon += 50;$y_up_exon += 50;$x_txt_intron = 125;$x_line_intron = 100;$x_intron_exon = 150;$x_txt_exon = 170;}
				##	if ($acc ne $result->{'gene'}[1]) {#new -> print acc
				##		$js.= "context.fillText(\"$result->{'gene'}[1]\", 0, $y_line_intron);";
				##		$acc = $result->{'gene'}[1];
				##	}
				##	if ($result->{'type'} ne 'exon') { #for intron, 5UTR, 3UTR=> print name of segment and a line + a map (left, top, right, bottom)
				##		#my $html_id = 'intron';
				##		if ($result->{'type'} ne 'intron') {$js .= "context.fillText(\"$result->{'nom'}\", ".($x_txt_intron-15).", $y_txt_intron);";}#$html_id =''}
				##		else {$js .= "\t\t\t\t\tcontext.fillText(\"$result->{'nom'}\", $x_txt_intron, $y_txt_intron);"}
				##		$js .= "context.moveTo($x_line_intron,$y_line_intron);
				##			context.lineTo($x_intron_exon,$y_line_intron);
				##			context.stroke();\n";
				##		#$js .=  "\$( \"#$html_id$result->{'nom'}\" )
				##		#		.button()
				##		#		.click(function() {
				##		#			var segment = \"$html_id$result->{'nom'}\";
				##		#		      \$(\"#dialog-form\").dialog(\"open\");
				##		#		});\n";
				##		$map .= "<area shape = 'rect' coords = '".($x_line_intron-100).",".($y_line_intron-25).",".($x_line_intron-50).",".($y_line_intron+25)."' onclick = 'createForm(\"$result->{'type'}\", \"$result->{'nom'}\", \"$result->{'numero'}\", \"$gene\", \"$acc\", \"$id$number\", \"$analysis\");' href = 'javascript:;'/>\n";
				##		$i++;
				##		$x_line_intron += 100;
				##		$x_txt_intron += 100;
				##		
				##	}
				##	elsif ($result->{'type'} eq 'exon') { #for exons print name of segment and a box + a map (left, top, right, bottom)
				##		$js .= "\t\t\t\t\tcontext.fillText(\"$result->{'nom'}\", $x_txt_exon, $y_txt_exon);
				##			context.strokeRect($x_intron_exon,$y_up_exon,50,25);\n";
				##		$map .= "<area shape = 'rect' coords = '".($x_intron_exon-100).",".($y_line_intron-25).",".($x_intron_exon-50).",".($y_line_intron+25)."' onclick = 'createForm(\"$result->{'type'}\", \"$result->{'nom'}\", \"$result->{'numero'}\", \"$gene\", \"$acc\", \"$id$number\", \"$analysis\");' href = 'javascript:;'/>\n";
				##		$i++;
				##		$x_intron_exon += 100;
				##		$x_txt_exon += 100;					
				##	}
				##}
				##
				##
				###secondary acc#
				##$query = "SELECT b.nom as gene, a.numero as numero, a.nom as nom, a.type as type FROM segment a, gene b WHERE a.nom_gene = b.nom AND nom_gene[1] = '$gene' AND b.main = 'f' AND (a.start_g NOT IN (SELECT a.start_g FROM segment a, gene b WHERE a.nom_gene = b.nom AND b.main = 't' AND b.nom[1] = '$gene') OR a.end_g NOT IN (SELECT a.end_g FROM segment a, gene b WHERE a.nom_gene = b.nom AND b.main = 't' AND b.nom[1] = '$gene'));";
				##$sth = $dbh->prepare($query);
				##$res = $sth->execute();
				###reinitialize - change line - we need to check if exons follow
				##($acc, $i, $x_txt_intron, $y_txt_intron, $x_line_intron, $x_intron_exon, $y_line_intron, $y_up_exon, $x_txt_exon, $y_txt_exon) = ('', 0, 125, $y_txt_intron, 100, 150, $y_line_intron, $y_up_exon, 170, $y_txt_exon);
				##my ($num, $type);
				##while (my $result = $sth->fetchrow_hashref()) {
				##	if (($result->{'type'} eq 'intron' && $result->{'numero'} > $num)) {###JUMP-non contiguous segment
				##		$x_intron_exon += 100;
				##		$x_txt_exon += 100;
				##		if ($type eq 'exon') {$x_txt_intron += 100;$x_line_intron += 100}
				##	}
				##	elsif ($result->{'type'} eq 'exon' && $type eq 'exon') {$x_txt_intron += 100;$x_line_intron += 100} #2 exons
				##	$num = $result->{'numero'};
				##	$type = $result->{'type'};
				##	if ($i == 20) {$i = 0;$y_txt_intron += 50;$y_line_intron += 50;$y_txt_exon += 50;$y_up_exon += 50;$x_txt_intron = 125;$x_line_intron = 100;$x_intron_exon = 150;$x_txt_exon = 170;}
				##	if ($acc ne $result->{'gene'}[1]) {#new -> print acc
				##		$i = 0;$y_txt_intron += 50;$y_line_intron += 50;$y_txt_exon += 50;$y_up_exon += 50;$x_txt_intron = 125;$x_line_intron = 100;$x_intron_exon = 150;$x_txt_exon = 170;
				##		$js.= "context.fillText(\"$result->{'gene'}[1]\", 0, $y_line_intron);";
				##		$acc = $result->{'gene'}[1];
				##	}
				##	if ($result->{'type'} ne 'exon') { #for intron, 5UTR, 3UTR=> print name of segment and a line + a map (left, top, right, bottom)
				##		if ($result->{'type'} ne 'intron') {$js .= "context.fillText(\"$result->{'nom'}\", ".($x_txt_intron-15).", $y_txt_intron);"}
				##		else {$js .= "\t\t\t\t\tcontext.fillText(\"$result->{'nom'}\", $x_txt_intron, $y_txt_intron);"}
				##		$js .= "context.moveTo($x_line_intron,$y_line_intron);
				##			context.lineTo($x_intron_exon,$y_line_intron);
				##			context.stroke();\n";
				##		$map .= "<area shape = 'rect' coords = '".($x_line_intron-100).",".($y_line_intron-25).",".($x_line_intron-50).",".($y_line_intron+25)."' onclick = 'createForm(\"$result->{'type'}\", \"$result->{'nom'}\", \"$result->{'numero'}\", \"$gene\", \"$acc\", \"$id$number\", \"$analysis\");' href = 'javascript:;'/>\n";
				##		$i++;
				##		$x_line_intron += 100;
				##		$x_txt_intron += 100;
				##		
				##	}
				##	elsif ($result->{'type'} eq 'exon') { #for exons print name of segment and a box + a map (left, top, right, bottom)
				##		$js .= "\t\t\t\t\tcontext.fillText(\"$result->{'nom'}\", $x_txt_exon, $y_txt_exon);
				##			context.strokeRect($x_intron_exon,$y_up_exon,50,25);\n";
				##		$map .= "<area shape = 'rect' coords = '".($x_intron_exon-100).",".($y_line_intron-25).",".($x_intron_exon-50).",".($y_line_intron+25)."' onclick = 'createForm(\"$result->{'type'}\", \"$result->{'nom'}\", \"$result->{'numero'}\", \"$gene\", \"$acc\", \"$id$number\", \"$analysis\");' href = 'javascript:;'/>\n";
				##		$i++;
				##		$x_intron_exon += 100;
				##		$x_txt_exon += 100;					
				##	}
				##}
				##
				##
				##
				##$map .= "</map>\n";
				
				#my $js = "	var canvas = document.getElementById(\"exon_selection\");
				#		var context = canvas.getContext(\"2d\");
				#		//context.drawImage(document.getElementById('transparent_image'), 0, 0);
				#		context.font = \"bold 14px sans-serif\";
				#		context.fillText(\"NM_001145853\", 0, 25);
				#		context.fillText(\"1\", 125, 19.5);
				#		context.strokeStyle = \"#FF0000\";
				#		context.moveTo(100,25);
				#		context.lineTo(150,25);					
				#		context.stroke();					
				#		//context.fillText(\"1\", 125, 19.5);
				#		context.strokeRect(150,12.5,50,25);
				#		context.fillText(\"1\", 170, 30);";
				#print $q->start_div({'class' => 'container'}), "\n<map name='segment'><area shape='rect' coords='0,0,1100,500' href='/U2/'/></map>\n<canvas class=\"ambitious\" width = \"1100\" height = \"500\" id=\"exon_selection\">Change web browser for a more recent please!</canvas>", $q->img({'src' => $HTDOCS_PATH.'data/img/transparency.png', 'usemap' => '#segment', 'class' => 'fented', 'id' => 'transparent_image'}), $q->end_div(), "\n", $q->script({'type' => 'text/javascript'}, $js);
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
			
			
			
			#print $q->start_ul({'id' => 'validations'}), "\n",
			#			$q->start_li(),
			#				$q->span("Technical validation: "), $q->span({'id' => 'technical_valid', 'class' => $tech_val_class}, $tech_val), "\n";
			if ($tech_val ne '+') {
				print $q->span("&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"), $q->button({'id' => 'technical_valid_2', 'value' => 'Validate', 'onclick' => "validate('$id$number', '$gene', '$analysis', 'technical_valid');", 'class' => 'w3-button w3-blue'});
			}
			print
					$q->end_td(), "\n",
					$q->start_td({'class' => 'td_border'}), "\n",
						$q->span({'id' => 'result', 'class' => $result_ana_class}, $result_ana), "\n";
			#print $q->end_li(),
			#	$q->start_li(),
			#		$q->span("Analysis result: "), $q->span({'id' => 'result', 'class' => $result_ana_class}, $result_ana), "\n";
			if ($user->isReferee() == 1) {
				if ($result_ana eq 'UNDEFINED') {
					print $q->start_span({'id' => 'result_2'}), $q->span("&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"), $q->button({'value' => 'Negative', 'onclick' => "validate('$id$number', '$gene', '$analysis', 'negatif');", 'class' => 'w3-button w3-blue'}), $q->span("&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"), $q->button({'value' => 'Positive', 'onclick' => "validate('$id$number', '$gene', '$analysis', 'positif');", 'class' => 'w3-button w3-blue'}),  $q->end_span();
				}
			}
			print
					$q->end_td(), "\n",
					$q->start_td({'class' => 'td_border'}), "\n",
						$q->span({'id' => 'valide', 'class' => $bio_val_class}, $bio_val), "\n";
			#print	$q->end_li(),
			#	$q->start_li(),
			#		$q->span("Biological validation: "), $q->span({'id' => 'valide', 'class' => $bio_val_class}, $bio_val), "\n";
			if ($user->isValidator() == 1) {
				if ($bio_val ne '+') {
					print $q->span("&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"), $q->button({'id' => 'valide_2', 'value' => 'Validate', 'onclick' => "validate('$id$number', '$gene', '$analysis', 'valide');", 'class' => 'w3-button w3-blue'});
				}
			}
			print
					$q->end_td(), "\n",
					$q->start_td({'class' => 'td_border'}), "\n",
						$q->button({'value' => 'Jump to genotype view', 'onclick' => "window.location = 'patient_genotype.pl?sample=$id$number&gene=$gene';", 'class' => 'w3-button w3-blue'}),
					$q->end_td(), "\n",
				$q->end_Tr(), "\n",
			$q->end_table(), "\n",
			$q->end_div(), "\n";
			#print	$q->end_li(),
			#	$q->start_li(),
			#		$q->button({'value' => 'Jump to genotype view', 'onclick' => "window.location = 'patient_genotype.pl?sample=$id$number&gene=$gene';"}),
			#	$q->end_li(),
			#		$q->end_ul(), "\n",
			#	$q->end_div(), "\n";
			
		}
		#$html .= $q->span("&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;").$q->button({'value' => 'Validate', 'onclick' => "validate('$id', '$number', 'USH2A', 'SANGER', 'technical');"});
	}
	#elsif ($step == 3) {
	#	my $analysis = U2_modules::U2_subs_1::check_analysis($q, $dbh);
	#	my ($gene, $second_name) = U2_modules::U2_subs_1::check_gene($q, $dbh);
	#	my $date = U2_modules::U2_subs_1::get_date();
	#	#record analysis
	#	#1st, check if experience already exists
	#	my ($tech_val, $result_ana, $bio_val) = ("NO", "UNDEFINED", "NO");
	#	my $query = "SELECT num_pat, analyste, date_analyse, technical_valid, result, valide FROM analyse_moleculaire WHERE num_pat = '$number' AND id_pat = '$id' AND nom_gene[1] = '$gene' AND type_analyse = '$analysis';";
	#	my $res = $dbh->selectrow_hashref($query);
	#	my $to_fill = '';
	#	
	#	if ($res->{'num_pat'} ne '') { #print variants already recorded
	#		if ($res->{'analyste'} ne '') {$to_fill = $q->li("$analysis by $res->{'analyste'}, $res->{'date_analyse'}")}
	#		$query = "SELECT a.nom_c, a.statut, a.allele, b.type_segment, b.classe, c.nom FROM variant2patient a, variant b, segment c WHERE a.nom_c = b.nom AND a.nom_gene = b.nom_gene AND b.nom_gene = c.nom_gene AND b.num_segment = c.numero AND b.type_segment = c.type AND a.num_pat = '$number' AND a.id_pat = '$id' AND a.nom_gene[1] = '$gene' AND a.type_analyse = '$analysis' ORDER by b.nom_g $order;";	
	#		my $sth = $dbh->prepare($query);
	#		my $res2 = $sth->execute();
	#		my $j;
	#		while (my $result = $sth->fetchrow_hashref()) {
	#			$j++;
	#			$to_fill .= $q->start_li({'id' => "v$j", 'class' => 'var'});
	#			if ($result->{'type_segment'} =~ /on/o) {$to_fill .= $q->span(ucfirst($result->{'type_segment'}))}				
	#			$to_fill .= $q->span("$result->{'nom'}: $result->{'nom_c'}, $result->{'statut'}, allele: $result->{'allele'}, classe: ").$q->span({'style' => "color:".U2_modules::U2_subs_1::color_by_classe($result->{'classe'}, $dbh).";"}, $result->{'classe'}."&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;").$q->img({'src' => $HTDOCS_PATH.'data/img/buttons/delete.png', 'class' => 'pointer text_img', 'width' => '15', height => '15', 'onclick' => "delete_var('$id$number', '$gene', '$analysis', '".uri_encode($result->{'nom_c'})."', 'v$j');"}).$q->end_li()."\n";
	#		}
	#		$to_fill .= $q->br();
	#		if ($res->{'technical_valid'} == 1) {$tech_val = 'YES'}
	#		if ($res->{'result'} == 1) {$result_ana = 'YES'}
	#		elsif ($res->{'result'}  eq '') {$result_ana = 'UNDEFINED'}
	#		elsif ($res->{'result'} == 0) {$result_ana = 'NO'}			
	#		if ($res->{'valide'} == 1) {$bio_val = 'YES'}
	#		
	#		#print $res->{'result'};
	#	}
	#	
	#}
}
else {U2_modules::U2_subs_1::standard_error('13', $q)}

##Basic end of USHVaM 2 perl scripts:

U2_modules::U2_subs_1::standard_end_html($q);

print $q->end_html();

exit();

##End of Basic end


##specific subs for current script

sub get_raw_data {
	my ($dir, $sample, $ssh, $file, $instrument) = @_;
	#we want - miseq
	#Percent Q30:,
	#Target coverage at 50X:,
	#SNV Ts/Tv ratio:,
	#Mean region coverage depth:,
	my ($q30_expr, $x50_expr, $tstv_expr, $doc_expr, $num_reads);
	
	if ($instrument eq 'miseq') {
		($q30_expr, $x50_expr, $tstv_expr, $doc_expr, $num_reads) = ('Percent Q30:,', 'Target coverage at 50X:,', 'SNV Ts/Tv ratio:,', 'Mean region coverage depth:,', 'Padded target aligned reads:,');
	}
	elsif ($instrument eq 'miniseq') {
		($q30_expr, $x50_expr, $tstv_expr, $doc_expr, $num_reads) = ('Percent Q30,', 'Target coverage at 50X,', 'SNV Ts/Tv ratio,', 'Mean region coverage depth,', 'Padded target aligned reads,');
	}
	
	my $q30 = &get_raw_detail($dir, $sample, $ssh, $q30_expr, $file);
	my $x50 = &get_raw_detail($dir, $sample, $ssh, $x50_expr, $file);
	my $tstv = &get_raw_detail($dir, $sample, $ssh, $tstv_expr, $file);
	my $doc = &get_raw_detail($dir, $sample, $ssh, $doc_expr, $file);
	my $ontarget_reads = &get_raw_detail($dir, $sample, $ssh, $num_reads, $file);
	#return ($q30, $x50, $tstv, $doc);
	my $criteria = '';
	if ($q30 < $U2_modules::U2_subs_1::Q30) {$criteria .= ' (Q30 &le; '.$U2_modules::U2_subs_1::Q30.') '}	
	if ($x50 < $U2_modules::U2_subs_1::PC50X) {$criteria .= ' (50X % &le; '.$U2_modules::U2_subs_1::PC50X.') '}
	if ($tstv < $U2_modules::U2_subs_1::TITV) {$criteria .= ' (Ts/Tv &le; '.$U2_modules::U2_subs_1::TITV.') '}
	if ($doc < $U2_modules::U2_subs_1::MDOC) {$criteria .= ' (mean DOC &le; '.$U2_modules::U2_subs_1::MDOC.') '}
	if ($ontarget_reads < $U2_modules::U2_subs_1::NUM_ONTARGET_READS) {$criteria .= ' (on target reads &lt; '.$U2_modules::U2_subs_1::NUM_ONTARGET_READS.') '}
	if ($criteria ne '') {return $q->div({'class' => 'fixed_200 red'}, "FAILED $criteria")}
	else {return $q->div({'class' => 'fixed_200 green'}, 'PASS')}
}

sub get_raw_detail {
	my ($dir, $sample, $ssh, $expr, $file) = @_;
	#print "grep -e \"$expr\" $dir/".$sample."_S*.$file";
	my $data = $ssh->capture("grep -e \"$expr\" $dir/".$sample."_S*.$file");
	#print "-$data-<br/>";
	if ($data =~ /$expr([\d\.]+)[%\s]{0,2}$/) {$data = $1}
	else {print "pb with $expr:$data:"}
	#print "_".$data."_<br/>";
	return $data,;
}


sub insert_analysis {
	my ($number, $id, $gene, $analysis, $date, $name, $neg, $dbh) = @_;
	#get #acc for all isoforms;
	my $query = "SELECT nom FROM gene WHERE nom[1] = '$gene';";
	my $sth = $dbh->prepare($query);
	my $res = $sth->execute();
	while (my $result = $sth->fetchrow_hashref()) {
		my $insert = "INSERT INTO analyse_moleculaire VALUES ('$number', '$id', '{\"$result->{'nom'}[0]\",\"$result->{'nom'}[1]\"}', '$analysis', 'f', NULL, '$date', NULL, NULL, '".$name."', NULL, NULL, '$neg');";
		$dbh->do($insert);
		#print $insert;
	}
}

sub getMetrics {
	my ($reg, $alignment_dir, $ssh, $file) = @_;	
	#my $grep = $ssh->capture("grep -Eo -m 1 \"$reg\" $SSH_RACKSTATION_BASE_DIR/$run/Data/Intensities/BaseCalls/$alignment_dir/EnrichmentStatistics.xml");
	#print "grep -Eo -m 1 \"$reg\" $alignment_dir/$file";
	my $grep = $ssh->capture("grep -Eo -m 1 \"$reg\" $alignment_dir/$file");
	$grep =~ />(\d+)<$/o;
	return $1;
}
