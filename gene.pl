BEGIN {delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV', 'PATH'};}

use strict;
use URI::Escape;
use U2_modules::U2_users_1;
use U2_modules::U2_init_1;
use U2_modules::U2_subs_1;
use U2_modules::U2_subs_2;
use U2_modules::U2_subs_3;
use Data::Dumper;


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
#		Gene specific page


##Custom init of USHVaM 2 perl scripts: slightly modified with custom js, jquery ui dalliance browser
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
my $DATABASES_PATH = $config->DATABASES_PATH();
my $DALLIANCE_DATA_DIR_URI = $config->DALLIANCE_DATA_DIR_URI();

my @styles = ($CSS_PATH.'font-awesome.min.css', $CSS_PATH.'w3.css', $CSS_DEFAULT, $CSS_PATH.'jquery-ui-1.12.1.min.css', $CSS_PATH.'form.css', $CSS_PATH.'jquery.alerts.css');

my $q = new CGI;

my $dbh = DBI->connect(    "DBI:Pg:database=$DB;host=$HOST;",
                        $DB_USER,
                        $DB_PASSWORD,
                        {'RaiseError' => 1}
                ) or die $DBI::errstr;

my $js = "
	function showVariants(type, nom, numero, gene, acc_no, order, nulle) {
		\$(\'area\').css(\'cursor\', \'progress\');
		\$(\'html\').css(\'cursor\', \'progress\');
		\$.ajax({
			type: 'POST',
			url: 'ajax.pl',
			data: {type: type, nom: nom, numero: numero, gene: gene, accession: acc_no, order: order, asked: \'var_list\'}
			})
		.done(function(msg) {
			\$(\"#fill_in\").html(msg);
			setDialog(msg, type, nom);
			\$(\'area\').css(\'cursor\', \'auto\');
			\$(\'html\').css(\'cursor\', \'auto\');
		});
	}
	function setDialog(msg, type, nom) {
		\$(\"#dialog-form\").dialog({
		//var \$dialog = \$(\'<div></div>\')
		//	.html(msg)
		//	.dialog({
			    autoOpen: false,
			    title: \'Variants lying in \' + type + \' \' + nom + \':\' + \$(\"#new_variant\").val(),
			    width: 650,
			    buttons: {
			       \"Create a variant using VariantValidator\": function() {
						\$(\'html\').css(\'cursor\', \'progress\');
						\$(\'.ui-dialog\').css(\'cursor\', \'progress\');
						var nom_c = \$(\"#new_variant\").val();
						\$(\"#title_form_var\").append(\"&nbsp;&nbsp;&nbsp;&nbsp;PLEASE WAIT WHILE CREATING VARIANT\");
						\$(\"#creation_form :input\").prop(\"disabled\", true);
						\$.ajax({
							type: \"POST\",
							url: \"variant_input_vv.pl\",
							data: {type: \$(\"#type\").val(), nom: \$(\"#nom\").val(), numero: \$(\"#numero\").val(), gene: \$(\"#gene\").val(), accession: \$(\"#acc_no\").val(), step: 2, new_variant: \$(\"#new_variant\").val(), nom_c: nom_c, ng_accno: \$(\"#ng_accno\").val(), single_var: \'y\'}
					    })
				       .done(function(msg) {
							if (msg !== '') {\$(\"#created_variant\").append(msg)};
							\$(\'.ui-dialog\').css(\'cursor\', \'default\');
							\$(\'html\').css(\'cursor\', \'default\');
							\$(\".ui-dialog-content\").dialog(\"close\"); //YES - CLOSE ALL DIALOGS
				       });
			       },
			       Cancel: function() {
				       \$(this).dialog(\"close\");
			       }
		       }
		});
		\$(\"#dialog-form\").dialog(\'open\');
		//\$(\'.ui-dialog\').zIndex(\'1002\');
		//}
	}
	function showAllVariants(gene, sort_value, sort_type, freq, dynamic) {
		\$(\'#page\').css(\'cursor\', \'progress\');
		\$(\'.w3-button\').css(\'cursor\', \'progress\');
		\$.ajax({
			type: 'POST',
			url: 'ajax.pl',
			data: {gene: gene, sort_value: sort_value, sort_type: sort_type, freq: freq, asked: \'var_all\', css_class: dynamic}
			})
		.done(function(msg) {
			\$(\'#vars\').html(msg);
			if (dynamic) {\$("." + dynamic).css(\'background-color\', \'#FFFF66\');}
			\$(\'#page\').css(\'cursor\', \'default\');
			\$(\'.w3-button\').css(\'cursor\', \'default\');
		});
	}";
my $user = U2_modules::U2_users_1->new();

if ($user->isPublic != 1) {
	$js .= "function chooseSortingType(gene) {
		var \$dialog = \$(\'<div></div>\')
			.html(\"<p>Choose how your variants will be sorted:</p><ul><li><a href = \'gene.pl?gene=\"+gene+\"&info=all_vars&sort=classe\' target = \'_self\'>Pathogenic class</a></li><li><a href = \'gene.pl?gene=\"+gene+\"&info=all_vars&sort=type_adn\' target = \'_self\'>DNA type (subs, indels...)</a></li><li><a href = \'gene.pl?gene=\"+gene+\"&info=all_vars&sort=type_prot\' target = \'_self\'>Protein type (missense, silent...)</a></li><li><a href = \'gene.pl?gene=\"+gene+\"&info=all_vars&sort=type_arn\' target = \'_self\'>RNA type (neutral / altered)</a></li><li><a href = \'gene.pl?gene=\"+gene+\"&info=all_vars&sort=taille\' target = \'_self\'>Variant size (get only large rearrangements)</a></li><li><a href = \'gene.pl?gene=\"+gene+\"&info=all_vars&sort=orphan\' target = \'_self\'>Orphan variants (not linked to any sample)</a></li><li><a href = \'https://pp-gb-gen.iurc.montp.inserm.fr/perl/led/engine.pl?research=\"+gene+\"\' target = \'_blank\'>LED rare variants</a></li></ul>\")
			.dialog({
			    autoOpen: false,
			    title: \'U2 choice\',
			    width: 450,
			});
		\$dialog.dialog(\'open\');
		\$(\'.ui-dialog\').zIndex(\'1002\');
	}"
}
else {
	$js .= "function chooseSortingType(gene) {
		var \$dialog = \$(\'<div></div>\')
			.html(\"<p>Choose how your variants will be sorted:</p><ul><li><a href = \'gene.pl?gene=\"+gene+\"&info=all_vars&sort=orphan\' target = \'_self\'>Variants in MobiDetails</a></li><li><a href = \'https://pp-gb-gen.iurc.montp.inserm.fr/perl/led/engine.pl?research=\"+gene+\"\' target = \'_blank\'>LED rare variants</a></li></ul>\")
			.dialog({
			    autoOpen: false,
			    title: \'MD choice\',
			    width: 450,
			});
		\$dialog.dialog(\'open\');
		\$(\'.ui-dialog\').zIndex(\'1002\');
	}"
}
my $soft = 'U2';
if ($user->isPublic() == 1) {$soft = 'MD'}
print $q->header(-type => 'text/html', -'cache-control' => 'no-cache'),
	$q->start_html(-title=>"$soft Gene page",
                        -lang => 'en',
                        -style => {-src => \@styles},
                        -head => [
				$q->Link({-rel => 'icon',
					-type => 'image/gif',
					-href => $HTDOCS_PATH.'data/img/animated_favicon1.gif'}),
				$q->Link({-rel => 'search',
					-type => 'application/opensearchdescription+xml',
					-title => "$soft search engine",
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
				-src => $JS_PATH.'jquery-ui-1.12.1.min.js', 'defer' => 'defer'},
				{-language => 'javascript',
				-src => $JS_PATH.'jquery.alerts.js', 'defer' => 'defer'},
				{-language => 'javascript',
				-src => $JS_PATH.'dalliance_v0.13/build/dalliance-compiled.js', 'defer' => 'defer'},
                                {-language => 'javascript',
                                -src => $JS_PATH.'jquery.autocomplete.min.js', 'defer' => 'defer'},
				$js,
                                {-language => 'javascript',
                                -src => $JS_DEFAULT, 'defer' => 'defer'}],
                        -encoding => 'ISO-8859-1');




if ($user->isPublic() == 1) {U2_modules::U2_subs_1::public_begin_html($q, $user->getName(), $dbh)}
else {U2_modules::U2_subs_1::standard_begin_html($q, $user->getName(), $dbh)}

##end of init

#hg38 transition variable for postgresql 'start_g' segment field
my ($postgre_start_g, $postgre_end_g) = ('start_g', 'end_g');  #hg19 style


my $ncbi_url = 'http://www.ncbi.nlm.nih.gov/nuccore/';

if ($q->param('gene') && $q->param('info') eq 'general') {
	my ($gene, $second_name) = U2_modules::U2_subs_1::check_gene($q, $dbh);


	#my ($pli, $prec, $pnull) = ('No pLi*', 'No pRec*', 'No pNull*');
	#if (U2_modules::U2_subs_1::test_mygene() == 1) {
	#	#use mygene.info REST API
	#	my $gene_api = $gene;
	#	if ($gene eq 'GPR98') {$gene_api = 'ADGRV1'}
	#	my $mygene = U2_modules::U2_subs_1::run_mygene($gene_api, 'exac.all', $user->getEmail());
	#	if ($mygene && $mygene->{'hits'}->[0]->{'exac'}->{'all'}->{'p_li'} ne '') {
	#		$pli = sprintf('%.6f', $mygene->{'hits'}->[0]->{'exac'}->{'all'}->{'p_li'});
	#		$prec = sprintf('%.6f', $mygene->{'hits'}->[0]->{'exac'}->{'all'}->{'p_rec'});
	#		$pnull = sprintf('%.6f', $mygene->{'hits'}->[0]->{'exac'}->{'all'}->{'p_null'});
	#	}
	#	#else {print $mygene->{'hits'}->[0]->{'exac'}."-"}
	#	#print Dumper($mygene->{'hits'}->[0]->{'exac'}->{'all'}->{'p_li'});
	#}
	#directly get gnomad oe
	my ($synoe, $misoe, $lofoe) = ('No Syn oe*', 'No Mis oe*', 'No Lof oe*');
	my $synoel = my $synoeu = my $misoel = my $misoeu = my $lofoel = my $lofoeu = 'NA';
	open GNOMAD, "<".$DATABASES_PATH."/gnomad/gnomad.v2.1.1.lof_metrics.by_gene.txt" or die $!;
	while (<GNOMAD>) {
		if (/^$gene\s+/) {
			my @line = split(/\t/, $_);
			($synoe, $misoe, $lofoe, $synoel, $synoeu, $misoel, $misoeu, $lofoel, $lofoeu) = ($line[13], $line[4], $line[23], $line[24], $line[25], $line[26], $line[27], $line[28], $line[29]);
			last;
		}
	}

	my $query = "SELECT * FROM gene WHERE nom[1] = '$gene' ORDER BY main DESC;";
	#my $order = 'ASC';
	my $order = U2_modules::U2_subs_1::get_strand($gene, $dbh);
	my $sth = $dbh->prepare($query);
	my $res = $sth->execute();
	my $chr;
	if ($res ne '0E0') {

		while (my $result = $sth->fetchrow_hashref()) {
			if ($result->{'main'} == 1) {

				U2_modules::U2_subs_1::gene_header($q, 'general_info', $gene, $user);

				$chr = $result->{'chr'};
				print $q->start_p({'class' => 'title w3-xlarge'}), $q->start_big(), $q->start_strong(), $q->em({'onclick' => "gene_choice('$gene');", 'class' => 'pointer', 'title' => 'click to get somewhere'}, $gene), $q->span(' main accession: '),
					$q->span({'onclick' => "window.open('$ncbi_url$result->{'nom'}[1].$result->{'acc_version'}', '_blank')", 'class' => 'pointer', 'title' => 'click to open Genbank in new tab'}, "$result->{'nom'}[1].$result->{'acc_version'}"),
					$q->br(), $q->br(), $q->span("($second_name / "), $q->span({'onclick' => "window.open('http://grch37.ensembl.org/Homo_sapiens/Transcript/Summary?db=core;t=$result->{'enst'}', '_blank')", 'class' => 'pointer', 'title' => 'click to open Ensembl in new tab'}, $result->{'enst'}), $q->span(')'),
					$q->end_strong(), $q->end_big(), $q->end_p(), "\n";

					my $ng_td = $q->span({'onclick' => "window.open('$ncbi_url$result->{'acc_g'}', '_blank')", 'class' => 'pointer', 'title' => 'click to open Genbank in new tab'}, $result->{'acc_g'});
					if ($result->{'acc_g'} eq 'NG_000000.0') {$ng_td = $q->span("No NG accession number. Mutalyzer accession: $result->{'mutalyzer_acc'}")}

					print U2_modules::U2_subs_3::add_variant_button($q, $gene, $result->{'nom'}[1], $result->{'acc_g'}),
					$q->start_div({'class' => 'w3-responsive', 'id' => 'single_gene_table'}), "\n",
					$q->start_table({'class' => 'w3-table w3-striped w3-bordered w3-centered'}), $q->caption("Gene info table:"),#technical ombre peche
					$q->start_Tr(), "\n",
						$q->th({'class' => 'left_general'}, 'Chr'), "\n",
						$q->th({'class' => 'left_general'}, 'Strand'), "\n",
						$q->th({'class' => 'left_general'}, 'Protein name'), "\n",
						$q->th({'class' => 'left_general'}, 'Genomic Accession #'), "\n",
						$q->th({'class' => 'left_general'}, "Synonymous <br/>obs/exp* (CI)"), "\n",
						$q->th({'class' => 'left_general'}, "Missense <br/>obs/exp* (CI)"), "\n",
						$q->th({'class' => 'left_general'}, "Loss of function <br/>obs/exp* (CI)"), "\n",
						#$q->th({'class' => 'left_general'}, 'pLi*'), "\n",
						#$q->th({'class' => 'left_general'}, 'pRec*'), "\n",
						#$q->th({'class' => 'left_general'}, 'pNull*'), "\n",
					$q->end_Tr(), "\n",
					$q->start_Tr(), "\n",
						$q->start_td(), $q->span("chr$chr"), $q->end_td(), "\n",
						$q->start_td(), $q->span($result->{'brin'}), $q->end_td(), "\n",
						$q->start_td(), $q->span("$result->{'nom_prot'} ($result->{'short_prot'})"), $q->end_td(), "\n",
						$q->start_td(), $q->span($ng_td), $q->end_td(), "\n",
						$q->start_td(), $q->span(sprintf('%.2f',$synoe)."<br/>(".sprintf('%.2f',$synoel)."-".sprintf('%.2f',$synoeu).")"), $q->end_td(), "\n",
						$q->start_td(), $q->span(sprintf('%.2f',$misoe)."<br/>(".sprintf('%.2f',$misoel)."-".sprintf('%.2f',$misoeu).")"), $q->end_td(), "\n",
						$q->start_td(), $q->span(sprintf('%.2f',$lofoe)."<br/>(".sprintf('%.2f',$lofoel)."-".sprintf('%.2f',$lofoeu).")"), $q->end_td(), "\n",
						#$q->start_td(), $q->span($pli), $q->end_td(), "\n",
						#$q->start_td(), $q->span($prec), $q->end_td(), "\n",
						#$q->start_td(), $q->span($pnull), $q->end_td(), "\n",
					$q->end_Tr(), "\n", $q->end_table(), $q->end_div(), "\n";
					#$q->start_ul({'class' => ' w3-large'}),
					#	$q->li("chr$chr, strand $result->{'brin'}"), "\n",
					#	$q->li("$result->{'nom_prot'} ($result->{'short_prot'})"), "\n";
				#if ($result->{'acc_g'} eq 'NG_000000.0') {print $q->li("No NG accession number. Mutalyzer accession: $result->{'mutalyzer_acc'}")}
				#else {print $q->start_li(), $q->span({'onclick' => "window.open('$ncbi_url$result->{'acc_g'}', '_blank')", 'class' => 'pointer', 'title' => 'click to open Genbank in new tab'}, $result->{'acc_g'}), $q->end_li(), "\n"}
				#print $q->start_li(), U2_modules::U2_subs_3::add_variant_button($q, $gene, $result->{'nom'}[1], $result->{'acc_g'}), $q->end_li(), "\n";
				if ($user->isPublic() != 1) {
					print $q->start_ul({'class' => ' w3-large'}), "\n";
					if ($result->{'rp'} == 1) {print $q->li("Shown in 'RP', 'RP+USH' and in 'ALL' filters, hidden in others"), "\n"}
					if ($result->{'dfn'} == 1) {print $q->li("Shown in 'DFN', 'DFN+USH' and in 'ALL' filters, hidden in others"), "\n"}
					if ($result->{'usher'} == 1) {print $q->li("Shown in 'USH', 'DFN+USH', 'RP+USH' and in 'ALL' filters, hidden in others"), "\n"}
					if ($result->{'nom'}[0] eq 'CHM') {print $q->li("Shown in 'CHM' and 'ALL' filters, hidden in others"), "\n"}

					#if ($result->{'usher'} != 1 && $result->{'rp'} == 1) {print $q->li("Hidden if DFN filtered"), "\n"}
					#if ($result->{'usher'} != 1 && $result->{'dfn'} == 1) {print $q->li("Hidden if RP filtered"), "\n"}
					if ($result->{'MiSeq-28'} == 1) {print $q->li("included in 28 genes design"), "\n"}
					if ($result->{'MiSeq-112'} == 1) {print $q->li("included in 112 genes design"), "\n"}
					if ($result->{'MiSeq-121'} == 1) {print $q->li("included in 121 genes design"), "\n"}
					if ($result->{'MiSeq-3'} == 1) {print $q->li("included in 3 genes design"), "\n"}
					if ($result->{'MiniSeq-132'} == 1) {print $q->li("included in 132 genes design"), "\n"}
					if ($result->{'MiniSeq-152'} == 1) {print $q->li("included in 152 genes design"), "\n"}
					if ($result->{'MiniSeq-158'} == 1) {print $q->li("included in 158 genes design"), "\n"}
					if ($result->{'diag'} == 1) {print $q->li("diagnostic gene"), "\n"}
					else {print $q->li("non-diagnostic gene"), "\n"}

					print $q->end_ul(), "\n";
				}
				#if ($result->{'brin'} eq '-') {$order = 'DESC'}great_table technical
				print $q->br(), "\n", $q->start_div({'class' => 'w3-responsive', 'id' => 'info_table'}), "\n",
					$q->start_table({'class' => 'w3-table w3-striped w3-bordered w3-centered'}), $q->caption("Transcript info table:"),#technical ombre peche
					$q->start_Tr(), "\n",
						$q->th({'class' => 'left_general'}, 'RefSeq transcript'), "\n",
						$q->th({'class' => 'left_general'}, 'Ensembl transcript (v75)'), "\n",
						$q->th({'class' => 'left_general'}, 'Number of exons'), "\n",
						$q->th({'class' => 'left_general'}, 'RefSeq protein'), "\n",
						$q->th({'class' => 'left_general'}, 'Uniprot ID'), "\n",
					$q->end_Tr(), "\n";
			}
			#					$q->th({'class' => 'left_general'}, 'Protein Product size (aa)'), "\n",


			print $q->start_Tr(), "\n",
				$q->start_td({'onclick' => "window.open('$ncbi_url$result->{'nom'}[1].$result->{'acc_version'}', '_blank')", 'class' => 'pointer', 'title' => 'click to open Genbank in new tab'}),
					$q->start_strong(), $q->span("$result->{'nom'}[1].$result->{'acc_version'}");
			if ($result->{'main'} == 1) {print $q->span(' (main)')}
			print $q->end_strong(), $q->end_td();

			if ($result->{'enst'}) {print $q->start_td({'onclick' => "window.open('http://grch37.ensembl.org/Homo_sapiens/Transcript/Summary?db=core;t=$result->{'enst'}', '_blank')", 'class' => 'pointer', 'title' => 'click to open Ensembl in new tab'}), $q->span($result->{'enst'}), $q->end_td(), "\n"}
			else {print $q->td('No ENST in Ensembl 75'), "\n"}
			print $q->start_td(), $q->span($result->{'nbre_exons'}), $q->end_td(), "\n",
				$q->start_td({'onclick' => "window.open('$ncbi_url$result->{'acc_p'}', '_blank')", 'class' => 'pointer', 'title' => 'click to open Genbank in new tab'}), $q->span($result->{'acc_p'}), $q->end_td(), "\n",
				$q->start_td({'onclick' => "window.open('http://www.uniprot.org/uniprot/$result->{'uniprot_id'}', '_blank')", 'class' => 'pointer', 'title' => 'click to open UNIPROT in new tab'}), $q->span($result->{'uniprot_id'}), $q->end_td(), "\n",
				$q->end_Tr();
				#				$q->start_td(), $q->span($result->{'taille_prot'}), $q->end_td(), "\n",

		}
		print $q->end_table(), $q->end_div(), $q->br(), $q->br(), "\n";
		#my $exac_text = '*Based on the ExAC dataset, the probabilities for each gene of being loss-of function intolerant (pLi - haploinsufficients genes),<br/> Recessive (pRec - Premature Termination Variants (PTVs) tolerated heterozygotes but not homozygotes) of null (pNull - tolerant to PTVs) have been computed by the ExAC group. The closer to one, the most likely to fall in the given category. More <a href = \'https://www.nature.com/articles/nature19057\', target = \'_blank\'>here</a> (Supplementary Information, beginning p27). Please note that these metrics will soon be replaced with the more accurate observed/expected ratio (currently in gnomAD).';
		my $gnomad_text = '*In gnomAD, the previous pLi, pRec and pNull scores have been replaced by the more accurate observed/expected scores.<br/> Synonymous variants, nsSNVs (missense) and Loss of functions variants are reported for each gene, and compared with the expected numbers based on size and compositon of the gene. A Confidence Interval is given to better appreciate the value and if needed a threshold is defined: a class of variants is considered under constraint if the upper bound of the CI is &lt; 0.35. See "Gene constraint" explanations in gnomAD browser for more details (e.g. <a href="https://gnomad.broadinstitute.org/gene/ENSG00000042781" target="_blank" title="go to USH2A gene page and click the question mark near Gene Constraint">here</a>).';
		print U2_modules::U2_subs_2::info_panel($gnomad_text, $q);
		print $q->start_div({'id' => 'created_variant'}), $q->end_div(), "\n";


		##genome browser
		#http://www.biodalliance.org/
		#my $DALLIANCE_DATA_DIR_URI = '/dalliance_data/hg19/';
		my $query_dalliance = "SELECT MIN($postgre_start_g), MAX($postgre_end_g) FROM segment where nom_gene[1] = '$gene';";
		my $res_dalliance = $dbh->selectrow_hashref($query_dalliance);
		my ($dal_start, $dal_stop) = (($res_dalliance->{'min'}-5000), ($res_dalliance->{'max'}+5000));
		#if ($highlight_start == $highlight_end) {$highlight_end++}
					#	{name: '132 genes Design',
					#desc: 'Nimblegen SeqCap on 132 genes',
					#tier_type: 'tabix',
					#payload: 'bed',
					#uri: '".$DALLIANCE_DATA_DIR_URI."designs/seqcap_targets_sorted.132.bed.gz'},
		my $browser = "
			console.log(\"creating browser with coords: chr$chr:$dal_start-$dal_stop\" );
			var sources = [
				{name: 'Genome',
					desc: 'hg19/Grch37',
					twoBitURI: '".$DALLIANCE_DATA_DIR_URI."genome/hg19.2bit',
					tier_type: 'sequence',
					provides_entrypoints: true,
					pinned: true},
				{name: 'Genes',
					desc: 'GENCODE v19',
					bwgURI: '".$DALLIANCE_DATA_DIR_URI."gencode/gencode.v19.annotation.bb',
					stylesheet_uri: '".$DALLIANCE_DATA_DIR_URI."gencode/gencode-expanded.xml',
					collapseSuperGroups: true,
					trixURI: '".$DALLIANCE_DATA_DIR_URI."gencode/gencode.v19.annotation.ix'},
				{name: 'Conservation',
					desc: 'PhastCons 100 way',
					bwgURI: '".$DALLIANCE_DATA_DIR_URI."cons/hg19.100way.phastCons.bw',
					noDownsample: true},
				{name: 'Repeats',
					desc: 'Repeat annotation from RepeatMasker',
					bwgURI: '".$DALLIANCE_DATA_DIR_URI."repeats/repeats.bb',
					stylesheet_uri: '".$DALLIANCE_DATA_DIR_URI."repeats/bb-repeats2.xml',
					forceReduction: -1}
					];
			var browser = new Browser({
				chr:		'$chr',
				viewStart:	$dal_start,
				viewEnd:	$dal_stop,
				cookieKey:	'human-grc_h37',
				prefix:		'".$JS_PATH."dalliance_v0.13/',
				fullScreen:	false,
				noPersist:	true,
				noPersistView:	true,
				maxHeight:	600,
				cookieKey:	'test',

				coordSystem:	{
					speciesName: 'Human',
					taxon: 9606,
					auth: 'GRCh',
					version: '37',
					ucscName: 'hg19'
				},
				sources:	sources,
				hubs:	['http://ftp.ebi.ac.uk/pub/databases/ensembl/encode/integration_data_jan2011/hub.txt']
			});

			function highlightRegion(){
				console.log(\" xx highlight region chr$chr,$dal_start,$dal_stop\");
				browser.setLocation(\"$chr\",$dal_start,$dal_stop);
			}

			browser.addInitListener( function(){
				console.log(\"dalliance initiated\");
				setTimeout(highlightRegion(),5000);
				//highlightRegion();
			});
		";

		print $q->br(), $q->script({'type' => 'text/javascript', 'defer' => 'defer'}, $browser), $q->div({'id' => 'svgHolder', 'class' => 'container'}, 'Dalliance Browser here'), $q->br(), $q->br();

		#modified 06/07/2015 gene structure now on separate page
		#print	$q->p('Click on an exon/intron  on the picture below to get the variants lying in it:'),
		##otherwise, '), $q->button({'onclick' => "chooseSortingType('$gene');", 'value' => 'get all variants'}),
		##		$q->span('&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;OR&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'), $q->button({'onclick' => "window.open('gene_graphs.pl?gene=$gene');", 'value' => 'get graphs for pathogenic variants'}),
		#	#$q->start_ul(), "\n",
		#	#$q->start_li(),$q->a({'href' => "gene.pl?gene=$gene&info=all_vars&sort=classe", 'target' => '_blank'}, 'Pathogenic class'), $q->end_li(), "\n",
		#	#$q->start_li(),$q->a({'href' => "gene.pl?gene=$gene&info=all_vars&sort=type_adn", 'target' => '_blank'}, 'DNA type (subs, indels...)'), $q->end_li(), "\n",
		#	#$q->start_li(),$q->a({'href' => "gene.pl?gene=$gene&info=all_vars&sort=type_prot", 'target' => '_blank'}, 'Protein type (missense, silent...)'), $q->end_li(), "\n",
		#	#$q->start_li(),$q->a({'href' => "gene.pl?gene=$gene&info=all_vars&sort=type_arn", 'target' => '_blank'}, 'RNA type (neutral / altered)'), $q->end_li(), "\n",
		#	#$q->start_li(),$q->a({'href' => "gene.pl?gene=$gene&info=all_vars&sort=taille", 'target' => '_blank'}, 'Variant size (show only large rearrangements)'), $q->end_li(), "\n",
		#	#$q->end_ul(), "\n",
		#	$q->br(), $q->br();
		#
		#my @js_params = ('showVariants', 'NULL', 'NULL');
		#my ($js, $map) = U2_modules::U2_subs_2::gene_canvas($gene, $order, $dbh, \@js_params);
		#
		#
		#print $q->start_div({'class' => 'container'}), $map, "\n<canvas class=\"ambitious\" width = \"1100\" height = \"500\" id=\"exon_selection\">Change web browser for a more recent please!</canvas>", $q->img({'src' => $HTDOCS_PATH.'data/img/transparency.png', 'usemap' => '#segment', 'class' => 'fented', 'id' => 'transparent_image'}), $q->end_div(), "\n", $q->script({'type' => 'text/javascript'}, $js), "\n",
		#	$q->start_div({'id' => 'dialog-form', 'title' => 'Add a variant'}), $q->p({'id' => 'fill_in'}), $q->end_div(), "\n";
	}
	else {print $q->p("Sorry I cannot recognize that gene name ($gene).")}
}
elsif ($q->param('gene') && $q->param('info') eq 'structure') {
	my ($gene, $second_name) = U2_modules::U2_subs_1::check_gene($q, $dbh);
	U2_modules::U2_subs_1::gene_header($q, 'structure', $gene, $user);
	my $query = "SELECT DISTINCT(brin) FROM gene WHERE nom[1] = '$gene' ORDER BY main DESC;";
	my $order = U2_modules::U2_subs_1::get_strand($gene, $dbh);
	my @js_params = ('showVariants', 'NULL', 'NULL');
	my ($js, $map, $main, $ng) = U2_modules::U2_subs_2::gene_canvas($gene, $order, $dbh, \@js_params);
	#get exon number for gene
	$query = "SELECT MAX(nbre_exons) as a FROM gene WHERE nom[1] = '$gene';";
	my $res_exons = $dbh->selectrow_hashref($query);
	my $nb_exons = $res_exons->{'a'};
	my ($canvas_height, $img_suffix, $css_suffix) = ('500', '', '');
	if ($nb_exons > 100) {$canvas_height = '1000';$img_suffix = '2';$css_suffix = '_1000'}
	if ($nb_exons > 200) {$canvas_height = '1700';$img_suffix = '3';$css_suffix = '_1700'}
	if ($nb_exons > 300) {$canvas_height = '2500';$img_suffix = '4';$css_suffix = '_2500'}

	#my $text = "Warning: non 'main' accession isoforms do not currently work.<br/> This will be fixed in a future release.";
	#print U2_modules::U2_subs_2::danger_panel($text, $q);

	print	$q->p('Click on an exon/intron on the picture below to get the variants lying in it:'),
		$q->br(),
		$q->start_div({'class' => 'w3-container w3-center w3-xlarge'}), U2_modules::U2_subs_3::add_variant_button($q, $gene, $main, $ng), $q->end_div(),
		$q->br(), $q->br(),
		$q->start_div({'class' => 'container'}), $map, "\n<canvas class=\"ambitious\" width = \"1100\" height = \"$canvas_height\" id=\"exon_selection\">Change web browser for a more recent please!</canvas>", $q->img({'src' => $HTDOCS_PATH.'data/img/transparency'.$img_suffix.'.png', 'usemap' => '#segment', 'class' => 'fented'.$css_suffix, 'id' => 'transparent_image'}),
		$q->end_div(), "\n",
		$q->script({'type' => 'text/javascript'}, $js), "\n",
		$q->start_div({'id' => 'dialog-form', 'title' => 'Add a variant'}),
			$q->p({'id' => 'fill_in'}),
		$q->end_div(), "\n",
		$q->div({'id' => 'created_variant', 'class' => 'fented_noleft'.$css_suffix.' w3-container container'}), "\n";
		#$q->start_div(), $q->start_ul({'id' => 'created_variant'}), $q->end_div(), "\n";
}
elsif ($q->param('gene') && $q->param('info') eq 'all_vars') {
	my ($gene, $second_name) = U2_modules::U2_subs_1::check_gene($q, $dbh);
	my ($sort, $css_class) = ('', '');
	if ($q->param('sort') && $q->param('sort') =~ /(classe|type_adn|type_arn|type_prot|taille|orphan)/o) {#orphans are variants not linked to any sample - or variants shown in mobidetails
		$sort = $1;
		if ($sort eq 'type_arn') {
			if ($q->param('dynamic') && $q->param('dynamic') =~ /([\w\s]+)/o) {$css_class = $1;$css_class =~ s/ /_/og;}#$js = "\$('.$1').css('background-color', '#FFFF66');";}
		}
	}
	elsif ($q->param('sort')) {#deal with params coming from gene_graphs.pl
		if ($q->param('sort') =~ /c\..+/o || $q->param('sort') eq 'Others') {$sort = 'classe'}
		elsif ($q->param('sort') =~ /RNA-altered/o) {$sort = 'type_arn'}
		elsif ($q->param('sort') =~ /(missense|nonsense|frameshift|start|inframe)/o) {$sort = 'type_prot'}
		elsif ($q->param('sort') =~ /large/o) {$sort = 'taille'}
	}

	U2_modules::U2_subs_1::gene_header($q, 'var_all', $gene, $user);

	print $q->br(), $q->start_p({'class' => 'title w3-xlarge'}), $q->start_big(), $q->start_strong(), $q->span('Variants found in '), $q->em({'onclick' => "gene_choice('$gene');", 'class' => 'pointer', 'title' => 'click to get somewhere'}, $gene),
		$q->end_strong(), $q->end_big(), $q->end_p(), $q->br(), "\n";
	my $query = "SELECT nom, acc_g FROM gene WHERE nom[1] = '$gene' and main = 't';";
	my $res = $dbh->selectrow_hashref($query);
	if ($res ne '0E0') {
		my ($ng, $acc) = ($res->{'acc_g'}, $res->{'nom'}[1]);
		print $q->start_div({'class' => 'w3-container w3-center w3-xlarge'}), U2_modules::U2_subs_3::add_variant_button($q, $gene, $acc, $ng), $q->end_div(), $q->br();
		print $q->start_div({'id' => 'created_variant'}), $q->end_div(), "\n";
	}


	if ($sort =~ /(classe|type_adn|type_arn|type_prot)/o) {
		print $q->p('All classes are represented in the table below. Click on a category to get all the associated variants (probands and relatives).');
		my ($i, $j) = (0, 0);

		my $query = "WITH tmp AS (SELECT DISTINCT(a.nom_c, a.num_pat, a.id_pat, a.nom_gene), a.nom_c, a.nom_gene FROM variant2patient a WHERE a.nom_gene[1] = '$gene')
				SELECT COUNT(DISTINCT(a.nom)) as var, a.$sort as sort, COUNT(b.nom_c) as allel FROM variant a, tmp b WHERE a.nom = b.nom_c AND a.nom_gene = b.nom_gene AND a.nom_gene[1] = '$gene' AND a.$sort <> '' GROUP BY a.$sort ORDER BY a.$sort;";

		#old fashion not rigourous with analysis_type in variant2patient
		#my $query = "SELECT COUNT(DISTINCT(a.nom)) as var, a.$sort as sort, COUNT(b.nom_c) as allel FROM variant a, variant2patient b WHERE a.nom = b.nom_c AND a.nom_gene = b.nom_gene AND a.nom_gene[1] = '$gene' AND a.$sort <> '' GROUP BY a.$sort ORDER BY a.$sort;";
		my $sth = $dbh->prepare($query);
		my $res = $sth->execute();
		if ($res ne '0E0') {
			print $q->start_div({'class' => 'container'}), $q->start_table({'class' => 'great_table technical'}), $q->caption("Variants summary:"),
					$q->start_Tr(), "\n",
					$q->th({'class' => 'left_general'}, 'Category'), "\n",
					$q->th({'class' => 'left_general'}, 'Number of different variants recorded'), "\n",
					$q->th({'class' => 'left_general'}, 'Number of cumulated variants'), "\n",
					$q->end_Tr();
			while (my $result = $sth->fetchrow_hashref()) {
				print $q->start_Tr(), "\n",
					$q->start_td(),
						$q->span({'class' => 'w3-button w3-ripple w3-blue', 'style' => 'width:60%', 'onclick' => "showAllVariants('$gene', '$result->{'sort'}', '$sort', '2', '$css_class');"}, $result->{'sort'}),
					$q->end_td(), "\n",
					$q->td($result->{'var'}),
					$q->td($result->{'allel'}), "\n",
					$q->end_Tr(), "\n";
					$i += $result->{'var'};$j += $result->{'allel'};
			}
			print $q->start_Tr(), "\n",
				$q->start_td(),
					$q->span({'class' => 'w3-button w3-ripple w3-blue', 'style' => 'width:60%', 'onclick' => "showAllVariants('$gene', 'all', 'all', '2');"}, 'Total'),
				$q->end_td(),
				$q->td($i), $q->td($j), "\n",
				$q->end_Tr(), "\n",
				$q->end_table(), $q->end_div();
		}
	}
	elsif ($sort eq 'orphan') {#MD code
		#missense
		my ($missense, $missense_text) = &variants_div('missense', "AND a.type_prot = 'missense'" , $dbh, $q, 'Missense', $gene);
		#silent
		my ($silent, $silent_text) = &variants_div('silent', "AND a.nom_prot ~ '=' AND a.type_segment = 'exon' AND a.type_segment_end = 'exon'", $dbh, $q, 'Silent*', $gene);#IN  ('p.(=)', 'p.=')
		#intronic
		my ($intronic, $intronic_text) = &variants_div('intronic', "AND (a.type_segment = 'intron' OR a.type_segment_end = 'intron')", $dbh, $q, 'Intronic**', $gene);
		#ptc
		my ($ptc, $ptc_text) = &variants_div('ptc', "AND a.type_prot IN ('nonsense','frameshift')", $dbh, $q, 'PTC***', $gene);
		#inframe
		my ($inframe, $inframe_text) = &variants_div('inframe', "AND a.type_prot LIKE '%inframe%'", $dbh, $q, 'In frame Indels', $gene);
		#all vars
		my ($all_vars, $all_vars_text) = &variants_div('all_vars', '', $dbh, $q, 'All', $gene);


		print $q->div({'class' => 'w3-row w3-center'}), "\n",
				$q->div({'class' => 'w3-col m4'}), "\n",
					$q->strong({'class' => 'w3-button w3-indigo w3-ripple w3-hover-light-blue w3-padding-32 w3-xlarge', 'style' => 'width:100%', 'onclick' => "hide_all();\$('#missense').show();"}, $missense_text),
				$q->end_div(), "\n",
				$q->div({'class' => 'w3-col m4'}), "\n",
					$q->strong({'class' => 'w3-button w3-indigo w3-ripple w3-hover-light-blue w3-padding-32 w3-xlarge', 'style' => 'width:100%', 'onclick' => "hide_all();\$('#silent').show();"}, $silent_text),
				$q->end_div(), "\n",
				$q->div({'class' => 'w3-col m4'}), "\n",
					$q->strong({'class' => 'w3-button w3-indigo w3-ripple w3-hover-light-blue w3-padding-32 w3-xlarge', 'style' => 'width:100%', 'onclick' => "hide_all();\$('#intronic').show();"}, "$intronic_text"),
				$q->end_div(), "\n",
			$q->end_div(), "\n",
			$q->div({'class' => 'w3-row'}), "\n",
				$q->div({'class' => 'w3-col m4'}), "\n",
					$q->strong({'class' => 'w3-button w3-indigo w3-ripple w3-hover-light-blue w3-padding-32 w3-xlarge', 'style' => 'width:100%', 'onclick' => "hide_all();\$('#ptc').show();"}, "$ptc_text"),
				$q->end_div(), "\n",
				$q->div({'class' => 'w3-col m4'}), "\n",
					$q->strong({'class' => 'w3-button w3-indigo w3-ripple w3-hover-light-blue w3-padding-32 w3-xlarge', 'style' => 'width:100%', 'onclick' => "hide_all();\$('#inframe').show();"}, "$inframe_text"),
				$q->end_div(), "\n",
				$q->div({'class' => 'w3-col m4'}), "\n",
					$q->strong({'class' => 'w3-button w3-indigo w3-ripple w3-hover-light-blue w3-padding-32 w3-xlarge', 'style' => 'width:100%', 'onclick' => "hide_all();\$('#all_vars').show();"}, $all_vars_text),
				$q->end_div(), "\n",
			$q->end_div(), "\n", $q->br(), $q->br();

		my $js = "
			//\$('#all_vars').show();
			function hide_all() {
				\$('#all_vars').hide();
				\$('#silent').hide();
				\$('#intronic').hide();
				\$('#ptc').hide();
				\$('#inframe').hide();
				\$('#missense').hide();
			}
		";
		my $explain = '* shortcut for variants not predicted by the genetic code to alter the protein sequence - does not consider splicing at all<br/>** Might include large rearrangements<br/>***Premature Termination Codons, including nonsense variants and frameshifts';
		print U2_modules::U2_subs_2::info_panel($explain, $q);
		print $all_vars, $missense, $silent, $intronic, $ptc, $inframe, $q->script({'type' => 'text/javascript'}, $js);
	}
	elsif ($sort eq 'taille') {
		print $q->p("All large rearrangements recorded for $gene are listed in the table below.");
		my $query = "SELECT a.classe, a.taille, a.nom, a.nom_gene, a.type_adn, a.num_segment, a.num_segment_end,  COUNT(b.nom_c) as allel FROM variant a, variant2patient b WHERE a.nom = b.nom_c AND a.nom_gene = b.nom_gene AND a.nom_gene[1] = '$gene' AND taille > 50 GROUP BY a.taille, a.nom, a.classe, a.nom_gene, a.nom_g, a.type_adn, a.num_segment, a.num_segment_end ORDER BY a.nom_g ".U2_modules::U2_subs_1::get_strand($gene, $dbh).";";
		my $sth = $dbh->prepare($query);
		my $res = $sth->execute();
		if ($res ne '0E0') {

			print $q->start_div({'class' => 'container patient_file_frame'}), $q->start_table({'class' => 'great_table technical'}), $q->caption("Large rearrangements summary:"),
					$q->start_Tr(), "\n",
					$q->th('Size'), "\n",
					$q->th('Variants'), "\n",
					#$q->th('Number of different variants recorded'), "\n",
					$q->th('Number of cumulated variants'), "\n",
					$q->end_Tr();
			while (my $result = $sth->fetchrow_hashref()) {
				my $color = U2_modules::U2_subs_1::color_by_classe($result->{'classe'}, $dbh);
				print $q->start_Tr(), "\n",
					$q->td($result->{'taille'}), $q->start_td({'onclick' => "window.open('variant.pl?gene=$gene&accession=$result->{'nom_gene'}[1]&nom_c=".uri_escape($result->{'nom'})."', \'_blank\')", 'title' => 'Go to the variant page', 'class' => 'pointer'}), $q->span({'style' => "color:$color", }, "$result->{'nom'} - (".U2_modules::U2_subs_2::create_lr_name($result, $dbh).")"), $q->end_td(), $q->td($result->{'allel'}), "\n",
					$q->end_Tr(), "\n";
			}
			print $q->end_table(), $q->end_div();
		}
	}

	print $q->br(), $q->br(), $q->div({'id' => 'vars'});
}
elsif ($q->param('gene') && $q->param('info') eq 'genotype') {
	my ($gene, $second_name) = U2_modules::U2_subs_1::check_gene($q, $dbh);
	U2_modules::U2_subs_1::gene_header($q, 'genotypes', $gene, $user);

	my ($rp, $dfn, $usher) = U2_modules::U2_subs_1::get_gene_group($gene, $dbh);

	#if (grep($gene, @U2_modules::U2_subs_1::USHER) || grep($gene, @U2_modules::U2_subs_1::DFNB) || grep($gene, @U2_modules::U2_subs_1::NSRP) ||  grep($gene, @U2_modules::U2_subs_1::LCA)) {
	#my $query = "SELECT DISTINCT(a.nom_c, a.num_pat, a.id_pat, a.nom_gene), a.nom_c, a.id_pat, a.num_pat, a.statut, c.pathologie FROM variant2patient a, variant b, patient c WHERE a.nom_c = b.nom AND a.nom_gene = b.nom_gene AND a.num_pat = c.numero AND a.id_pat = c.identifiant AND b.classe in ('pathogenic', 'VUCS class III', 'VUCS class IV') AND a.nom_gene[1] = '$gene' AND c.proband = 't' ORDER BY c.pathologie, a.id_pat, a.num_pat, a.statut;";

	my $query = "WITH tmp AS (SELECT DISTINCT(a.nom_c, a.num_pat, a.id_pat, a.nom_gene), a.nom_c, a.id_pat, a.num_pat, a.statut, c.pathologie FROM variant2patient a, variant b, patient c WHERE a.nom_c = b.nom AND a.nom_gene = b.nom_gene AND a.num_pat = c.numero AND a.id_pat = c.identifiant AND b.classe in ('pathogenic', 'VUCS class III', 'VUCS class IV') AND a.nom_gene[1] = '$gene' AND c.proband = 't')\nSELECT DISTINCT(a.id_pat, a.num_pat, a.statut, b.filter, a.nom_c), a.pathologie, a.id_pat, a.num_pat, a.statut FROM tmp a LEFT OUTER JOIN miseq_analysis b ON a.id_pat = b.id_pat AND a.num_pat = b.num_pat ORDER BY a.pathologie, a.id_pat, a.num_pat, a.statut;";

	#SELECT a.id_pat, a.num_pat, a.statut, a.pathologie, b.filter FROM tmp a LEFT OUTER JOIN miseq_analysis b ON a.id_pat = b.id_pat AND a.num_pat = b.num_pat ORDER BY a.pathologie, a.id_pat, a.num_pat, a.statut;

	my $sth = $dbh->prepare($query);
	my $res = $sth->execute();
	my ($hash_count, $hash_html, $hash_done);
	my $current_patient = ['', '', '', ''];
	my $het_count = 0;
	if ($res ne '0E0') {

		while (my $result = $sth->fetchrow_hashref()) {
			#filters!!!
			#my $query_filter = "SELECT b.filter, c.rp, c.dfn, c.usher FROM variant2patient a, miseq_analysis b, gene c WHERE a.num_pat = b.num_pat AND a.id_pat = b.id_pat AND a.type_analyse = b.type_analyse AND a.nom_gene = c.nom AND a.nom_gene[1] = '$gene' AND c.main = 't' AND a.id_pat = '$result->{'id_pat'}' AND a.num_pat = '$result->{'num_pat'}';";
			#my $res_filter = $dbh->selectrow_hashref($query_filter);
			#
			if ($result->{'filter'} eq 'RP' && $rp == 0) {next}
			elsif ($result->{'filter'} eq 'DFN' && $dfn == 0) {next}
			elsif ($result->{'filter'} eq 'USH' && $usher == 0) {next}
			elsif ($result->{'filter'} eq 'DFN-USH' && ($dfn == 0 && $usher == 0)) {next}
			elsif ($result->{'filter'} eq 'RP-USH' && ($rp == 0 && $usher == 0)) {next}
			elsif ($result->{'filter'} eq 'CHM' && $gene ne 'CHM') {next}

			#print STDERR $result->{'id_pat'}.$result->{'num_pat'}."-1\n";
			if (!exists($hash_done->{$result->{'id_pat'}.$result->{'num_pat'}})) {$hash_done->{$result->{'id_pat'}.$result->{'num_pat'}} = 0}
			if ($result->{'statut'} !~ /homo/) {
				$het_count++;
				if (($current_patient->[1] eq $result->{'id_pat'}) && ($current_patient->[2] eq $result->{'num_pat'})) {#compound het
					#print STDERR $result->{'id_pat'}.$result->{'num_pat'}."-2\n";
					($hash_count, $hash_html, $hash_done) = &build_hash($hash_count, $hash_html, $hash_done, $result->{'pathologie'}, $result->{'id_pat'}, $result->{'num_pat'}, 1, $gene);
					$het_count = 0;
				}
				elsif ($het_count == 2) { #het/hemi
					#print STDERR $result->{'id_pat'}.$result->{'num_pat'}."-3\n";
					($hash_count, $hash_html, $hash_done) = &build_hash($hash_count, $hash_html, $hash_done, $current_patient->[0], $current_patient->[1], $current_patient->[2], 0, $gene);
					$het_count -= 1;
				}
			}
			else {
				if ($current_patient->[3] !~ /homo/ && $hash_done->{$current_patient->[1].$current_patient->[2]} == 0) {
					#print STDERR $result->{'id_pat'}.$result->{'num_pat'}."-4\n";
					($hash_count, $hash_html, $hash_done) = &build_hash($hash_count, $hash_html, $hash_done, $current_patient->[0], $current_patient->[1], $current_patient->[2], 0, $gene);
					$het_count = 0;
				}
				#print STDERR $result->{'id_pat'}.$result->{'num_pat'}."-5\n";
				($hash_count, $hash_html, $hash_done) = &build_hash($hash_count, $hash_html, $hash_done, $result->{'pathologie'}, $result->{'id_pat'}, $result->{'num_pat'}, 2, $gene);
			}
			$current_patient = [$result->{'pathologie'}, $result->{'id_pat'}, $result->{'num_pat'}, $result->{'statut'}];
		}
		if ($current_patient->[3] !~ /homo/ && $hash_done->{$current_patient->[1].$current_patient->[2]} == 0) {
			#print STDERR $current_patient->[1].$current_patient->[2]."-6\n";
			($hash_count, $hash_html, $hash_done) = &build_hash($hash_count, $hash_html, $hash_done, $current_patient->[0], $current_patient->[1], $current_patient->[2], 0, $gene);
		}
		#foreach my $pat (keys %{$hash_done}) {
		#	print STDERR "$pat\n"
		#}
		my $js = "
			function getPatients(content, type) {
				if (!content) {content = 'No sample to display'}
				var \$dialog = \$('<div></div>')
					.html(content)
					.dialog({
					    autoOpen: false,
					    title: 'list of '+type,
					    width: 450,
					    maxHeight: 600
					});
				\$dialog.dialog('open');
			};";
		my ($homo_title, $het_title, $chr_type) = ('homozygotes', 'heterozygotes/hemizygotes', 'non_M');
		if (U2_modules::U2_subs_1::get_chr_from_gene($gene, $dbh) eq 'M') {($homo_title, $het_title, $chr_type) = ('homoplasmics', 'heteroplasmics', 'M')}
		print $q->br(), $q->br(), $q->start_p(), $q->span('A summary of the pathogenic genotypes for '), $q->em($gene), $q->span(' are shown below. Click on a cell to get the sample list. Results respect NGS filtering options.'), $q->br(), $q->br(), $q->script({'type' => 'text/javascript', 'defer' => 'defer'}, $js), $q->start_div({'class' => 'container patient_file_frame', 'id' => 'info_table'}), $q->start_table({'class' => 'great_table technical'}), $q->caption("Genotypes table:"),
					$q->start_Tr(), "\n",
					$q->th({'class' => 'twenty_five left_general'}, 'Phenotype'), "\n",
					$q->th({'class' => 'twenty_five left_general'}, "# $het_title"), "\n";
		if ($chr_type eq 'non_M') {print $q->th({'class' => 'twenty_five left_general'}, '# compound heterozygotes'), "\n"}
		print		$q->th({'class' => 'twenty_five left_general'}, "# $homo_title"), "\n",
					$q->end_Tr(), "\n";

		foreach my $disease (sort keys(%{$hash_count})) {
			#print STDERR "$disease-".$hash_count->{$disease}[0]."-".$hash_count->{$disease}[1]."-".$hash_count->{$disease}[1]."-\n";
			if ($disease ne '') {
				print $q->start_Tr(),
					$q->td($disease),
					$q->td({'class' => 'pointer', 'onclick' => 'getPatients(\''.$hash_html->{$disease}[0].'\',\''.$het_title.'\')'}, $hash_count->{$disease}[0]);
				if ($chr_type eq 'non_M') {print $q->td({'class' => 'pointer', 'onclick' => 'getPatients(\''.$hash_html->{$disease}[1].'\',\'compound heterozygotes\')'}, $hash_count->{$disease}[1])}
				print $q->td({'class' => 'pointer', 'onclick' => 'getPatients(\''.$hash_html->{$disease}[2].'\',\''.$homo_title.'\')'}, $hash_count->{$disease}[2]),
				$q->end_Tr(), "\n";
			}
		}
		print $q->end_table(), $q->end_div(), $q->br(), $q->br();
	}
	else {
		print $q->br(), $q->br(), $q->p('No pathogenic genotype to display')
	}





}

##Basic end of USHVaM 2 perl scripts:

if ($user->isPublic() == 1) {U2_modules::U2_subs_1::public_end_html($q)}
else {U2_modules::U2_subs_1::standard_end_html($q)}

print $q->end_html();

exit();

##End of Basic end

sub variants_div {
	my ($id, $subquery, $dbh, $q, $txt, $gene) = @_;
	my $query ="SELECT a.nom, a.nom_gene[2] as acc, a.nom_ivs, a.nom_prot, a.type_segment, a.num_segment FROM variant a LEFT JOIN variant2patient b ON a.nom = b.nom_c AND a.nom_gene = b.nom_gene WHERE a.nom_gene[1] = '$gene' AND b.nom_c IS NULL $subquery ORDER BY a.nom_g;";
	my $sth = $dbh->prepare($query);
	my $res = $sth->execute();
	my ($html, $var_text) = ('', "No $txt");
	if ($res ne '0E0') {
		$var_text = "$txt ($res)";
		$html =  $q->start_div({'class' => 'w3-container w3-animate-opacity', 'id' => "$id", 'style' => 'display:none'}). $q->start_p(). $q->span("$txt variants recorded in "). $q->em({'onclick' => "gene_choice('$gene');", 'class' => 'pointer', 'title' => 'click to get somewhere'}, $gene). $q->span(':'). $q->end_p(). $q->start_ul({'class' => 'w3-ul w3-hoverable  w3-center', 'style' => 'width:50%'});
		while (my $result = $sth->fetchrow_hashref()) {
			my $other_name = $result->{'nom_prot'};
			if ($result->{'nom_ivs'} ne '') {$other_name = $result->{'nom_ivs'}}
			$html .= $q->start_li(). $q->a({'href' => "variant.pl?gene=$gene&accession=$result->{'acc'}&nom_c=".uri_escape($result->{'nom'}), 'target' => '_blank'}, "$result->{'acc'}:$result->{'nom'}"). $q->span(" - $other_name - ($result->{'type_segment'} $result->{'num_segment'})"). $q->end_li();
		}
		$html .= $q->end_ul(). $q->end_div(), "\n";
	}
	elsif($txt eq 'All') {
			my $text = 'No orphan variant to display';
			$html = U2_modules::U2_subs_2::info_panel($text, $q);
	}
	return $html, $var_text;
}

#sub variant_div {
#	my ($id, $gene, $sth, $q, $txt) = @_;
#	my $html =  $q->start_div({'class' => 'w3-container', 'id' => "$id", 'style' => 'display:none'}). $q->start_p(). $q->span("$txt variants recorded in "). $q->em({'onclick' => "gene_choice('$gene');", 'class' => 'pointer', 'title' => 'click to get somewhere'}, $gene). $q->span(':'). $q->end_p(). $q->start_ul({'class' => 'w3-ul w3-hoverable  w3-center', 'style' => 'width:50%'});
#	while (my $result = $sth->fetchrow_hashref()) {
#		my $other_name = $result->{'nom_prot'};
#		if ($result->{'nom_ivs'} ne '') {$other_name = $result->{'nom_ivs'}}
#		$html .= $q->start_li(). $q->a({'href' => "variant.pl?gene=$gene&accession=$result->{'acc'}&nom_c=".uri_escape($result->{'nom'}), 'target' => '_blank'}, "$result->{'acc'}:$result->{'nom'}"). $q->span(" - $other_name"). $q->end_li();
#	}
#	$html .= $q->end_ul(). $q->end_div(), "\n";
#	return $html;
#}

sub build_hash {
	my ($hash_count, $hash_html, $hash_done, $disease, $id, $num, $index, $gene) = @_;
	if (!exists $hash_count->{$disease}) {$hash_count->{$disease} = [0, 0, 0]}
	#if (!exists $hash_html->{$disease}) {$hash_html->{$disease} = ['', '', '']}
	#print STDERR $id.$num."-inside\n";
	$hash_count->{$disease}[$index]++;
	$hash_html->{$disease}[$index] .= $q->start_div().$q->span("-$id$num&nbsp;&nbsp;").$q->start_a({'href' => "patient_file.pl?sample=$id$num", 'target' => '_blank'}).$q->span('patient&nbsp;&nbsp;').$q->img({'src' => $HTDOCS_PATH.'data/img/link_small.png', 'border' => '0', 'width' =>'15'}).$q->end_a().$q->span('&nbsp;&nbsp;&nbsp;').$q->start_a({'href' => "patient_genotype.pl?sample=$id$num&gene=$gene", 'target' => '_blank'}).$q->span('genotype&nbsp;&nbsp;').$q->img({'src' => $HTDOCS_PATH.'data/img/link_small.png', 'border' => '0', 'width' =>'15'}).$q->end_a().$q->end_div();
	$hash_done->{$id.$num} = 1;
	return ($hash_count, $hash_html, $hash_done);
}
