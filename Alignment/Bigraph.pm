package Alignment::Bigraph;
use base 'Goo::Canvas';
use Alignment::Model;
use Alignment::Link;
use Alignment::TextItem;

sub new {
    my $class = shift;
    my %options = @_;
    
    my $canvas = new Goo::Canvas();
    bless $canvas, $class;
    
    $canvas->{model} = $options{"alignment-model"};
    
    $canvas->{src_text} = [ undef ];
    $canvas->{trg_text} = [ undef ];
    $canvas->{links} = [ undef ];

    $canvas->{src_marked} = 0;
    $canvas->{trg_marked} = 0;

    $canvas->{button_callback} = sub { 0 };
    $canvas->{enter_callback} = sub { 0 };
    $canvas->{leave_callback} = sub { 0 };
     
    $canvas->set(anchor => 'center');
    $canvas->set('automatic-bounds' => 1);
    $canvas->set('bounds-from-origin' => 0);
    $canvas->set('bounds-padding' => 10);

    $canvas->signal_connect("leave-notify-event", sub { $canvas->reset_all() });

    return $canvas;
}

sub update {
    my $self = shift;

    $self->{src_text} = [ undef ];
    $self->{trg_text} = [ undef ];
    $self->{links} = [ undef ];

    $self->{src_marked} = 0;
    $self->{trg_marked} = 0;

    $self->clear();
    $self->draw();
}

sub clear {
    my $self = shift;
    my $root = $self->get_root_item();
    $root->remove_child(0);
}

sub reset_all {
    my $self = shift;
    $self->unmark_src();
    $self->unmark_trg();
    
    foreach(@{$self->{src_text}}) {
        if(defined($_)) {
            $_->unmark();
            $_->highlight(0);
        }
    }
    foreach(@{$self->{trg_text}}) {
        if(defined($_)) {
            $_->unmark();
            $_->highlight(0);
        }
    }
    foreach my $i ( 1 .. @{$self->{links}} ) {
        if(defined($self->{links}->[$i])) {
            foreach my $j ( 1 .. @{$self->{links}->[$i]}) {
                if(defined($self->{links}->[$i]->[$j])) {
                    $self->{links}->[$i]->[$j]->highlight(0);
                }
            }
        }
    }
}

sub get_mark_src {
    my $self = shift;
    return $self->{src_marked};
}

sub get_mark_trg {
    my $self = shift;
    return $self->{trg_marked};
}

sub mark_src {
    my ($self, $i) = @_;
    $self->{src_marked} = $i;
}

sub mark_trg {
    my ($self, $i) = @_;
    $self->{trg_marked} = $i;
}

sub unmark_src {
    my ($self) = @_;
    $self->{src_marked} = 0;
}

sub unmark_trg {
    my ($self) = @_;
    $self->{trg_marked} = 0;
}

sub get_item {
    my $self = shift;
    my ($i,$j) = @_;
    
    return $self->{links}->[$i]->[$j];
}


sub highlight {
    my ($self, $i, $j, $state) = @_;

    $self->{src_text}->[$i]->highlight($state);
    $self->{trg_text}->[$j]->highlight($state);    
    $self->{links}->[$i]->[$j]->highlight($state);
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

sub draw {
    my $canvas = shift;
    my $src = $canvas->{model}->get_src();    
    my $trg = $canvas->{model}->get_trg();    
        
    my $root = $canvas->get_root_item();

    my $family = 'Arial';
    my $sizept = 14;    
    my $size = $sizept * 1000;
    
    my $font  = "$family $sizept";
    my $font_desc = Gtk2::Pango::FontDescription->from_string($font);
    my $pangolayout = $canvas->create_pango_layout("");
    $pangolayout->set_font_description($font_desc);
    my $markup = "<span font_family ='$family' foreground = '#000000' size = '$size'> </span>";
    $pangolayout->set_markup( $markup );
    my ($lw,$lh) = $pangolayout->get_pixel_size();
 
    my $agraph = new Goo::Canvas::Group($root);
    
    my $margin = 0;
    
    my $linespace = $lh;
    my $horspace = $lw;
    
    my $tickheight = $linespace*1/2;
    my $distance   = $linespace + ($tickheight * 6) + ($horspace*2);
    my $linewidth = 2;
    
    my $srcx = 0;
    my $srcy = 0;
    
    my $trgx = 0;
    my $trgy = $srcx + $distance;
    
    my $src_grp = new Goo::Canvas::Group($agraph);
    my $src_words = new Goo::Canvas::Group($src_grp);
    my $src_ticks = new Goo::Canvas::Group($src_grp);
    {
        my ($x, $y) = ($srcx, $srcy);
        foreach( 0 .. $#$src ) {
            $markup = "<span font_family ='$family' size = '$size'>$src->[$_]</span>"; 
            my $text = new Alignment::TextItem(
                $src_words,
                $markup,
                $x, $y, -1,
                'north-west',
                'use-markup' => 1,
                'point' => $_+1,
                'dir' => "src"
            );
            push(@{$canvas->{src_text}}, $text);
            
            $text->signal_connect('enter-notify-event', $canvas->{enter_callback});
            $text->signal_connect('leave-notify-event', $canvas->{leave_callback});
            $text->signal_connect('button-release-event', $canvas->{button_callback});
            
            my $bb = $text->get_bounds();
            my $width = abs($bb->x1 - $bb->x2);
            
            if($_ < $#$src) {
                $x += $width+$horspace;
            }
             
            my $xtick = $bb->x1 + $width/2;
            my $ytick = $bb->y1 + $linespace;
            
            my $tick = Goo::Canvas::Polyline->new_line(
                $src_ticks,
                $xtick, $ytick, $xtick, $ytick+$tickheight
            );
        }
    }
    
    my $trg_grp = new Goo::Canvas::Group($agraph);
    my $trg_words = new Goo::Canvas::Group($trg_grp);
    my $trg_ticks = new Goo::Canvas::Group($trg_grp);
    {
        my ($x, $y) = ($trgx, $trgy);
        foreach( 0 .. $#$trg ) {
            $markup = "<span font_family ='$family' size = '$size'>$trg->[$_]</span>"; 
            my $text = new Alignment::TextItem(
                $trg_words,
                $markup,
                $x, $y, -1,
                'north-west',
                'use-markup' => 1,
                'point' => $_+1,
                'dir' => "trg"
            );
            push(@{$canvas->{trg_text}}, $text);
            $text->signal_connect('enter-notify-event', $canvas->{enter_callback});
            $text->signal_connect('leave-notify-event', $canvas->{leave_callback});
            $text->signal_connect('button-release-event', $canvas->{button_callback});
            
            my $bb = $text->get_bounds();
            my $width = abs($bb->x1 - $bb->x2);
            
            if($_ < $#$trg) {
                $x += $width+$horspace;
            }
             
            my $xtick = $bb->x1 + $width/2;
            my $ytick = $bb->y1;
            
            my $tick = Goo::Canvas::Polyline->new_line(
                $trg_ticks,
                $xtick, $ytick, $xtick, $ytick-$tickheight
            );
        }
    }
    
    my $coords_src = $src_grp->get_bounds();
    my $coords_trg = $trg_grp->get_bounds();
    
    my $src_width = $coords_src->x2 - $coords_src->x1;
    my $trg_width = $coords_trg->x2 - $coords_trg->x1;
    
    my $offset = abs($src_width - $trg_width)/2;
    if($src_width < $trg_width) {
        $src_grp->translate($offset, 0);
    }
    else {
        $trg_grp->translate($offset, 0);        
    }

    foreach my $i ( 1 .. @$src ) {
        foreach my $j ( 1 .. @$trg ) {
            
            my $src_tick = $src_ticks->get_child($i-1);
            my $trg_tick = $trg_ticks->get_child($j-1);
            
            my $sc = $src_tick->get_bounds();
            my $tc = $trg_tick->get_bounds();
            
            my $sx = $sc->x2;
            my $sy = $sc->y2;
            
            my $tx = $tc->x1;
            my $ty = $tc->y1;
            
            $canvas->convert_from_item_space($src_tick, $sx, $sy);
            $canvas->convert_from_item_space($trg_tick, $tx, $ty);
            
            my $line = new Alignment::Link(
                $agraph,
                $sx-1, $sy, $tx+1, $ty,
                'stroke-pattern' => undef,
                'src-point' => $i,
                'trg-point' => $j,
                'src-item' => $canvas->{src_text}->[$i],
                'trg-item' => $canvas->{trg_text}->[$j],
            );
            
            #$rect->signal_connect('button-release-event', $canvas->{callback});
            $canvas->{links}->[$i]->[$j] = $line;
        }
    }

    my $model = $canvas->{model};
    my $iter = $model->get_iter_first();
    if($iter) {
        do {
            my ($i, $j, $degree) = $model->get($iter);
            $canvas->{links}->[$i]->[$j]->set_state($degree);
        } while(defined($iter = $model->iter_next($iter)));
    }
    my @b = $canvas->get_bounds();
    $canvas->set_size_request(abs($b[0]-$b[2]),abs($b[1]-$b[3]));
}

1
