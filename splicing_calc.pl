BEGIN {delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV', 'PATH'};}

use strict;
#use CGI;
#use DBI;
#use AppConfig qw(:expand :argcount);
use U2_modules::U2_users_1;
use U2_modules::U2_init_1;
use U2_modules::U2_subs_1;
use U2_modules::U2_subs_2;
use File::Temp qw/ :seekable /;
use REST::Client;


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
#		Page for splicing calculations


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

my @styles = ($CSS_PATH.'w3.css', $CSS_DEFAULT, $CSS_PATH.'fullsize/fullsize.css', $CSS_PATH.'jquery.alerts.css');

my $q = new CGI;

my $dbh = DBI->connect(    "DBI:Pg:database=$DB;host=$HOST;",
                        $DB_USER,
                        $DB_PASSWORD,
                        {'RaiseError' => 1}
                ) or die $DBI::errstr;


print $q->header(-type => 'text/html', -'cache-control' => 'no-cache'),
	$q->start_html(-title=>"U2 splicing analysis",
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
                                -src => $JS_PATH.'jquery.autocomplete.min.js', 'defer' => 'defer'},
                                {-language => 'javascript',
                                -src => $JS_DEFAULT, 'defer' => 'defer'}],		
                        -encoding => 'ISO-8859-1');

my $user = U2_modules::U2_users_1->new();


U2_modules::U2_subs_1::standard_begin_html($q, $user->getName(), $dbh);

##end of Basic init
my $DATABASES_PATH = $config->DATABASES_PATH();
$ENV{PATH} = $DATABASES_PATH;
my $var = U2_modules::U2_subs_1::check_nom_g($q, $dbh);


#hg38 transition variable for postgresql 'start_g' segment field
my ($postgre_start_g, $postgre_end_g) = ('start_g', 'end_g');  #hg19 style


if ($q->param('calc') && $q->param('calc') eq 'maxentscan') {
	
	
	
	my ($wt, $mt, $dna_type, $size, $cname, $segment_type, $segment_num, $gene, $nom_seg) = &get_seq($var);
	if ($size < 10 || $dna_type eq 'indel') {
		#print $q->p('ok man');
	
		print $q->p({'class' => 'title'}, "Splicing Predictions for $var ($gene->[0]:$cname / $segment_type $nom_seg)");
		
		#get natural sites positions
		my $query_strand = "SELECT brin FROM gene WHERE nom = '{\"$gene->[0]\",\"$gene->[1]\"}';";
		my $res_strand = $dbh->selectrow_hashref($query_strand);
		my $strand = $res_strand->{'brin'};
		my $query = "SELECT $postgre_start_g, $postgre_end_g, taille FROM segment WHERE nom_gene = '{\"$gene->[0]\",\"$gene->[1]\"}' AND numero = '$segment_num' AND type = '$segment_type';";
		my $res = $dbh->selectrow_hashref($query);
		my ($start_g, $end_g, $seg_size) = ($res->{$postgre_start_g}, $res->{$postgre_end_g}, $res->{'taille'});
		#print $query;
		
		#HTML5 canvas to draw exon/intron and place variant
		#we need var_name, 3 segments #, a position for variant name and a case
		#case a: exonic variant and intronic flanking (<100bp)
		#case b: other intronic
		#a || b
		my ($case, $seg1, $seg2, $seg3, $pos, $label1, $label2) = ('a', '', '', '', 'Intron', 'Intron');
		my $dist_from_exon = U2_modules::U2_subs_1::get_pos_from_exon($cname);
		#print $cname."-".$dist_from_exon;
		if ($segment_type eq 'intron' && $dist_from_exon > 100) {
			#print $q->p('ok man');
			($case, $seg1, $seg2, $seg3) = ('b', $nom_seg, $nom_seg, &get_neighbouring_nom_seg($segment_num+1, $gene->[0], $gene->[1], $segment_type));
			if ($cname =~ /\+/o) {$pos = 200+sprintf('%.0f',(($dist_from_exon/$seg_size)*200))}
			else {$pos = 400-sprintf('%.0f',(($dist_from_exon/$seg_size)*200))}
		}
		else {
			if ($segment_type eq 'intron' && $cname =~ /[^\.]-/o) {
				my $segplus = &get_neighbouring_nom_seg($segment_num+1, $gene->[0], $gene->[1], $segment_type);
				#we need exon size not intron
				$seg_size  = &get_neighbouring_seg_size($segment_num, $gene->[0], $gene->[1], $segment_type);
				($seg1, $seg2, $seg3) = ($nom_seg, $segplus, $segplus);
				($label1, $label2) = &get_label($segment_num, $gene->[1], $segment_type, $cname);
				$pos = 200 - $dist_from_exon;
			}
			else {
				#print $q->p('ok man');
				($seg1, $seg2, $seg3) = (&get_neighbouring_nom_seg($segment_num-1, $gene->[0], $gene->[1], $segment_type), $nom_seg, $nom_seg);
				($label1, $label2) = &get_label($segment_num, $gene->[1], $segment_type, $cname);
				if ($segment_type eq 'intron') {
					$pos = 400 + $dist_from_exon;
					#we need exon size not intron
					$seg_size  = &get_neighbouring_seg_size($segment_num, $gene->[0], $gene->[1], $segment_type);
					#print $q->p('ok man');
				}
				else {
					my $query_var = "SELECT * FROM variant WHERE nom_g = '$var';";
					my $all_info = $dbh->selectrow_hashref($query_var);
					my ($dist, $label_site) = U2_modules::U2_subs_1::get_pos_from_intron($all_info, $dbh);
					if ($label_site eq 'middle') {$pos = 200+sprintf('%.0f',($seg_size/2))}
					elsif ($label_site eq 'donor') {$pos = 400-sprintf('%.0f',(($dist/$seg_size)*200))}
					elsif ($label_site eq 'acceptor') {$pos = 200+sprintf('%.0f',(($dist/$seg_size)*200))}
				}
			}			
		}	
		
		my ($score3, $txt3, $site3, $chr3, $x3, $y3, $score5, $txt5, $site5, $chr5, $x5, $y5);
		$var =~ /(chr[\dXY]+):/o;
		my $chr = $1;
		if ($segment_type eq 'exon') {
			($score3, $txt3, $site3, $chr3, $x3, $y3) = &get_natural($start_g, '3', $segment_type, $strand, $chr, $DATABASES_PATH, $nom_seg);
			($score5, $txt5, $site5, $chr5, $x5, $y5) = &get_natural($end_g, '5', $segment_type, $strand, $chr, $DATABASES_PATH, $nom_seg);
		}
		elsif ($segment_type eq 'intron') {
			($score3, $txt3, $site3, $chr3, $x3, $y3) = &get_natural($end_g, '3', $segment_type, $strand, $chr, $DATABASES_PATH, $nom_seg);
			($score5, $txt5, $site5, $chr5, $x5, $y5) = &get_natural($start_g, '5', $segment_type, $strand, $chr, $DATABASES_PATH, $nom_seg);
		}
		#if ($segment_type eq 'intron') {my ($score5, $txt5, $site5, $chr5, $x5, $y5) = &get_natural($start_g, '5', $segment_type, $strand, $chr, $DATABASES_PATH, $nom_seg)}
		#elsif ($segment_type eq 'exon') {my ($score5, $txt5, $site5, $chr5, $x5, $y5) = &get_natural($end_g, '5', $segment_type, $strand, $chr, $DATABASES_PATH, $nom_seg)}
		#print $score5->[0];
		
		my $js = U2_modules::U2_subs_2::segment_canvas($cname, $seg1, $seg2, $seg3, $pos, $case, $seg_size, $label1, $label2, $score3, $score5);
		print $q->start_div({'class' => 'container center'}), "\n<canvas class=\"ambitious\" width = \"600\" height = \"150\" id=\"segment_drawing\">Change web browser for a more recent please!</canvas>", $q->end_div(), "\n", $q->script({'type' => 'text/javascript'}, $js), "\n";
		
		
		
		
		my ($window3_wt, $window3_mt, $html3_wt, $html3_mt) = &build_window($wt, $mt, $dna_type, $size, '22');
		my ($score3_wt, $txt3_wt) = &get_maxent_score('3', $window3_wt, $DATABASES_PATH);	
		my ($score3_mt, $txt3_mt) = &get_maxent_score('3', $window3_mt, $DATABASES_PATH);
		print $q->br(), $q->br(), $q->p({'class' => 'title'}, '3\'ss (acceptor) MaxEntScan scores'), "\n",
			$q->start_div({'class' => 'container'}), $q->start_table({'class' => 'technical great_table'}), "\n",
			$q->start_Tr(), "\n",
				$q->th({'class' => 'left_general'}, 'WT sequence'), "\n",
				$q->th({'class' => 'left_general'}, 'Score 3\''), "\n",
				$q->th({'class' => 'left_general'}, 'MT sequence'), "\n",
				$q->th({'class' => 'left_general'}, 'Score 3\''), "\n",
			$q->end_Tr(), "\n";
		my $i = 0;
		my $html = '';
		
		foreach (@{$score3_wt}) {
			if ($_ < 0 && (!$score3_mt->[$i] || $score3_mt->[$i] < 0)) {$i++;next;}
			$html .= $q->start_Tr()."\n".
				$q->start_td().$html3_wt->[$i].$q->br().$txt3_wt->[$i].$q->end_td()."\n".
				$q->td($_)."\n".
				$q->start_td().$html3_mt->[$i].$q->br().$txt3_mt->[$i].$q->end_td()."\n".
				$q->td($score3_mt->[$i])."\n".
			$q->end_Tr()."\n";
			$i++;
		}
		if ($html eq '') {
			print $q->start_Tr(), "\n",
				$q->td({'colspan' => '4'}, 'No notable 3\'ss score to display'), "\n",
			$q->end_Tr();
		}
		else {print $html;$html = '';}
		
		print $q->end_table(), $q->end_div(), "\n";
		$var =~ /(chr[\dXY]+):/o;
		my $chr = $1;
		&print_natural($score3, $txt3, $site3, $chr3, $x3, $y3, $segment_type, $nom_seg, '3');
		#if ($segment_type eq 'exon') {&get_natural($start_g, '3', $segment_type, $strand, $chr, $DATABASES_PATH, $nom_seg)}
		#elsif ($segment_type eq 'intron') {&get_natural($end_g, '3', $segment_type, $strand, $chr, $DATABASES_PATH, $nom_seg)}
		
		print $q->br(), $q->br(), $q->br();
		
		my ($window5_wt, $window5_mt, $html5_wt, $html5_mt) = &build_window($wt, $mt, $dna_type, $size, '8');
		my ($score5_wt, $txt5_wt) = &get_maxent_score('5', $window5_wt, $DATABASES_PATH);
		my ($score5_mt, $txt5_mt) = &get_maxent_score('5', $window5_mt, $DATABASES_PATH);
			
		print $q->p({'class' => 'title'}, '5\'ss (donor) MaxEntScan scores'), "\n",
			$q->start_div({'class' => 'container'}), $q->start_table({'class' => 'technical great_table'}), "\n",
			$q->start_Tr(), "\n",
				$q->th({'class' => 'left_general'}, 'WT sequence'), "\n",
				$q->th({'class' => 'left_general'}, 'Score 5\''), "\n",
				$q->th({'class' => 'left_general'}, 'MT sequence'), "\n",
				$q->th({'class' => 'left_general'}, 'Score 5\''), "\n",
			$q->end_Tr(), "\n";
		my $i = 0;
		foreach (@{$score5_wt}) {
			if ($_ < 0 && (!$score5_mt->[$i] || $score5_mt->[$i] < 0)) {$i++;next;}
			$html .= $q->start_Tr()."\n".
				$q->start_td().$html5_wt->[$i].$q->br().$txt5_wt->[$i].$q->end_td()."\n".
				$q->td($_)."\n".
				$q->start_td().$html5_mt->[$i].$q->br().$txt5_mt->[$i].$q->end_td()."\n".
				$q->td($score5_mt->[$i])."\n".
			$q->end_Tr()."\n";
			$i++;
		}
		if ($html eq '') {
			print $q->start_Tr(), "\n",
				$q->td({'colspan' => '4'}, 'No notable 5\'ss score to display'), "\n",
			$q->end_Tr();
		}
		else {print $html;}
		print $q->end_table(), $q->end_div(), $q->br(), $q->br(), "\n";
		
		&print_natural($score5, $txt5, $site5, $chr5, $x5, $y5, $segment_type, $nom_seg, '5');
		#if ($segment_type eq 'intron') {&get_natural($start_g, '5', $segment_type, $strand, $chr, $DATABASES_PATH, $nom_seg)}
		#elsif ($segment_type eq 'exon') {&get_natural($end_g, '5', $segment_type, $strand, $chr, $DATABASES_PATH, $nom_seg)}
	}
	else {
		print $q->p('USHVaM 2 is not currently confident on its own ability to provide accurate data on splicing for variants > 10 bp or for indels');
	}
	
	#print $q->start_p(), $q->span('MaxEnt predictions are made with '), $q->a({'href' => 'http://genes.mit.edu/burgelab/maxent/Xmaxentscan_scoreseq.html', 'target' => '_blank'}, 'MaxEntScan'), $q->span('. Sequences are dynamically retrieved by ushvam2, which builds all possible input sequences for maxent given the variant and displays interesting ones as well as natural sites scores for comparison.'), $q->end_p(), "\n";
	my $text = $q->span('MaxEnt predictions are made with ').
		$q->a({'href' => 'http://genes.mit.edu/burgelab/maxent/Xmaxentscan_scoreseq.html', 'target' => '_blank'}, 'MaxEntScan').
		$q->span('. ').$q->br().$q->span('Sequences are dynamically retrieved by ushvam2, which builds all possible input sequences for maxent given the variant and displays interesting ones as well as natural sites scores for comparison.');
	print U2_modules::U2_subs_2::info_panel($text, $q);
	
}
my @hyphen = split(/-/, U2_modules::U2_subs_1::getExacFromGenoVar($var));
my ($chr, $pos, $wt, $mt) = ($hyphen[0], $hyphen[1], $hyphen[2], $hyphen[3]);
if ($q->param('retrieve') && $q->param('retrieve') eq 'spidex') {
	#my $var = U2_modules::U2_subs_1::check_nom_g($q, $dbh);
	#my @hyphen = split(/-/, U2_modules::U2_subs_1::getExacFromGenoVar($var));
	#my ($chr, $pos, $wt, $mt) = ($hyphen[0], $hyphen[1], $hyphen[2], $hyphen[3]);
	#print "$EXE_PATH/tabix $DATABASES_PATH/spidex_public_noncommercial_v1.0/spidex_public_noncommercial_v1_0.tab.gz chr$chr:$pos-$pos";
	my @spidex = split(/\n/, `$DATABASES_PATH/htslib-1.2.1/tabix $DATABASES_PATH/spidex_public_noncommercial_v1.0/spidex_public_noncommercial_v1_0.tab.gz chr$chr:$pos-$pos`);
	#print "$DATABASES_PATH/htslib-1.2.1/tabix $DATABASES_PATH/spidex_public_noncommercial_v1.0/spidex_public_noncommercial_v1_0.tab.gz chr$chr:$pos-$pos";
	foreach (@spidex) {
		#print $_;
		if (/\t$wt\t$mt\t/) {
			my @res = split(/\t/, $_);
			print $q->br(), $q->br(),
			$q->p({'class' => 'title'}, 'Spidex Results*'), "\n",
			$q->start_div({'class' => 'container'}), $q->start_table({'class' => 'technical great_table'}), "\n",
			$q->start_Tr(), "\n",
				$q->th({'class' => 'left_general'}, 'Variant'), "\n",
				$q->th({'class' => 'left_general'}, 'SPANR dPSI (%)'), "\n",
				$q->th({'class' => 'left_general'}, 'dPSI Z-score'), "\n",
			$q->end_Tr(), "\n",
			$q->start_Tr(), "\n",
				$q->td($var), "\n",
				$q->td(sprintf('%.2f', $res[4])), "\n",
				$q->td(sprintf('%.2f', $res[5])), "\n",
			$q->end_Tr(), "\n",
			$q->end_table(),$q->end_div(), $q->br(), $q->br(), "\n";
			
			my $text = $q->span('*').
				$q->a({'href' => 'http://www.deepgenomics.com/spidex', 'target' => '_blank'}, 'Spidex').$q->span(' is a dataset which provide access, for all variants in and around 300bp of exons, to ').$q->a({'href' => 'http://tools.genes.toronto.edu/', 'target' => '_blank'}, 'SPANR').$q->span(' predictions').$q->br().$q->span('percent inclusion ratio (PSI) of the affected exon given the wildtype and the mutant sequence).')."\n".
				$q->start_ul().
					$q->li('dPSI: The delta PSI. This is the predicted change in percent-inclusion due to the variant, reported as the maximum across tissues (in percent).').
					$q->li('dPSI z-score: This is the z-score of dpsi_max_tissue relative to the distribution of dPSI that are due to common SNP. 0 means dPSI equals to mean common SNP. A negative score means dPSI is less than mean common SNP dataset, positive greater.').
				$q->end_ul()."\n";
				print U2_modules::U2_subs_2::info_panel($text, $q);
		}		
	}
}

if ($q->param('find') && $q->param('find') eq 'dbscSNV') {
	
	my @dbscsnv = split(/\n/, `$DATABASES_PATH/htslib-1.2.1/tabix $DATABASES_PATH/dbscSNV/dbscSNV.txt.gz $chr:$pos-$pos`);
	my ($rf_content, $ada_content) = (U2_modules::U2_subs_2::info_panel('no RF score', $q), U2_modules::U2_subs_2::info_panel('no ADA score', $q));
	foreach (@dbscsnv) {
		if (/\t$wt\t$mt\t/) {
			my @res = split(/\t/, $_);
			print $q->br(), $q->br(),
			$q->p({'class' => 'title'}, 'dbscSNV Results*'), "\n",
			$q->start_div({'class' => 'container'}), $q->start_table({'class' => 'technical great_table'}), "\n",
			$q->start_Tr(), "\n",
				$q->th({'class' => 'left_general'}, 'Variant'), "\n",
				$q->th({'class' => 'left_general'}, 'dbscSNV Random Forest Score'), "\n",
				$q->th({'class' => 'left_general'}, 'dbscSNV ADA score'), "\n",
			$q->end_Tr(), "\n",
			$q->start_Tr(), "\n",
				$q->td($var), "\n";
			$rf_content = sprintf('%.2f', $res[15]);
			$ada_content = sprintf('%.2f', $res[14]);
		}
	}
	print $q->td($rf_content), $q->td($ada_content), $q->end_Tr(), "\n",
			$q->end_table(),$q->end_div(), "\n";	
	my $text .=$q->span('**').
		$q->a({'href' => 'http://nar.oxfordjournals.org/content/42/22/13534.full', 'target' => '_blank'}, 'dbscSNV').
		$q->span(' is a dataset which provide access, for all variants located into identified intron/exon junctions ').$q->br().
		$q->span({'class' => 'gras'}, '(-3 to +8 at the 5\' splice site and -12 to +2 at the 3\' splice site)').
		$q->span(' to precomputed splicing alterations likelyhood scores. These scores called Random Forest or ADA depending on the learning machine used rely on both MaxEntScan and Position Weight Matrix (Shapiro) prediction scores.').$q->br().
		$q->span({'class' => 'gras'}, 'The closer to 1, the likely to disrupt splicing.').$q->end_p()."\n";
	print U2_modules::U2_subs_2::info_panel($text, $q);
	
	
	#my $gene = U2_modules::U2_subs_1::get_gene_from_nom_g($q, $dbh);
	#my $tempfile = File::Temp->new(UNLINK => 1);
	#if ($var =~ /chr([\dXY]+):g\.(\d+)([ATGC])>([ATGC])/o) {print $tempfile "$1 $2 $2 $3/$4 +\n";}
	#else {print "pb with variant $var with VEP"}
	#if ($tempfile->filename() =~ /(\/tmp\/\w+)/o) {
	#	delete $ENV{PATH};
	#	my @results = split('\n', `$DATABASES_PATH/variant_effect_predictor_81/variant_effect_predictor.pl --fasta $DATABASES_PATH/.vep/homo_sapiens/75/Homo_sapiens.GRCh37.75.dna.primary_assembly.fa --offline --cache --compress "gunzip -c" --refseq --no_progress -q --fork 4 --no_stats --dir $DATABASES_PATH/.vep/ --force -i $1 --plugin dbscSNV,$DATABASES_PATH/dbscSNV/dbscSNV.txt.gz -o STDOUT`); ###VEP78
	#	#print "$DATABASES_PATH/variant_effect_predictor_78/variant_effect_predictor.pl --fasta $DATABASES_PATH/.vep/homo_sapiens/78_GRCh37/Homo_sapiens.GRCh37.75.dna.primary_assembly.fa --offline --cache --compress \"gunzip -c\" --refseq --no_progress -q --fork 4 --no_stats --dir $DATABASES_PATH/.vep/ --force -i $1 --plugin dbscSNV,$DATABASES_PATH/dbscSNV/dbscSNV.txt.gz -o STDOUT";
	#	
	#	if ($gene->[1] =~ /(N[MR]_\d+)/o) {
	#		my @good_line = grep(/$1/, @results);
	#		print $q->br(), $q->br(),
	#		$q->p({'class' => 'title'}, 'dbscSNV Results*'), "\n",
	#		$q->start_div({'class' => 'container'}), $q->start_table({'class' => 'technical great_table'}), "\n",
	#		$q->start_Tr(), "\n",
	#			$q->th({'class' => 'left_general'}, 'Variant'), "\n",
	#			$q->th({'class' => 'left_general'}, 'dbscSNV Random Forest Score'), "\n",
	#			$q->th({'class' => 'left_general'}, 'dbscSNV ADA score'), "\n",
	#		$q->end_Tr(), "\n",
	#		$q->start_Tr(), "\n",
	#			$q->td($var), "\n";
	#		my ($rf_content, $ada_content) = ('no RF score', 'no ADA score');
	#		if ($good_line[0] =~ /rf_score=([\d\.]+);*/o) {
	#			$rf_content = sprintf('%.2f', $1)
	#		}
	#		if ($good_line[0] =~ /ada_score=([\d\.]+);*/o) {
	#			$ada_content = sprintf('%.2f', $1)
	#		}
	#		print $q->td($rf_content), $q->td($ada_content), $q->end_Tr(), "\n",
	#		$q->end_table(),$q->end_div(), $q->br(), $q->br(), "\n",		
	#		$q->start_p(), $q->span('**'), $q->a({'href' => 'http://nar.oxfordjournals.org/content/42/22/13534.full', 'target' => '_blank'}, 'dbscSNV'), $q->span(' is a dataset which provide access, for all variants located into identified intron/exon junctions '), $q->span({'class' => 'gras'}, '(-3 to +8 at the 5\' splice site and -12 to +2 at the 3\' splice site)'), $q->span(' to precomputed splicing alterations likelyhood scores. These scores called random Forest or ADA depending on the learning machine used rely on both MaxEntScan and Position Weight Matrix (Shapiro) prediction scores.'), $q->br(), $q->span({'class' => 'gras'}, 'The closer to 1, the likely to disrupt splicing.'), $q->end_p(), "\n";
	#	}
	#	#foreach(@results) {print "$_<br/>"}
	#}
}


##Basic end of USHVaM 2 perl scripts:

U2_modules::U2_subs_1::standard_end_html($q);

print $q->end_html();

exit();

##End of Basic end

##specific subs for current script

sub get_seq {
	my $var = shift;
	my $query = "SELECT a.seq_wt, a.seq_mt, a.type_adn, a.type_segment, a.num_segment, a.nom, a.taille, a.nom_gene, b.nom as nom_seg FROM variant a, segment b WHERE a.num_segment = b.numero AND a.type_segment = b.type AND a.nom_gene = b.nom_gene AND a.nom_g = '$var';";
	my $res = $dbh->selectrow_hashref($query);
	$res->{'seq_wt'} =~ /([ATCG]{25})\s+([ATGC-]+)\s+([ATCG]{25})/o or die "bad seq in get_seq in splicing_calc.pl for var $var ($res->{'nom'})";
	my @wt = ($1, $2, $3);
	$res->{'seq_mt'} =~ /([ATCG]{25})\s+([ATGC-]+)\s+([ATCG]{25})/o or die "bad seq in get_seq in splicing_calc.pl for var $var ($res->{'nom'})";
	my @mt = ($1, $2, $3);
	
	return (\@wt, \@mt, $res->{'type_adn'}, $res->{'taille'}, $res->{'nom'}, $res->{'type_segment'}, $res->{'num_segment'}, $res->{'nom_gene'}, $res->{'nom_seg'});	
}

sub build_window {
	my ($wt, $mt, $dna_type, $size, $window_size) = @_;
	my (@window_wt, @window_mt, @html_wt, @html_mt);
	my ($temp_wt, $temp_mt, $temp_html_wt, $temp_html_mt);
	if ($dna_type eq 'substitution') {
		for (my $i = -$window_size; $i <= 0; $i++) {
			$temp_wt = substr($wt->[0], $i, -$i).$wt->[1];
			$temp_html_wt = substr($wt->[0], $i, -$i).$q->span({'class' => 'red'}, $wt->[1]);
			$temp_mt = substr($mt->[0], $i, -$i).$mt->[1];
			$temp_html_mt = substr($mt->[0], $i, -$i).$q->span({'class' => 'red'}, $mt->[1]);
			if ($i > -$window_size) {
				$temp_wt .= substr($wt->[2], 0, ($i+$window_size));
				$temp_html_wt .= substr($wt->[2], 0, ($i+$window_size));
				$temp_mt .= substr($mt->[2], 0, ($i+$window_size));
				$temp_html_mt .= substr($wt->[2], 0, ($i+$window_size));
			}
			push @window_wt, $temp_wt;
			push @html_wt, $temp_html_wt;
			push @window_mt, $temp_mt;
			push @html_mt, $temp_html_mt;
			
		}
	}
	elsif ($dna_type eq 'deletion') {
		for (my $i = -$window_size+$size+1; $i < $size; $i++) {
			if ($i <= 0) {
				$temp_wt = substr($wt->[0], $i, -$i).$wt->[1].substr($wt->[2], 0, ($i+($window_size-($size-1))));
				$temp_html_wt = substr($wt->[0], $i, -$i).$q->span({'class' => 'red'}, $wt->[1]).substr($wt->[2], 0, ($i+($window_size-($size-1))));
				$temp_mt = substr($mt->[0], $i, -$i).substr($mt->[2], 0, ($i+$window_size+1));
				$temp_html_mt = substr($mt->[0], $i, -$i).$q->span({'class' => 'red'}, $mt->[1]).substr($mt->[2], 0, ($i+($window_size+1)));
			}
			else {
				$temp_wt = substr($wt->[1], $i, $size-$i).substr($wt->[2], 0, ($i+($window_size-($size-1))));
				$temp_html_wt = $q->span({'class' => 'red'}, substr($wt->[1], $i, $size-$i)).substr($wt->[2], 0, ($i+($window_size-($size-1))));
				$temp_mt = substr($mt->[2], $i, ($window_size+1));
				$temp_html_mt = $q->span({'class' => 'red'}, substr($mt->[1], $i, $size-$i)).substr($mt->[2], $i, ($window_size+1));
			}
			#print $temp_wt."<br/>";
			push @window_wt, $temp_wt;
			push @html_wt, $temp_html_wt;
			push @window_mt, $temp_mt;
			push @html_mt, $temp_html_mt;
		}
	}
	elsif ($dna_type eq 'duplication' || $dna_type eq 'insertion') {
		for (my $i = -$window_size+$size+1; $i < $size; $i++) {
			if ($i <= 0) {
				$temp_wt = substr($wt->[0], $i, -$i).substr($wt->[2], 0, ($i+$window_size+1));
				$temp_html_wt = substr($wt->[0], $i, -$i).$q->span({'class' => 'red'}, $wt->[1]).substr($wt->[2], 0, ($i+$window_size+1));
				$temp_mt = substr($mt->[0], $i, -$i).$mt->[1].substr($mt->[2], 0, ($i+($window_size-($size-1))));
				$temp_html_mt = substr($mt->[0], $i, -$i).$q->span({'class' => 'red'}, $mt->[1]).substr($mt->[2], 0, (($i+$window_size-($size-1))));
			}
			else {
				$temp_wt = substr($wt->[2], 0, ($window_size+1));
				$temp_html_wt = $q->span({'class' => 'red'}, substr($wt->[1], $i, $size-$i)).substr($wt->[2], 0, ($window_size+1));
				$temp_mt = substr($mt->[1], $i, $size-$i).substr($mt->[2], $i, ($i+($window_size-($size-1))));
				$temp_html_mt = $q->span({'class' => 'red'}, substr($mt->[1], $i, $size-$i)).substr($mt->[2], $i, ($i+($window_size-($size-1))));
			}
			#print $temp_wt."<br/>";
			push @window_wt, $temp_wt;
			push @html_wt, $temp_html_wt;
			push @window_mt, $temp_mt;
			push @html_mt, $temp_html_mt;
		}
	}
	return (\@window_wt, \@window_mt, \@html_wt, \@html_mt);
}

sub get_natural {
	my ($pos, $version, $type, $strand, $chr, $path, $nom) = @_;
	my $client = REST::Client->new();
	my ($x, $y);
	if ($version == 3) {
		if ($type eq 'exon' && $strand eq '+') {$x = $pos-20;$y = $pos+2;}
		elsif ($type eq 'exon' && $strand eq '-') {$x = $pos-2;$y = $pos+20;}
		elsif ($type eq 'intron' && $strand eq '+') {$x = $pos-19;$y = $pos+3;}
		elsif ($type eq 'intron' && $strand eq '-') {$x = $pos-3;$y = $pos+19;}		
	}
	elsif ($version == 5) {
		if ($type eq 'exon' && $strand eq '+') {$x = $pos-2;$y = $pos+6;}
		elsif ($type eq 'exon' && $strand eq '-') {$x = $pos-6;$y = $pos+2;}
		elsif ($type eq 'intron' && $strand eq '+') {$x = $pos-3;$y = $pos+5;}
		elsif ($type eq 'intron' && $strand eq '-') {$x = $pos-5;$y = $pos+3;}		
	}
	
	$client->GET("http://togows.org/api/ucsc/hg19/$chr:$x-$y");
	push my @seq, $client->responseContent();
	#print $client->responseContent();
	if ($strand eq '-') {
		my $seqrev = reverse $seq[0];
		$seqrev =~ tr/acgtACGT/tgcaTGCA/;
		$seq[0] = $seqrev;
	}
	my ($score, $txt) = &get_maxent_score($version, \@seq, $path);
	
	my $site = 'acceptor';
	if ($version == 5) {$site = 'donor'}
	
	return ($score, $txt, $site, $chr, $x, $y);
	
}

sub print_natural {
	my ($score, $txt, $site, $chr, $x, $y, $type, $nom, $version) = @_;
	print $q->start_div({'class' => 'container'}), $q->start_table({'class' => 'technical great_table'}), "\n",
		$q->start_Tr(), "\n",
			$q->start_th({'class' => 'left_general'}), $q->span("Natural $site site ("), $q->a({'href' => "http://genome.ucsc.edu/cgi-bin/hgTracks?db=hg19&position=$chr%3A$x-$y", 'target' => '_blank'}, 'UCSC'), $q->span(") / $type $nom"), "\n",
			$q->th({'class' => 'left_general'}, "Score $version\'"), "\n",
		$q->end_Tr(), "\n",
		$q->start_Tr(), "\n",
			$q->td($txt->[0]), "\n",
			$q->td($score->[0]), "\n",
		$q->end_Tr(), "\n",
		$q->end_table(), $q->end_div(), "\n";
}

sub get_maxent_score {
	my ($version, $input, $path) = @_;
	my $tempfile = File::Temp->new(UNLINK => 1);
	my (@scores, @txt);
	foreach(@{$input}) {print $tempfile "$_\n"}	
	if ($tempfile->filename() =~ /(\/tmp\/\w+)/o) {
		delete $ENV{PATH};
		my @temp = split(/\n/, `perl $path/maxentscan/score$version.pl $1 $path/maxentscan`);
		foreach(@temp) {
			if (/^([ATCG]+)\s+(-?[\d\.]+)$/o) {
				push @scores, $2;
				if ($version == 5) {push @txt, substr($1, 0, 3).lc(substr($1, 3, 6))}
				else {push @txt, lc(substr($1, 0, 20)).substr($1, 20, 22)}
			}			
		}
	}
	return (\@scores, \@txt);
}
sub get_label {
	my ($number, $transcript, $type, $name) = @_;
	#print U2_modules::U2_subs_1::get_last_exon_number($transcript, $dbh);
	if ($type eq 'exon' && U2_modules::U2_subs_1::get_last_exon_number($transcript, $dbh) == 1) {return ('3UTR', '5UTR')}
	elsif ($type eq 'exon' && $number == U2_modules::U2_subs_1::get_last_exon_number($transcript, $dbh)) {return ('Intron', '5UTR')}
	elsif ($type eq 'intron' && ($number+1) == U2_modules::U2_subs_1::get_last_exon_number($transcript, $dbh) && $name =~ /[^\.]-/o) {return ('Intron', '5UTR')}
	elsif (($type eq 'exon' && $number == 1) || ($type eq 'intron' && $number == 1 && $name =~ /\+/o)) {return ('3UTR', 'Intron')}
	else {return ('Intron', 'Intron')}
}
sub get_neighbouring_nom_seg {
	my ($number, $gene, $transcript, $type) = @_;
	#my $query_nom = "SELECT nom_seg FROM segment WHERE numero = '$number' AND nom_gene = '{\"$gene\",\"$transcript\"}' AND type = '$type';";
	my $res = $dbh->selectrow_hashref("SELECT nom FROM segment WHERE numero = '$number' AND nom_gene = '{\"$gene\",\"$transcript\"}' AND type != '$type';");
	return $res->{'nom'};
}
sub get_neighbouring_seg_size {
	my ($number, $gene, $transcript, $type) = @_;
	#my $query_nom = "SELECT nom_seg FROM segment WHERE numero = '$number' AND nom_gene = '{\"$gene\",\"$transcript\"}' AND type = '$type';";
	my $res = $dbh->selectrow_hashref("SELECT taille FROM segment WHERE numero = '$number' AND nom_gene = '{\"$gene\",\"$transcript\"}' AND type != '$type';");
	return $res->{'taille'};
}
