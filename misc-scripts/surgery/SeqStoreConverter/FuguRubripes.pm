
use strict;
use warnings;

use SeqStoreConverter::BasicConverter;

package SeqStoreConverter::FuguRubripes;

use vars qw(@ISA);

@ISA = qw(SeqStoreConverter::BasicConverter);


sub create_coord_systems {
  my $self = shift;

  $self->debug("FuguRubripes Specific: creating scaffold coord system");

  #
  # Load the coord system table.
  # Fugu has only one coord system : scaffold
  #
  my $default_assembly = $self->get_default_assembly();
  my $target = $self->target();

  my $sth = $self->dbh()->prepare
   ("INSERT INTO $target.coord_system (name, version, attrib, rank)" .
    "VALUES (?,?,?,?)");
  $sth->execute('scaffold', $default_assembly,
                'default_version,sequence_level', $rank);

  my $csid =  $sth->{'mysql_insertid'};

  $sth->finish();

  #
  # Load the meta_coord table. Every feature is in scaffold coordinates.
  #
  $sth = $self->dbh()->prepare
    ("INSERT INTO $target.meta_coord (table_name, coord_system_id) " .
     "VALUES (?,?)");

  my @tables = qw(gene
                  transcript  
                  exon               	
                  dna_align_feature    
                  protein_align_feature 
                  marker_feature       
                  simple_feature        
                  repeat_feature      
                  qtl_feature         
                  misc_feature   
                  prediction_transcript 
                  karyotype);
  
  foreach my $table (@tables) {
    $sth->execute($table, $csid);
  }
  $sth->finish();
}



sub create_seq_regions {
  my $self = shift;

  $self->debug("FuguRubripes Specific: creating scaffolds");

  $self->contig_to_seq_region('scaffold');
}


sub create_assembly {
  my $self = shift;

  $self->debug("FuguRubripes Specific: no assembly data needed");
  #fugu has no assembly table
}


sub transfer_genes {
  my $self = shift;

  my $target = $self->target();
  my $source = $self->source();
  my $dbh    = $self->dbh();

  #
  # This is simple in fugu since all genes are actually in contig (now
  # renamed scaffold) coords.  We don't need joins to the assembly table
  # and we don't have to worry about stickies
  #

  $self->debug("FuguRubripes Specific: Building gene table " .
               "(no chromosomal conversion)");

  #
  # Transfer the gene table
  #

  $dbh->do
    ("INSERT INTO $target.gene " .
     "SELECT g.gene_id, g.type, g.analysis_id, e.contig_id, " .
     "       MIN(e.contig_start), MAX(e.contig_end), e.contig_strand, " .
     "       g.display_xref_id " .
     "FROM   $source.transcript t, $source.exon_transcript et, " .
     "       $source.exon e, $source.gene g " .
     "WHERE  t.transcript_id = et.transcript_id " .
     "AND    et.exon_id = e.exon_id " .
     "AND    g.gene_id = t.gene_id " .
     "GROUP BY g.gene_id");

  $self->debug("FuguRubripes Specific: Building transcript table " .
               "(no chromosomal conversion)");

  #
  # Transfer transcript table
  #

  $dbh->do
    ("INSERT INTO $target.transcript " .
     "SELECT t.transcript_id, t.gene_id, e.contig_id, " .
     "       MIN(e.contig_start), MAX(e.contig_end), e.contig_strand, " .
     "       t.display_xref_id " .
     "FROM   $source.transcript t, $source.exon_transcript et, " .
     "       $source.exon e " .
     "WHERE  t.transcript_id = et.transcript_id " .
     "AND    et.exon_id = e.exon_id " .
     "GROUP BY t.transcript_id");

  $self->debug("FuguRubripes Specific: Building exon table " .
               "(no chromosomal conversion)");


  #
  # Transfer exon table
  #

  $self->debug("FuguRubripes Specific: Building transcript table " .
               "(no chromosomal conversion)");

  $dbh->do
    ("INSERT INTO $target.exon " .
     "SELECT e.exon_id, e.contig_id, " .
     "       e.contig_start, e.contig_end, e.contig_strand, " .
     "       e.phase, e.end_phase " .
     "FROM   $source.exon e");


  # 
  # Transfer translation table
  # 

  $self->debug("Building translation table");

  $dbh->do
    ("INSERT INTO $target.translation " .
     "SELECT tl.translation_id, ts.transcript_id, tl.seq_start, " .
     "       tl.start_exon_id, tl.seq_end, tl.end_exon_id " .
     "FROM $source.transcript ts, $source.translation tl " .
     "WHERE ts.translation_id = tl.translation_id");

  return;
}


1;
