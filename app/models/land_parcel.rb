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
# == Table: products
#
#  active                   :boolean          not null
#  address_id               :integer
#  area_measure             :decimal(19, 4)
#  area_unit                :string(255)
#  asset_id                 :integer
#  born_at                  :datetime
#  content_maximal_quantity :decimal(19, 4)   default(0.0), not null
#  content_nature_id        :integer
#  content_unit             :string(255)
#  created_at               :datetime         not null
#  creator_id               :integer
#  current_place_id         :integer
#  dead_at                  :datetime
#  description              :text
#  external                 :boolean          not null
#  father_id                :integer
#  id                       :integer          not null, primary key
#  identification_number    :string(255)
#  lock_version             :integer          default(0), not null
#  maximal_quantity         :decimal(19, 4)   default(0.0), not null
#  minimal_quantity         :decimal(19, 4)   default(0.0), not null
#  mother_id                :integer
#  name                     :string(255)      not null
#  nature_id                :integer          not null
#  number                   :string(255)      not null
#  owner_id                 :integer          not null
#  parent_id                :integer
#  picture_content_type     :string(255)
#  picture_file_name        :string(255)
#  picture_file_size        :integer
#  picture_updated_at       :datetime
#  real_quantity            :decimal(19, 4)   default(0.0), not null
#  reproductor              :boolean          not null
#  reservoir                :boolean          not null
#  sex                      :string(255)
#  shape                    :spatial({:srid=>
#  tracking_id              :integer
#  type                     :string(255)      not null
#  unit                     :string(255)      not null
#  updated_at               :datetime         not null
#  updater_id               :integer
#  variety                  :string(127)      not null
#  virtual_quantity         :decimal(19, 4)   default(0.0), not null
#  work_number              :string(255)
#


class LandParcel < PrimaryZone
  attr_accessible :name, :area_measure, :area_unit, :born_at, :dead_at, :shape, :unit, :variety
  # belongs_to :area_unit, :class_name => "Unit"
  # TODO : adapt with operations
  #has_many :operations, :as => :target
  # TODO : waiting for "merge" operation type
  #has_many :parent_kinships, :class_name => "LandParcelKinship", :foreign_key => :child_land_parcel_id, :dependent => :destroy
  #has_many :child_kinships, :class_name => "LandParcelKinship", :foreign_key => :parent_land_parcel_id, :dependent => :destroy
  #[VALIDATORS[ Do not edit these lines directly. Use `rake clean:validations`.
  #]VALIDATORS]
  validates_presence_of :born_at # :area_measure, :area_unit,

  before_validation do
    if self.shape
      self.area_measure = self.shape.area
      self.area_unit = Unit.get(:m2)
      for unit in Unit.where(:base => "m2").order("coefficient DESC")
        measure = unit.convert_from(self.area_measure, self.area_unit)
        if measure >= 1
          self.area_unit = unit
          self.area_measure = measure
          break
        end
      end
    end
  end

  # TODO : waiting for operations stabilizations
  #before_validation(:on => :update) do
    #if self.operations.count <= 0
      # We can't change the area of a parcel if operations has been made on it
      #old = self.class.find(self.id)
      #self.area_measure = old.area_measure
      #self.area_unit = old.area_unit
    #end
  #end

  # TODO : waiting for "merge" operation type
  #def divide(subdivisions, divided_on)
  #  if (total = subdivisions.collect{|s| s[:area_measure].to_f}.sum) != self.area_measure.to_f
  #   errors.add :area_measure, :invalid, :measure => total, :expected_measure => self.area_measure, :unit => self.area_unit.name
  #    return false
  # end
  #  return false unless divided_on.is_a? Date
  #  return false unless divided_on > self.started_on
  #  for subdivision in subdivisions
  #    child = LandParcel.create!(subdivision.merge(:started_on => divided_on+1, :area_unit => self.area_unit))
  #    LandParcelKinship.create!(:parent_land_parcel => self, :child_land_parcel => child, :nature => "divide")
  #  end
  #  self.update_column(:stopped_on, divided_on)
  #end

  # TODO : waiting for "merge" operation type
  #def merge(other_parcels, merged_on)
  #  return false unless other_parcels.size > 0
  #  return false unless merged_on.is_a? Date
  #  return false unless merged_on > self.started_on
  #  parcels, area = [self]+other_parcels, 0.0
  # parcels.each{|p| area += p.area(self.area_unit) }
  # child = LandParcel.create!(:name => parcels.collect{|p| p.name}.join("+"), :started_on => merged_on+1, :area_unit => self.area_unit, :area_measure => area)
  #  for parcel in parcels
  #    LandParcelKinship.create!(:parent_land_parcel => parcel, :child_land_parcel => child, :nature => "merge")
  #   parcel.update_column(:stopped_on, merged_on)
  # end
  #return child
  #end


  def area(unit=nil)
    # return Unit.convert(self.area_measure, self.area_unit, unit)
    return self.area_unit.convert_to(self.area_measure, unit)
  end

  # TODO : waiting for operations
  #def operations_on(viewed_on=Date.today)
    #self.operations.find(:all, :conditions => ["(moved_on IS NULL AND planned_on=?) OR (moved_on IS NOT NULL AND moved_on=?)", viewed_on, viewed_on])
  #end

end
