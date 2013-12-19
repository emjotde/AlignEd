package Alignment::Link;
use base 'Goo::Canvas::Rect';
use strict;

sub new {
    my $class = shift;
    my ($parent, $x1, $y1, $x2, $y2, %options) = @_;

    my @option_names = qw(src-point trg-point src-item trg-item); 
    my ($i, $j, $itemi, $itemj) = map { $options{$_} } @option_names;
    delete $options{$_} foreach(@option_names);
    
    my $link = Goo::Canvas::Polyline->new_line(
        $parent,
        $x1, $y1, $x2, $y2,
        %options
    );
    bless $link, $class;
        
    $link->{'src-point'} = $i;
    $link->{'trg-point'} = $j;
    
    $link->{'src-item'} = $itemi;
    $link->{'trg-item'} = $itemj;
    
    $link->{'state'} = "unset";
        
    return $link;
}

sub get_state {
    my $self = shift;
    return $self->{state};
}

sub set_state {
    my $self = shift;
    my $state = shift;
    
    $self->{state} = $state;
    if($state eq "sure") {
        my $linedash = Goo::Canvas::LineDash->new([]);
        $self->set( 'line-dash' => $linedash );
        $self->set( 'stroke-color' => 'black' );
    }
    elsif($state eq "probable") {
        my $linedash = Goo::Canvas::LineDash->new([3,3]);
        $self->set( 'line-dash' => $linedash );
        $self->set( 'stroke-color' => 'black' );        
    }
    elsif($state eq "unset") {
        my $linedash = Goo::Canvas::LineDash->new([]);
        $self->set( 'line-dash' => $linedash );
        $self->set( 'stroke-pattern' => undef );
    }
}

sub highlight {
    my ($self, $state) = @_;
    if($self->get_state() eq "unset") {
        if($state == 1) {
            $self->set_property('stroke-color' => 'grey');
        }
        else {
            my $linedash = Goo::Canvas::LineDash->new([]);
            $self->set( 'line-dash' => $linedash );
            $self->set( 'stroke-pattern' => undef );
        }
    }
}

sub get_point {
    my $self = shift;
    return ($self->{'src-point'}, $self->{'trg-point'});
}

1;