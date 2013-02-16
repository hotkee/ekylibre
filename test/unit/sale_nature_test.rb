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
# == Table: sale_natures
#
#  active                  :boolean          default(TRUE), not null
#  created_at              :datetime         not null
#  creator_id              :integer
#  currency                :string(3)
#  description             :text
#  downpayment             :boolean          not null
#  downpayment_minimum     :decimal(19, 4)   default(0.0), not null
#  downpayment_percentage  :decimal(19, 4)   default(0.0), not null
#  expiration_delay        :string(255)      not null
#  id                      :integer          not null, primary key
#  journal_id              :integer
#  lock_version            :integer          default(0), not null
#  name                    :string(255)      not null
#  payment_delay           :string(255)      not null
#  payment_mode_complement :text
#  payment_mode_id         :integer
#  sales_conditions        :text
#  updated_at              :datetime         not null
#  updater_id              :integer
#  with_accounting         :boolean          not null
#


require 'test_helper'

class SaleNatureTest < ActiveSupport::TestCase
  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
