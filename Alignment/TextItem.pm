package Alignment::TextItem;
use base 'Goo::Canvas::Text';

sub new {
    my $class = shift;
    my ($parent, $text, $x, $y, $width, $anchor, %options) = @_;

    my @option_names = qw(point state dir); 
    my ($point, $state, $dir) = map { $options{$_} } @option_names;
    delete $options{$_} foreach(@option_names);
    
    my $titem = Goo::Canvas::Text->new(
        $parent,
        $text,
        $x, $y, $width,
        $anchor,
        %options
    );
    bless $titem, $class;
        
    $titem->{'point'} = $point ? $point : 1;
    $titem->{'state'} = $state ? $state : "unmarked";
    $titem->{'dir'} = $dir ? $dir : "src";    
    
    return $titem;
}

sub get_dir {
    my $self = shift;
    return $self->{dir};
}

sub highlight {
    my ($self, $state) = @_;
    
    if(not $self->is_marked()) {
        if($state == 1) {
            $self->set_property('fill-color' => 'red');
        }
        else {
            $self->set_property('fill-color' => 'black');        
        }
    }
}

sub mark {
    my $self = shift;
    $self->{state} = "marked";
}

sub unmark {
    my $self = shift;
    $self->{state} = "ummarked";
}

sub is_marked {
    my $self = shift;
    return 1 if($self->{state} eq "marked");
    return 0;
}

sub get_point {
    my $self = shift;
    return $self->{'point'};
}

1;