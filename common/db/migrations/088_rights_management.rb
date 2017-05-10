require_relative 'utils'
require 'securerandom'

def create_rights_statement_act
  create_table(:rights_statement_act) do
    primary_key :id

    Integer :rights_statement_id, :null => false
    DynamicEnum :act_type_id, :null => false
    DynamicEnum :restriction_id, :null => false
    Date :start_date, :null => false
    Date :end_date, :null => true

    apply_mtime_columns
  end

  alter_table(:rights_statement_act) do
    add_foreign_key([:rights_statement_id], :rights_statement, :key => :id)
  end

  create_editable_enum("rights_statement_act_type",
                       ['delete', 'disseminate', 'migrate', 'modify', 'replicate', 'use'])

  create_editable_enum("rights_statement_act_restriction",
                       ['allow', 'disallow', 'conditional'])
end


def link_acts_to_notes
  alter_table(:note) do
    add_column(:rights_statement_act_id, Integer,  :null => true)
    add_foreign_key([:rights_statement_act_id], :rights_statement_act, :key => :id)
  end

  create_enum("note_rights_statement_act_type",
              ['permissions', 'restrictions', 'extension', 'expiration', 'additional_information'])

end


def link_rights_statements_to_agents
  alter_table(:linked_agents_rlshp) do
    add_column(:rights_statement_id, Integer,  :null => true)
    add_foreign_key([:rights_statement_id], :rights_statement, :key => :id)
  end
end


def link_rights_statements_to_notes
  alter_table(:note) do
    add_column(:rights_statement_id, Integer,  :null => true)
    add_foreign_key([:rights_statement_id], :rights_statement, :key => :id)
  end

  create_enum("note_rights_statement_type",
              ['materials', 'type_note', 'additional_information'])

end


def add_identifier_type_to_external_documents
  alter_table(:external_document) do
    add_column(:identifier_type_id, Integer, :null => true)
    add_foreign_key([:identifier_type_id], :enumeration_value, :key => :id, :name => 'external_document_identifier_type_id_fk')
  end

  create_editable_enum('rights_statement_external_document_identifier_type',
                       [ 'agrovoc',
                                'allmovie',
                                'allmusic',
                                'allocine',
                                'amnbo',
                                'ansi',
                                'artsy',
                                'bdusc',
                                'bfi',
                                'bnfcg',
                                'cantic',
                                'cgndb',
                                'danacode',
                                'datoses',
                                'discogs',
                                'dkfilm',
                                'doi',
                                'ean',
                                'eidr',
                                'fast',
                                'filmport',
                                'findagr',
                                'freebase',
                                'gec',
                                'geogndb',
                                'geonames',
                                'gettytgn',
                                'gettyulan',
                                'gnd',
                                'gnis',
                                'gtin-14',
                                'hdl',
                                'ibdb',
                                'idref',
                                'imdb',
                                'isan',
                                'isbn',
                                'isbn-a',
                                'isbnre',
                                'isil',
                                'ismn',
                                'isni',
                                'iso',
                                'isrc',
                                'issn',
                                'issn-l',
                                'issue-number',
                                'istc',
                                'iswc',
                                'itar',
                                'kinopo',
                                'lccn',
                                'lcmd',
                                'lcmpt',
                                'libaus',
                                'local',
                                'matrix-number',
                                'moma',
                                'munzing',
                                'music-plate',
                                'music-publisher',
                                'musicb',
                                'natgazfid',
                                'nga',
                                'nipo',
                                'nndb',
                                'npg',
                                'odnb',
                                'opensm',
                                'orcid',
                                'oxforddnb',
                                'porthu',
                                'rbmsbt',
                                'rbmsgt',
                                'rbmspe',
                                'rbmsppe',
                                'rbmspt',
                                'rbmsrd',
                                'rbmste',
                                'rid',
                                'rkda',
                                'saam',
                                'scholaru',
                                'scope',
                                'scopus',
                                'sici',
                                'spotify',
                                'sprfbsb',
                                'sprfbsk',
                                'sprfcbb',
                                'sprfcfb',
                                'sprfhoc',
                                'sprfoly',
                                'sprfpfb',
                                'stock-number',
                                'strn',
                                'svfilm',
                                'tatearid',
                                'theatr',
                                'trove',
                                'upc',
                                'uri',
                                'urn',
                                'viaf',
                                'videorecording-identifier',
                                'wikidata',
                                'wndla'])

  # Default identifier type to 'local' for any rights statement
  # external documents
  enum_local_id = self[:enumeration_value]
                     .filter(:enumeration_id => self[:enumeration]
                                                  .filter(:name => 'rights_statement_external_document_identifier_type')
                                                  .select(:id))
                     .filter(:value => 'local')
                     .select(:id)
                     .first[:id]

  self[:external_document]
    .filter(Sequel.~(:rights_statement_id => nil))
    .update(:identifier_type_id => enum_local_id)
end


def add_new_rights_statement_columns
  alter_table(:rights_statement) do
    add_column(:status_id, Integer,  :null => true)
    add_column(:start_date, Date, :null => true)
    add_column(:end_date, Date, :null => true)
    add_column(:determination_date, Date, :null => true)
    add_column(:license_terms, String, :null => true)
    add_column(:other_rights_basis_id, Integer, :null => true)

    add_foreign_key([:status_id], :enumeration_value, :key => :id, :name => 'rights_statement_status_id_fk')
    add_foreign_key([:other_rights_basis_id], :enumeration_value, :key => :id, :name => 'rights_statement_other_rights_basis_id_fk')
  end

  create_editable_enum('rights_statement_other_rights_basis',
                       ['donor', 'policy'])
end


# - Populate a meaningful start_date for rights statements
def migrate_rights_statement_start_date
  self[:rights_statement]
    .filter(Sequel.~(:restriction_start_date => nil))
    .update(:start_date => :restriction_start_date)

  # - Ensure all rights statements have a start_date

  # For accessions use the accession_date
  self[:accession]
    .left_outer_join(:rights_statement, :rights_statement__accession_id => :accession__id)
    .filter(:rights_statement__start_date => nil)
    .select(Sequel.as(:rights_statement__id, :rights_statement_id),
            Sequel.as(:accession__accession_date, :accession_date))
    .order(:rights_statement__id)
    .each do |row|

    next if row[:rights_statement_id].nil?

    self[:rights_statement]
      .filter(:id => row[:rights_statement_id])
      .update(:start_date => row[:accession_date])
  end

  # For resources or archival objects
  # take the begin from a 'creation' date and fallback to the 
  # creation timestamp
  ['resource', 'archival_object'].each do |record_type|
    last_rights_statement_id = nil
    # find a date with a 'begin' date
    self[:"#{record_type}"]
      .left_outer_join(:rights_statement, :"rights_statement__#{record_type}_id" => :"#{record_type}__id")
      .left_outer_join(:date, :"date__#{record_type}_id" => :"#{record_type}__id")
      .filter(:rights_statement__start_date => nil)
      .filter(Sequel.~(:date__begin => nil))
      .filter(:date__label_id => self[:enumeration_value]
                                   .filter(:value => 'creation')
                                   .filter(:enumeration_id => self[:enumeration]
                                                                .filter(:name => 'date_label')
                                                                .select(:id))
                                   .select(:id))
      .select(Sequel.as(:rights_statement__id, :rights_statement_id),
              Sequel.as(:date__begin, :begin))
      .order(:rights_statement__id)
      .each do |row|

      next if last_rights_statement_id == row[:rights_statement_id] || row[:rights_statement_id].nil?

      start_date = coerce_date(row[:begin])

      self[:rights_statement]
        .filter(:id => row[:rights_statement_id])
        .update(:start_date => start_date)

      last_rights_statement_id = row[:rights_statement_id]
    end

    # fallback to the create timestamp
    self[:"#{record_type}"]
      .left_outer_join(:rights_statement, :"rights_statement__#{record_type}_id" => :"#{record_type}__id")
      .filter(:rights_statement__start_date => nil)
      .select(Sequel.as(:rights_statement__id, :rights_statement_id),
              Sequel.as(:"#{record_type}__create_time", :create_time))
      .order(:rights_statement__id)
      .each do |row|

      next if row[:rights_statement_id].nil?

      start_date = coerce_timestamp(row[:create_time])

      self[:rights_statement]
        .filter(:id => row[:rights_statement_id])
        .update(:start_date => start_date)
    end
  end

  # For agents, take the begin from the dates of existence and fallback
  # to the creation timestamp
  ['person', 'corporate_entity', 'family','software'].each do |agent_type|
    agent_table = :"agent_#{agent_type}"
    fk_column_id = :"agent_#{agent_type}_id"

    # find a date with a 'begin' date
    last_rights_statement_id = nil
    self[agent_table]
      .left_outer_join(:rights_statement, :"rights_statement__#{fk_column_id}" => :"#{agent_table}__id")
      .left_outer_join(:date, :"date__#{fk_column_id}" => :"#{agent_table}__id")
      .filter(:rights_statement__start_date => nil)
      .filter(Sequel.~(:date__begin => nil))
      .select(Sequel.as(:rights_statement__id, :rights_statement_id),
              Sequel.as(:date__begin, :begin))
      .order(:rights_statement__id)
      .each do |row|
      next if last_rights_statement_id == row[:rights_statement_id] || row[:rights_statement_id].nil?

      start_date = coerce_date(row[:begin])

      self[:rights_statement]
        .filter(:id => row[:rights_statement_id])
        .update(:start_date => start_date)

      last_rights_statement_id = row[:rights_statement_id]
    end

    # fallback to the create timestamp
    self[agent_table]
      .left_outer_join(:rights_statement, :"rights_statement__#{fk_column_id}" => :"#{agent_table}__id")
      .filter(:rights_statement__start_date => nil)
      .select(Sequel.as(:rights_statement__id, :rights_statement_id),
              Sequel.as(:"#{agent_table}__create_time", :create_time))
      .order(:rights_statement__id)
      .each do |row|
      next if row[:rights_statement_id].nil?

      start_date = coerce_timestamp(row[:create_time])

      self[:rights_statement]
        .filter(:id => row[:rights_statement_id])
        .update(:start_date => start_date)
    end
  end
end


# - Rights types coded as "Intellectual Property" should be converted to
#   "Copyright", and Rights types coded as "Institutional Policy"
#   should be converted to "Other".
def migrate_rights_statement_types
  @rights_type_enum_id = self[:enumeration]
                           .filter(:name => 'rights_statement_rights_type')
                           .select(:id)

  self[:enumeration_value]
    .filter(:enumeration_id => @rights_type_enum_id)
    .filter(:value => 'intellectual_property')
    .update(:value => 'copyright')

  self[:enumeration_value]
    .filter(:enumeration_id => @rights_type_enum_id)
    .filter(:value => 'institutional_policy')
    .update(:value => 'other')
end

# - Order Rights Type enums as follows
#   'Copyright', 'License', 'Statute', 'Other'
def reorder_rights_statement_types
  # pump up order to avoid unique constraints
  ['copyright', 'license', 'statute', 'other'].each_with_index do |type, i|
    self[:enumeration_value]
      .filter(:enumeration_id => @rights_type_enum_id)
      .filter(:value => type)
      .update(:position => 10000 + i)
  end

  # now apply the correct order
  ['copyright', 'license', 'statute', 'other'].each_with_index do |type, i|
    self[:enumeration_value]
      .filter(:enumeration_id => @rights_type_enum_id)
      .filter(:value => type)
      .update(:position => i)
  end

end


# - Migrate data currently encoded in "IP Expiration Date" on the
#   "Intellectual Property" template to "End Date" on the Copyright
#   template
def migrate_ip_expiration_date
  self[:rights_statement]
    .filter(Sequel.~(:ip_expiration_date => nil))
    .update(:end_date => :ip_expiration_date)
end


#  - When a rights type is converted from "Institutional Policy" to
#    "Other", the "Other Rights Basis" value should be "Institutional
#    Policy"
def migrate_other_rights_basis
  other_rights_basis_enum = self[:enumeration]
                              .filter(:name => 'rights_statement_other_rights_basis')
                              .select(:id)
  policy_enum_id = self[:enumeration_value]
                     .filter(:enumeration_id => other_rights_basis_enum)
                     .filter(:value => 'policy')
                     .select(:id)
  other_type_id = self[:enumeration_value]
                    .filter(:enumeration_id => @rights_type_enum_id)
                    .filter(:value => 'other')
                    .select(:id)
  self[:rights_statement]
    .filter(:rights_type_id => other_type_id)
    .update(:other_rights_basis_id => policy_enum_id)
end


# - All data currently included in the "Materials" element should be
#   migrated to the note with the label "Materials".
def migrate_materials_to_note
  self[:rights_statement]
    .filter(Sequel.~(:materials => nil))
    .select(:id, :materials, :last_modified_by, :create_time, :system_mtime, :user_mtime)
    .each do |row|
    self[:note].insert(
      :rights_statement_id => row[:id],
      :publish => 1,
      :notes_json_schema_version => 1,
      :notes => ASUtils.to_json({
                                  'jsonmodel_type' => 'note_rights_statement',
                                  'content' => [row[:materials]],
                                  'type' => 'materials',
                                  'persistent_id' => SecureRandom.hex
                                }),
      :last_modified_by => row[:last_modified_by],
      :create_time => row[:create_time],
      :system_mtime => row[:system_mtime],
      :user_mtime => row[:user_mtime]
    )
  end
end


# - Also, all data currently included in the "Type" note should be
# migrated to the note with the label "Type".
def migrate_type_to_note
  self[:rights_statement]
    .filter(Sequel.~(:type_note => nil))
    .select(:id, :type_note, :last_modified_by, :create_time, :system_mtime, :user_mtime)
    .each do |row|
    self[:note].insert(
      :rights_statement_id => row[:id],
      :publish => 1,
      :notes_json_schema_version => 1,
      :notes => ASUtils.to_json({
                                  'jsonmodel_type' => 'note_rights_statement',
                                  'content' => [row[:type_note]],
                                  'type' => 'type_note',
                                  'persistent_id' => SecureRandom.hex
                                }),
      :last_modified_by => row[:last_modified_by],
      :create_time => row[:create_time],
      :system_mtime => row[:system_mtime],
      :user_mtime => row[:user_mtime]
    )
  end
end


# - Migrate data currently encoded in "Permissions" to an Act note
#   sub-record with Label = "Permissions".
def migrate_permissions_to_act_note
  @act_type_use_id = self[:enumeration_value]
                       .filter(:value => 'use')
                       .filter(:enumeration_id => self[:enumeration].filter(:name => 'rights_statement_act_type').select(:id))
                       .select(:id)
                       .first[:id]

  @restriction_allow_id = self[:enumeration_value]
                            .filter(:value => 'allow')
                            .filter(:enumeration_id => self[:enumeration].filter(:name => 'rights_statement_act_restriction').select(:id))
                            .select(:id)
                            .first[:id]

  @allow_act_for_rights_statement = {}

  self[:rights_statement]
    .filter(Sequel.~(:permissions => nil))
    .select(:id, :permissions, :restriction_start_date, :restriction_end_date,
            :start_date, :end_date,
            :last_modified_by, :create_time, :system_mtime, :user_mtime)
    .each do |row|
    act_id = self[:rights_statement_act]
               .insert(
                 :rights_statement_id => row[:id],
                 :act_type_id => @act_type_use_id,
                 :restriction_id => @restriction_allow_id,
                 :start_date => row[:restriction_start_date] || row[:start_date], 
                 :end_date => row[:restriction_end_date],
                 :last_modified_by => row[:last_modified_by],
                 :create_time => row[:create_time],
                 :system_mtime => row[:system_mtime],
                 :user_mtime => row[:user_mtime])

    @allow_act_for_rights_statement[row[:id]] = act_id

    self[:note]
      .insert(
        :rights_statement_act_id => act_id,
        :publish => 1,
        :notes_json_schema_version => 1,
        :notes => ASUtils.to_json({
                                    'jsonmodel_type' => 'note_rights_statement_act',
                                    'content' => [row[:permissions]],
                                    'type' => 'permissions',
                                    'persistent_id' => SecureRandom.hex
                                  }),
        :last_modified_by => row[:last_modified_by],
        :create_time => row[:create_time],
        :system_mtime => row[:system_mtime],
        :user_mtime => row[:user_mtime])
  end
end


# - Migrate data currently encoded in "Restrictions" to an Act note
#   sub-record with Label = "Restrictions".
def migrate_restrictions_to_act_note
  @restriction_disallow_id = self[:enumeration_value]
                              .filter(:value => 'disallow')
                              .filter(:enumeration_id => self[:enumeration].filter(:name => 'rights_statement_act_restriction').select(:id))
                              .select(:id)
                              .first[:id]

  self[:rights_statement]
    .filter(Sequel.~(:restrictions => nil))
    .select(:id, :restrictions, :restriction_start_date, :restriction_end_date,
            :last_modified_by, :create_time, :system_mtime, :user_mtime)
    .each do |row|

    act_id = self[:rights_statement_act]
               .insert(
                 :rights_statement_id => row[:id],
                 :act_type_id => @act_type_use_id,
                 :restriction_id => @restriction_disallow_id,
                 :start_date => row[:restriction_start_date] || row[:start_date],
                 :end_date => row[:restriction_end_date],
                 :last_modified_by => row[:last_modified_by],
                 :create_time => row[:create_time],
                 :system_mtime => row[:system_mtime],
                 :user_mtime => row[:user_mtime])

    self[:note]
      .insert(
        :rights_statement_act_id => act_id,
        :publish => 1,
        :notes_json_schema_version => 1,
        :notes => ASUtils.to_json({
                                    'jsonmodel_type' => 'note_rights_statement_act',
                                    'content' => [row[:restrictions]],
                                    'type' => 'restrictions',
                                    'persistent_id' => SecureRandom.hex
                                  }),
        :last_modified_by => row[:last_modified_by],
        :create_time => row[:create_time],
        :system_mtime => row[:system_mtime],
        :user_mtime => row[:user_mtime])
  end
end


# - Migrate data currently encoded in "Granted Note" to an Act note
#   sub-record with Label = "Additional Information"
#   NB. this will add this note the 'allow' act if created above 
def migrate_granted_note_to_act_note
  self[:rights_statement]
    .filter(Sequel.~(:granted_note => nil))
    .select(:id, :granted_note, :last_modified_by, :create_time, :system_mtime, :user_mtime)
    .each do |row|

    if @allow_act_for_rights_statement.has_key?(row[:id])
      act_id = @allow_act_for_rights_statement[row[:id]]
    else
      act_id = self[:rights_statement_act]
                 .insert(
                   :rights_statement_id => row[:id],
                   :act_type_id => @act_type_use_id,
                   :restriction_id => @restriction_allow_id,
                   :start_date => row[:restriction_start_date] || row[:start_date],
                   :end_date => row[:restriction_end_date],
                   :last_modified_by => row[:last_modified_by],
                   :create_time => row[:create_time],
                   :system_mtime => row[:system_mtime],
                   :user_mtime => row[:user_mtime])
    end

    self[:note]
      .insert(
        :rights_statement_act_id => act_id,
        :publish => 1,
        :notes_json_schema_version => 1,
        :notes => ASUtils.to_json({
                                    'jsonmodel_type' => 'note_rights_statement_act',
                                    'content' => [row[:granted_note]],
                                    'type' => 'additional_information',
                                    'persistent_id' => SecureRandom.hex
                                  }),
        :last_modified_by => row[:last_modified_by],
        :create_time => row[:create_time],
        :system_mtime => row[:system_mtime],
        :user_mtime => row[:user_mtime])
  end
end


def migrate_license_terms
  self[:rights_statement]
    .filter(Sequel.~(:license_identifier_terms => nil))
    .update(:license_terms => :license_identifier_terms)
end



def drop_old_rights_statement_columns
  alter_table(:rights_statement) do
    # drop fks
    drop_foreign_key [:ip_status_id] #, :name => :rights_statement_ibfk_2

    # drop columns
    drop_column(:active)
    drop_column(:ip_status_id)
    drop_column(:restriction_start_date)
    drop_column(:restriction_end_date)
    drop_column(:materials)
    drop_column(:ip_expiration_date)
    drop_column(:type_note)
    drop_column(:permissions)
    drop_column(:restrictions)
    drop_column(:granted_note)
    drop_column(:license_identifier_terms)
  end
end


def coerce_date(date)
  if date =~ /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/
    date # Date.strptime(date, '%Y-%m-%d')
  elsif date =~ /[0-9][0-9][0-9][0-9]-[0-9][0-9]/
    "#{date}-01" # Date.strptime("#{date}-01", '%Y-%m-%d')
  elsif date =~ /[0-9][0-9][0-9][0-9]/
    "#{date}-01-01" # Date.strptime("#{date}-01-01", '%Y-%m-%d')
  else
    raise "Not a date: #{date}"
  end
end


def coerce_timestamp(timestamp)
  timestamp.strftime('%Y-%m-%d')
end

Sequel.migration do

  up do
    self.transaction do
      create_rights_statement_act
      link_acts_to_notes
      link_rights_statements_to_agents
      link_rights_statements_to_notes
      add_identifier_type_to_external_documents
      add_new_rights_statement_columns

      migrate_rights_statement_start_date
      migrate_rights_statement_types
      reorder_rights_statement_types
      migrate_license_terms
      migrate_ip_expiration_date
      migrate_other_rights_basis
      migrate_materials_to_note
      migrate_type_to_note
      migrate_permissions_to_act_note
      migrate_restrictions_to_act_note
      migrate_granted_note_to_act_note

      drop_old_rights_statement_columns
    end
  end

  down do
  end

end
