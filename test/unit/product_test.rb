# = Informations
# 
# == License
# 
# Ekylibre - Simple ERP
# Copyright (C) 2009-2010 Brice Texier, Thibaud Mérigon
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
#  active                 :boolean          default(TRUE), not null
#  catalog_description    :text             
#  catalog_name           :string(255)      not null
#  charge_account_id      :integer          
#  code                   :string(8)        
#  code2                  :string(64)       
#  comment                :text             
#  company_id             :integer          not null
#  created_at             :datetime         not null
#  creator_id             :integer          
#  critic_quantity_min    :decimal(, )      default(1.0)
#  description            :text             
#  ean13                  :string(13)       
#  id                     :integer          not null, primary key
#  lock_version           :integer          default(0), not null
#  manage_stocks          :boolean          not null
#  name                   :string(255)      not null
#  nature                 :string(8)        not null
#  number                 :integer          not null
#  price                  :decimal(, )      default(0.0)
#  product_account_id     :integer          
#  quantity_max           :decimal(, )      default(0.0)
#  quantity_min           :decimal(, )      default(0.0)
#  reduction_submissive   :boolean          not null
#  service_coeff          :float            
#  shelf_id               :integer          not null
#  subscription_nature_id :integer          
#  subscription_period    :string(255)      
#  subscription_quantity  :integer          
#  to_produce             :boolean          not null
#  to_purchase            :boolean          not null
#  to_rent                :boolean          not null
#  to_sale                :boolean          default(TRUE), not null
#  unit_id                :integer          not null
#  unquantifiable         :boolean          not null
#  updated_at             :datetime         not null
#  updater_id             :integer          
#  weight                 :decimal(, )      
#

require 'test_helper'

class ProductTest < ActiveSupport::TestCase
  # Replace this with your real tests.
  def test_truth
    assert true
  end
end