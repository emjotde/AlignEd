package Alignment::Model;
use Gtk2;
use base 'Gtk2::ListStore';
use DBI;
use Data::Dumper;

sub new {
    my $class = shift;
    my %options = @_;
    
    my $model = new Gtk2::ListStore('Glib::Int', 'Glib::Int', 'Glib::String');
    
    my $sorter = sub {
        my $self = shift;
        my ($iter1, $iter2) = @_;
        
        my $col0_1 = $self->get_value($iter1, 0);
        my $col0_2 = $self->get_value($iter2, 0);
        
        my $col1_1 = $self->get_value($iter1, 1);
        my $col1_2 = $self->get_value($iter2, 1);
        
        my $col2_1 = $self->get_value($iter1, 2);
        my $col2_2 = $self->get_value($iter2, 2);
        
        return ($col0_1 <=> $col0_2 or $col1_1 <=> $col1_2 or $col2_1 cmp $col2_2);
    };
    
    $model->set_sort_func(0, $sorter);
    $model->set_sort_column_id(0, 'ascending');
    bless $model, $class;

    $model->{author}    = exists($options{author})    ? $options{author}    : 1;
    $model->{direction} = exists($options{direction}) ? $options{direction} : 1;
    
    $model->{autosave}  = exists($options{autosave})  ? $options{autosave}  : 0;
    $model->{modified}  = 0;
    
    my $db = exists($options{db}) ? $options{db} : "annotations";
    
    $model->{dbh} = DBI->connect("dbi:SQLite:dbname=$db", "", "");
    $model->{dbh}->{AutoCommit} = 1;

    # create all tables if things are empty
    my ($result) = $model->{dbh}->selectrow_array("SELECT name FROM sqlite_master WHERE type='table' AND name='documents'");
    if(!defined($result) or $result ne "documents") {
        $model->{dbh}->do("DROP TABLE IF EXISTS documents;");
        $model->{dbh}->do("DROP TABLE IF EXISTS tu;");
        $model->{dbh}->do("DROP TABLE IF EXISTS tuv;");
        $model->{dbh}->do("DROP TABLE IF EXISTS seg_tokenized;");
        $model->{dbh}->do("DROP TABLE IF EXISTS alignment;");
        $model->{dbh}->do("DROP TABLE IF EXISTS comment;");
        $model->{dbh}->do("DROP TABLE IF EXISTS direction;");
        
        $model->{dbh}->do("CREATE TABLE documents(doc_id INTEGER PRIMARY KEY, name);");
        $model->{dbh}->do("CREATE TABLE tu(tu_id INTEGER PRIMARY KEY, doc_id INTEGER);");
        $model->{dbh}->do("CREATE TABLE tuv(tuv_id INTEGER PRIMARY KEY, tu_id INTEGER, lang_id INTEGER);");
        $model->{dbh}->do("CREATE TABLE seg_tokenized(seg_id INTEGER PRIMARY KEY, tuv_id INTEGER, data);");
        $model->{dbh}->do("CREATE TABLE alignment(a_id INTEGER PRIMARY KEY, tu_id INTEGER, dir_id INTEGER, aut_id INTEGER, sure, probable, created);");
        $model->{dbh}->do("CREATE TABLE comment(c_id INTEGER PRIMARY KEY, tu_id INTEGER, dir_id INTEGER, aut_id INTEGER, data);");
        $model->{dbh}->do("CREATE TABLE direction(dir_id INTEGER PRIMARY KEY, lang1_id INTEGER, lang2_id INTEGER);");
    }

    $model->{insert_document}  = $model->{dbh}->prepare("INSERT INTO documents (name) values (?)");
    $model->{insert_tu}        = $model->{dbh}->prepare("INSERT INTO tu (doc_id) values (?)");
    $model->{insert_tuv}       = $model->{dbh}->prepare("INSERT INTO tuv (tu_id, lang_id) values (?, ?)");
    $model->{insert_segment}   = $model->{dbh}->prepare("INSERT INTO seg_tokenized (tuv_id, data) values (?, ?)");
    $model->{insert_direction} = $model->{dbh}->prepare("INSERT INTO direction (lang1_id, lang2_id) values (?, ?)");
    
    $model->{get_last_alignment_id} = $model->{dbh}->prepare("SELECT last_insert_rowid() as currval;");

    $model->{count} = $model->{dbh}->prepare("SELECT COUNT(*) AS count FROM tu;");
    
    $model->{data_query} = $model->{dbh}->prepare("
        SELECT t1.tu_id, d.dir_id, s1.data as src, s2.data as trg, a_id, sure, probable FROM
            tuv t1
            JOIN seg_tokenized s1 ON (t1.tuv_id = s1.tuv_id)
            JOIN tuv t2 ON (t1.tu_id = t2.tu_id)
            JOIN seg_tokenized s2 ON (t2.tuv_id = s2.tuv_id)
            JOIN direction d ON (t1.lang_id = d.lang1_id and t2.lang_id = d.lang2_id)
            LEFT OUTER JOIN (
                SELECT * FROM alignment WHERE aut_id = ?
            ) a ON (t1.tu_id = a.tu_id and d.dir_id = a.dir_id)
            WHERE d.dir_id = ?
            ORDER BY t1.tu_id
            LIMIT 1 OFFSET ?;   
    ");

    $model->{insert_alignment} = $model->{dbh}->prepare("INSERT INTO alignment (tu_id, dir_id, aut_id, sure, probable) VALUES (?,?,?,?,?);");
    $model->{update_alignment} = $model->{dbh}->prepare("UPDATE alignment SET sure = ?, probable = ?, created = datetime('now') WHERE tu_id = ? and dir_id = ? and aut_id = ?;");
    $model->{insert_comment}   = $model->{dbh}->prepare("INSERT INTO comment (tu_id, dir_id, aut_id, data) VALUES (?,?,?,?);");

    my $max = 0;
    $model->{count}->execute();
    while(my $row = $model->{count}->fetchrow_hashref()) {
        $max = $row->{count}-1;
    }
    
    $model->{adjustment} = new Gtk2::Adjustment(0, 0, $max, 1, 10, 0);
    
    $model->{adjustment}->signal_connect('value-changed' => sub {
        $model->get_data()
    });

    $model->{adjustment}->signal_emit("value-changed");

    $model->get_data();
    return $model;
}

sub last_id {
    my $self = shift;
    $self->{get_last_alignment_id}->execute();
    my $ref = $self->{get_last_alignment_id}->fetchrow_hashref();
    print Dumper(\$ref);
    return $ref->{currval};
}

sub add_sentence_pair {
    my $self = shift;
}

sub add_comment {
    my $self = shift;
    my $comment = shift;
    
    $self->{insert_comment}->execute($self->{data}->{tu_id}, $self->{direction}, $self->{author}, $comment);
}

sub set_autosave {
    my $self = shift;
    $self->{autosave} = shift;
}

sub save {
    my $self = shift;
    $Data::Dumper::Indent = 0;
    if($self->{data}->{a_id}) {
        $self->{update_alignment}->execute(Dumper($self->get_sure()), Dumper($self->get_probable()), $self->{data}->{tu_id}, $self->{direction}, $self->{author});
    }
    else {
        $self->{insert_alignment}->execute($self->{data}->{tu_id}, $self->{direction}, $self->{author}, Dumper($self->get_sure()), Dumper($self->get_probable()));
        $self->{data}->{a_id} = $self->last_id();
    }
    $self->{modified} = 0;
}

sub next() {
    my $self = shift;
    $self->save() if($self->{autosave} and $self->{modified});
    
    $self->{adjustment}->value($self->{adjustment}->value() + 1) if($self->{adjustment}->value() < $self->{adjustment}->upper());
    $self->{adjustment}->signal_emit("value_changed");
    #$self->get_data($self->{adjustment}->value());
}

sub previous() {
    my $self = shift;
    $self->save() if($self->{autosave} and $self->{modified});
    
    $self->{adjustment}->value($self->{adjustment}->value() - 1) if($self->{adjustment}->value() > $self->{adjustment}->lower());
    $self->{adjustment}->signal_emit("value_changed");
    #$self->get_data();
}

sub get_data {
    my $self = shift;
    
    $self->{data_query}->execute($self->{author}, $self->{direction}, $self->{adjustment}->value());
    while(my $row = $self->{data_query}->fetchrow_hashref()) {
        $self->{data}->{tu_id} = $row->{tu_id};
        $self->{data}->{a_id}  = $row->{a_id};
        $self->{data}->{src}   = [ map { s/&/&amp;/g; $_ } split(/\s+/, $row->{src}) ];
        $self->{data}->{trg}   = [ map { s/&/&amp;/g; $_ } split(/\s+/, $row->{trg}) ];
        $self->update($row->{sure}, $row->{probable});
    };
    $self->{modified} = 0;
}

sub get_src {
    my $self = shift;
    return $self->{data}->{src};
}

sub get_trg {
    my $self = shift;
    return $self->{data}->{trg};
}

sub update() {
    my $self = shift;
    my ($sure, $probable) = @_;
    
    $self->clear();
    if(defined($sure) and defined($probable)) {
        my $sure = eval($sure);
        foreach( @$sure ) {
            my ($i,$j) = @$_;
            $self->set($self->append(), 0 => $i, 1 => $j, 2 => "sure");
        }
        my $probable = eval($probable);
        foreach( @$probable ) {
            my ($i,$j) = @$_;
            $self->set($self->append(), 0 => $i, 1 => $j, 2 => "probable");
        }
    }
    
}

sub get_all {
    my $self = shift;
    
    my $all = [];
    my $iter = $self->get_iter_first();
    if(defined($iter)) {
        do {
            push(@$all, [ $self->get($iter) ]);
        } while(defined($iter = $self->iter_next($iter)));
    }
    return $all;    
}

sub get_sure {
    my $self = shift;
    
    my $sure = [];
    my $iter = $self->get_iter_first();
    if(defined($iter)) {
        do {
            my ($i, $j, $degree) = $self->get($iter);
            push(@$sure, [$i, $j]) if($degree eq "sure");
        } while(defined($iter = $self->iter_next($iter)));
    }
    return $sure;
}

sub get_probable {
    my $self = shift;
    
    my $probable = [];
    my $iter = $self->get_iter_first();
    if(defined($iter)) {
        do {
            my ($i, $j, $degree) = $self->get($iter);
            push(@$probable, [$i, $j]) if($degree eq "probable");
        } while(defined($iter = $self->iter_next($iter)));
    }
    return $probable;    
}

sub get_state {
    my $self = shift;
    my ($i,$j) = @_;
    
    my $degree = "unset";
    my $iter = $self->get_iter_first();
    if($iter) {
        do {
            my ($i2, $j2, $degree2) = $self->get($iter);
            if($i == $i2 and $j == $j2) {
                return $degree2;
            }
        } while(defined($iter = $self->iter_next($iter)));
    }
    return $degree;
}

sub set_state {
    my $self = shift;
    my ($i,$j,$degree) = @_;
    
    $self->{modified} = 1;
    my $iter = $self->get_iter_first();
    if($iter) {
        do {
            my ($i2, $j2, $degree2) = $self->get($iter);
            if($i == $i2 and $j == $j2) {
                if($degree eq "unset") {
                    $self->remove($iter);
                    return $degree;
                }
                else {
                    $self->set_value($iter, 2 => $degree);
                    return $degree;
                }
            }
        } while(defined($iter = $self->iter_next($iter)));
    }
    if(not defined($iter) and $i and $j) {
        $self->set($self->append(), 0 => $i, 1 => $j, 2 => $degree);
    }
    
    return $degree;
}

1