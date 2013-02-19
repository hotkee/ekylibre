# -*- coding: utf-8 -*-
# == License
# Ekylibre - Simple ERP
# Copyright (C) 2008-2011 Brice Texier, Thibaud Merigon
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
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

class Backend::JournalEntryItemsController < BackendController

  def new
    @journal_entry_item = JournalEntryItem.new
    @journal_entry_item.name = params[:name] if params[:name]
    if params["entry-original-debit"] and params["entry-original-credit"]
      debit, credit = params["entry-original-debit"].to_f, params["entry-original-credit"].to_f
      if debit > credit
        @journal_entry_item.original_credit = debit - credit
      else
        @journal_entry_item.original_debit  = credit - debit
      end
    end
    if params[:journal_id] and @journal = Journal.find_by_id(params[:journal_id])
      if @journal.cashes.size == 1
        @journal_entry_item.account = @journal.cashes.first.account
      end
    end
    params[:printed_on] = params[:printed_on].to_date rescue nil
    if params[:printed_on]
      @financial_year = FinancialYear.at(params[:printed_on])
    end
    if request.xhr?
      render :partial=>"journal_entry_items/row_form", :object=>@journal_entry_item
    else
      redirect_to_back
    end
  end

end
