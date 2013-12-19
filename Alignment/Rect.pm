package Alignment::Rect;
use base 'Goo::Canvas::Rect';

sub new {
    my $class = shift;
    my ($parent, $x, $y, $sx, $sy, %options) = @_;

    my @option_names = qw(src-point trg-point); 
    my ($i, $j) = map { $options{$_} } @option_names;
    delete $options{$_} foreach(@option_names);
    
    my $rect = new Goo::Canvas::Rect(
        $parent,
        $x, $y, $sx, $sy,
        %options
    );
    bless $rect, $class;
        
    $rect->{'src-point'} = $i;
    $rect->{'trg-point'} = $j;
    $rect->{state} = "unset";
    
    return $rect;
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
        $self->set( 'fill-color' => 'red' );
    }
    elsif($state eq "probable") {
        $self->set( 'fill-color' => 'orange' );        
    }
    elsif($state eq "unset") {
        $self->set( 'fill-color' => 'white' );
    }
}

sub highlight {
    my ($self, $state) = @_;
    if($self->get_state() eq "unset") {
        if($state == 1) {
            $self->set_property('fill-color' => 'lightgrey');
        }
        else {
            $self->set_property('fill-color' => 'white');        
        }
    }
}

sub get_point {
    my $self = shift;
    return ($self->{'src-point'}, $self->{'trg-point'});
}

1;
