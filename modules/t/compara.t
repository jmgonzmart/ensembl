# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use strict;
use warnings;

use Test::More;
use Test::Exception;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::DBSQL::OntologyDBAdaptor;
use Bio::EnsEMBL::Test::TestUtils;
use Bio::EnsEMBL::Exon;
use Bio::EnsEMBL::FeaturePair;
use Bio::EnsEMBL::Transcript;
use Bio::EnsEMBL::Translation;
use Bio::EnsEMBL::Gene;
use Bio::EnsEMBL::DnaDnaAlignFeature;

my $human = Bio::EnsEMBL::Test::MultiTestDB->new('homo_sapiens');
my $mouse = Bio::EnsEMBL::Test::MultiTestDB->new('mus_musculus');
my $multi = Bio::EnsEMBL::Test::MultiTestDB->new('multi');

my $core_db = $human->get_DBAdaptor('core');
my $compara_db = $multi->get_DBAdaptor('compara');

# Needed by the functions of the Core API we are testing
Bio::EnsEMBL::Registry->add_alias('multi', 'compara');


## Gene::get_all_homologous_Genes()

my $human_gene = $core_db->get_GeneAdaptor->fetch_by_stable_id('ENSG00000174852');
my $homologues = $human_gene->get_all_homologous_Genes();
is(scalar(@$homologues), 46, 'Got all the homologues');

sub _check_consistency {
    my $triplet = shift;
        subtest $triplet->[2], sub {
            isa_ok($triplet->[0], 'Bio::EnsEMBL::Gene');
            isa_ok($triplet->[1], 'Bio::EnsEMBL::Compara::Homology');
            my $members = $triplet->[1]->get_all_Members;
            is($members->[0]->gene_member->stable_id, 'ENSG00000174852', 'The query gene is correct');
            is($triplet->[0]->stable_id, $members->[1]->gene_member->stable_id, 'The target gene is consistent between Gene and Homology');
            is($members->[1]->genome_db->name, $triplet->[2], 'The species name is correct');
        };
};

my $mouse_gene = $mouse->get_DBAdaptor('core')->get_GeneAdaptor->fetch_by_stable_id('ENSMUSG00000088524');
my @mouse_triplets = grep {$_->[2] eq 'mus_musculus'} @$homologues;
is(scalar(@mouse_triplets), 1, 'One with mouse');
my $mouse_triplet = $mouse_triplets[0];
_check_consistency($mouse_triplet);
subtest 'Mouse triplet', sub {
    ok($mouse_gene->equals($mouse_triplet->[0]), 'The mouse gene is correct');
    is($mouse_triplet->[1]->method_link_species_set_id, 50976, 'mouse homology mlss_id');
    is($mouse_triplet->[1]->dbID, 100972489, 'mouse homology dbID');
};

# For species with no core database, the Gene object is an empty shell
my @dog_triplets = grep {$_->[2] eq 'canis_familiaris'} @$homologues;
is(scalar(@dog_triplets), 1, 'One with dog');
my $dog_triplet = $dog_triplets[0];
_check_consistency($dog_triplet);
subtest 'Dog triplet', sub {
    ok(!$dog_triplet->[0]->dbID, 'The dog gene is made up and has no dbID');
    is($dog_triplet->[0]->stable_id, 'ENSCAFG00000027814', 'dog stable_id');
    is($dog_triplet->[0]->description, 'Small nucleolar RNA SNORD2 [Source:RFAM;Acc:RF01299]', 'dog description');
    is($dog_triplet->[1]->method_link_species_set_id, 50981, 'dog homology mlss_id');
    is($dog_triplet->[1]->dbID, 100972657, 'dog homology dbID');
};


## Slice::get_all_compara_Syntenies()

my $human_chr1 = $core_db->get_SliceAdaptor->fetch_by_region('chromosome', '1');
my $syntenies = $human_chr1->get_all_compara_Syntenies('mus_musculus');
is(scalar(@$syntenies), 18, 'Got all the syntenies');

my $slice_10mb = $core_db->get_SliceAdaptor->fetch_by_region('chromosome', '1', 70_000_000, 80_000_000);
$syntenies = $slice_10mb->get_all_compara_Syntenies('mus_musculus');
is(scalar(@$syntenies), 1, 'Only 1 synteny on this slice');

subtest 'SyntenyRegion', sub {
    my $this_synteny = $syntenies->[0];
    isa_ok($this_synteny, 'Bio::EnsEMBL::Compara::SyntenyRegion');
    is($this_synteny->dbID, 51476, 'dbID');
    is($this_synteny->method_link_species_set_id, 10080, 'mlss_id');
    my $dnafrag_regions = $this_synteny->get_all_DnaFragRegions();
    is(scalar(@$dnafrag_regions), 2, '2 objects in the DnaFragRegion array');
    my ($df1, $df2) = $dnafrag_regions->[0]->genome_db->name eq 'homo_sapiens' ?  @$dnafrag_regions : ($dnafrag_regions->[1], $dnafrag_regions->[0]);
    isa_ok($df1, 'Bio::EnsEMBL::Compara::DnaFragRegion');
    is($df1->dnafrag->name, '1', 'human chromosome 1');
    is($df1->dnafrag_start, 68121446, 'human start');
    is($df1->dnafrag_end, 89272452, 'human end');
    is($df1->dnafrag_strand, 1, 'human strand');
    isa_ok($df2, 'Bio::EnsEMBL::Compara::DnaFragRegion');
    is($df2->genome_db->name, 'mus_musculus', 'Synteny with mouse');
    is($df2->dnafrag->name, '3', 'mouse chromosome 3');
    is($df2->dnafrag_start, 142496995, 'mouse start');
    is($df2->dnafrag_end, 159939079, 'mouse end');
    is($df2->dnafrag_strand, -1, 'mouse strand');
};

done_testing();
