package U2_modules::QMetricsOut;
use Moose;
use Data::Dumper;
use Statistics::Basic qw(mean stddev);
use List::AllUtils qw(pairwise sum max min );
use Path::Class ();
use Math::BigFloat;
use Moose::Util::TypeConstraints;
use List::Util qw/ sum/;
use POSIX qw/ceil/;

# "stolen" from https://github.com/enigmabbott/illumina_interop/tree/master

subtype 'PCFile',
  as 'Path::Class::File';

coerce 'PCFile',
  from 'Str',
  via { Path::Class::file($_); };

has 'file' => ( is => 'ro', isa => 'PCFile', coerce => 1);

has 'version' => ( is => 'rw', isa => 'Int',);
has 'record_length' => ( is => 'rw', isa => 'Int',);
has 'file_data' => ( is => 'rw', isa => 'HashRef', lazy_build => 1);

=cut 
Quality Metrics (QMetricsOut.bin) Format:
Version 5:
    byte 0: file version number (5)
    byte 1: length of each record
    byte 2: quality score binning (byte flag representing if binning was on

    if (byte 2 == 1) // quality score binning on

    byte 3: number of quality score bins, B
    bytes 4 – (4+B-1): lower boundary of quality score bins
    bytes (4+B) – (4+2*B-1): upper boundary of quality score bins
    bytes (4+2*B) – (4+3*B-1): remapped scores of quality score bins

    The remaining bytes are for the records, with each record in this forma

    2 bytes: lane number (uint16)
    2 bytes: tile number (uint16)
    2 bytes: cycle number (uint16)

    4 x 50 bytes: number of clusters assigned score (uint32) Q1 through Q50 Where N is the record index

Version 6:
    byte 0: file version number (6)
    byte 1: length of each record
    byte 2: quality score binning (byte flag representing if binning was on)
    if (byte 2 == 1) // quality score binning on
        byte 3: number of quality score bins, B
        bytes 4 - (4+B-1): lower boundary of quality score bins
        bytes (4+B) - (4+2*B-1): upper boundary of quality score bins
        bytes (4+2*B) - (4+3*B-1): remapped scores of quality score bins
        The remaining bytes are for the records, with each record in this format:

        2 bytes: lane number (uint16)
        2 bytes: tile number (uint16)
        2 bytes: cycle number (uint16)
        if (byte 2 == 1)
            4 x B bytes: number of clusters assigned to Q-score bins 1 - B (uint32)
        else
            4 x 50 bytes: number of clusters assigned score Q1 through Q50 (uint32) Where N is the record index  (same as version 5)

perl notes:

C  An unsigned char (octet) value.
S  An unsigned short value (16-bit)
L  An unsigned long value.i (32-bit)
=cut

sub BUILD { 
    my $self = shift;
    open(SAV, $self->file) or die;

    my $line;
    read(SAV,$line,2) or die;
    close SAV;
    my ($version, $record_length) = unpack('CC',$line) ;

    $self->version($version);
    $self->record_length($record_length);
    
    return 1 if $version == 5 or $version == 4 or $version == 6;

    die "version: $version is not support";
}

sub _build_file_data {
    my $self = shift;

    open(SAV, $self->file) or die;
    my $rec;
    my ($binning_on, $B);
    my %temp_data;

#need to skip forward
    if($self->version >= 5){
        read(SAV, $rec, 3)  || return undef;
        my @parse= unpack('CCC',$rec);
        if($parse[$#parse]){ #binning turned on
            $binning_on++;
            read(SAV, $rec, 1)  || return undef;
            $B =  unpack('C', $rec);
            read(SAV, $rec, + (3*$B) ) || return undef;
        }
    }else{
        read(SAV, $rec, 2)  || return undef;
    }
    
    my $record_length= $self->record_length;
    local $/ = \$record_length;

    my %data;
    if($self->version == 6 && $binning_on)  {

#http://www.illumina.com/documents/products/whitepapers/whitepaper_datacompression.pdf
        my %bin_to_avg_quality = (1  => 6, 2 =>15, 3 => 22, 4 => 27, 5 => 33, 6 => 37, 7 => 40);
        my $q30_start_bin = 4;

        while($rec=<SAV>){ 
            my ($lane, $tile, $cycle, @qscore_bins) =  unpack( "S3L".$B, $rec);

            my $tally = 0;
            for my $i (1 .. @qscore_bins) {
                $tally += $qscore_bins[$i - 1] * $bin_to_avg_quality{$i};
            }

             $temp_data{$lane}->{$cycle}->{$tile}->{all_qscores_weighted} =  $tally;
             $temp_data{$lane}->{$cycle}->{$tile}->{q30} = sum( (@qscore_bins[$q30_start_bin .. $#qscore_bins]));
             $temp_data{$lane}->{$cycle}->{$tile}->{all_qscore_instances} = sum(@qscore_bins);
        }
    }else {
        while($rec=<SAV>){ 
            my ($lane, $tile, $cycle, @qscore_counts) =   unpack( "S3L50", $rec);

            my $tally = 0;
            for my $i (1 .. @qscore_counts) {
                $tally += $qscore_counts[$i - 1] * $i;
            }

             $temp_data{$lane}->{$cycle}->{$tile}->{all_qscores_weighted} =  $tally;
             $temp_data{$lane}->{$cycle}->{$tile}->{q30} = sum( (@qscore_counts[29 .. $#qscore_counts]));
             $temp_data{$lane}->{$cycle}->{$tile}->{all_qscore_instances} = sum(@qscore_counts);
        }
    }
    close SAV;

    for my $lane ( keys %temp_data){
        for my $cycle( keys %{$temp_data{$lane}}){
            my $count = scalar( keys %{$temp_data{$lane}->{$cycle}});
            $data{$lane}->{$cycle}->{bcl_count}=$count;
            for my $tile( keys %{$temp_data{$lane}->{$cycle}}){
                $data{$lane}->{$cycle}->{all_qscores_weighted} +=  $temp_data{$lane}->{$cycle}->{$tile}->{all_qscores_weighted};
                $data{$lane}->{$cycle}->{q30} += $temp_data{$lane}->{$cycle}->{$tile}->{q30} ;
                $data{$lane}->{$cycle}->{all_qscore_instances} += $temp_data{$lane}->{$cycle}->{$tile}->{all_qscore_instances};
            }
        }
    }

    return \%data;
}

#this is truly the max of all the data which has come through
sub max_cycle {
    my $data = $_[0]->file_data or return;
    return max( map{keys %{$data->{$_}} } keys %$data );
}

#this is the max cycle shared across all lanes
sub max_cycle_all_lanes {
    my $data = $_[0]->file_data or return;

#assumption: lane1 cycle1 will always have all bcls
    my $tile_count=$data->{1}->{1}->{bcl_count} or return 0;
    my @maxes;
    for my $lane (keys %$data){
        my $h= $data->{$lane};
#keys %$h is cycles
        my ($x) = sort {$b <=> $a} grep {$h->{$_}->{bcl_count} == $tile_count}  keys %$h;
        push @maxes, $x if $x;
    }
    return 0  unless @maxes;
    return min @maxes;
}

sub average_qscore {
    my ($self,%p) =@_;
    my $data = $self->file_data or return;

    my $start_cycle = $p{start_cycle};
    my $end_cycle = $p{end_cycle};
    my $lane = $p{lane};

    my $num  = sum( map{$data->{$lane}->{$_}->{all_qscores_weighted}} grep{ $data->{$lane}->{$_}}($start_cycle .. $end_cycle)) or return;
    my $den= sum( map{$data->{$lane}->{$_}->{all_qscore_instances}} grep{ $data->{$lane}->{$_}}($start_cycle .. $end_cycle));
    my $x = Math::BigFloat->new( ($num/$den));
    $x->precision(-1);
    return $x . '';
}

sub percent_qscore_greater_30 {
    my ($self,%p) =@_;
    my $data = $self->file_data or return;

    my $start_cycle = $p{start_cycle};
    my $end_cycle = $p{end_cycle};
    my $lane = $p{lane};

    my $num  = sum( map{$data->{$lane}->{$_}->{q30}} grep{ $data->{$lane}->{$_}}($start_cycle .. $end_cycle)) or return;
    my $den= sum( map{$data->{$lane}->{$_}->{all_qscore_instances}} grep{ $data->{$lane}->{$_}}($start_cycle .. $end_cycle));

    my $x = Math::BigFloat->new( ($num/$den) * 100);
    $x->precision(-1);

    return $x . '';
}

#borrowed from interweb
sub median {
  sum( ( sort { $a <=> $b } @_ )[ int( $#_/2 ), ceil( $#_/2 ) ] )/2;
}

1;