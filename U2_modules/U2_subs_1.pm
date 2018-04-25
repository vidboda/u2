package U2_modules::U2_subs_1;

use U2_modules::U2_init_1;
#use Apache::Reload;
#remove above line for production!!!
use File::Temp qw(tempdir);
use URI::Encode qw(uri_encode uri_decode);
use strict;
use warnings;
use SOAP::Lite;
#use Data::Dumper;
use LWP::UserAgent;


#   This program is part of ushvam2, USHer VAriant Manager version 2
#    Copyright (C) 2012-2015  David Baux
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
#		general subroutines and variables


our @COUNTRY = ('Unknown','France','Afghanistan','Albania','Algeria','American Samoa','Andorra','Angola','Anguilla','Antarctica','Antigua and Barbuda','Argentina','Armenia','Aruba','Australia','Austria','Azerbaijan','Bahamas','Bahrain','Bangladesh','Barbados','Belarus','Belgium','Belize','Benin','Bermuda','Bhutan','Bolivia','Bosnia and Herzegovina','Botswana','Bouvet Island','Brazil','British Indian Ocean Territory','Brunei','Bulgaria','Burkina Faso','Burundi','Cambodia','Cameroon','Canada','Cape Verde','Cayman Islands','Central African Republic','Chad','Chile','China','Christmas Island','Cocos Islands','Colombia','Comoros','Congo','Cook Islands','Costa Rica','Cote d\' Ivoire','Croatia','Cuba','Cyprus','Czech Republic','Congo','Denmark','Djibouti','Dominica','Dominican Republic','East Timor','Ecuador','Egypt','El Salvador','England','Equatorial Guinea','Eritrea','Estonia','Ethiopia','Falkland Islands','Faroe Islands','Fiji Islands','Finland','French Guiana','French Polynesia','French Southern and Antarctic Lands','Gabon','Gambia','Georgia','Germany','Ghana','Gibraltar','Greece','Greenland','Grenada','Guadeloupe','Guam','Guatemala','Guinea','Guinea-Bissau','Guyana','Haiti','Heard Island and McDonald Islands','Honduras','Hong Kong SAR','Hungary','Iceland','India','Indonesia','Iran','Iraq','Ireland','Israel','Italy','Jamaica','Japan','Jordan','Kazakhstan','Kenya','Kiribati','Korea','Kuwait','Kyrgyzstan','Laos','Latvia','Lebanon','Lesotho','Liberia','Libya','Liechtenstein','Lithuania','Luxembourg','Macao SAR','Macedonia','Madagascar','Malawi','Malaysia','Maldives','Mali','Malta','Marshall Islands','Martinique','Mauritania','Mauritius','Mayotte','Mexico','Micronesia','Moldova','Monaco','Mongolia','Montserrat','Morocco','Mozambique','Myanmar','Namibia','Nauru','Nepal','Netherlands','Netherlands Antilles','New Caledonia','New Zealand','Nicaragua','Niger','Nigeria','Niue','Norfolk Island','North Korea','Northern Ireland','Northern Mariana Islands','Norway','Oman','Pakistan','Palau','Panama','Papua New Guinea','Paraguay','Peru','Philippines','Pitcairn Islands','Poland','Portugal','Puerto Rico','Qatar','Reunion','Romania','Russia','Rwanda','Samoa','San Marino','Saudi Arabia','Scotland','Senegal','Serbia and Montenegro','Seychelles','Sierra Leone','Singapore','Slovakia','Slovenia','Solomon Islands','Somalia','South Africa','South Georgia and the South Sandwich Islands','Spain','Sri Lanka','St. Helena','St. Kitts and Nevis','St. Lucia','St. Pierre and Miquelon','St. Vincent and the Grenadines','Sudan','Suriname','Svalbard and Jan Mayen','Swaziland','Sweden','Switzerland','Syria','Taiwan','Tajikistan','Tanzania','Thailand','Togo','Tokelau','Tonga','Trinidad and Tobago','Tunisia','Turkey','Turkmenistan','Turks and Caicos Islands','Tuvalu','Uganda','Ukraine','United Arab Emirates','United Kingdom','United States','United States Minor Outlying Islands','Uruguay','Uzbekistan','Vanuatu','Vatican City','Venezuela','Viet Nam','Virgin Islands','Virgin Islands','Wales','Wallis and Futuna','Yemen','Zambia','Zimbabwe');

#manage groups

our @USHER = ('MYO7A', 'USH1C', 'CDH23', 'PCDH15', 'USH1G', 'CIB2', 'USH2A', 'GPR98', 'DFNB31', 'CLRN1', 'HARS', 'PDZD7', 'VEZT', 'CEP250');
our @USH1 = ('', 'MYO7A', 'USH1C', 'CDH23', 'PCDH15', 'USH1G', 'CIB2');
our @USH2 = ('USH2A', 'GPR98', 'DFNB31', 'PDZD7');
our @USH3 = ('CLRN1', 'HARS');
our @CHM = ('CHM');
our @DFNB = ('ADCY1', 'CABP2', 'CDC14A', 'CIB2', 'CLDN14', 'CLIC5', 'COL11A2', 'DFNB59', 'ESPN', 'EPS8', 'EPS8L2', 'ESRRB', 'FAM65B', 'FOXI1', 'GIPC3', 'GJB2', 'GJB3', 'GJB6', 'GPSM2', 'GRXCR1', 'GRXCR2', 'HGF', 'ILDR1', 'KCNJ10', 'LHFPL5', 'LOXHD1', 'LRTOMT', 'MARVELD2', 'MSRB3', 'MYO3A', 'MYO6', 'MYO15A', 'OTOA', 'OTOF', 'OTOG', 'OTOGL', 'PTPRQ', 'RDX', 'SERPINB6', 'SLC26A4', 'SLC26A5', 'STRC', 'SYNE4', 'TBC1D24', 'TECTA', 'TMC1', 'TMIE', 'TMPRSS3', 'TPRN', 'TRIOBP', 'TSPEAR');
our @DFNA = ('ACTG1', 'CCDC50', 'CEACAM16', 'COCH', 'COL11A2', 'CRYM', 'DIABLO', 'DFNA5', 'DIAPH1', 'DIAPH3', 'DSPP', 'EYA4', 'GJB2', 'GJB6', 'GJB3', 'GRHL2', 'HOMER2', 'KCNQ4', 'KITLG', 'MIR96', 'MIR182', 'MIR183', 'MYH9', 'MYH14', 'MYO1A', 'MYO6', 'OSBPL2', 'PTPRQ', 'POU4F3', 'SLC17A8', 'TBC1D24', 'TECTA', 'TJP2', 'TMC1', 'WFS1');
our @NSRP = ('ABCA4', 'BBS1', 'BEST1', 'C2orf71', 'C8orf37', 'CERKL', 'CNGA1', 'CNGB1', 'CRB1', 'DHDDS', 'EYS', 'FAM161A', 'FLVCR1', 'IDH3B', 'IMPG2', 'MAK', 'MERTK', 'NR2E3', 'NRL', 'PDE6A', 'PDE6B', 'PDE6G', 'PRCD', 'PROM1', 'PRPF31', 'RP1', 'RP2', 'RBP3', 'RGR', 'RHO', 'RLBP1', 'RPE65', 'RPGR', 'SAG', 'TTC8', 'ZNF513');
our @DFNX = ('POU3F4', 'PRPS1', 'SMPX', 'COL4A6');
our @LCA = ('LRAT', 'SPATA7', 'TULP1', 'RPE65');
our @OTHER_NS = ('ABHD12', 'ACOX1', 'ACTB', 'ACY1', 'ALMS1', 'ATP2B2', 'ATP6V0A4', 'ATP6V1B1', 'BSND', 'CACNA1D', 'CATSPER2', 'CHD7', 'CISD2', 'COL11A1', 'COL2A1', 'COL4A1', 'COL4A3', 'COL4A4', 'COL4A5', 'COL9A1', 'COL9A2', 'COL9A3', 'COLEC11', 'ECE1', 'EDN3', 'EDNRA', 'EDNRB', 'ERCC2', 'EYA1', 'FGF3', 'FGFR3', 'GATA3', 'HARS2', 'HSD17B4', 'JAG1', 'KARS', 'KCNE1', 'KCNQ1', 'KIT', 'LARS2', 'MASP1', 'MITF', 'MTAP', 'MYO1F', 'NDP', 'NF2', 'OPA1', 'PAX1', 'PAX3', 'PAX6', 'PEX1', 'PEX6', 'PHYH', 'PLS1', 'PMP22', 'POLR1C', 'POLR1D', 'SEMA3E', 'SIX1', 'SIX5', 'SLC4A11', 'SNAI2', 'SOX10', 'SOX2', 'TCOF1', 'TFAP2A', 'TIMM8A', 'TNC', 'TSHZ1', 'TWNK');
#our @NOGROUP = ();


#values for quality criteria (NGS) panel
#number of on target reads mini
#= (panel size in kb * enrichment coeff * mean expected doc) / read size
#= (900000 * 1,3 * 150) / 150 = 1170000
our $NUM_ONTARGET_READS = 1170000;
our $TITV = 2.3;
our $MDOC = 150;
our $PC50X = 95;
our $Q30 = 80;
#for whole genes
our $TITV_WG = 1.8;
our $PC50X_WG = 70;
#Clinical exomes
our $PC20X_CE = 75;
our $MDOC_CE = 30;
our $TITV_CE = 2.8;

#genes for aCGH
our @ACGH = ('MYO7A', 'USH1C', 'CDH23', 'PCDH15', 'USH1G', 'CIB2', 'USH2A', 'GPR98', 'DFNB31', 'CLRN1', 'PDZD7', 'CHM', 'OTOF', 'TECTA', 'MYO15A', 'COCH', 'TMC1', 'SLC26A4', 'KCNQ4', 'EYA4', 'TMPRSS3', 'WFS1', 'MYO6', 'EYS', 'GJB2', 'GJB6', 'POU3F4', 'ACTG1');
#genes for our LOVD install - deprecated 2014/12/17 in variant.pl- reused since
our @LOVD = ('MYO7A', 'USH1C', 'CDH23', 'PCDH15', 'USH1G', 'USH2A', 'GPR98', 'DFNB31', 'CLRN1', 'CHM', 'MYO15A', 'OTOF', 'PDZD7', 'SLC26A4', 'TECTA',' TMC1', 'MYO6');


my $config_file = U2_modules::U2_init_1->getConfFile();
my $config = U2_modules::U2_init_1->initConfig();
$config->file($config_file);# or die $!;
my $HTDOCS_PATH = $config->HTDOCS_PATH();
my $PATIENT_IDS = $config->PATIENT_IDS();
my $PATIENT_PHENOTYPE = $config->PATIENT_PHENOTYPE();
my $ANALYSIS_MISEQ_FILTER = $config->ANALYSIS_MISEQ_FILTER();

#hg38 transition variable for postgresql 'start_g' segment field
my ($postgre_start_g, $postgre_end_g) = ('start_g', 'end_g');  #hg19 style

# HTML subs

sub standard_begin_html { #prints top of the pages
	my ($q, $user_name, $dbh) = @_;
	#prints fix_top.html in one div and starts main div , 'src' => $HTDOCS_PATH.'fix_top.shtml'
	#print $q->start_div({'id' => 'page'}), $q->start_div({'id' => 'fixtop'}), $q->end_div(), $q->br(), $q->br(),
	#$q->start_div({'id' => 'internal'}), $q->p({'id' => 'log'}, 'logged in as '.$user_name), $q->br();
	#$q->start_a({'href' => '#bottom', 'class' => 'print_hidden'}), $q->img({'src' => $HTDOCS_PATH.'data/img/buttons/bottom_arrow.png', 'width' => '23', 'height' => '34', 'border' => '0'}), $q->strong('Go to bottom'), $q->end_a(), $q->br();
	print $q->start_div({'id' => 'page', 'class' => 'w3-medium'}), $q->start_div({'class' => 'w3-top', 'style' => 'z-index:1112'}),
		$q->start_div({'id' => 'scroll', 'class' => 'w3-white w3-opacity-min'}),
			$q->start_div({'id' => 'scroll-bar', 'class' => 'w3-blue', 'style' => 'height:4px;width:0%'}), $q->end_div(),
		$q->end_div(),
		$q->start_div({'id' => 'myNavbar', 'class' => 'w3-bar w3-card-2 w3-black'}),
		$q->start_div({'class' => 'w3-dropdown-hover'}),
			$q->start_a({'class' => 'w3-button w3-ripple w3-black', 'onclick' => 'window.location="/U2/";'}),$q->start_i({'class' => 'fa fa-home w3-xxlarge'}), $q->end_i(), $q->end_a(),
			$q->start_div({'class' => 'w3-dropdown-content w3-bar-block w3-card-4'}),
				$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/resources.pl'}, 'Resources'),
			$q->end_div(),
		$q->end_div(),
		$q->start_div({'class' => 'w3-dropdown-hover'}),
			$q->start_a({'class' => 'w3-button w3-ripple w3-black'}),$q->start_i({'class' => 'fa fa-stethoscope w3-xxlarge'}), $q->end_i(), $q->end_a(),
			#$q->a({'class' => 'w3-button w3-ripple w3-large'},'Patients'),
			$q->start_div({'class' => 'w3-dropdown-content w3-bar-block w3-card-4'});
	#get patients' pathologies
	my $query = "SELECT pathologie FROM valid_pathologie ORDER BY id;";
	print $q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/patients.pl?phenotype=all'}, 'ALL'),
		$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/patients.pl?phenotype=USHER'}, 'USHER');	
	my $sth = $dbh->prepare($query);
	my $res = $sth->execute();	
	while (my $result = $sth->fetchrow_hashref()) {
		print $q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => "/perl/U2/patients.pl?phenotype=$result->{'pathologie'}"}, $result->{'pathologie'});
	}
		#		$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-xlarge', 'href' => '/perl/U2/resources.pl'}, 'Resources'),
	print 		$q->end_div(),
		$q->end_div(),
		$q->start_div({'class' => 'w3-dropdown-hover'}), "\n",
			$q->start_a({'class' => 'w3-button w3-ripple w3-black'}),$q->start_i({'class' => 'fa fa-ioxhost w3-xxlarge'}), $q->end_i(), $q->end_a(), "\n",
			#$q->a({'class' => 'w3-button w3-ripple w3-xlarge'},'Genes'),
			$q->start_div({'class' => 'w3-dropdown-content w3-bar-block w3-card-4'}), "\n",
				$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/gene_page.pl?sort=ALL'}, 'ALL'), "\n",
				$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/gene_page.pl?sort=USHER'}, 'USHER'), "\n",
				$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/gene_page.pl?sort=DFNB'}, 'DFNB'), "\n",
				$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/gene_page.pl?sort=DFNA'}, 'DFNA'), "\n",
				$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/gene_page.pl?sort=DFNX'}, 'DFNX'), "\n",
				$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/gene_page.pl?sort=NSRP'}, 'NSRP'), "\n",
				$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/gene_page.pl?sort=CHM'}, 'CHM'), "\n",
				$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/gene_page.pl?sort=LCA'}, 'LCA'), "\n",
			$q->end_div(), "\n",
		$q->end_div(), "\n",
		$q->start_div({'class' => 'w3-dropdown-hover'}), "\n",
			$q->start_a({'class' => 'w3-button w3-ripple w3-black'}),$q->start_i({'class' => 'fa fa-pie-chart w3-xxlarge'}), $q->end_i(), $q->end_a(), "\n",
			#$q->a({'class' => 'w3-button w3-ripple w3-large'},'Statistics'),
			$q->start_div({'class' => 'w3-dropdown-content w3-bar-block w3-card-4'}), "\n",
				$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/stats_ngs.pl'}, 'Illumina tables'), "\n",
				$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/stats_ngs.pl?graph=1'}, 'Illumina graphs'), "\n",
				$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/ngs_compare.pl'}, 'NGS compare'), "\n",
				$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/dbsnp_info.pl'}, 'dbSNP'), "\n",
				$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/stats_general_1.pl'}, 'General Stats'), "\n",
			$q->end_div(), "\n",
		$q->end_div(), "\n",
		$q->start_div({'class' => 'w3-dropdown-hover'}), "\n",
			#$q->a({'class' => 'w3-button w3-ripple w3-large'},'Advanced'),
			$q->start_a({'class' => 'w3-button w3-ripple w3-black'}),$q->start_i({'class' => 'fa fa-gears w3-xxlarge'}), $q->end_i(), $q->end_a(), "\n",
			$q->start_div({'class' => 'w3-dropdown-content w3-bar-block w3-card-4'}), "\n",
				$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/automated_class.pl?class=1', 'onclick' => 'info(\'class\');'}, 'Automatic Classification'), "\n",
				$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/automated_class.pl?neg=1', 'onclick' => 'info(\'neg\');'}, 'Automatic Negative'), "\n",
				$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/search_controls.pl?step=1'}, 'Search Controls'), "\n",
				$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/advanced.pl?advanced=non-USH'}, 'USH non-USH'), "\n",
				$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/advanced.pl?advanced=non-USH'}, 'USH non-USH'), "\n",
				$q->a({'class' => 'w3-bar-item w3-button w3-ripple w3-large', 'href' => '/perl/U2/advanced.pl?advanced=forgotten_samples'}, 'Forgotten Samples'), "\n",
			$q->end_div(), "\n",
		$q->end_div(), "\n",
		$q->start_a({'class' => 'w3-bar-item w3-button w3-ripple w3-xlarge w3-right', 'href' => '/ushvam2/change_user.php'}), $q->start_i({'class' => 'fa fa-user-times w3-xxlarge'}), $q->end_i(), $q->end_a(),
		$q->span({'class' => 'w3-bar-item w3-xlarge w3-right'}, "Logged in as $user_name"), "\n",
		$q->end_div(), $q->end_div(), $q->br(), $q->br(), "\n",
		$q->start_div({'id' => 'internal'}), $q->br(), "\n";	
	
}

sub standard_end_html { #prints bottom of the pages
	my ($q) = shift;
	#ends main div and prints fix_bot.html , 'src' => $HTDOCS_PATH.'fix_bot.html'
	#print $q->end_div(), $q->br(), $q->start_div({'id' => 'bottom', 'align' => 'right', 'class' => 'print_hidden'}), $q->start_a({'href' => '#page'}), $q->img({'src' => $HTDOCS_PATH.'data/img/buttons/top_arrow.png', 'width' => '23', 'height' => '34', 'border' => '0'}), $q->strong('Go to top'), $q->end_a(), $q->end_div(), "\n",
	print $q->end_div(), $q->br(), $q->start_div({'id' => 'fixbot', 'class' => 'w3-container w3-center'}), $q->end_div(), $q->br(), $q->br(), $q->br(), $q->br(), $q->br(), $q->end_div();
}

#common header for gene pages in gene.pl, gene_graphs.pl
sub gene_header {
	my ($q, $current_tab, $gene) = @_;
	
	print $q->start_div({'class' => 'w3-container'}), $q->start_h2(), $q->em($gene), $q->span(" page:"), $q->end_h2(), "\n",
		$q->br(), $q->start_div({'class' => 'w3-row'}), "\n";
	if ($current_tab eq 'general_info') {&print_span(' w3-border-red', $current_tab, "window.open('gene.pl?gene=$gene&amp;info=general', '_self');", 'General features', $q)}
	else {&print_span('', $current_tab, "window.open('gene.pl?gene=$gene&amp;info=general', '_self');", 'General info', $q)}
	if ($current_tab eq 'structure') {&print_span(' w3-border-red', $current_tab, "window.open('gene.pl?gene=$gene&amp;info=structure', '_self');", 'Exon structure', $q)}
	else {&print_span('', $current_tab, "window.open('gene.pl?gene=$gene&amp;info=structure', '_self');", 'Exons structure', $q)}	
	if ($current_tab eq 'var_all') {&print_span(' w3-border-red', $current_tab, "chooseSortingType('$gene');", 'Get all variants', $q)}
	else {&print_span('', $current_tab, "chooseSortingType('$gene');", 'Get all variants', $q)}
	if ($current_tab eq 'genotypes') {&print_span(' w3-border-red', $current_tab, "window.open('gene.pl?gene=$gene&amp;info=genotype', '_self');", 'Genotypes', $q)}
	else {&print_span('', $current_tab, "window.open('gene.pl?gene=$gene&amp;info=genotype', '_self');", 'Genotypes', $q)}
	if ($current_tab eq 'graphs') {&print_span(' w3-border-red', $current_tab, "window.open('gene_graphs.pl?gene=$gene', '_self');", 'Beautiful graphs', $q)}
	else {&print_span('', $current_tab, "window.open('gene_graphs.pl?gene=$gene', '_self');", 'Beautiful graphs', $q)}
	
	#"chooseSortingType('$gene');"
	
	print $q->end_div(), $q->end_div(),"\n",
		$q->div({'class' => 'tab_content', 'style' => 'display:block;'}), "\n";
		
		
		
		
	#print $q->start_h2(), $q->em($gene), $q->span(" page:"), $q->end_h2(), "\n",
	#	$q->br(), $q->start_div(), "\n";
	#if ($current_tab eq 'general_info') {&print_span('tab tab_current', $current_tab, "window.open('gene.pl?gene=$gene&amp;info=general', '_self');", 'General features', $q)}
	#else {&print_span('tab tab_other', $current_tab, "window.open('gene.pl?gene=$gene&amp;info=general', '_self');", 'General info', $q)}
	#if ($current_tab eq 'structure') {&print_span('tab tab_current', $current_tab, "window.open('gene.pl?gene=$gene&amp;info=structure', '_self');", 'Exon structure', $q)}
	#else {&print_span('tab tab_other', $current_tab, "window.open('gene.pl?gene=$gene&amp;info=structure', '_self');", 'Exons structure', $q)}	
	#if ($current_tab eq 'var_all') {&print_span('tab tab_current', $current_tab, "chooseSortingType('$gene');", 'Get all variants', $q)}
	#else {&print_span('tab tab_other', $current_tab, "chooseSortingType('$gene');", 'Get all variants', $q)}
	#if ($current_tab eq 'genotypes') {&print_span('tab tab_current', $current_tab, "window.open('gene.pl?gene=$gene&amp;info=genotype', '_self');", 'Genotypes', $q)}
	#else {&print_span('tab tab_other', $current_tab, "window.open('gene.pl?gene=$gene&amp;info=genotype', '_self');", 'Genotypes', $q)}
	#if ($current_tab eq 'graphs') {&print_span('tab tab_current', $current_tab, "window.open('gene_graphs.pl?gene=$gene', '_self');", 'Beautiful graphs', $q)}
	#else {&print_span('tab tab_other', $current_tab, "window.open('gene_graphs.pl?gene=$gene', '_self');", 'Beautiful graphs', $q)}
	#
	##"chooseSortingType('$gene');"
	#
	#print $q->end_div(), "\n",
	#	$q->div({'class' => 'tab_content', 'style' => 'display:block;'}), "\n";
}
#used in gene_header
sub print_span {
	my ($class, $id, $action, $title, $q) = @_;
	print "\t", $q->span({'class' => "tablink w3-bottombar w3-hover-light-grey w3-padding pointer".$class, 'id' => $id, 'onclick' => $action}, $title), "\n";
}
sub accent2html {
	my ($str) = shift;
	#ok
	$str =~ s/é/&eacute;/og;
	$str =~ s/á/&aacute;/og;
	$str =~ s/ú/&uacute;/og;
	$str =~ s/í/&iacute;/og;
	$str =~ s/ó/&oacute;/og;
	$str =~ s/è/&egrave;/og;
	$str =~ s/ù/&ugrave;/og;
	$str =~ s/ò/&ograve;/og;
	$str =~ s/à/&agrave;/og;
	$str =~ s/ì/&igrave;/og;
	$str =~ s/È/&Egrave;/og;
	$str =~ s/Ù/&Ugrave;/og;
	$str =~ s/Ò/&Ograve;/og;
	$str =~ s/À/&Agrave;/og;
	$str =~ s/Ì/&Igrave;/og;
	$str =~ s/ç/&ccedil;/og;
	$str =~ s/ä/&auml;/og;
	$str =~ s/ë/&euml;/og;
	$str =~ s/ü/&uuml;/og;
	$str =~ s/ï/&iuml;/og;
	$str =~ s/ö/&ouml;/og;
	$str =~ s/Ä/&Auml;/og;
	$str =~ s/Ë/&Euml;/og;
	$str =~ s/Ü/&Uuml;/og;
	$str =~ s/Ï/&Iuml;/og;
	$str =~ s/Ö/&Ouml;/og;
	$str =~ s/ê/&ecirc;/og;
	$str =~ s/ô/&ocirc;/og;
	$str =~ s/â/&acirc;/og;
	$str =~ s/î/&icirc;/og;
	$str =~ s/û/&ucirc;/og;
	$str =~ s/Ê/&Ecirc;/og;
	$str =~ s/Ô/&Ocirc;/og;
	$str =~ s/Â/&Acirc;/og;
	$str =~ s/Î/&Icirc;/og;
	$str =~ s/Û/&Ucirc;/og;
	$str =~ s/Ø/O/og;
	$str =~ s/'/\'/og;
	return $str;
}
sub html2accent {
	my ($str) = shift;
	#ok
	$str =~ s/&eacute;/é/og;
	$str =~ s/&aacute;/á/og;
	$str =~ s/&uacute;/ú/og;
	$str =~ s/&iacute;/í/og;
	$str =~ s/&oacute;/ó/og;
	$str =~ s/&egrave;/è/og;
	$str =~ s/&ugrave;/ù/og;
	$str =~ s/&ograve;/ò/og;
	$str =~ s/&agrave;/à/og;
	$str =~ s/&igrave;/ì/og;
	$str =~ s/&Egrave;/È/og;
	$str =~ s/&Ugrave;/Ù/og;
	$str =~ s/&Ograve;/Ò/og;
	$str =~ s/&Agrave;/À/og;
	$str =~ s/&Igrave;/Ì/og;
	$str =~ s/&ccedil;/ç/og;
	$str =~ s/&auml;/ä/og;
	$str =~ s/&euml;/ë/og;
	$str =~ s/&uuml;/ü/og;
	$str =~ s/&iuml;/ï/og;
	$str =~ s/&ouml;/ö/og;
	$str =~ s/&Auml;/Ä/og;
	$str =~ s/&Euml;/Ë/og;
	$str =~ s/&Uuml;/Ü/og;
	$str =~ s/&Iuml;/Ï/og;
	$str =~ s/&Ouml;/Ö/og;
	$str =~ s/&ecirc;/ê/og;
	$str =~ s/&ocirc;/ô/og;
	$str =~ s/&acirc;/â/og;
	$str =~ s/&icirc;/î/og;
	$str =~ s/&ucirc;/û/og;
	$str =~ s/&Ecirc;/Ê/og;
	$str =~ s/&Ocirc;/Ô/og;
	$str =~ s/&Acirc;/Â/og;
	$str =~ s/&Icirc;/Î/og;
	$str =~ s/&Ucirc;/Û/og;
	$str =~ s/O/Ø/og;
	$str =~ s/\'/'/og;
	return $str;
}
# Form subs
sub select_origin { #insert a list of countries in a pop up menu
	my ($q) = shift;
	print $q->popup_menu(-name => 'origin', -id => 'origin', -values => \@COUNTRY, -class => 'w3-select w3-border');
}

sub select_phenotype { #insert a list of phenotypes in a pop up menu
	my ($q) = shift;
	$PATIENT_PHENOTYPE =~ /^\((.+)\)$/o;
	my @phenotype_tab = split(/\|/, $1);
	unshift @phenotype_tab, '';
	print $q->popup_menu(-name => 'phenotype', -id => 'phenotype', -values => \@phenotype_tab, -class => 'w3-select w3-border');
}

sub select_gene { #insert a list of genes in a pop up menu
	my ($q, $dbh) = @_;
	my @gene_list;
	my $sth = $dbh->prepare("SELECT nom[1] as gene FROM gene;");
	my $res = $sth->execute();
	while (my $result = $sth->fetchrow_hashref()) {push @gene_list, $result->{'gene'}}
	print $q->popup_menu(-name => 'gene', -id => 'genes', -values => \@gene_list, -class => 'w3-select w3-border');
}

sub select_genes_grouped { #insert a list of genes in a pop up menu - group by phenotypes
	my ($q, $id, $form) = @_;
	print $q->popup_menu(-name => 'gene', -id => $id, -form => $form, -class => 'w3-select w3-border',
				-values => [
					$q->optgroup (-name => 'USH1', -values => \@USH1),
					$q->optgroup (-name => 'USH2', -values => \@USH2),
					$q->optgroup (-name => 'USH3', -values => \@USH3),
					$q->optgroup (-name => 'CHM', -values => \@CHM),
					$q->optgroup (-name => 'DFNB', -values => \@DFNB),
					$q->optgroup (-name => 'DFNA', -values => \@DFNA),
					$q->optgroup (-name => 'DFNX', -values => \@DFNX),
					$q->optgroup (-name => 'NSRP', -values => \@NSRP),
					$q->optgroup (-name => 'LCA', -values => \@LCA),
					$q->optgroup (-name => 'OTHER NS', -values => \@OTHER_NS)
					#$q->optgroup (-name => 'NO GROUP', -values => \@NOGROUP)			    
					    ]);
}
#in add_analysis.pl and patient_file.pl
sub select_filter { #insert a list of filter types in a pop up menu
	my ($q, $id, $form, $default) = @_;
	$ANALYSIS_MISEQ_FILTER =~ /^\((.+)\)$/o;
	my @filters = split(/\|/, $1);
	#my @filters = ('All', 'DFN', 'RP');
	if(!$default) {return $q->popup_menu(-name => $id, -id => $id, -form => $form, -values => \@filters, -class => 'w3-select w3-border')}
	else {return $q->popup_menu(-name => $id, -id => $id, -form => $form, -values => \@filters, -default => $default, -class => 'w3-select w3-border')}
}
#in add_analysis.pl
sub select_analysis {
	my ($q, $dbh, $form) = @_;
	my @analysis_list;
	my $sth = $dbh->prepare("SELECT type_analyse FROM valid_type_analyse WHERE form = 't';");
	my $res = $sth->execute();
	while (my $result = $sth->fetchrow_hashref()) {push @analysis_list, $result->{'type_analyse'}}
	@analysis_list = sort(@analysis_list);
	return $q->popup_menu(-name => 'analysis', -id => 'analysis', -form => $form, -values => \@analysis_list, -onchange => 'associate_gene();', -class => 'w3-select w3-border');
}


#was used to present the analyses under a radio button style - changed 05/07/2014 for a select style
#sub radio_analysis {
#	my ($q, $dbh) = @_;
#	my @analysis_list;
#	my $sth = $dbh->prepare("SELECT type_analyse FROM valid_type_analyse WHERE form = 't';");
#	my $res = $sth->execute();
#	while (my $result = $sth->fetchrow_hashref()) {push @analysis_list, $result->{'type_analyse'}}
#	@analysis_list = sort(@analysis_list);
#	print $q->radio_group(-name => 'analysis', -values => \@analysis_list, -columns => 1, -defaults => '', -onchange => 'associate_gene();');
#}


sub valid {
	my ($user, $number, $id, $dbh, $q) = @_;
	if ($user->isAnalyst() == 1) {
		my $tech_val = "SELECT DISTINCT(a.nom_gene[1]), a.type_analyse FROM analyse_moleculaire a, valid_type_analyse b WHERE a.type_analyse = b.type_analyse AND b.multiple = 'f' AND a.num_pat = '$number' AND a.id_pat = '$id' AND (a.technical_valid = 'f' OR a.result IS NULL OR a.valide = 'f');";
		my $sth = $dbh->prepare($tech_val);
		my $res = $sth->execute();
		my $html;
		if ($res ne '0E0') {
			while (my $result = $sth->fetchrow_hashref()) {
				$html .= $q->start_li().$q->em($result->{'nom_gene'}).$q->span("&nbsp;&nbsp;($result->{'type_analyse'})&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;");
				$html .= $q->button({'value' => 'Access', 'onclick' => "document.location = 'add_analysis.pl?step=2&sample=$id$number&gene=$result->{'nom_gene'}&analysis=$result->{'type_analyse'}';", 'class' => 'w3-button w3-ripple w3-blue'});
				$html .= $q->end_li();
			}		
		}
		else {$html = $q->li('no analyses pending')}
		return $html;
	}
}

sub valid_table {
	my ($user, $number, $id, $dbh, $q) = @_;
	if ($user->isAnalyst() == 1) {
		my $tech_val = "SELECT DISTINCT(a.nom_gene[1]), a.type_analyse FROM analyse_moleculaire a, valid_type_analyse b WHERE a.type_analyse = b.type_analyse AND b.multiple = 'f' AND a.num_pat = '$number' AND a.id_pat = '$id' AND (a.technical_valid = 'f' OR a.result IS NULL OR a.valide = 'f');";
		my $sth = $dbh->prepare($tech_val);
		my $res = $sth->execute();
		my $html;
		if ($res ne '0E0') {
			$html .= $q->start_table({'class' => 'great_table technical'}).$q->start_Tr().$q->th({'class' => 'left_general'}, 'Gene').$q->th({'class' => 'left_general'}, 'Analysis').$q->th({'class' => 'left_general'}, 'Link').$q->end_Tr();
			while (my $result = $sth->fetchrow_hashref()) {
				$html .= $q->start_Tr().$q->td({'class' => 'italique'}, $result->{'nom_gene'}).$q->td($result->{'type_analyse'});
				$html .= $q->start_td().$q->button({'value' => 'Access', 'onclick' => "document.location = 'add_analysis.pl?step=2&sample=$id$number&gene=$result->{'nom_gene'}&analysis=$result->{'type_analyse'}';", 'class' => 'w3-button w3-ripple w3-blue'}).$q->end_td();
				$html .= $q->end_Tr();
				#$html .= $q->start_li().$q->em($result->{'nom_gene'}).$q->span("&nbsp;&nbsp;($result->{'type_analyse'})&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;");
				#$html .= $q->button({'value' => 'Access', 'onclick' => "document.location = 'add_analysis.pl?step=2&sample=$id$number&gene=$result->{'nom_gene'}&analysis=$result->{'type_analyse'}';"});
				#$html .= $q->end_li();
			}
			$html .= $q->end_table();
		}
		else {$html = $q->span('no analyses pending')}
		return $html;
	}
}
# CGI params subs

sub check_step {  #check step cgi param : must be a number
	my ($q) = shift;
	if ($q->param('step') =~ /^(\d)$/o) {return $1}
	else {&standard_error('1', $q)}
}

sub check_phenotype { # check phenotype param
	my ($q) = shift;
	if ($q->param('phenotype') =~ /$PATIENT_PHENOTYPE/og) {return $1}
	else {&standard_error('3', $q)}
}
#used in import_illumina.pl, add_analysis.pl
sub sample2idnum { #transform a sample into an id and a number
	my ($sample, $q) = @_;
	if ($sample =~ /^$PATIENT_IDS\s*(\d+)$/o) {return($1, $2)}
	else {&standard_error('2', $q)}
}

sub check_gene { #checks gene param
	my ($q, $dbh) = @_;
	if ($q->param('gene') =~ /(\w+)/og) {
		my $name = $1;
		if ($name =~ /ORF/o) {$name =~ s/ORF/orf/og}
		my $query = "SELECT DISTINCT (nom[1]) as gene, second_name FROM gene WHERE nom[1] = '$name';";
		my $res = $dbh->selectrow_hashref($query);
		if ($res->{'gene'} ne '0E0') {return ($res->{'gene'}, $res->{'second_name'})}
		else {&standard_error('5', $q)}
	}
	else {&standard_error('4', $q)}
}

sub create_image_file_name {
	my ($gene, $ng) = @_;
	if ($ng =~ /g\.(\d+).*(_\d+).*(del|dup|ins).*/o) {
		return ($gene."_".$1.$2.$3.".png", $1, $2, $3);
	}
}

sub check_acc {
	#checks gene param
	my ($q, $dbh) = @_;
	if ($q->param('accession') =~ /(N[MRG]_\d+\.*\d*)/og) {
		my $query = "SELECT nom[2] as acc FROM gene WHERE nom[2] = '$1';";
		if ($1 =~ /NG_.+/o) {$query = "SELECT acc_g as acc FROM gene WHERE nom[2] = '$1';";}
		my $res = $dbh->selectrow_hashref($query);
		if ($res->{'acc'} ne '0E0') {return $res->{'acc'}}
		else {&standard_error('6', $q)}
	}
	else {&standard_error('7', $q)}
}

sub check_nom_c {
	my ($q, $dbh) = @_;
	if (uri_decode($q->param('nom_c')) =~ /([nc]\.[>\w\*\-\+\?_\{\}]+)/og) {
		my $query = "SELECT nom as var FROM variant WHERE nom = '$1' AND nom_gene[1] = '".$q->param('gene')."';";
		#print $query;
		my $res = $dbh->selectrow_hashref($query);
		if ($res->{'var'} ne '0E0') {return $res->{'var'}}
		else {&standard_error('9', $q)}
	}
	else {&standard_error('8', $q)}
}
#get nom_gene in splicing_calc.pl, otherwise get var
sub check_nom_g {
	my ($q, $dbh) = @_;
	if (uri_decode($q->param('nom_g')) =~ /(chr[\dXY]+:g\.[>\w\*\-\+\?_\{\}]+)/og) {
		my $query = "SELECT nom_g as var FROM variant WHERE nom_g = '$1';";
		#print $query;
		my $res = $dbh->selectrow_hashref($query);
		if ($res->{'var'} ne '0E0') {return ($res->{'var'})}
		else {&standard_error('9', $q)}
	}
	else {&standard_error('8', $q)}
}

#in ajax.pl,gets enst or ensp as type
sub check_ens {
	my ($q, $dbh, $type) = @_;
	if (uri_decode($q->param($type)) =~ /(ENST\d+)/og) {
		my $query = "SELECT $type FROM gene WHERE $type = '$1';";
		#print $query;
		my $res = $dbh->selectrow_hashref($query);
		if ($res->{$type} ne '0E0') {return $res->{$type}}
		else {&standard_error('6', $q)}
	}
	else {&standard_error('7', $q)}	
}

sub check_status {
	my ($q) = shift;
	if ($q->param('status') =~ /(homozygous|heterozygous|hemizygous)/o) {return $1}
	else {&standard_error('16', $q)}
}
sub check_allele {
	my ($q) = shift;
	if ($q->param('allele') =~ /(1|2|both|unknown)/o) {return $1}
	else {&standard_error('16', $q)}
}
sub check_denovo {
	my ($q) = shift;
	if ($q->param('denovo') =~ /(true)/o) {return $1}
	else {return 'false'}
}
sub check_status_modify {
	my ($q) = shift;
	if ($q->param('status_modify') =~ /(homozygous|heterozygous|hemizygous)/o) {return $1}
	else {&standard_error('16', $q)}
}
sub check_allele_modify {
	my ($q) = shift;
	if ($q->param('allele_modify') =~ /(1|2|both|unknown)/o) {return $1}
	else {&standard_error('16', $q)}
}
sub check_denovo_modify {
	my ($q) = shift;
	if ($q->param('denovo_modify') =~ /(true)/o) {return $1}
	else {return 'false'}
}
#used in add_analysis.pl, ajax.pl
sub check_analysis {
	my ($q, $dbh, $mode) = @_;
	if ($q->param('analysis') && $q->param('analysis') =~ /^([\w\(\)-]+)$/og) {
		my $totest = $1;
		my $res = $dbh->selectrow_hashref("SELECT type_analyse FROM valid_type_analyse WHERE type_analyse = '$totest' AND form = 't';");
		if ($mode eq 'basic') {$res = $dbh->selectrow_hashref("SELECT type_analyse FROM valid_type_analyse WHERE type_analyse = '$totest';")}
		if ($mode eq 'filtering') {$res = $dbh->selectrow_hashref("SELECT type_analyse FROM valid_type_analyse WHERE type_analyse = '$totest' AND filtering_possibility = 't';")}
		if ($res->{'type_analyse'} eq $totest) {return $res->{'type_analyse'}}
		else {&standard_error('12', $q)}
	}
	else {&standard_error('12', $q)}
}
#used in add_analysis.pl, ajax.pl
sub check_filter {
	my ($q) = shift;
	if ($q->param('filter') =~ /^$ANALYSIS_MISEQ_FILTER$/) {return $1}
	else {&standard_error('20', $q)}
}
#used in import_illumina.pl
sub check_illumina_run_id {
	my ($q) = shift;
	if ($q->param('run_id') =~ /^(\d{6}_[A-Z]\d{5}_\d{4}_0{9}-[A-Z0-9]{5})$/o || $q->param('run_id') =~ /^(\d{6}_[A-Z]{2}\d{5,6}_\d{4}_[A-Z0-9]{10})$/o) {return $1}
	else {&standard_error('21', $q)}	
}


sub check_class {
	my ($q, $dbh) = @_;
	my $query = "SELECT classe FROM valid_classe;";
	my $sth = $dbh->prepare($query);
	my $res = $sth->execute();
	while (my $result = $sth->fetchrow_hashref()) {
		if ($q->param('class') eq $result->{'classe'}) {
			return $result->{'classe'};
		}		
	}
	&standard_error('17', $q)
}
sub check_rna_status {
	my ($q, $dbh) = @_;
	my $query = "SELECT type_arn FROM valid_type_arn;";
	my $sth = $dbh->prepare($query);
	my $res = $sth->execute();
	while (my $result = $sth->fetchrow_hashref()) {
		if ($q->param('rna_status') eq $result->{'type_arn'}) {
			return $result->{'type_arn'};
		}		
	}
	&standard_error('24', $q)
}


#sub check_number {
#	my ($q) = @_;
#	if ($q->param('number') =~ /^(\d+)$/og) {return $1}
#	else {&standard_error($self, '4', $q)}
#}


# Error sub

sub standard_error { #returns an error and ends script
	my ($code, $q) = @_;
	my %error_code = (
		1	=>	'step numbering of the script',
		2	=>	'sample ID',
		3	=>	'patient phenotype',
		4	=>	'gene regexp',
		5	=>	'gene name',
		6	=>	'accession regexp',
		7	=>	'accession name',
		8	=>	'variant regexp',
		9	=>	'variant name',
		10	=>	'research character is not allowed',
		11	=>	'fact that the sample asked is unknown by the system',
		12	=>	'submitted analysis type',
		13	=>	'user credits (not an analyser)',
		14	=>	'fact that the submitted analysis already exists for this sample',
		15	=>	'segment information',
		16	=>	'unknown status',
		17	=>	'class error',
		18	=>	'fact that I cannot retrieve the patient ID in the MiSeq runs',
		19	=>	'manifest file name. Check NRCCE (MiSeq-112) or Nimblegen (MiSeq-28)',
		20	=>	'filter name',
		21	=>	'run ID',
		22	=>	'transfer of MiSeq files from RS to U2',
		23	=>	'the mutalyzer webservice which is unreachable. Try again later',
		24	=>	'RNA status value',
		25	=>	'User name'
	);
	print $q->start_p(), $q->span('USHVaM 2 encountered an error and cannot proceed further.'), $q->br(), $q->span("The error is linked to the $error_code{$code}."), $q->br(), $q->span('Please contact your admin.'), $q->end_p();
	&standard_end_html($q, $HTDOCS_PATH);
	print $q->end_html();
	exit();
}

# Patients subs



# gene subs

sub get_gene_group {
	my ($gene, $dbh) = @_;
	my $query = "SELECT rp, dfn, usher FROM gene WHERE nom[1] = '$gene';";
	my $res = $dbh->selectrow_hashref($query);
	return ($res->{'rp'}, $res->{'dfn'}, $res->{'usher'});
}

sub get_gene_from_nom_g {
	my ($q, $dbh) = @_;
	if (uri_decode($q->param('nom_g')) =~ /(chr[\dXY]+:g\.[>\w\*\-\+\?_\{\}]+)/og) {
		my $query = "SELECT nom_gene FROM variant WHERE nom_g = '$1';";
		my $res = $dbh->selectrow_hashref($query);
		if ($res->{'nom_gene'} ne '0E0') {return ($res->{'nom_gene'})}
		else {&standard_error('9', $q)}
	}
	else {&standard_error('8', $q)}
}

sub get_ng_accno {
	my ($gene, $acc, $dbh, $q) = @_;
	#gene, acc must have been checked before
	my $query = "SELECT acc_g FROM gene WHERE nom[1] = '$gene' AND nom[2] = '$acc';";
	my $res = $dbh->selectrow_hashref($query);
	if ($res) {return $res->{'acc_g'}}
	else {&standard_error('5', $q)}
}

# Variants subs

#deprecated is now in U2_subs_2 2013/12/23
#sub is_in_interval {
#	my ($var, $mini, $maxi) = @_;
#	my $pos;
#	$var->{'nom_g'} =~ /chr\w+:g\.(\d+)[^\d]+.+/o;
#	$pos = $1;
#	if (($var->{'num_segment'} eq $var->{'num_segment_end'}) && ($pos >= $mini && $pos <= $maxi)) {return 1}
#	else {return 0}
#}

sub color_by_classe {
	my ($classe, $dbh) = @_;
	my $query = "SELECT html_code FROM valid_classe WHERE classe = '$classe';";
	my $res = $dbh->selectrow_hashref($query);
	return $res->{'html_code'};
}
#in variant.pl
sub color_by_rna_status {
	my ($status, $dbh) = @_;
	my $query = "SELECT html_code FROM valid_type_arn WHERE type_arn = '$status';";
	my $res = $dbh->selectrow_hashref($query);
	return $res->{'html_code'};
}


###subs for SIFT using querying with SQLlite or VEP
sub sift_color {
	my $score = shift;
	if ($score < 0.05) {return '#FF0000'}
	else {return '#00A020'}	
}

sub sift_interpretation {
	my $score = shift;
	if ($score < 0.05) {return 'damaging'}
	else {return 'tolerated'}	
}

sub sift_color2 {
	my $res = shift;
	if ($res =~ /deleterious/) {return '#FF0000'}
	else {return '#00A020'}	
}

sub pph2_color {
	my $res = shift;
	if ($res =~ /damaging/) {return '#FF0000'}
	else {return '#00A020'}	
}

sub pph2_color2 {
	my $res = shift;
	if ($res > 0.447) {return '#FF0000'}
	else {return '#00A020'}	
}

sub fathmm_color {
	my $score = shift;
	if ($score < -1.5) {return '#FF0000'}
	else {return '#00A020'}	
}

sub metalr_color {
	my $score = shift;
	if ($score > 0.5) {return '#FF0000'}
	else {return '#00A020'}	
}

sub mcap_color {
	my $score = shift;
	if ($score > 0.025) {return '#FF0000'}
	else {return '#00A020'}	
}

#in variant.pl, engine.pl, gene.pl, ajax.pl
#sub get_interpreted_position2 {
#	my ($result, $dbh, , $q) = @_;
#	#my $spec = '';
#	if ($result->{'type_segment'} eq 'exon') {
#		my ($dist, $label) = U2_modules::U2_subs_1::get_pos_from_intron($result, $dbh);
#		if ($dist <= 3 && $dist >= 0) {if ($type eq 'hash'){return "exonic near $label"}++}elsif ($type eq 'span') {return $q->span(" - exonic near $label")}}
#		elsif ($label eq 'overlap') {if ($type eq 'hash'){$spec->{'overlap junction'}++}elsif ($type eq 'span') {$spec = $q->span(' - overlap junction')}}
#		else {if ($type eq 'hash'){$spec->{'exonic middle'}++}elsif ($type eq 'span') {$spec = $q->span(' - exonic middle')}}
#		
#		if ($dist <= 3 && $dist >= 0) {if ($type eq 'hash'){$spec->{"exonic near $label"}++}elsif ($type eq 'span') {$spec = $q->span(" - exonic near $label")}}
#		elsif ($label eq 'overlap') {if ($type eq 'hash'){$spec->{'overlap junction'}++}elsif ($type eq 'span') {$spec = $q->span(' - overlap junction')}}
#		else {if ($type eq 'hash'){$spec->{'exonic middle'}++}elsif ($type eq 'span') {$spec = $q->span(' - exonic middle')}}
#	}
#	elsif ($result->{'type_segment'} eq 'intron') {
#		my $dist = U2_modules::U2_subs_1::get_pos_from_exon($result->{'nom'});
#		if ($dist < 3 && $dist > 0) {if ($type eq 'hash'){$spec->{'cannonical site'}++}elsif ($type eq 'span') {$spec = $q->span(' - cannonical site')}}
#		elsif ($dist > 100) {if ($type eq 'hash'){$spec->{'deep intronic'}++}elsif ($type eq 'span') {$spec = $q->span(' - deep intronic')}}
#		elsif ($dist != -1) {if ($type eq 'hash'){$spec->{'other intronic'}++}elsif ($type eq 'span') {$spec = $q->span(' - other intronic')}}
#		elsif ($dist == -1) {if ($type eq 'hash'){$spec->{'overlap junction'}++}elsif ($type eq 'span') {$spec = $q->span(' - overlap junction')}}
#	}
#	return $spec;
#}
#in engine.pl, U2_subs_2 (RNA_pie), ajax.pl
sub get_interpreted_position {
	my ($result, $dbh) = @_;
	if ($result->{'type_segment'} eq 'exon') {
		my ($dist, $label) = U2_modules::U2_subs_1::get_pos_from_intron($result, $dbh);
		if ($dist <= 3 && $dist >= 0) {return "exonic near $label"}
		elsif ($label eq 'overlap') {return 'overlap junction'}
		else {return 'exonic middle'}
	}
	elsif ($result->{'type_segment'} eq 'intron') {
		my $dist = U2_modules::U2_subs_1::get_pos_from_exon($result->{'nom'});
		if ($dist < 3 && $dist > 0) {return 'cannonical site'}
		elsif ($dist > 100) {return 'deep intronic'}
		elsif ($dist != -1) {return 'other intronic'}
		elsif ($dist == -1) {return 'overlap junction'}
	}
}

#in variant.pl, patient_genotype.pl, engine.pl, ajax.pl, automated_class.pl
sub extract_pos_from_genomic { #get chr and genomic positions
	my ($genomic, $type) = @_;
	if ($genomic =~ /^chr([\dXY]+):g\.(\d+)[\+-]?\??_?(\d*)[^\d]*/o) {
		#print "--$type--$3--";
		if ($type eq 'clinvar') {return ($1, $2)}
		elsif ($type eq 'evs') {
			if ($3 ne '') {return ($1, $2, $3)}
			else {return ($1, $2, $2)}
		}
	}
}

#in gene_graphs.pl, variant.pl, engine.pl, ajax.pl
sub get_pos_from_exon {
	my $name = shift;
	if ($name !~ /_/ && $name =~ /c\.-?\d+[\+-](\d+)[^_]/o) {return $1}
	elsif ($name =~ /c\.-?\d+([\+-])(\d+)_\d+[\+-](\d+)[^\d]/o) {
		if ($1 eq '+') {return $2}
		elsif ($1 eq '-') {return $3}
	}
	else {return -1}#overlap
}
#in gene_graphs.pl, variant.pl, engine.pl, ajax.pl
sub get_pos_from_intron {
	my ($result, $dbh) = @_;
	my ($nom_g, $gene, $acc, $num_seg, $type_seg, $num_seg_end, $type_seg_end) = ($result->{'nom_g'}, $result->{'nom_gene'}[0], $result->{'nom_gene'}[1], $result->{'num_segment'}, $result->{'type_segment'}, $result->{'num_segment_end'}, $result->{'type_segment_end'});
	#1st extract position(s)
	my ($chr, $pos1, $pos2) = &extract_pos_from_genomic($nom_g, 'evs');
	#2nd get strand
	my $query = "SELECT brin FROM gene WHERE nom[1] = '$gene' AND nom[2] = '$acc';";
	my $res = $dbh->selectrow_hashref($query);
	#possible overlapping?
	
	if ($pos1 == $pos2) {
		#NO - simple case
		return &compute_exonic_positions("SELECT $postgre_start_g, $postgre_end_g, taille FROM segment WHERE nom_gene[1] = '$gene' AND nom_gene[2] = '$acc' AND type = '$type_seg' AND numero = '$num_seg';", $pos1, $res->{'brin'}, $dbh);	
	}
	else {
		if ($type_seg ne $type_seg_end) { #overlap
			return ('-1', 'overlap')
		}
		else {#only exonic
			my ($dist5, $label5) = &compute_exonic_positions("SELECT $postgre_start_g, $postgre_end_g, taille FROM segment WHERE nom_gene[1] = '$gene' AND nom_gene[2] = '$acc' AND type = '$type_seg' AND numero = '$num_seg';", $pos1, $res->{'brin'}, $dbh);
			my ($dist3, $label3) = &compute_exonic_positions("SELECT $postgre_start_g, $postgre_end_g, taille FROM segment WHERE nom_gene[1] = '$gene' AND nom_gene[2] = '$acc' AND type = '$type_seg_end' AND numero = '$num_seg_end';", $pos2, $res->{'brin'}, $dbh);
			if ($dist5 > $dist3) {return ($dist3, $label3)}
			elsif ($dist5 < $dist3) {return ($dist5, $label5)}
			elsif ($dist5 == $dist3) {return ($dist5, 'middle')}
		}		
	}	
}
#same
sub compute_exonic_positions {
	my ($query, $pos, $strand, $dbh) = @_;
	my $res = $dbh->selectrow_hashref($query);
	my ($dist1, $dist2);
	if ($strand eq '+') {($dist1, $dist2) = (($pos - ($res->{$postgre_start_g}-1)), (($res->{$postgre_end_g}+1) - $pos))}#intronic exact 1st nts
	elsif ($strand eq '-') {($dist1, $dist2) = ((($res->{$postgre_start_g}+1) - $pos), ($pos - ($res->{$postgre_end_g}-1)))}
	if ($dist1 <= $res->{'taille'} && $dist2 <= $res->{'taille'}) {
		if ($dist1 > $dist2) {
			#if ($strand eq '+') {return ($dist2, 'donor')}
			#elsif ($strand eq '-') {return ($dist2, 'acceptor')}
			return ($dist2, 'donor')
		}
		elsif ($dist1 < $dist2) {
			#if ($strand eq '+') {return ($dist1, 'acceptor')}
			#if ($strand eq '-') {return ($dist1, 'donor')}
			return ($dist1, 'acceptor')
		}
		else {return ($dist1, 'middle')}
	}
	else {print "size pb with $query-$pos-$dist1-$dist2-$res->{'taille'}::"}	
}



#in variant.pl & variant creation scripts
sub get_deleted_sequence {
	my $mutalyzer_seq = shift;
	if ($mutalyzer_seq =~ /[ATCG]\s([ATGC]+)\s[ATGC]/) {
		return $1
	}
}

sub getExacFromGenoVar {
	my $genomic = shift;
	if ($genomic =~ /chr([0-9XY]{1,2}):g.(\d+)([ATCG])>([ATGC])/o) {
		return "$1-$2-$3-$4"
	}
}

sub is_large {
	my ($var) = shift;
	if ($var->{'taille'} > 50) {return 1}
	else {return 0}
}

#in splicing_calc.pl
sub get_last_exon_number {
	my ($transcript, $dbh) = @_;
	my $query = "SELECT numero-1 as a FROM segment WHERE nom_gene[2] = '$transcript' AND type = '3UTR';";
	my $res = $dbh->selectrow_hashref($query);
	#print "--$res->{'a'}--";
	return $res->{'a'};
}

sub maf {
	my ($dbh, $gene, $acc, $var, $analyse) = @_;
	my $maf = 'NA';
	my $query = "SELECT COUNT(DISTINCT(num_pat)) as a FROM variant2patient b, patient c WHERE b.num_pat = c.numero AND b.id_pat = c.identifiant AND b.type_analyse ~ '$analyse' AND b.nom_gene[1] = '$gene'  AND b.nom_gene[2] = '$acc' AND nom_c = '$var' AND b.statut <> 'homozygous' AND c.proband = 't';";
	my $res_1 = $dbh->selectrow_hashref($query);
	$query = "SELECT COUNT(DISTINCT(num_pat)) as a FROM variant2patient b, patient c WHERE b.num_pat = c.numero AND b.id_pat = c.identifiant AND b.type_analyse ~ '$analyse' AND b.nom_gene[1] = '$gene'  AND b.nom_gene[2] = '$acc' AND nom_c = '$var' AND b.statut = 'homozygous' AND c.proband = 't';";
	my $res_2 = $dbh->selectrow_hashref($query);
	my $alleles = $res_1->{'a'} + ($res_2->{'a'} * 2);
	$query = "SELECT COUNT(DISTINCT(num_pat)) as a FROM analyse_moleculaire b, patient c WHERE b.num_pat = c.numero AND b.id_pat = c.identifiant AND b.type_analyse ~ '$analyse' AND b.nom_gene[1] = '$gene'  AND b.nom_gene[2] = '$acc' AND c.proband = 't';";
	my $res_3 = $dbh->selectrow_hashref($query);
	my $total = $res_3->{'a'} * 2;
	if ($total == 0) {$maf = 'NA';return $maf;}
	$maf = sprintf('%.3f', ($alleles/$total));
	if ($maf == 0) {$maf = 'NA'}
	return $maf;	
}


sub one2three {
    my ($aa) = shift;
    my  %amino_acid = (
	    'A' => 'Ala',
	    'C' => 'Cys',
	    'D' => 'Asp',
	    'E' => 'Glu',
	    'F' => 'Phe',
	    'G' => 'Gly',
	    'H' => 'His',
	    'I' => 'Ile',
	    'K' => 'Lys',
	    'L' => 'Leu',
	    'M' => 'Met',
	    'N' => 'Asn',
	    'P' => 'Pro',
	    'Q' => 'Gln',
	    'R' => 'Arg',
	    'S' => 'Ser',
	    'T' => 'Thr',
	    'V' => 'Val',
	    'W' => 'Trp',
	    'Y' => 'Tyr',
    );
    return $amino_acid{$aa};
}

sub three2one {
    my ($aa) = shift;
    my  %amino_acid = (
	    'Ala' => 'A',
	    'Cys' => 'C',
	    'Asp' => 'D',
	    'Glu' => 'E',
	    'Phe' => 'F',
	    'Gly' => 'G',
	    'His' => 'H',
	    'Ile' => 'I',
	    'Lys' => 'K',
	    'Leu' => 'L',
	    'Met' => 'M',
	    'Asn' => 'N',
	    'Pro' => 'P',
	    'Gln' => 'Q',
	    'Arg' => 'R',
	    'Ser' => 'S',
	    'Thr' => 'T',
	    'Val' => 'V',
	    'Trp' => 'W',
	    'Tyr' => 'Y',
	    'del' => 'del'
    );
    return $amino_acid{$aa};
}

sub nom_three2one{
	my $var = shift;
	$var =~ s/\(//og;
	$var =~ s/\)//og;
	if ($var =~ /^p\.(\w{3})(\d+)(\w{3})$/o) {return &three2one($1).$2.&three2one($3)}
	elsif ($var =~ /^p\.(\w{3})(\d+_)(\w{3})(\d+.+)$/o) {return &three2one($1).$2.&three2one($3).$4}
}

sub get_strand {
	my ($gene, $dbh) = @_;
	my $res = $dbh->selectrow_hashref("SELECT brin FROM gene WHERE nom[1] = '$gene' AND main = 't';");
	my $order = 'ASC';
	if ($res->{'brin'} eq '-') {$order = 'DESC'}
	return $order;
}

sub get_nom_segment_main {
	my ($num, $gene, $dbh) = @_;
	my $query = "SELECT a.nom FROM segment a, gene b WHERE a.nom_gene = b.nom AND a.nom_gene[1] = '$gene' AND b.main = 't' AND a.numero = '$num' AND a.type <> 'intron';";
	my $res = $dbh->selectrow_hashref($query);
	return $res->{'nom'};
}

sub test_mutalyzer {
	my $ua = LWP::UserAgent->new();
	#http://mutalyzer.nl/2.0/services
	my $request = $ua->get('https://mutalyzer.nl/services');
	my $content = $request->content();
	#print "$content<br/>";
	if ($content !~ /soap/o) {return 0}
	else {return 1}
}

sub run_mutalyzer {
	my ($soap, $acc_g, $gene, $var, $mutalyzer_version, $mutalyzer_acc) = @_;
	if ($mutalyzer_acc && $mutalyzer_acc ne '') {$acc_g = $mutalyzer_acc}
	#if ($mutalyzer_acc && $mutalyzer_acc ne '') {$acc_g = $mutalyzer_acc}
	#print "$acc_g($gene$mutalyzer_version:$var";
	#GPR98/ADGRV1 exception
	if ($gene eq 'GPR98') {$gene = 'ADGRV1'}
	my $call = $soap->call('runMutalyzer', SOAP::Data->name('variant')->value("$acc_g($gene$mutalyzer_version):$var"));
	if ($call->fault()) {print "Mutalyzer Fault $var $gene<br/>"}
	return $call;
}


# Other

sub get_date { #returns a date in a specific format
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	my $month = ($mon+1);
	if ($month < 10) {$month = "0$month"}
	if ($mday < 10) {$mday = "0$mday"}
	return (1900+$year)."-$month-".$mday;
}

sub get_run_date {#get date from illumina run_id (pg format)
	my $id = shift;
	$id =~ /^(\d{2})(\d{2})(\d{2})_/o;
	return "20$1-$2-$3";
}

sub date_pg2tjs { #transform date in pg format to timeline format
	my $date = shift;
	$date =~ s/-/,/og;
	return $date;
}

sub translate_boolean {
	my ($boolean) = shift;
	#print "__".$boolean."__";
	#print length($boolean);
	if (defined($boolean) && $boolean == 1) {return '+'}
	elsif(defined($boolean)) {return '-'}
	else {return 'UNDEFINED'}
}

sub translate_boolean_class {
	my ($boolean) = shift;
	if (defined($boolean) && $boolean == 1) {return 'yes'}
	elsif(defined($boolean)) {return 'no'}
	else {return 'undefined'}
}

sub translate_boolean_denovo {
	my ($boolean) = shift;
	if (defined($boolean) && $boolean ne "" && $boolean == 1) {return ' denovo'}
	else {return ''}
}

sub translate_valide_human {
	my ($boolean) = shift;
	if (defined($boolean) && $boolean == 1) {return 'Validated'}
}

sub translate_result_human {
	my ($boolean) = shift;
	if (defined($boolean) && $boolean == 1) {return 'Positive'}
	elsif(defined($boolean)) {return 'Negative'}
	else {return 'Undefined'}
}

#used in add_analysis.pl, import_illumina.pl

sub nas_connexion {
	my ($link, $q) = @_;
	my $SSH_RACKSTATION_LOGIN = $config->SSH_RACKSTATION_LOGIN();
	my $SSH_RACKSTATION_PASSWORD = $config->SSH_RACKSTATION_PASSWORD();
	my $SSH_RACKSTATION_IP = $config->SSH_RACKSTATION_IP();
	#initiate connexion to RackStation where the data actually is
	#we first need to set up the connexion, a little bit difficult under mod_perl as
	#STDIN and STDOUT are not related to real file handles under mod_perl so we need to fix it
	#and Net::OpenSSH requires a secure ctl_dir
	#also needs ~/.ssh (see google .ssh apache) with a proper public key in the known_hosts file
	#need to untaint /dev/null - not sure of the method but it works
	$ENV{PATH} = '/dev/null';
	open my $def, '<', '/dev/null' or die "unable to open /dev/null";
	my $ctl_dir = tempdir(CLEANUP => 1, TMPDIR => 1) or die $!;
	my $ssh = Net::OpenSSH->new("$SSH_RACKSTATION_LOGIN:$SSH_RACKSTATION_PASSWORD\@$SSH_RACKSTATION_IP", default_stdin_fh => $def, default_stdout_fh => $def, ctl_dir => $ctl_dir);
	$ssh->error() and die "$link Can't ssh to RackStation: " . $ssh->error() . $q->br() . "If you see this page, please contact your admin and keep the error message.";
	return $ssh;
}




#sub get_analysis_hash {#returns a hash of available analysis
#	my ($dbh) = shift;
#	my $hash_ref;
#	my $query = 'SELECT type_analyse FROM valid_type_analyse';
#	my $sth = $dbh->prepare($query);
#	my $res = $sth->execute();
#	while (my $result = $sth->fetchrow_hashref()) {
#		$hash_ref->{$result->{'type_analyse'}} = '0';
#	}
#	return $hash_ref;
#}




1;