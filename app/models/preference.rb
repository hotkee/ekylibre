# = Informations
#
# == License
#
# Ekylibre - Simple ERP
# Copyright (C) 2009-2013 Brice Texier, Thibaud Merigon
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see http://www.gnu.org/licenses.
#
# == Table: preferences
#
#  boolean_value     :boolean
#  created_at        :datetime         not null
#  creator_id        :integer
#  decimal_value     :decimal(19, 4)
#  id                :integer          not null, primary key
#  integer_value     :integer
#  lock_version      :integer          default(0), not null
#  name              :string(255)      not null
#  nature            :string(8)        default("u"), not null
#  record_value_id   :integer
#  record_value_type :string(255)
#  string_value      :text
#  updated_at        :datetime         not null
#  updater_id        :integer
#  user_id           :integer
#


class Preference < Ekylibre::Record::Base
  enumerize :nature, :in => Preference.columns_hash.keys.select{|x| x.match(/_value(_id)?$/)}.collect{|x| x.split(/_value/)[0].to_sym }, :default => :string, :predicates => true
  @@natures = self.nature.values
  @@conversions = {:float => :decimal, :true_class => :boolean, :false_class => :boolean, :fixnum => :integer}
  cattr_reader :reference
  attr_readonly :user_id, :name, :nature
  belongs_to :user, :class_name => "Entity"
  belongs_to :record_value, :polymorphic => true
  # cattr_reader :reference
  #[VALIDATORS[ Do not edit these items directly. Use `rake clean:validations`.
  validates_numericality_of :integer_value, :allow_nil => true, :only_integer => true
  validates_numericality_of :decimal_value, :allow_nil => true
  validates_length_of :nature, :allow_nil => true, :maximum => 8
  validates_length_of :name, :record_value_type, :allow_nil => true, :maximum => 255
  validates_presence_of :name, :nature
  #]VALIDATORS]
  validates_inclusion_of :nature, :in => @@natures
  validates_uniqueness_of :name, :scope => [:user_id]

  def self.prefer(name, nature, default_value)
    @@reference ||= HashWithIndifferentAccess.new
    raise ArgumentError.new("Nature (#{nature.inspect}) is unacceptable. #{self.nature.values.to_sentence} are accepted.") unless self.nature.values.include?(nature.to_s)
    @@reference[name] = {:name => :name, :nature => nature.to_sym, :default => default_value}
  end

  prefer :bookkeep_automatically, :boolean, true
  prefer :bookkeep_in_draft, :boolean, true
  prefer :detail_payments_in_deposit_bookkeeping, :boolean, true
  prefer :use_entity_codes_for_account_numbers, :boolean, true
  prefer :sales_conditions, :string, ""

  # TODO removes these preferences to manage charts
  prefer :capital_gains_accounts, :integer, 120
  prefer :capital_losses_accounts, :integer, 129
  prefer :charges_accounts, :integer, 6
  prefer :financial_banks_accounts, :integer, 51
  prefer :financial_cashes_accounts, :integer, 53
  prefer :financial_internal_transfers_accounts, :integer, 58
  prefer :financial_payments_to_deposit_accounts, :integer, 511
  prefer :products_accounts, :integer, 7
  prefer :taxes_acquisition_accounts, :integer, 4452
  prefer :taxes_assimilated_accounts, :integer, 447
  prefer :taxes_balance_accounts, :integer, 44567
  prefer :taxes_payback_accounts, :integer, 44583
  prefer :taxes_collected_accounts, :integer, 4457
  prefer :taxes_paid_accounts, :integer, 4456
  prefer :third_attorneys_accounts, :integer, 467
  prefer :third_clients_accounts, :integer, 411
  prefer :third_suppliers_accounts, :integer, 401


  def self.type_to_nature(klass)
    klass = klass.to_s
    if  ['String', 'Symbol'].include? klass
      :string
    elsif ['Integer', 'Fixnum', 'Bignum'].include? klass
      :integer
    elsif ['TrueClass', 'FalseClass', 'Boolean'].include? klass
      :boolean
    elsif ['BigDecimal'].include? klass
      :decimal
    else
      :record
    end
  end

  def self.[](name)
    return self.get(name).value
  end


  def self.get(name)
    preference = Preference.find_by_name(name)
    if preference.nil? and self.reference.has_key?(name.to_s)
      preference = self.new
      preference.name = name
      preference.nature = self.reference[name][:nature]
      preference.value = self.reference[name][:default] if self.reference[name][:default]
      preference.save!
    elsif preference.nil?
      raise ArgumentError.new("Undefined preference: "+name.to_s)
    end
    return preference
  end

  def value
    self.send(self.nature+'_value')
  end

  def value=(object)
#     if @@reference[self.name]
#       self.nature = @@reference[self.name][:nature]
#       self.record_value_type = @@reference[self.name][:model].name if @@reference[self.name][:model]
#     end
    self.nature ||= self.class.type_to_nature(object.class)
    raise ArgumentError.new("Object to define as preference is an unknown type #{object.class.name}:#{self.nature}") unless @@natures.include? self.nature
    if self.nature == 'record' and object.class.name != self.record_value_type
      begin
        self.send(self.nature.to_s+'_value=', self.record_value_type.constantize.find(object.to_i))
      rescue
        self.record_value_id = nil
      end
    else
      self.send(self[:nature].to_s+'_value=', object)
    end
  end

  def set(object)
    self.value = object
    self.save
  end

  def label(locale=nil)
    ::I18n.t("preferences." + self.name.to_s, :locale => locale)
  end

  def record?
    self.nature == 'record'
  end

  def model
    self.record? ? self.record_value_type.constantize : nil
  end


  private

  def self.convert(nature, string)
    case nature.to_sym
    when :boolean
      (string == "true" ? true : false)
    when :integer
      string.to_i
    when :decimal
      string.to_f
    else
      string
    end
  end

end
