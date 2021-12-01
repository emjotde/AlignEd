#!/usr/bin/perl -w
use utf8;
use strict;
use Data::Dumper;
use Getopt::Long;

use Gtk2 '-init';
use Gtk2::Gdk::Keysyms;
use Goo::Canvas;

use FindBin qw($Bin);
use lib "$Bin";

use Alignment::Model;
use Alignment::Matrix;
use Alignment::Bigraph;

####################################################################################################################

my $direction = 1;
my $aut_id = 1;
my $db = "annotations";

GetOptions(
    "author=i" => \$aut_id,
    "direction=i" => \$direction,
    "db=s" => \$db,
);

my $alignment_model = new Alignment::Model(
    author => $aut_id,
    direction => $direction,
    db => $db
);

my $canvas_matrix = new Alignment::Matrix(
    'alignment-model' => $alignment_model,
);

my $canvas_bigraph = new Alignment::Bigraph(
    'alignment-model' => $alignment_model,
);


my $matrix_button_callback = sub {
    my ($self, undef, $event) = @_;
        
    my ($i, $j) = $self->get_point();
    my $state = $alignment_model->get_state($i, $j);
    
    my $states = {
        unset => {
            0 => 'sure',
            1 => 'probable'
        },
        sure  => {
            0 => 'unset',
            1 => 'probable'
        },
        probable => {
            0 => 'sure',
            1 => 'unset'
        }
    };
    
    my $event_state = $event->state();
    my $shift_pressed = 0;
    $shift_pressed = 1 if($event_state =~ /shift/ or $event_state =~ /lock/);
    
    if(defined($state)) {
        my $newstate = $states->{$state}->{$shift_pressed};
        
        $canvas_matrix->get_item($i, $j)->set_state($newstate);
        $canvas_bigraph->get_item($i, $j)->set_state($newstate);
        $alignment_model->set_state($i, $j, $newstate);
    }
};
          
my $matrix_enter_callback = sub {
    my ($self, undef, $event) = @_;
    
    my ($i, $j) = $self->get_point();
    $canvas_matrix->highlight($i, $j, 1);
    $canvas_bigraph->highlight($i, $j, 1);
};

my $matrix_leave_callback = sub {
    my ($self, undef, $event) = @_;
    
    my ($i, $j) = $self->get_point();
    $canvas_matrix->highlight($i, $j, 0);
    $canvas_bigraph->highlight($i, $j, 0);
};

my $bigraph_button_callback = sub {
    my ($self, undef, $event) = @_;
    
    my $dir   = $self->get_dir();
    my $point = $self->get_point();
    
    my $i = $canvas_bigraph->get_mark_src();
    my $j = $canvas_bigraph->get_mark_trg();
    
    if($dir eq "src" and $i == 0) {
        $self->highlight(1);
        $self->mark();
        $canvas_bigraph->mark_src($point);
        $i = $point;
    }
    if($dir eq "trg" and $j == 0) {
        $self->highlight(1);
        $self->mark();
        $canvas_bigraph->mark_trg($point);
        $j = $point;
    }
    
    if($i and $j) {        
        $canvas_bigraph->{src_text}->[$i]->unmark();
        $canvas_bigraph->{src_text}->[$i]->highlight(0);
        $canvas_bigraph->unmark_src($i);        
    
        $canvas_bigraph->{trg_text}->[$j]->unmark();
        $canvas_bigraph->{trg_text}->[$j]->highlight(0);
        $canvas_bigraph->unmark_trg($j);
        
        $canvas_matrix->highlight($i, $j, 0);
        
        my $state = $alignment_model->get_state($i, $j);
        my $states = {
            unset => {
                0 => 'sure',
                1 => 'probable'
            },
            sure  => {
                0 => 'unset',
                1 => 'probable'
            },
            probable => {
                0 => 'sure',
                1 => 'unset'
            }
        };
        
        my $event_state = $event->state();
        my $shift_pressed = 0;
        $shift_pressed = 1 if($event_state =~ /shift/ or $event_state =~ /lock/);
        
        if(defined($state)) {
            my $newstate = $states->{$state}->{$shift_pressed};
            
            $canvas_matrix->get_item($i, $j)->set_state($newstate);
            $canvas_bigraph->get_item($i, $j)->set_state($newstate);
            $alignment_model->set_state($i, $j, $newstate);
        }
    }
};

my $bigraph_enter_callback = sub {
    my ($self, undef, $event) = @_;
    
    my $dir   = $self->get_dir();
    my $point = $self->get_point();
    
    my $i = $canvas_bigraph->get_mark_src();
    my $j = $canvas_bigraph->get_mark_trg();
    
    if($dir eq "src" and $i == 0) {
        if($j) {
            $canvas_bigraph->highlight($point,$j,1);
            $canvas_matrix->highlight($point, $j, 1);
        }
        $self->highlight(1);
    }
    if($dir eq "trg" and $j == 0) {
        if($i) {
            $canvas_bigraph->highlight($i,$point,1);
            $canvas_matrix->highlight($i,$point,1);
        }
        $self->highlight(1);
    }
};

my $bigraph_leave_callback = sub {
    my ($self, undef, $event) = @_;
    
    my $dir   = $self->get_dir();
    my $point = $self->get_point();
    
    my $i = $canvas_bigraph->get_mark_src();
    my $j = $canvas_bigraph->get_mark_trg();
    
    if($dir eq "trg" and $i > 0) {
        $canvas_bigraph->highlight($i,$point,0);
        $canvas_matrix->highlight($i,$point, 0);
    }
    if($dir eq "src" and $j > 0) {
        $canvas_bigraph->highlight($point,$j,0);
        $canvas_matrix->highlight($point,$j,0);
    }
    $self->highlight(0);
};

            
$canvas_matrix->set_button_callback($matrix_button_callback);
$canvas_matrix->set_enter_callback($matrix_enter_callback);
$canvas_matrix->set_leave_callback($matrix_leave_callback);

$canvas_bigraph->set_enter_callback($bigraph_enter_callback);
$canvas_bigraph->set_leave_callback($bigraph_leave_callback);
$canvas_bigraph->set_button_callback($bigraph_button_callback);

my $window = Gtk2::Window->new('toplevel');

my $toolbar_callbacks = {
    back    => sub {
        $alignment_model->previous();
        $canvas_matrix->update();
        $canvas_bigraph->update();        
    },
    forward => sub {
        $alignment_model->next();
        $canvas_matrix->update();
        $canvas_bigraph->update();        
    },
    open    => sub {
        my $dialog = Gtk2::Dialog->new("Import corpus", $window, [qw/modal destroy-with-parent/],
            'gtk-cancel' => 'cancel',
            'gtk-save'      => 'ok'
        );
        
        #my $label = new Gtk2::Label("Enter comment:");
        
        my $main_box = new Gtk2::VBox(0, 5);
        my $fc_btn_file =Gtk2::FileChooserButton->new ('select a file' , 'open');
        
        $main_box->pack_start($fc_btn_file, 0, 0, 0);
        #$main_box->pack_start($scroll_text,1, 1, 0);
        
        $dialog->get_content_area()->add($main_box);
        $dialog->set_default_response ('ok');
        $dialog->set_default_size(600, 400);
        
        $dialog->show_all();
        
        my $response = $dialog->run();
        if($response eq "ok") {
            #my $buffer = $entry->get_buffer();
            #my $comment = $buffer->get_text($buffer->get_start_iter, $buffer->get_end_iter, 1);
            #$alignment_model->add_comment($comment);
        }
        $dialog->destroy();
    },
    save    => sub {
        $alignment_model->save();
    },
    reload => sub {
        $alignment_model->get_data();
        $canvas_matrix->update();
        $canvas_bigraph->update();
    },
    clear   => sub {
        $alignment_model->clear();
        $canvas_matrix->update();
        $canvas_bigraph->update();                
    },
    autosave => sub {
        my $button = shift;
        if($button->get_active()) {
            $alignment_model->set_autosave(1);
        }
        else {
            $alignment_model->set_autosave(0);            
        }
    },
    spin => sub {
        $alignment_model->get_data();
        $canvas_matrix->update();
        $canvas_bigraph->update();
    },
    comment => sub {
        my $dialog = Gtk2::Dialog->new("Enter comment", $window, [qw/modal destroy-with-parent/],
            'gtk-cancel' => 'cancel',
            'gtk-save'      => 'ok'
        );
        
        my $label = new Gtk2::Label("Enter comment:");
        
        my $entry = new Gtk2::TextView();
        $entry->set_wrap_mode("word");
        
        my $scroll_text = new Gtk2::ScrolledWindow();
        $scroll_text->set_shadow_type('in');
        $scroll_text->set_policy('automatic', 'automatic');
        $scroll_text->add($entry);

        my $main_box = new Gtk2::VBox(0, 5);
        $main_box->pack_start($label, 0, 0, 0);
        $main_box->pack_start($scroll_text,1, 1, 0);
        
        $dialog->get_content_area()->add($main_box);
        $dialog->set_default_response ('ok');
        $dialog->set_default_size(400, 200);
        
        $dialog->show_all();
        
        my $response = $dialog->run();
        if($response eq "ok") {
            my $buffer = $entry->get_buffer();
            my $comment = $buffer->get_text($buffer->get_start_iter, $buffer->get_end_iter, 1);
            $alignment_model->add_comment($comment);
        }
        $dialog->destroy();
    },
};

####################################################################################################################

$window->set_title("AlignEd 0.4");
$window->signal_connect('delete_event' => sub { Gtk2->main_quit; });
$window->signal_connect('key_press_event' => sub {
    my ($self, $event) = @_;
    if($event->keyval() == $Gtk2::Gdk::Keysyms{period}) {
        &{$toolbar_callbacks->{forward}}();
    }
    if($event->keyval() == $Gtk2::Gdk::Keysyms{comma}) {
        &{$toolbar_callbacks->{back}}();
    }
    if($event->keyval() == $Gtk2::Gdk::Keysyms{s} or $event->keyval() == $Gtk2::Gdk::Keysyms{z}) {
        &{$toolbar_callbacks->{save}}();
    }
    if($event->keyval() == $Gtk2::Gdk::Keysyms{x}) {
        &{$toolbar_callbacks->{reload}}();
    }
    if($event->keyval() == $Gtk2::Gdk::Keysyms{c}) {
        &{$toolbar_callbacks->{clear}}();
    }
    if($event->keyval() == $Gtk2::Gdk::Keysyms{a}) {
        print STDERR "I wonder how to enable autosave?\n";        
    }
});
$window->set_size_request(800, 600);


my $main_box = new Gtk2::VBox(0,1);
my $statusbar = Gtk2::Statusbar->new();

$main_box->pack_end($statusbar,0,0,0);

my $hpaned_main = new Gtk2::HPaned();

my $toolbar = make_toolbar($toolbar_callbacks);

$main_box->pack_start($toolbar, 0, 1, 0);
$main_box->pack_start(new Gtk2::HSeparator(),0,1,0);
$main_box->add($hpaned_main);
$window->add($main_box);

my $vpaned_left = new Gtk2::VPaned();
$hpaned_main->pack1($vpaned_left,1,1);

my $box_matrix = new Gtk2::HBox(); 
$box_matrix->set_border_width(3);

my $box_bigraph = new Gtk2::HBox(); 
$box_bigraph->set_border_width(3);

$vpaned_left->pack1($box_matrix, 1, 1);
$vpaned_left->pack2($box_bigraph, 0 ,1);

my $zoom_box_matrix = make_zoom_box($canvas_matrix, value => 100, lower => 25, upper => 150, step => 5, page => 25, noscale => 0);
$box_matrix->pack_start($zoom_box_matrix,0,1,0);

my $scroll_matrix = new Gtk2::ScrolledWindow();
$scroll_matrix->set_shadow_type('in');
$scroll_matrix->set_policy('automatic', 'automatic');
$box_matrix->add($scroll_matrix);

$scroll_matrix->add($canvas_matrix);
$canvas_matrix->draw();

my $zoom_box_bigraph = make_zoom_box($canvas_bigraph, value => 100, lower => 25, upper => 150, step => 5, page => 25, noscale => 1);
$box_bigraph->pack_start($zoom_box_bigraph,0,1,0);

my $scroll_bigraph = new Gtk2::ScrolledWindow();
$scroll_bigraph->set_shadow_type('in');
$scroll_bigraph->set_policy('automatic', 'automatic');
$box_bigraph->add($scroll_bigraph);

$scroll_bigraph->add($canvas_bigraph);
$canvas_bigraph->draw();

#######################################################################################################

my $view1 = Gtk2::TreeView->new($alignment_model);
my $col1 = Gtk2::TreeViewColumn->new_with_attributes('Src', Gtk2::CellRendererText->new(), text => 0);
my $col2 = Gtk2::TreeViewColumn->new_with_attributes('Trg', Gtk2::CellRendererText->new(), text => 1);
my $col3 = Gtk2::TreeViewColumn->new_with_attributes('Degree', Gtk2::CellRendererText->new(), text => 2);

$view1->append_column($col1);
$view1->append_column($col2);
$view1->append_column($col3);

my $box_number = new Gtk2::VBox(); 

my $scroll_number = new Gtk2::ScrolledWindow();
$scroll_number->set_policy('automatic', 'automatic');
$scroll_number->add($view1);
$box_number->add($scroll_number);

$hpaned_main->pack2($box_number, 0, 1);

$window->show_all();

my @b = $canvas_bigraph->get_bounds();
$vpaned_left->set_position($vpaned_left->get_property("max-position")-abs($b[1]-$b[3])-30);
$hpaned_main->set_position($hpaned_main->get_property("max-position"));
Gtk2->main();   



############################################################################################################


sub write_pdf_clicked {
    my ($but, $canvas) = @_;
    print "Write PDF...\n";

    my $scale = 1;    
    my @b = $canvas->get_bounds();
    
    my $surface = Cairo::PdfSurface->create("$0-$scale.pdf", 
                abs($b[0]-$b[2]),abs($b[1]-$b[3]));
    
    my $cr = Cairo::Context->create($surface);
    $cr->translate(-$b[0], -$b[1]);
    
    $canvas->render($cr, undef, 1);
    $cr->show_page();
    
    print "done\n";
    return 1;
}

sub make_toolbar {
    my $callbacks = shift;
    
    my $toolbar = new Gtk2::Toolbar();
    
    $toolbar->set_icon_size ('large-toolbar');
    #my $tt = Gtk2::Tooltips->new();

    
    my $button_goback = Gtk2::ToolButton->new_from_stock("gtk-go-back");
    $toolbar->insert($button_goback,-1);
    $button_goback->signal_connect("clicked" => $callbacks->{back} );

    my $button_goforward = Gtk2::ToolButton->new_from_stock("gtk-go-forward");
    $toolbar->insert($button_goforward,-1);
    $button_goforward->signal_connect("clicked" => $callbacks->{forward} );
    
    $toolbar->insert(new Gtk2::SeparatorToolItem(),-1);
    
    my $tool_offset = Gtk2::ToolItem->new();
    my $navigation = new Gtk2::Label("Offset: ");
    $tool_offset->add($navigation);    
    
    my $tool_jump = Gtk2::ToolItem->new();
    my $entry_jump = Gtk2::SpinButton->new($alignment_model->{adjustment}, 1, 0);
    $entry_jump->signal_connect("value-changed" => $callbacks->{spin} );
    $tool_jump->add($entry_jump);
    
    $toolbar->insert($tool_offset,-1);
    $toolbar->insert($tool_jump,-1);
    
    $toolbar->insert(new Gtk2::SeparatorToolItem(),-1);
    
    my $tool_db = Gtk2::ToolItem->new();
    my $chooser_db = Gtk2::FileChooserButton->new ('select a file' , 'open');
    $chooser_db->set_size_request(150, -1);
    $tool_db->add($chooser_db);
    $toolbar->insert($tool_db,-1);
    
    $toolbar->insert(new Gtk2::SeparatorToolItem(),-1);
    
    my $button_open = Gtk2::ToolButton->new_from_stock("gtk-new");
    $button_open->set_label("Open");
    $toolbar->insert($button_open, -1);
    $button_open->signal_connect("clicked" => $callbacks->{open} );
    
    my $button_save = Gtk2::ToolButton->new_from_stock("gtk-save");
    $toolbar->insert($button_save,-1);
    $button_save->signal_connect("clicked" => $callbacks->{save} );
    
    my $button_reload = Gtk2::ToolButton->new_from_stock("gtk-revert-to-saved");
    $toolbar->insert($button_reload,-1);
    $button_reload->signal_connect("clicked" => $callbacks->{reload} );

    my $button_clear = Gtk2::ToolButton->new_from_stock("gtk-clear");
    $toolbar->insert($button_clear,-1);
    $button_clear->signal_connect("clicked" => $callbacks->{clear} );

    my $button_info = Gtk2::ToolButton->new_from_stock("gtk-dialog-warning");
    $toolbar->insert($button_info,-1);
    $button_info->signal_connect("clicked" => $callbacks->{comment} );
    
    
    my $bpdf = Gtk2::ToolButton->new_from_stock("gtk-convert");
    $toolbar->insert($bpdf, -1);                            
    #$bpdf->show();                                                          
    $bpdf->signal_connect("clicked", \&write_pdf_clicked, $canvas_matrix);  
    
    $toolbar->insert(new Gtk2::SeparatorToolItem(),-1);
    
    my $tool_autosave = Gtk2::ToolItem->new();
    my $button_autosave = Gtk2::CheckButton->new_with_label("Autosave");
    $tool_autosave->add($button_autosave);
    $toolbar->insert($tool_autosave,-1);
    $button_autosave->signal_connect("toggled" => $callbacks->{autosave} );
            
    return $toolbar;
}

sub make_zoom_box {
    my $canvas = shift;
    my %opts = @_;
    
    my $adjustment = Gtk2::Adjustment->new($opts{value}, $opts{lower}, $opts{upper}, $opts{step}, $opts{page}, 0);
    $adjustment->signal_connect("value_changed" => sub {
        $canvas->set_scale($_[0]->value/100)
    });
    
    my $zoom_box = new Gtk2::VBox();
    my $button_box1 = new Gtk2::VBox(1,0);
    my $button_box2 = new Gtk2::VBox(1,0);
    
    my $button_zoom_in = Gtk2::ToolButton->new_from_stock("gtk-zoom-in");
    $button_zoom_in->signal_connect("clicked" =>  => sub {
        my $new_value = $adjustment->value() + $adjustment->step_increment();
        $adjustment->value( $new_value > $adjustment->upper() ? $adjustment->upper() : $new_value );
        $adjustment->signal_emit("value_changed");
    } );
    $button_box1->pack_start($button_zoom_in,1,0,0);
    
    my $button_zoom_out = Gtk2::ToolButton->new_from_stock("gtk-zoom-out");
    $button_zoom_out->signal_connect("clicked" => sub {
        my $new_value = $adjustment->value() - $adjustment->step_increment();
        $adjustment->value( $new_value < $adjustment->lower() ? $adjustment->lower() : $new_value );
        $adjustment->signal_emit("value_changed")
    });
    $button_box1->pack_start($button_zoom_out,1,0,0);
    
    my $button_zoom_100 = Gtk2::ToolButton->new_from_stock("gtk-zoom-100");
    $button_zoom_100->signal_connect("clicked" => sub {
        $adjustment->value(100);
        $adjustment->signal_emit("value_changed")
    });
    $button_box2->add($button_zoom_100);

    my $button_zoom_fit = Gtk2::ToolButton->new_from_stock("gtk-zoom-fit");
    $button_zoom_fit->signal_connect("clicked" => sub {
        my $alloc = $canvas->allocation();
        my @bbox  = $canvas->get_bounds();
        
        my $sw = $alloc->width;
        my $sh = $alloc->height;
        
        my $cw = abs($bbox[0] - $bbox[2]);
        my $ch = abs($bbox[1] - $bbox[3]);
        
        my $wr = int($sw/$cw*100);
        my $hr = int($sh/$ch*100);
        
        my $tscale = $wr < $hr ? $wr : $hr; 
        my $scale  = $tscale < $adjustment->lower ? $adjustment->lower : $tscale > $adjustment->upper ? $adjustment->upper : $tscale;
        
        $adjustment->value($scale);
        $adjustment->signal_emit("value_changed")
    });
    $button_box2->add($button_zoom_fit);
    
    $zoom_box->pack_start($button_box1,0,1,0);
    
    if(not exists($opts{noscale}) or not $opts{noscale} == 1) {
        my $scale = Gtk2::VScale->new($adjustment);
        $scale->set('draw-value' => 0);
        $scale->set_update_policy('continuous');
        $scale->set(inverted => 1);
        $zoom_box->pack_start($scale,1,1,0);
    }
    
    $zoom_box->pack_start($button_box2,0,1,0);
    my $zoom_frame = new Gtk2::Frame();
    $zoom_frame->add($zoom_box);
    
    return $zoom_frame;
}

