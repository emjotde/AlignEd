package Alignment::Matrix;
use base 'Goo::Canvas';
use Alignment::Model;
use Alignment::Rect;

sub new {
    my $class = shift;
    my %options = @_;
    
    my $canvas = new Goo::Canvas();
    bless $canvas, $class;
    
    $canvas->{model} = $options{"alignment-model"};
    
    $canvas->{button_callback} = sub { 0 };
    $canvas->{enter_callback} = sub { 0 };
    $canvas->{leave_callback} = sub { 0 };
    
    $canvas->{src_text} = [ undef ];
    $canvas->{trg_text} = [ undef ];
    $canvas->{rects} = [ undef ];
    
    $canvas->set(anchor => 'center');
    $canvas->set('automatic-bounds' => 1);
    $canvas->set('bounds-from-origin' => 0);
    $canvas->set('bounds-padding' => 10);
    
    return $canvas;
}

sub update {
    my $self = shift;

    $self->{src_text} = [ undef ];
    $self->{trg_text} = [ undef ];
    $self->{rects} = [ undef ];

    $self->clear();
    $self->draw();
}

sub clear {
    my $self = shift;
    my $root = $self->get_root_item();
    $root->remove_child(0);
}

sub highlight {
    my ($self, $i, $j, $state) = @_;
    
    if($state == 1) {
        if(defined($self->{src_text}->[$i]) and defined($self->{trg_text}->[$i]) and defined($self->{rects}->[$i]->[$j])) {
            $self->{src_text}->[$i]->set('fill-color' => 'red');
            $self->{trg_text}->[$j]->set('fill-color' => 'red');
            
            $self->{rects}->[$i]->[$j]->highlight($state);
        }
    }
    else {
        if(defined($self->{src_text}->[$i]) and defined($self->{trg_text}->[$i]) and defined($self->{rects}->[$i]->[$j])) {
            $self->{src_text}->[$i]->set('fill-color' => 'black');
            $self->{trg_text}->[$j]->set('fill-color' => 'black');
            
            $self->{rects}->[$i]->[$j]->highlight($state);
        }
    }
}

sub set_button_callback {
    my $self = shift;
    $self->{button_callback} = shift;
}

sub set_enter_callback {
    my $self = shift;
    $self->{enter_callback} = shift;
}

sub set_leave_callback {
    my $self = shift;
    $self->{leave_callback} = shift;
}

sub get_item {
    my $self = shift;
    my ($i,$j) = @_;
    
    return $self->{rects}->[$i]->[$j];
}

sub draw {
    my $canvas = shift;
    my $src = $canvas->{model}->get_src();    
    my $trg = $canvas->{model}->get_trg();    
    
    my $root = $canvas->get_root_item();

    my $sizept = 14;    
    my $size = $sizept * 1000;

    my $family = 'Arial';
    my $font  = "$family $sizept";
    my $font_desc = Gtk2::Pango::FontDescription->from_string($font);
    my $pangolayout = $canvas->create_pango_layout("");
    $pangolayout->set_font_description($font_desc);
    my $markup = "<span font_family ='$family' foreground = '#000000' size = '$size'>W</span>";
    $pangolayout->set_markup( $markup );
    my ($lw,$lh) = $pangolayout->get_pixel_size();
 

    my $matrix = new Goo::Canvas::Group($root);

    my $margin = 0;
    
    my $linespace = $lh;
    my $horspace = $lw;
    
    my $sx = $margin;
    my $sy = $margin;
    foreach( 0 .. $#$src ) {
        if($_ > 0) {
            $sy += $linespace;
        }
        
        $markup = "<span font_family ='$family' size = '$size'> $src->[$_] </span>"; 
        my $text = new Goo::Canvas::Text(
            $matrix,
            $markup,
            $sx, $sy, -1,
            'north-east',
            'use-markup' => 1,
        );
        push(@{$canvas->{src_text}}, $text);
    }
    
    my $tx = $margin;
    my $ty = $margin;
    foreach( 0 .. $#$trg ) {
        if($_ > 0) {
            $tx += $linespace;
        }
        
        $markup = "<span font_family ='$family' size = '$size'> $trg->[$_] </span>"; 
        my $text = new Goo::Canvas::Text(
            $matrix,
            $markup,
            $tx, $ty, -1,
            'north-west',
            'use-markup' => 1,
        );
        $text->rotate(-90, $tx, $ty);
        push(@{$canvas->{trg_text}}, $text);
    }
    
    my ($xstart, $ystart) = (0,0);
    my $side = $linespace;
    
    foreach my $i ( 1 .. @$src ) {
        foreach my $j ( 1 .. @$trg ) {
            
            my $rect = new Alignment::Rect(
                $matrix,
                ($j-1)*$side + $xstart, ($i-1)*$side + $ystart, $side, $side,
                'line-width' => 1,
                'stroke-color' => 'black',
                'fill-color' => 'white',
                
                'src-point' => $i,
                'trg-point' => $j,
            );
            $rect->set_state("unset");
            
            $rect->signal_connect('button-release-event', $canvas->{button_callback});
            $rect->signal_connect('enter-notify-event', $canvas->{enter_callback});
            $rect->signal_connect('leave-notify-event', $canvas->{leave_callback});
            
            $canvas->{rects}->[$i]->[$j] = $rect;
        }
    }

    my $alignments = $canvas->{model}->get_all();
    foreach $al (@$alignments) {
        my ($i, $j, $degree) = @$al;
        $canvas->{rects}->[$i]->[$j]->set_state($degree);
    }
    
    my @b = $canvas->get_bounds();
    $canvas->set_size_request(abs($b[0]-$b[2]),abs($b[1]-$b[3]));
}

1;
